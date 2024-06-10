%include '/user1/qcpap020/autoexec_new.sas'; 
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  Identify Drug Therapy
|
| LOGIC:    This program is used to produce several tasks (7, 11, 13, 19, 21).
|           The tasks differ in that they include no drug information on the
|           file layout (task id 11), drug name only (task id 19) or drug and
|           strength (task id 21).  Additionally, these tasks are shared among
|           different Caremark Programs.  Some macros execute conditionally
|           based on Program.
|
| LOCATION: /PRG/sas&sysmode.1/hercules/
|
| INPUT:    tables referenced by macros are not listed here
|           &CLAIMSA..&CLAIM_HIS_TBL
|           &CLAIMSA..TCLIENT1
|           &CLAIMSA..TDRUG1
|
|
| OUTPUT:   STANDARD OUTPUT FILES IN /pending and /results directories
+--------------------------------------------------------------------------------
| HISTORY:  December 2003 - Yury Vilk
|
|  For specialty mailing:
|  RESET &CLIENT_CONDITION= to have all the client included
|			Jan, 2007	- Kuladeep M	  Added Claim end date is not null when
|										  fill_dt between claim begin date and claim end
|										  date.
|
|	    Mar  2007    - Greg Dudley Hercules Version  1.0                                      
|           14SEP2007     - N.Williams - Hercules Version  1.5.01
|                          Commented out call to %check_tbl macro because its not
|                          needed and db changes will not keep statistics of table
|                          loads anymore.
|
+------------------------------------------------------------------------HEADER*/
%LET err_fl=0;
%set_sysmode(mode=prod);

OPTIONS MLOGIC mlogicnest MPRINT mprintnest symbolgen source2;
OPTIONS SYSPARM='INITIATIVE_ID=     PHASE_SEQ_NB=1';
%INCLUDE "/herc&sysmode/prg/hercules/hercules_in.sas" / nosource2;

%LET PROGRAM_NAME=specialty_mailing;

 PROC SQL NOPRINT;
    SELECT QUOTE(TRIM(email)) INTO :Primary_programmer_email SEPARATED BY ' '
    FROM ADM_LKP.ANALYTICS_USERS
    WHERE UPCASE(QCP_ID) IN ("&USER");
 QUIT;

%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log");

%update_task_ts(job_start_ts);

*SASDOC--------------------------------------------------------------------------
| CALL %resolve_client but don't execute for Quality Mailings
+------------------------------------------------------------------------SASDOC*;
%resolve_client(NO_OUTPUT_TABLES_IN=1,
                Execute_condition=%STR(&PROGRAM_ID NE 105));

%let client_condition=;


*SASDOC--------------------------------------------------------------------------
| CALL %get_ndc
+------------------------------------------------------------------------SASDOC*;
%get_ndc(DRUG_NDC_TBL=&DB2_TMP..&TABLE_PREFIX._NDC,
         CLAIM_DATE_TBL=&DB2_TMP..&TABLE_PREFIX._RVW_DATES);


/*  Find CLAIM_BEGIN_DT and CLAIM_END_DT, determine if drug group2 exist
         and  whether the program should expect NDC table from the macro %get_ndc  */

%LET DRUG_GROUP2_EXIST_FLAG=0; * Initialize DRUG_GROUP2_EXIST_FLAG;

DATA _NULL_;
  SET &DB2_TMP..&TABLE_PREFIX._RVW_DATES;
IF      DRG_GROUP_SEQ_NB=1 THEN
                                                        DO;
  CALL SYMPUT('CLAIM_BEGIN_DT' || TRIM(LEFT(DRG_GROUP_SEQ_NB)), "'" || PUT(CLAIM_BEGIN_DT,yymmddd10.) || "'");
  CALL SYMPUT('CLAIM_END_DT' || TRIM(LEFT(DRG_GROUP_SEQ_NB)), "'" || PUT(CLAIM_END_DT,yymmddd10.) || "'");
  CALL SYMPUT('ALL_DRUG_IN' || TRIM(LEFT(DRG_GROUP_SEQ_NB)), PUT(ALL_DRUG_IN,1.));
                                                        END;
 * IF all_drug_in=0             THEN CALL  SYMPUT('NDC_TBL_EXIST_FLAG', PUT('1',1.));
  IF DRG_GROUP_SEQ_NB=2 THEN CALL SYMPUT('DRUG_GROUP2_EXIST_FLAG',PUT('1',1.));
