%include '/user1/qcpap020/autoexec_new.sas';
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  retail_daw.sas
|
| LOCATION: /PRG/sas&sysmode.1/hercules/123
|
| PURPOSE:  Used to produce task #16 (Standard Retail DAW mailing).
|
| LOGIC:    All clients are targeted unless they have an annual fill
|           restriction or if they are turned off in CSS. The annual fill
|           restriction may be overridden at the client level.
|
|           Target POS claims where the drug is a maintenance (expanded list) brand
|           w/ generic available and the drug is not excluded in the program gpi
|           table.
|
|           The letter is sent to the party that specified DAW.  If the claim is
|           DAW1, the prescriber receives the letter.  If it's  DAW2, the
|           participant receives the letter.
|
|
| INPUT:    TABLES ACCESSED BY CALLED MACROS ARE NOT LISTED BELOW
|           CLAIMSA.TRXCLM_BASE
|           CLAIMSA.TPRSCBR_PRESCRIBE1
|           CLAIMSA.TDRUG1
|           CLAIMSA.TGPITC_GPI_THR_CLS
|           CLAIMSA.TCONFLICT_RULE
|           CLAIMSA.TPRSCBR_CNFL_RULE
|           CLAIMSA.TBENEF_CNFL_RULE
|           CLAIMSA.TCPG_PB_TRL_HIST
|           CLAIMSA.TCLIENT1
|           HERCULES.TINITIATIVE
|           HERCULES.TCLT_BSRL_OVRD_HIS
|           HERCULES.TPHASE_RVR_FILE
|           HERCULES.TINITIATIVE_DATE
|           HERCULES.TPROGRAM_GPI_HIS
|           HERCULES.TGPI_MIN_AGE
|           HERCULES.TCMCTN_SBJ_NDC_HIS
|           SUMMARY.TCOPAY_PLAN_SUMM
|           SUMMARY.TDRUG_COV_LMT_SUMM
|
| OUTPUT:   standard files in /pending and /results directories
|
|
+-------------------------------------------------------------------------------
| HISTORY:  May 2005  - P.Wonders Yury Vilk  - Original Draft
|
|           Jul 2005  - G. Comerford - Modified date logic. Productionalize program.
|                                      Added %reset_sql_err_cd to updates of CLAIMS2
|                                      tables to prevent abend if no row updated.
|
|           Jul 2006  - B. Stropich  - Created the reset_apn_cmctn_id macro.  This 
|                                      macro resets all the apn_cmctn_id to 007765    
|                                      for the initiative due to the request from the
|                                      business side. 
|
|           Jan 2007  - B. Stropich  - Removed old logic which was incorrect with  
|                                      new logic based on the business users request
|                                      of a 10 day range. 
|                                      The new logic determines begin date by taking 
|                                      todays date and minus 10 day and end date by taking
|                                      todays date and minus 1  day.
|
|	    Mar  2007 - Greg Dudley Hercules Version  1.0    
|
|	    Aug  2007 - B. Stropich Hercules Version  1.5.01 
|                                      Business requested that the mailing be auto-release and
|                                      application cmctn id be assigned differently for the 
|                                      participant (007765) and the prescriber (007766).  The
|                                      change requires the following:
|                                      1.) modification to insert_scheduled_initiative.sas
|                                      2.) assigning ltr_rule_seq_nb of 1 to 007765 in the
|                                          hercules.tpgm_task_dom which is used in the 
|                                          check document macro
|                                      3.) comment out reset_apn_cmctn_id macro
|                                      4.) insert a few put _all_ statements into the code
|                                          to capture macro variables for hercules support
|
+-----------------------------------------------------------------------HEADER*/
**%LET sysmode=prod;
/*YM:Nov1,2012: Please uncommnet %reset_sql_err_cd; through out the code while moving to PROD */
%set_sysmode;
/* options sysparm='INITIATIVE_ID= PHASE_SEQ_NB=1';  */
OPTIONS MPRINT SOURCE2 MPRINTNEST MLOGIC MLOGICNEST symbolgen ; 
%INCLUDE "/herc&sysmode/prg/hercules/hercules_in.sas";
LIBNAME SUMMARY DB2 DSN=&UDBSPRP SCHEMA=SUMMARY;
LIBNAME SYSCAT DB2 DSN=&UDBSPRP SCHEMA=SYSCAT;
%let err_fl=0;
%LET PROGRAM_NAME=RETAIL_DAW;


*SASDOC ------------------------------------------------------------------------
| Find the latest billing_end_month for the Copay Summary table.
+-----------------------------------------------------------------------SASDOC*;

 PROC SQL NOPRINT;
   SELECT MAX(BILLING_END_MONTH)
         INTO :MAX_COPAY_DATE
   FROM SUMMARY.TCOPAY_PLAN_SUMM;
 QUIT;



* ---> Set the parameters for error checking;
 PROC SQL NOPRINT;
    SELECT QUOTE(TRIM(email)) INTO :Primary_programmer_email SEPARATED BY ' '
    FROM ADM_LKP.ANALYTICS_USERS
    WHERE UPCASE(QCP_ID) IN ("&USER");
 QUIT;

%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:(YM:Testing plz ignore)  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");


*SASDOC-------------------------------------------------------------------------
|  Update the job complete timestamp
+-----------------------------------------------------------------------SASDOC*;
%update_task_ts(job_start_ts);


*SASDOC-------------------------------------------------------------------------
|  Find the last claim date reviewed for this program-task.  This is the begin
|  date for this initiative.
|  bss 01.25.2007 - implemented a ten day range based on the users request.
+-----------------------------------------------------------------------SASDOC*;
data _null_;
      ** create DB2 date format;
      call symput('END_DT', "'"||put(today()-1, MMDDYY10.)||"'");
      call symput('BEGIN_DT',   "'"||put(today()-10, MMDDYY10.)||"'");
run;


%PUT BEGIN_DT=&BEGIN_DT;
%PUT END_DT=&END_DT;

PROC SQL;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
EXECUTE(
		DELETE FROM &HERCULES..TINITIATIVE_DATE
		WHERE INITIATIVE_ID = &INITIATIVE_ID.
)BY DB2;
DISCONNECT FROM DB2;
QUIT;



