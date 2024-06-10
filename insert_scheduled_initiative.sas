%include '/user1/qcpap020/autoexec_new.sas';

options nomprint nomprintnest nomlogic nomlogicnest nosymbolgen nosource2;

/*HEADER------------------------------------------------------------------------
|
| PROGRAM:   insert_scheduled_initiative.sas
|
| LOCATION:  /PRG/sastest1/hercules/gen_utilities/sas
|
| PURPOSE:   Insert batch scheduling information into HERCULES tables based on
|            the SAS scheduling dataset-HERCULES_SCHEDULES. The program runs every
|            morning.
|
| LOGIC:     The program flows as follows:
|
|            Get scheduled jobs        ---> 
|            Assign new initiative_ids --->
|            Create temp datasets      --->
|            Insert new initiative records into HCE tables
|
| INPUT:     HERCULES Tables 
|            HERCULES_PROGRAM_SCHEDULES.sas7bdat
|
| OUTPUT:    HERCULES Tables
|
| REFERENCE: General Utility Programs, HCE
|
|
+--------------------------------------------------------------------------------
|
|
| HISTORY: Jun  2003 - J.Hou  - Original.
|          Jan  2005 - J.Hou  - Change the release from 'final' to 'preliminary' for
|                      all programs except retail to mail to avoid the file
|                      get archived before been validated.
|          Jul  2005 - G. Comerford - Updated Primary_programer_email.
|          Jan  2007 - B. Stropich  - Added aux_hercules_schedules.sas include
|                      to set Retail to Mail mailing to second Monday of each
|                      month.
|          Mar  2007 - B. Stropich  - updated sql for tphase_rvr_file for h2 
|                      and email code
|
|	   Mar  2007 - Greg Dudley - Hercules Version  1.0  
|
|	   July 2007 - Nick Williams - Hercules Version  1.5.01 
|                      Scheduled jobs were failing to be scheduled
|                      because of table changes and newly created tables
|                      during ibenefit2 project. Added code to insert into HERCULES.
|                      TINIT_ADJUD_ENGINE, modified insert into HERCULES.TSCREEN_STATUS
|                      to match table definition. Also added selection of no_autorelease_list
|                      from a sasdataset instead of hard-coded in program.
|
|	   Aug  2007 - B. Stropich - Hercules Version  1.5.02 
|                     Renamed HERCULES_NORELLIST to HERCULES_NO_AUTO_RELEASE
|
|	   Nov  2008 - B. Stropich - Hercules Version  2.1.2.01 
|                     1.  Created additional logic and two macros to insert 
|                         Non Book of Business and Book of Business 
|                         initiatives into Hercules.  
|                            a.  CreateBookOfBusinessSchedule
|                            b.  CreateNonBookOfBusinessSchedule   
|                     2.  Created a new SAS dataset HERCULES_PROGRAM_SCHEDULES
|                         to support the changes.
|                     3.  Added the following variables to the process because
|                         of the Novemeber Hercules release 
|                            a.  TPHASE_RVR_FILE   - ACT_NBR_OF_DAYS
|                            b.  TPHASE_RVR_FILE   - ELIGIBILITY_DT
|                            c.  TINITIATIVE_PHASE - INITIATIVE_STS_CD
|        
|
+------------------------------------------------------------------------HEADER*/

OPTIONS SYMBOLGEN MLOGIC MPRINT MLOGICNEST MPRINTNEST;

* %let sysmode=prod;
%set_sysmode;

%include "/herc&sysmode/prg/hercules/hercules_in.sas";
** bss - 01.25.2007 ;
%include "/herc&sysmode/prg/hercules/gen_utilities/sas/aux_hercules_schedules.sas";

%LET HCE_SCHMA=&USER.;

PROC SQL NOPRINT ;
 SELECT  QUOTE(TRIM(email)) INTO : Primary_programer_email SEPARATED BY ' ' 
 FROM ADM_LKP.ANALYTICS_USERS
 WHERE UPCASE(QCP_ID) IN ("&USER") ;
QUIT;

%PUT NOTE: Primary Programer Email=&Primary_programer_email;

LIBNAME xtables "/herc&sysmode/data/hercules/auxtables";
LIBNAME &HERCULES DB2 DSN=&UDBSPRP SCHEMA=&HERCULES DEFER=YES;

%let phase_seq_nb=1;
%let file_use=1; ** SET TO 1 FOR MAILING;
%let hce_id=%CMPRES(%str(%'&user.%'));
%let err_fl=0;
%put NOTE: HCE ID: &hce_id;


*SASDOC-------------------------------------------------------------------------
|  Build date variables for the scheduling
+------------------------------------------------------------------------- SASDOC*;
DATA _NULL_;
  DATE=PUT(TODAY(),DATE9.);
  CALL SYMPUT('DATE',DATE);
  CALL SYMPUT('THS_MON', "'"||put(month(today()),Z2.)||"'");
  CALL SYMPUT('TO_DAY' , "'"||put(day(date()),Z2.)||"'");
  CALL SYMPUT('WKDAY'  , "'"||put(weekday(date()),1.)||"'");
RUN;

%put NOTE: SYSDATE9: &SYSDATE9. ;
%put NOTE: DATE:     &DATE.     ;
%put NOTE: HCE ID:   &HCE_ID.   ;
%put NOTE: weekday:  &WKDAY.    ;
%put NOTE: today:    &TO_DAY.   ;
%put NOTE: month:    &THS_MON.  ;


*SASDOC-------------------------------------------------------------------------
|  July 2007 N. Williams - Obtain non-autorelease list data from the HERCULES_NO_AUTO_RELEASE
| /* This is for adhoc use only */
+------------------------------------------------------------------------- SASDOC*;
PROC SQL NOPRINT;
  SELECT PROGRAM_ID INTO :no_autorelease_list SEPARATED BY ','
  FROM XTABLES.HERCULES_NO_AUTO_RELEASE; 
QUIT;

%put NOTE: No Auto-release programs: &no_autorelease_list;

*SASDOC-------------------------------------------------------------------------
|  Obtain program task job schedule data from the HERCULES_SCHEDULES.
|
|  Definition of the conditions:
|  1.  first where condition is for Retail to Mail
|  2.  second where condition is for ARC Scheduling  
|  3.  third condition is for Retail DAW and Proactive Refill
+------------------------------------------------------------------------- SASDOC*;
PROC SQL;
  CREATE TABLE JOB_4_TODAY AS
  SELECT * 
  FROM  XTABLES.HERCULES_PROGRAM_SCHEDULES (rename=(bus_user_id=BUS_USER_ID))
  WHERE (     ( INDEX(DAY_OF_WEEK, &WKDAY)>0 OR DAY_OF_WEEK='*')
          AND ( INDEX(DAY, &TO_DAY) > 0 OR DAY='*')
          AND ( INDEX(MONTH, &THS_MON) >0 OR compress(MONTH)='*' )
          AND   ADHOC_FLAG ne -1)
  OR
        (     ( INDEX(DAY_OF_WEEK, &WKDAY)>0 OR DAY_OF_WEEK='*')
          AND ( INDEX(DAY, &TO_DAY) > 0 OR DAY='*')
          AND ( INDEX(MONTH, &THS_MON) >0 OR compress(MONTH)='*' )
          AND   TASK_FLAG > 0
          AND   ADHOC_FLAG ne -1)
  OR    
          ADHOC_FLAG = 1
  ORDER BY PROGRAM_ID; 