RUN;

%set_error_fl;
%PUT CLAIM_BEGIN_DT1=&CLAIM_BEGIN_DT1 CLAIM_END_DT1=&CLAIM_END_DT1;
%PUT ALL_DRUG_IN1=&ALL_DRUG_IN1;
%PUT GET_NDC_NDC_TBL_FL=&GET_NDC_NDC_TBL_FL;
%PUT DRUG_GROUP2_EXIST_FLAG=&DRUG_GROUP2_EXIST_FLAG;

*SASDOC-------------------------------------------------------------------------
| Generate strings for various where clause to be used later in the code. These
| strings are included based on variable conditions (delivery system exclusions,
| existence of drug group 2, drug name/str/dose fields.
+-----------------------------------------------------------------------SASDOC*;
%MACRO get_where_strings;
%GLOBAL DELIVERY_SYSTEM_CONDITION DRUG_FIELDS_LIST DRUG_FIELDS_FLAG
                STR_TDRUG1 DRUG_JOIN_CONDITION;

%LET DS_STR=;
%LET DRUG_FIELDS_LIST=;

PROC SQL NOPRINT;
  SELECT DISTINCT (FIELD_NM) INTO : DRUG_FIELDS_LIST  SEPARATED BY ','
 FROM &HERCULES..TFILE_FIELD                 AS A ,
          &HERCULES..TFIELD_DESCRIPTION  AS B,
          &HERCULES..TPHASE_RVR_FILE   AS C
                WHERE INITIATIVE_ID=&INITIATIVE_ID
                  AND PHASE_SEQ_NB=&PHASE_SEQ_NB
                  AND A.FILE_ID = C.FILE_ID
              AND A.FIELD_ID = B.FIELD_ID
                  AND B.FIELD_NM IN ('DRUG_ABBR_PROD_NM','DRUG_ABBR_STRG_NM','DRUG_ABBR_DSG_NM')
;
QUIT;

%set_error_fl;

%LET DRUG_FIELDS_FLAG=1;
%LET STR_TDRUG1=;
%LET DRUG_JOIN_CONDITION=;
%IF &DRUG_FIELDS_LIST NE  %THEN
                                        %DO;
                %LET DRUG_FIELDS_LIST=, &DRUG_FIELDS_LIST ;
                %LET STR_TDRUG1=%STR(, &CLAIMSA..TDRUG1 AS G);
                %LET DRUG_JOIN_CONDITION=%STR(AND E.DRUG_NDC_ID = G.DRUG_NDC_ID
                                                                          AND E.NHU_TYPE_CD = G.NHU_TYPE_CD);
                                        %END;
%ELSE   %LET DRUG_FIELDS_FLAG=0;

%PUT DRUG_FIELDS_LIST=&DRUG_FIELDS_LIST;
%PUT STR_TDRUG1=&STR_TDRUG1;
%PUT DRUG_JOIN_CONDITION=&DRUG_JOIN_CONDITION;

   PROC SQL NOPRINT;
        SELECT DELIVERY_SYSTEM_CD INTO :DS_STR SEPARATED BY ','
        FROM &HERCULES..TDELIVERY_SYS_EXCL
        WHERE INITIATIVE_ID = &INITIATIVE_ID;
    QUIT;

%set_error_fl;

%IF &DS_STR NE
%THEN  %LET DELIVERY_SYSTEM_CONDITION=%STR(AND DELIVERY_SYSTEM_CD NOT IN (&DS_STR));
%ELSE  %LET DELIVERY_SYSTEM_CONDITION=;
%PUT DELIVERY_SYSTEM_CONDITION = &DELIVERY_SYSTEM_CONDITION;

%set_error_fl;

**%IF &GET_NDC_NDC_TBL_FL=1 %THEN
**%check_tbl(tbl_name=&DB2_TMP..&TABLE_PREFIX._NDC);

%MEND get_where_strings;

%get_where_strings;


*SASDOC--------------------------------------------------------------------------
| Retrieve the claim data for group 1 drugs.
+------------------------------------------------------------------------SASDOC*;

 * OPTIONS MPRINT MLOGIC SYMBOLGEN;
*OPTIONS SYMBOLGEN;
* OPTIONS NOMPRINT NOMLOGIC NOSYMBOLGEN;
/* The macro pulls patients based on the condition defined in the hercules tables for
the initiative */
%MACRO pull_pat_from_claims;

%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP);
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_B);

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP   AS
      (  SELECT                  A.NTW_PRESCRIBER_ID AS PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID,
                                 A.PT_BENEFICIARY_ID,
                                 A.PT_BIRTH_DT          AS BIRTH_DT,
                                 B.DRG_GROUP_SEQ_NB,
                                 B.DRG_SUB_GRP_SEQ_NB,
                                 A.CLIENT_ID,
                                 A.RX_COUNT_QY,
                                 C.CLIENT_NM
                          FROM  &CLAIMSA..&CLAIM_HIS_TBL                        AS A,
                                    &DB2_TMP..&TABLE_PREFIX._RVW_DATES  AS B,
                                        &CLAIMSA..TCLIENT1                                      AS C
      ) DEFINITION ONLY NOT LOGGED INITIALLY
               ) BY DB2;
   DISCONNECT FROM DB2;
