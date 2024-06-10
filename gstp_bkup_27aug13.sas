%include '/user1/qcpap020/autoexec_new.sas'; 
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  gstp.sas
|
| LOCATION: /PRG/sas&sysmode.1/hercules/5295
|
| PURPOSE:  produce task #57 (GSTP mailing).
|
| LOGIC:    All clients enrolled in GSTP program are targeted
|           One-time preimplementation letter is sent to prescribers and participants
|           There are three program types
|           14 different drug classes are targeted
|
| INPUT:    TABLES ACCESSED BY CALLED MACROS ARE NOT LISTED BELOW
|
| OUTPUT:   standard files in /pending and /results directories
|
|
+-------------------------------------------------------------------------------
| HISTORY:  E.Sliounkova 11/04/2010 Original Version
|
|           01MAY2011     - Brian Stropich - Hercules Version  2.1.0
|                           Adjusted the program for a Rx number - character of 12.
|           27JUL2010     - P. Landis                
|							Modified to execute in hercdev2 environment
+-----------------------------------------------------------------------HEADER*/

%SET_SYSMODE;

/*OPTIONS SYSPARM='INITIATIVE_ID= PHASE_SEQ_NB=1';*/
OPTIONS MPRINT SOURCE2 MPRINTNEST MLOGIC MLOGICNEST symbolgen ;
%include "/herc&sysmode/prg/hercules/hercules_in.sas";

/*OPTIONS FULLSTIMER MPRINT MLOGIC SYMBOLGEN SOURCE2 MPRINTNEST MLOGICNEST;*/

%LET ERR_FL=0;
%LET PROGRAM_NAME=gstp;

filename parm  "/herc&sysmode/data/hercules/5295/gstp_custom_parm.csv"; 
filename apn   "/herc&sysmode/data/hercules/5295/gstp_apn_parm.csv";
libname out    "/herc&sysmode/data/hercules/5295/";

*SASDOC----------------------------------------------------------------------
| SET THE PARAMETERS FOR ERROR CHECKING
+---------------------------------------------------------------------SASDOC*;
 PROC SQL NOPRINT;
    SELECT QUOTE(TRIM(EMAIL)) INTO :PRIMARY_PROGRAMMER_EMAIL SEPARATED BY ' '
    FROM ADM_LKP.ANALYTICS_USERS
    WHERE UPCASE(QCP_ID) IN ('QCPAP020');
 QUIT;
%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  NOTIFICATION OF ABEND",
          EM_MSG="A PROBLEM WAS ENCOUNTERED.  SEE LOG FILE - &PROGRAM_NAME..LOG FOR INITIATIVE ID &INITIATIVE_ID");

*SASDOC-------------------------------------------------------------------------
| UPDATE THE JOB START TIMESTAMP.
+-----------------------------------------------------------------------SASDOC*;
%UPDATE_TASK_TS(JOB_START_TS);

*SASDOC-------------------------------------------------------------------------
| SETUP DATES
+-----------------------------------------------------------------------SASDOC*;

DATA _NULL_;
IMPL_DT_SAS     = INTNX ("MONTH", TODAY(), 2);
CLM_END_DT_SAS  = INTNX ("DAY", TODAY(), -7);
CLM_BEG_DT_SAS  = CLM_END_DT_SAS - 120;
CLM_EXL_DT_SAS  = MDY(MONTH(CLM_BEG_DT_SAS), DAY(CLM_BEG_DT_SAS), YEAR(CLM_BEG_DT_SAS) -2);

IMPL_DT         = "'" || PUT(IMPL_DT_SAS, YYMMDD10.) || "'";  
CALL SYMPUT('IMPL_DT', TRIM(IMPL_DT));
BDATE           = "'" || PUT(CLM_BEG_DT_SAS, YYMMDD10.) || "'";  
CALL SYMPUT('BDATE', TRIM(BDATE));
EDATE           = "'" || PUT(CLM_END_DT_SAS, YYMMDD10.) || "'";  
CALL SYMPUT('EDATE', TRIM(EDATE));
BDATE_EXCL      = "'" || PUT(CLM_EXL_DT_SAS, YYMMDD10.) || "'";  
CALL SYMPUT('BDATE_EXCL', TRIM(BDATE_EXCL));


CALL SYMPUT('BDATE_SAS',CLM_BEG_DT_SAS);
CALL SYMPUT('EDATE_SAS',CLM_END_DT_SAS);


PUT _ALL_;
RUN;

*SASDOC-------------------------------------------------------------------------
| Override Date Parameters for testing only
+-----------------------------------------------------------------------SASDOC*;
/*%LET IMPL_DT=%STR('2013-01-01');*/

/*%LET BDATE=%STR('2010-07-07');          ***BEGINING DISPENSE DATE***;*/
/**/
/****EXCLUSION MEDS BEGIN DATE - STANDARD IS MOST RECENT 24 MONTHS OF DATA***;*/
/*%LET BDATE_EXCL=%STR('2008-07-07');          ***BEGINING DISPENSE DATE***;*/
/**/
/****CLAIMS INCLUSION AND EXCLUSION END DATE****;*/
/*%LET EDATE=%STR('2010-11-04');*/

*SASDOC-------------------------------------------------------------------------
| Set Global Parameters
+-----------------------------------------------------------------------SASDOC*;
***PARTICIPANT AGE QUAL - DEFAULT VALUE IS 0 ****;
%LET AGEQUAL=0;

**PHYSICIAN DEGREES ELIGIBLE FOR TARGETING - DEFAULT VALUES: ('MD','NP','DO','PA')***;
%LET DEGREE=%STR('MD','NP','DO','PA');

****EDW SCHEMA - DEFAULT IS DSS_CLIN  USE DSS_PHI FOR CVS AND OTHER CLIENTS NOT IN DSS_CLIN***;
%LET DSS_CLIN=DSS_CLIN; 
LIBNAME DWCORP ORACLE SCHEMA=DWCORP PATH=&GOLD;

*SASDOC-------------------------------------------------------------------------
| Create current timestamp
+-----------------------------------------------------------------------SASDOC*;
DATA _NULL_;
  X=PUT(TODAY(),YYMMDD10.);
  Y="'"||X||"'"; 
  DSNME=INT(TIME());
  CALL SYMPUT('DSNME',LEFT(TRIM(DSNME)));
  CALL SYMPUT('CURDATE',LEFT(Y) );
RUN;
%PUT &CURDATE;
%PUT &DSNME;
*SASDOC----------------------------------------------------------------------
| READ CUSTOM PARM FILE TO DETERMINE STANDARD OR CUSTOM RUN
+---------------------------------------------------------------------SASDOC*;

%MACRO GSTP_RUN_TYPE;

%GLOBAL STD_IND;

DATA CUSTOM_LIST
;

INFILE PARM 
DLM=',' 
DSD 
MISSOVER
FIRSTOBS=2;

INPUT 

SYS_CD             :$1.
INSURANCE_CD       :$3.
CARRIER_ID         :$20.
ACCOUNT_ID         :$20.
GROUP_CD           :$20.
CLIENT_ID          :5.
GROUP_CLASS_CD     :8.
GROUP_CLASS_SEQ_NB :5.
BLG_REPORTING_CD   :$15.
PLAN_NM            :$40.
PLAN_CD            :$8.
PLAN_EXT_CD        :$8.
GROUP_CD           :$15.
GROUP_EXT_CD       :$5.
IMPL_DT            :$10.
;

RUN;

RUN;
%SET_ERROR_FL;

*SASDOC----------------------------------------------------------------------
| If dataset is empty this means STANDARD RUN
+---------------------------------------------------------------------SASDOC*;
		PROC SQL NOPRINT;
        SELECT COUNT(*) INTO :CUSTOM_CNT
        FROM CUSTOM_LIST;
        QUIT;
		RUN;
%SET_ERROR_FL;


DATA _NULL_;
IF &CUSTOM_CNT = 0 THEN DO;
   CALL SYMPUT('STD_IND','Y');
END;
ELSE DO;
   CALL SYMPUT('STD_IND','N');
END;
RUN;
%SET_ERROR_FL;

%PUT STD_IND = &STD_IND;

*SASDOC----------------------------------------------------------------------
| Create temp DB2 table to store hierarchy for custom run
+---------------------------------------------------------------------SASDOC*;
%IF %UPCASE(&STD_IND.) = N %THEN %DO;

%DROP_DB2_TABLE(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._GSTP_CSTM_IN); 

	PROC SQL;
	 CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	    EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._GSTP_CSTM_IN
		(			 SRC_SYS_CD                 CHAR(1)
				     ,INSURANCE_CD               VARCHAR(20)
				     ,CARRIER_ID                 VARCHAR(20)
					 ,ACCOUNT_ID                 VARCHAR(20)
					 ,GROUP_CD                   VARCHAR(20)
					 ,CLIENT_ID               INTEGER
					 ,GROUP_CLASS_CD          INTEGER
					 ,GROUP_CLASS_SEQ_NB      INTEGER
					 ,BLG_REPORTING_CD        VARCHAR(15)
					 ,PLAN_NM                 VARCHAR(40)
					 ,PLAN_CD_TX                 VARCHAR(8)
					 ,PLAN_EXT_CD_TX             VARCHAR(8)
					 ,GROUP_CD_TX                VARCHAR(15)
					 ,GROUP_EXT_CD_TX            VARCHAR(5)
					 ,EFFECTIVE_DT               DATE
		) NOT LOGGED INITIALLY) BY DB2;
	 DISCONNECT FROM DB2;
	QUIT;
%SET_ERROR_FL;
	PROC SQL;
			INSERT INTO &DB2_TMP..&TABLE_PREFIX._GSTP_CSTM_IN
				SELECT  SYS_CD      
						,INSURANCE_CD 
						,CARRIER_ID      
						,ACCOUNT_ID  
						,GROUP_CD
						,CLIENT_ID
						,GROUP_CLASS_CD
						,GROUP_CLASS_SEQ_NB
						,BLG_REPORTING_CD
						,PLAN_NM
						,PLAN_CD
						,PLAN_EXT_CD
						,GROUP_CD
						,GROUP_EXT_CD
						,INPUT(IMPL_DT,YYMMDD10.)

				FROM CUSTOM_LIST;
				QUIT;
				RUN;
	%END;
%SET_ERROR_FL;
%MEND;




*SASDOC--------------------------------------------------------------------------
| Link specific client with specific targetting GSTP drugs
+------------------------------------------------------------------------SASDOC*;


%MACRO GET_CLIENT_DRUG_LINK(STD_IND=);


