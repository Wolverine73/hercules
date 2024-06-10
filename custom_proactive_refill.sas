%include '/user1/qcpap020/autoexec_new.sas';

/** Remove parameters **/  
/* uncomment %LOAD_CLIENT */ 

/***HEADER -------------------------------------------------------------------------
 |  PROGRAM NAME:     CUSTOM_PROACTIVE_REFILL.SAS
 |
 |  PURPOSE:    TARGETS A CLIENT WHO WOULD LIKE A CUSTOM PROACTIVE MAILING.  THIS
 |              IS A ONE TIME MAILING.
 |              -- SELECT CLIENTS AND CPGS
 |              -- SELECT NDCS (EXPANDED MAINTENANCE)
 |              -- GET 45 DAY POS CLAIMS
 |              -- DO NOT TARGET IF MAIL SERVICE WAS USED WITHIN LAST 90 DAYS
 |              -- APPLY ONLY PARTICIPANTS WITH BOTH MAIL AND POS PBS
 |              -- UNLIKE THE PROACTIVE REFILL NOTIFICATION PROGRAM, THIS PROGRAM
 |                 DOES NOT CHECK FOR REFILL RESTRICTIONS
 |
 |  INPUT:      UDB TABLES ACCESSED BY MACROS ARE NOT LISTED
 |                        &CLAIMSA..TCPG_PB_TRL_HIST,
 |                        SUMMARY.TDRUG_COV_LMT_SUMM,
 |                        &CLAIMSA..TBENEF_BENEFICIAR1,
 |                        &CLAIMSA..TCLIENT1,
 |                        &CLAIMSA..TDRUG1,
 |                        &CLAIMSA.TRXCLM_BASE
 |
 |  OUTPUT:     STANDARD DATASETS IN /RESULTS AND /PENDING DIRECTORIES
 |
 |
 |  HISTORY:    MARCH 2004 - PEGGY WONDERS
 |              JAN 2005 - JOHN HOU
 |                         ADDED CODES TO FOR RETAINING PLAN_CD, GROUP_CD FIELDS WHICH
 |                         ARE NEEDED AS PART OF FILE LAYOUT
 |			JAN, 2007	- KULADEEP M	  ADDED CLAIM END DATE IS NOT NULL WHEN
 |										  FILL_DT BETWEEN CLAIM BEGIN DATE AND CLAIM END
 |										  DATE.
 |
 |	        MAR  2007    - GREG DUDLEY HERCULES VERSION  1.0
 |
 |           07MAR2008 - N.WILLIAMS   - HERCULES VERSION  2.0.01
 |                                      1. INITIAL CODE MIGRATION INTO DIMENSIONS
 |                                         SOURCE SAFE CONTROL TOOL. 
 |                                      2. UPDATE TO ADJUST BULKLOAD TO SQL PASS-THRU FOR TABLE LOADS.
 |
 |           APR. 22, 2008 - CARL STARKS - HERCULES VERSION 2.1.01
 |
 |           ADDED 3 MACRO CALLS TO GET RETAIL CLAIM DATA 
 |           PULL_EDW_RETAIL_CLAIMS IS A NEW MACRO TO PULL CLAIMS FOR RECAP AND RXCLAIM 
 |           PULL_QL_RETAIL_CLAIMS IS A NEW MACRO ALTHOUGH THE LOGIC WAS JUST PULLED 
 |           FROM CUSTOM PROACTIVE REFILL AND MADE INTO A MACRO              
 |           CALL NEW MACRO EDW2UNIX TO DOWNLOAD DATA TO UNIX THEN CALL               
 |           NEW MACRO COMBINE_ADJ TO COMBINE ADJUDICATIONS AND DATA CONVERSION
 |           ADDED LOGIC TO RUN SOME EXISTING MACROS TO RUN BASED ON ADJUDICATION 
 |           ADDED LOGIC TO READ 3 NEW MACRO VARIABLE TO DETERMINE WHICH ADJUDICATION PROCESS THAT
 |           WILL BE RAN (QL_ADJ, RX_ADJ AND RE_ADJ). THE QL_ADJ WILL RUN THE QL PROCESS WHOSE CODE
 |           DID NOT CHANGE MUCH FROM THE OLE ELIGIBILITY CHECK MACRO. THE RX_ADJ WILL RUN RXCLAIM
 |           AND RECAP WILL RUN RECAP THESE ARE 2 NEW PROCESSES ADDED 
 |
 | 			 - Hercules Version  2.1.2.01
 |
 |           Jun 2012   - Paul Landis  Testing new Hercules environment, hercdev2
 |                                    
 +-------------------------------------------------------------------------------HEADER*/

/*%include '/home/user/qcpap020/autoexec_new.sas'; */

%set_sysmode;
/*options sysparm='initiative_id=9034 phase_seq_nb=1';*/
/*%include "/herc&sysmode/prg/hercules/hercules_in_oak.sas" /nosource2;*/
%include "/herc&sysmode/prg/hercules/hercules_in.sas";

options mlogic mlogicnest mprint mprintnest symbolgen source2;

LIBNAME SUMMARY DB2 DSN=&UDBSPRP SCHEMA=SUMMARY DEFER=YES;
%GLOBAL POS_REVIEW_DAYS POS_REVIEW_DAYS2 CHK_DT CHK_DT2;
%LET POS_REVIEW_DAYS2 = 90; 
%LET ERR_FL=0;

%LET PROGRAM_NAME=custom_proactive_refill;
* ---> SET THE PARAMETERS FOR ERROR CHECKING;
 PROC SQL NOPRINT;
    SELECT QUOTE(TRIM(EMAIL)) INTO :PRIMARY_PROGRAMMER_EMAIL SEPARATED BY ' '
    FROM ADM_LKP.ANALYTICS_USERS
    WHERE UPCASE(QCP_ID) IN ("&USER");
 QUIT;
%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");

%UPDATE_TASK_TS(JOB_START_TS);

*SASDOC--------------------------------------------------------------------------
| CALL %RESOLVE_CLIENT
| RETRIEVE ALL CLIENT IDS THAT ARE INCLUDED IN THE MAILING.  IF A CLIENT IS
| PARTIAL, THIS WILL BE HANDLED AFTER DETERMINING CURRENT ELIGIBILITY.
|
| C.J.S MAY2008 
|     ADDED OUTPUT NAMES FOR EDW PROCESSING IN RESOLVE CLIENT
+------------------------------------------------------------------------SASDOC*;

