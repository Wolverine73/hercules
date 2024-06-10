%include '/user1/qcpap020/autoexec_new.sas';

/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  Value of Benefits Statement
|
| LOGIC:    This mailing is used to provide a comprehensive statement to
|           participants of utilization history.
|
|           The statement summarizes fills for a defined date range.  It is rare
|           that all fields are actually used from this file layout but the
|           file is general purpose.
|
|           When new claims table becomes available this code should be modified.
|           The code was initially tested but macros have been added and it is
|           clearly marked where incomplete macros need to be inserted.
|
| LOCATION: /PRG/sas&sysmode.1/hercules/106
|
| INPUT:    &CLAIMSA..&CLAIM_HIS_TBL A,
|           &CLAIMSA..TBENEF_XREF_DN B,
|           &CLAIMSA..TCLIENT1 C,
|           &CLAIMSA..TDRUG1 D,
|           &CLAIMSA..TPHARM_PHARMACY E,
|           &CLAIMSA..TRXCLM_BASE_EXT F
|
| OUTPUT:   STANDARD OUTPUT FILES IN /pending and /results directories
+--------------------------------------------------------------------------------
| HISTORY:  02OCT2003 - P.Wonders - Original.
|
|			01JAN2007	- Kuladeep M	  Added Claim end date is not null when
|										  fill_dt between claim begin date and claim end
|										  date.
|
|	        01MAR2007    - Greg Dudley Hercules Version  1.0                                      
|
|           01MAY2011     - Brian Stropich - Hercules Version  2.1.0
|                           Adjusted the program for an Rx number - character of 12.
|
|           09JUL2012 - P. Landis - modified to use new hercdev2 file system  
+------------------------------------------------------------------------HEADER*/




%LET err_fl=0;
%set_sysmode;

/* options sysparm='INITIATIVE_ID=  PHASE_SEQ_NB=1' ;  */
%include "/herc&sysmode/prg/hercules/hercules_in.sas";
options mlogic mlogicnest mprint mprintnest symbolgen source2;
%LET PROGRAM_NAME=value_of_benefits;


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
%resolve_client(TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CLT_CPG) ;

PROC SQL NOPRINT;
   SELECT DISTINCT CLIENT_ID INTO :CLIENT_IDS SEPARATED BY ','
   FROM &DB2_TMP..&TABLE_PREFIX._CLT_CPG;
QUIT;
%PUT CLIENT_IDS = &CLIENT_IDS;


*SASDOC--------------------------------------------------------------------------
| Call %get_ndc to determine the dates for the mailing.
| This mailing is always for all drugs so only one table is needed but two names
| are required as macro parameters.
+------------------------------------------------------------------------SASDOC*;
%get_ndc(DRUG_NDC_TBL=&DB2_TMP..&TABLE_PREFIX._NDC,
         CLAIM_DATE_TBL=&DB2_TMP..&TABLE_PREFIX._RVW_DATES);

PROC SQL NOPRINT;
    SELECT
           "'"||PUT(CLAIM_BEGIN_DT, MMDDYY10.)||"'",
           "'"||PUT(CLAIM_END_DT, MMDDYY10.)||"'"
    INTO   :CLAIM_BEGIN_DT, :CLAIM_END_DT
    FROM   &DB2_TMP..&TABLE_PREFIX._RVW_DATES
    WHERE  DRG_GROUP_SEQ_NB=1;
QUIT;

%PUT BEGIN_DT=&CLAIM_BEGIN_DT END_DT=&CLAIM_END_DT;