*SASDOC-------------------------------------------------------------------------
| Macro for fields compare: character fields
+-----------------------------------------------------------------------SASDOC*;
%MACRO BLANK_OR_EQ_DB2(VAR=);
AND ((A.&VAR. IS NULL AND C.&VAR. IS NULL) 
OR (A.&VAR. ='' AND C.&VAR. IS NULL)
OR (A.&VAR. IS NULL AND C.&VAR. ='')
OR (UPPER(TRIM(A.&VAR.)) = UPPER(TRIM(C.&VAR.))))
%MEND;

*SASDOC-------------------------------------------------------------------------
| Macro for fields compare: numeric fields
+-----------------------------------------------------------------------SASDOC*;
%MACRO BLANK_OR_EQ_DB2_NUM(NMA=,NMC=);
AND ((A.&NMA. IS NULL AND C.&NMC. IS NULL) 
OR (A.&NMA. =0 AND C.&NMC. IS NULL)
OR (A.&NMA. IS NULL AND C.&NMC. =0)
OR (A.&NMA. = C.&NMC.))
%MEND;


*SASDOC--------------------------------------------------------------------------
| Get QL Client-Drug Information
+------------------------------------------------------------------------SASDOC*;
PROC SQL NOPRINT;
	        CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
			CREATE TABLE STD_QL_GSTP AS
	        SELECT * FROM CONNECTION TO DB2
	   		(  SELECT
					'Q' || TRIM(COALESCE(CHAR(A.CLIENT_ID),''))|| TRIM(COALESCE(CHAR(A.GROUP_CLS_CD),'')) 
                    || TRIM(COALESCE(CHAR(A.GROUP_CLS_SEQ_NB),''))
					|| TRIM(COALESCE(A.BLG_REPORTING_CD,'')) || TRIM(COALESCE(A.PLAN_NM,'')) || TRIM(COALESCE(A.PLAN_CD_TX,'')) 
					|| TRIM(COALESCE(A.PLAN_EXT_CD_TX,'')) || TRIM(COALESCE(A.GROUP_CD_TX,'')) || TRIM(COALESCE(A.GROUP_EXT_CD_TX,''))
					AS TARGET_CLIENT_KEY
					, A.GSTP_GSA_PGMTYP_CD
					, A.CLT_EFF_DT AS EFFECTIVE_DT
					, A.DRG_CLS_SEQ_NB
					, A.DRG_CLS_CATG_TX
					, A.DRG_CLS_CAT_DES_TX AS DRG_CLS_CATG_DESC_TX
					, A.GSTP_GRD_FATH_IN
					, B.GSTP_GPI_CD
			        , CHAR(B.GSTP_GCN_CD) AS GSTP_GCN_CD 
					, CHAR(B.GSTP_DRG_NDC_ID) AS GSTP_DRG_NDC_ID
					, B.DRG_DTW_CD
					, B.GSTP_GPI_NM
					, B.MULTI_SRC_IN
					, B.RXCLAIM_BYP_STP_IN
					, B.QL_BRND_IN
					, B.DRG_LABEL_NM
					, D.GSA_SHT_DSC_TX  AS PROGRAM_TYPE
					FROM &HERCULES..TPMTSK_GSTP_QL_RUL A
				   %IF %UPCASE(&STD_IND.) = N %THEN %DO;
					, &HERCULES..TPMTSK_GSTP_QL_DET B
					%END;
					%ELSE %DO;
					, &HERCULES..TGSTP_DRG_CLS_DET B
					%END;

/*					FROM PBATCH.TPMTSK_GSTP_QL_RUL A*/
/*					, PBATCH.TPMTSK_GSTP_QL_DET B*/
					, &HERCULES..VSMINT_GSA_PGMTYP_CD  D
					%IF %UPCASE(&STD_IND.) = N %THEN %DO;
			           , &DB2_TMP..&TABLE_PREFIX._GSTP_CSTM_IN C
			  		%END;
					
					WHERE A.PROGRAM_ID = &PROGRAM_ID.
			  		AND A.TASK_ID = &TASK_ID.
	
					%IF %UPCASE(&STD_IND.) = N %THEN %DO;
					AND A.GSTP_QL_RUL_ID = B.GSTP_QL_RUL_ID
		  	  		AND A.GSTP_GSA_PGMTYP_CD IN (4)
			  		AND C.SRC_SYS_CD = 'Q'
			  		AND C.CLIENT_ID = A.CLIENT_ID
			  		AND C.EFFECTIVE_DT = A.CLT_EFF_DT
			  		%BLANK_OR_EQ_DB2_NUM(NMA=GROUP_CLS_CD,NMC=GROUP_CLASS_CD)
			  		%BLANK_OR_EQ_DB2_NUM(NMA=GROUP_CLS_SEQ_NB,NMC=GROUP_CLASS_SEQ_NB)
			  		%BLANK_OR_EQ_DB2    (VAR=BLG_REPORTING_CD)
			  		%BLANK_OR_EQ_DB2    (VAR=PLAN_NM)
			  		%BLANK_OR_EQ_DB2    (VAR=PLAN_CD_TX)
			  		%BLANK_OR_EQ_DB2    (VAR=PLAN_EXT_CD_TX)
			  		%BLANK_OR_EQ_DB2    (VAR=GROUP_CD_TX)
			  		%BLANK_OR_EQ_DB2    (VAR=GROUP_EXT_CD_TX)
			  		%END;

			  		%ELSE %DO;
					AND A.CLT_EFF_DT = &IMPL_DT. /*update later*/
					AND A.GSTP_GSA_PGMTYP_CD IN (1,2,3)
					AND A.GSTP_GSA_PGMTYP_CD = B.GSTP_GSA_PGMTYP_CD
					AND A.DRG_CLS_SEQ_NB = B.DRG_CLS_SEQ_NB
					AND B.DRG_CLS_EFF_DT <= CURRENT DATE  
					AND B.DRG_CLS_EXP_DT >= CURRENT DATE  
					%END;

				    AND A.DRG_CLS_EFF_DT <= CURRENT DATE 
					AND A.DRG_CLS_EXP_DT >= CURRENT DATE 
					AND B.DRG_EFF_DT <= CURRENT DATE 
					AND B.DRG_EXP_DT >= CURRENT DATE 
					AND A.GSTP_GSA_PGMTYP_CD = D.GSA_PGMTYP_CD
			

		    WITH UR
			  		);

*SASDOC--------------------------------------------------------------------------
| Get RECAP Client-Drug Information   
+------------------------------------------------------------------------SASDOC*;
			CREATE TABLE STD_RECAP_GSTP  AS
	        SELECT * FROM CONNECTION TO DB2
	   		(  SELECT 
					'R'|| TRIM(COALESCE(A.INSURANCE_CD,'')) ||TRIM(COALESCE(A.CARRIER_ID,''))
                       || TRIM(COALESCE(A.GROUP_CD,''))
					AS TARGET_CLIENT_KEY
					, A.GSTP_GSA_PGMTYP_CD
					, A.CLT_EFF_DT AS EFFECTIVE_DT
					, A.DRG_CLS_SEQ_NB
					, A.DRG_CLS_CATG_TX
					, A.DRG_CLS_CAT_DES_TX AS DRG_CLS_CATG_DESC_TX
					, A.GSTP_GRD_FATH_IN
					, B.GSTP_GPI_CD
			        , CHAR(B.GSTP_GCN_CD) AS GSTP_GCN_CD 
					, CHAR(B.GSTP_DRG_NDC_ID) AS GSTP_DRG_NDC_ID
					, B.DRG_DTW_CD
					, B.GSTP_GPI_NM
					, B.MULTI_SRC_IN
					, B.RXCLAIM_BYP_STP_IN
					, B.QL_BRND_IN
					, B.DRG_LABEL_NM
					, D.GSA_SHT_DSC_TX  AS PROGRAM_TYPE
					FROM &HERCULES..TPMTSK_GSTP_RP_RUL A
				   %IF %UPCASE(&STD_IND.) = N %THEN %DO;
					, &HERCULES..TPMTSK_GSTP_RP_DET B
					%END;
					%ELSE %DO;
					, &HERCULES..TGSTP_DRG_CLS_DET B
					%END;

/*					FROM PBATCH.TPMTSK_GSTP_RP_RUL A*/
/*					, PBATCH.TPMTSK_GSTP_RP_DET B*/
					, &HERCULES..VSMINT_GSA_PGMTYP_CD  D

					%IF %UPCASE(&STD_IND.) = N %THEN %DO;
			           , &DB2_TMP..&TABLE_PREFIX._GSTP_CSTM_IN C
			  		%END;
	
					WHERE A.PROGRAM_ID = &PROGRAM_ID.
			  		AND A.TASK_ID = &TASK_ID.
			

					%IF %UPCASE(&STD_IND.) = N %THEN %DO;
					AND A.GSTP_RECAP_RUL_ID = B.GSTP_RECAP_RUL_ID
		  	  		AND A.GSTP_GSA_PGMTYP_CD IN (4)
			  		AND C.SRC_SYS_CD = 'R'
			  		AND C.INSURANCE_CD = A.INSURANCE_CD
			  		AND C.EFFECTIVE_DT = A.CLT_EFF_DT
			  		%BLANK_OR_EQ_DB2    (VAR=CARRIER_ID)
			  		%BLANK_OR_EQ_DB2    (VAR=GROUP_CD)
			  		%END;
			 		%ELSE %DO;
					AND A.CLT_EFF_DT = &IMPL_DT.
					AND A.GSTP_GSA_PGMTYP_CD IN (1,2,3)
					AND A.GSTP_GSA_PGMTYP_CD = B.GSTP_GSA_PGMTYP_CD
					AND A.DRG_CLS_SEQ_NB = B.DRG_CLS_SEQ_NB
					AND B.DRG_CLS_EFF_DT <= CURRENT DATE  
					AND B.DRG_CLS_EXP_DT >= CURRENT DATE  
			  		%END;

				    AND A.DRG_CLS_EFF_DT <= CURRENT DATE  
					AND A.DRG_CLS_EXP_DT >= CURRENT DATE  
					AND B.DRG_EFF_DT <= CURRENT DATE  
					AND B.DRG_EXP_DT >= CURRENT DATE  

					AND A.GSTP_GSA_PGMTYP_CD = D.GSA_PGMTYP_CD
					WITH UR
			  		);