QUIT;
*SASDOC-------------------------------------------------------------------------
|  GSTP add-on
+------------------------------------------------------------------------- SASDOC*;
DATA JOB_4_TODAY_GSTP (KEEP=PROGRAM_ID TASK_ID ADJ_ENGINE_CD TASK_FLAG);
SET JOB_4_TODAY;
IF PROGRAM_ID = 5295 AND TASK_ID = 57 THEN OUTPUT;
IF PROGRAM_ID = 72 AND TASK_ID = 14 THEN OUTPUT;		/*	AK, 01MAY2012 - ADDED PROACTIVE REFILL */
RUN;

proc sort data = JOB_4_TODAY_GSTP nodupkey;
  by program_id task_id ADJ_ENGINE_CD;
run;

*SASDOC-------------------------------------------------------------------------
|  Extract the maxium value of the initiative id from TINITIATIVE table and
|  increment it sequentially for new initiatives.
+------------------------------------------------------------------------- SASDOC*;
PROC SQL noprint;
  SELECT CASE WHEN MAX(A.INITIATIVE_ID) <=0 THEN '0'
	 ELSE PUT(MAX(A.INITIATIVE_ID),20.) END
         INTO: MAX_INIT_ID
  FROM &HERCULES..TINITIATIVE A;
QUIT;

%put NOTE:  Maximum Initiative ID:  &MAX_INIT_ID. ;

*SASDOC-------------------------------------------------------------------------
|  Load data into DB2 table to reference for Non Book of Business and
|  Book of Business initiatives.
+------------------------------------------------------------------------- SASDOC*;
proc sql noprint; 
  drop TABLE &HCE_SCHMA..JOB_4_TODAY_%UPCASE(&SYSMODE); 
quit;

proc sort data = JOB_4_TODAY nodupkey;
  by program_id task_id client_id;
run;

PROC SQL noprint;
  CREATE TABLE JOB_4_TODAY  AS
  SELECT B.SHORT_TX , 
         A.*
  FROM JOB_4_TODAY       A, 
       CLAIMSA.TPROGRAM  B
  WHERE A.PROGRAM_ID=B.PROGRAM_ID;
QUIT;

data  JOB_4_TODAY ;
  format PROGRAM_NM $50. ;
  set JOB_4_TODAY ;
  if index(DESCRIPTION,'ARC') > 0 then PROGRAM_NM=trim(left(DESCRIPTION))||' - '||trim(left(CLIENT_NM));
  else if index(DESCRIPTION,'ALERT') > 0 then PROGRAM_NM=trim(left(DESCRIPTION))||' - '||trim(left(CLIENT_NM));
  else PROGRAM_NM=trim(SHORT_TX);
run;

data  JOB_4_TODAY ;
  **set JOB_4_TODAY (where=(client_id in (11703,10367,12508,13425))) ;**siho, state farm, bnsf, cps ;
  set JOB_4_TODAY ;
  INITIATIVE_ID=&MAX_INIT_ID+_N_;
run;
*SASDOC-------------------------------------------------------------------------
|  GSTP add-on
+------------------------------------------------------------------------- SASDOC*;
proc sort data = JOB_4_TODAY out= JOB_4_TODAY_A ;
  by PROGRAM_ID TASK_ID;
run;

DATA JOB_4_TODAY_GSTP (keep=INITIATIVE_ID ADJ_ENGINE_CD TASK_FLAG);
MERGE JOB_4_TODAY_GSTP (IN=A)
      JOB_4_TODAY_A      (IN=B DROP=ADJ_ENGINE_CD)
	  ;
by PROGRAM_ID TASK_ID;
IF A=1 AND B=1 THEN OUTPUT;
RUN;
proc sort data = JOB_4_TODAY ;
  by INITIATIVE_ID;
run;

data &HCE_SCHMA..JOB_4_TODAY_%UPCASE(&SYSMODE);
  set JOB_4_TODAY;
run;

*SASDOC-------------------------------------------------------------------------
|  Create a list of initiatives and programs for the support email.     
+------------------------------------------------------------------------- SASDOC*;
PROC SQL noprint;
  CREATE TABLE PROGRAM_TODAY AS
  SELECT PROGRAM_ID,
         PROGRAM_NM,
         SHORT_TX,  
         BUS_USER_ID,
	 CLIENT_NM,
	 INITIATIVE_ID
  FROM &HCE_SCHMA..JOB_4_TODAY_%UPCASE(&SYSMODE)  
  ORDER by INITIATIVE_ID;
QUIT;

data _null_;
 length day $ 2;
 day= put(day(today()),z2.);
 call symput('day', day);
run;

data XTABLES.PROGRAM_TODAY_&day;
 set PROGRAM_TODAY;
run;

PROC SQL noprint;
  SELECT PROGRAM_NM, COUNT(*) INTO :PROGRAMS SEPARATED BY ", " , :JOB_COUNTS
  FROM PROGRAM_TODAY; 
QUIT;

%PUT NOTE: Scheduled Jobs     for today: &JOB_COUNTS. ;
%PUT NOTE: Scheduled Programs for today: &PROGRAMS.   ;

