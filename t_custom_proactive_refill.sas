/***HEADER -------------------------------------------------------------------------
 |  PROGRAM NAME:     CUSTOM_PROACTIVE_REFILL.SAS
 |
 |  PURPOSE:    TARGETS A CLIENT WHO WOULD LIKE A CUSTOM PROACTIVE MAILING.  THIS
 |              IS A ONE TIME MAILING.
 |              -- Select clients and CPGs
 |              -- select NDCs (expanded maintenance)
 |              -- get 45 day POS claims
 |              -- apply only participants with both mail and POS PBs
 |              -- unlike the Proactive Refill Notification program, this program
 |                 does not check mail history usage
 |
 |  INPUT:      UDB Tables accessed by macros are not listed
 |                        &claimsa..TCPG_PB_TRL_HIST,
 |                        SUMMARY.TDRUG_COV_LMT_SUMM,
 |                        &claimsa..TBENEF_BENEFICIAR1,
 |                        &claimsa..TCLIENT1,
 |                        &claimsa..TDRUG1,
 |                        &claimsa.trxclm_base
 |
 |  OUTPUT:     Standard datasets in /results and /pending directories
 |
 |
 |  HISTORY:    MARCH 2004 - PEGGY WONDERS
 +-------------------------------------------------------------------------------HEADER*/

OPTIONS SYSPARM='initiative_id=538 phase_seq_nb=1';


%set_sysmode;
%include "/PRG/sas&sysmode.1/hercules/hercules_in.sas";

LIBNAME SUMMARY DB2 DSN=&UDBSPRP SCHEMA=SUMMARY DEFER=YES;

%LET err_fl=0;
%LET POS_REVIEW_DAYS=207;
%LET PROGRAM_NAME=custom_proactive_refill;
%let elig_dt='01-01-2005';

* ---> Set the parameters for error checking;
 PROC SQL NOPRINT;
    SELECT QUOTE(TRIM(email)) INTO :Primary_programmer_email SEPARATED BY ' '
    FROM ADM_LKP.ANALYTICS_USERS
    WHERE UPCASE(QCP_ID) IN ("&USER");
 QUIT;

%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");


%update_task_ts(job_start_ts);

*SASDOC--------------------------------------------------------------------------
| Retrieve all client ids that are included in the mailing.  If a client is
| partial, this will be handled after determining current eligibility.
|
+------------------------------------------------------------------------SASDOC*;

%include '/PRG/sastest1/hercules/macros/resolve_client_his.sas';
%resolve_client_his(TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CLT_CPG,
                    setup_eff_dt='01-01-2005') ;

PROC SQL NOPRINT;
   SELECT DISTINCT CLIENT_ID INTO :CLIENT_IDS SEPARATED BY ','
   FROM &DB2_TMP..&TABLE_PREFIX._CLT_CPG;
QUIT;
%PUT CLIENT_IDS = &CLIENT_IDS;

*SASDOC--------------------------------------------------------------------------
| Call %get_ndc to determine the maintenance NDCs
+------------------------------------------------------------------------SASDOC*;

%get_ndc(DRUG_NDC_TBL=&DB2_TMP..&TABLE_PREFIX._NDCS);