*SASDOC--------------------------------------------------------------------------
| Get RxClaim Client-Drug Information 
+------------------------------------------------------------------------SASDOC*;
			CREATE TABLE STD_RXCLM_GSTP  AS
	        SELECT * FROM CONNECTION TO DB2
	   		(  SELECT 
					'X' || TRIM(COALESCE(A.CARRIER_ID,'')) || TRIM(COALESCE(A.ACCOUNT_ID,''))
					|| TRIM(COALESCE(A.GROUP_CD,'')) AS TARGET_CLIENT_KEY
					, A.GSTP_GSA_PGMTYP_CD
					, A.CLT_EFF_DT AS EFFECTIVE_DT
					, A.DRG_CLS_SEQ_NB
					, A.DRG_CLS_CATG_TX
					, A.DRG_CLS_CAT_DES_TX AS DRG_CLS_CATG_DESC_TX
					, A.GSTP_GRD_FATH_IN
					, B.GSTP_GPI_CD
			        , CHAR(B.GSTP_GCN_CD) AS GSTP_GCN_CD 
					, CHAR(B.GSTP_DRG_NDC_ID) AS GSTP_DRG_NDC_ID
					, B.DRG_DTW_CD
					, B.GSTP_GPI_NM
					, B.MULTI_SRC_IN
					, B.RXCLAIM_BYP_STP_IN
					, B.QL_BRND_IN
					, B.DRG_LABEL_NM
					, D.GSA_SHT_DSC_TX  AS PROGRAM_TYPE
					FROM &HERCULES..TPMTSK_GSTP_RX_RUL A

					%IF %UPCASE(&STD_IND.) = N %THEN %DO;
					, &HERCULES..TPMTSK_GSTP_RX_DET B
					%END;
					%ELSE %DO;
					, &HERCULES..TGSTP_DRG_CLS_DET B
					%END;

/*					FROM PBATCH.TPMTSK_GSTP_RX_RUL A*/
/*					   , PBATCH.TPMTSK_GSTP_RX_DET B*/
	                   , &HERCULES..VSMINT_GSA_PGMTYP_CD  D
					%IF %UPCASE(&STD_IND.) = N %THEN %DO;
			           , &DB2_TMP..&TABLE_PREFIX._GSTP_CSTM_IN C
			  		%END;

					WHERE A.PROGRAM_ID = &PROGRAM_ID.
			  		AND A.TASK_ID = &TASK_ID.
	
					%IF %UPCASE(&STD_IND.) = N %THEN %DO;
					AND A.GSTP_RXCLM_RUL_ID = B.GSTP_RXCLM_RUL_ID
		  	  		AND A.GSTP_GSA_PGMTYP_CD IN (4)
			  		AND C.SRC_SYS_CD = 'X'
			  		AND C.CARRIER_ID = A.CARRIER_ID
			  		AND C.EFFECTIVE_DT = A.CLT_EFF_DT
			  		%BLANK_OR_EQ_DB2    (VAR=ACCOUNT_ID)
			  		%BLANK_OR_EQ_DB2    (VAR=GROUP_CD)
			  		%END;
			  		%ELSE %DO;
					AND A.CLT_EFF_DT = &IMPL_DT.
					AND A.GSTP_GSA_PGMTYP_CD IN (1,2,3)
					AND A.GSTP_GSA_PGMTYP_CD = B.GSTP_GSA_PGMTYP_CD
					AND A.DRG_CLS_SEQ_NB = B.DRG_CLS_SEQ_NB
					AND B.DRG_CLS_EFF_DT <= CURRENT DATE  
					AND B.DRG_CLS_EXP_DT >= CURRENT DATE  
			  		%END;

				    AND A.DRG_CLS_EFF_DT <= CURRENT DATE  
					AND A.DRG_CLS_EXP_DT >= CURRENT DATE  
					AND B.DRG_EFF_DT <= CURRENT DATE  
					AND B.DRG_EXP_DT >= CURRENT DATE  

					AND A.GSTP_GSA_PGMTYP_CD = D.GSA_PGMTYP_CD				
					WITH UR
			  		);
			  

		 	DISCONNECT FROM DB2;

		QUIT;
%SET_ERROR_FL;

*SASDOC--------------------------------------------------------------------------
| Separate target and prerequisite drugs and create a drug key
+------------------------------------------------------------------------SASDOC*;
DATA STD_GSTP_TARGET (DROP=DRG_CLS_SEQ_NB DRG_CLS_CATG_TX DRG_CLS_CATG_DESC_TX GSTP_GRD_FATH_IN 
                           GSTP_GSA_PGMTYP_CD PROGRAM_TYPE)
     STD_GSTP_PREREQ (DROP=DRG_CLS_SEQ_NB DRG_CLS_CATG_TX DRG_CLS_CATG_DESC_TX GSTP_GRD_FATH_IN 
                           GSTP_GSA_PGMTYP_CD PROGRAM_TYPE)
     STD_GSTP_TARGET_DC (KEEP=TARGET_CLIENT_KEY DRG_CLS_SEQ_NB DRG_CLS_CATG_TX DRG_CLS_CATG_DESC_TX
	 GSTP_GRD_FATH_IN DRUG_KEY GSTP_GSA_PGMTYP_CD PROGRAM_TYPE)
 	 STD_GSTP_PREREQ_DC (KEEP=TARGET_CLIENT_KEY DRG_CLS_SEQ_NB DRG_CLS_CATG_TX DRG_CLS_CATG_DESC_TX
	 GSTP_GRD_FATH_IN DRUG_KEY GSTP_GSA_PGMTYP_CD PROGRAM_TYPE)
    ;
SET STD_QL_GSTP
    STD_RECAP_GSTP
	STD_RXCLM_GSTP
	;
/*	length TARGET_CLIENT_KEY $200;*/
		IF GSTP_GPI_CD NE '0' THEN DO;
		   DRUG_KEY   = 'GPI'||TRIM(GSTP_GPI_CD);
		END;
		ELSE IF GSTP_DRG_NDC_ID NE '0' THEN DO;
		   DRUG_KEY   = 'NDC'||TRIM(COMPRESS(GSTP_DRG_NDC_ID,'.'));
		END;
		ELSE DO;
		   DRUG_KEY   = 'GCN'||TRIM(GSTP_GCN_CD);
		END;

		IF DRG_DTW_CD = 1 THEN DO;
             OUTPUT  STD_GSTP_TARGET;
			 OUTPUT  STD_GSTP_TARGET_DC;
		END;
		ELSE DO;
              OUTPUT STD_GSTP_PREREQ;
			  OUTPUT STD_GSTP_PREREQ_DC;
		END;
RUN;
%SET_ERROR_FL;

PROC SORT DATA = STD_GSTP_TARGET NODUPKEY; BY TARGET_CLIENT_KEY DRUG_KEY;
RUN;
%SET_ERROR_FL;
PROC SORT DATA = STD_GSTP_PREREQ NODUPKEY; BY TARGET_CLIENT_KEY DRUG_KEY;
RUN;
%SET_ERROR_FL;

PROC SORT DATA = STD_GSTP_TARGET_DC NODUPKEY; BY TARGET_CLIENT_KEY DRUG_KEY DRG_CLS_SEQ_NB;
RUN;
%SET_ERROR_FL;
PROC SORT DATA = STD_GSTP_PREREQ_DC NODUPKEY; BY TARGET_CLIENT_KEY DRUG_KEY DRG_CLS_SEQ_NB;
RUN;
%SET_ERROR_FL;
%MEND;

*SASDOC--------------------------------------------------------------------------
| Get targeting info for client, drug and client-drug link
+------------------------------------------------------------------------SASDOC*;

%MACRO GET_STD_OR_CUSTOM;



%GSTP_RUN_TYPE;

%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  NOTIFICATION OF ABEND",
          EM_MSG="ERROR DETERMINING RUN TYPE.  SEE LOG FILE - &PROGRAM_NAME..LOG FOR INITIATIVE ID &INITIATIVE_ID");



%RESOLVE_CLIENT_GSTP(TBL_NAME_OUT=&ORA_TMP..&TABLE_PREFIX._GSTP_CLT_TGT,STD_IND=&STD_IND.);


%PUT STD_IND = &STD_IND;

%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  NOTIFICATION OF ABEND",
          EM_MSG="ERROR RESOLVING CLIENT.  SEE LOG FILE - &PROGRAM_NAME..LOG FOR INITIATIVE ID &INITIATIVE_ID");


	%GET_NDC_GSTP(DRUG_NDC_TBL=&ORA_TMP..&TABLE_PREFIX._GSTP_DRUG,STD_IND=&STD_IND.);


%PUT STD_IND = &STD_IND;

%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  NOTIFICATION OF ABEND",
          EM_MSG="ERROR RESOLVING DRUGS.  SEE LOG FILE - &PROGRAM_NAME..LOG FOR INITIATIVE ID &INITIATIVE_ID");


%GET_CLIENT_DRUG_LINK(STD_IND=&STD_IND.);
%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  NOTIFICATION OF ABEND",
          EM_MSG="ERROR IN CLIENT DRUG LINK.  SEE LOG FILE - &PROGRAM_NAME..LOG FOR INITIATIVE ID &INITIATIVE_ID");


%PUT STD_IND = &STD_IND;

%MEND;

%GET_STD_OR_CUSTOM;


*SASDOC-------------------------------------------------------------------------- 
| Get claims for targetted drugs
+------------------------------------------------------------------------SASDOC*;