*SASDOC-------------------------------------------------------------------------
| Macro: CreateNonBookOfBusinessSchedule
| Insert initiatives which are Non Book of Business                
+------------------------------------------------------------------------- SASDOC*;
%macro CreateNonBookOfBusinessSchedule;

	%global TOTALNONBOOKBUSINESS;

	proc sql noprint;
	  select count(*) into : TOTALNONBOOKBUSINESS
	  from  &HCE_SCHMA..JOB_4_TODAY_%UPCASE(&SYSMODE) 
	  where task_flag > 0 ;
	quit;	 
	
	%put NOTE:  TOTAL NON BOOK OF BUSINESS = &TOTALNONBOOKBUSINESS. ;
	
	%if &TOTALNONBOOKBUSINESS. > 0 %then %do;**** start TOTALNONBOOKBUSINESS loop;

	%let TOTAL=0;

	DATA _NULL_;
	  SET &HCE_SCHMA..JOB_4_TODAY_%UPCASE(&SYSMODE) (where = (task_flag > 0)) END=EOF;
	  I+1;
	  II=LEFT(PUT(I,3.));
		  CALL SYMPUT('PROGRAM_ID'||II, LEFT(PROGRAM_ID));
		  CALL SYMPUT('TASK_ID'||II, LEFT(TASK_ID));
		  CALL SYMPUT('CLIENT_ID'||II, LEFT(CLIENT_ID));
		  CALL SYMPUT('CLIENT_NM'||II, LEFT(CLIENT_NM));
		  CALL SYMPUT('PROGRAM_NM'||II, LEFT(PROGRAM_NM));
		  CALL SYMPUT('BUS_RQSTR_NM'||II, LEFT(BUS_RQSTR_NM));
		  CALL SYMPUT('CLAIMENDDATE'||II, LEFT(date_range_days));
		  CALL SYMPUT('MINMEMBERCOSTAT'||II, LEFT(MIN_MEMBER_COST_AT));
		  CALL SYMPUT('MINESMSAVEAT'||II, LEFT(MIN_ESM_SAVE_AT));
		  CALL SYMPUT('MAXMEMBERCOSTAT'||II, LEFT(MAX_MEMBER_COST_AT));
		  CALL SYMPUT('MINIMUMAGEAT'||II, LEFT(MINIMUM_AGE_AT));
		  CALL SYMPUT('OPERATORTX'||II, LEFT(OPERATOR_TX));
		  CALL SYMPUT('OPERATOR2TX'||II, LEFT(OPERATOR_2_TX));
		  CALL SYMPUT('ALLCLIENT'||II, LEFT(all_client));
		  CALL SYMPUT('MOD8MESSAGE'||II, LEFT(MESSAGE_ID_8));
		  CALL SYMPUT('MOD12MESSAGE'||II, LEFT(MESSAGE_ID_12));
		  CALL SYMPUT('MOD13MESSAGE'||II, LEFT(MESSAGE_ID_13));
		  CALL SYMPUT('INITIATIVE_ID'||II, LEFT(INITIATIVE_ID));
		  CALL SYMPUT('APN_CMCTN_ID'||II, LEFT(APN_CMCTN_ID));
		  CALL SYMPUT('DOCUMENT_LOC_CD'||II, LEFT(DOCUMENT_LOC_CD));
		  CALL SYMPUT('TMSTMP', "'"||translate(PUT(TODAY(),yymmdd10.)||"-"||left(PUT(TIME(),TIME16.6)),'.',':')||"'" );
		  IF EOF THEN CALL SYMPUT('TOTAL',II);
	RUN;

	*SASDOC -------------------------------------------------------------------------
	| Aug  2007 - B. Stropich
	| Capture macro variables for hercules support.
	+-------------------------------------------------------------------------SASDOC*;
	%put _all_;

	*SASDOC -------------------------------------------------------------------------
	| Generate data to populate the hercules schema for the scheduled initiatives
	|
	+-------------------------------------------------------------------------SASDOC*;

	%do i = 1 %to &TOTAL. ;**** start initiative loop;

	%put NOTE: -------------------------------------------------------------------------;
	%put NOTE: INITIATIVE ID: &&INITIATIVE_ID&i ;
	%put NOTE: PRORGRAM ID  : &&PROGRAM_ID&i ;
	%put NOTE: TASK ID      : &&TASK_ID&i ;
	%put NOTE: CLIENT ID    : &&CLIENT_ID&i ;
	%put NOTE: CLIENT NAME  : &&CLIENT_NM&i ;
	%put NOTE: CLIENT NAME  : &&PROGRAM_NM&i ;
	%put NOTE: -------------------------------------------------------------------------;

	/*-------------------------------------------------------------------------
	general setup
	-------------------------------------------------------------------------*/

		PROC SQL;
		  CREATE TABLE TINITIATIVE AS
		  SELECT  INITIATIVE_ID,
			  A.PROGRAM_ID, A.TASK_ID, 
			  B.TRGT_RECIPIENT_CD,
			  "&&BUS_RQSTR_NM&i" AS BUS_RQSTR_NM,
			  "&&PROGRAM_NM&i" AS TITLE_TX,
			  ' ' AS DESCRIPTION_TX,
			  0 AS EXT_DRUG_LIST_IN,
			  0 AS OVRD_CLT_SETUP_IN,
			  &HCE_ID AS HSC_USR_ID,
			  INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSC_TS FORMAT=DATETIME25.6,
			  BUS_USER_ID AS HSU_USR_ID,
			  INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSU_TS FORMAT=DATETIME25.6
		  FROM &HCE_SCHMA..JOB_4_TODAY_%UPCASE(&SYSMODE) A, 
		       &HERCULES..TPROGRAM_TASK B
		  WHERE A.PROGRAM_ID=B.PROGRAM_ID
		    AND A.TASK_ID=B.TASK_ID
		    AND A.INITIATIVE_ID = &&INITIATIVE_ID&i ;
		QUIT;

		PROC SQL;
		  CREATE TABLE TINITIATIVE_PHASE AS
		  SELECT INITIATIVE_ID,
			 &PHASE_SEQ_NB AS PHASE_SEQ_NB,
			 INPUT("&DATE."||':'||HOUR||':'||MINUTE||':00.000000', DATETIME25.6)
			 AS JOB_SCHEDULED_TS FORMAT=DATETIME25.6,
			 . AS JOB_START_TS FORMAT=DATETIME25.6,
			 .  AS JOB_COMPLETE_TS FORMAT=DATETIME25.6,
			 &HCE_ID AS HSC_USR_ID,
			 INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSC_TS FORMAT=DATETIME25.6,
			 BUS_USER_ID AS HSU_USR_ID,
		     INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSU_TS FORMAT=DATETIME25.6,
		     2 as INITIATIVE_STS_CD

		  FROM  &HCE_SCHMA..JOB_4_TODAY_%UPCASE(&SYSMODE)
		  WHERE INITIATIVE_ID = &&INITIATIVE_ID&I ;
		QUIT;

		PROC SQL;
		  CREATE TABLE TPHASE_RVR_FILE AS
		  SELECT A.INITIATIVE_ID,
			 &PHASE_SEQ_NB AS PHASE_SEQ_NB,
			 D.CMCTN_ROLE_CD,
			 0 AS REJECTED_QY,
			 0 AS ACCEPTED_QY,
			 0 AS SUSPENDED_QY,
			 0 AS LETTERS_REQ_QY,
			 0 AS LETTERS_SENT_QY,
			 C.DATA_CLEANSING_CD,
			 0 AS REJECT_EDIT_CD,
			 CASE WHEN C.PROGRAM_ID IN (&NO_AUTORELEASE_LIST.)
			   THEN 3
			   ELSE 1
			 END AS FILE_USAGE_CD,
			 C.DESTINATION_CD,
			 CASE WHEN C.PROGRAM_ID IN (&NO_AUTORELEASE_LIST.)
			   THEN 1
			   ELSE 2  /* 2 IS FINAL */
			 END AS RELEASE_STATUS_CD, /* 2 IS FINAL */
			 . AS RELEASE_TS FORMAT=DATETIME25.6,
			 D.FILE_ID,
			 &HCE_ID AS HSC_USR_ID,
			 INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSC_TS FORMAT=DATETIME25.6,
			 BUS_USER_ID  AS HSU_USR_ID,
			 INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSU_TS FORMAT=DATETIME25.6,
			 0 AS ARCHIVE_STS_CD,
			 1 AS ELIGIBILITY_CD,
	         . AS ELIGIBILITY_DT,
	         0 AS ACT_NBR_OF_DAYS

		  FROM  &HCE_SCHMA..JOB_4_TODAY_%UPCASE(&SYSMODE) A, 
			    &HERCULES..TCMCTN_PROGRAM C,
			    &HERCULES..TPGM_TASK_RVR_FILE D
		  WHERE A.INITIATIVE_ID = &&INITIATIVE_ID&I
		    AND A.PROGRAM_ID=C.PROGRAM_ID
		    AND A.PROGRAM_ID=D.PROGRAM_ID
		    AND A.TASK_ID=D.TASK_ID  ;
		QUIT;

		PROC SQL;
		  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
		  CREATE TABLE TSCREEN_STATUS AS
		      SELECT * FROM CONNECTION TO DB2
		      ( WITH VALID_DOCS AS
			  (SELECT  T.PROGRAM_ID, 
				   T.TASK_ID, 
				   T.APN_CMCTN_ID, 
				   T2.PHASE_SEQ_NB,
				   MAX(T.EFFECTIVE_DT) AS EFFECTIVE_DT,
				   MIN(T.EXPIRATION_DT) AS EXPIRATION_DT
			   FROM  &HERCULES..TDOCUMENT_VERSION A, 
				 &HERCULES..TPGM_TASK_DOM T,
				 &HERCULES..TPGM_TASK_LTR_RULE T2
			   WHERE T.PROGRAM_ID= T2.PROGRAM_ID
			     AND A.PROGRAM_ID=T.PROGRAM_ID
			     AND T.TASK_ID=T2.TASK_ID
			     AND A.APN_CMCTN_ID=T.APN_CMCTN_ID
			     AND T.CMCTN_ROLE_CD=T.CMCTN_ROLE_CD
			     AND T.LTR_RULE_SEQ_NB=T2.LTR_RULE_SEQ_NB
			   GROUP BY T.PROGRAM_ID, T.TASK_ID, T.APN_CMCTN_ID, T2.PHASE_SEQ_NB
			   HAVING MAX(T.EFFECTIVE_DT) <= CURRENT DATE
			     AND  MIN(T.EXPIRATION_DT) > CURRENT DATE ),

		       PROG_TODAY AS
		       (SELECT A.PROGRAM_ID, 
			       A.TASK_ID, 
			       A.DRG_DEFINITION_CD, 
			       B.INITIATIVE_ID, 
			       B.BUS_USER_ID
			FROM &HERCULES..TPROGRAM_TASK A, 
			     &HCE_SCHMA..JOB_4_TODAY_%UPCASE(&SYSMODE) B
			WHERE A.PROGRAM_ID=B.PROGRAM_ID
			  AND A.TASK_ID=B.TASK_ID)

		     SELECT DISTINCT
			   INITIATIVE_ID,
			   D.PHASE_SEQ_NB,
			   3 AS CLT_STS_CMPNT_CD,  /** client setup **/
			   3 AS DRG_STS_CMPNT_CD,
			   1 AS PRB_STS_CMPNT_CD,
			   3 AS PIT_STS_CMPNT_CD,
			   1 AS FRML_STS_CMPNT_CD,
			   CASE WHEN D.EXPIRATION_DT > CURRENT DATE THEN 3 
				ELSE 2 END
			   AS DOM_STS_CMPT_CD,
			   &HCE_ID AS HSC_USR_ID,
			   TIMESTAMP(&TMSTMP) AS HSC_TS,
			   BUS_USER_ID AS HSU_USR_ID,
			   TIMESTAMP(&TMSTMP) AS HSU_TS,
			   3 AS IBNFT_STS_CMPNT_CD,     /* N. Williams added 07.06.2007 */
			   3 AS EOB_STS_CMPNT_CD     /* NF EOB 12-06-2012 release */
		     FROM  PROG_TODAY A, VALID_DOCS D
		     WHERE A.INITIATIVE_ID = &&INITIATIVE_ID&I
		       AND A.PROGRAM_ID=D.PROGRAM_ID
		       AND A.TASK_ID=D.TASK_ID);
		  DISCONNECT FROM DB2;
		QUIT;

		PROC SQL;
		  CREATE TABLE TINIT_ADJUD_ENGINE AS
		  SELECT A.INITIATIVE_ID,
			 A.ADJ_ENGINE_CD,
			 &HCE_ID AS HSC_USR_ID,
			 INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSC_TS FORMAT=DATETIME25.6,
			 &HCE_ID AS HSU_USR_ID,
			 INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSU_TS FORMAT=DATETIME25.6

		  FROM &HCE_SCHMA..JOB_4_TODAY_%UPCASE(&SYSMODE) A, 
		       &HERCULES..TPROGRAM_TASK B
		  WHERE A.INITIATIVE_ID = &&INITIATIVE_ID&I
		    AND A.PROGRAM_ID = B.PROGRAM_ID
		    AND   A.TASK_ID    = B.TASK_ID 
			AND A.PROGRAM_ID NOT IN (5295, 72); 
		QUIT;
