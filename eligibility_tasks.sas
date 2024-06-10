%include '/user1/qcpap020/autoexec_new.sas'; 
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  eligibility_tasks.sas
|
| LOCATION: /PRG/sastest1/hercules/106
|
| PURPOSE:  Used to produce tasks #8, #9 and #20 for Custom Mailings program.
|
| LOGIC:    Produce a file of eligible participants or cardholders.
|           Task #8 is all participants for the given client.
|           Task #9 layout includes just the eligible cardholders.
|           Task #20 is cardholders (recipient) with all covered participants
|           including the cardholder (subject).
|           Note that this program is based on monthly eligibility updates
|
|
| INPUT:    &CLAIMSA..TELIG_DETAIL_HIS
|           &CLAIMSA..TCPGRP_CLT_PLN_GR1
|           &CLAIMSA..TCLIENT1
|           &CLAIMSA..TBENEF_XREF_DN
|
| OUTPUT:   Standard datasets in results and pending directories
|
+--------------------------------------------------------------------------------
| HISTORY:  December 2003 - P.Wonders - Original.
|
+------------------------------------------------------------------------HEADER*/
* options mprint symbolgen mlogic;
%set_sysmode;
/* options sysparm='INITIATIVE_ID=14827 PHASE_SEQ_NB=1';*/
%INCLUDE "/herc&sysmode/prg/hercules/hercules_in.sas";

%LET err_fl=0;

 %put task_id=&task_id;
%LET PROGRAM_NAME=ELIGIBILITY_TASKS;

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
| Call %resolve_client
| Retrieve all client ids that are included in the mailing.  If a client is
| partial, this will be handled after determining current eligibility.
+------------------------------------------------------------------------SASDOC*;

%resolve_client(TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CLT_CPG) ;

PROC SQL NOPRINT;
   SELECT DISTINCT CLIENT_ID INTO :CLIENT_IDS SEPARATED BY ','
   FROM &DB2_TMP..&TABLE_PREFIX._CLT_CPG;
QUIT;
%PUT CLIENT_IDS = &CLIENT_IDS;


 *SASDOC--------------------------------------------------------------------------
| Retrieve the cardholders and participants that are currently eligible
| for the CPGs that we are including in the initiative.
+------------------------------------------------------------------------SASDOC*;

%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._ELIG_CDH_PT);


PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE TABLE &db2_TMP..&TABLE_PREFIX._ELIG_CDH_PT
           ( CDH_BENEFICIARY_ID INTEGER,
             PT_BENEFICIARY_ID INTEGER,
             CLT_PLAN_GROUP_ID INTEGER)) BY DB2;

   EXECUTE (INSERT INTO &DB2_TMP..&TABLE_PREFIX._ELIG_CDH_PT
            SELECT
                   A.CDH_BENEFICIARY_ID,
                   A.PT_BENEFICIARY_ID,
                   MAX(A.CLT_PLAN_GROUP_ID)
            FROM &CLAIMSA..TELIG_DETAIL_HIS A,
                 &CLAIMSA..TCPGRP_CLT_PLN_GR1 B,
                 &DB2_TMP..&TABLE_PREFIX._CLT_CPG C
            WHERE C.CLT_PLAN_GROUP_ID = A.CLT_PLAN_GROUP_ID
            AND A.CLT_PLAN_GROUP_ID = B.CLT_PLAN_GROUP_ID
            AND EXPIRATION_DT > CURRENT DATE
            GROUP BY A.CDH_BENEFICIARY_ID,
                     A.PT_BENEFICIARY_ID
           ) BY DB2;
   DISCONNECT FROM DB2;
QUIT;
%set_error_fl;
%RUNSTATS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._ELIG_CDH_PT);


*SASDOC--------------------------------------------------------------------------
| CALL %get_moc_phone
| Add the Mail Order pharmacy and customer service phone to the cpg file
+------------------------------------------------------------------------SASDOC*;
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CPG);

PROC SQL;
  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
  EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._CPG
            (CLT_PLAN_GROUP_ID INTEGER NOT NULL))BY DB2;

  EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX._CPG
            SELECT DISTINCT CLT_PLAN_GROUP_ID
            FROM &DB2_TMP..&TABLE_PREFIX._ELIG_CDH_PT) BY DB2;
  DISCONNECT FROM DB2;
QUIT;

%get_moc_csphone(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._CPG,
                  TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CPG_MOC);

 *SASDOC--------------------------------------------------------------------------
| Create strings that will be used in the SQL to make the records distinct based
| on who the subject and receiver are.  The task id determines this.
+------------------------------------------------------------------------SASDOC*;