PROC SQL;
  CONNECT TO ORACLE(PATH=&GOLD PRESERVE_COMMENTS);
  CREATE TABLE CLAIMS_NEW2  AS
  SELECT * FROM CONNECTION TO ORACLE	(

SELECT %bquote(/)%bquote(*) + ORDERED use_hash(claim) full(claim) use_hash(algn) full(algn) use_hash(prctr) full(prctr) use_hash(phmcy) full(phmcy)  %bquote(*)%bquote(/)
  CASE
  WHEN ALGN.SRC_SYS_CD ='R' THEN ALGN.RPT_OPT1_CD
  WHEN ALGN.SRC_SYS_CD ='X' THEN ALGN.EXTNL_LVL_ID1
  WHEN ALGN.SRC_SYS_CD ='Q' THEN ALGN.EXTNL_LVL_ID1 END AS CLIENT_LEVEL_1
  ,ALGN.ALGN_LVL_GID_KEY AS ALGN_LVL_GID_CLM
  ,PRCTR.PRCTR_GID 
  ,PRCTR.QL_PRSCR_ID
  ,PRCTR.PRCTR_NPI_ID                  AS NPI
  ,SUBSTR(PRCTR.PRCTR_ID,1,9)          AS DOC_ID
  ,SUBSTR(PRCTR.ADDR_CITY,1,20)        AS D_CITY
  ,PRCTR.DEGR_1_CD                     AS DEGREE
  ,PRCTR.PRCTR_FRST_NM                 AS D_FIRST
  ,PRCTR.PRCTR_LAST_NM                 AS D_LAST
  ,PRCTR.SITE_COMM_1_NB                AS D_PHONE
  ,PRCTR.SPCLT_1_CD                    AS D_SPEC
  ,PRCTR.ADDR_STATE_CD                 AS D_STATE
  ,PRCTR.ADDR_LINE1_TXT                AS D_ADD1
  ,PRCTR.ADDR_LINE2_TXT                AS D_ADD2
  ,SUBSTR(PRCTR.ADDR_ZIP_CD,1,5)||PRCTR.ADDR_ZIP_CD_PLUS AS D_ZIP
  ,PRCTR.TERM_REAS_CD                 AS PROV_INT
  ,PRCTR.ENTITY_IND                    AS PROV_INST
  ,PRCTR.REC_SRC_FLG                   AS PROV_SRC_FLG
  ,PRCTR.PRCTR_ID_TYP_CD               AS PROV_TYP_CD
  ,PRCTR.REC_SRC_NM                    AS PROV_REC_SRC_NM   
  ,MBR.RPT_MBR_ID                      AS MBR
  ,DWCORP.SAS_DAYS(CLAIM.PTNT_BRTH_DT) AS M_DOB
   ,GREATEST(CLAIM.QL_CPG_ID*1,0)       AS QL_CPG_ID_CLM
  ,CLAIM.EXTNL_CLAIM_ID                AS DOC_NB
  ,CLAIM.EXTNL_CLAIM_SEQ_NBR           AS DOC_NB_SEQ
  ,DWCORP.SAS_DAYS(CLAIM.DSPND_DATE)   AS DISP_DT
		  	,CLAIM.UNIT_QTY                      AS DISPENSED_QY 
  			,CLAIM.DAYS_SPLY                     AS DAY_SUPPLY_QY
  ,FLOOR(MONTHS_BETWEEN(CLAIM.DSPND_DATE,CLAIM.PTNT_BRTH_DT)/12) AS AGE
  			,CLAIM.RX_NBR                        AS RX_NB
  ,CLAIM.PHMCY_GID                     AS PHMCY_GID
  ,DRUG.DRUG_GID       
  ,DRUG.NDC      
  ,DRUG.LABEL_NAME             
  ,DRUG.GEN_CODE                 
  ,DRUG.GPI_CODE 
  ,DRUG.GCN_CODE
  ,DRUG.DRUG_NAME           
  ,DRUG.GPI_NAME                 
  ,DRUG.RECAP_GNRC_FLAG         
  ,DRUG.MS_GNRC_FLAG             
  ,DRUG.QL_DRUG_MULTI_SRC_IN     
  ,DRUG.MS_SS_CD                
  ,DRUG.MDDB_MS_SS_CD            
  ,DRUG.DRUG_KEY  
  ,DRUG.QL_DRUG_ABBR_PROD_NM AS DRUG_ABBR_PROD_NM
  ,DRUG.QL_DRUG_ABBR_DSG_NM  AS DRUG_ABBR_DSG_NM
  ,DRUG.QL_DRUG_ABBR_STRG_NM AS DRUG_ABBR_STRG_NM
  ,CLAIM.MAIL_ORDR_CODE
  ,CLAIM.QL_DLVRY_SYSTM_CD
  ,CASE WHEN PHMCY.PHMCY_GID IN
    (18557,454004,30570,83877,166487,62166,76751,146897,454867,66657)
        OR substr(PHMCY.NABP_CODE_6,1,6) in 
('147389', '100229', '146603', '032691', '482663',
 '458303', '459822', '012929', '398095', '032664')
      THEN 1  ELSE 0 END         AS CMX_MS,


  MBR.MBR_ID, 
  CAST(PHMCY.PHMCY_DSPNS_TYPE AS INT) AS LAST_DELIVERY_SYS,
  SUBSTR(CLAIM.DSPND_DATE, 1, 10) AS LAST_FILL_DT,
  CASE WHEN DRUG.RECAP_GNRC_FLAG = '2' OR DRUG.MDDB_MS_SS_CD IN ('M','O','N') 
       THEN 'B'
       ELSE 'G'
  END AS BRAND_GENERIC,
  PHMCY.PHMCY_NAME AS PHARMACY_NM,
  CAST(CLAIM.NEW_REFIL_CODE AS INT) AS REFILL_FILL_QY,
  PRCTR.PRCTR_NPI_ID as PRESCRIBER_NPI_NB,
  CLAIM.FRMLY_GID

 FROM   &ORA_TMP..&TABLE_PREFIX._GSTP_DRUG          DRUG,
  		&DSS_CLIN..V_CLAIM_CORE_PAID          CLAIM,
		&DSS_CLIN..V_ALGN_LVL_DENORM  ALGN,
  		&DSS_CLIN..V_PRCTR_DENORM             PRCTR,
  		&DSS_CLIN..V_PHMCY_DENORM             PHMCY,
  		&DSS_CLIN..V_MBR                      MBR,
    	&ORA_TMP..&TABLE_PREFIX._GSTP_LVL1 CLNT
	

WHERE CLNT.SYS_CD = ALGN.SRC_SYS_CD
	  AND ( (CLNT.SYS_CD ='R' AND ALGN.RPT_OPT1_CD = CLNT.RPT_OPT1_CD) OR
      (CLNT.SYS_CD IN ('Q','X') AND ALGN.EXTNL_LVL_ID1 = CLNT.EXTNL_LVL_ID1))
      AND CLAIM.DSPND_DATE BETWEEN TO_DATE(&BDATE,'YYYY-MM-DD') AND TO_DATE(&EDATE,'YYYY-MM-DD')
      AND (CLAIM.MBR_SUFFX_FLG = 'Y' OR CLAIM.MBR_SUFFX_FLG IS NULL)
      AND CLAIM.MBR_GID = MBR.MBR_GID
  	  AND CLAIM.PAYER_ID = MBR.PAYER_ID
      AND CLAIM.DRUG_GID = DRUG.DRUG_GID
      AND CLAIM.ALGN_LVL_GID = ALGN.ALGN_LVL_GID_KEY
 	  AND CLAIM.PRCTR_GID=PRCTR.PRCTR_GID
      AND ALGN.PAYER_ID = MBR.PAYER_ID
 	  AND CLAIM.PHMCY_GID = PHMCY.PHMCY_GID
);
QUIT;



/*YM:Oct02,2012 New table  created  to add FORMULARY_TX for add base column.*/
		PROC SQL;
			 CREATE TABLE CLAIMS AS
			      SELECT CLAIMS.* 
					 ,FRMLY.FRMLY_NB AS FORMULARY_TX 
					 ,CASE WHEN SUBSTR(PRCTR.PRCTR_ID,1,1) NOT IN
						   ('1','2','3','4','5','6','7','8','9','0') AND
						   SUBSTR(PRCTR.PRCTR_ID,2,1) NOT IN
						   ('1','2','3','4','5','6','7','8','9','0')
						   THEN PRCTR.PRCTR_ID
						   ELSE ' '
					       END AS DEA_NB
					 FROM   CLAIMS_NEW2 CLAIMS
				LEFT JOIN &DSS_CLIN..V_FRMLY_HDR FRMLY 
				     ON  CLAIMS.FRMLY_GID = FRMLY.FRMLY_GID
															/*YM:Oct02,2012 New table  created  to add DEA_NB for add base column.*/   
				LEFT JOIN &DSS_CLIN..V_PRCTR_DENORM PRCTR
					ON CLAIMS.PRESCRIBER_NPI_NB = PRCTR.PRCTR_NPI_ID
					AND PRCTR.PRCTR_ID_TYP_CD ='DH'
					AND PRCTR.PRCTR_ID <> PRCTR.PRCTR_NPI_ID
					AND PRCTR.PRCTR_GID = CLAIMS.PRCTR_GID;
		QUIT;


%SET_ERROR_FL;


DATA OUT.CLAIMS;
SET CLAIMS;
RUN;




%SET_ERROR_FL;

%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  NOTIFICATION OF ABEND",
          EM_MSG="ERROR ON CLAIMS STEP.  SEE LOG FILE - &PROGRAM_NAME..LOG FOR INITIATIVE ID &INITIATIVE_ID");


*SASDOC--------------------------------------------------------------------------
| Get claims for targetted drugs - end
+------------------------------------------------------------------------SASDOC*;

/*DATA CLAIMS;*/
/*SET OUT.CLAIMS;*/
/*RUN;*/






*SASDOC--------------------------------------------------------------------------
| Get the latest drug by fill date
+------------------------------------------------------------------------SASDOC*;

PROC SORT DATA=CLAIMS;
  BY PHMCY_GID RX_NB DISP_DT DRUG_KEY NDC
     DESCENDING DOC_NB DESCENDING DOC_NB_SEQ;
RUN;
%SET_ERROR_FL;

DATA CLAIMS_2 
/*  (DROP=OPT1 LVL1 LVL2 LVL3)*/
;
 FORMAT M_DOB YYMMDD10.;

  SET CLAIMS;   
  BY PHMCY_GID RX_NB DISP_DT DRUG_KEY  NDC
     DESCENDING DOC_NB DESCENDING DOC_NB_SEQ;
  IF FIRST.NDC;  

   IF (D_ADD1 NE '  ' AND
      D_CITY NE '  ' AND
	  D_STATE NE '  ' AND
	  D_ZIP NE '  ' AND
	  PROV_INT = '  ' AND
	  PROV_INST ='1'  AND 
	  PROV_SRC_FLG=0 AND
      PROV_TYP_CD IN ('NP','DH','FW') AND 
      DEGREE IN (&DEGREE)) 
	  AND NPI NE '  '
     THEN PHYS_MAIL_FLAG=1;ELSE PHYS_MAIL_FLAG=0;
 
   IF (
	  PROV_INT = '  ' AND
	  PROV_INST ='1'  AND 
	  PROV_SRC_FLG=0 AND
      PROV_TYP_CD IN ('NP','DH','FW') AND 
      DEGREE IN (&DEGREE)) 
	  AND NPI NE '  '
     THEN PHYS_MAIL_FLAG_2=1;ELSE PHYS_MAIL_FLAG_2=0;

RUN;
%SET_ERROR_FL;

*SASDOC--------------------------------------------------------------------------
| Get eligible members
+------------------------------------------------------------------------SASDOC*;

