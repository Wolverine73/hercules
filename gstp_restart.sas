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
|
+-----------------------------------------------------------------------HEADER*/


OPTIONS SYSPARM='INITIATIVE_ID=9143 PHASE_SEQ_NB=1';

%SET_SYSMODE;


%include "/PRG/sas&sysmode.1/hercules/hercules_in.sas";

/*OPTIONS FULLSTIMER MPRINT MLOGIC SYMBOLGEN SOURCE2 MPRINTNEST MLOGICNEST;*/
OPTIONS SOURCE
         NOSOURCE2 
         MPRINT
         /*
		 SYMBOLGEN 
         MACROGEN 
		 */
 ;


%LET ERR_FL=0;
%LET PROGRAM_NAME=gstp;

filename parm    "/DATA/sas&sysmode.1/hercules/5295/gstp_custom_parm.csv"; 
filename apn    "/DATA/sas&sysmode.1/hercules/5295/gstp_apn_parm.csv";
libname out "/DATA/sas&sysmode.1/hercules/5295/";

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
/*%LET IMPL_DT=%STR('2011-01-02');*/
/**/
/*%LET BDATE=%STR('2010-06-12');          ***BEGINING DISPENSE DATE***;*/
/**/
/****EXCLUSION MEDS BEGIN DATE - STANDARD IS MOST RECENT 24 MONTHS OF DATA***;*/
/*%LET BDATE_EXCL=%STR('2008-06-12');          ***BEGINING DISPENSE DATE***;*/
/**/
/****CLAIMS INCLUSION AND EXCLUSION END DATE****;*/
/*%LET EDATE=%STR('2010-10-11');*/

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
| Copy of final claims to perm location for testing 
+------------------------------------------------------------------------SASDOC*;
DATA FINAL_CLAIMS;
SET OUT.FINAL_CLAIMS;
RUN;
%SET_ERROR_FL;

%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  NOTIFICATION OF ABEND",
          EM_MSG="ERROR ON CLAIM POST-PROCESSING.  SEE LOG FILE - &PROGRAM_NAME..LOG FOR INITIATIVE ID &INITIATIVE_ID");



/*Final file create */

%DROP_DB2_TABLE(TBL_NAME=QCPAP020.&TABLE_PREFIX._GSTP_VENDOR); 

/*%DROP_DB2_TABLE(TBL_NAME=&DB2_TMP..GSTP_VENDOR_PHYS); */
/*%DROP_DB2_TABLE(TBL_NAME=QCPAP020.GSTP_VENDOR_PHYS); */

 	PROC SQL;
	 CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	    EXECUTE(
/*    CREATE TABLE &DB2_TMP..GSTP_VENDOR*/

    CREATE TABLE QCPAP020.&TABLE_PREFIX._GSTP_VENDOR
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

		) NOT LOGGED INITIALLY) BY DB2;
	 DISCONNECT FROM DB2;
	QUIT;
  		

		PROC SQL;
/*			INSERT INTO &DB2_TMP..GSTP_VENDOR*/
			INSERT INTO QCPAP020.&TABLE_PREFIX._GSTP_VENDOR
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
,   QL_DRUG_ABBR_PROD_NM 
,   QL_DRUG_ABBR_DSG_NM 
,   QL_DRUG_ABBR_STRG_NM 
,	DISP_DT
,	QUANTITY
,	DAYS_SUPPLY
,	RX_NBR
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
,   CLNT_LVL1
,   CLNT_LVL2
,   CLNT_LVL3
,   TARGET_CLIENT_KEY
,   PHYS_MAIL_FLAG_2
, 0
, DELIVERY_CD


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

%CREATE_BASE_FILE(TBL_NAME_IN=QCPAP020.&TABLE_PREFIX._GSTP_VENDOR);

%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  NOTIFICATION OF ABEND",
          EM_MSG="ERROR ON CREATE BASE FILE.  SEE LOG FILE - &PROGRAM_NAME..LOG FOR INITIATIVE ID &INITIATIVE_ID");


*SASDOC-------------------------------------------------------------------------
| CALL %CHECK_DOCUMENT TO SEE IF THE STELLENT ID(S) HAVE BEEN ATTACHED.
+-----------------------------------------------------------------------SASDOC*;
%CHECK_DOCUMENT;

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
 %DROP_DB2_TABLE(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._GSTP_CSTM_IN);
 %DROP_DB2_TABLE(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._GSTP_LVL1);
 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._GSTP_CLT_TGT);
 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._GSTP_CLT_TGT1);
 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._GSTP_LVL1);
 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._GSTP_DRUG);
 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._GSTP_PR_MBR_ID);
 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._GSTP_PR_DRUG_GID);
 %DROP_DB2_TABLE(TBL_NAME=QCPAP020.&TABLE_PREFIX._GSTP_VENDOR);
 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RE);
 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX);
 %end;
 %MEND;

/* %DELETE_GSTP_TEMP;*/



*SASDOC-------------------------------------------------------------------------
| UPDATE THE JOB COMPLETE TIMESTAMP
+-----------------------------------------------------------------------SASDOC*;
%UPDATE_TASK_TS(JOB_COMPLETE_TS);


