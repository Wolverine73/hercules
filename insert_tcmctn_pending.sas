/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Wednesday, May 04, 2005      TIME: 03:43:20 PM
   PROJECT: retail_daw_formulary
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\Hercules\retail_daw_formulary.seg
---------------------------------------- */
/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  insert_tcmctn_pending.sas (macro)
|
| LOCATION: /PRG/sas&sysmode.1/hercules/macros
|
| PURPOSE:  Updates TPHASE_RVR_FILE -fields rejected_qy, suspended_qy,
|           accepted_qy, hsu_usr_id, hsu_ts.  These counts do not take
|           into account the data quality code (accept all or reject all)
|
|           Inserts the distinct receivers along with the sum of
|           communications for each receiver into TCMCTN_PENDING.
|           If the &autorelease from %autorelease.sas was set to true,
|           this step is skipped.  If the &autorelease = 1, call
|           macro %release_data.
|
|                       If &autorelease=0, send an email to the user with the Initiative
|                       Summary report. If &doc_complete_in != 1, let the user know that
|                       the document id(s) are incomplete and need to be assigned before
|                       mailing release.
|
| INPUT:    &INITIATIVE_ID
|           &PHASE_SEQ_NB
|           &AUTORELEASE
|           &LETTER_TYPE_QY_CD
|
| OUTPUT:
|
+-------------------------------------------------------------------------------
| HISTORY:  21OCT2003 - S.Shariff  - Original.
|           06NOV2003 - S.Shariff  - Made Email Changes.
|           02DEC2003 - T.Kalfas   - Changed call to %release_data to use
|                                    &&CMCTN_ROLE_CD&I, and revised the email
|                                    macro stmts to remove redundant code.
|           21JAN2004 - S.Shariff  - Added CC to mail component.
|           20FEB2004 - S.Shariff  - Added Error Checking for Inserts.
|           07APR2004 - S.Shariff  - Inserts Only 1 record for Data_Cleansing_Cd 1,2
|                                    Added Initiative and Program to Error Email
|           05MAY2004 - P.Wonders  - Added Functionality for LETTER_TYPE_QY_CD=3
|           06DEC2005 - G. Dudley  - Qouted macro variables referenced during
|                                    the update of the TPHASE_RVR_FILE DB2 table
|            07MAR2008 - N.WILLIAMS   - Hercules Version  2.0.01
|                                      1. Initial code migration into Dimensions
|                                         source safe control tool. 
|                                      2. Added references new program path.
| Hercules Version  2.1.01
|           31JUL2008 - SR - Added ADDRESS1_TX, CITY_TX, STATE_CD to the 
|                            query(if &DATA_CLEANSING_CD ne 3), 
|                            in insert into TCMCTN_ENGINE table, as these
|                            columns are NOT NULLABLE
+-----------------------------------------------------------------------HEADER*/

options mprint mlogic source2 symbolgen;

%MACRO INSERT_TCMCTN_PENDING(INIT_ID=&INITIATIVE_ID, PHASE_ID=&PHASE_SEQ_NB);

%LET err_fl=0;
%LOCAL I I1;

/*  %ON_ERROR(ACTION=ABORT, EM_TO=&primary_programmer_email,*/
/*          EM_SUBJECT="HCE SUPPORT:  Notification of Abend - Insert_tcmctn_pending failed.",*/
/*          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Program &PROGRAM_ID and Initiative &INITIATIVE_ID");*/