PROC SQL;
  CONNECT TO ORACLE(PATH=&GOLD );
  CREATE TABLE ELIG  AS
    SELECT * FROM CONNECTION TO ORACLE(
      SELECT  
   DISTINCT
   CASE
  WHEN ALGN.SRC_SYS_CD ='R' THEN ALGN.RPT_OPT1_CD
  WHEN ALGN.SRC_SYS_CD ='X' THEN ALGN.EXTNL_LVL_ID1
    WHEN ALGN.SRC_SYS_CD ='Q' THEN ALGN.EXTNL_LVL_ID1       
  END AS CLIENT_LEVEL_1
  ,ALGN.ALGN_LVL_GID_KEY 
  ,ALGN.RPT_OPT1_CD      AS OPT1
  ,ALGN.EXTNL_LVL_ID1    AS LVL1
  ,ALGN.EXTNL_LVL_ID2    AS LVL2
  ,ALGN.EXTNL_LVL_ID3    AS LVL3
  ,ALGN.PAYER_ID
  ,ALGN.CUST_NM
  ,ALGN.SRC_SYS_CD       AS SYS_CD
  ,ALGN.INSURANCE_CD
  ,ALGN.CARRIER_ID
  ,ALGN.ACCOUNT_ID
  ,ALGN.GROUP_CD
  ,ALGN.QL_CLIENT_ID
  ,GREATEST(ELIG.QL_CPG_ID*1,0)       AS QL_CPG_ID
  ,MBR.RPT_MBR_ID                      AS MBR
  ,MBR.QL_BNFCY_ID      
  ,MBR.MBR_GID                         AS MBR_GID
  ,MBR.SRC_MBR_GNDR_CD                 AS M_SEX
  ,MBR.MBR_FIRST_NM                    AS M_FIRST
  ,MBR.MBR_LAST_NM                     AS M_LAST
  ,MBR.MBR_MDL_NM                      AS M_MI
  ,MBR.MBR_REUSE_RISK_FLG
  ,MBR.MBR_REUSE_LAST_UPDT_DT
  ,SUBSTR(MBR.ADDR_ZIP_CD,1,5)
                                      AS M_ZIP
  ,MBR.ADDR_LINE1_TXT                  AS M_ADDRESS1
  ,MBR.ADDR_LINE2_TXT                  AS M_ADDRESS2
  ,MBR.ADDR_CITY_NM                    AS M_CITY
  ,MBR.ADDR_ST_CD                       AS M_STATE
  ,MBR.MBR_TLPHN_NB                    AS MBR_PHONE
 FROM 
  &ORA_TMP..&TABLE_PREFIX._GSTP_CLT_TGT1         ALGN,
  &DSS_CLIN..V_MBR_ELIG_ACTIVE         ELIG,
  &DSS_CLIN..V_MBR                     MBR


WHERE 
       ALGN.SRC_SYS_CD=ELIG.SRC_SYS_CD
  AND ELIG.ALGN_LVL_GID = ALGN.ALGN_LVL_GID_KEY
  AND ELIG.PAYER_ID = ALGN.PAYER_ID
  AND (TO_DATE(&CURDATE,'YYYY-MM-DD') BETWEEN ELIG.ELIG_EFF_DT
  AND ELIG.ELIG_END_DT)
 AND ELIG.MBR_GID = MBR.MBR_GID
 AND ELIG.PAYER_ID = MBR.PAYER_ID

);
QUIT;
%SET_ERROR_FL;


DATA OUT.ELIG;
SET ELIG;
RUN;
%SET_ERROR_FL;

%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  NOTIFICATION OF ABEND",
          EM_MSG="ERROR ON ELIG STEP.  SEE LOG FILE - &PROGRAM_NAME..LOG FOR INITIATIVE ID &INITIATIVE_ID");



*SASDOC--------------------------------------------------------------------------
| For restart - COMMENT OUT
+------------------------------------------------------------------------SASDOC*;
/*DATA ELIG;*/
/*SET OUT.ELIG;*/
/*RUN;*/
*SASDOC--------------------------------------------------------------------------
| Get the only QL CPG IDs we need
+-------------------------------------------------------------n-----------SASDOC*;
DATA ELIG;
SET ELIG; 
IF QL_CPG_ID = . OR SYS_CD IN ('R','X') THEN QL_CPG_ID = 0;
RUN;

PROC SORT DATA = ELIG; BY ALGN_LVL_GID_KEY QL_CPG_ID;
RUN;

DATA ELIG;
MERGE ELIG     (IN=A)
      CPG_DATA (IN=B)
	  ;
BY ALGN_LVL_GID_KEY QL_CPG_ID;
IF A=1 and B=1 THEN OUTPUT;
RUN;

/*%SET_ERROR_FL;*/
*SASDOC--------------------------------------------------------------------------
| Narrow down claims to only include ones for eligible members
+------------------------------------------------------------------------SASDOC*;
PROC SORT DATA=CLAIMS_2;
BY CLIENT_LEVEL_1 MBR ;
RUN;
%SET_ERROR_FL;

PROC SORT NODUPKEY DATA=ELIG;
BY CLIENT_LEVEL_1 MBR ;
RUN;
%SET_ERROR_FL;

DATA CLAIMS_3;
FORMAT M_DOB YYMMDD10.;
LENGTH CLIENT_LEVEL_1 CLIENT_LEVEL_2 CLIENT_LEVEL_3 $21.;
MERGE CLAIMS_2(IN=A) ELIG(IN=B);
BY CLIENT_LEVEL_1 MBR ;
IF A AND B THEN DO;
IF SYS_CD='R' THEN DO;
    CLIENT_LEVEL_1=OPT1;
	CLIENT_LEVEL_2=LVL1;
    CLIENT_LEVEL_3=LVL3;
	  IF MAIL_ORDR_CODE = 'Y' THEN DELIVERY_CD = 2;
  		ELSE IF MAIL_ORDR_CODE = 'N' THEN DELIVERY_CD = 3;

   END;ELSE IF SYS_CD='X' THEN DO;
    CLIENT_LEVEL_1=LVL1;
	CLIENT_LEVEL_2=LVL2;
    CLIENT_LEVEL_3=LVL3;
   
	IF CMX_MS = 1 THEN DELIVERY_CD = 2;
	ELSE DELIVERY_CD = 3;
   END;ELSE DO;
   CLIENT_LEVEL_1=OPT1;
   CLIENT_LEVEL_2=LVL2;
   CLIENT_LEVEL_3=LEFT(PUT(QL_CPG_ID,20.));

		IF QL_DLVRY_SYSTM_CD NE '' THEN DELIVERY_CD = INPUT(QL_DLVRY_SYSTM_CD,1.);
		ELSE DO;
			  IF MAIL_ORDR_CODE = 'Y' THEN DELIVERY_CD = 2;
  			  ELSE IF MAIL_ORDR_CODE = 'N' THEN DELIVERY_CD = 3;
		END;

   END;

 IF MBR_REUSE_RISK_FLG = 'Y' AND DISP_DT <= MBR_REUSE_LAST_UPDT_DT THEN DELETE;
  IF (M_ADDRESS1 NE '  ' AND
      M_CITY NE '  ' AND
	  M_STATE NE '  ' AND
      M_ZIP NE '  ' AND
      M_LAST NE '  ') THEN MBR_MAIL_FLAG=1;ELSE MBR_MAIL_FLAG=0; 
  OUTPUT CLAIMS_3;
  END;

RUN;

%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  NOTIFICATION OF ABEND",
          EM_MSG="ERROR ON CLAIMS ELIG MERGE.  SEE LOG FILE - &PROGRAM_NAME..LOG FOR INITIATIVE ID &INITIATIVE_ID");



*SASDOC--------------------------------------------------------------------------
| Narrow down claims using client-drug link
+------------------------------------------------------------------------SASDOC*;
PROC SORT DATA = CLAIMS_3; BY TARGET_CLIENT_KEY DRUG_KEY;
RUN;
%SET_ERROR_FL;



DATA CLAIMS_4;
MERGE CLAIMS_3 (IN=A)
      STD_GSTP_TARGET (IN=B)
	  ; BY TARGET_CLIENT_KEY DRUG_KEY;
IF A=1 AND B=1 THEN OUTPUT;
RUN;
%SET_ERROR_FL;


*SASDOC--------------------------------------------------------------------------
| Get MBR_GIDs for the prerequisite claims query
+------------------------------------------------------------------------SASDOC*;
DATA MBR_IDS_ONLY (KEEP= MBR TARGET_CLIENT_KEY PAYER_ID);
SET CLAIMS_4;
RUN;
%SET_ERROR_FL;
DATA MEDS_PRE;
SET MEDS;
IF DRG_DTW_CD = 2 THEN OUTPUT;
RUN;
%SET_ERROR_FL;

PROC SORT DATA = MEDS_PRE; BY DRUG_KEY;
RUN;
%SET_ERROR_FL;

*SASDOC--------------------------------------------------------------------------
| Get DRUG_GIDs for the prerequisite claims query
+------------------------------------------------------------------------SASDOC*;

PROC SORT DATA = STD_GSTP_PREREQ OUT=ALL_PREREQ NODUPKEY; BY DRUG_KEY;
RUN;
%SET_ERROR_FL;


DATA DRUG_GIDS_ONLY (KEEP=DRUG_GID DRUG_KEY);
MERGE MEDS_PRE (IN=A)
      ALL_PREREQ (IN=B)
	  ;
	  BY DRUG_KEY;
	  IF B=1 THEN OUTPUT DRUG_GIDS_ONLY;
RUN;
%SET_ERROR_FL;

PROC SORT DATA = MBR_IDS_ONLY NODUPKEY;
BY MBR TARGET_CLIENT_KEY;
RUN;
PROC SORT DATA = DRUG_GIDS_ONLY NODUPKEY;
BY DRUG_GID DRUG_KEY;
RUN;
%SET_ERROR_FL;
*SASDOC--------------------------------------------------------------------------
| Create and populate mbr and drug tables for preprequisite claims query
+------------------------------------------------------------------------SASDOC*;
%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._GSTP_PR_MBR_ID); 
%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._GSTP_PR_DRUG_GID); 

			PROC SQL NOPRINT;
					CONNECT TO ORACLE(PATH=&GOLD );
		  			EXECUTE 
					(
					CREATE TABLE &ORA_TMP..&TABLE_PREFIX._GSTP_PR_MBR_ID
					(
					 RPT_MBR_ID                 VARCHAR2(25)
					,TARGET_CLIENT_KEY          VARCHAR2(200)
					,PAYER_ID                   NUMBER
					)
		  			) BY ORACLE;

						EXECUTE 
					(
					CREATE TABLE &ORA_TMP..&TABLE_PREFIX._GSTP_PR_DRUG_GID
					(DRUG_GID                    NUMBER
/*					,DRG_CLS_SEQ_NB              NUMBER*/
					,DRUG_KEY                    VARCHAR2(20)
					)
		  			) BY ORACLE;
		    		DISCONNECT FROM ORACLE;
				QUIT;
				RUN;
%SET_ERROR_FL;
				PROC SQL;
				INSERT INTO &ORA_TMP..&TABLE_PREFIX._GSTP_PR_MBR_ID
				SELECT MBR, TARGET_CLIENT_KEY, PAYER_ID       
                FROM MBR_IDS_ONLY;
				QUIT;
				RUN;
%SET_ERROR_FL;
				PROC SQL;
				INSERT INTO &ORA_TMP..&TABLE_PREFIX._GSTP_PR_DRUG_GID
				SELECT DRUG_GID, DRUG_KEY          
                FROM DRUG_GIDS_ONLY;
				QUIT;
				RUN;
