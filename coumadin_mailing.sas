/*HEADER------------------------------------------------------------------------

|

| PROGRAM:  coumadin_mailing.sas

|

| LOCATION: /PRG/sas&sysmode.1/hercules/106

|

| PURPOSE:  Used to produce task #30 (Coumadin - Warfarin mailing mailing).

|

| LOGIC:    Weekly mailing to inform business of a manufacturer change

|

| INPUT:    TABLES ACCESSED BY CALLED MACROS ARE NOT LISTED BELOW

|

|

| OUTPUT:   standard files in /pending and /results directories

|

|

+-------------------------------------------------------------------------------

| HISTORY:  MAY 2005  - P.Wonders - Original.

|           22MAY2006 - G. Dudley - Updated code to extract and compare the 

|                                   manufacturer ID with the manufacturer ID 

|                                   from the previously filled script.

|			Jan, 2007	- Kuladeep M	  Added Claim end date is not null when

|										  fill_dt between claim begin date and claim end

|										  date.

|

|	    Mar  2007    - Greg Dudley Hercules Version  1.0                                      

|

+-----------------------------------------------------------------------HEADER*/



%LET err_fl=0;

%set_sysmode;

/*options sysparm='INITIATIVE_ID=128 PHASE_SEQ_NB=1';*/

%INCLUDE "/herc&sysmode/prg/hercules/hercules_in.sas";



%LET ERR_FL=0;

%LET PROGRAM_NAME=COUMADIN_MAILING;

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

| Get the claim review dates.  No NDCs will be selected.

+-----------------------------------------------------------------------SASDOC*;



 %get_ndc(DRUG_NDC_TBL=&DB2_TMP..&TABLE_PREFIX._NDC,

          CLAIM_DATE_TBL=&DB2_TMP..&TABLE_PREFIX._RVW_DATES);





DATA _NULL_;

 SET &DB2_TMP..&TABLE_PREFIX._RVW_DATES;

  CALL SYMPUT('CLAIM_BEGIN_DT',COMPRESS(CLAIM_BEGIN_DT));

  CALL SYMPUT('CLAIM_END_DT',COMPRESS(CLAIM_END_DT));

  CALL SYMPUT('CLAIM_BEGIN_DT_db2',"'" || PUT(CLAIM_BEGIN_DT, MMDDYY10.) || "'") ;

  CALL SYMPUT('CLAIM_END_DT_db2',"'" || PUT(CLAIM_END_DT, MMDDYY10.) || "'");

RUN;



%PUT CLAIM_BEGIN_DT=&CLAIM_BEGIN_DT;

%PUT CLAIM_END_DT=&CLAIM_END_DT;

%PUT CLAIM_BEGIN_DT_db2=&CLAIM_BEGIN_DT_db2;

%PUT CLAIM_END_DT_db2=&CLAIM_END_DT_db2;





 %on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,

           EM_SUBJECT="HCE SUPPORT:  Notification of Abend",

           EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log");



*SASDOC-------------------------------------------------------------------------

| Find members who have filled a prescription for Coumadin or warfarin in the

| date range (generally a week).

+-----------------------------------------------------------------------SASDOC*;

PROC SQL NOPRINT;

  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);

    CREATE TABLE WORK.RECENT_FILLS AS

	 SELECT * FROM CONNECTION TO DB2

	  ( SELECT DISTINCT A.PT_BENEFICIARY_ID,

                        A.CDH_BENEFICIARY_ID,

                        A.NTW_PRESCRIBER_ID,

                        A.CLIENT_ID AS CLIENT_ID,

                        0 AS LTR_RULE_SEQ_NB,

                        A.PT_BIRTH_DT AS PT_BIRTH_DT,

                        B.MANUFACTURER,

						A.DRUG_NDC_ID,

						A.NHU_TYPE_CD,

						A.FILL_DT



                 FROM  CLAIMSA.TRXCLM_BASE A,

                      QCPAP020.TCOUMADIN_WARFARIN B

                 WHERE A.DRUG_NDC_ID = B.DRUG_NDC_ID

                 AND   A.NHU_TYPE_CD = B.NHU_TYPE_CD

                 AND   FILL_DT BETWEEN &CLAIM_BEGIN_DT_db2. AND &CLAIM_END_DT_db2.

				 AND   A.BILLING_END_DT IS NOT NULL

                 AND   BILLING_END_DT >= &CLAIM_BEGIN_DT_db2.

                 AND   DELIVERY_SYSTEM_CD = 2

                 AND NOT EXISTS

                          (SELECT 1 FROM CLAIMSA.TRXCLM_BASE

                           WHERE A.BENEFIT_REQUEST_ID = BENEFIT_REQUEST_ID

                           AND   A.BRLI_NB = BRLI_NB

                           AND   A.BRLI_VOID_IN > 0)

			)

		ORDER BY PT_BENEFICIARY_ID,DRUG_NDC_ID,NHU_TYPE_CD,FILL_DT;

	  DISCONNECT FROM DB2;

   QUIT;

 %set_error_fl;



   DATA WORK.RECENT_FILLS1;

    SET WORK.RECENT_FILLS;

	 BY PT_BENEFICIARY_ID DRUG_NDC_ID NHU_TYPE_CD FILL_DT;

	  IF LAST.NHU_TYPE_CD;

	RUN;

  %set_error_fl;

 