options mprint mlogic source2 symbolgen;

  %LOCAL N_FILES _MAX_ID REJECTED_QY SUSPENDED_QY ACCEPTED_QY;

  %*SASDOC=====================================================================;
  %* Checks TPHASE_RVR_FILE for associated Communication Role Codes.
  %* Macro is run once for each Role Code.
  %*====================================================================SASDOC*;

  DATA WORK.TPHASE_RVR_FILE;
    SET &HERCULES..TPHASE_RVR_FILE(WHERE=(INITIATIVE_ID=&INITIATIVE_ID
                                          AND PHASE_SEQ_NB=&PHASE_SEQ_NB));
    KEEP CMCTN_ROLE_CD FILE_ID;
    CALL SYMPUT('CMCTN_ROLE_CD' || TRIM(LEFT(PUT(_N_,BEST.))), TRIM(LEFT(PUT(CMCTN_ROLE_CD,BEST.))));
    CALL SYMPUT('FILE_ID' || TRIM(LEFT(PUT(_N_,BEST.))), TRIM(LEFT(PUT(FILE_ID,BEST.))));
  RUN;

  PROC SQL NOPRINT;
    SELECT TRIM(LEFT(PUT(COUNT(*),8.) )) INTO : N_FILES
    FROM WORK.TPHASE_RVR_FILE;
  QUIT;

  %PUT  N_FILES=&N_FILES;
  %*SASDOC=====================================================================;
  %* Following Loop Runs through the Update/Insert for each CMCTN_ROLE_CD
  %*====================================================================SASDOC*;

  %DO  I1=1 %TO &N_FILES;
    %LET I=&I1;
    %PUT I=&I;
    %PUT CMCTN_ROLE_CD&I=&&CMCTN_ROLE_CD&I ;
    %PUT FILE_ID&I=&&FILE_ID&I;

    %IF (&LETTER_TYPE_QY_CD=1) %THEN %DO;
      PROC SQL NOPRINT;
        CREATE   TABLE WORK.PENDING AS
        SELECT   DISTINCT
                 RECIPIENT_ID,
                 DATA_QUALITY_CD,
                 COUNT(DISTINCT SUBJECT_ID) AS LETTERS
        FROM     DATA_PND.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I
        GROUP BY RECIPIENT_ID,
                 DATA_QUALITY_CD;
      QUIT;
    %END;

    %IF (&LETTER_TYPE_QY_CD=2) %THEN %DO;
      PROC SQL NOPRINT;
        CREATE TABLE WORK.PENDING AS
        SELECT DISTINCT RECIPIENT_ID,
                        DATA_QUALITY_CD,
                        1 AS LETTERS
        FROM   DATA_PND.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I;
      QUIT;
    %END;

    %IF (&LETTER_TYPE_QY_CD=3) %THEN %DO;
      PROC SQL NOPRINT;
        CREATE   TABLE WORK.PENDING AS
        SELECT   DISTINCT
                 RECIPIENT_ID,
                 DATA_QUALITY_CD,
                 COUNT(DISTINCT put(SUBJECT_ID, best12.) || put(DRUG_NDC_ID, best12.)) AS LETTERS
        FROM     DATA_PND.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I
        GROUP BY RECIPIENT_ID,
                 DATA_QUALITY_CD;
      QUIT;
    %END;


    PROC SQL NOPRINT;
      SELECT   SUM (CASE A.DATA_QUALITY_CD WHEN 3 THEN A.LETTERS ELSE 0 END) AS REJECTED_QY,
               SUM (CASE A.DATA_QUALITY_CD WHEN 2 THEN A.LETTERS ELSE 0 END) AS SUSPENDED_QY,
               SUM (CASE A.DATA_QUALITY_CD WHEN 1 THEN A.LETTERS ELSE 0 END) AS ACCEPTED_QY
      INTO     :REJECTED_QY,
               :SUSPENDED_QY,
               :ACCEPTED_QY
      FROM     WORK.PENDING A;
    QUIT;
    /*SASDOC===================================================================
     * Updates TPHASE_RVR_FILE.
     *==================================================================SASDOC*/

    PROC SQL NOPRINT;
      UPDATE &HERCULES..TPHASE_RVR_FILE
      SET    ACCEPTED_QY = &ACCEPTED_QY,
             SUSPENDED_QY = &SUSPENDED_QY,
             REJECTED_QY = &REJECTED_QY,
             HSU_USR_ID = "&USER",
             HSU_TS = DATETIME()
      WHERE  INITIATIVE_ID = &INITIATIVE_ID
        AND  PHASE_SEQ_NB  = &PHASE_SEQ_NB
        AND  CMCTN_ROLE_CD = &&CMCTN_ROLE_CD&I;
    QUIT;

        %let DATA_CLEANSING_CD =0;

        PROC SQL NOPRINT;
                SELECT  DATA_CLEANSING_CD
                INTO    :DATA_CLEANSING_CD
                FROM    &HERCULES..TPHASE_RVR_FILE
                WHERE   INITIATIVE_ID = &INITIATIVE_ID
        AND     PHASE_SEQ_NB  = &PHASE_SEQ_NB
        AND     CMCTN_ROLE_CD = &&CMCTN_ROLE_CD&I;
        QUIT;

    %*SASDOC===================================================================;
    %* IF &AUTORELEASE is not true, then an INSERT is performed into
    %* the TCMCTN_PENDING table.
    %*==================================================================SASDOC*;

    %IF &AUTORELEASE=0 %THEN %DO;

        %*SASDOC===============================================================;
        %* Select the MAX CMCTN_PENDING_ID from the table in order to generate
        %* subsequent pending IDs.
        %*==============================================================SASDOC*;
      PROC SQL;
        SELECT MAX(CMCTN_PENDING_ID)
        INTO   :_MAX_ID
        FROM   &HERCULES..TCMCTN_PENDING;
      QUIT;


      %*SASDOC=================================================================;
      %* Insertions into the table should have records with DATA_QUALITY_CD = 2
      %* come first. Hence, a NEW_ID is created to manipulate it in this manner.
      %*================================================================SASDOC*;
      DATA NEW_DATA;
        SET DATA_PND.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I;
        IF DATA_QUALITY_CD=2 THEN NEW_ID=0;
        ELSE NEW_ID = DATA_QUALITY_CD;
      RUN;

      PROC SORT DATA=NEW_DATA OUT=SORTED_DATA;
        BY NEW_ID RECIPIENT_ID;
      RUN;

      DATA NEW_DATA2;
        SET SORTED_DATA;
        BY NEW_ID RECIPIENT_ID;

        RETAIN SEQ_NB &_MAX_ID;

        IF FIRST.RECIPIENT_ID THEN SEQ_NB + 1;
        ELSE DELETE;
      RUN;

          %let accepted_qy =%trim(&Accepted_Qy);
          %let suspended_qy =%trim(&Suspended_Qy);
          %let DATA_CLEANSING_CD=%trim(&DATA_CLEANSING_CD);


        %*SASDOC===================================================================;
    %* IF &DATA_CLEANSING_CD = 1 or 2, then insert only 1 row into
        %* TCMCTN_PENDING. The CMCTN_COUNT_QTY will also differ as defined below.
        %* 07MAR2008 - N.WILLIAMS   -  Adjust bulkload
    %*==================================================================SASDOC*;

                %if &DATA_CLEANSING_CD=1 %then %do;
                        %let CMCTN_COUNT_QTY=%eval(&ACCEPTED_QY+&SUSPENDED_QY);
                        %let RVR_LAST_NM=%str("ACCEPT ALL");
                %end;
                %else %if &DATA_CLEANSING_CD=2 %then %do;
                        %let CMCTN_COUNT_QTY=&ACCEPTED_QY;
                        %let RVR_LAST_NM=%str("REJECT ALL");
                %end;

         %if (&DATA_CLEANSING_CD=3) %then
                %do;
                    PROC SQL UNDO_POLICY=REQUIRED;
                INSERT INTO &HERCULES..TCMCTN_PENDING
                  (BULKLOAD=YES BL_DATAFILE="&ADHOC_DIR/TCMCTN_PENDING.ixf" BL_LOG="&ADHOC_DIR/TCMCTN_PENDING.log" ,
                   RECIPIENT_ID,
                   INITIATIVE_ID,
                   PHASE_SEQ_NB,
                   CMCTN_PENDING_ID,
                   CMCTN_ROLE_CD,
                   DATA_QUALITY_CD,
                   CMCTN_COUNT_QY,
                   RVR_FIRST_NM,
                   RVR_LAST_NM,
                   ADDRESS1_TX,
                   ADDRESS2_TX,
                   ADDRESS3_TX,
                   CITY_TX,
                   STATE_CD,
                   ZIP_CD,
                   ZIP_SUFFIX_CD,
                   HSU_USR_ID,
                   HSU_TS,
                   HSC_USR_ID,
                   HSC_TS)
                SELECT
                       A.RECIPIENT_ID,
                       &INITIATIVE_ID AS INITIATIVE_ID,
                       &PHASE_SEQ_NB AS PHASE_SEQ_NB,
                       A.SEQ_NB,
                       &&CMCTN_ROLE_CD&I AS CMCTN_ROLE_CD,
                       A.DATA_QUALITY_CD,
                       B.LETTERS AS CMCTN_COUNT_QTY,
                       RVR_FIRST_NM,
                       RVR_LAST_NM,
                       A.ADDRESS1_TX,
                       A.ADDRESS2_TX,
                       A.ADDRESS3_TX,
                       A.CITY_TX,
                       A.STATE,
                       A.ZIP_CD,
                       A.ZIP_SUFFIX_CD,
                       "&USER" AS HSU_USR_ID,
                       DATETIME() AS HSU_TS,
                       "&USER" AS HSC_USR_ID,
                       DATETIME() AS HSC_TS
                FROM   NEW_DATA2    A,
                       WORK.PENDING B
                WHERE  A.RECIPIENT_ID = B.RECIPIENT_ID;
              QUIT;
                  %set_error_fl;

           %end;

           %if (&DATA_CLEANSING_CD ne 3) %then
                %do;
                  PROC SQL;
                INSERT INTO &HERCULES..TCMCTN_PENDING
                  (RECIPIENT_ID,
                   INITIATIVE_ID,
                   PHASE_SEQ_NB,
                   CMCTN_PENDING_ID,
                   CMCTN_ROLE_CD,
                   DATA_QUALITY_CD,
                   CMCTN_COUNT_QY,
                   RVR_FIRST_NM,
                   RVR_LAST_NM,
                           HSU_USR_ID,
                   HSU_TS,
                   HSC_USR_ID,
                   HSC_TS

					,ADDRESS1_TX, 
					CITY_TX, 
					STATE_CD 
          )
                SELECT
                       1                                        AS RECIPIENT_ID,
                       &INITIATIVE_ID           AS INITIATIVE_ID,
                       &PHASE_SEQ_NB            AS PHASE_SEQ_NB,
                       1                                        AS CMCTN_PENDING_ID,
                       &&CMCTN_ROLE_CD&I        AS CMCTN_ROLE_CD,
                       1                                        AS DATA_QUALITY_CD,
                                   MAX(&CMCTN_COUNT_QTY) AS CMCTN_COUNT_QTY,
                       "NO DATA CLEANSING"      AS RVR_FIRST_NAME,
                                   &RVR_LAST_NM                 AS RVR_LAST_NM,
                                   "&USER"                              AS HSU_USR_ID,
                       DATETIME()                       AS HSU_TS,
                       "&USER"                          AS HSC_USR_ID,
                       DATETIME()                       AS HSC_TS

						," " AS ADDRESS1_TX,
						" " AS CITY_TX, 
						" " AS STATE_CD

                FROM   PENDING;
              QUIT;
                  %set_error_fl;
           %end;

        %END; *autorelease=0;