QUIT;
 %set_error_fl;

%PUT CLAIMS_TBL=&CLAIMSA..&CLAIM_HIS_TBL;


*SASDOC--------------------------------------------------------------------------
|  The code below executes only if no drug information is required and
|  the drug group1 is all drugs
+------------------------------------------------------------------------SASDOC*;
%IF &ALL_DRUG_IN1=1 AND &DRUG_FIELDS_LIST=%STR() %THEN
                   %DO;
                       PROC SQL;
                          CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
                          EXECUTE
                          (ALTER TABLE &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;
 
                          EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP
                            WITH PTS AS
                                 (SELECT  A.NTW_PRESCRIBER_ID AS PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID, A.PT_BENEFICIARY_ID,
                                 MAX(A.PT_BIRTH_DT)     AS BIRTH_DT,
                                 MAX(1)                 AS DRG_GROUP_SEQ_NB,
                                 MAX(1)                 AS DRG_SUB_GRP_SEQ_NB,
                                 MAX(A.CLIENT_ID)       AS CLIENT_ID,
                                 SUM(A.RX_COUNT_QY) AS  RX_COUNT_QY
                            FROM &CLAIMSA..&CLAIM_HIS_TBL   AS A
                           WHERE A.FILL_DT 
                         BETWEEN &CLAIM_BEGIN_DT1. AND &CLAIM_END_DT1.
                                 &CLIENT_ID_CONDITION.
                                 &DELIVERY_SYSTEM_CONDITION.
		                     AND A.BILLING_END_DT IS NOT NULL
                             AND NOT EXISTS
                                 (SELECT 1
                                    FROM &CLAIMSA..&CLAIM_HIS_TBL
                                   WHERE A.BENEFIT_REQUEST_ID = BENEFIT_REQUEST_ID
                                     AND   A.BRLI_NB = BRLI_NB
                                     AND   BRLI_VOID_IN > 0)
                        GROUP BY A.NTW_PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID,
                                 A.PT_BENEFICIARY_ID
                )
                SELECT E.*, F.CLIENT_NM
                  FROM PTS                    AS E,
                       &CLAIMSA..TCLIENT1     AS F
                 WHERE E.CLIENT_ID=F.CLIENT_ID
                ) BY DB2;
          %PUT Before reset;
          %PUT SQLXRC=&SQLXRC SYSERR=&SYSERR;
      %reset_sql_err_cd;
   *  DISCONNECT FROM DB2;
QUIT;
%set_error_fl;

%IF &err_fl=0 %THEN %PUT Created table &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP;
%runstats(TBL_NAME=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP);

                   %END; /* End of &ALL_DRUG_IN1=1 AND &DRUG_FIELDS_LIST=%STR()*/

*SASDOC--------------------------------------------------------------------------
| Check if NDC table is provided by macro %get_ndc and if yes join claims to this table.
| If the drug information is requiered the macro also joins to the STR_TDRUG1 table.
+------------------------------------------------------------------------SASDOC*;
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM);

%IF &GET_NDC_NDC_TBL_FL=1 %THEN
   %DO;
PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM      AS
      (  SELECT  A.NTW_PRESCRIBER_ID AS PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID,
                                         A.PT_BENEFICIARY_ID,
                                 A.PT_BIRTH_DT          AS BIRTH_DT,
                                         D.DRG_GROUP_SEQ_NB,
                                 D.DRG_SUB_GRP_SEQ_NB,
                                 A.CLIENT_ID,
                                 A.RX_COUNT_QY,
                                 C.CLIENT_NM
                                 &DRUG_FIELDS_LIST.
                          FROM  &CLAIMSA..&CLAIM_HIS_TBL             AS A,
                                &CLAIMSA..TCLIENT1                   AS C,
                                 &DB2_TMP..&TABLE_PREFIX._RVW_DATES  AS D,
                                 &CLAIMSA..TDRUG1                    AS E
      )DEFINITION ONLY NOT LOGGED INITIALLY
               ) BY DB2;
   DISCONNECT FROM DB2;
QUIT;
%set_error_fl;

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
EXECUTE
  (ALTER TABLE &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;
EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM
                WITH PTS AS
        (SELECT  A.NTW_PRESCRIBER_ID    AS PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID,
                                 A.PT_BENEFICIARY_ID,
                                 MAX(A.PT_BIRTH_DT)     AS BIRTH_DT,
                                 B.DRG_GROUP_SEQ_NB,
                                 B.DRG_SUB_GRP_SEQ_NB,
                                 MAX(A.CLIENT_ID) AS CLIENT_ID,
                                 D.DRUG_NDC_ID,
                                 D.NHU_TYPE_CD,
                                 SUM(A.RX_COUNT_QY) AS  RX_COUNT_QY
                 FROM    &CLAIMSA..&CLAIM_HIS_TBL   AS A,
                                 &DB2_TMP..&TABLE_PREFIX._RVW_DATES AS B,
                                                 &DB2_TMP..&TABLE_PREFIX._NDC           AS D
        WHERE (   (B.ALL_DRUG_IN=0)
                           OR (&DRUG_FIELDS_FLAG=1 AND B.ALL_DRUG_IN=1))
                   AND    A.FILL_DT BETWEEN CLAIM_BEGIN_DT AND CLAIM_END_DT
				   AND    A.BILLING_END_DT IS NOT NULL
                   AND    B.DRG_GROUP_SEQ_NB=D.DRG_GROUP_SEQ_NB
                   AND    B.DRG_SUB_GRP_SEQ_NB=D.DRG_SUB_GRP_SEQ_NB
                   AND    A.DRUG_NDC_ID = D.DRUG_NDC_ID
                   AND    A.NHU_TYPE_CD = D.NHU_TYPE_CD
                                  &CLIENT_ID_CONDITION
                  &DELIVERY_SYSTEM_CONDITION
         AND NOT EXISTS
              (SELECT 1
               FROM &CLAIMSA..&CLAIM_HIS_TBL
               WHERE A.BENEFIT_REQUEST_ID = BENEFIT_REQUEST_ID
               AND   A.BRLI_NB = BRLI_NB
               AND   BRLI_VOID_IN > 0)
                        GROUP BY A.NTW_PRESCRIBER_ID,
                                         A.CDH_BENEFICIARY_ID,
                                         A.PT_BENEFICIARY_ID,
                                         B.DRG_GROUP_SEQ_NB,
                                         B.DRG_SUB_GRP_SEQ_NB,
                                         D.DRUG_NDC_ID,
                                     D.NHU_TYPE_CD
                        )
                 SELECT  E.PRESCRIBER_ID,
                                 E.CDH_BENEFICIARY_ID,
                         E.PT_BENEFICIARY_ID,
                                 E.BIRTH_DT,
                     E.DRG_GROUP_SEQ_NB,
                                 E.DRG_SUB_GRP_SEQ_NB,
                                 E.CLIENT_ID,
                                 E.RX_COUNT_QY,
                                 F.CLIENT_NM
                                 &DRUG_FIELDS_LIST.

                        FROM    PTS                                     AS E,
                                        &CLAIMSA..TCLIENT1              AS F
                                        &STR_TDRUG1.
                      WHERE  E.CLIENT_ID=F.CLIENT_ID
                                &DRUG_JOIN_CONDITION.

      ) BY DB2;
          %PUT Before reset;
          %PUT SQLXRC=&SQLXRC SYSERR=&SYSERR;
          %reset_sql_err_cd;
  * DISCONNECT FROM DB2;