*SASDOC --------------------------------------------------------------------
|
|  Identify the retail maintenance Rx claims during the last &pos_review_days
|  who have not filled any scripts at Mail during the last 90 days.
+--------------------------------------------------------------------SASDOC*;
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS);

 PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);

     EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS
                 (PT_BENEFICIARY_ID INTEGER NOT NULL,
                  CDH_BENEFICIARY_ID INTEGER NOT NULL,
                  CLIENT_ID INTEGER NOT NULL,
                  BIRTH_DT DATE,
                  DRUG_NDC_ID DECIMAL(11) NOT NULL,
                  NHU_TYPE_CD SMALLINT NOT NULL,
                  DRUG_ABBR_PROD_NM CHAR(12),
                  DRUG_CATEGORY_ID INTEGER ) NOT LOGGED INITIALLY) BY DB2;
   DISCONNECT FROM DB2;
 QUIT;

 PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
     EXECUTE(ALTER TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS
             ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;

     EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX._CLAIMS
             SELECT
                     A.PT_BENEFICIARY_ID,
                     A.CDH_BENEFICIARY_ID,
                     A.CLIENT_ID,
                     MAX(A.PT_BIRTH_DT),
                     MAX(A.DRUG_NDC_ID),
                     MAX(A.NHU_TYPE_CD),
                     C.DRUG_ABBR_PROD_NM,
                     B.DRUG_CATEGORY_ID
           FROM    &claimsa..&claim_his_tbl A,
                   &DB2_TMP..&TABLE_PREFIX._NDCS B,
                   &claimsa..TDRUG1 C
           WHERE  A.CLIENT_ID IN (&CLIENT_IDS)
             AND  A.FILL_DT BETWEEN (CURRENT DATE - &POS_REVIEW_DAYS DAYS) AND CURRENT DATE
             AND  A.DELIVERY_SYSTEM_CD = 3
             AND  A.DRUG_NDC_ID = B.DRUG_NDC_ID
             AND  A.NHU_TYPE_CD = B.NHU_TYPE_CD
             AND  A.DRUG_NDC_ID = C.DRUG_NDC_ID
             AND  A.NHU_TYPE_CD = C.NHU_TYPE_CD
             GROUP BY
                     A.PT_BENEFICIARY_ID,
                     A.CDH_BENEFICIARY_ID,
                     A.CLIENT_ID,
                     C.DRUG_ABBR_PROD_NM,
                     B.DRUG_CATEGORY_ID
           HAVING SUM(RX_COUNT_QY)>0
           AND PT_BENEFICIARY_ID NOT IN
                     (SELECT distinct
                             PT_BENEFICIARY_ID
                       FROM   &claimsa..&claim_his_tbl
                       WHERE  CLIENT_ID in (&CLIENT_IDS)
                       AND    FILL_DT BETWEEN (CURRENT DATE - 90 DAYS) AND CURRENT DATE
                       AND    DELIVERY_SYSTEM_CD = 2) )BY DB2;
  DISCONNECT FROM DB2;
 QUIT;
 %set_error_fl;
 %on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");



 %RUNSTATS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CLAIMS);


 *SASDOC--------------------------------------------------------------------------
| Select only the CPGs that have both POS and Mail delivery systems.
+------------------------------------------------------------------------SASDOC*;


%drop_db2_table(tbl_name=&db2_tmp..&TABLE_PREFIX._CPG_PB);

PROC SQL;
  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
     EXECUTE
        (CREATE TABLE &db2_tmp..&TABLE_PREFIX._CPG_PB
         (CLT_PLAN_GROUP_ID INTEGER NOT NULL PRIMARY KEY,
          POS_PB INTEGER,
          MAIL_PB INTEGER) NOT LOGGED INITIALLY) BY DB2;
  DISCONNECT FROM DB2;
QUIT;


PROC SQL;
  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
       EXECUTE
          (ALTER TABLE &db2_tmp..&TABLE_PREFIX._CPG_PB
           ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;

       EXECUTE (INSERT INTO &db2_tmp..&TABLE_PREFIX._CPG_PB
               (  SELECT D.CLT_PLAN_GROUP_ID,
                     MAX(CASE
                            WHEN A.DELIVERY_SYSTEM_CD = 3 THEN PB_ID
                            ELSE 0
                         END) AS POS_PB,
                     MAX(CASE
                           WHEN A.DELIVERY_SYSTEM_CD = 2 THEN PB_ID
                           ELSE 0
                        END) AS MAIL_PB
              FROM &claimsa..TCPG_PB_TRL_HIST  A,
                   &DB2_TMP..&TABLE_PREFIX._CLT_CPG D
              WHERE D.CLT_PLAN_GROUP_ID = A.CLT_PLAN_GROUP_ID
              AND   A.EXP_DT > &elig_dt
              AND   A.EFF_DT <= &elig_dt
              AND   A.DELIVERY_SYSTEM_CD IN (2,3)
           GROUP BY D.CLT_PLAN_GROUP_ID
             HAVING COUNT(DISTINCT A.DELIVERY_SYSTEM_CD)=2)
           ) BY DB2;
      DISCONNECT FROM DB2;
 QUIT;
%set_error_fl;

%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");


 %RUNSTATS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CPG_PB);


 *SASDOC--------------------------------------------------------------------------
| CALL %get_moc_phone
| Add the Mail Order pharmacy and customer service phone to the cpg file
+------------------------------------------------------------------------SASDOC*;
 %get_moc_csphone(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._CPG_PB,
                  TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CPG_MOC);


*SASDOC-------------------------------------------------------------------------
| Determine eligibility for the cardholdler as well as participant (if
| available).
+-----------------------------------------------------------------------SASDOC*;

%ELIGIBILITY_CHECK(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._CLAIMS,
                     TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG,
                     CLAIMSA=&CLAIMSA);