*SASDOC-------------------------------------------------------------------------
|  Insert the begin claim and end claim review dates into TINITIATIVE_DATE.
+-----------------------------------------------------------------------SASDOC*;
PROC SQL;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
  EXECUTE(
    INSERT INTO &HERCULES..TINITIATIVE_DATE
    VALUES (&INITIATIVE_ID, 5, &BEGIN_DT,
            'QCPAP020', CURRENT TIMESTAMP,'QCPAP020', CURRENT TIMESTAMP)
  )BY DB2;
DISCONNECT FROM DB2;
QUIT;

PROC SQL;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
  EXECUTE(
    INSERT INTO &HERCULES..TINITIATIVE_DATE
    VALUES (&INITIATIVE_ID, 6, &END_DT,
            'QCPAP020', CURRENT TIMESTAMP,'QCPAP020', CURRENT TIMESTAMP)
  )BY DB2;
DISCONNECT FROM DB2;
QUIT;

*SASDOC ------------------------------------------------------------------------
| Aug  2007 - B. Stropich
| Capture macro variables for hercules support.
+-----------------------------------------------------------------------SASDOC*;
%put _all_;

*SASDOC--------------------------------------------------------------------------
 | RETRIEVE THE CLAIM DATA
 | YM:OCT11,2012 : ADDED NEW BASE FIELDS AS PER ADD BASE COLUMNS PROJECT
 +------------------------------------------------------------------------SASDOC*;
/* %drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS);*/

%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS_A);
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS);
PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
    EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS_A 
       (PT_BENEFICIARY_ID  INTEGER,
               CDH_BENEFICIARY_ID INTEGER,
               NTW_PRESCRIBER_ID  INTEGER,
               CLIENT_ID INTEGER,
               PT_BIRTH_DT DATE,
               FORMULARY_IN SMALLINT,
               DRUG_NDC_ID DECIMAL(11) NOT NULL, 
			   NHU_TYPE_CD SMALLINT NOT NULL,
               DRUG_ABBR_PROD_NM CHAR(12),
               DRUG_ABBR_DSG_NM CHAR(3),
               DRUG_ABBR_STRG_NM CHAR(8),
               GPI_GROUP CHAR(2),
               GPI_CLASS CHAR(2),
               GPI_SUBCLASS CHAR(2),
               GPI_NAME CHAR(2),
               GPI_NAME_EXTENSION CHAR(2),
               GPI_FORM CHAR(2),
               GPI_STRENGTH CHAR(2),
               DAW_TYPE_CD SMALLINT,
               SBJ_ADDRESS1_TX CHAR(40),
               SBJ_ADDRESS2_TX CHAR(40),
               SBJ_CITY_TX CHAR(40),
               SBJ_STATE CHAR(2),
               SBJ_ZIP_CD CHAR(5),
               SBJ_ZIP_SUFFIX_CD CHAR(4),
			   MBR_ID VARCHAR(25),
			   LAST_FILL_DT DATE,
		   	   RX_NB CHARACTER(12),          /* NEW FIELDS FROM TRXCLM_BASE */
			   DISPENSED_QY DECIMAL(12,3),
			   DAY_SUPPLY_QY SMALLINT,
			   REFILL_FILL_QY SMALLINT,
			   FORMULARY_TX CHARACTER(30),
			   LAST_DELIVERY_SYS SMALLINT,
			   NABP_ID CHAR(7),
			   CLT_PLAN_GROUP_ID INTEGER,
			   GENERIC_NDC_IN DECIMAL(11,0),
			   GCN_CODE INTEGER,
			   BRAND_GENERIC CHAR(1)
					
) not logged initially) BY DB2;
  DISCONNECT FROM DB2;