%RESOLVE_CLIENT(TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CLT_CPG_QL,
                TBL_NAME_OUT_RX=&ORA_TMP..&TABLE_PREFIX._CLT_CPG_RX,
                TBL_NAME_OUT_RE=&ORA_TMP..&TABLE_PREFIX._CLT_CPG_RE) ;

%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered in the Resolve Client SAS Macro.  See LOG file - &PROGRAM_NAME..log for Initiative Id &INITIATIVE_ID");

/*%LET CC_QL_MIGR_IND =1;*/

*SASDOC ----------------------------------------------------------------------------------
 | Q2X - Adding condition for Migrated clients from QL
 +-----------------------------------------------------------------------------------SASDOC;

%MACRO LOAD_CLIENT;
%IF &QL_ADJ =1 OR &CC_QL_MIGR_IND. %THEN %DO;
   %GLOBAL CLIENT_IDS CLIENT_IDS_MIGR;
   %LET CLIENT_IDS_MIGR = %STR( );
   %LET CLIENT_IDS = %STR( );
   	%IF &QL_ADJ = 1 %THEN %DO;
		PROC SQL NOPRINT;
       		SELECT DISTINCT CLIENT_ID 
			INTO :CLIENT_IDS SEPARATED BY ','
       		FROM &DB2_TMP..&TABLE_PREFIX._CLT_CPG_QL;
	 	QUIT;
		%PUT NOTE:	CLIENT_IDS = &CLIENT_IDS;
	%END;
	%IF &CC_QL_MIGR_IND. %THEN %DO;
		PROC SQL NOPRINT;
       		SELECT DISTINCT CLIENT_ID
			INTO 	:CLIENT_IDS_MIGR SEPARATED BY ','
       		FROM &DB2_TMP..&TABLE_PREFIX._CLT_CPG_QL_MIGR;
    	QUIT;		
	%PUT NOTE:	CLIENT_IDS_MIGR=&CLIENT_IDS_MIGR ;
	%END;
%END;
%MEND LOAD_CLIENT;
%LOAD_CLIENT;


*SASDOC--------------------------------------------------------------------------
| CALL %GET_NDC TO DETERMINE THE MAINTENANCE NDCS
+------------------------------------------------------------------------SASDOC*;
%GET_NDC(DRUG_NDC_TBL=&DB2_TMP..&TABLE_PREFIX._NDC_QL,
         DRUG_NDC_TBL_RX=&ORA_TMP..&TABLE_PREFIX._NDC_RX,
         DRUG_NDC_TBL_RE=&ORA_TMP..&TABLE_PREFIX._NDC_RE
        );
%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered in macro GET_NDC.  See LOG file - &PROGRAM_NAME..log for Initiative Id &INITIATIVE_ID");


*SASDOC--------------------------------------------------------------------------
| CREATE POS_REVIEW_DAYS MACRO VARIABLE BY READING ACT_NBR_OF_DAYS
| FROM HERCULES.TPHASE_RVR_FILE TABLE 
|		01OCT2008 - K.MITTAPALLI- HERCULES VERSION  2.1.0.2
+------------------------------------------------------------------------SASDOC*;
PROC SQL NOPRINT;
SELECT ACT_NBR_OF_DAYS INTO : POS_REVIEW_DAYS
  FROM &HERCULES..TPHASE_RVR_FILE
 WHERE INITIATIVE_ID = &INITIATIVE_ID.
   AND PHASE_SEQ_NB  = &PHASE_SEQ_NB.
 ;
QUIT;
%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT: Notification of Abend",
          EM_MSG="A problem was encountered in creating macro variable POS_REVIEW_DAYS.  See LOG file - &PROGRAM_NAME..log for Initiative Id &INITIATIVE_ID");

*SASDOC--------------------------------------------------------------------------
| CREATE MACRO VARIABLES FOR DATES.
|		01OCT2008 - K.MITTAPALLI- HERCULES VERSION  2.1.0.2
+------------------------------------------------------------------------SASDOC*;

/*%let POS_REVIEW_DAYS = 45;*/
/*%let POS_REVIEW_DAYS2 = 60;*/



DATA _NULL_;
  IF &POS_REVIEW_DAYS. >= &POS_REVIEW_DAYS2. THEN DO;
  CALL SYMPUT('CLM_BEGIN_DT',PUT((TODAY()-&POS_REVIEW_DAYS), YYMMDD10.));
  CALL SYMPUT('CHK_DT',  "'"||PUT(TODAY()-&POS_REVIEW_DAYS, YYMMDD10.)||"'");

  END;
	  ELSE IF &POS_REVIEW_DAYS. < &POS_REVIEW_DAYS2. THEN DO;
	  CALL SYMPUT('CLM_BEGIN_DT',PUT((TODAY()-&POS_REVIEW_DAYS2), YYMMDD10.));
	  CALL SYMPUT('CHK_DT',  "'"||PUT(TODAY()-&POS_REVIEW_DAYS2, YYMMDD10.)||"'");

	  END;
  CALL SYMPUT('CLM_END_DT',PUT(TODAY(),YYMMDD10.));  
  CALL SYMPUT('CHK_DT2',  "'"||PUT(TODAY()-&POS_REVIEW_DAYS2, YYMMDD10.)||"'");
RUN;


%LET TODAY_DATE = today();
%LET RTL_HIS_DAYS=45;

/*	AK - modified date logic to suit custom proactive refill	*/
DATA _NULL_;
  CALL SYMPUT('CLM_BEGIN_DT_EDW',"TO_DATE('"||PUT((&TODAY_DATE-&RTL_HIS_DAYS), YYMMDD10.)||"','YYYY-MM-DD')");
  CALL SYMPUT('CHK_DT_EDW',"TO_DATE('"||PUT(&TODAY_DATE-&RTL_HIS_DAYS, YYMMDD10.)||"','YYYY-MM-DD')");
  CALL SYMPUT('CLM_END_DT_EDW',"TO_DATE('"||PUT(&TODAY_DATE,YYMMDD10.)||"','YYYY-MM-DD')");  
RUN;