QUIT;
 %set_error_fl;
%IF &err_fl=0 %THEN %PUT Created table &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM;
%runstats(TBL_NAME=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM);

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
EXECUTE
  (ALTER TABLE &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;
EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP
         SELECT  PRESCRIBER_ID,
                                 CDH_BENEFICIARY_ID,
                 PT_BENEFICIARY_ID,
                                 MAX(BIRTH_DT) AS BIRTH_DT,
                                 DRG_GROUP_SEQ_NB,
                                 DRG_SUB_GRP_SEQ_NB,
                                 MAX(CLIENT_ID) AS CLIENT_ID,
                                 SUM(RX_COUNT_QY) AS    RX_COUNT_QY,
                                 MAX(CLIENT_NM) AS CLIENT_NM
                 FROM  &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM
                        GROUP BY PRESCRIBER_ID,
                                         CDH_BENEFICIARY_ID,
                                         PT_BENEFICIARY_ID,
                                         DRG_GROUP_SEQ_NB,
                                         DRG_SUB_GRP_SEQ_NB
      ) BY DB2;
%PUT Before reset;
%PUT SQLXRC=&SQLXRC SYSERR=&SYSERR;
 %reset_sql_err_cd;
* DISCONNECT FROM DB2;
QUIT;
%set_error_fl;
%IF &err_fl=0 %THEN %PUT Updated table &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP;
%runstats(TBL_NAME=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP);

*SASDOC--------------------------------------------------------------------------
| Check for existence of drug group 2 and if it exist execute code based on
| whether the therapy rule is include or exclude.
+------------------------------------------------------------------------SASDOC*;
%IF &DRUG_GROUP2_EXIST_FLAG=1 %THEN
   %DO;
DATA _NULL_;
  SET &HERCULES..TINIT_DRUG_GROUP(WHERE=(       INITIATIVE_ID=&INITIATIVE_ID
                                           AND DRG_GROUP_SEQ_NB=2));
IF  TRIM(LEFT(OPERATOR_TX))='NOT' THEN CALL SYMPUT('NULL_CONDITION','IS NULL');
ELSE                                   CALL SYMPUT('NULL_CONDITION','IS NOT NULL');
RUN;
%set_error_fl;

%PUT NULL_CONDITION=&NULL_CONDITION;

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
   EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_B AS
      (  SELECT  * FROM &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP
      ) DEFINITION ONLY NOT LOGGED INITIALLY
               ) BY DB2;
   EXECUTE
  (ALTER TABLE &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_B ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;
        EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_B
     WITH PTS  AS
                        ( SELECT PT_BENEFICIARY_ID,COUNT(*) AS COUNT
                   FROM &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP
                                        WHERE DRG_GROUP_SEQ_NB=2
                                          GROUP BY  PT_BENEFICIARY_ID
                                )
           SELECT A.*
                 FROM &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP AS A        LEFT JOIN
                 PTS                                                                            AS B
         ON A.PT_BENEFICIARY_ID=B.PT_BENEFICIARY_ID
         WHERE  B.PT_BENEFICIARY_ID &NULL_CONDITION
                        ) BY DB2;
%PUT Before reset;
%PUT SQLXRC=&SQLXRC SYSERR=&SYSERR;
%reset_sql_err_cd;
* DISCONNECT FROM DB2;
QUIT;
%set_error_fl;
%runstats(TBL_NAME=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_B);
   %END; /* End of &DRUG_GROUP2_EXIST_FLAG = 1*/
%ELSE
                                                                                                                %DO;

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE ALIAS &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_B FOR
                                                &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP
           ) BY DB2;
        DISCONNECT FROM DB2;
QUIT;
%set_error_fl;
  %END; /* End of &GET_NDC_NDC_TBL_FL = 1 AND &DRUG_GROUP2*/

                                   %END; /* End of &GET_NDC_NDC_TBL_FL = 1 */
%ELSE
                        %DO;
PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE ALIAS &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM FOR
                                                &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP
           ) BY DB2;
        DISCONNECT FROM DB2;