/*	AK ADDED 72 IN ABOVE STEP - 01MAY2012	*/

		PROC SQL;
		  CREATE TABLE TINIT_ADJUD_ENGINE2 AS
		  SELECT A.INITIATIVE_ID,
			 A.ADJ_ENGINE_CD,
			 &HCE_ID AS HSC_USR_ID,
			 INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSC_TS FORMAT=DATETIME25.6,
			 &HCE_ID AS HSU_USR_ID,
			 INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSU_TS FORMAT=DATETIME25.6

		  FROM JOB_4_TODAY_GSTP A
			WHERE A.TASK_FLAG >= 1;
		
		QUIT;



	/*-------------------------------------------------------------------------
	client setup
	-------------------------------------------------------------------------*/

		PROC SQL;
		  CREATE TABLE TINIT_CLT_RULE_DEF AS
		  SELECT  INITIATIVE_ID,
			  &&CLIENT_ID&i AS CLIENT_ID,
			  1 AS CLT_SETUP_DEF_CD,
			  &HCE_ID AS HSC_USR_ID,
			  INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSC_TS FORMAT=DATETIME25.6,
			  BUS_USER_ID AS HSU_USR_ID,
			  INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSU_TS FORMAT=DATETIME25.6
		  FROM &HCE_SCHMA..JOB_4_TODAY_%UPCASE(&SYSMODE) A, 
		       &HERCULES..TPROGRAM_TASK B
		  WHERE A.PROGRAM_ID=B.PROGRAM_ID
		    AND A.TASK_ID=B.TASK_ID
		    AND A.INITIATIVE_ID = &&INITIATIVE_ID&i ;
		QUIT;

		PROC SQL;
		  DROP TABLE &HCE_SCHMA..TEMP_QL;
		QUIT;
		

		%if &&DOCUMENT_LOC_CD&i = 1 %then %do; ** initiative level;
			/*-------------------------------------------------------------------------
			created a shell observation for task 31
			-------------------------------------------------------------------------*/
			PROC SQL;
			  CREATE TABLE TINIT_PHSE_RVR_DOM AS
			  SELECT *
			  FROM &HERCULES..TINIT_PHSE_RVR_DOM
			  WHERE INITIATIVE_ID = &&TASK_ID&i.;  
			QUIT;

			DATA TINIT_PHSE_RVR_DOM;
			  SET TINIT_PHSE_RVR_DOM;
			  INITIATIVE_ID = &&INITIATIVE_ID&I ;
			  APN_CMCTN_ID="&&APN_CMCTN_ID&i.";
			RUN;
			
			/*-------------------------------------------------------------------------
			created a shell observation for task 31
			-------------------------------------------------------------------------*/
			PROC SQL;
			  CREATE TABLE TINIT_QL_DOC_OVR AS
			  SELECT *
			  FROM &HERCULES..TINIT_QL_DOC_OVR
			  WHERE INITIATIVE_ID = &&TASK_ID&i.;  
			QUIT;

			DATA TINIT_QL_DOC_OVR;
			  SET TINIT_QL_DOC_OVR;
			  INITIATIVE_ID = &&INITIATIVE_ID&I ;
			  CLIENT_ID=&&CLIENT_ID&i.;
			  APN_CMCTN_ID="&&APN_CMCTN_ID&i.";
			RUN;	
		
		%end;  ** initiative level;	

		/*-------------------------------------------------------------------------
		created a shell observation for task 31
		-------------------------------------------------------------------------*/

		PROC SQL;
		  CREATE TABLE TINIT_CLIENT_RULE AS
		  SELECT *
		  FROM &HERCULES..TINIT_CLIENT_RULE
		  WHERE INITIATIVE_ID = &&TASK_ID&i.;  
		QUIT;

		DATA TINIT_CLIENT_RULE;
		 SET TINIT_CLIENT_RULE;
		 INITIATIVE_ID = &&INITIATIVE_ID&i;
		 CLIENT_ID=&&CLIENT_ID&i.;
		 DROP INIT_QL_CLT_RUL_ID;
		RUN;

		%if &&ALLCLIENT&i = 0 %then %do;

			data client_setup_info;
			  SET XTABLES.HERCULES_PROGRAM_SCHEDULES ;
			  if program_id = &&program_id&i
			   and task_id = &&task_id&i
			   and client_id = &&client_id&i ;
			   keep BLG_REPORTING_CD GROUP_CD_TX GROUP_EXT_CD_TX 
				    PLAN_CD_TX PLAN_EXT_CD_TX PLAN_NM;
			run;

			data  TINIT_CLIENT_RULE ;
			  if _n_=1 then set  TINIT_CLIENT_RULE ; 
			  set client_setup_info ;
			run;

		%end;

		PROC SQL;
		CONNECT TO DB2 (DSN=&UDBSPRP);
		EXECUTE(
		  CREATE TABLE &HCE_SCHMA..TEMP_QL AS
		  (SELECT 
			INITIATIVE_ID,
			CLIENT_ID,
			GROUP_CLASS_CD,
			GROUP_CLASS_SEQ_NB,
			BLG_REPORTING_CD,
			PLAN_CD_TX,
			PLAN_EXT_CD_TX,
			GROUP_CD_TX,
			GROUP_EXT_CD_TX,
			INCLUDE_IN,
			HSC_USR_ID,
			HSC_TS,
			HSU_USR_ID,
			HSU_TS,
			PLAN_NM 		
		   FROM &HERCULES..TINIT_CLIENT_RULE)
		   DEFINITION ONLY NOT LOGGED INITIALLY) BY DB2;
		DISCONNECT FROM DB2; 
		QUIT;

		PROC SQL;
			INSERT INTO &HCE_SCHMA..TEMP_QL
			( 
			INITIATIVE_ID,
			CLIENT_ID,
			GROUP_CLASS_CD,
			GROUP_CLASS_SEQ_NB,
			BLG_REPORTING_CD,
			PLAN_CD_TX,
			PLAN_EXT_CD_TX,
			GROUP_CD_TX,
			GROUP_EXT_CD_TX,
			INCLUDE_IN,
			HSC_USR_ID,
			HSC_TS,
			HSU_USR_ID,
			HSU_TS,
			PLAN_NM 	
			)
			SELECT  
			INITIATIVE_ID,
			CLIENT_ID,
			GROUP_CLASS_CD,
			GROUP_CLASS_SEQ_NB,
			BLG_REPORTING_CD,
			PLAN_CD_TX,
			PLAN_EXT_CD_TX,
			GROUP_CD_TX,
			GROUP_EXT_CD_TX,
			INCLUDE_IN,
			HSC_USR_ID,
			HSC_TS,
			HSU_USR_ID,
			HSU_TS,
			PLAN_NM 
			FROM  TINIT_CLIENT_RULE;
		QUIT;


	/*-------------------------------------------------------------------------
	drug setup
	-------------------------------------------------------------------------*/

		PROC SQL;
		  CREATE TABLE TINIT_DRUG_GROUP AS
		  SELECT  INITIATIVE_ID,
			  1 AS DRG_GROUP_SEQ_NB,
			  "ALL DRUGS" AS DRUG_GROUP_DSC_TX,
			  0 AS EXCLUDE_OTC_IN,
			  "AND" AS OPERATOR_TX,
			  &HCE_ID AS HSC_USR_ID,
			  INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSC_TS FORMAT=DATETIME25.6,
			  BUS_USER_ID AS HSU_USR_ID,
			  INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSU_TS FORMAT=DATETIME25.6

		  FROM  &HCE_SCHMA..JOB_4_TODAY_%UPCASE(&SYSMODE)
		  WHERE INITIATIVE_ID = &&INITIATIVE_ID&i ;
		QUIT;

		PROC SQL;
		  create table TINIT_DRUG_SUB_GRP as
		  SELECT INITIATIVE_ID,
			 1 AS DRG_GROUP_SEQ_NB,
			 1 AS DRG_SUB_GRP_SEQ_NB,
			 "All Drugs" AS DRG_SUB_GRP_DSC_TX,
			 0 AS SAVINGS_IN,
			 0 AS NUMBERATOR_IN,
			 1 AS BRD_GNRC_OPT_CD,
			 1 AS ALL_DRUG_IN,
			 &HCE_ID AS HSC_USR_ID,
			 INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSC_TS FORMAT=DATETIME25.6,
			 BUS_USER_ID AS HSU_USR_ID,
			 INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSU_TS FORMAT=DATETIME25.6

		  FROM  &HCE_SCHMA..JOB_4_TODAY_%UPCASE(&SYSMODE)
		  WHERE INITIATIVE_ID = &&INITIATIVE_ID&i ;
		QUIT;

		PROC SQL;
		  CREATE TABLE TPHASE_DRG_GRP_DT AS
		  SELECT INITIATIVE_ID,
			 1 AS DRG_GROUP_SEQ_NB,
			 1 AS PHASE_SEQ_NB,
			 today() - &&CLAIMENDDATE&i AS CLAIM_BEGIN_DT,
			 today() AS CLAIM_END_DT,
			 &HCE_ID AS HSC_USR_ID,
			 INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSC_TS FORMAT=DATETIME25.6,
			 BUS_USER_ID AS HSU_USR_ID,
			 INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSU_TS FORMAT=DATETIME25.6

		  FROM  &HCE_SCHMA..JOB_4_TODAY_%UPCASE(&SYSMODE)
		  WHERE INITIATIVE_ID = &&INITIATIVE_ID&i ;
		QUIT;



	/*-------------------------------------------------------------------------
	participant setup
	-------------------------------------------------------------------------*/
	
		/*-------------------------------------------------------------------------
		created a shell observation for task 31
		-------------------------------------------------------------------------*/

		PROC SQL;
		  CREATE TABLE TINIT_PRTCPNT_RULE AS
		  SELECT *
		  FROM &HERCULES..TINIT_PRTCPNT_RULE
		  WHERE INITIATIVE_ID = &&TASK_ID&i.;  
		QUIT;

		DATA TINIT_PRTCPNT_RULE;
		  SET TINIT_PRTCPNT_RULE;
		  INITIATIVE_ID = &&INITIATIVE_ID&I ;
		  MIN_ESM_SAVE_AT=&&MINESMSAVEAT&i.;
		  MIN_MEMBER_COST_AT=&&MINMEMBERCOSTAT&i.;
		  MAX_MEMBER_COST_AT=&&MAXMEMBERCOSTAT&i.;
		  MINIMUM_AGE_AT=&&MINIMUMAGEAT&i.;
		  OPERATOR_TX="&&OPERATORTX&i.";
		  OPERATOR_2_TX="&&OPERATOR2TX&i.";
		RUN;



	/*-------------------------------------------------------------------------
	ibenefit setup
	-------------------------------------------------------------------------*/

		/*-------------------------------------------------------------------------
		created a shell observation for task 31
		-------------------------------------------------------------------------*/
		PROC SQL;
		  CREATE TABLE TIBNFT_MODULE_STS AS
		  SELECT *
		  FROM &HERCULES..TIBNFT_MODULE_STS
		  WHERE INITIATIVE_ID = &&TASK_ID&i.; 
		QUIT;

		DATA TIBNFT_MODULE_STS;
		  SET TIBNFT_MODULE_STS;
		  INITIATIVE_ID = &&INITIATIVE_ID&I ;
		RUN;

		PROC SQL;
		  CREATE TABLE TINIT_MODULE_MSG AS
		  SELECT *
		  FROM &HERCULES..TINIT_MODULE_MSG
		  WHERE INITIATIVE_ID = &&TASK_ID&i.; 
		QUIT;

		DATA TINIT_MODULE_MSG;
		  SET TINIT_MODULE_MSG;
		  INITIATIVE_ID = &&INITIATIVE_ID&I ;
		  IF MODULE_NB=8 THEN DO;
		    MESSAGE_ID=&&MOD8MESSAGE&I ;
		  END;
		  ELSE IF MODULE_NB=12 THEN DO;
		    MESSAGE_ID=&&MOD12MESSAGE&I ;
		  END;
		  ELSE IF MODULE_NB=13 THEN DO;
		    MESSAGE_ID=&&MOD13MESSAGE&I ;
		  END;
		RUN;



		/*-------------------------------------------------------------------------
		insert data into hercules schema
		-------------------------------------------------------------------------*/
		%InsertNonBookBusIntoHercules;

	%end; **** end initiative loop;
	
	%end; **** end TOTALNONBOOKBUSINESS loop;