%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._RECENT_FILLS);



PROC SQL;

 CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);

  EXECUTE (CREATE TABLE &DB2_TMP..&TABLE_PREFIX._RECENT_FILLS AS

    (SELECT 			A.PT_BENEFICIARY_ID,

                        A.CDH_BENEFICIARY_ID,

                        A.NTW_PRESCRIBER_ID,

                        A.CLIENT_ID AS CLIENT_ID,

                        0 AS LTR_RULE_SEQ_NB,

                        A.PT_BIRTH_DT AS PT_BIRTH_DT,

                        B.MANUFACTURER,

						A.DRUG_NDC_ID,

						A.NHU_TYPE_CD,

						A.FILL_DT



                 FROM  CLAIMSA.TRXCLM_BASE A,

                      QCPAP020.TCOUMADIN_WARFARIN B) DEFINITION ONLY

	)BY DB2;

   DISCONNECT FROM DB2;

   QUIT;

 %set_error_fl;



   PROC SQL;

   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);

    INSERT INTO &DB2_TMP..&TABLE_PREFIX._RECENT_FILLS 

  			SELECT * FROM WORK.RECENT_FILLS1

		;

   DISCONNECT FROM DB2;

   QUIT;

 %set_error_fl;



%runstats(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._RECENT_FILLS);



*SASDOC-------------------------------------------------------------------------

| Gather all fills for Coumadin/warfarin in the past 180 days.

+-----------------------------------------------------------------------SASDOC*;



 PROC SQL NOPRINT;

  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);

    CREATE TABLE WORK.NEW_FILLS AS

	 SELECT * FROM CONNECTION TO DB2

	  (SELECT DISTINCT

                        D.PT_BENEFICIARY_ID,

                        MAX(D.CDH_BENEFICIARY_ID) 	AS CDH_BENEFICIARY_ID,

                        D.NTW_PRESCRIBER_ID,

                        MAX(D.CLIENT_ID) 			AS CLIENT_ID,

                        MAX(D.LTR_RULE_SEQ_NB) 		AS LTR_RULE_SEQ_NB,

                        MAX(D.PT_BIRTH_DT) 			AS PT_BIRTH_DT,

                        MAX(D.MANUFACTURER) 		AS MANUFACTURER,

						D.DRUG_NDC_ID,

						D.NHU_TYPE_CD,

						D.FILL_DT,

						A.DRUG_NDC_ID 				AS PREV_DRUG_NDC_ID,

						A.FILL_DT 					AS PREV_FILL_DT				

                 FROM 			 CLAIMSA.TRXCLM_BASE A	

                      INNER JOIN QCPAP020.TCOUMADIN_WARFARIN B

					  		 ON A.DRUG_NDC_ID = B.DRUG_NDC_ID

                 	 		AND A.NHU_TYPE_CD = B.NHU_TYPE_CD

               		  RIGHT JOIN &DB2_TMP..&TABLE_PREFIX._RECENT_FILLS D

                   		 	   ON A.PT_BENEFICIARY_ID = D.PT_BENEFICIARY_ID

							  AND   A.FILL_DT < D.FILL_DT

                 WHERE  A.FILL_DT BETWEEN (CURRENT DATE - 180 DAYS) AND &CLAIM_END_DT_db2.	 

				 AND   A.BILLING_END_DT IS NOT NULL

                 AND   A.BILLING_END_DT > CURRENT DATE - 180 DAYS

                 AND   A.DELIVERY_SYSTEM_CD = 2

				 AND NOT EXISTS

                          (SELECT 1 FROM CLAIMSA.TRXCLM_BASE

                           WHERE A.BENEFIT_REQUEST_ID = BENEFIT_REQUEST_ID

                           AND   A.BRLI_NB = BRLI_NB

                           AND   A.BRLI_VOID_IN > 0)

					GROUP BY D.PT_BENEFICIARY_ID,

	                         D.NTW_PRESCRIBER_ID,

							 D.DRUG_NDC_ID,

							 D.NHU_TYPE_CD,

							 D.FILL_DT,

							 A.DRUG_NDC_ID,

							 A.FILL_DT

				)

			ORDER BY PT_BENEFICIARY_ID,DRUG_NDC_ID,NHU_TYPE_CD,FILL_DT,PREV_FILL_DT;

  DISCONNECT FROM DB2;