QUIT;

 PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
     EXECUTE(ALTER TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS_A
             ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;


    EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX._CLAIMS_A
           (SELECT A.PT_BENEFICIARY_ID,
                   A.CDH_BENEFICIARY_ID,
                   A.NTW_PRESCRIBER_ID,
                   A.CLIENT_ID,
                   MAX(A.PT_BIRTH_DT)  AS PT_BIRTH_DT,
                   A.FORMULARY_IN,
                   A.DRUG_NDC_ID,
                   A.NHU_TYPE_CD,
                   MAX(B.DRUG_ABBR_PROD_NM) AS DRUG_ABBR_PROD_NM,
                   MAX(B.DRUG_ABBR_DSG_NM)      AS DRUG_ABBR_DSG_NM,
                   MAX(B.DRUG_ABBR_STRG_NM)     AS DRUG_ABBR_STRG_NM,
                   CAST(MAX(B.GPI_GROUP) AS CHAR(2)) AS GPI_GROUP,
                   CAST(MAX(B.GPI_CLASS) AS CHAR(2))AS GPI_CLASS,
                   CAST(MAX(B.GPI_SUBCLASS)AS CHAR(2))AS GPI_SUBCLASS,
                   CAST(MAX(B.GPI_NAME)AS CHAR(2)) AS GPI_NAME,
                   CAST(MAX(B.GPI_NAME_EXTENSION) AS CHAR(2)) AS GPI_NAME_EXTENSION,
                   CAST(MAX(B.GPI_FORM)AS CHAR(2)) AS GPI_FORM,
                   CAST(MAX(B.GPI_STRENGTH)AS CHAR(2))AS GPI_STRENGTH,
                   A.DAW_TYPE_CD,
                   MAX(ADDRESS_LINE1_TX)        AS ADDRESS_LINE1_TX,
                   MAX(ADDRESS_LINE2_TX)        AS ADDRESS_LINE2_TX,
                   MAX(CITY_TX)                         AS CITY_TX,
                   MAX(STATE)                           AS STATE,
                   MAX(ZIP_CD)                          AS ZIP_CD,
                   MAX(ZIP_SUFFIX_CD)           AS ZIP_SUFFIX_CD,
				   C.BENEFICIARY_ID               AS MBR_ID,
				   MAX(A.FILL_DT)  AS LAST_FILL_DT ,
		   		   MAX(A.RX_NB),          /* NEW FIELDS FROM TRXCLM_BASE */
				   SUM(A.DISPENSED_QY) ,
				   SUM(A.DAY_SUPPLY_QY),
				   SUM(A.REFILL_NB) as REFILL_FILL_QY,
				   CAST(MAX(A.FORMULARY_ID) as char(30)) as FORMULARY_TX,
				   MAX(A.DELIVERY_SYSTEM_CD) as LAST_DELIVERY_SYS,
				   MAX(A.NABP_ID),
				   MAX(A.CLT_PLAN_GROUP_ID),
				   B.GENERIC_NDC_IN,
				   B.DGH_GCN_CD as GCN_CODE,
				   B.DRUG_BRAND_CD as BRAND_GENERIC
				   
          FROM  &CLAIMSA..TRXCLM_BASE A,
                &CLAIMSA..TDRUG1 B,
                &HERCULES..TPROGRAM_NDC BB,
                &CLAIMSA..TBENEF_ADDRESS_DN C

          WHERE A.DRUG_NDC_ID = B.DRUG_NDC_ID
          AND   B.DRUG_NDC_ID = BB.DRUG_NDC_ID
          AND   BB.PROGRAM_ID=&PROGRAM_ID
        /*  AND   CURRENT DATE BETWEEN BB.EFFECTIVE_DT AND BB.EXPIRATION_DT */
          AND   BB.EFFECTIVE_DT  <= CURRENT DATE
          AND   BB.EXPIRATION_DT >= CURRENT DATE
          AND   A.NHU_TYPE_CD = B.NHU_TYPE_CD
          AND   A.PT_BENEFICIARY_ID = C.BENEFICIARY_ID
          AND   A.DELIVERY_SYSTEM_CD = 3
          AND   A.DAW_TYPE_CD IN (1,2)
          AND   COALESCE(B.DRUG_MAINT_IN, B.DGH_EXT_MNT_IN) = 1
          AND   B.DRUG_BRAND_CD = 'B'
          AND   B.GENERIC_AVAIL_IN = 1
          AND  ((B.DISCONTINUANCE_DT > (CURRENT DATE - 3 YEARS))
                      OR B.DISCONTINUANCE_DT IS NULL)

        /*  AND   A.FILL_DT BETWEEN &BEGIN_DT AND CURRENT DATE - 1 DAY */
          AND   A.FILL_DT >= &BEGIN_DT
          AND   A.FILL_DT <= &END_DT

          AND NOT EXISTS
                (SELECT 1 FROM &CLAIMSA..TRXCLM_BASE
                               WHERE A.BENEFIT_REQUEST_ID = BENEFIT_REQUEST_ID
                               AND A.BRLI_NB = BRLI_NB
                               AND BRLI_VOID_IN > 0)
          GROUP BY A.PT_BENEFICIARY_ID,
                   A.CDH_BENEFICIARY_ID,
                   A.NTW_PRESCRIBER_ID,
                   A.CLIENT_ID,
                   A.FORMULARY_IN,
                   A.DRUG_NDC_ID,
                   A.NHU_TYPE_CD,
                   A.DAW_TYPE_CD,
				   C.BENEFICIARY_ID,
				   B.GENERIC_NDC_IN,
				   B.DGH_GCN_CD,
				   B.DRUG_BRAND_CD
				   
/*				   &ADD_BASE_GROUP_BY. /* GROUP BY CONDITION FOR ADD BASE COLUMNS */				
       HAVING COUNT(*)>0) ) BY DB2;

    DISCONNECT FROM DB2;
 QUIT;
 %set_error_fl;

PROC SQL;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
CREATE TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS AS

		(SELECT 		 
				 A.*, 
				 H.BLG_REPORTING_CD ,  
				 H.PLAN_CD,
				 H.PLAN_EXTENSION_CD as PLAN_EXT_CD_TX,
				 H.GROUP_CD,
				 H.GROUP_EXTENSION_CD as GROUP_EXT_CD_TX,
				 H.CLIENT_ID as CLIENT_LEVEL_1 ,
				 H.GROUP_CD as CLIENT_LEVEL_2,
				 H.BLG_REPORTING_CD as CLIENT_LEVEL_3,
				 K.PRESCRIBER_DEA_NB as DEA_NB,
 				 K.PRESCRIBER_NPI_NB,
				 L.PHARMACY_NM

		FROM &DB2_TMP..&TABLE_PREFIX._CLAIMS_A A LEFT JOIN
			 &CLAIMSA..TCPGRP_CLT_PLN_GR1 H ON 
					  A.CLT_PLAN_GROUP_ID = H.CLT_PLAN_GROUP_ID

		 LEFT JOIN &CLAIMSA..TPRSCBR_PRESCRIBE1 K ON
				    A.NTW_PRESCRIBER_ID = K.PRESCRIBER_ID
		
		 LEFT JOIN &CLAIMSA..TPHARM_PHARMACY L ON
				   A.NABP_ID = L.NABP_ID
);
DISCONNECT FROM DB2;
QUIT; 


 *SASDOC--------------------------------------------------------------------------
 | Eliminate participants for who received RTIP or RDAW letter on the same target
 | drug within the past six months. Drug is targeted at strength level, ignoring
 | package size.
 +------------------------------------------------------------------------SASDOC*;

PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
          EXECUTE(DELETE FROM &DB2_TMP..&TABLE_PREFIX._CLAIMS X
                  WHERE EXISTS
                    (SELECT Z.SUBJECT_ID,
                            Z.DRUG_NDC_ID
                     FROM &HERCULES..TINITIATIVE A,
                          &HERCULES..TPHASE_RVR_FILE B,
                          &HERCULES..TCMCTN_SBJ_NDC_HIS Z
                     WHERE A.INITIATIVE_ID = B.INITIATIVE_ID
                     AND   A.INITIATIVE_ID = Z.INITIATIVE_ID
                     AND   A.PROGRAM_ID in (123)
                     AND   B.RELEASE_TS > CURRENT TIMESTAMP - 180 DAYS
                     AND   Z.SUBJECT_ID = X.PT_BENEFICIARY_ID
                     AND   INTEGER(Z.DRUG_NDC_ID/100) = INTEGER(X.DRUG_NDC_ID/100)

                   )) BY DB2;
/*        %reset_sql_err_cd;*/
 DISCONNECT FROM DB2;
 QUIT;
 %set_error_fl;

PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
               EXECUTE(DELETE FROM &DB2_TMP..&TABLE_PREFIX._CLAIMS X
                  WHERE EXISTS
                    (SELECT Z.SUBJECT_ID,
                            Z.DRUG_NDC_ID
                     FROM &HERCULES..TINITIATIVE A,
                          &HERCULES..TPHASE_RVR_FILE B,
                          &HERCULES..TCMCTN_SBJ_NDC_HIS Z
                     WHERE A.INITIATIVE_ID = B.INITIATIVE_ID
                     AND   A.INITIATIVE_ID = Z.INITIATIVE_ID
                     AND   A.PROGRAM_ID in (86)
                     AND   B.RELEASE_TS BETWEEN (CURRENT TIMESTAMP -180 DAYS) AND (CURRENT TIMESTAMP -90 DAYS)
                     AND   Z.SUBJECT_ID = X.PT_BENEFICIARY_ID
                     AND   INTEGER(Z.DRUG_NDC_ID/100) = INTEGER(X.DRUG_NDC_ID/100)
                   )) BY DB2;

/*  %reset_sql_err_cd;*/

 DISCONNECT FROM DB2;
 QUIT;
 %set_error_fl;


 %runstats(tbl_name=&db2_tmp..&table_prefix._claims);
*SASDOC-------------------------------------------------------------------------
| Find the NDCs that have age restrictions.
+-----------------------------------------------------------------------SASDOC*;

%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._AGE_LMT);
%set_error_fl;

 PROC SQL;
  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
     EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._AGE_LMT
              (
               GPI_GROUP CHAR(2),
               GPI_CLASS CHAR(2),
               GPI_SUBCLASS CHAR(2),
               GPI_NAME CHAR(2),
               GPI_NAME_EXTENSION CHAR(2),
               GPI_FORM CHAR(2),
               GPI_STRENGTH CHAR(2),
               MIN_AGE_NB SMALLINT)) BY DB2;
   DISCONNECT FROM DB2;
 QUIT;

PROC SQL;
  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
     EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX._AGE_LMT
              SELECT
                     CAST(SUBSTR(GPI_CD,01,2) AS CHAR(2)) AS GPI_GROUP
                    ,CAST(NULLIF(SUBSTR(GPI_CD,03,2),'  ') AS CHAR(2)) AS GPI_CLASS
                    ,CAST(NULLIF(SUBSTR(GPI_CD,05,2),'  ') AS CHAR(2)) AS GPI_SUBCLASS
                    ,CAST(NULLIF(SUBSTR(GPI_CD,07,2),'  ') AS CHAR(2)) AS GPI_NAME
                    ,CAST(NULLIF(SUBSTR(GPI_CD,09,2),'  ') AS CHAR(2)) AS GPI_NAME_EXTENSION
                    ,CAST(NULLIF(SUBSTR(GPI_CD,11,2),'  ') AS CHAR(2)) AS GPI_FORM
                    ,CAST(NULLIF(SUBSTR(GPI_CD,13,2),'  ') AS CHAR(2)) AS GPI_STRENGTH
                    ,MIN_AGE_NB
              FROM &HERCULES..TGPI_MIN_AGE
              WHERE ACTIVE_IN = 1)BY DB2;
  DISCONNECT FROM DB2;
QUIT;

%RUNSTATS(db_name=UDBSPRP, TBL_NAME=&DB2_TMP..&TABLE_PREFIX._AGE_LMT);



 *SASDOC--------------------------------------------------------------------------
 | Eliminate participants that do not qualify based on age criteria.
 +------------------------------------------------------------------------SASDOC*;

PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
          EXECUTE(DELETE FROM &DB2_TMP..&TABLE_PREFIX._CLAIMS A
                  WHERE EXISTS
                    (SELECT 1
                     FROM &DB2_TMP..&TABLE_PREFIX._AGE_LMT B
                     WHERE   A.GPI_GROUP = B.GPI_GROUP
                     AND   YEAR(CURRENT DATE - PT_BIRTH_DT) < MIN_AGE_NB
                     AND   (A.GPI_CLASS = B.GPI_CLASS OR B.GPI_CLASS IS NULL)
                     AND   (A.GPI_SUBCLASS = B.GPI_SUBCLASS OR B.GPI_SUBCLASS IS NULL)
                     AND   (A.GPI_NAME = B.GPI_NAME OR B.GPI_NAME IS NULL)
                     AND   (A.GPI_NAME_EXTENSION = B.GPI_NAME_EXTENSION OR B.GPI_NAME_EXTENSION IS NULL)
                     AND   (A.GPI_FORM = B.GPI_FORM OR B.GPI_FORM IS NULL)
                     AND   (A.GPI_STRENGTH = B.GPI_STRENGTH OR B.GPI_STRENGTH IS NULL))) BY DB2;
/* %reset_sql_err_cd;*/
  DISCONNECT FROM DB2;
 QUIT;


 *SASDOC--------------------------------------------------------------------------
 | When letter is sent to the prescriber, eliminate prescribers that are turned
 | off to DAW.  Note that only one conflict needs to be turned off in the DAW
 | program. It is standard practice to turn prescribers off to all 4 DAW conflicts.
 +------------------------------------------------------------------------SASDOC*;

 PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
          EXECUTE(DELETE FROM &DB2_TMP..&TABLE_PREFIX._CLAIMS X
                  WHERE EXISTS
                    (SELECT 1
                     FROM &CLAIMSA..TPRSCBR_CNFL_RULE A,
                          &CLAIMSA..TCONFLICT_RULE B
                     WHERE X.NTW_PRESCRIBER_ID = A.PRESCRIBER_ID
                     AND B.PROBLEM_CD IN (10,29)
                     AND   A.CONFLICT_RULE_ID = B.CONFLICT_RULE_ID)
                  AND DAW_TYPE_CD = 1) BY DB2;
/* %reset_sql_err_cd;*/
  DISCONNECT FROM DB2;
 QUIT;


 *SASDOC--------------------------------------------------------------------------
 | Eliminate prescribers that are turned off to either participant specific
 | mailings (PRCBR_MLG_PRMSN_CD>0) or prescriber is active (PRCBR_STATUS_CD > 0).
  Only eliminate them if the daw_type is "prescriber".
 +------------------------------------------------------------------------SASDOC*;

 /*Question. PRCBR_MLG_PRMSN_CD > 0 ? */

 PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
          EXECUTE(DELETE FROM &DB2_TMP..&TABLE_PREFIX._CLAIMS X
                  WHERE EXISTS
                    (SELECT DISTINCT PRESCRIBER_ID
                     FROM &CLAIMSA..TPRSCBR_PRESCRIBE1 A
                     WHERE X.NTW_PRESCRIBER_ID = A.PRESCRIBER_ID
                     AND   (A.PBR_CLASS_CD <> 1
                            OR    A.PRCBR_MLG_PRMSN_CD > 0
                            OR    A.PRCBR_STATUS_CD > 0))
                  AND DAW_TYPE_CD = 1) BY DB2;