*SASDOC--------------------------------------------------------------------------
| RETRIEVE THE CLAIM DATA.
+------------------------------------------------------------------------SASDOC*;
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS_A);
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS1);

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS_A
      (    CDH_BENEFICIARY_ID INTEGER,
           PT_BENEFICIARY_ID INTEGER,
           DRG_GROUP_SEQ_NB SMALLINT,
           BIRTH_DT DATE,
           CLIENT_ID INTEGER,
           CLIENT_NM CHAR(30),
           DELIVERY_SYSTEM_CD SMALLINT,
           BRAND_GENERIC      CHAR(18),
           FORMULARY_TX       CHAR(30),
           DRUG_ABBR_PROD_NM CHAR(12),
           DRUG_ABBR_STRG_NM CHAR(8),
           DRUG_ABBR_DSG_NM CHAR(3),
           CALC_GROSS_COST    DECIMAL(11,2),
           COPAY_AT           DECIMAL(11,2),
           MEMBER_COST_AT     DECIMAL(11,2),
           NET_COST_AT        DECIMAL(11,2),
           DEDUCTIBLE_AT      DECIMAL(11,2),
           CDH_DAW_DIFF_AT    DECIMAL(11,2),
           EXCESS_OOP_AT      DECIMAL(11,2),
           EXCESS_MAB_AT      DECIMAL(11,2),
           APPLIED_MAB_AT     DECIMAL(11,2),
           SUBMITTD_CHRG_AT   DECIMAL(11,2),
           RX_NB              CHAR(12),
           PHARMACY_NM        CHAR(30),
           FILL_DT DATE, /* NEW FIELDS FROM TRXCLM_BASE */
           RX_COUNT_QY        INTEGER,
           PRESCRIBER_NM      CHAR(60),
           DISPENSED_QY       DECIMAL(12,3),
           APPLIED_OOP_AT     DECIMAL(11,2),
           DAY_SUPPLY_QY SMALLINT,
		   REFILL_FILL_QY SMALLINT,
		   FORMULARY_TX1 CHAR(30),
		   MBR_ID CHAR(25),
		   LAST_DELIVERY_SYS SMALLINT,
		   GCN_CODE INTEGER ,
		   DEA_NB CHAR(9),
 		   PRESCRIBER_NPI_NB CHAR(10),
		   GPI_THERA_CLS_CD CHAR(14),
 		   DRUG_NDC_ID DECIMAL(11) NOT NULL,
		   NABP_ID CHAR(7),
		   CLT_PLAN_GROUP_ID INTEGER,
		   NTW_PRESCRIBER_ID INTEGER

      ) not logged initially) BY DB2;
  DISCONNECT FROM DB2;