QUIT;



%set_error_fl;



*SASDOC-------------------------------------------------------------------------

| 22MAY2006 - Gregory Dudley

| Updated this step to extract and compare the manufacturer ID with the 

| manufacturer ID from the last filled script.

+-----------------------------------------------------------------------SASDOC*;

DATA WORK.NEW_FILLS1;

 LENGTH CHAR_DRUG_NDC_ID CHAR_PREV_DRUG_NDC_ID $11 CURRENT_DOSAGE 

        PREV_DOSAGE $6;

 SET WORK.NEW_FILLS;

  BY PT_BENEFICIARY_ID DRUG_NDC_ID NHU_TYPE_CD FILL_DT PREV_FILL_DT;

  IF LAST.FILL_DT;

  /****************************************************************

   * PAD THE CURRENT NDC ID WITH LEADING ZEROS TO A LENGTH OF $11

   * THEN PARSE OUT THE MANFC NUMBER AND DOSAGE

   * G. Dudley

   ****************************************************************/

  CHAR_DRUG_NDC_ID = PUT(DRUG_NDC_ID,z11.);

  MANUFACT=SUBSTR(CHAR_DRUG_NDC_ID,1,5);

  CURRENT_DOSAGE=SUBSTR(CHAR_DRUG_NDC_ID,6,6);

  /****************************************************************

   * PAD THE PREVIOUS NDC ID WITH LEADING ZEROS TO A LENGTH OF $11

   * THEN PARSE OUT THE MANFC NUMBER AND DOSAGE

   * G. Dudley

   ****************************************************************/

  CHAR_PREV_DRUG_NDC_ID = PUT(PREV_DRUG_NDC_ID,z11.);

  PREV_MANUFACT=SUBSTR(CHAR_PREV_DRUG_NDC_ID,1,5);

  PREV_DOSAGE=SUBSTR(CHAR_PREV_DRUG_NDC_ID,6,6);

  IF MANUFACT NE PREV_MANUFACT;

  IF LAST.PT_BENEFICIARY_ID;

RUN; 

%set_error_fl;

%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS);



*SASDOC-------------------------------------------------------------------------

| 22MAY2006 - Gregory Dudley

| Remove analysis variables so insertion into the DB2 table will not fail.

+-----------------------------------------------------------------------SASDOC*;

DATA WORK.NEW_FILLS1;

  SET WORK.NEW_FILLS1;

  DROP MANUFACT PREV_MANUFACT CHAR_DRUG_NDC_ID CHAR_PREV_DRUG_NDC_ID

       CURRENT_DOSAGE PREV_DOSAGE;

RUN;



PROC SQL NOPRINT;

  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);



    EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS AS

                (SELECT PT_BENEFICIARY_ID,

                        CDH_BENEFICIARY_ID,

                        NTW_PRESCRIBER_ID,

                        CLIENT_ID				AS CLIENT_ID,

                        LTR_RULE_SEQ_NB 		AS LTR_RULE_SEQ_NB,

                        PT_BIRTH_DT				AS PT_BIRTH_DT,

                        MANUFACTURER		 	AS MANUFACTURER,

						DRUG_NDC_ID,

						NHU_TYPE_CD,

						FILL_DT,

						DRUG_NDC_ID 				AS PREV_DRUG_NDC_ID,

						FILL_DT 					AS PREV_FILL_DT				

                 FROM 	&DB2_TMP..&TABLE_PREFIX._RECENT_FILLS) DEFINITION ONLY

			) BY DB2;

 DISCONNECT FROM DB2;