/* %reset_sql_err_cd;*/
  DISCONNECT FROM DB2;
 QUIT;

 *SASDOC--------------------------------------------------------------------------
 | Eliminate participants that that are turned off to DAW.
 +------------------------------------------------------------------------SASDOC*;

PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
          EXECUTE(DELETE FROM &DB2_TMP..&TABLE_PREFIX._CLAIMS X
                  WHERE EXISTS
                    (SELECT 1
                     FROM &CLAIMSA..TBENEF_CNFL_RULE A,
                          &CLAIMSA..TCONFLICT_RULE B
                     WHERE X.PT_BENEFICIARY_ID = A.BENEFICIARY_ID
                     AND   B.PROBLEM_CD IN (10,29)
                     AND   A.CONFLICT_RULE_ID = B.CONFLICT_RULE_ID)) BY DB2;
/* %reset_sql_err_cd;*/
  DISCONNECT FROM DB2;
 QUIT;

 *SASDOC--------------------------------------------------------------------------
 | CALL %eligibility_check
 | Find the last cpg for each beneficiary that is eligible
 +------------------------------------------------------------------------SASDOC*;
   %eligibility_check(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._CLAIMS,
                      TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG);
   %runstats(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG);

*SASDOC--------------------------------------------------------------------------
 | Call resolve client and eliminate client/plans that shouldn't be included.
 +------------------------------------------------------------------------SASDOC*;

   /*Question? Are Clients only excluded? */

 %resolve_client(TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CLT_CPG) ;

 PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
          EXECUTE(DELETE FROM &DB2_TMP..&TABLE_PREFIX._CPG_ELIG X
                  WHERE CLT_PLAN_GROUP_ID IN
                    (SELECT CLT_PLAN_GROUP_ID
                     FROM &DB2_TMP..&TABLE_PREFIX._CLT_CPG)) BY DB2;
/* %reset_sql_err_cd;*/
  DISCONNECT FROM DB2;
 QUIT;


*SASDOC--------------------------------------------------------------------------
 | CALL %get_moc_phone
 | Add the Mail Order pharmacy and customer service phone.
 +------------------------------------------------------------------------SASDOC*;
  %get_moc_csphone(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG,
                   TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG_PHN);


 *SASDOC--------------------------------------------------------------------------
 | When the Physician specified DAW, set the letter rule code to zero (MD letter).
 | Get the therapeutic class name based on GPI-10 and the copay information.  The
 | brand copay depends on the formulary status of the drug.  Set the letter rule
 | to 1 (include copay) by default but if the plan has the following features,
 | the letter rule is set to 2 (no copay letter):  deductibles, DAW penalty,
 | coinsurance, stepped copays or no savings between the brand and generic at a
 | delivery system.
 |
 | Also added copay saving calculation based on 90 days supply
 |
 +------------------------------------------------------------------------SASDOC*;

 %drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS2);

 PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
    EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS2
       (    PT_BENEFICIARY_ID  INTEGER,
            CDH_BENEFICIARY_ID INTEGER,
            NTW_PRESCRIBER_ID  INTEGER,
            POS_PB_ID INTEGER,
            MAIL_PB_ID INTEGER,
            CLIENT_ID INTEGER,
            CLIENT_NM CHAR(30),
            BIRTH_DT DATE,
            MOC_PHM_CD CHAR(3),
            CS_AREA_PHONE CHAR(13),
            FORMULARY_IN SMALLINT,
            DRUG_NDC_ID DECIMAL(11) NOT NULL,
            NHU_TYPE_CD SMALLINT NOT NULL,
            DRUG_ABBR_PROD_NM CHAR(12),
            DRUG_ABBR_DSG_NM CHAR(3),
            DRUG_ABBR_STRG_NM CHAR(8),
            GPI_THERA_CLS_NM CHAR(60),
            POS_BRD_C_AT DECIMAL(11,2),
            POS_GENC_C_AT DECIMAL(11,2),
            POS_SAVINGS_AT  DECIMAL(11,2),
            MAIL_BRD_C_AT DECIMAL(11,2),
            MAIL_GENC_C_AT DECIMAL(11,2),
            MAIL_SAVINGS_AT DECIMAL(11,2),
            LTR_RULE_SEQ_NB SMALLINT,
            ANNUAL_FILL_QY INTEGER,
            SBJ_ADDRESS1_TX CHAR(40),
            SBJ_ADDRESS2_TX CHAR(40),
            SBJ_CITY_TX CHAR(40),
            SBJ_STATE CHAR(2),
            SBJ_ZIP_CD CHAR(5),
            SBJ_ZIP_SUFFIX_CD CHAR(4),
			LAST_FILL_DT DATE, /* NEW FIELDS FROM TRXCLM_BASE */
		   	RX_NB CHAR(12),          
			DISPENSED_QY DECIMAL(12,3),
			DAY_SUPPLY_QY SMALLINT,
			FORMULARY_TX CHARACTER(30),
		    GENERIC_NDC_IN DECIMAL(11),/* NEW FIELDS FROM TDRUG */	
			BLG_REPORTING_CD CHAR(15) , /* NEW FIELDS FROM TCPGRP_CLT_PLN_GR1 */ 
			PLAN_CD CHAR(8),
			PLAN_EXT_CD_TX CHAR(8),
			GROUP_CD CHAR(15),
			GROUP_EXT_CD_TX CHAR(5),
			CLIENT_LEVEL_1 CHAR(20),
			CLIENT_LEVEL_2 CHAR(15),
			CLIENT_LEVEL_3 CHAR(15),
			MBR_ID CHAR(25),
			LAST_DELIVERY_SYS SMALLINT,
			GCN_CODE INTEGER ,
			BRAND_GENERIC CHAR(1)    ,
			DEA_NB CHAR(9),
 			PRESCRIBER_NPI_NB CHAR(10),
			PHARMACY_NM CHAR(30),
			GPI_THERA_CLS_CD CHAR(14)


)NOT LOGGED INITIALLY) BY DB2;

 DISCONNECT FROM DB2;
 QUIT;

PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
     EXECUTE(ALTER TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS2
             ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;


     EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX._CLAIMS2
           (  SELECT DISTINCT
                   a.PT_BENEFICIARY_ID,
                   a.CDH_BENEFICIARY_ID,
                   c.NTW_PRESCRIBER_ID,
                   CPY_POS.PB_ID,
                   CPY_MOR.PB_ID,
                   c.CLIENT_ID,
                   clt.CLIENT_NM,
                   c.PT_BIRTH_DT,
                   a.MOC_PHM_CD,
                   a.CS_AREA_PHONE,
                   c.FORMULARY_IN,
                   c.DRUG_NDC_ID,
                   c.NHU_TYPE_CD,
                   c.DRUG_ABBR_PROD_NM,
                   c.DRUG_ABBR_DSG_NM,
                   c.DRUG_ABBR_STRG_NM,
                   gpi.GPI_THERA_CLS_NM,
                  COALESCE(
                   (CASE FORMULARY_IN
                      WHEN 3 THEN CPY_POS.FRMBRD_COPAY_AT
                      WHEN 4 THEN CPY_POS.FRMBRD_COPAY_AT
                      WHEN 5 THEN CPY_POS.NONFRM_COPAY_AT
                      ELSE CPY_POS.BRD_COPAY_AT
                   END)*3,0) AS POS_BRD_C_AT,

                  COALESCE(CPY_POS.GENC_COPAY_AT*3,0) AS POS_GENC_C_AT, /* convert to 90 days */
                   (COALESCE( (CASE FORMULARY_IN
                      WHEN 3 THEN CPY_POS.FRMBRD_COPAY_AT
                      WHEN 4 THEN CPY_POS.FRMBRD_COPAY_AT
                      WHEN 5 THEN CPY_POS.NONFRM_COPAY_AT
                      ELSE CPY_POS.BRD_COPAY_AT
                   END),0) -
                    COALESCE( CPY_POS.GENC_COPAY_AT,0)
                     )*3        AS POS_SAVINGS_AT,  /* POS_SAVING 90days */
                CASE WHEN CPY_MOR.PB_ID IS NULL THEN NULL
                ELSE
                   COALESCE(
                   (CASE FORMULARY_IN
                      WHEN 3 THEN CPY_MOR.FRMBRD_COPAY_AT
                      WHEN 4 THEN CPY_MOR.FRMBRD_COPAY_AT
                      WHEN 5 THEN CPY_MOR.NONFRM_COPAY_AT
                      ELSE CPY_MOR.BRD_COPAY_AT
                   END) ,0)
                 END,
                CASE WHEN CPY_MOR.PB_ID IS NULL THEN NULL
                    ELSE
                   COALESCE(CPY_MOR.GENC_COPAY_AT,0) END,

                CASE WHEN CPY_MOR.PB_ID IS NULL THEN NULL
                    ELSE
                   COALESCE(  (CASE FORMULARY_IN
                      WHEN 3 THEN CPY_MOR.FRMBRD_COPAY_AT
                      WHEN 4 THEN CPY_MOR.FRMBRD_COPAY_AT
                      WHEN 5 THEN CPY_MOR.NONFRM_COPAY_AT
                      ELSE CPY_MOR.BRD_COPAY_AT
                   END),0) -
                   COALESCE (CPY_MOR.GENC_COPAY_AT,0) END,  /*MAIL_SAVING */

                   CASE
                      WHEN DAW_TYPE_CD = 1 THEN 0
                      WHEN CPY_MOR.BRD_COPAY_RT IS NOT NULL THEN 2
                      WHEN CPY_MOR.GENC_COPAY_RT IS NOT NULL THEN 2
                      WHEN CPY_MOR.BRDNGENC_COPAY_RT IS NOT NULL THEN 2
                      WHEN CPY_MOR.FRMBRD_COPAY_RT IS NOT NULL THEN 2
                      WHEN CPY_MOR.NONFRM_COPAY_RT IS NOT NULL THEN 2
                      WHEN CPY_MOR.CALC_STY_CD > 0 THEN 2
                      WHEN CPY_MOR.CALC_DAW_CD > 0 THEN 2
                      WHEN CPY_MOR.DEDUCTIBLE_CD > 0 THEN 2
                      WHEN CPY_POS.BRD_COPAY_RT IS NOT NULL THEN 2
                      WHEN CPY_POS.GENC_COPAY_RT IS NOT NULL THEN 2
                      WHEN CPY_POS.BRDNGENC_COPAY_RT IS NOT NULL THEN 2
                      WHEN CPY_POS.FRMBRD_COPAY_RT IS NOT NULL THEN 2
                      WHEN CPY_POS.NONFRM_COPAY_RT IS NOT NULL THEN 2
                      WHEN CPY_POS.CALC_STY_CD > 0 THEN 2
                      WHEN CPY_POS.CALC_DAW_CD > 0 THEN 2
                      WHEN CPY_POS.DEDUCTIBLE_CD > 0 THEN 2
                      ELSE 1
                   END,
                   ANNUAL_FILL_QY,
				   SBJ_ADDRESS1_TX,
                   SBJ_ADDRESS2_TX,
                   SBJ_CITY_TX,
                   SBJ_STATE,
                   SBJ_ZIP_CD,
                   SBJ_ZIP_SUFFIX_CD,
                   C.LAST_FILL_DT,
				   C.RX_NB, 
				   C.DISPENSED_QY ,
				   C.DAY_SUPPLY_QY,
				   C.FORMULARY_TX,
				   C.GENERIC_NDC_IN,
				   C.BLG_REPORTING_CD ,
				   C.PLAN_CD,
				   C.PLAN_EXT_CD_TX,
				   C.GROUP_CD,
				   C.GROUP_EXT_CD_TX,
				   C.CLIENT_LEVEL_1 ,
				   C.CLIENT_LEVEL_2,
                   C.CLIENT_LEVEL_3,
				   C.MBR_ID,
                   C.LAST_DELIVERY_SYS,
				   C.GCN_CODE,
				   C.BRAND_GENERIC,
				   C.DEA_NB,
				   C.PRESCRIBER_NPI_NB,
				   C.PHARMACY_NM,
				   CAST(C.GPI_GROUP AS CHAR(2))||CAST(C.GPI_CLASS AS CHAR(2))||CAST(C.GPI_SUBCLASS AS CHAR(2))||CAST(C.GPI_NAME AS CHAR(2))||CAST(C.GPI_NAME_EXTENSION AS CHAR(2))||CAST(C.GPI_FORM AS CHAR(2))||CAST(C.GPI_STRENGTH AS CHAR(2)) AS GPI_THERA_CLS_CD

          FROM
                (((((((&DB2_TMP..&TABLE_PREFIX._CPG_ELIG_PHN A INNER JOIN
                CLAIMSA.TCPG_PB_TRL_HIST B
          ON    A.CLT_PLAN_GROUP_ID = B.CLT_PLAN_GROUP_ID
          AND   CURRENT DATE BETWEEN B.EFF_DT AND B.EXP_DT
          AND   B.DELIVERY_SYSTEM_CD = 3) INNER JOIN
                &DB2_TMP..&TABLE_PREFIX._CLAIMS C
          ON    A.PT_BENEFICIARY_ID = C.PT_BENEFICIARY_ID) INNER JOIN
                CLAIMSA.TCLIENT1 CLT
          ON    CLT.CLIENT_ID = c.CLIENT_ID) INNER JOIN
                SUMMARY.TCOPAY_PLAN_SUMM CPY_POS
          ON    CPY_POS.PB_ID = B.PB_ID
          AND   CPY_POS.BILLING_END_MONTH = &MAX_COPAY_DATE
          AND   CPY_POS.DELIVERY_SYSTEM_CD=3) INNER JOIN
                SUMMARY.TDRUG_COV_LMT_SUMM C
          ON    C.PB_ID = B.PB_ID
          AND   C.BILLING_END_MONTH = &MAX_COPAY_DATE
          AND   DRUG_CATEGORY_ID = 59 ) INNER JOIN
                claimsa.TGPITC_GPI_THR_CLS GPI
          ON    SUBSTR(GPI.GPI_THERA_CLS_CD, 1,2) = GPI_GROUP
          AND   SUBSTR(GPI.GPI_THERA_CLS_CD, 3,2) = GPI_CLASS
          AND   SUBSTR(GPI.GPI_THERA_CLS_CD, 5,2) = GPI_SUBCLASS
          AND   SUBSTR(GPI.GPI_THERA_CLS_CD, 7,2) = GPI_NAME
          AND   SUBSTR(GPI.GPI_THERA_CLS_CD, 9,2) = GPI_NAME_EXTENSION
                  AND   SUBSTR(GPI.GPI_THERA_CLS_CD, 11,2) = GPI_FORM
                  AND   SUBSTR(GPI.GPI_THERA_CLS_CD, 13,2) = GPI_STRENGTH
          AND   GPI_REC_TYP_CD = '5') LEFT JOIN
                (SELECT AA.CLT_PLAN_GROUP_ID,
                        CPY_M.*

                FROM &DB2_TMP..&TABLE_PREFIX._CPG_ELIG_PHN AA,
                CLAIMSA.TCPG_PB_TRL_HIST BB, SUMMARY.TCOPAY_PLAN_SUMM CPY_M
          WHERE AA.CLT_PLAN_GROUP_ID = BB.CLT_PLAN_GROUP_ID
          AND   BB.PB_ID = CPY_M.PB_ID
          AND   CURRENT DATE BETWEEN BB.EFF_DT AND BB.EXP_DT
          AND   BB.DELIVERY_SYSTEM_CD = 2
          AND   BB.DELIVERY_SYSTEM_CD = CPY_M.DELIVERY_SYSTEM_CD
          AND   CPY_M.BILLING_END_MONTH = &MAX_COPAY_DATE)
               CPY_MOR
          ON    B.CLT_PLAN_GROUP_ID = CPY_MOR.CLT_PLAN_GROUP_ID)

    )) BY DB2;
    DISCONNECT FROM DB2;
 QUIT;
 %set_error_fl;

PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
    create table check_copay as
    select * from connection to db2
    (select a.*
      from SUMMARY.TCOPAY_PLAN_SUMM A, &DB2_TMP..&TABLE_PREFIX._CLAIMS2 B
      WHERE BILLING_END_MONTH=&MAX_COPAY_DATE
        AND A.PB_ID=B.POS_PB_ID);
     DISCONNECT FROM DB2;
  QUIT;


%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");


%runstats(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CLAIMS2);


PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
     EXECUTE(UPDATE &DB2_TMP..&TABLE_PREFIX._CLAIMS2
             SET LTR_RULE_SEQ_NB = 2
             WHERE (POS_BRD_C_AT  <= POS_GENC_C_AT
             OR   MAIL_BRD_C_AT  <= MAIL_GENC_C_AT)
              AND  LTR_RULE_SEQ_NB = 1)BY DB2;
/* %reset_sql_err_cd;*/
    DISCONNECT FROM DB2;
QUIT;
%set_error_fl;

 *SASDOC--------------------------------------------------------------------------
 | Send the no copay letter if the member has Retail only.
 +------------------------------------------------------------------------SASDOC*;

PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
     EXECUTE(UPDATE &DB2_TMP..&TABLE_PREFIX._CLAIMS2
             SET LTR_RULE_SEQ_NB = 2
             WHERE  MAIL_BRD_C_AT IS NULL
             AND LTR_RULE_SEQ_NB = 1)BY DB2;
/* %reset_sql_err_cd;*/
    DISCONNECT FROM DB2;
QUIT;
%set_error_fl;

 *SASDOC--------------------------------------------------------------------------
 | Do not target plans that have the annual fill restriction for the drug unless
 | the business rule has been overridden.
 | Removed per Peggy 05/02/2005
 +------------------------------------------------------------------------SASDOC*;

/*
PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
          EXECUTE(DELETE FROM &DB2_TMP..&TABLE_PREFIX._CLAIMS2 X
                  WHERE ANNUAL_FILL_QY IS NOT NULL
                  AND CLIENT_ID NOT IN
                    (SELECT CLIENT_ID
                     FROM &HERCULES..TCLT_BSRL_OVRD_HIS
                     WHERE PROGRAM_ID = &PROGRAM_ID
                     AND BUS_RULE_TYPE_CD = 1
                     AND CURRENT TIMESTAMP BETWEEN EFFECTIVE_TS AND EXPIRATION_TS)) BY DB2;
 %reset_sql_err_cd;
 QUIT;
*/