QUIT;

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
    EXECUTE(ALTER TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS_A
            ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;

   EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX._CLAIMS_A
      (  SELECT  A.CDH_BENEFICIARY_ID,
                 A.PT_BENEFICIARY_ID,
                 1,
                 B.BIRTH_DT,
                 A.CLIENT_ID,
                 C.CLIENT_NM,
                 DELIVERY_SYSTEM_CD,
                 CASE CALC_BRAND_CD
                   WHEN 0 THEN 'GENERIC'
                   WHEN 1 THEN 'BRAND W/O GENERIC'
                   ELSE 'BRAND WITH GENERIC'
                 END,
                 CASE FORMULARY_IN
                   WHEN 3 THEN 'PREFERRED'
                   WHEN 4 THEN 'PREFERRED'
                   ELSE 'NON-PREFERRED'
                 END AS FORMULARY_TX,
                 D.DRUG_ABBR_PROD_NM,
                 D.DRUG_ABBR_STRG_NM,
                 D.DRUG_ABBR_DSG_NM,
                 A.CALC_GROSS_COST,
                 A.COPAY_AT,
                 A.MEMBER_COST_AT,
                 A.NET_COST_AT,
                 A.DEDUCTIBLE_AT,
                 A.CDH_DAW_DIFF_AT,
                 F.EXCESS_OOP_AT,
                 A.EXCESS_MAB_AT,
                 A.APPLIED_MAB_AT,
                 CASE
                    WHEN DELIVERY_SYSTEM_CD = 2 THEN (DRG_AWP_PRICE * DISPENSED_QY)
                    ELSE UNC_AT
                 END,
                 A.RX_NB,
                 E.PHARMACY_NM,
                 A.FILL_DT  AS LAST_FILL_DT , 
                 A.RX_COUNT_QY,
                 G.PRESCRIBER_NM,
                 A.DISPENSED_QY,
                 A.APPLIED_OOP_AT, 
		       	 A.DAY_SUPPLY_QY ,
		         A.REFILL_NB as REFILL_FILL_QY,
		         CAST(A.FORMULARY_ID as char(30)) as FORMULARY_TX1 ,
		   		 B.BENEFICIARY_ID as MBR_ID,
		         A.DELIVERY_SYSTEM_CD as LAST_DELIVERY_SYS,
		   		 D.DGH_GCN_CD as GCN_CODE,
		   		 G.PRESCRIBER_DEA_NB as DEA_NB,
 		   		 G.PRESCRIBER_NPI_NB ,
		   		 cast(D.GPI_GROUP as char(2))||cast(D.GPI_CLASS as char(2))||cast(D.GPI_SUBCLASS as char(2))||cast(D.GPI_NAME as char(2))||cast(D.GPI_NAME_EXTENSION as char(2))||cast(D.GPI_FORM as char(2))||cast(D.GPI_STRENGTH as char(2)) AS GPI_THERA_CLS_CD,
 		         D.DRUG_NDC_ID,
				 A.NABP_ID,
				 A.CLT_PLAN_GROUP_ID,
				 A.NTW_PRESCRIBER_ID

         FROM    &CLAIMSA..&CLAIM_HIS_TBL A,
                 &CLAIMSA..TBENEF_XREF_DN B,
                 &CLAIMSA..TCLIENT1 C,
                 &CLAIMSA..TDRUG1 D,
                 &CLAIMSA..TPHARM_PHARMACY E,
                 &CLAIMSA..TRXCLM_BASE_EXT F,
                 &CLAIMSA..TPRSCBR_PRESCRIBE1 G

         WHERE   A.CLIENT_ID IN (&CLIENT_IDS)
         AND     A.PT_BENEFICIARY_ID = B.BENEFICIARY_ID
         AND     A.CLIENT_ID = C.CLIENT_ID
         AND     A.NABP_ID = E.NABP_ID
         AND     A.DRUG_NDC_ID = D.DRUG_NDC_ID
         AND     A.NHU_TYPE_CD = D.NHU_TYPE_CD
         AND     A.NTW_PRESCRIBER_ID = G.PRESCRIBER_ID
         AND     A.FILL_DT BETWEEN &CLAIM_BEGIN_DT AND &CLAIM_END_DT
         AND     A.BILLING_END_DT IS NOT NULL
         AND     A.BENEFIT_REQUEST_ID = F.BENEFIT_REQUEST_ID
         AND     A.BRLI_NB = F.BRLI_NB
         AND     A.BRLI_VOID_IN = F.BRLI_VOID_IN 
         AND NOT EXISTS
              (SELECT 1
               FROM &CLAIMSA..&CLAIM_HIS_TBL
               WHERE A.BENEFIT_REQUEST_ID = BENEFIT_REQUEST_ID
               AND   A.BRLI_NB = BRLI_NB
               AND   BRLI_VOID_IN > 0))

      ) BY DB2;
   DISCONNECT FROM DB2;
QUIT;

PROC SQL;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
CREATE TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS1 AS
    SELECT
	      A.*,
		  H.BLG_REPORTING_CD  , /*YM:ADD BASE COL: NEW FIELDS FROM TCPGRP_CLT_PLN_GR1 */
		  H.PLAN_CD,
		  H.PLAN_EXTENSION_CD as PLAN_EXT_CD_TX,
		  H.GROUP_CD,
		  H.GROUP_EXTENSION_CD as GROUP_EXT_CD_TX,
		  H.CLIENT_ID as CLIENT_LEVEL_1 ,
		  H.GROUP_CD as CLIENT_LEVEL_2,
		  H.BLG_REPORTING_CD as CLIENT_LEVEL_3
	FROM &DB2_TMP..&TABLE_PREFIX._CLAIMS_A A LEFT JOIN
		 &CLAIMSA..TCPGRP_CLT_PLN_GR1 AS H ON 
	      A.CLT_PLAN_GROUP_ID = H.CLT_PLAN_GROUP_ID