%SET_ERROR_FL;

*SASDOC--------------------------------------------------------------------------
| Create indexes and run runstats on mbr and drug temp table
+------------------------------------------------------------------------SASDOC*;
PROC SQL;
 CONNECT TO ORACLE(PATH=&GOLD );
  EXECUTE (
    CREATE INDEX &ORA_TMP..&TABLE_PREFIX._GSTP_PR_MBR_ID_I1
    ON &ORA_TMP..&TABLE_PREFIX._GSTP_PR_MBR_ID(RPT_MBR_ID,PAYER_ID)
	)
  BY ORACLE;

    EXECUTE (
    CREATE INDEX &ORA_TMP..&TABLE_PREFIX._GSTP_PR_DRUG_GID_I1
    ON &ORA_TMP..&TABLE_PREFIX._GSTP_PR_DRUG_GID(DRUG_GID)
	)
  BY ORACLE;

  DISCONNECT FROM ORACLE;
QUIT;
%SET_ERROR_FL;


DATA _NULL_;
TICK = "'";
COMMA=",";
DB_ID = TRIM(LEFT("&ORA_TMP."));
TBL_NM1 = TRIM(LEFT("&TABLE_PREFIX._GSTP_PR_MBR_ID"));
TBL_NM2 = TRIM(LEFT("&TABLE_PREFIX._GSTP_PR_DRUG_GID"));
CALL SYMPUT('ORA_STR1',TICK||LEFT(TRIM(DB_ID))||TICK||COMMA);
CALL SYMPUT('ORA_STR2',TICK||LEFT(TRIM(TBL_NM1))||TICK);
CALL SYMPUT('ORA_STR3',TICK||LEFT(TRIM(TBL_NM2))||TICK);
RUN;

%SET_ERROR_FL;
RUN;

DATA _NULL_;
CALL SYMPUT('ORA_STRB1',TRIM(LEFT("&ORA_STR1"))||TRIM(LEFT("&ORA_STR2")));
CALL SYMPUT('ORA_STRB2',TRIM(LEFT("&ORA_STR1"))||TRIM(LEFT("&ORA_STR3")));
RUN;
%SET_ERROR_FL;

PROC SQL;
  CONNECT TO ORACLE(PATH=&GOLD );
EXECUTE(EXEC DBMS_STATS.GATHER_TABLE_STATS(&ORA_STRB1.)) BY ORACLE;
EXECUTE(EXEC DBMS_STATS.GATHER_TABLE_STATS(&ORA_STRB2.)) BY ORACLE;
DISCONNECT FROM ORACLE;
 QUIT;
RUN;
%SET_ERROR_FL;


*SASDOC--------------------------------------------------------------------------
| Get members taking prerequisite drugs
+------------------------------------------------------------------------SASDOC*;
PROC SQL;
  CONNECT TO ORACLE(PATH=&GOLD preserve_comments);
  CREATE TABLE MBREXCL  AS
    SELECT * FROM CONNECTION TO ORACLE(

SELECT /*+ parallel(a,8) */
      A.MBR, A.TARGET_CLIENT_KEY, A.DRUG_KEY,SUM (A.DAYS_SPLY_CNT) AS DAYS_SUM
  FROM
  (
  SELECT /*+ ordered full(pre)  full(drug)  
             parallel(drug,8) parallel(claim,8) parallel(pre,8) parallel (mbr,8)
             use_hash (drug) use_hash (claim) use_hash (pre) use_hash (mbr)
             pq_distribute(drug,hash,hash) pq_distribute(claim,hash,hash) 
             pq_distribute(pre,hash,hash) pq_distribute(mbr,hash,hash) */
        MBR.RPT_MBR_ID AS MBR,
           PRE.TARGET_CLIENT_KEY,
           DRUG.DRUG_KEY,
           CLAIM.DAYS_SPLY_CNT
    FROM   &ORA_TMP..&TABLE_PREFIX._GSTP_PR_MBR_ID         PRE,
                    DWCORP.T_MBR                           MBR,
                dwcorp.t_claim_core               claim,
             &ORA_TMP..&TABLE_PREFIX._GSTP_PR_DRUG_GID          DRUG
       
   WHERE   CLAIM.payer_id NOT IN (680201, 201, 2072701)
           AND CLAIM.claim_wshd_cd IN ('P', 'L')
           AND CLAIM.claim_type_nb = 1
           AND CLAIM.SRC_SYS_CD = MBR.SRC_SYS_CD
    	   AND (CLAIM.DSPND_DT BETWEEN TO_DATE(&BDATE_EXCL,'YYYY-MM-DD')
      				AND TO_DATE(&EDATE,'YYYY-MM-DD'))
           AND CLAIM.MBR_GID = MBR.MBR_GID
           AND CLAIM.PAYER_ID = MBR.PAYER_ID
           AND PRE.RPT_MBR_ID = MBR.RPT_MBR_ID
           AND PRE.PAYER_ID = MBR.PAYER_ID
           AND MBR.payer_id NOT IN (680201, 201, 2072701, 4000036)
           AND CLAIM.DRUG_GID = DRUG.DRUG_GID) A
GROUP BY   A.MBR, A.TARGET_CLIENT_KEY, A.DRUG_KEY

);
QUIT;
%SET_ERROR_FL;


DATA OUT.MBREXCL;
SET MBREXCL;
RUN;
%SET_ERROR_FL;


%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  NOTIFICATION OF ABEND",
          EM_MSG="ERROR ON PREREQ CLAIM QRY.  SEE LOG FILE - &PROGRAM_NAME..LOG FOR INITIATIVE ID &INITIATIVE_ID");


/*DATA MBREXCL;*/
/*SET OUT.MBREXCL;*/
/*RUN;*/

PROC SORT DATA = MBREXCL; BY TARGET_CLIENT_KEY DRUG_KEY;
RUN;
%SET_ERROR_FL;

*SASDOC--------------------------------------------------------------------------
| Narrow down members taking prerequisite drugs by applying client-drug link
+------------------------------------------------------------------------SASDOC*;
DATA MBREXCL;
MERGE MBREXCL (IN=A)
      STD_GSTP_PREREQ (IN=B)
	  ; BY TARGET_CLIENT_KEY DRUG_KEY;
IF A=1 AND B=1 THEN OUTPUT;
RUN;
%SET_ERROR_FL;
*SASDOC--------------------------------------------------------------------------
| Apply Drug Class - PREREQUISITES
+------------------------------------------------------------------------SASDOC*;

PROC SQL;
     CREATE TABLE MBREXCL1 AS
	 SELECT A.TARGET_CLIENT_KEY
	      , A.MBR
		  , A.DRUG_KEY
		  , A.DAYS_SUM 
		  , B.DRG_CLS_SEQ_NB

	 FROM MBREXCL  A
	 , STD_GSTP_PREREQ_DC         B

	 WHERE A.TARGET_CLIENT_KEY = B.TARGET_CLIENT_KEY
	   AND A.DRUG_KEY          = B.DRUG_KEY
			 ;
QUIT;
%SET_ERROR_FL;

*SASDOC--------------------------------------------------------------------------
| Narrow down members taking prerequisite drugs by only including day supply over 
| 30 days
+------------------------------------------------------------------------SASDOC*;
PROC SQL;
CREATE TABLE MBREXCL_SUMMARY AS
SELECT A.TARGET_CLIENT_KEY, A.DRG_CLS_SEQ_NB,A.MBR,SUM(DAYS_SUM) AS DAYSSUM
FROM MBREXCL1 A
GROUP BY TARGET_CLIENT_KEY,DRG_CLS_SEQ_NB,MBR
HAVING SUM(DAYS_SUM)>=30
ORDER BY TARGET_CLIENT_KEY,DRG_CLS_SEQ_NB,MBR;
QUIT;
%SET_ERROR_FL;

*SASDOC--------------------------------------------------------------------------
| Apply Drug Class - TARGET CLAIMS
+------------------------------------------------------------------------SASDOC*;

PROC SQL;
CREATE TABLE CLAIMS_4A AS 
SELECT 
  A.ALGN_LVL_GID_KEY
, A.OPT1
, A.CLIENT_LEVEL_1
, A.CLIENT_LEVEL_2
, A.CLIENT_LEVEL_3
, A.PAYER_ID
, A.CUST_NM
, A.SYS_CD
, A.INSURANCE_CD
, A.CARRIER_ID
, A.ACCOUNT_ID
, A.GROUP_CD
, A.QL_CPG_ID
, A.QL_CLIENT_ID
, A.QL_GROUP_CLASS_CD
, A.QL_GROUP_CLASS_SEQ_NB
, A.QL_BLG_REPORTING_CD
, A.QL_PLAN_NM
, A.QL_PLAN_CD
, A.QL_PLAN_EXT_CD
, A.QL_GROUP_CD
, A.QL_GROUP_EXT_CD
, A.TARGET_CLIENT_KEY
, A.OVR_CLIENT_NM
, A.QL_BNFCY_ID
, A.PRCTR_GID
, A.QL_PRSCR_ID
, A.NPI
, A.DOC_ID
, A.D_CITY
, A.DEGREE
, A.D_FIRST
, A.D_LAST
, A.D_PHONE
, A.D_SPEC
, A.D_STATE
, A.D_ADD1
, A.D_ADD2
, A.D_ZIP
, A.PROV_INT
, A.PROV_INST
, A.PROV_SRC_FLG
, A.PROV_TYP_CD
, A.PROV_REC_SRC_NM
, A.MBR
, A.MBR_GID
, A.M_SEX
, A.M_FIRST
, A.M_LAST
, A.M_MI
, A.M_ZIP
, A.M_ADDRESS1
, A.M_ADDRESS2
, A.M_CITY
, A.M_STATE
, A.MBR_PHONE
, A.M_DOB
, A.QL_CPG_ID_CLM
, A.DOC_NB
, A.DOC_NB_SEQ
, A.DISP_DT
, A.DISPENSED_QY
, A.DAY_SUPPLY_QY
, A.AGE
, A.RX_NB
, A.PHMCY_GID
, A.DRUG_GID
, A.NDC
, A.LABEL_NAME
, A.GEN_CODE
, A.GPI_CODE
, A.GCN_CODE
, A.DRUG_NAME
, A.GPI_NAME
, A.RECAP_GNRC_FLAG
, A.MS_GNRC_FLAG
, A.QL_DRUG_MULTI_SRC_IN
, A.MS_SS_CD
, A.MDDB_MS_SS_CD
, A.DRUG_KEY
, A.DRUG_ABBR_PROD_NM
, A.DRUG_ABBR_DSG_NM
, A.DRUG_ABBR_STRG_NM
, A.DELIVERY_CD
, A.PHYS_MAIL_FLAG
, A.PHYS_MAIL_FLAG_2
, A.MBR_MAIL_FLAG
, A.EFFECTIVE_DT
, A.GSTP_GPI_CD
, A.GSTP_GCN_CD
, A.GSTP_DRG_NDC_ID
, A.DRG_DTW_CD
, A.GSTP_GPI_NM
, A.MULTI_SRC_IN
, A.RXCLAIM_BYP_STP_IN
, A.QL_BRND_IN
, A.DRG_LABEL_NM
, B.DRG_CLS_SEQ_NB
, B.DRG_CLS_CATG_TX
, B.DRG_CLS_CATG_DESC_TX
, B.GSTP_GRD_FATH_IN
, B.GSTP_GSA_PGMTYP_CD 
, B.PROGRAM_TYPE
		/* NEW COLUMNS */