/*  AK - Mail date range initialization for EDW mail claims pull - default - 90 days*/
%LET MAIL_HIS_DAYS=90;

DATA _NULL_;
  CALL SYMPUT('MAIL_BGN_DT_EDW',  "TO_DATE('"||PUT((&TODAY_DATE.-&MAIL_HIS_DAYS),YYMMDDD10.)||"','YYYY-MM-DD')");
  CALL SYMPUT('MAIL_END_DT_EDW',  "TO_DATE('"||PUT(&TODAY_DATE.,YYMMDDD10.)||"','YYYY-MM-DD')");
RUN;



/*AK added-CCQL*/
%PUT NOTE:  POS_REVIEW_DAYS = &POS_REVIEW_DAYS.;
%PUT NOTE:  POS_REVIEW_DAYS2 = &POS_REVIEW_DAYS2.;
%PUT NOTE:	CLM_BEGIN_DT = &CLM_BEGIN_DT;
%PUT NOTE:	CHK_DT = &CHK_DT;
%PUT NOTE:	CLM_END_DT = &CLM_END_DT;
%PUT NOTE:	CHK_DT2 = &CHK_DT2;
%PUT NOTE:  CLM_BEGIN_DT_EDW = &CLM_BEGIN_DT_EDW;
%PUT NOTE:  CHK_DT_EDW = &CHK_DT_EDW ;
%PUT NOTE:  CLM_END_DT_EDW = &CLM_END_DT_EDW;


		  
%MACRO QL_PROCESS;
*SASDOC --------------------------------------------------------------------
|  IDENTIFY THE RETAIL MAINTENANCE QL CLAIMS DURING THE LAST &POS_REVIEW_DAYS
|  WHO HAVE NOT FILLED ANY SCRIPTS AT MAIL DURING THE LAST 90 DAYS.
| MAY2008 C.J.S
| LOGIC ADDED SO THAT THIS MACRO WILL ONLY RUN IF QL WAS SELECTED TO RUN FROM
| JAVA SCREENS
+--------------------------------------------------------------------SASDOC*;
%PULL_QL_RETAIL_CLAIMS(TBL_NAME_IN1=&DB2_TMP..&TABLE_PREFIX._CLT_CPG_QL,
					   TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._NDC_QL, 
                       TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CLAIMS_QL,
                       ADJ_ENGINE='QL',CLIENT_IDS = &CLIENT_IDS);

     %DROP_DB2_TABLE(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CPG_PB);

      PROC SQL;
        CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
          EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._CPG_PB
                 (
		       CLT_PLAN_GROUP_ID	INTEGER			NOT NULL,
		       CLIENT_ID	        INTEGER			NOT NULL,
		       PLAN_CD	        	CHARACTER(8) 	NOT NULL,
		       PLAN_EXTENSION_CD	CHARACTER(8) 	NOT NULL,
		       GROUP_CD	        	CHARACTER(15)	NOT NULL,
		       GROUP_EXTENSION_CD	CHARACTER(5)	NOT NULL,
		       BLG_REPORTING_CD		CHARACTER(15)	NOT NULL,
		       PLAN_GROUP_NM	    CHARACTER(30)	NOT NULL,        
		       POS_PB               INTEGER,
		       MAIL_PB              INTEGER		  
                  ) NOT LOGGED INITIALLY) BY DB2;
        DISCONNECT FROM DB2;
      QUIT;
 
      PROC SQL;
         CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
          EXECUTE(ALTER TABLE &db2_tmp..&TABLE_PREFIX._CPG_PB 
                  ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;

          EXECUTE(INSERT INTO &db2_tmp..&TABLE_PREFIX._CPG_PB 
                  SELECT E.CLT_PLAN_GROUP_ID,E.CLIENT_ID, 
                         E.PLAN_CD, E.PLAN_EXTENSION_CD,
                         E.GROUP_CD, E.GROUP_EXTENSION_CD,
                         E.BLG_REPORTING_CD,
                         E.PLAN_GROUP_NM,
                       MAX(CASE
                           WHEN A.DELIVERY_SYSTEM_CD = 3 THEN PB_ID
                            ELSE 0
                        END) AS POS_PB,
                        MAX(CASE
                           WHEN A.DELIVERY_SYSTEM_CD = 2 THEN PB_ID
                           ELSE 0
                        END) AS MAIL_PB
                   FROM &CLAIMSA..TCPG_PB_TRL_HIST  A,
                        &DB2_TMP..&TABLE_PREFIX._CLT_CPG_QL D,
                        &CLAIMSA..TCPGRP_CLT_PLN_GR1  E
                   WHERE D.CLT_PLAN_GROUP_ID = A.CLT_PLAN_GROUP_ID
                      AND   D.CLT_PLAN_GROUP_ID = E.CLT_PLAN_GROUP_ID
                      AND   A.EXP_DT > CURRENT DATE
                      AND   A.EFF_DT < CURRENT DATE
                      AND   A.DELIVERY_SYSTEM_CD IN (2,3)
                  GROUP BY E.CLT_PLAN_GROUP_ID,E.CLIENT_ID,
                      E.PLAN_CD, E.PLAN_EXTENSION_CD,
                      E.GROUP_CD, E.GROUP_EXTENSION_CD,
                      E.BLG_REPORTING_CD,
                      E.PLAN_GROUP_NM
                  HAVING COUNT(DISTINCT A.DELIVERY_SYSTEM_CD)=2             
             )BY DB2;
        DISCONNECT FROM DB2;
    QUIT;
  %SET_ERROR_FL;
  %ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered in QL_PROCESS.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");

  %RUNSTATS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CPG_PB);

*SASDOC--------------------------------------------------------------------------
| CALL %GET_MOC_PHONE
| ADD THE MAIL ORDER PHARMACY AND CUSTOMER SERVICE PHONE TO THE CPG FILE
|C.J.S  APR2008
| ADDED ADJ LOGIC SO MACRO WILL RUN FOR QL ONLY
+------------------------------------------------------------------------SASDOC*;
 %GET_MOC_CSPHONE(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._CPG_PB,
                  TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CPG_MOC);
%MEND QL_PROCESS;



