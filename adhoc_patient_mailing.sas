%include '/user1/qcpap020/autoexec_new.sas'; 
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  adhoc_patient_mailing.sas
|
| LOCATION: /PRG/sas&sysmode.1/hercules/106
|
| PURPOSE:  Used to produce task #29 (Adhoc patient mailing).
|
| LOGIC:    This program can be used to perform a follow up mailing to the exact
|           same member or receiver who was included in another initiative.
|           The ability to check eligibility is optional. Currently, this program
|           requires I.T. personnel to run it manually - entering the original
|           initiative id.
|
| INPUT:    TABLES ACCESSED BY CALLED MACROS ARE NOT LISTED BELOW
|
|
| OUTPUT:   standard files in /pending and /results directories
|
|
+-------------------------------------------------------------------------------
| HISTORY:  April 2005 - P.Wonders - Original.
|
+-----------------------------------------------------------------------HEADER*/


*SASDOC-------------------------------------------------------------------------
| Enter the original initiative_id
+-----------------------------------------------------------------------SASDOC*;
%let old_initiative_id = 593;
%let eligibility_chk = 0;


%set_sysmode;
* %let sysmode=prod;
/*options sysparm='INITIATIVE_ID=14830 PHASE_SEQ_NB=1';*/
%INCLUDE "/herc&sysmode/prg/hercules/hercules_in.sas";

%LET ERR_FL=0;
%LET PROGRAM_NAME=ADHOC_PATIENT_MAILING;

* ---> Set the parameters for error checking;
 PROC SQL NOPRINT;
    SELECT QUOTE(TRIM(email)) INTO :Primary_programmer_email SEPARATED BY ' '
    FROM ADM_LKP.ANALYTICS_USERS
    WHERE UPCASE(QCP_ID) IN ("&USER");
 QUIT;

%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &INITIATIVE_ID");


*SASDOC-------------------------------------------------------------------------
| Update the job start timestamp.
+-----------------------------------------------------------------------SASDOC*;
%update_task_ts(job_start_ts);

*SASDOC-------------------------------------------------------------------------
| Find the members targeted in the prior mailing
+-----------------------------------------------------------------------SASDOC*;

%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._RECEIVERS);

PROC SQL NOPRINT;
  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);

    EXECUTE(
      CREATE TABLE &DB2_TMP..&TABLE_PREFIX._RECEIVERS
                (PT_BENEFICIARY_ID INTEGER NOT NULL PRIMARY KEY)
    ) BY DB2;

        EXECUTE(
      INSERT INTO &DB2_TMP..&TABLE_PREFIX._RECEIVERS
                SELECT DISTINCT RECIPIENT_ID
                                FROM &HERCULES..TCMCTN_RECEIVR_HIS
                                WHERE INITIATIVE_ID = &OLD_INITIATIVE_ID
    ) BY DB2;
  DISCONNECT FROM DB2;
QUIT;
%SET_ERROR_FL;

*SASDOC-------------------------------------------------------------------------
| Find the cardholder beneficiary id.
+-----------------------------------------------------------------------SASDOC*;

%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._RECEIVER_CDH);
PROC SQL NOPRINT;
  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);

    EXECUTE(
      CREATE TABLE &DB2_TMP..&TABLE_PREFIX._RECEIVER_CDH
                (PT_BENEFICIARY_ID INTEGER NOT NULL PRIMARY KEY,
                 CDH_BENEFICIARY_ID INTEGER,
                 CLIENT_ID INTEGER,
                 LTR_RULE_SEQ_NB SMALLINT,
                 BIRTH_DT DATE)) BY DB2;

    EXECUTE(
       INSERT INTO &DB2_TMP..&TABLE_PREFIX._RECEIVER_CDH
                SELECT A.PT_BENEFICIARY_ID,
                       CDH_BENEFICIARY_ID,
                       CLIENT_ID,
                       0,
                       BIRTH_DT
                FROM &DB2_TMP..&TABLE_PREFIX._RECEIVERS A,
                     &CLAIMSA..TBENEF_XREF_DN B
                WHERE A.PT_BENEFICIARY_ID = B.BENEFICIARY_ID
    ) BY DB2;
  DISCONNECT FROM DB2;
QUIT;
%SET_ERROR_FL;

*SASDOC-------------------------------------------------------------------------
| Call the eligibility macro. This is required even if the business does not
| want to check eligibility for late step to retrieve Customer Care phone number.
+-----------------------------------------------------------------------SASDOC*;

%ELIGIBILITY_CHECK(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._RECEIVER_CDH,
                   TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG,
                   CLAIMSA=&CLAIMSA);

%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._RECEIVERS2);

PROC SQL NOPRINT;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
      EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._RECEIVERS2
                (PT_BENEFICIARY_ID INTEGER NOT NULL PRIMARY KEY,
                 CDH_BENEFICIARY_ID INTEGER,
                 CLT_PLAN_GROUP_ID INTEGER,
                 CLIENT_ID INTEGER,
                 LTR_RULE_SEQ_NB INTEGER,
                 BIRTH_DT DATE)) BY DB2;
DISCONNECT FROM DB2;
QUIT;
%SET_ERROR_FL;

 *SASDOC-------------------------------------------------------------------------
| If the eligibilty check is set to true, join to the table generated from the
| eligibilty macro.  If eligibility checking is off because the business wants
| to mail to the exact same members, a left join is performed and no members are
| dropped.
+-----------------------------------------------------------------------SASDOC*;


data _null_;
      if &eligibility_chk = 1 then do;
         call symput('join_string', "inner join");
      end;

      else if &eligibility_chk = 0 then do;
         call symput('join_string', "left join");
      end;
run;

%Put join=&join_string;


        PROC SQL NOPRINT;
          CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
             EXECUTE(
                       INSERT INTO &DB2_TMP..&TABLE_PREFIX._RECEIVERS2
                       SELECT A.PT_BENEFICIARY_ID,
                              A.CDH_BENEFICIARY_ID,
                              CLT_PLAN_GROUP_ID,
                              CLIENT_ID,
                              LTR_RULE_SEQ_NB,
                              BIRTH_DT
                       FROM  &DB2_TMP..&TABLE_PREFIX._RECEIVER_CDH a &join_string
                             &DB2_TMP..&TABLE_PREFIX._CPG_ELIG B
                       ON A.PT_BENEFICIARY_ID = B.PT_BENEFICIARY_ID
             ) BY DB2;
         DISCONNECT FROM DB2;
       QUIT;
       %SET_ERROR_FL;

%RUNSTATS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._RECEIVERS2);


 *SASDOC--------------------------------------------------------------------------
| CALL %get_moc_phone
| Add the Mail Order pharmacy and customer service phone to the cpg file
+------------------------------------------------------------------------SASDOC*;
 %get_moc_csphone(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._RECEIVERS2,
                  TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CPG_MOC);


*SASDOC-------------------------------------------------------------------------
| Get beneficiary address and create SAS file layout.
+-----------------------------------------------------------------------SASDOC*;

%CREATE_BASE_FILE(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._CPG_MOC);


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
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._RECEIVERS);
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._RECEIVER_CDH);
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._RECEIVERS2);
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CPG_MOC);
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG);


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