%MACRO GET_RECEIVER_SUBJECT;
%GLOBAL RECEIVER_STR1;
%GLOBAL RECEIVER_STR2;
%GLOBAL RECEIVER_STR3;
%GLOBAL BIRTH_DT_STR;

  %IF &TASK_ID=8 %then %DO;
     %LET RECEIVER_STR1 = %STR(PT_BENEFICIARY_ID INTEGER NOT NULL);
     %LET RECEIVER_STR2 = %STR(PT_BENEFICIARY_ID);
     %LET RECEIVER_STR3 = %STR(PT_BENEFICIARY_ID = BENEFICIARY_ID);
     %LET BIRTH_DT_STR = &RECEIVER_STR2;
  %END;

  %IF &TASK_ID=9 %then %DO;
     %LET RECEIVER_STR1 = %STR(CDH_BENEFICIARY_ID INTEGER NOT NULL);
     %LET RECEIVER_STR2 = %STR(a.CDH_BENEFICIARY_ID);
     %LET RECEIVER_STR3 = %STR(a.CDH_BENEFICIARY_ID = BENEFICIARY_ID);
     %LET BIRTH_DT_STR = &RECEIVER_STR2;
  %END;

  %IF &TASK_ID=20 %then %DO;
     %LET RECEIVER_STR1 = %STR(CDH_BENEFICIARY_ID INTEGER NOT NULL,
      PT_BENEFICIARY_ID INTEGER NOT NULL);
     %LET RECEIVER_STR2 = %STR(a.CDH_BENEFICIARY_ID, PT_BENEFICIARY_ID);
     %LET RECEIVER_STR3 = %STR(PT_BENEFICIARY_ID = BENEFICIARY_ID);
     %LET BIRTH_DT_STR = %STR(PT_BENEFICIARY_ID);
  %END;

%MEND GET_RECEIVER_SUBJECT;

%GET_RECEIVER_SUBJECT;

%PUT RECEIVER_STR1=&RECEIVER_STR1;
%PUT RECEIVER_STR2=&RECEIVER_STR2;
%PUT RECEIVER_STR3=&RECEIVER_STR3;


 *SASDOC--------------------------------------------------------------------------
| Add the additional fields to the file
|
+------------------------------------------------------------------------SASDOC*;

%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._FINAL);

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._FINAL
           (
             &RECEIVER_STR1,
             BIRTH_DT DATE,
             CLIENT_ID INTEGER,
             CLIENT_NM CHAR(30),
             MOC_PHM_CD CHAR(3),
             CS_AREA_PHONE CHAR(13),
             LTR_RULE_SEQ_NB SMALLINT)) BY DB2;

   EXECUTE (INSERT INTO &DB2_TMP..&TABLE_PREFIX._FINAL
            SELECT DISTINCT
                   &RECEIVER_STR2,
                   D.BIRTH_DT,
                   D.CLIENT_ID,
                   C.CLIENT_NM,
                   B.MOC_PHM_CD,
                   B.CS_AREA_PHONE,
                   0
            FROM &DB2_TMP..&TABLE_PREFIX._ELIG_CDH_PT A,
                 &DB2_TMP..&TABLE_PREFIX._CPG_MOC B,
                 &CLAIMSA..TCLIENT1 C,
                 &CLAIMSA..TBENEF_XREF_DN D
            WHERE A.CLT_PLAN_GROUP_ID = B.CLT_PLAN_GROUP_ID
              AND &BIRTH_DT_STR = D.BENEFICIARY_ID
              AND D.CLIENT_ID = C.CLIENT_ID) BY DB2;
   DISCONNECT FROM DB2;
QUIT;
%set_error_fl;

%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");


%RUNSTATS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._FINAL);


*SASDOC-------------------------------------------------------------------------
| Call %create_base_file.
+-----------------------------------------------------------------------SASDOC*;

%create_base_file(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._FINAL);


*SASDOC-------------------------------------------------------------------------
| Drop the temp UDB tables.
+-----------------------------------------------------------------------SASDOC*;
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._ELIG_CDH_PT);
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._FINAL);
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CPG);
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLT_CPG);
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CPG_MOC);

*SASDOC-------------------------------------------------------------------------
| Call %check_document
+-----------------------------------------------------------------------SASDOC*;
%check_document;

*SASDOC-------------------------------------------------------------------------
| Check for autorelease of file.
+-----------------------------------------------------------------------SASDOC*;
%autorelease_file(INIT_ID=&INITIATIVE_ID, PHASE_ID=&PHASE_SEQ_NB);

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
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");