*SASDOC --------------------------------------------------------------------
|   C.J.S MAY2008
|  IDENTIFY THE RETAIL MAINTENANCE RX/RE CLAIMS DURING THE LAST &POS_REVIEW_DAYS
|  WHO HAVE NOT FILLED ANY SCRIPTS AT MAIL DURING THE LAST 90 DAYS.
| MAY2008 C.J.S
| LOGIC ADDED SO THAT THIS MACRO WILL ONLY RUN IF RX WAS SELECTED TO RUN FROM
| JAVA SCREENS
+--------------------------------------------------------------------SASDOC*;
       	
%MACRO RX_RE_PROCESS(TBL_NM_RX_RE,INPT_TBL_RX_RE,EDW_ADJ,CLAIMS_TBL,
					 TBL_NM_RX_RE2,MODULE2);

*SASDOC --------------------------------------------------------------------
|   C.J.S MAY2008
|   CALL DELIVERY_SYS_CHECK MACRO TO RESOLVE IF ANY OF THE DELIVERY SYSTEMS 
|	SHOULD BE EXCLUDED FROM THE INITIATIVE.  IF SO, FORM A STRING THAT WILL 
|	BE INSERTED INTO THE SQL THAT QUERIES CLAIMS.
+--------------------------------------------------------------------SASDOC*;

%INCLUDE "/herc&sysmode/prg/hercules/macros/delivery_sys_check_tbd.sas";

%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered in delivery_sys_check_tbd.sas.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");


*SASDOC --------------------------------------------------------------------
|   C.J.S MAY2008
|  THIS PROC AQL STEP DOES A JOIN AGAINST VARIOUS TABLES IN ORDER TO PULL
|  THE RETAIL CLAIMS	
+--------------------------------------------------------------------SASDOC*;

%DROP_ORACLE_TABLE(TBL_NAME=&&ORA_TMP..RXKEY_&INITIATIVE_ID._&MODULE2.);

options mlogic mlogicnest mprint mprintnest symbolgen source2;
/*	SUMMARIZE THE CLAIMS */
PROC SQL;
  CONNECT TO ORACLE(PATH=&GOLD);
  EXECUTE(
    CREATE TABLE &ORA_TMP..RXKEY_&INITIATIVE_ID._&MODULE2. AS
    SELECT
    UNIQUE
     B.ALGN_LVL_GID_KEY
    ,B.MBR_ID
	,B.MBR_GID
    ,B.DRUG_NDC_ID
    ,MAX(B.LAST_FILL_DT||B.DRUG_NDC_ID||B.RX_NB||B.REFILL_FILL_QY) AS RXKEY
    FROM &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._&MODULE2. B
    GROUP
    BY
     B.ALGN_LVL_GID_KEY
    ,B.MBR_ID
	,B.MBR_GID
    ,B.DRUG_NDC_ID
    HAVING SUM(B.RX_COUNT_QY)>0
  ) BY ORACLE;
  DISCONNECT FROM ORACLE;
QUIT;



%DROP_ORACLE_TABLE(TBL_NAME=&TBL_NM_RX_RE.);
PROC SQL noprint;
CONNECT TO ORACLE(PATH=&GOLD);
CREATE TABLE &TBL_NM_RX_RE. AS
SELECT * FROM CONNECTION TO ORACLE 
(
  SELECT %BQUOTE(/)%BQUOTE(*)+ORDERED%BQUOTE(*)%BQUOTE(/) DISTINCT
                 CLAIM.MBR_GID				AS MBR_GID,
				 CLAIM.PAYER_ID				AS PAYER_ID,
				 CLAIM.ALGN_LVL_GID_KEY		AS ALGN_LVL_GID_KEY,
				 CLAIM.PT_BENEFICIARY_ID 	AS PT_BENEFICIARY_ID,
				 CLAIM.MBR_ID				AS MBR_ID,
				 CLAIM.CDH_BENEFICIARY_ID 	AS CDH_BENEFICIARY_ID,
				 CLAIM.CLIENT_ID			AS CLIENT_ID,
				 CLAIM.CLIENT_LEVEL_1 		AS CLIENT_LEVEL_1,
				 CLAIM.CLIENT_LEVEL_2 		AS CLIENT_LEVEL_2,
				 CLAIM.CLIENT_LEVEL_3 		AS CLIENT_LEVEL_3,
				 CLAIM.ADJ_ENGINE			AS ADJ_ENGINE,
				 CLAIM.LAST_FILL_DT  		AS LAST_FILL_DT,
				 CLAIM.CLIENT_NM			AS CLIENT_NM,
				 0 							AS LTR_RULE_SEQ_NB,
				 CLAIM.REFILL_FILL_QY 		AS REFILL_FILL_QY,
				 CLAIM.DRUG_NDC_ID 			AS DRUG_NDC_ID,
				 CLAIM.RX_NB AS RX_NB,
				 CLAIM.LAST_DELIVERY_SYS,
				 CLAIM.DISPENSED_QY,
				 CLAIM.DAY_SUPPLY_QY,
				 CLAIM.GPI14, 
				 CLAIM.GCN_CODE,
				 CLAIM.BRAND_GENERIC,
				 CLAIM.DRUG_ABBR_DSG_NM,
				 CLAIM.DRUG_ABBR_PROD_NM, 
				 CLAIM.DRUG_ABBR_STRG_NM,
				 CLAIM.PHARMACY_NM, 
				 CLAIM.PRESCRIBER_NPI_NB, 
				 CLAIM.FORMULARY_TX, 
				 CLAIM.DEA_NB,
				 &&CREATE_DELIVERY_SYSTEM_CD_&MODULE2.
			FROM &CLAIMS_TBL. CLAIM, DSS_CLIN.V_PHMCY_DENORM PHMCY, &ORA_TMP..RXKEY_&INITIATIVE_ID._&MODULE2. KEYS
		   WHERE  CLAIM.ALGN_LVL_GID_KEY=KEYS.ALGN_LVL_GID_KEY
			    AND CLAIM.MBR_ID=KEYS.MBR_ID
			    AND CLAIM.DRUG_NDC_ID=KEYS.DRUG_NDC_ID
			    AND CLAIM.LAST_FILL_DT||CLAIM.DRUG_NDC_ID||CLAIM.RX_NB||CLAIM.REFILL_FILL_QY=KEYS.RXKEY
				AND CLAIM.PHMCY_GID = PHMCY.PHMCY_GID
	  			 	&RETAIL_DELVRY_CD.
);
	  DISCONNECT FROM ORACLE;