%mend CreateNonBookOfBusinessSchedule;



*SASDOC-------------------------------------------------------------------------
| Macro: CreateBookOfBusinessSchedule
| Insert initiatives which are Book of Business (RDAW, RTM, PR)               
+------------------------------------------------------------------------- SASDOC*;
%MACRO CreateBookOfBusinessSchedule;

	%global TOTALBOOKBUSINESS;
	
	proc sql noprint;
	  select count(*) into : TOTALBOOKBUSINESS
	  from  &HCE_SCHMA..JOB_4_TODAY_%UPCASE(&SYSMODE) 
	  where task_flag < 1 ;
	quit;	 
	
	%put NOTE:  TOTAL BOOK OF BUSINESS = &TOTALBOOKBUSINESS. ;
	
	%if &TOTALBOOKBUSINESS. > 0 %then %do;**** start TOTALBOOKBUSINESS loop;

		DATA _NULL_;
		  CALL SYMPUT('TMSTMP', "'"||translate(PUT(TODAY(),yymmdd10.)||"-"||left(PUT(TIME(),TIME16.6)),'.',':')||"'" );
		RUN;
		
		%PUT NOTE: TIMESTAMP: &TMSTMP;
		

	*SASDOC -------------------------------------------------------------------------
	| Aug  2007 - B. Stropich
	| Capture macro variables for hercules support.
	+-------------------------------------------------------------------------SASDOC*;
	%put _all_;		     
		
		
	/*-------------------------------------------------------------------------
	general setup
	-------------------------------------------------------------------------*/

		PROC SQL;
		     create table TINITIATIVE as
		     SELECT INITIATIVE_ID,
			    A.PROGRAM_ID, A.TASK_ID, B.TRGT_RECIPIENT_CD,
			    'HERCULES Administrator' AS BUS_RQSTR_NM,
			    "Scheduled Batch &SYSDATE9." as TITLE_TX,
			    ' ' as DESCRIPTION_TX,
			    0 as EXT_DRUG_LIST_IN,
			    0 as OVRD_CLT_SETUP_IN,
			    &hce_id AS HSC_USR_ID,
		      input("&SYSDATE9."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSC_TS FORMAT=DATETIME25.6,
			    BUS_USER_ID AS HSU_USR_ID,
		      input("&SYSDATE9."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSU_TS FORMAT=DATETIME25.6

		     FROM &hce_SCHMA..JOB_4_TODAY_%upcase(&sysmode) A, &HERCULES..TPROGRAM_TASK B
		       WHERE A.PROGRAM_ID=B.PROGRAM_ID
		       AND A.TASK_ID=B.TASK_ID
		       AND A.task_flag < 1
		       AND EXISTS (SELECT 1 FROM &HERCULES..TINITIATIVE C
					HAVING MIN(A.INITIATIVE_ID) >MAX(C.INITIATIVE_ID));
		     QUIT;

		PROC SQL;
		     create table TINITIATIVE_PHASE as
		     SELECT INITIATIVE_ID,
			    &phase_seq_nb AS PHASE_SEQ_nb,

			    input("&SYSDATE9."||':'||HOUR||':'||MINUTE||':00.000000', DATETIME25.6)
				 AS JOB_SCHEDULED_TS FORMAT=DATETIME25.6,
			       . AS JOB_START_TS FORMAT=DATETIME25.6,

			       .  AS JOB_COMPLETE_TS FORMAT=DATETIME25.6,
			    &hce_id AS HSC_USR_ID,
			    input("&SYSDATE9."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSC_TS FORMAT=DATETIME25.6,
			    BUS_USER_ID AS HSU_USR_ID,
                INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSU_TS FORMAT=DATETIME25.6,
                2 as INITIATIVE_STS_CD

		      FROM  &hce_SCHMA..JOB_4_TODAY_%upcase(&sysmode)
		      WHERE task_flag < 1;
		     QUIT;

		PROC SQL;
		     create table TPHASE_RVR_FILE as
		     SELECT a.INITIATIVE_ID,
			    &phase_seq_nb AS PHASE_SEQ_NB,
			    D.CMCTN_ROLE_CD,
			    0 AS REJECTED_QY,
			    0 AS ACCEPTED_QY,
			    0 AS SUSPENDED_QY,
			    0 AS LETTERS_REQ_QY,
			    0 as LETTERS_SENT_QY,
			    C.DATA_CLEANSING_CD,
			    0 AS REJECT_EDIT_CD,
			    CASE WHEN C.PROGRAM_ID IN (&no_autorelease_list.)
						  THEN 3
						  ELSE 1
					END AS FILE_USAGE_CD,
			    C.DESTINATION_CD,
			    CASE WHEN C.PROGRAM_ID IN (&no_autorelease_list.)
						  THEN 1
						  ELSE 2  /* 2 IS FINAL */
					END AS RELEASE_STATUS_CD, /* 2 IS FINAL */
			    . AS RELEASE_TS FORMAT=DATETIME25.6,
			    D.FILE_ID,
			    &hce_id AS HSC_USR_ID,
			    input("&SYSDATE9."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSC_TS FORMAT=DATETIME25.6,
			    BUS_USER_ID  AS HSU_USR_ID,
			    input("&SYSDATE9."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSU_TS FORMAT=DATETIME25.6,
			    0 AS ARCHIVE_STS_CD,
			    1 AS ELIGIBILITY_CD,
	            . AS ELIGIBILITY_DT,
	            0 AS ACT_NBR_OF_DAYS


		     FROM &hce_SCHMA..JOB_4_TODAY_%upcase(&sysmode) A, &HERCULES..TCMCTN_PROGRAM C,
			  &HERCULES..TPGM_TASK_RVR_FILE D
		       WHERE A.PROGRAM_ID=C.PROGRAM_ID
		       AND  A.PROGRAM_ID=D.PROGRAM_ID
		       AND A.TASK_ID=D.TASK_ID
		       AND A.task_flag < 1
		       AND EXISTS (SELECT 1 FROM &HERCULES..TPHASE_RVR_FILE F
					HAVING MIN(a.INITIATIVE_ID) >MAX(F.INITIATIVE_ID)) ;
		     QUIT;

		PROC SQL;
		     CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
		     CREATE TABLE TSCREEN_STATUS AS
		      SELECT * FROM CONNECTION TO DB2
		      ( WITH VALID_DOCS AS
			  (SELECT  T.PROGRAM_ID, T.TASK_ID, T.APN_CMCTN_ID, T2.PHASE_SEQ_NB,
					  MAX(T.EFFECTIVE_DT) AS EFFECTIVE_DT,
					  MIN(T.EXPIRATION_DT) AS EXPIRATION_DT
				     FROM  HERCULES.TDOCUMENT_VERSION A, &HERCULES..TPGM_TASK_DOM T,
					   &HERCULES..TPGM_TASK_LTR_RULE T2
				    WHERE T.PROGRAM_ID= T2.PROGRAM_ID
				      AND A.PROGRAM_ID=T.PROGRAM_ID
				      AND T.TASK_ID=T2.TASK_ID
				      AND A.APN_CMCTN_ID=T.APN_CMCTN_ID
				      AND T.CMCTN_ROLE_CD=T.CMCTN_ROLE_CD
				      AND T.LTR_RULE_SEQ_NB=T2.LTR_RULE_SEQ_NB
				 GROUP BY T.PROGRAM_ID, T.TASK_ID, T.APN_CMCTN_ID, T2.PHASE_SEQ_NB
				   HAVING MAX(T.EFFECTIVE_DT) <= CURRENT DATE
				      AND MIN(T.EXPIRATION_DT) > CURRENT DATE
				    ),

			   PROG_TODAY AS
			       (SELECT A.PROGRAM_ID, A.TASK_ID, A.DRG_DEFINITION_CD, B.INITIATIVE_ID, B.BUS_USER_ID
				  FROM &HERCULES..TPROGRAM_TASK A, &HCE_SCHMA..JOB_4_TODAY_%UPCASE(&SYSMODE) B
				 WHERE A.PROGRAM_ID=B.PROGRAM_ID
				   AND A.TASK_ID=B.TASK_ID
				   AND B.task_flag < 1)

			SELECT DISTINCT
			   INITIATIVE_ID,
			   D.PHASE_SEQ_NB,
			   1 AS CLT_STS_CMPNT_CD,
			   CASE WHEN A.DRG_DEFINITION_CD IN (1,2) THEN 3 ELSE 1 END
				AS DRG_STS_CMPNT_CD,
			   1 AS PRB_STS_CMPNT_CD,
			   1 AS PIT_STS_CMPNT_CD,
			   1 AS FRML_STS_CMPNT_CD,
			   CASE WHEN D.EXPIRATION_DT > CURRENT DATE THEN 3 ELSE 2 END
				AS DOM_STS_CMPT_CD,
			   &HCE_ID AS HSC_USR_ID,
			   TIMESTAMP(&TMSTMP) AS HSC_TS,
			   BUS_USER_ID AS HSU_USR_ID,
			   TIMESTAMP(&TMSTMP) AS HSU_TS,
			   1 AS IBNFT_STS_CMPNT_CD,     /* N. Williams added 07.06.2007 */
			   1 AS EOB_STS_CMPNT_CD     /* NF EOB 12-06-2012 release */
		     FROM  PROG_TODAY A, VALID_DOCS D
		     WHERE A.PROGRAM_ID=D.PROGRAM_ID
		       AND A.TASK_ID=D.TASK_ID);
		 DISCONNECT FROM DB2;
		 QUIT;

		 *-------------------------------------------------------------------------
		 | July 2007 - N. Williams - Added creation of TINIT_ADJUD_ENGINE 
		 | sas dataset. 
		 +-------------------------------------------------------------------------*;
		PROC SQL;
		  create table TINIT_ADJUD_ENGINE as
		  SELECT A.INITIATIVE_ID,
		         A.ADJ_ENGINE_CD,
			 &hce_id AS HSC_USR_ID,
			 input("&SYSDATE9."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSC_TS FORMAT=DATETIME25.6,
			 &hce_id AS HSU_USR_ID,
			 input("&SYSDATE9."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSU_TS FORMAT=DATETIME25.6

	          FROM &hce_SCHMA..JOB_4_TODAY_%upcase(&sysmode) A, 
		       &HERCULES..TPROGRAM_TASK B

		  WHERE    A.PROGRAM_ID = B.PROGRAM_ID
		       AND A.TASK_ID    = B.TASK_ID
			   AND A.PROGRAM_ID NOT IN (5295, 72)	/*AK ADDED 72 - 01MAY2012*/
		       AND A.task_flag < 1
		       AND EXISTS (SELECT 1 
		                   FROM &HERCULES..TINITIATIVE C
			 	   HAVING MIN(A.INITIATIVE_ID) >MAX(C.INITIATIVE_ID)); 
		QUIT;

		PROC SQL;
		  CREATE TABLE TINIT_ADJUD_ENGINE2 AS
		  SELECT A.INITIATIVE_ID,
			 A.ADJ_ENGINE_CD,
			 &HCE_ID AS HSC_USR_ID,
			 INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSC_TS FORMAT=DATETIME25.6,
			 &HCE_ID AS HSU_USR_ID,
			 INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSU_TS FORMAT=DATETIME25.6

		  FROM JOB_4_TODAY_GSTP A
			WHERE A.TASK_FLAG < 1;
		
		QUIT;



		
	%end; **** end TOTALBOOKBUSINESS loop;
	
	
	/*-------------------------------------------------------------------------
	insert data into hercules schema
	-------------------------------------------------------------------------*/
	%InsertBookBusIntoHercules;

	  
%mend CreateBookOfBusinessSchedule;


*SASDOC -------------------------------------------------------------------------
| Macro: InsertBookBusIntoHercules             
| Insert Book of Business initiatives into the Hercules schema 
+ -------------------------------------------------------------------------SASDOC*;
%MACRO InsertBookBusIntoHercules;

	%IF &TOTALBOOKBUSINESS = 0 %then %goto EXIT;
	%IF &ERR_FL=0 and &TOTALBOOKBUSINESS > 0  %THEN %DO;

		PROC SQL;
		  INSERT INTO &HERCULES..TINITIATIVE
		  SELECT *
		  FROM TINITIATIVE;
		QUIT;

		PROC SQL;
		  INSERT INTO &HERCULES..TINIT_ADJUD_ENGINE
		  SELECT *
		  FROM TINIT_ADJUD_ENGINE;
		QUIT;

			PROC SQL;
		  INSERT INTO &HERCULES..TINIT_ADJUD_ENGINE
		  SELECT *
		  FROM TINIT_ADJUD_ENGINE2;
		QUIT;


		PROC SQL;
		  INSERT INTO &HERCULES..TINITIATIVE_PHASE
		  SELECT *
		  FROM TINITIATIVE_PHASE;
		QUIT;

		PROC SQL;
		  INSERT INTO &HERCULES..TPHASE_RVR_FILE
		  SELECT *
		  FROM TPHASE_RVR_FILE;
		QUIT;

		PROC SQL;
		  INSERT INTO &HERCULES..TSCREEN_STATUS
		  SELECT *
		  FROM TSCREEN_STATUS;
		QUIT;

	%EXIT:;
	  %on_error(ACTION=STOP, EM_TO=&Primary_programer_email);
	%END;
	
%MEND InsertBookBusIntoHercules;


*SASDOC -------------------------------------------------------------------------
| Macro: InsertNonBookBusIntoHercules             
| Insert Non Book of Business initiatives into the Hercules schema 
+ -------------------------------------------------------------------------SASDOC*;
%MACRO InsertNonBookBusIntoHercules;

	%IF &TOTALNONBOOKBUSINESS = 0 %then %goto EXIT;
	%IF &ERR_FL=0 and &TOTALNONBOOKBUSINESS > 0  %THEN %DO;

		PROC SQL;
		  INSERT INTO &HERCULES..TINITIATIVE
		  SELECT *
		  FROM TINITIATIVE;
		QUIT;

		PROC SQL;
		 INSERT INTO &HERCULES..TINIT_CLT_RULE_DEF
		 SELECT *
		 FROM TINIT_CLT_RULE_DEF;
		QUIT;

		%if &&DOCUMENT_LOC_CD&i = 1 %then %do; ** initiative level;
			PROC SQL;
			  INSERT INTO &HERCULES..TINIT_QL_DOC_OVR
			  SELECT *
			  FROM TINIT_QL_DOC_OVR;
			QUIT;
			
			PROC SQL;
			  INSERT INTO &HERCULES..TINIT_PHSE_RVR_DOM
			  SELECT *
			  FROM TINIT_PHSE_RVR_DOM;
			QUIT;	
        %end; ** initiative level;	

		PROC SQL;
		CONNECT TO DB2 (DSN=&UDBSPRP);
		EXECUTE (
		INSERT INTO &HERCULES..TINIT_CLIENT_RULE
			   ( 
			INITIATIVE_ID,
			CLIENT_ID,
			GROUP_CLASS_CD,
			GROUP_CLASS_SEQ_NB,
			BLG_REPORTING_CD,
			PLAN_CD_TX,
			PLAN_EXT_CD_TX,
			GROUP_CD_TX,
			GROUP_EXT_CD_TX,
			INCLUDE_IN,
			HSC_USR_ID,
			HSC_TS,
			HSU_USR_ID,
			HSU_TS,
			PLAN_NM 	)
		SELECT  
			INITIATIVE_ID,
			CLIENT_ID,
			GROUP_CLASS_CD,
			GROUP_CLASS_SEQ_NB,
			BLG_REPORTING_CD,
			PLAN_CD_TX,
			PLAN_EXT_CD_TX,
			GROUP_CD_TX,
			GROUP_EXT_CD_TX,
			INCLUDE_IN,
			HSC_USR_ID,
			HSC_TS,
			HSU_USR_ID,
			HSU_TS,
			PLAN_NM 	        
		FROM &HCE_SCHMA..TEMP_QL  ) BY DB2;
		DISCONNECT FROM DB2;
		QUIT;

		PROC SQL;
		  INSERT INTO &HERCULES..TINIT_ADJUD_ENGINE
		  SELECT *
		  FROM TINIT_ADJUD_ENGINE;
		QUIT;

			PROC SQL;
		  INSERT INTO &HERCULES..TINIT_ADJUD_ENGINE
		  SELECT *
		  FROM TINIT_ADJUD_ENGINE2;
		QUIT;


		PROC SQL;
		  INSERT INTO &HERCULES..TINITIATIVE_PHASE
		  SELECT *
		  FROM TINITIATIVE_PHASE;
		QUIT;

		PROC SQL;
		  INSERT INTO &HERCULES..TPHASE_RVR_FILE
		  SELECT *
		  FROM TPHASE_RVR_FILE;
		QUIT;

		PROC SQL;
		  INSERT INTO &HERCULES..TSCREEN_STATUS
		  SELECT *
		  FROM TSCREEN_STATUS;
		QUIT;

		PROC SQL;
		  INSERT INTO &HERCULES..TINIT_DRUG_GROUP
		  SELECT *
		  FROM TINIT_DRUG_GROUP;
		QUIT;

		PROC SQL;
		  INSERT INTO &HERCULES..TINIT_DRUG_SUB_GRP
		  SELECT *
		  FROM TINIT_DRUG_SUB_GRP;
		QUIT;

		PROC SQL;
		  INSERT INTO &HERCULES..TPHASE_DRG_GRP_DT
		  SELECT *
		  FROM TPHASE_DRG_GRP_DT;
		QUIT;

		PROC SQL;
		  INSERT INTO &HERCULES..TINIT_PRTCPNT_RULE
		  SELECT *
		  FROM TINIT_PRTCPNT_RULE;
		QUIT;

		PROC SQL;
		  INSERT INTO &HERCULES..TINIT_MODULE_MSG
		  SELECT *
		  FROM TINIT_MODULE_MSG;
		QUIT;

		PROC SQL;
		  INSERT INTO &HERCULES..TIBNFT_MODULE_STS
		  SELECT *
		  FROM TIBNFT_MODULE_STS;
		QUIT;
	
	%EXIT:;
	  %on_error(ACTION=STOP, EM_TO=&Primary_programer_email);
	%END;

%MEND InsertNonBookBusIntoHercules;


*SASDOC -------------------------------------------------------------------------
| Email notice to hercules support of the scheduled initiatives for execution  
+ -------------------------------------------------------------------------SASDOC*;
%macro email_update;

	PROC SQL NOPRINT;
	  SELECT QUOTE(TRIM(EMAIL)) INTO : BUSINESS_USER_EMAIL SEPARATED BY ' '
	  FROM ADM_LKP.ANALYTICS_USERS
	  WHERE UPCASE(QCP_ID) IN ('CEE_SUPP')
	    AND INDEX(UPCASE(EMAIL),'NANCY')>0 ;
	QUIT;

	%put NOTE: HERCULES_EMAIL      = &Primary_programer_email.;
	%put NOTE: BUSINESS_USER_EMAIL = &business_user_email.;

	PROC SORT DATA = XTABLES.PROGRAM_TODAY_&day
                  OUT  = HERCULES_PROGRAM_SCHEDULES
                  NODUPKEY;
	  BY PROGRAM_ID INITIATIVE_ID;
	RUN;

	PROC SORT DATA = XTABLES.HERCULES_SCHEDULED_INITIATIVES ;
	  BY PROGRAM_ID;
	RUN;

	PROC SORT DATA = XTABLES.HERCULES_NO_AUTO_RELEASE ;
	  BY PROGRAM_ID;
	RUN;

	DATA HERCULES_PROGRAM_SCHEDULES ;
	  LENGTH EMAIL_NAME $60. ;
	  MERGE HERCULES_PROGRAM_SCHEDULES             (IN=A)
		XTABLES.HERCULES_NO_AUTO_RELEASE       (IN=B)
                XTABLES.HERCULES_SCHEDULED_INITIATIVES (IN=C);
	  BY PROGRAM_ID;
	  IF A AND C;
	  IF C AND B THEN AUTO_RELEASE='No';
	  ELSE AUTO_RELEASE='Yes';
	  EMAIL_NAME=TRIM(INITIATIVE_ID)||' - '||TRIM(PROGRAM_NM);
	RUN;
	
	
	filename mymail email 'hceprod@dalcdcp';

	%if &err_fl=0 and &JOB_COUNTS >0 %then %do;
	
	  data _null_;
	    set HERCULES_PROGRAM_SCHEDULES end=end;
	    file mymail
	    to =(&Primary_programer_email.)
/*	    cc =(&business_user_email.) */
		cc = ("Marianna.Sumoza@caremark.com")
            subject='HCE SUPPORT: Scheduled Batch Jobs' ;
	    if _n_ =1 then do;
	       put 'Hercules Support Team:' ;
         
	       put / "Good morning.  This message is to inform Hercules Support of the %cmpres(&JOB_COUNTS) scheduled batch job(s) for today.";
	       put / "Please monitor the scheduled batch job(s) and report any discrepancies or issues that may occur.";
	       put / "Below is a summary of the %cmpres(&JOB_COUNTS) scheduled batch job(s).";	      
	       put / ' ' ;
	       put / '         PROGRAM ID     INITIATIVE INFORMATION                                 AUTO RELEASE';
	       put   '         ----------     ----------------------                                 ------------';
	    end;
	       put @10 PROGRAM_ID   @25 EMAIL_NAME  @80 AUTO_RELEASE;
	    if end then do;
	       put / ' ' ;
	       put / 'Thank you,';
	       put / 'Hercules Support Team';
	    end;
	  run;
	
	%end;
	
%mend email_update;

%CreateBookOfBusinessSchedule;
%CreateNonBookOfBusinessSchedule;
%email_update;