;
DISCONNECT FROM DB2;
QUIT;
%set_error_fl;

%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");


%RUNSTATS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._claims1);


*SASDOC--------------------------------------------------------------------------
| CALL %delivery_system_ck
| Excludes claims from specified delivery systems when applicable
|
+------------------------------------------------------------------------SASDOC*;
%delivery_system_check(initiative_id=&initiative_id,
                       tbl_name_in=&DB2_TMP..&TABLE_PREFIX._CLAIMS1,
                       tbl_name_out=&DB2_TMP..&TABLE_PREFIX._CLAIMS2,
                       HERCULE=&HERCULES);

*SASDOC--------------------------------------------------------------------------
| CALL %participant_parms
| Restrict the data by gender, age and number of rxs as specified
 +------------------------------------------------------------------------SASDOC*;
%participant_parms(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._CLAIMS2,
                   TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._PTS);


 *SASDOC--------------------------------------------------------------------------
| CALL %eligibility_check
| Exclude or include participants based on gender, age and prescription actvity
+------------------------------------------------------------------------SASDOC*;
%ELIGIBILITY_CHECK(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._CLAIMS2,
                       TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG);

*SASDOC--------------------------------------------------------------------------
| CALL %get_moc_phone
| Add the Mail Order pharmacy and customer service phone to the cpg file
 +------------------------------------------------------------------------SASDOC*;
%get_moc_csphone(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG,
                 TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG_MOC);


*SASDOC--------------------------------------------------------------------------
| Check for mailings that are for subsets of a client while only selecting
| the eligible participants and those who met the participant parameters.
| Add the letter rule sequence (default 0).
+------------------------------------------------------------------------SASDOC*;
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS3);

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._claims3
      (    LTR_RULE_SEQ_NB SMALLINT,
           PT_BENEFICIARY_ID INTEGER,
           BIRTH_DT DATE,
           CLIENT_ID INTEGER,
           CLIENT_NM CHAR(30),
           DELIVERY_SYSTEM CHAR(5),
           BRAND_GENERIC      CHAR(18),
           FORMULARY_TX       CHAR(13),
           DRUG_ABBR_PROD_NM CHAR(12),
           DRUG_ABBR_STRG_NM CHAR(8),
           DRUG_ABBR_DSG_NM CHAR(3),
           APPLIED_MAB_AT     DECIMAL(11,2),
           CALC_GROSS_COST    DECIMAL(11,2),
           COPAY_AT           DECIMAL(11,2),
           MEMBER_COST_AT     DECIMAL(11,2),
           NET_COST_AT        DECIMAL(11,2),
           DEDUCTIBLE_AT      DECIMAL(11,2),
           CDH_DAW_DIFF_AT    DECIMAL(11,2),
           EXCESS_OOP_AT      DECIMAL(11,2),
           EXCESS_MAB_AT      DECIMAL(11,2),
           SUBMITTD_CHRG_AT   DECIMAL(11,2),
           RX_NB              CHAR(12),
           PHARMACY_NM        CHAR(30),
           FILL_DT           DATE,
           MOC_PHM_CD         CHAR(3),
           CS_AREA_PHONE      CHAR(13),
           PRESCRIBER_NM      CHAR(60),
           DISPENSED_QY       DECIMAL(12,3),
           APPLIED_OOP_AT     DECIMAL(11,3),
		   BLG_REPORTING_CD CHAR(15) , /*YM:ADD BASE COL: NEW FIELDS FROM TCPGRP_CLT_PLN_GR1 */ 
           DAY_SUPPLY_QY SMALLINT,
		   REFILL_FILL_QY SMALLINT,
		   FORMULARY_TX1 CHAR(30),
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
		   DEA_NB CHAR(9),
 		   PRESCRIBER_NPI_NB CHAR(10),
		   GPI_THERA_CLS_CD CHAR(14),
 		   DRUG_NDC_ID DECIMAL(11) NOT NULL

      ) not logged initially) BY DB2;
   DISCONNECT FROM DB2;