QUIT;


/*	AK - Mail order removals	*/
libname dwcorp oracle path=gold user=dss_herc pw=anlt2web schema=dwcorp;

		PROC SQL NOPRINT;
		SELECT PHMCY.PHMCY_GID INTO :PHMCY_GID SEPARATED BY ','
		FROM DWCORP.T_IBEN_ECOE_MOC_PHMCY_CD MOC_ECOE,
			 DWCORP.V_PHMCY_DENORM PHMCY
		WHERE MOC_ECOE.MOC_PHMCY_NPI_ID=PHMCY.CURR_NPI_ID;
		QUIT;

%put PHMCY_GID = &PHMCY_GID;





%if %sysfunc(exist(DATA_RES.mail_claims_&initiative_id._&MODULE2.)) %then %do;

				/*	Concatenating regular RX mail claims with migrated mail claims		*/
				%if &module2. = RX and %sysfunc(exist(data_res.mail_claims_migr_&initiative_id.)) %then %do;

					proc append base = DATA_RES.mail_claims_&initiative_id._&MODULE2. data = data_res.mail_claims_migr_&initiative_id.;
					run;

				%end;

%end;


%if %sysfunc(exist(DATA_RES.mail_claims_&initiative_id._&MODULE2.)) = 0 %then %do;
			%if &module2. = RX and %sysfunc(exist(data_res.mail_claims_migr_&initiative_id.)) %then %do;
						data DATA_RES.mail_claims_&initiative_id._&MODULE2.;
						set data_res.mail_claims_migr_&initiative_id.;
			%end;
%end;

%if %sysfunc(exist(DATA_RES.mail_claims_&initiative_id._&MODULE2.)) %then %do;

	proc sql noprint;
	  drop table MAIL_CLAIMS_&INITIATIVE_ID._&MODULE2.;quit;

		proc sql;
       create table MAIL_CLAIMS_&INITIATIVE_ID._&MODULE2. as
        select * from DATA_RES.MAIL_CLAIMS_&INITIATIVE_ID._&MODULE2.
       where PHMCY_GID IN (&PHMCY_GID.)
          ;quit;

%end;



%if %sysfunc(exist(mail_claims_&initiative_id._&MODULE2.)) %then %do;

	proc sql noprint;
		create table data_res.mail_members_removed_&initiative_id._&MODULE2. as
		select a.* from
		mail_claims_&initiative_id._&MODULE2. a left join &tbl_nm_rx_re. b
		on a.mbr_gid = b.mbr_gid
		where b.mbr_id is null;
	;quit;


%if &sqlobs %then %do;		/*	Apply delete if there are rows in the mail claims dataset else skip	*/
%put sqlobs=&sqlobs;

/*	Delete the members from the claims pulled	*/
	proc sql;
	delete from &tbl_nm_rx_re.
	where mbr_gid in (select distinct mbr_gid from mail_claims_&initiative_id._&module2.);
	quit;

%end;
%end;


/*	FIX TO UPDATE THE DELIVERY SYSTEM CODES - CONVERTS THE VALUES TO 2/3 - MAIL/RETAIL*/
%UPDATE_DELIVERY_SYS(TABLE_NAME=%str(%trim(&TBL_NM_RX_RE.)), COL_LKP=%STR(DELIVERY_SYSTEM),COL_UPD=%STR(LAST_DELIVERY_SYS));


/*	QL CLIENT CONNECT PROJECT - REMOVE BAD MBR_GIDS	*/
%IF &MODULE2. = RX AND &CC_QL_MIGR_IND. %THEN %DO;

%IF %SYSFUNC(EXIST(&tbl_nm_rx_re.)) %THEN %DO;

%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..BADRX_GIDS_REMOVAL_&INITIATIVE_ID.);

/* BACKING UP BAD MBR_GIDS	*/
PROC SQL;
CONNECT TO ORACLE(PATH=&GOLD. PRESERVE_COMMENTS);
CREATE TABLE &ORA_TMP..BADRX_GIDS_REMOVAL_&INITIATIVE_ID. AS
SELECT * FROM CONNECTION TO ORACLE
(
SELECT %bquote(/)%bquote(*)+ordered index(B X_MBR_ELIG_N10)%bquote(*)%bquote(/)
		 A.*, B.ELIG_EFF_DT, B.ELIG_END_DT
	FROM  &tbl_nm_rx_re. A,   
		 &DSS_CLIN..V_MBR_ELIG_ACTIVE  B
		WHERE 		A.PAYER_ID = B.PAYER_ID 
				AND A.MBR_GID = B.MBR_GID
				AND CLIENT_LEVEL_1 IN (SELECT DISTINCT CLIENT_LEVEL_1 FROM &ORA_TMP..T_&INITIATIVE_ID._1_QL_MIGR1) 
		 		AND	(B.ELIG_EFF_DT > SYSDATE OR B.ELIG_END_DT < SYSDATE))
;DISCONNECT FROM ORACLE
;QUIT;



PROC SQL;
CONNECT TO ORACLE(PATH=&GOLD.);
EXECUTE (
DELETE FROM  &tbl_nm_rx_re.
WHERE CLIENT_LEVEL_1 IN (SELECT DISTINCT CLIENT_LEVEL_1 FROM &ORA_TMP..T_&INITIATIVE_ID._1_QL_MIGR1)
  AND  MBR_GID IN
(SELECT DISTINCT MBR_GID FROM &ORA_TMP..BADRX_GIDS_REMOVAL_&INITIATIVE_ID.)
)
BY ORACLE;
DISCONNECT FROM ORACLE;
QUIT;



%END;
%END;


*SASDOC--------------------------------------------------------------------------
| CALL %GET_MOC_PHONE
| ADD THE MAIL ORDER PHARMACY AND CUSTOMER SERVICE PHONE TO THE CPG FILE
|C.J.S  APR2008
| CHANGED INPUT AND OUTPUT NAMES AND ADDED ADJ LOGIC SO MACRO WILL RUN FOR RX/RE
+------------------------------------------------------------------------SASDOC*;
%GET_MOC_CSPHONE(MODULE=&MODULE2.,
					 TBL_NAME_IN =&TBL_NM_RX_RE., 
                     TBL_NAME_OUT=&TBL_NM_RX_RE2.);