QUIT;

%set_error_fl;

  



   PROC SQL;

   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);

    INSERT INTO &DB2_TMP..&TABLE_PREFIX._CLAIMS 

  			SELECT * FROM WORK.NEW_FILLS1

		;

   DISCONNECT FROM DB2;

   QUIT;

%set_error_fl;



%runstats(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CLAIMS); 





*SASDOC-------------------------------------------------------------------------

| Check for current eligibility.

+-----------------------------------------------------------------------SASDOC*;



%eligibility_check(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._CLAIMS,

                   TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG,

                   CLAIMSA=&CLAIMSA);



 *SASDOC-------------------------------------------------------------------------

| Check for members that have multiple manufacturers and filter out

| ineligible members.

+-----------------------------------------------------------------------SASDOC*;

%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS2);



PROC SQL NOPRINT;

  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);

    EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS2 AS

                (SELECT A.PT_BENEFICIARY_ID,

                        A.CDH_BENEFICIARY_ID,

                        NTW_PRESCRIBER_ID,

                        A.CLIENT_ID				AS CLIENT_ID,

                        LTR_RULE_SEQ_NB 		AS LTR_RULE_SEQ_NB,

                        PT_BIRTH_DT				AS BIRTH_DT,

                        MANUFACTURER		 	AS MANUFACTURER,

						DRUG_NDC_ID,

						NHU_TYPE_CD,

						FILL_DT,

						PREV_DRUG_NDC_ID,

						PREV_FILL_DT,

						CLT_PLAN_GROUP_ID,

                 		C.CLIENT_NM,	

						2							AS N	

                 FROM 	&DB2_TMP..&TABLE_PREFIX._CLAIMS A,

                      &DB2_TMP..&TABLE_PREFIX._CPG_ELIG B,

                      CLAIMSA.TCLIENT1 C

				) DEFINITION ONLY

			) BY DB2;

 DISCONNECT FROM DB2;

QUIT;

%set_error_fl;



PROC SQL NOPRINT;

  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP); 

    EXECUTE(

       INSERT INTO &DB2_TMP..&TABLE_PREFIX._CLAIMS2

              SELECT DISTINCT

                        A.PT_BENEFICIARY_ID,

                        A.CDH_BENEFICIARY_ID,

                        NTW_PRESCRIBER_ID,

                        A.CLIENT_ID				AS CLIENT_ID,

                        LTR_RULE_SEQ_NB 		AS LTR_RULE_SEQ_NB,

                        PT_BIRTH_DT				AS BIRTH_DT,

                        MANUFACTURER		 	AS MANUFACTURER,

						DRUG_NDC_ID,

						NHU_TYPE_CD,

						FILL_DT,

						PREV_DRUG_NDC_ID,

						PREV_FILL_DT,

						CLT_PLAN_GROUP_ID,

                 		C.CLIENT_NM,	

						2							AS N

                 FROM &DB2_TMP..&TABLE_PREFIX._CLAIMS A,

                      &DB2_TMP..&TABLE_PREFIX._CPG_ELIG B,

                      CLAIMSA.TCLIENT1 C

                 WHERE A.PT_BENEFICIARY_ID = B.PT_BENEFICIARY_ID

                 AND   C.CLIENT_ID = A.CLIENT_ID

    ) BY DB2;

  DISCONNECT FROM DB2;

QUIT;

%set_error_fl;

%runstats(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CLAIMS2);







 *SASDOC--------------------------------------------------------------------------

| CALL %get_moc_phone

| Add the Mail Order pharmacy and customer service phone to the cpg file

+------------------------------------------------------------------------SASDOC*;

 %get_moc_csphone(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._CLAIMS2,

                  TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CPG_MOC);



*SASDOC-------------------------------------------------------------------------

| Get beneficiary address and create SAS file layout.

+-----------------------------------------------------------------------SASDOC*;



%create_base_file(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._CPG_MOC);





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

%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._MEMBMERS);

%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS);

%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS2);

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