QUIT;
%set_error_fl;

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE ALIAS &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_B FOR
                                                &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP
           ) BY DB2;
        DISCONNECT FROM DB2;
QUIT;
%set_error_fl;
                        %END; /* End of &GET_NDC_NDC_TBL_FL NE 1 */

%IF &err_fl=0 %THEN
                                        %DO;
    %PUT Created table &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM;
        %PUT Created table &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_B;
                                        %END;

%table_properties(TBL_NAME=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP);
%table_properties(TBL_NAME=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM);
%table_properties(TBL_NAME=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_B);
%MEND;

%pull_pat_from_claims;

*SASDOC--------------------------------------------------------------------------
| Call the macro %participant_parms. The logic in the macro determines whether the
| participants check is actualy performed.
+------------------------------------------------------------------------SASDOC*;
 %participant_parms(tbl_name_in=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_B,
                                    tbl_name_out2=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_C);
 %table_properties(TBL_NAME=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_C);

*SASDOC--------------------------------------------------------------------------
| Call the macro %prescriber_parms. The logic in the macro determines whether
| prescriber check is actualy performed.
+------------------------------------------------------------------------SASDOC*;
 %prescriber_parms(tbl_name_in=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_C,
                                   tbl_name_out2=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_D);

 %table_properties(TBL_NAME=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_D);

*SASDOC--------------------------------------------------------------------------
| Call the macro %eligibility_check for all programs except Quality Mailings-105.
+------------------------------------------------------------------------SASDOC*;
 %eligibility_check(tbl_name_in=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_D,
                    tbl_name_out2=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_E,
                    Execute_condition=%STR(&PROGRAM_ID NE 105));

*SASDOC--------------------------------------------------------------------------
| Call the macro resolve_client for all programs except 105. The CPGs are included
| when the macro variable &CPG_CONDITION resolves to IS NOT NULL and excluded
| if this variable resolves to IS NULL.
+------------------------------------------------------------------------SASDOC*;

*SASDOC--------------------------------------------------------------------------
| CALL %get_moc_phone
| Add the Mail Order pharmacy and customer service phone to the cpg file
+------------------------------------------------------------------------SASDOC*;
  %get_moc_csphone(TBL_NAME_IN=&&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_E,
                   TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_G);
  %table_properties(TBL_NAME=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_G);

*SASDOC--------------------------------------------------------------------------
| Check for mailings that are for subsets of a client while only selecting
| the eligible participants.  Add the letter rule sequence (default 0).
+------------------------------------------------------------------------SASDOC*;

  %drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_B);

  PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_B    AS
      (  SELECT  A.PRESCRIBER_ID AS NTW_PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID,
                                                 A.PT_BENEFICIARY_ID,
                                 A.BIRTH_DT,
                                 A.RX_COUNT_QY,
                                 A.CLIENT_ID,
                                 A.CLIENT_NM,
                                 B.CS_AREA_PHONE,
                                 B.MOC_PHM_CD,
                                 0 AS LTR_RULE_SEQ_NB
                                 &DRUG_FIELDS_LIST.
                  FROM  &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM                      AS A,
                                &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_G         AS B
      )DEFINITION ONLY NOT LOGGED INITIALLY
               ) BY DB2;
   DISCONNECT FROM DB2;
QUIT;
%set_error_fl;

%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative Id &INITIATIVE_ID");

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
EXECUTE
  (ALTER TABLE &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_B ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;
EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_B
                SELECT                   A.PRESCRIBER_ID                AS NTW_PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID,
                                                 A.PT_BENEFICIARY_ID,
                                 MAX(A.BIRTH_DT)                AS BIRTH_DT,
                                 SUM(A.RX_COUNT_QY)     AS      RX_COUNT_QY,
                                 MAX(A.CLIENT_ID)               AS CLIENT_ID,
                                 MAX(A.CLIENT_NM)               AS CLIENT_NM,
                                 MAX(CS_AREA_PHONE)             AS CS_AREA_PHONE,
                                 MAX(MOC_PHM_CD)                AS MOC_PHM_CD,
                                 MAX(0)                         AS LTR_RULE_SEQ_NB
                                 &DRUG_FIELDS_LIST.

                 FROM    &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM                      AS A,
                         &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_G          AS B
        WHERE                   A.PRESCRIBER_ID=B.PRESCRIBER_ID
                  AND   A.CDH_BENEFICIARY_ID=B.CDH_BENEFICIARY_ID
                  AND   A.PT_BENEFICIARY_ID=B.PT_BENEFICIARY_ID
                        GROUP BY A.PRESCRIBER_ID,
                                         A.CDH_BENEFICIARY_ID,
                                         A.PT_BENEFICIARY_ID
                                         &DRUG_FIELDS_LIST.
                             ) BY DB2;
  %PUT SQLXRC=&SQLXRC SYSERR=&SYSERR;
  %reset_sql_err_cd;
   * DISCONNECT FROM DB2;