%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered in macro RX_RE_PROCESS.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");

%MEND RX_RE_PROCESS;

*SASDOC--------------------------------------------------------------------------
| Q2X - Added &CC_QL_MIGR_IND. to run historical 
|			claims QL process if client(s) migrated from QL to RX
+------------------------------------------------------------------------SASDOC*;
 
%MACRO PROCESS;


%CLAIMS_PULL_EDW_CUSTOM_PROACTIVE(DRUG_NDC_TABLE_RX = &ORA_TMP..&TABLE_PREFIX._NDC_RX,
                                 DRUG_NDC_TABLE_RE = &ORA_TMP..&TABLE_PREFIX._NDC_RE, 
                                 DRUG_RVW_DATES_TABLE = &ORA_TMP..&TABLE_PREFIX._RVW_DATES,
                                 RESOLVE_CLIENT_TABLE_RX = &ORA_TMP..&TABLE_PREFIX._CLT_CPG_RX ,
                                 RESOLVE_CLIENT_TABLE_RE = &ORA_TMP..&TABLE_PREFIX._CLT_CPG_RE
                       );

%IF &RX_ADJ EQ 1 %THEN %DO;
	
/*	AK added	*/
%IF &CC_QL_MIGR_IND. %THEN %DO;

%local ADJ_ENGINE;
%let ADJ_ENGINE = RX;

%DROP_DB2_TABLE(TBL_NAME=&DB2_TMP..&table_prefix._QL_MIGR);
proc sql noprint;
connect to db2(dsn=&udbsprp.);
create table &db2_tmp..&table_prefix._QL_MIGR as
select * from connection to db2(
select * from &db2_tmp..&table_prefix._CLT_CPG_QL_MIGR);
disconnect from db2;
quit;

%LET MAIL_BGN_EDW_DT = &MAIL_BGN_DT_EDW;
%LET MAIL_END_EDW_DT = &MAIL_END_DT_EDW;

%GLOBAL CLM_BEGIN_DT_CONV;
%GLOBAL CLM_END_DT_CONV;

%LET CLM_BEGIN_DT_CONV  = &CLM_BEGIN_DT_EDW;
%LET CLM_END_DT_CONV = &CLM_END_DT_EDW;

%PUT MAIL_BGN_EDW_DT=&MAIL_BGN_EDW_DT;
%PUT MAIL_END_EDW_DT=&MAIL_END_EDW_DT;
%PUT CLM_BEGIN_DT_CONV=&CLM_BEGIN_DT_CONV;
%PUT CLM_END_DT_CONv=&CLM_END_DT_CONV;


%CLAIMS_PULL_EDW_QL_MIGR;	/*Calling the same macro that proactive refill uses, to produce QL history claims and combine with RX claims pull*/

%END;


	%RX_RE_PROCESS(&ORA_TMP..&TABLE_PREFIX.PT_CLAIMS_GROUP_RX
			  ,&ORA_TMP..&TABLE_PREFIX._CLT_CPG_RX
			  ,2
			  ,&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX
			  ,&ORA_TMP..&TABLE_PREFIX.PT_CLAIM_MOC_RX
			  ,RX);
%END;
%IF &RE_ADJ EQ 1 %THEN %DO;
	%RX_RE_PROCESS(&ORA_TMP..&TABLE_PREFIX.PT_CLAIMS_GROUP_RE
			  ,&ORA_TMP..&TABLE_PREFIX._CLT_CPG_RE
			  ,3
			  ,&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RE
			  ,&ORA_TMP..&TABLE_PREFIX.PT_CLAIM_MOC_RE
			  ,RE);
%END;
%IF &QL_ADJ EQ 1 %THEN %DO;
	%QL_PROCESS;
%END;
%MEND PROCESS;
%PROCESS;



*SASDOC-------------------------------------------------------------------------
| DETERMINE ELIGIBILITY FOR THE CARDHOLDLER AS WELL AS PARTICIPANT (IF
| AVAILABLE).
|C.J.S  APR2008
| PASS NEW INPUT AND OUTPUT NAMES FOR RECAP AND RXCLAIM
+-----------------------------------------------------------------------SASDOC*;
%ELIGIBILITY_CHECK(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._CLAIMS_QL,
                   TBL_NAME_IN_RX=&ORA_TMP..&TABLE_PREFIX.PT_CLAIM_MOC_RX, 
                   TBL_NAME_IN_RE=&ORA_TMP..&TABLE_PREFIX.PT_CLAIM_MOC_RE, 
                   TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG_QL,
                   TBL_NAME_RX_OUT2=&ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RX,
                   TBL_NAME_RE_OUT2=&ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RE,
                   CLAIMSA=&CLAIMSA);

%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered in macro ELIGIBILITY_CHECK.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");



*SASDOC ------------------------------------------------------------------------
 | FIND THE LATEST BILLING_END_MONTH FOR THE SUMMARY TABLES. USE COPAY SUMMARY
 | FOR FASTEST RESULTS.
 | C.J.S MAY2008
 | ADDED CODE SO THAT THIS ONLY RUNS FOR QL
 +-----------------------------------------------------------------------SASDOC*;
%MACRO REFILL_DATA;
%IF &QL_ADJ = 1 %THEN %DO;

     PROC SQL NOPRINT;
       SELECT MAX(BILLING_END_MONTH)
             INTO :MAX_COPAY_DATE
       FROM SUMMARY.TCOPAY_PLAN_SUMM;
     QUIT;

*SASDOC -----------------------------------------------------------------------------
 |   USE SUMMARY.TDRUG_COV_LMT_SUMM TO DELETE DRUG CATEGORIES NOT BEING COVERED WHILE
 |   CALCULATING THE REFILL_FILL_QY (SUBTRACT 1 FROM ANNUAL_REFILL_QY).  KEEP ONLY
 |   THE ELIGIBLE CPGS, PARTICIPANTS
 |
 |     NOTE: REFILL_FILL_QY OR ANNUAL_FILL_QY MAY HAVE VALUES LIKE '9999' WHICH MEANS
 |           NO REFILL LIMIT AND SHOULD BE TREATED SAME AS NULL
 + ----------------------------------------------------------------------------SASDOC*;