QUIT;

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);

   EXECUTE(ALTER TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS3
            ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;

   EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX._claims3
      (SELECT DISTINCT
           0 as LTR_RULE_SEQ_NB,
           A.PT_BENEFICIARY_ID,
           BIRTH_DT,
           A.CLIENT_ID,
           CLIENT_NM,
           CASE DELIVERY_SYSTEM_CD
                   WHEN 3 THEN 'POS'
                   WHEN 2 THEN 'MAIL'
                   ELSE 'PAPER'
           END,
           BRAND_GENERIC,
           FORMULARY_TX,
           DRUG_ABBR_PROD_NM,
           DRUG_ABBR_STRG_NM,
           DRUG_ABBR_DSG_NM,
           APPLIED_MAB_AT,
           CALC_GROSS_COST,
           COPAY_AT,
           MEMBER_COST_AT,
           NET_COST_AT,
           DEDUCTIBLE_AT,
           CDH_DAW_DIFF_AT,
           EXCESS_OOP_AT,
           EXCESS_MAB_AT,
           SUBMITTD_CHRG_AT,
           RX_NB,
           PHARMACY_NM,
           FILL_DT AS LAST_FILL_DT,
           MOC_PHM_CD,
           CS_AREA_PHONE,
           PRESCRIBER_NM,
           DISPENSED_QY,
           APPLIED_OOP_AT,
		   A.BLG_REPORTING_CD  , /*YM:ADD BASE COL: NEW FIELDS FROM TCPGRP_CLT_PLN_GR1 */ 
		   A.DAY_SUPPLY_QY ,
		   A.REFILL_FILL_QY,
		   A.FORMULARY_TX1 ,
		   A.PLAN_CD,
		   A.PLAN_EXT_CD_TX,
		   A.GROUP_CD,
		   A.GROUP_EXT_CD_TX,
		   A.CLIENT_LEVEL_1 ,
		   A.CLIENT_LEVEL_2,
		   A.CLIENT_LEVEL_3,
		   A.MBR_ID,
		   A.LAST_DELIVERY_SYS,
		   A.GCN_CODE,
		   A.DEA_NB,
 		   A.PRESCRIBER_NPI_NB ,
		   A.GPI_THERA_CLS_CD,
 		   A.DRUG_NDC_ID 
      FROM &DB2_TMP..&TABLE_PREFIX._CLAIMS2 A,
           &DB2_TMP..&TABLE_PREFIX._CPG_ELIG_MOC B,
           &DB2_TMP..&TABLE_PREFIX._CLT_CPG C,
           &DB2_TMP..&TABLE_PREFIX._PTS D
      where A.PT_BENEFICIARY_ID = B.PT_BENEFICIARY_ID
      AND   A.PT_BENEFICIARY_ID = D.PT_BENEFICIARY_ID
      AND   C.CLT_PLAN_GROUP_ID = B.CLT_PLAN_GROUP_ID

      )) BY DB2;
   DISCONNECT FROM DB2;
QUIT;
%RUNSTATS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CLAIMS3);

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(
            UPDATE &DB2_TMP..&TABLE_PREFIX._claims3
            SET FORMULARY_TX = 'PREFERRED'
            WHERE BRAND_GENERIC = 'GENERIC')BY DB2;
   DISCONNECT FROM DB2;
QUIT;

*SASDOC-------------------------------------------------------------------------
| Call %create_base_file
+-----------------------------------------------------------------------SASDOC*;

%CREATE_BASE_FILE(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._CLAIMS3);

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
| Check for Stellent ID and add to file layout if available.  Set the
| doc_complete_in variable.
+-----------------------------------------------------------------------SASDOC*;
%check_document;
%add_client_variables(INIT_ID=&INITIATIVE_ID);

*SASDOC-------------------------------------------------------------------------
| Check for autorelease of file.
+-----------------------------------------------------------------------SASDOC*;
%AUTORELEASE_FILE(INIT_ID=&INITIATIVE_ID, PHASE_ID=&PHASE_SEQ_NB);


*SASDOC-------------------------------------------------------------------------
| Drop the temporary UDB tables
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
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");
