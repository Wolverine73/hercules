
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  abpd_insert_scheduled_initiative.sas
|
| LOCATION: /PRG/sastest1/hercules/gen_utilities/sas
|
| PURPOSE:  Insert batch scheduling information into HERCULES tables based on
|           the SAS scheduling dataset-HERCULES_SCHEDULES. The program runs every
|           morning.
| 
|   LOGIC:    The program flows as follows:
|                    
|
| INPUT:    
|
| OUTPUT:   
+--------------------------------------------------------------------------------
| HISTORY: July 26, 2012 P. Landis - updated to use new hercdev2 environment
|
+------------------------------------------------------------------------HEADER*/

%MACRO abpd_insert_scheduled_initiative ;

%LET HCE_SCHMA=&USER.;

/*%set_sysmode(mode=dev2);*/
PROC SQL NOPRINT ;
 SELECT  QUOTE(TRIM(email)) INTO : Primary_programer_email SEPARATED BY ' ' 
 FROM ADM_LKP.ANALYTICS_USERS
 WHERE UPCASE(QCP_ID) IN ("&USER") ;
QUIT;

%PUT NOTE: Primary Programer Email=&Primary_programer_email;

LIBNAME xtables "/herc&sysmode/data/hercules/auxtables";

%let phase_seq_nb=1;
%let file_use=1; ** SET TO 1 FOR MAILING;
%let hce_id=%CMPRES(%str(%'&user.%'));
%let err_fl=0;
%put NOTE: HCE ID: &hce_id;

DATA _NULL_;
  DATE=PUT(TODAY(),DATE9.);
  CALL SYMPUT('DATE',DATE);
  CALL SYMPUT('THS_MON', "'"||put(month(today()),Z2.)||"'");
  CALL SYMPUT('TO_DAY' , "'"||put(day(date()),Z2.)||"'");
  CALL SYMPUT('WKDAY'  , "'"||put(weekday(date()),1.)||"'");
 RUN;
%put NOTE: Weekday: &wkday;

** SASDOC ---------------------------------------------------------------
 |  July 2007 N. Williams - Obtain non-autorelease list data from the HERCULES_NO_AUTO_RELEASE
 | /* This is for adhoc use only */
 + --------------------------------------------------------------- SASDOC*;
 PROC SQL NOPRINT;
    SELECT PROGRAM_ID INTO :no_autorelease_list SEPARATED BY ','
    FROM XTABLES.HERCULES_NO_AUTO_RELEASE	; 
 QUIT;
 %put NOTE: No Auto-release programs: &no_autorelease_list;

** SASDOC ---------------------------------------------------------------
 |  Obtain HERCULE job schedule data from the HERCULES_SCHEDULES.
 + --------------------------------------------------------------- SASDOC*;



** bss - 01.25.2007 ;

%put _all_;

** SASDOC -------------------------------------------------------------------
 |  Extract the maxium value of the initiative id from TINITIATIVE table and
 |  increment it sequentially for new initiatives.
 + ------------------------------------------------------------------- SASDOC*;





PROC SQL;
     CREATE TABLE PROGRAM_TODAY AS
     SELECT B.SHORT_TX AS PROGRAM_NM, BUS_USER_ID
       FROM JOB_4_TODAY A, CLAIMSA.TPROGRAM B
      WHERE A.PROGRAM_ID=B.PROGRAM_ID;
QUIT;

PROC SQL NOPRINT;
     SELECT PROGRAM_NM, COUNT(*) INTO :PROGRAMS SEPARATED BY ", " , :JOB_CNTS
     FROM PROGRAM_TODAY; 
QUIT;

PROC SQL NOPRINT;
     SELECT CASE WHEN MAX(A.INITIATIVE_ID) <=0 THEN '0'
                 ELSE PUT(MAX(A.INITIATIVE_ID),20.) END
       INTO: MAX_INIT_ID
     FROM &HERCULES..TINITIATIVE A;
QUIT;
** SASDOC --------------------------------------------------------------------
 |   create initiative_id, update datasets and apply error checking.
 + -------------------------------------------------------------------- SASDOC*;



%global _mis_cnt mis_init_ids;

%IF &JOB_CNTS>0 %THEN %DO;

%global INITIATIVEID;

DATA _NULL_;
     SET JOB_4_TODAY END=LAST;
     CALL SYMPUT('INITIATIVEID', left(put((&max_init_id+_n_),8.)));
     CALL SYMPUT('TMSTMP', "'"||translate(PUT(TODAY(),yymmdd10.)||"-"||left(PUT(TIME(),TIME16.6)),'.',':')||"'" );