%DROP_DB2_TABLE(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CLAIMS2_QL);

       PROC SQL;
         CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
         CREATE TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS2_QL AS
         SELECT * FROM CONNECTION TO DB2
            (SELECT DISTINCT
                0 as LTR_RULE_SEQ_NB,
                A.PT_BENEFICIARY_ID,
                A.CDH_BENEFICIARY_ID,
                A.BIRTH_DT,
                A.CLIENT_ID,
                A.CLT_PLAN_GROUP_ID2,
				A.ADJ_ENGINE,
                CLIENT_NM,
                c.PLAN_CD,
                c.GROUP_CD,
                c.BLG_REPORTING_CD,
                DRUG_ABBR_PROD_NM,
                CASE
                  WHEN (A.REFILL_FILL_QY >= 1 AND A.REFILL_FILL_QY < 9999) THEN A.REFILL_FILL_QY
                  WHEN (ANNUAL_FILL_QY > 1 AND ANNUAL_FILL_QY < 9999) THEN (ANNUAL_FILL_QY - 1)
                END as REFILL_FILL_QY,
                MOC_PHM_CD,
                CS_AREA_PHONE,
				A.RX_NB,          /* NEW FIELDS FROM TRXCLM_BASE */
				A.DISPENSED_QY ,
				A.DAY_SUPPLY_QY,
				A.FORMULARY_TX,
				A.DRUG_NDC_ID,
				A.DRUG_ABBR_STRG_NM,
				A.DRUG_ABBR_DSG_NM,
				A.PLAN_EXT_CD_TX,
				A.GROUP_EXT_CD_TX,
                A.CLIENT_LEVEL_1 ,
				A.CLIENT_LEVEL_2,
				A.CLIENT_LEVEL_3,
				A.MBR_ID,
				A.LAST_DELIVERY_SYS,
				A.LAST_FILL_DT,
				A.GCN_CODE,
				A.BRAND_GENERIC     ,
				A.DEA_NB,
 				A.PRESCRIBER_NPI_NB,
				A.PHARMACY_NM,
				A.GPI_THERA_CLS_CD

            FROM &DB2_TMP..&TABLE_PREFIX._CLAIMS_QL A,
                 &DB2_TMP..&TABLE_PREFIX._CPG_ELIG_QL B,
                 &DB2_TMP..&TABLE_PREFIX._CPG_MOC C,
                 &CLAIMSA..TCLIENT1 E,
            SUMMARY.TDRUG_COV_LMT_SUMM D
            where A.PT_BENEFICIARY_ID = B.PT_BENEFICIARY_ID
                AND   A.CLIENT_ID = E.CLIENT_ID
                AND   C.CLT_PLAN_GROUP_ID = B.CLT_PLAN_GROUP_ID
/*                AND   D.BILLING_END_MONTH = 201102*/
                AND   D.BILLING_END_MONTH = &MAX_COPAY_DATE
                AND   C.POS_PB = D.PB_ID
                AND   A.DRUG_CATEGORY_ID = D.DRUG_CATEGORY_ID);
        DISCONNECT FROM DB2;
       QUIT;
      %SET_ERROR_FL;
      %ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
             EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
             EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");

      %LET ERR_FL=0;
       %RUNSTATS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CLAIMS2_QL);

%END;   /* END QL PROCESS FOR REFILLS*/

%MEND  REFILL_DATA;

%REFILL_DATA;

*SASDOC--------------------------------------------------------------------------
| MAY2008 C.J.S 
| THIS PROCESS WILL DOWNLOAD EDW DATA TO UNIX FOR EACH ADJUDICATION.
|
+------------------------------------------------------------------------SASDOC*;
%MACRO PROCESS1;

%IF &QL_ADJ EQ 1 %THEN %DO;

%DROP_DB2_TABLE(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CLAIMS3_QL);

DATA &DB2_TMP..&TABLE_PREFIX._CLAIMS3_QL(DROP = CLT_PLAN_GROUP_ID2);
 SET &DB2_TMP..&TABLE_PREFIX._CLAIMS2_QL;
 CLIENT_LEVEL_1 = PUT(CLT_PLAN_GROUP_ID2,$20.);
 CLIENT_LEVEL_2 = ' ';
 CLIENT_LEVEL_3 = ' ';
RUN;

%EDW2UNIX(TBL_NM_IN=&DB2_TMP..&TABLE_PREFIX._CLAIMS3_QL
		 ,TBL_NM_OUT=DATA.&TABLE_PREFIX._CLAIMS2_QL
         ,ADJ_ENGINE=1  );
%END;
%IF &RX_ADJ EQ 1 %THEN %DO;

%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RX_TMP);

DATA &ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RX_TMP;
	SET &ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RX;
    DAY_SPPLY_TMP=INPUT(DAY_SUPPLY_QY,4.);
    DROP DAY_SUPPLY_QY;
    RENAME DAY_SPPLY_TMP=DAY_SUPPLY_QY;
RUN;
%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RX);

%EDW2UNIX(TBL_NM_IN=&ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RX_TMP
		 ,TBL_NM_OUT=DATA.&TABLE_PREFIX._CPG_ELIG_RX
         ,ADJ_ENGINE=2   );
%END;
%IF &RE_ADJ EQ 1 %THEN %DO;

%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RE_TMP);
DATA &ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RE_TMP;
	SET &ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RE;
    DAY_SPPLY_TMP=INPUT(DAY_SUPPLY_QY,4.);
    DROP DAY_SUPPLY_QY;
    RENAME DAY_SPPLY_TMP=DAY_SUPPLY_QY;
RUN;
%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RE);

%EDW2UNIX(TBL_NM_IN=&ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RE_TMP
		 ,TBL_NM_OUT=DATA.&TABLE_PREFIX._CPG_ELIG_RE
         ,ADJ_ENGINE=3  );
%END;

%MEND PROCESS1;
%PROCESS1;