/*, A.MBR_ID  */
/*, A.LAST_DELIVERY_SYS*/
/*, A.LAST_FILL_DT*/
/*, A.DRUG_NDC_ID*/
/*, A.GPI_THERA_CLS_CD*/
, A.BRAND_GENERIC
, A.PHARMACY_NM
, A.REFILL_FILL_QY
/*, A.PRESCRIBER_NPI_NB*/
, A.FRMLY_GID
, A.DEA_NB
, A.FORMULARY_TX 
	 FROM CLAIMS_4  A
	 , STD_GSTP_TARGET_DC     B

	 WHERE A.TARGET_CLIENT_KEY = B.TARGET_CLIENT_KEY
	   AND A.DRUG_KEY          = B.DRUG_KEY
			 ;
QUIT;
%SET_ERROR_FL;

PROC SORT DATA = CLAIMS_4A;
BY TARGET_CLIENT_KEY DRG_CLS_SEQ_NB MBR;
RUN;
%SET_ERROR_FL;

PROC SORT DATA = MBREXCL_SUMMARY NODUPKEY;
BY TARGET_CLIENT_KEY DRG_CLS_SEQ_NB MBR;
RUN;
%SET_ERROR_FL;
*SASDOC--------------------------------------------------------------------------
| Narrow down targetted members by excluding those that took prerequisite meds 
+------------------------------------------------------------------------SASDOC*;
DATA CLAIMS_5;
MERGE CLAIMS_4A (IN=A)
      MBREXCL_SUMMARY (IN=B)
	  ;
BY TARGET_CLIENT_KEY DRG_CLS_SEQ_NB MBR;
IF A AND NOT B;
IF SYS_CD='Q' THEN DO;
   CLIENT_LEVEL_1=LEFT(PUT(QL_CPG_ID,20.));
   CLIENT_LEVEL_2='';
   CLIENT_LEVEL_3='';   
END;
IF      SYS_CD = 'Q' THEN ADJ_CD = 'QL';
ELSE IF SYS_CD = 'X' THEN ADJ_CD = 'RX';
ELSE IF SYS_CD = 'R' THEN ADJ_CD = 'RE';

RUN;
%SET_ERROR_FL;

*SASDOC--------------------------------------------------------------------------
| Get only one claim per drug class 
+------------------------------------------------------------------------SASDOC*;
PROC SORT DATA = CLAIMS_5; BY TARGET_CLIENT_KEY DRG_CLS_SEQ_NB MBR DISP_DT;
RUN;
%SET_ERROR_FL;


DATA FINAL_CLAIMS;
SET CLAIMS_5;
BY TARGET_CLIENT_KEY DRG_CLS_SEQ_NB MBR;
IF LAST.MBR THEN OUTPUT;
RUN;
%SET_ERROR_FL;

*SASDOC--------------------------------------------------------------------------
| Copy of final claims to perm location for testing 
+------------------------------------------------------------------------SASDOC*;
DATA OUT.FINAL_CLAIMS;
SET FINAL_CLAIMS;
RUN;
%SET_ERROR_FL;

%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  NOTIFICATION OF ABEND",
          EM_MSG="ERROR ON CLAIM POST-PROCESSING.  SEE LOG FILE - &PROGRAM_NAME..LOG FOR INITIATIVE ID &INITIATIVE_ID");

/*DATA FINAL_CLAIMS;*/
/*SET OUT.FINAL_CLAIMS;*/
/*RUN;*/

%put &db2_tmp;
/*Final file create */

%DROP_DB2_TABLE(TBL_NAME=&db2_tmp..&TABLE_PREFIX._GSTP_VENDOR); 

/*%DROP_DB2_TABLE(TBL_NAME=&DB2_TMP..GSTP_VENDOR_PHYS); */
/*%DROP_DB2_TABLE(TBL_NAME=QCPAP020.GSTP_VENDOR_PHYS); */

/*YM:ADD BASE NEW COLUMNS */
 	PROC SQL;
	 CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	    EXECUTE(
    CREATE TABLE &DB2_TMP..&TABLE_PREFIX._GSTP_VENDOR

/*    CREATE TABLE QCPAP020.&TABLE_PREFIX._GSTP_VENDOR*/
		( PT_BENEFICIARY_ID INTEGER
		, NTW_PRESCRIBER_ID INTEGER
,	SUBJECT_ID	INTEGER
,	BNF_LAST_NM	CHAR(30)
,	SBJ_FIRST_NM	CHAR(30)
,	BIRTH_DT	DATE
,	MBR_ID	CHAR(25)
,	GENDER	CHAR(1)
,	AGE	SMALLINT
,   PROGRAM_TYPE CHAR(10)
,	DRG_CLS_CATG_TX	CHAR(50)
,   DRG_CLS_CATG_DESC_TX CHAR(200)
,	BRAND_NAME	CHAR(60)
,	GPI_THERA_CLS_CD	CHAR(14)
,   DRUG_NDC_ID DECIMAL(12,0)
,   GCN_CODE    INTEGER
,	LBL_NAME	CHAR(30)
,	GPI_NAME	CHAR(60)
,   DRUG_ABBR_PROD_NM CHAR(30)
,   DRUG_ABBR_DSG_NM  CHAR(30)
,   DRUG_ABBR_STRG_NM CHAR(30)
,	LAST_FILL_DT	DATE
,	DISPENSED_QY	DECIMAL(13,2)
,	DAY_SUPPLY_QY	INTEGER
,	RX_NB	CHAR(12)
,	CLIENT_ID	INTEGER
,   CLIENT_NM   CHAR(100)
,	PRG_CLIENT_NM	CHAR(100)
,	BLG_REPORTING_CD	CHAR(15)
,	GROUP_CD	CHAR(15)
,	GROUP_CLASS_CD	SMALLINT
,	GROUP_CLASS_SEQ_NB	SMALLINT
,	GROUP_EXT_CD_TX	CHAR(5)
,	PLAN_CD	CHAR(8)
,	PLAN_EXT_CD_TX	CHAR(8)
,	PLAN_NM	CHAR(40)
,	EFFECTIVE_DT  DATE
,   BEGIN_PERIOD  DATE
,   END_PERIOD    DATE
,   INITIATIVE_ID  INTEGER
,   TASK_ID        INTEGER
,   MBR_GID        DECIMAL(15,0)
,   PRCTR_GID      INTEGER
,   ALGN_LVL_GID   INTEGER
,   DRUG_GID       INTEGER
,   QL_CPG_ID      INTEGER
,   MBR_MAIL_FLAG  SMALLINT
,   PHYS_MAIL_FLAG  SMALLINT
,   PRESCRIBER_NPI_NB CHAR(20)
,   PRBR_DEGREE       CHAR(3)
,   PRCBR_LAST_NAME   CHAR(30)
,   PRCBR_FIRST_NM    CHAR(30)
,   PRCBR_SPEC        CHAR(3)
,   ADJ_ENGINE        CHAR(2)
,   CLIENT_LEVEL_1    CHAR(20)
,   CLIENT_LEVEL_2    CHAR(20)
,   CLIENT_LEVEL_3    CHAR(20)
,   TARGET_CLIENT_KEY CHAR(200)
,   PHYS_MAIL_FLAG_2  SMALLINT
,   LTR_RULE_SEQ_NB    SMALLINT
,   LAST_DELIVERY_SYS  SMALLINT
,   BRAND_GENERIC      CHAR(1) /*YM:ADD BASE NEW COLUMNS */
,   PHARMACY_NM        CHAR(60)
,   REFILL_FILL_QY     INTEGER
,   FRMLY_GID          INTEGER
,   DEA_NB             CHAR(20)
,   FORMULARY_TX       CHAR(10)

		) NOT LOGGED INITIALLY) BY DB2;
	 DISCONNECT FROM DB2;
	QUIT;

PROC SQL;
			INSERT INTO &db2_tmp..&TABLE_PREFIX._GSTP_VENDOR
/*			INSERT INTO QCPAP020.&TABLE_PREFIX._GSTP_VENDOR*/
				SELECT  
    QL_BNFCY_ID
,   INPUT(QL_PRSCR_ID,11.)  
,	QL_BNFCY_ID
,	M_LAST
,	M_FIRST
,	M_DOB
,	MBR
,	M_SEX
,	AGE
,   PROGRAM_TYPE
,	DRG_CLS_CATG_TX
,   DRG_CLS_CATG_DESC_TX
,	DRUG_NAME
,	GPI_CODE
,   INPUT(NDC,11.)
,   GCN_CODE
,	LABEL_NAME
,	GPI_NAME
,   DRUG_ABBR_PROD_NM 
,   DRUG_ABBR_DSG_NM 
,   DRUG_ABBR_STRG_NM 
,	DISP_DT
,	DISPENSED_QY
,	DAY_SUPPLY_QY
,	RX_NB
,	QL_CLIENT_ID
,   CUST_NM
,	OVR_CLIENT_NM
,	QL_BLG_REPORTING_CD
,	QL_GROUP_CD
,	QL_GROUP_CLASS_CD
,	QL_GROUP_CLASS_SEQ_NB
,	QL_GROUP_EXT_CD
,	QL_PLAN_CD
,	QL_PLAN_EXT_CD
,	QL_PLAN_NM
,	EFFECTIVE_DT
,   INPUT(&BDATE.,YYMMDD10.)
,   INPUT(&EDATE.,YYMMDD10.)
,   &INITIATIVE_ID.
,   &TASK_ID.
,   MBR_GID
,   PRCTR_GID   
,   ALGN_LVL_GID_KEY  
,   DRUG_GID     
,   QL_CPG_ID
,   MBR_MAIL_FLAG
,   PHYS_MAIL_FLAG
,   NPI
,   DEGREE 
,   D_LAST
,   D_FIRST
,   D_SPEC
,   ADJ_CD
,    CLIENT_LEVEL_1
,   CLIENT_LEVEL_2
,   CLIENT_LEVEL_3
,   TARGET_CLIENT_KEY
,   PHYS_MAIL_FLAG_2
, 0
, DELIVERY_CD
, BRAND_GENERIC  /*YM:ADD BASE NEW COLUMNS */
, PHARMACY_NM
, REFILL_FILL_QY
, FRMLY_GID
, DEA_NB
, FORMULARY_TX  


				FROM FINAL_CLAIMS;
				QUIT;
				RUN;