run;

%PUT NOTE: INITIATIVEID: &INITIATIVEID. ;
%PUT NOTE: Timestamp: &TMSTMP;

%drop_db2_table(tbl_name= &HCE_SCHMA..JOB_4_TODAY_%upcase(&sysmode));

DATA &HCE_SCHMA..JOB_4_TODAY_%upcase(&sysmode);
     SET  JOB_4_TODAY;
     INITIATIVE_ID=&MAX_INIT_ID+_N_;
RUN;

TITLE "&HCE_SCHMA..JOB_4_TODAY_%upcase(&sysmode) PRINT";
PROC PRINT DATA=&HCE_SCHMA..JOB_4_TODAY_%upcase(&sysmode);
RUN;
TITLE;

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

      FROM  &hce_SCHMA..JOB_4_TODAY_%upcase(&sysmode);
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
                                  ELSE 3
                        END AS FILE_USAGE_CD,
            C.DESTINATION_CD, 	
          CASE WHEN C.PROGRAM_ID IN (&no_autorelease_list.)
                                  THEN 1
                                  ELSE 1  /* 2 IS FINAL */
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
                  FROM &HERCULES..TPROGRAM_TASK A, &hce_SCHMA..JOB_4_TODAY_%upcase(&sysmode) B
                 WHERE A.PROGRAM_ID=B.PROGRAM_ID
                   AND A.TASK_ID=B.TASK_ID)

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
		   1 AS EOB_STS_CMPNT_CD
     FROM  PROG_TODAY A, VALID_DOCS D
     WHERE A.PROGRAM_ID=D.PROGRAM_ID
       AND A.TASK_ID=D.TASK_ID);
 DISCONNECT FROM DB2;
 QUIT;

 *----------------------------------------------------------------------
 | July 2007 - N. Williams - Added creation of TINIT_ADJUD_ENGINE 
 | sas dataset. 
 +----------------------------------------------------------------------*;
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

       WHERE A.PROGRAM_ID = B.PROGRAM_ID
       AND   A.TASK_ID    = B.TASK_ID
       AND EXISTS (SELECT 1 FROM &HERCULES..TINITIATIVE C
                        HAVING MIN(A.INITIATIVE_ID) >MAX(C.INITIATIVE_ID)); 
QUIT;

DATA TINIT_ADJUD_ENGINE1;
 SET TINIT_ADJUD_ENGINE;
 ADJ_ENGINE_CD=1;
RUN;

DATA TINIT_ADJUD_ENGINE2;
 SET TINIT_ADJUD_ENGINE;
 ADJ_ENGINE_CD=2;
RUN;

DATA TINIT_ADJUD_ENGINE3;
 SET TINIT_ADJUD_ENGINE;
 ADJ_ENGINE_CD=3;
RUN;

DATA TINIT_ADJUD_ENGINE;
 SET TINIT_ADJUD_ENGINE1 TINIT_ADJUD_ENGINE2 TINIT_ADJUD_ENGINE3;
RUN;

** SASDOC ----------------------------------------------------------------------
 | Setup simple checking in case there are missing records in any of the
 | TSCREEN_STATUS related tables.
 + ---------------------------------------------------------------------- SASDOC*;

proc sql noprint;
     select &JOB_CNTS-count(*) into :_MIS_CNT
     from TSCREEN_STATUS; QUIT;

proc sql noprint;
     select description into :mis_init_ids separated by ", "
     from &hce_SCHMA..JOB_4_TODAY_%upcase(&sysmode) a
      where not exists
     (select 1 from TSCREEN_STATUS b
           where a.initiative_id=b.initiative_id); QUIT;
%END;


   %on_error(ACTION=STOP, EM_TO=&Primary_programer_email);




%put NOTE: Missing Records: &_mis_cnt &mis_init_ids;

/*%drop_db2_table(tbl_name= &HCE_SCHMA..JOB_4_TODAY_%upcase(&sysmode));*/


** SASDOC ----------------------------------------------------------------------------
 | Insert new initiative records only if there is no error during the new initiative
 | records creation.
 | July 2007 - N. Williams - Added insert to HERCULES.TINIT_ADJUD_ENGINE 
 + ---------------------------------------------------------------------------- SASDOC*;


%macro insert_rcrd;

  %IF &JOB_CNTS =0 %then %goto EXIT;
    %IF &ERR_FL=0 and &JOB_CNTS >0  %THEN %DO;
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
%mend insert_rcrd;

%INSERT_RCRD;



%MEND ABPD_INSERT_SCHEDULED_INITIATIVE ;