*SASDOC--------------------------------------------------------------------------
| MAY2008 C.J.S
| CALL THE MACRO %COMBINE_ADJUDICATIONS. THE LOGIC IN THE MACRO COMBINES THE CLAIMS
| THAT WERE PULLED FOR ALL THREE ADJUDICATIONS.
+------------------------------------------------------------------------SASDOC*;
%COMBINE_ADJ(TBL_NM_QL=DATA.&TABLE_PREFIX._CLAIMS2_QL,
             TBL_NM_RX=DATA.&TABLE_PREFIX._CPG_ELIG_RX_TMP,
             TBL_NM_RE=DATA.&TABLE_PREFIX._CPG_ELIG_RE,
             TBL_NM_OUT=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB
             ); 
 *SASDOC-------------------------------------------------------------------------
 | GET BENEFICIARY ADDRESS AND CREATE SAS FILE LAYOUT.
 | JUL2004 C.J.S
 | INPUT FILE NAME CHANGED
 +-----------------------------------------------------------------------SASDOC*;
/*%CREATE_BASE_FILE(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB);*/
%CREATE_BASE_FILE(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB);

*SASDOC-------------------------------------------------------------------------
| Remove duplicate records based on participant and drug, since one letter per ndc
| will be sent. We will keep only the maximum last_fill_dt value
| per participant per NDC - AK - JAN2013
+-----------------------------------------------------------------------SASDOC*;
%macro del_dupes;
%IF %SYSFUNC(EXIST(DATA_PND.&TABLE_PREFIX._1)) %THEN %DO;
%delete_duplicates(TBL_IN=DATA_PND.&TABLE_PREFIX._1);
%delete_duplicates(TBL_IN=DATA_RES.&TABLE_PREFIX._1);
%END;

%IF %SYSFUNC(EXIST(DATA_PND.&TABLE_PREFIX._2)) %THEN %DO;
%delete_duplicates(TBL_IN=DATA_PND.&TABLE_PREFIX._2);
%delete_duplicates(TBL_IN=DATA_RES.&TABLE_PREFIX._2);
%END;
%mend del_dupes;
%del_dupes;
 *SASDOC-------------------------------------------------------------------------
 | CALL %CHECK_DOCUMENT TO SEE IF THE STELLENT ID(S) HAVE BEEN ATTACHED.
 +-----------------------------------------------------------------------SASDOC*;
%CHECK_DOCUMENT;
 *SASDOC-------------------------------------------------------------------------
 | CHECK FOR AUTORELEASE OF FILE.
 +-----------------------------------------------------------------------SASDOC*;
%AUTORELEASE_FILE(INIT_ID=&INITIATIVE_ID, PHASE_ID=&PHASE_SEQ_NB);
 *SASDOC-------------------------------------------------------------------------
 | DROP THE TEMPORARY UDB TABLES
 +-----------------------------------------------------------------------SASDOC*;
 

 *SASDOC-------------------------------------------------------------------------
 | INSERT DISTINCT RECIPIENTS INTO TCMCTN_PENDING IF THE FILE IS NOT AUTORELEASE.
 | THE USER WILL RECEIVE AN EMAIL WITH THE INITIATIVE SUMMARY REPORT.  IF THE
 | FILE IS AUTORELEASED, %RELEASE_DATA IS CALLED AND NO EMAIL IS GENERATED FROM
 | %INSERT_TCMCTN_PENDING.
 +-----------------------------------------------------------------------SASDOC*;
/*%LET AUTORELEASE=0;*/

%INSERT_TCMCTN_PENDING(INIT_ID=&INITIATIVE_ID, PHASE_ID=&PHASE_SEQ_NB);

%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative Id &INITIATIVE_ID");

**SASDOC -----------------------------------------------------------------------------
 | GENERATE CLIENT_INITIATIVE_SUMMARY REPORT
 + ----------------------------------------------------------------------------SASDOC*;

PROC SQL;
    SELECT MAX(REQUEST_ID) INTO :MAX_ID
    FROM HERCULES.TREPORT_REQUEST;
QUIT;
%PUT  &MAX_ID;

PROC SQL;
   INSERT INTO HERCULES.TREPORT_REQUEST
   (REQUEST_ID, REPORT_ID, REQUIRED_PARMTR_ID, SEC_REQD_PARMTR_ID, JOB_REQUESTED_TS,
    JOB_START_TS, JOB_COMPLETE_TS, HSC_USR_ID , HSC_TS , HSU_USR_ID , HSU_TS )
   VALUES
   (%EVAL(&MAX_ID.+1), 11, &INITIATIVE_ID., &PHASE_SEQ_NB., %SYSFUNC(DATETIME()), %SYSFUNC(DATETIME()), 
    NULL, 'QCPAP020' , %SYSFUNC(DATETIME()), 'QCPAP020', %SYSFUNC(DATETIME()));
QUIT;

options sysparm="request_id=%EVAL(&MAX_ID.+1)" ;

%INCLUDE "/herc&sysmode/prg/hercules/reports/client_initiative_summary.sas";

**SASDOC -----------------------------------------------------------------------------
 | GENERATE RECEIVER_LISTING REPORT
 + ----------------------------------------------------------------------------SASDOC*;
 PROC SQL;
 SELECT MAX(REQUEST_ID) INTO :MAX_ID
 FROM HERCULES.TREPORT_REQUEST;
 QUIT;
%PUT  &MAX_ID;

PROC SQL;
   INSERT INTO HERCULES.TREPORT_REQUEST
     (REQUEST_ID, REPORT_ID, REQUIRED_PARMTR_ID, SEC_REQD_PARMTR_ID, JOB_REQUESTED_TS,
      JOB_START_TS, JOB_COMPLETE_TS, HSC_USR_ID , HSC_TS , HSU_USR_ID , HSU_TS )
   VALUES
    (%EVAL(&MAX_ID.+1), 15, &INITIATIVE_ID., &PHASE_SEQ_NB., %SYSFUNC(DATETIME()), %SYSFUNC(DATETIME()), 
 NULL, 'QCPAP020' , %SYSFUNC(DATETIME()), 'QCPAP020', %SYSFUNC(DATETIME()));
QUIT;

options sysparm="request_id=%EVAL(&MAX_ID.+1)" ;
%include "/herc&sysmode/prg/hercules/reports/receiver_listing.sas" / nosource2;
 *SASDOC-------------------------------------------------------------------------
 | UPDATE THE JOB COMPLETE TIMESTAMP.
 +-----------------------------------------------------------------------SASDOC*;
 %UPDATE_TASK_TS(JOB_COMPLETE_TS);