*SASDOC ------------------------------------------------------------------------
 | Find the latest billing_end_month for the SUMMARY tables. Use Copay Summary
 | for fastest results.
 +-----------------------------------------------------------------------SASDOC*;

PROC SQL NOPRINT;
  SELECT MAX(BILLING_END_MONTH)
        INTO :MAX_COPAY_DATE
  FROM SUMMARY.TCOPAY_PLAN_SUMM;
QUIT;



*SASDOC -----------------------------------------------------------------------------
 |
 |   Use SUMMARY.TDRUG_COV_LMT_SUMM to delete drug categories not being covered while
 |   calculating the REFILL_FILL_QY (subtract 1 FROM ANNUAL_REFILL_QY).  Keep only
 |   the eligible cpgs, participants
 |
 |     NOTE: refill_fill_qy or ANNUAL_FILL_QY may have values like '9999' which means
 |           no refill limit and should be treated same as null
 |
 + ----------------------------------------------------------------------------SASDOC*;


%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS2);

  PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
    EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._claims2
       (    LTR_RULE_SEQ_NB SMALLINT,
            PT_BENEFICIARY_ID INTEGER,
            CDH_BENEFICIARY_ID INTEGER,
            BIRTH_DT DATE,
            CLIENT_ID INTEGER,
            CLIENT_NM CHAR(30),
            DRUG_ABBR_PROD_NM CHAR(12),
            REFILL_FILL_QY SMALLINT,
            MOC_PHM_CD         CHAR(3),
            CS_AREA_PHONE      CHAR(13)) not logged initially) BY DB2;
    DISCONNECT FROM DB2;
 QUIT;

 PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);

    EXECUTE(ALTER TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS2
             ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;

    EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX._claims2
       (SELECT DISTINCT
            0 as LTR_RULE_SEQ_NB,
            A.PT_BENEFICIARY_ID,
            A.CDH_BENEFICIARY_ID,
            A.BIRTH_DT,
            A.CLIENT_ID,
            CLIENT_NM,
            DRUG_ABBR_PROD_NM,
            nullif(0,0),
            MOC_PHM_CD,
            CS_AREA_PHONE
       FROM &DB2_TMP..&TABLE_PREFIX._CLAIMS A,
            &DB2_TMP..&TABLE_PREFIX._CPG_ELIG B,
            &DB2_TMP..&TABLE_PREFIX._CPG_MOC C,
            &CLAIMSA..TCLIENT1 E
       where A.PT_BENEFICIARY_ID = B.PT_BENEFICIARY_ID
       AND   A.CLIENT_ID = E.CLIENT_ID
       AND   C.CLT_PLAN_GROUP_ID = B.CLT_PLAN_GROUP_ID)) BY DB2;
    DISCONNECT FROM DB2;
 QUIT;
 %set_error_fl;

 %on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");


 %RUNSTATS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CLAIMS2);

  %let err_fl=0;
 *SASDOC-------------------------------------------------------------------------
 | Get beneficiary address and create SAS file layout.
 +-----------------------------------------------------------------------SASDOC*;

 %CREATE_BASE_FILE(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._CLAIMS2);

 *SASDOC-------------------------------------------------------------------------
 | Call %check_document to see if the Stellent id(s) have been attached.
 +-----------------------------------------------------------------------SASDOC*;

 %CHECK_DOCUMENT;

 *SASDOC-------------------------------------------------------------------------
 | Check for autorelease of file.
 +-----------------------------------------------------------------------SASDOC*;
 %AUTORELEASE_FILE(INIT_ID=&INITIATIVE_ID, PHASE_ID=&PHASE_SEQ_NB);


 *SASDOC-------------------------------------------------------------------------
 | Drop the temporary UDB tables
 +-----------------------------------------------------------------------SASDOC*;
 %drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLT_CPG);
 %drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG);
 %drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CPG_MOC);
 %drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS);
 %drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS2);
 %drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._NDCS);

 *SASDOC-------------------------------------------------------------------------
 | Update the job complete timestamp.
 +-----------------------------------------------------------------------SASDOC*;
 %update_task_ts(job_complete_ts);


 *SASDOC-------------------------------------------------------------------------
 | Insert distinct recipients into TCMCTN_PENDING if the file is not autorelease.
 | The user will receive an email with the initiative summary report.  If the
 | file is autoreleased, %release_data is called and no email is generated from
 | %insert_tcmctn_pending.
 +-----------------------------------------------------------------------SASDOC*;
 %insert_tcmctn_pending(init_id=&initiative_id, phase_id=&phase_seq_nb);


 %on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
           EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
           EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative Id &INITIATIVE_ID");