/*        %ON_ERROR(ACTION=ABORT, EM_TO=&primary_programmer_email,*/
/*          EM_SUBJECT="HCE SUPPORT:  Notification of Abend - Insert_tcmctn_pending failed.",*/
/*          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Program &PROGRAM_ID and Initiative &INITIATIVE_ID");*/

options mprint mlogic source2 symbolgen;

  %*SASDOC===================================================================;
    %* IF &AUTORELEASE is true, then %release_data is called.
        %* CHECK the Error Flag. If there is an error, the following will not execute.
    %*==================================================================SASDOC*;
   %IF (&ERR_FL = 0) %THEN %DO;

    %IF (&AUTORELEASE=1) %THEN %DO;
      %RELEASE_DATA(INIT_ID=&INIT_ID,
                    PHASE_ID=&PHASE_ID,
                    COM_CD=&&CMCTN_ROLE_CD&I);
    %END; *autorelease=1;

  %END; *err_fl = 0;
  %PUT FILE_ID loop index I=&I.;  
 %END;  *Do loop;

  %IF (&ERR_FL = 0) %THEN %DO;
   PROC SQL NOPRINT;
    SELECT TRIM(HSU_USR_ID),
                   TRIM(HSC_USR_ID)
    INTO   :HSU_USR_ID,
                   :HSC_USR_ID
    FROM   &HERCULES..TINITIATIVE_PHASE
    WHERE  INITIATIVE_ID   = &INITIATIVE_ID
      AND  PHASE_SEQ_NB    = &PHASE_SEQ_NB;

    SELECT TRIM(EMAIL)
    INTO   :USER_EMAIL SEPARATED BY ' '
    FROM   ADM_LKP.ANALYTICS_USERS
    WHERE  UPCASE(QCP_ID) IN ("&HSU_USR_ID");

        SELECT TRIM(EMAIL)
    INTO   :USER_EMAIL_CC SEPARATED BY ' '
    FROM   ADM_LKP.ANALYTICS_USERS
    WHERE  UPCASE(QCP_ID) IN ("&HSC_USR_ID");
  QUIT;

  %if %upcase(&hsc_usr_id)^=QCPAP020 and %upcase(&hsc_usr_id)^=%upcase(&hsu_usr_id)
                  %then %let _em_cc=&USER_EMAIL_CC;
                  %else %let _em_cc=%str();


  %IF (&AUTORELEASE=0) %THEN %DO;

    %INCLUDE "/herc&sysmode/prg/hercules/reports/initiative_results_overview.sas";


%let _em_msg=Your job titled &TITLE_TX (initiative id &INITIATIVE_ID) is complete and waiting in Pending Files.;
%let _em_msg=%str(&_em_msg Attached is the Initiative Summary report.);
%if (&DOC_COMPLETE_IN ^= 1) %then
%do;
   %let _em_msg=%str(&_em_msg Your document id(s) are incomplete and need to be assigned before mailing release.);
%end;

%MACRO SKIPIT;
        %email_parms( EM_TO="&USER_EMAIL"
             ,EM_CC="&_em_cc"  
/*          %email_parms( EM_TO="greg.dudley@caremark.com"*/
/*		     ,EM_CC='greg.dudley@caremark.com'*/
             ,EM_SUBJECT=Initiative Results Overview
             ,EM_MSG=&_em_msg
             ,EM_ATTACH="/herc&sysmode/report_doc/hercules/general/&INITIATIVE_ID._initiative_results_overview.pdf"  ct="application/pdf"); /* 07MAR2008 - N.WILLIAMS */
%MEND SKIPIT;

  %END; *Autorelease;
  %END; *Error Flag;


%MEND INSERT_TCMCTN_PENDING;