*SASDOC-------------------------------------------------------------------------
| Call %create_base_file
+-----------------------------------------------------------------------SASDOC*;
%LET ERR_FL=0;

OPTIONS MPRINT MLOGIC;
%LET DEBUG_FLAG=Y;
%create_base_file(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._CLAIMS2);
%set_error_fl;
%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");
*SASDOC-------------------------------------------------------------------------
| Call %check_document to see if the Stellent id(s) have been attached.
+-----------------------------------------------------------------------SASDOC*;
%check_document;

*SASDOC ------------------------------------------------------------------------
| Aug  2007 - B. Stropich
| Capture macro variables for hercules support.
+-----------------------------------------------------------------------SASDOC*;
%put _all_;

*SASDOC--------------------------------------------------------------------------
| SET APN_CMCTN_ID TO 007765 - DAW promote generics Retail ppts without co-pay info
| In reference to H02685228 - bss
+------------------------------------------------------------------------SASDOC*;

DATA WORK.TPHASE_RVR_FILE;
     SET &HERCULES..TPHASE_RVR_FILE(WHERE=(INITIATIVE_ID=&INITIATIVE_ID
                                AND PHASE_SEQ_NB=&PHASE_SEQ_NB));
     KEEP CMCTN_ROLE_CD FILE_ID;
RUN;
DATA _NULL_;
     SET TPHASE_RVR_FILE END=FILE_END;
     IF FILE_END THEN CALL SYMPUT('N_files', PUT(_n_,1.) );
RUN;

%let TABLE_PREFIX_LOWCASE = %lowcase(&TABLE_PREFIX.);

%macro reset_apn_cmctn_id;

  %do j = 1 %to &N_files. ;
  
  %put set apn_cmctn_id to 007765 for the following dataset: &TABLE_PREFIX_LOWCASE._&j. ;
  
    ** set values to the datasets in the pending directory ;
    %if %SYSFUNC(EXIST(DATA_PND.&TABLE_PREFIX_LOWCASE._&j.)) %then %do;
    
        proc sort data = DATA_PND.&TABLE_PREFIX_LOWCASE._&j. 
                  out  = test (keep = apn_cmctn_id) nodupkey;
          by apn_cmctn_id;
        run;
        
        data _null_;
         length status $100 ;
         set test;
         status="DATA_PND.&TABLE_PREFIX_LOWCASE._&j. BEFORE SETTING APN_CMCTN_ID";
         put _all_;
        run;
  
  	data DATA_PND.&TABLE_PREFIX_LOWCASE._&j. ;
  	 set DATA_PND.&TABLE_PREFIX_LOWCASE._&j. ;
  	  apn_cmctn_id='007765';
  	run;
  	
        proc sort data = DATA_PND.&TABLE_PREFIX_LOWCASE._&j. 
                  out  = test (keep = apn_cmctn_id) nodupkey;
          by apn_cmctn_id;
        run;
        
        data _null_;
         length status $100 ;
         set test;
         status="DATA_PND.&TABLE_PREFIX_LOWCASE._&j. AFTER SETTING APN_CMCTN_ID";
         put _all_;
        run;  	
  
    %end;
    
    ** set values to the datasets in the results directory ;
    %if %SYSFUNC(EXIST(DATA_RES.&TABLE_PREFIX_LOWCASE._&j.)) %then %do;
    
        proc sort data = DATA_RES.&TABLE_PREFIX_LOWCASE._&j. 
                  out  = test (keep = apn_cmctn_id) nodupkey;
          by apn_cmctn_id;
        run;    
        
        data _null_;
         length status $100 ;
         set test;
         status="DATA_RES.&TABLE_PREFIX_LOWCASE._&j BEFORE SETTING APN_CMCTN_ID";
         put _all_;
        run;
  
  	data DATA_RES.&TABLE_PREFIX_LOWCASE._&j. ;
  	 set DATA_RES.&TABLE_PREFIX_LOWCASE._&j. ;
  	  apn_cmctn_id='007765';
  	run;
  	
        proc sort data = DATA_RES.&TABLE_PREFIX_LOWCASE._&j. 
                  out  = test (keep = apn_cmctn_id) nodupkey;
          by apn_cmctn_id;
        run; 
        
        data _null_;
         length status $100 ;
         set test;
         status="DATA_RES.&TABLE_PREFIX_LOWCASE._&j AFTER SETTING APN_CMCTN_ID";
         put _all_;
        run;
  
    %end;  
    
  %end; 

%mend reset_apn_cmctn_id;


*SASDOC-------------------------------------------------------------------------
| Aug  2007 - B. Stropich 
| Comment out reset_apn_cmctn_id macro from the process that assigns all participants
| and presribers 007765.
+-----------------------------------------------------------------------SASDOC*;
**%reset_apn_cmctn_id;

*SASDOC-------------------------------------------------------------------------
| Check for autorelease of file.
+-----------------------------------------------------------------------SASDOC*;
%autorelease_file(INIT_ID=&INITIATIVE_ID, PHASE_ID=&PHASE_SEQ_NB);

*SASDOC-------------------------------------------------------------------------
| Insert distinct recipients into TCMCTN_PENDING if the file is not autorelease.
| The user will receive an email with the initiative summary report.  If the
| file is autoreleased, %release_data is called and no email is generated from
| %insert_tcmctn_pending.
+-----------------------------------------------------------------------SASDOC*;
%insert_tcmctn_pending(init_id=&initiative_id, phase_id=&phase_seq_nb);

*SASDOC ------------------------------------------------------------------------
| Aug  2007 - B. Stropich
| Capture macro variables for hercules support.
+-----------------------------------------------------------------------SASDOC*;
%put _all_;

%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &initiative_id");

*SASDOC-------------------------------------------------------------------------
| Update the job complete timestamp
+-----------------------------------------------------------------------SASDOC*;
%update_task_ts(job_complete_ts);

*SASDOC-------------------------------------------------------------------------
| Drop the temporary UDB tables if there is no error
+-----------------------------------------------------------------------SASDOC*;
%macro cleanup_rdawtemps;

%if &err_fl=0 %then %do;

%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS);
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS2);
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._EXPAND_GPIS);
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG);
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG_PHN);
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLT_CPG);
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._AGE_LMT);
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._MAINT_NDC);


%end;
%mend;

%cleanup_rdawtemps;