%SET_ERROR_FL;
*SASDOC--------------------------------------------------------------------------
| Create and populate tables for RE and RX for members with missing QL ID
+------------------------------------------------------------------------SASDOC*;
%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RE); 
%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX); 

			PROC SQL NOPRINT;
					CONNECT TO ORACLE(PATH=&GOLD );
		  			EXECUTE 
					(
					CREATE TABLE &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RE
					(MBR_ID                     VARCHAR2(25)
                    ,MBR_GID                    NUMBER
					,MBR_FIRST_NM               VARCHAR2(40)
					,MBR_LAST_NM                VARCHAR2(40)
					,ADDR_LINE1_TXT             VARCHAR2(60)
					,ADDR_LINE2_TXT             VARCHAR2(60)
					,ADDR_CITY_NM               VARCHAR2(60)
					,ADDR_ST_CD                 VARCHAR2(3)
					,ADDR_ZIP_CD                VARCHAR2(20)
					)
		  			) BY ORACLE;

			  			EXECUTE 
					(
					CREATE TABLE &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX
					(MBR_ID                     VARCHAR2(25)
                    ,MBR_GID                    NUMBER
					,MBR_FIRST_NM               VARCHAR2(40)
					,MBR_LAST_NM                VARCHAR2(40)
					,ADDR_LINE1_TXT             VARCHAR2(60)
					,ADDR_LINE2_TXT             VARCHAR2(60)
					,ADDR_CITY_NM               VARCHAR2(60)
					,ADDR_ST_CD                 VARCHAR2(3)
					,ADDR_ZIP_CD                VARCHAR2(20)
					)
		  			) BY ORACLE;
		    		DISCONNECT FROM ORACLE;
				QUIT;
				RUN;
%SET_ERROR_FL;


				PROC SQL;
				INSERT INTO &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RE
				SELECT MBR, MBR_GID, M_FIRST, M_LAST, M_ADDRESS1, M_ADDRESS2,
                       M_CITY, M_STATE, M_ZIP
                FROM FINAL_CLAIMS
				WHERE ADJ_CD = 'RE';
				QUIT;
				RUN;
%SET_ERROR_FL;


				PROC SQL;
				INSERT INTO &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX
				SELECT MBR, MBR_GID, M_FIRST, M_LAST, M_ADDRESS1, M_ADDRESS2,
                       M_CITY, M_STATE, M_ZIP
                FROM FINAL_CLAIMS
				WHERE ADJ_CD = 'RX';
				QUIT;
				RUN;
%SET_ERROR_FL;
*SASDOC-------------------------------------------------------------------------
| CALL %CREATE_BASE_FILE
+-----------------------------------------------------------------------SASDOC*;

%CREATE_BASE_FILE(TBL_NAME_IN=&db2_tmp..&TABLE_PREFIX._GSTP_VENDOR);

%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  NOTIFICATION OF ABEND",
          EM_MSG="ERROR ON CREATE BASE FILE.  SEE LOG FILE - &PROGRAM_NAME..LOG FOR INITIATIVE ID &INITIATIVE_ID");

OPTIONS MLOGIC MPRINT MPRINTNEST MLOGICNEST SYMBOLGEN;
*SASDOC-------------------------------------------------------------------------
| CALL %CHECK_DOCUMENT TO SEE IF THE STELLENT ID(S) HAVE BEEN ATTACHED.
+-----------------------------------------------------------------------SASDOC*;
%CHECK_DOCUMENT_PROD;

%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  NOTIFICATION OF ABEND",
          EM_MSG="ERROR ON CHECK_DOCUMENT.  SEE LOG FILE - &PROGRAM_NAME..LOG FOR INITIATIVE ID &INITIATIVE_ID");



*SASDOC-------------------------------------------------------------------------
| Reset stellent ids to the appropriate one for the clients with one GSTP type
+-----------------------------------------------------------------------SASDOC*;

DATA WORK.TPHASE_RVR_FILE;
     SET &HERCULES..TPHASE_RVR_FILE(WHERE=(INITIATIVE_ID=&INITIATIVE_ID
                                AND PHASE_SEQ_NB=&PHASE_SEQ_NB));
     KEEP CMCTN_ROLE_CD FILE_ID;
RUN;
%SET_ERROR_FL;

DATA _NULL_;
     SET TPHASE_RVR_FILE END=FILE_END;
     IF FILE_END THEN CALL SYMPUT('N_files', PUT(_n_,1.) );
RUN;
%SET_ERROR_FL;

%let TABLE_PREFIX_LOWCASE = %lowcase(&TABLE_PREFIX.);


%MACRO RESET_APN_CMCTN_ID;

  %DO J = 1 %TO &N_FILES. ;
  
  %PUT SET APN_CMCTN_ID FOR ONE PROGRAM CLIENT FOR THE DATASET: &TABLE_PREFIX_LOWCASE._&J. ;
  
    ** SET VALUES TO THE DATASETS IN THE PENDING DIRECTORY ;
    %IF %SYSFUNC(EXIST(DATA_PND.&TABLE_PREFIX_LOWCASE._&J.)) %THEN %DO;
    
  PROC SQL;

  UPDATE	 DATA_PND.&TABLE_PREFIX_LOWCASE._&J.  A
     SET  APN_CMCTN_ID = ( SELECT APN_CMCTN_ID
	                         FROM ONE_TYPE_APN B
							 WHERE A.TARGET_CLIENT_KEY = B.TARGET_CLIENT_KEY
                              AND  B.LTR_TYPE = %EVAL(&J.))
  	 WHERE EXISTS ( SELECT * FROM ONE_TYPE_APN C
	  				 WHERE A.TARGET_CLIENT_KEY = C.TARGET_CLIENT_KEY
					   AND C.LTR_TYPE = %EVAL(&J.)
	 );
  	QUIT;
	%SET_ERROR_FL;
  
    %END;
    
    ** SET VALUES TO THE DATASETS IN THE RESULTS DIRECTORY ;
    %IF %SYSFUNC(EXIST(DATA_RES.&TABLE_PREFIX_LOWCASE._&J.)) %THEN %DO;
    
     PROC SQL;

  UPDATE	 DATA_RES.&TABLE_PREFIX_LOWCASE._&J.  A
     SET  APN_CMCTN_ID = ( SELECT APN_CMCTN_ID
	                         FROM ONE_TYPE_APN B
							 WHERE A.TARGET_CLIENT_KEY = B.TARGET_CLIENT_KEY
                              AND  B.LTR_TYPE = %EVAL(&J.))
  	 WHERE EXISTS ( SELECT * FROM ONE_TYPE_APN C
	  				 WHERE A.TARGET_CLIENT_KEY = C.TARGET_CLIENT_KEY
					   AND C.LTR_TYPE = %EVAL(&J.)
	 );
  	QUIT;
	%SET_ERROR_FL;
    %END;  
    
  %END; 

%MEND RESET_APN_CMCTN_ID;

%RESET_APN_CMCTN_ID;

*SASDOC-------------------------------------------------------------------------
| Remove invalid provider records
+-----------------------------------------------------------------------SASDOC*;
DATA DATA_PND.&TABLE_PREFIX_LOWCASE._2;
SET  DATA_PND.&TABLE_PREFIX_LOWCASE._2;
IF PHYS_MAIL_FLAG_2 =1 THEN OUTPUT;
RUN;
%SET_ERROR_FL;

DATA DATA_RES.&TABLE_PREFIX_LOWCASE._2;
SET  DATA_RES.&TABLE_PREFIX_LOWCASE._2;
IF PHYS_MAIL_FLAG_2 =1 THEN OUTPUT;
RUN;
%SET_ERROR_FL;

%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  NOTIFICATION OF ABEND",
          EM_MSG="ERROR ON POST-PROCESSING.  SEE LOG FILE - &PROGRAM_NAME..LOG FOR INITIATIVE ID &INITIATIVE_ID");



*SASDOC-------------------------------------------------------------------------
| Check for autorelease of file.
+-----------------------------------------------------------------------SASDOC*;
%autorelease_file(INIT_ID=&INITIATIVE_ID, PHASE_ID=&PHASE_SEQ_NB);
*SASDOC-------------------------------------------------------------------------
| INSERT DISTINCT RECIPIENTS INTO TCMCTN_PENDING IF THE FILE IS NOT AUTORELEASE.
| THE USER WILL RECEIVE AN EMAIL WITH THE INITIATIVE SUMMARY REPORT.  IF THE
| FILE IS AUTORELEASED, %RELEASE_DATA IS CALLED AND NO EMAIL IS GENERATED FROM
| %INSERT_TCMCTN_PENDING.
+-----------------------------------------------------------------------SASDOC*;
%INSERT_TCMCTN_PENDING(INIT_ID=&INITIATIVE_ID, PHASE_ID=&PHASE_SEQ_NB);

%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  NOTIFICATION OF ABEND",
          EM_MSG="ERROR ON COMM HIST.  SEE LOG FILE - &PROGRAM_NAME..LOG FOR INITIATIVE ID &INITIATIVE_ID");


*SASDOC-------------------------------------------------------------------------
| DELETE TEMP TABLES
+-----------------------------------------------------------------------SASDOC*;
%MACRO DELETE_GSTP_TEMP;
%if %eval(&err_fl) = 0 %then %do;
/* %DROP_DB2_TABLE(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._GSTP_CSTM_IN);*/
/* %DROP_DB2_TABLE(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._GSTP_LVL1);*/
/* %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._GSTP_CLT_TGT);*/
/* %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._GSTP_CLT_TGT1);*/
/* %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._GSTP_LVL1);*/
/* %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._GSTP_DRUG);*/
/* %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._GSTP_PR_MBR_ID);*/
/* %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._GSTP_PR_DRUG_GID);*/
/* %DROP_DB2_TABLE(TBL_NAME=&db2_tmp..&TABLE_PREFIX._GSTP_VENDOR);*/
/* %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RE);*/
/* %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX);*/
 %end;
 %MEND;

/*%DELETE_GSTP_TEMP;*/



*SASDOC-------------------------------------------------------------------------
| UPDATE THE JOB COMPLETE TIMESTAMP
+-----------------------------------------------------------------------SASDOC*;
%UPDATE_TASK_TS(JOB_COMPLETE_TS);