QUIT;
   %PUT SQLXRC=&SQLXRC SYSERR=&SYSERR;
/*
 %LET SQLXRC=100;
 %PUT SYSERR=&SYSERR;

  %reset_sql_err_cd;
  %PUT SQLXRC=&SQLXRC;
  %PUT SYSERR=&SYSERR;
*/

%set_error_fl;

%runstats(TBL_NAME=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_B);
%table_properties(TBL_NAME=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_B);

/*
%LET DEBUG_FLAG=Y;
*/

%create_base_file(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_B);

/*** ADD last fill date to the file ****/


PROC SQL;
     CONNECT TO DB2 (DSN=&UDBSPRP);
     CREATE TABLE DATA_PND.LAST_FILL_DT AS
     SELECT * FROM CONNECTION TO DB2
(

SELECT  A.NTW_PRESCRIBER_ID    AS PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID,
                                 A.PT_BENEFICIARY_ID,
                                 MAX(A.FILL_DT) MAX_FILL_DT
                 FROM    &CLAIMSA..&CLAIM_HIS_TBL   AS A,
                                 &DB2_TMP..&TABLE_PREFIX._RVW_DATES AS B,
                                                 &DB2_TMP..&TABLE_PREFIX._NDC           AS D
        WHERE A.FILL_DT BETWEEN CLAIM_BEGIN_DT AND CLAIM_END_DT
				   AND    A.BILLING_END_DT IS NOT NULL
                   AND    B.DRG_GROUP_SEQ_NB=D.DRG_GROUP_SEQ_NB
                   AND    B.DRG_SUB_GRP_SEQ_NB=D.DRG_SUB_GRP_SEQ_NB
                   AND    A.DRUG_NDC_ID = D.DRUG_NDC_ID
                   AND    A.NHU_TYPE_CD = D.NHU_TYPE_CD
                                  &CLIENT_ID_CONDITION
                   &DELIVERY_SYSTEM_CONDITION
         AND NOT EXISTS
              (SELECT 1
               FROM &CLAIMSA..&CLAIM_HIS_TBL
               WHERE A.BENEFIT_REQUEST_ID = BENEFIT_REQUEST_ID
               AND   A.BRLI_NB = BRLI_NB
               AND   BRLI_VOID_IN > 0)
                        GROUP BY A.NTW_PRESCRIBER_ID,
                                         A.CDH_BENEFICIARY_ID,
                                         A.PT_BENEFICIARY_ID
      ); DISCONNECT FROM DB2;
QUIT;

PROC SQL;
     CREATE TABLE DATA_PND.&TABLE_PREFIX._1  AS
     SELECT A.*, B.MAX_FILL_DT
     FROM DATA_PND.&TABLE_PREFIX._1 A, DATA_PND.LAST_FILL_DT B
      WHERE A.NTW_PRESCRIBER_ID= B.PRESCRIBER_ID
         AND   A.CDH_BENEFICIARY_ID= B.CDH_BENEFICIARY_ID
         AND   A.RECIPIENT_ID=B.PT_BENEFICIARY_ID; QUIT;


*SASDOC-------------------------------------------------------------------------
| Check for Stellent ID and add to file layout if available.  Set the
| doc_complete_in variable.
+-----------------------------------------------------------------------SASDOC*;
%check_document;

%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative Id &INITIATIVE_ID");

*SASDOC-------------------------------------------------------------------------
| Check for autorelease of file.
+-----------------------------------------------------------------------SASDOC*;
%autorelease_file(INIT_ID=&INITIATIVE_ID, PHASE_ID=&PHASE_SEQ_NB);

%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative Id &INITIATIVE_ID");

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
