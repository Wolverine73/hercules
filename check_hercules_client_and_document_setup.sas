%set_sysmode(mode=prod);
%include "/herc&sysmode./prg/hercules/hercules_in.sas";

LIBNAME CLIENT '/PRG/sastest1/hercules/gd';
FOOTNOTE1;
FOOTNOTE2;
FOOTNOTE3;
/*%let prg_id_chk= %str(AND CLT.PROGRAM_ID=72);*/
%let prg_id_chk= %str(AND CLT.PROGRAM_ID=72);
/*%let initiative_id=5606;*/

DATA _NULL_;
  TMP=TODAY();
  RPT_DT=PUT(TMP,MMDDYYD10.);
  CALL SYMPUT('RPT_DT',RPT_DT);
RUN;
TITLE4 "as of &RPT_DT";

%PUT NOTE REPORT DATE - &RPT_DT;

PROC FORMAT;
  VALUE CLT_CDE
  1 = 'ENTIRE'
  2 = 'CLT w/ EXCL'
  3 = 'PARTIAL'
  4 = 'ENTIRE CLIENT EXCLUSION'
  OTHER='ERROR';
  VALUE INC_EXC
  1 = 'DEFAULT INCLUDE'
  0 = 'DEFAULT EXCLUDE'
  OTHER = 'ERROR';
RUN;
/*CLT.PROGRAM_ID=&PROGRAM_ID*/
/*        AND */
PROC SQL;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   CREATE TABLE QL_CLIENT AS
   SELECT * FROM CONNECTION TO DB2
     (SELECT CLT.*,
             NME.CLIENT_NM,
             PGM.DFL_CLT_INC_EXU_IN,
             DOC.APN_CMCTN_ID as DEFAULT_TEMPLATE_ID,
             TSK.SHORT_TX AS MAILING
      FROM HERCULES.TPGMTASK_QL_RUL CLT,
           HERCULES.TPROGRAM_TASK PGM,
           HERCULES.TTASK TSK,
           HERCULES.TPGM_TASK_DOM DOC,
           CLAIMSA.TCLIENT1 NME
      WHERE CLT.PROGRAM_ID=PGM.PROGRAM_ID
        AND CLT.TASK_ID=PGM.TASK_ID
        AND PGM.TASK_ID=TSK.TASK_ID
        AND CLT.PROGRAM_ID = DOC.PROGRAM_ID
        AND CURRENT DATE BETWEEN CLT.EFFECTIVE_DT AND CLT.EXPIRATION_DT
        AND CLT.CLIENT_ID=NME.CLIENT_ID
        &PRG_ID_CHK
      ORDER BY MAILING, CLIENT_ID,GROUP_CLASS_CD,GROUP_CLASS_SEQ_NB,BLG_REPORTING_CD,PLAN_NM,PLAN_CD_TX,PLAN_EXT_CD_TX,
               GROUP_CD_TX,GROUP_EXT_CD_TX
     );
DISCONNECT FROM DB2;
QUIT;

PROC SQL NOPRINT;
  SELECT DISTINCT(MAILING) INTO :MAILING
  FROM QL_CLIENT;
QUIT;

PROC SQL;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   CREATE TABLE QL_CLIENT_OVR AS
   SELECT * FROM CONNECTION TO DB2
     (SELECT  OVR.CLIENT_ID
             ,OVR.GROUP_CLASS_CD
             ,OVR.GROUP_CLASS_SEQ_NB
             ,OVR.BLG_REPORTING_CD
             ,OVR.PLAN_NM
             ,OVR.PLAN_CD_TX
             ,OVR.PLAN_EXT_CD_TX
             ,OVR.GROUP_CD_TX
             ,OVR.GROUP_EXT_CD_TX
             ,OVR.APN_CMCTN_ID as OVERRIDE_TEMPLATE_ID
             ,'Standard Proactive Refill Notification' AS MAILING
      FROM HERCULES.TPGMTASK_QL_OVR OVR
      WHERE OVR.PROGRAM_ID = 72
      ORDER BY MAILING, CLIENT_ID,GROUP_CLASS_CD,GROUP_CLASS_SEQ_NB,BLG_REPORTING_CD,PLAN_NM,PLAN_CD_TX,PLAN_EXT_CD_TX,
               GROUP_CD_TX,GROUP_EXT_CD_TX
     );
DISCONNECT FROM DB2;
QUIT;

DATA QL_CLIENT_SETUP;
  MERGE QL_CLIENT QL_CLIENT_OVR;
  BY MAILING CLIENT_ID GROUP_CLASS_CD GROUP_CLASS_SEQ_NB BLG_REPORTING_CD PLAN_NM PLAN_CD_TX PLAN_EXT_CD_TX
     GROUP_CD_TX GROUP_EXT_CD_TX;
  IF OVERRIDE_TEMPLATE_ID = '' THEN OVERRIDE_TEMPLATE_ID='004';
RUN;

/*DATA CLIENT.QL_CLIENT_SETUP_CLIENT_19366;*/
/*  SET QL_CLIENT_SETUP_CLIENT_19366;*/
/*  FORMAT CLT_SETUP_DEF_CD CLT_CDE.*/
/*         DFL_CLT_INC_EXU_IN INC_EXC.;*/
/*  DROP HSC_USR_ID HSC_TS HSU_USR_ID HSU_TS;*/
/*RUN;*/

/*DATA QL_CLIENT_SETUP;*/
/*  SET QL_CLIENT_SETUP;*/
/*  FORMAT CLT_SETUP_DEF_CD CLT_CDE.*/
/*         DFL_CLT_INC_EXU_IN INC_EXC.;*/
/*  DROP PROGRAM_ID TASK_ID HSC_USR_ID HSC_TS HSU_USR_ID HSU_TS;*/
/*RUN;*/
DATA QL_CLIENT_SETUP;
  length client $50;
  SET QL_CLIENT_SETUP;
  CLIENT=TRIM(LEFT(CLIENT_NM))||'('||TRIM(LEFT(PUT(CLIENT_ID, 6.)))||')';
  FORMAT CLT_SETUP_DEF_CD CLT_CDE.
         DFL_CLT_INC_EXU_IN INC_EXC.;
  DROP client_id client_nm program_id task_id HSC_USR_ID HSC_TS HSU_USR_ID HSU_TS;
RUN;

OPTIONS ORIENTATION=LANDSCAPE LS=256 PAPERSIZE=LEGAL PAGESIZE=50 NODATE;
filename RPTFL "/herc%lowcase(&SYSMODE)/data/hercules/reports/ql_client_setup.pdf";
ODS LISTING CLOSE;
ODS pdf FILE=RPTFL;
TITLE1 "Hercules Program Maintenance";
TITLE2 'QL Client Setup';
TITLE3 "by Mailing Program";
TITLE4 "as of &RPT_DT";
PROC PRINT DATA=QL_CLIENT_SETUP SPLIT='_' ROWS=PAGE
Style(HEADER ) = {background=yellow} style (DATA)= [ background = white ] ;
  BY MAILING;
  PAGEBY MAILING;
  ID MAILING;
/*  WHERE PROGRAM_ID=72;*/
/*  VAR PGM_ID ERROR_NBR COUNT;*/
/*  SUM COUNT;*/
/*  SUMBY ERR_YR;*/
/*  FORMAT ERROR_NBR $ERR_CD. COUNT COMMA10.;*/
RUN;
ODS pdf CLOSE;
ODS LISTING;

PROC SQL;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   CREATE TABLE RX_CLIENT AS
   SELECT * FROM CONNECTION TO DB2
     (SELECT CLT.*,
             NME.CLIENT_NM,
             NME.CLIENT_ID,
             PGM.DFL_CLT_INC_EXU_IN,
             DOC.APN_CMCTN_ID as DEFAULT_TEMPLATE_ID,
             TSK.SHORT_TX AS MAILING
      FROM HERCULES.TPGMTASK_RXCLM_RUL CLT,
           HERCULES.TPROGRAM_TASK PGM,
           HERCULES.TTASK TSK,
           HERCULES.TPGM_TASK_DOM DOC,
           CLAIMSA.TCLIENT1 NME
      WHERE CLT.PROGRAM_ID=PGM.PROGRAM_ID
        AND CLT.TASK_ID=PGM.TASK_ID
        AND PGM.TASK_ID=TSK.TASK_ID
        AND CLT.PROGRAM_ID = DOC.PROGRAM_ID
        AND CLT.TASK_ID    = DOC.TASK_ID
        AND CLT.CARRIER_ID=NME.CLIENT_CD
/*        AND CURRENT DATE BETWEEN OVR.EFFECTIVE_DT AND OVR.EXPIRATION_DT*/
        &PRG_ID_CHK
      ORDER BY CLT.CARRIER_ID, CLT.ACCOUNT_ID, CLT.GROUP_CD
     );
DISCONNECT FROM DB2;
QUIT;
PROC SQL;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   CREATE TABLE RX_CLIENT_OVR AS
   SELECT * FROM CONNECTION TO DB2
    (SELECT OVR.PROGRAM_ID,
             OVR.TASK_ID,
             OVR.CARRIER_ID,
             OVR.ACCOUNT_ID,
             OVR.GROUP_CD,
             OVR.APN_CMCTN_ID as OVERRIDE_TEMPLATE_ID
      FROM HERCULES.TPGMTASK_RXCLM_OVR OVR
      WHERE OVR.PROGRAM_ID = 72
      ORDER BY OVR.CARRIER_ID, OVR.ACCOUNT_ID, OVR.GROUP_CD
     );
DISCONNECT FROM DB2;
QUIT;

PROC SQL;
  CREATE TABLE RX_CLIENT_SETUP AS
  SELECT CLT.*,
         OVR.OVERRIDE_TEMPLATE_ID
  FROM RX_CLIENT AS CLT LEFT JOIN RX_CLIENT_OVR AS OVR
    ON CLT.PROGRAM_ID = OVR.PROGRAM_ID
   AND CLT.TASK_ID=OVR.TASK_ID
   AND CLT.CARRIER_ID=OVR.CARRIER_ID
   AND CLT.ACCOUNT_ID=OVR.ACCOUNT_ID
/*   AND CLT.GROUP_CD=OVR.GROUP_CD*/
 ORDER BY CLT.CARRIER_ID, CLT.ACCOUNT_ID, CLT.GROUP_CD
/* ORDER BY CLT.MAILING*/
;
QUIT;
DATA RX_CLIENT_SETUP;
  SET RX_CLIENT_SETUP;
  IF OVERRIDE_TEMPLATE_ID = '' THEN OVERRIDE_TEMPLATE_ID='004';
RUN;
/*DATA RX_CLIENT_SETUP;*/
/*  MERGE RX_CLIENT RX_CLIENT_OVR;*/
/*  BY CARRIER_ID ACCOUNT_ID GROUP_CD;*/
/*  IF OVERRIDE_TEMPLATE_ID = '' THEN OVERRIDE_TEMPLATE_ID='4';*/
/*RUN;*/

/*        AND CURRENT DATE <= OVR.EXPIRATION_DT*/
/*        AND CLT.CARRIER_ID='X4689'*/

/*DATA RX_CLIENT_SETUP;*/
/*  SET RX_CLIENT_SETUP;*/
/*  FORMAT CLT_SETUP_DEF_CD CLT_CDE.*/
/*         DFL_CLT_INC_EXU_IN INC_EXC.;*/
/*  DROP PROGRAM_ID TASK_ID HSC_USR_ID HSC_TS HSU_USR_ID HSU_TS;*/
/*RUN;*/
DATA RX_CLIENT_SETUP;
  length client $50;
  SET RX_CLIENT_SETUP;
  CLIENT=TRIM(LEFT(CLIENT_NM))||'('||TRIM(LEFT(PUT(CLIENT_ID, 6.)))||')';
/*  IF OVERRIDE_TEMPLATE_ID = '4' THEN OVERRIDE_TEMPLATE_ID='004';*/
  FORMAT CLT_SETUP_DEF_CD CLT_CDE.
         DFL_CLT_INC_EXU_IN INC_EXC.;
  DROP client_id client_nm program_id task_id HSC_USR_ID HSC_TS HSU_USR_ID HSU_TS;
RUN;

PROC SORT DATA=RX_CLIENT_SETUP NODUPLICATES;
  BY MAILING CARRIER_ID ACCOUNT_ID GROUP_CD;
RUN;

OPTIONS ORIENTATION=LANDSCAPE LS=256 PAPERSIZE=LEGAL PAGESIZE=50;
filename RPTFL "/herc%lowcase(&SYSMODE)/data/hercules/reports/rx_client_setup.pdf";
ODS LISTING CLOSE;
ODS pdf FILE=RPTFL;
TITLE1 "Hercules Program Maintenance";
TITLE2 'RXCLAIM Client Setup';
TITLE3 "By Mailing Progam";
TITLE4 "as of &RPT_DT";
PROC PRINT DATA=RX_CLIENT_SETUP SPLIT='_' ROWS=PAGE
Style(HEADER ) = {background=yellow} style (DATA)= [ background = white ] ;
  BY MAILING;
  PAGEBY MAILING;
  ID MAILING;
/*  VAR PGM_ID ERROR_NBR COUNT;*/
/*  SUM COUNT;*/
/*  SUMBY ERR_YR;*/
/*  FORMAT ERROR_NBR $ERR_CD. COUNT COMMA10.;*/
RUN;
ODS pdf CLOSE;
ODS LISTING;

PROC SQL;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   CREATE TABLE RE_CLIENT AS
   SELECT * FROM CONNECTION TO DB2
     (SELECT CLT.*,
             NME.CLIENT_NM,
             NME.CLIENT_ID,
             PGM.DFL_CLT_INC_EXU_IN,
             DOC.APN_CMCTN_ID as DEFAULT_TEMPLATE_ID,
             TSK.SHORT_TX AS MAILING
      FROM HERCULES.TPGMTASK_RECAP_RUL CLT,
           HERCULES.TPROGRAM_TASK PGM,
           HERCULES.TTASK TSK,
           HERCULES.TPGM_TASK_DOM DOC,
           CLAIMSA.TCLIENT1 NME
      WHERE CLT.PROGRAM_ID=PGM.PROGRAM_ID
        AND CLT.TASK_ID=PGM.TASK_ID
        AND PGM.TASK_ID=TSK.TASK_ID
        AND CLT.PROGRAM_ID = DOC.PROGRAM_ID
        AND CLT.CARRIER_ID=NME.CLIENT_CD
/*        AND CURRENT DATE BETWEEN OVR.EFFECTIVE_DT AND OVR.EXPIRATION_DT*/
/*        AND CURRENT DATE <= OVR.EXPIRATION_DT*/
        &PRG_ID_CHK
      ORDER BY MAILING
     );
DISCONNECT FROM DB2;
QUIT;

PROC SQL;
  UPDATE RE_CLIENT
  SET CLIENT_NM='LAKE FOREST HOSPITAL'
  WHERE INSURANCE_CD='0XE';
QUIT;

PROC SQL;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   CREATE TABLE RE_CLIENT_OVR AS
   SELECT * FROM CONNECTION TO DB2
    (SELECT OVR.PROGRAM_ID
            ,OVR.TASK_ID 
            ,OVR.INSURANCE_CD
            ,OVR.CARRIER_ID
            ,OVR.GROUP_CD
            ,OVR.APN_CMCTN_ID as OVERRIDE_TEMPLATE_ID
      FROM HERCULES.TPGMTASK_RECAP_OVR OVR
      WHERE OVR.PROGRAM_ID=72
     );
DISCONNECT FROM DB2;
QUIT;

/*PROC DATASETS LIB=WORK;*/
/*  DELETE RE_CLIENT_SETUP;*/
/*QUIT;*/

PROC SQL;
  CREATE TABLE RE_CLIENT_SETUP AS
  SELECT CLT.*,
         OVR.OVERRIDE_TEMPLATE_ID
  FROM RE_CLIENT AS CLT LEFT JOIN RE_CLIENT_OVR AS OVR
    ON CLT.PROGRAM_ID = OVR.PROGRAM_ID
   AND CLT.TASK_ID=OVR.TASK_ID
   AND CLT.INSURANCE_CD=OVR.INSURANCE_CD
   AND CLT.CARRIER_ID=OVR.CARRIER_ID
   AND CLT.GROUP_CD=OVR.GROUP_CD
 ORDER BY CLT.MAILING
;
QUIT;

DATA RE_CLIENT_SETUP;
  SET RE_CLIENT_SETUP;
  IF OVERRIDE_TEMPLATE_ID='' THEN DO;
    OVERRIDE_TEMPLATE_ID='004';
  END;
RUN;

/*DATA RE_CLIENT_SETUP;*/
/*  SET RE_CLIENT_SETUP;*/
/*  FORMAT CLT_SETUP_DEF_CD CLT_CDE.*/
/*         DFL_CLT_INC_EXU_IN INC_EXC.;*/
/*  DROP PROGRAM_ID TASK_ID HSC_USR_ID HSC_TS HSU_USR_ID HSU_TS;*/
/*RUN;*/
DATA RE_CLIENT_SETUP;
  length client $50;
  SET RE_CLIENT_SETUP;
  CLIENT=TRIM(LEFT(CLIENT_NM))||'('||TRIM(LEFT(PUT(CLIENT_ID, 6.)))||')';
  FORMAT CLT_SETUP_DEF_CD CLT_CDE.
         DFL_CLT_INC_EXU_IN INC_EXC.;
  DROP client_id client_nm program_id task_id HSC_USR_ID HSC_TS HSU_USR_ID HSU_TS;
RUN;

PROC SORT DATA=RE_CLIENT_SETUP NODUPLICATES;
  BY INSURANCE_CD CARRIER_ID GROUP_CD;
RUN;

/* PROC SQL;*/
/*	CREATE TABLE TINIT_CLT_RULE_DEF AS*/
/*	SELECT * FROM &HERCULES..TINIT_CLT_RULE_DEF */
/*	WHERE INITIATIVE_ID = &INITIATIVE_ID;*/
/**/
/*	CREATE TABLE TINIT_RXCLM_CLT_RL AS*/
/*	SELECT * FROM &HERCULES..TINIT_RXCLM_CLT_RL*/
/*	WHERE INITIATIVE_ID = &INITIATIVE_ID;*/
/* QUIT;*/

OPTIONS ORIENTATION=LANDSCAPE LS=256 PAPERSIZE=LEGAL PAGESIZE=50;
filename RPTFL "/herc%lowcase(&SYSMODE)/data/hercules/reports/re_client_setup.pdf";
ODS LISTING CLOSE;
ODS pdf FILE=RPTFL;
TITLE1 "Hercules Program Maintenance";
TITLE2 'RECAP Client Setup';
TITLE3 "By Mailing Progam";
TITLE4 "as of &RPT_DT";
PROC PRINT DATA=RE_CLIENT_SETUP SPLIT='_' ROWS=PAGE
Style(HEADER ) = {background=yellow} style (DATA)= [ background = white ] ;
  BY MAILING;
  PAGEBY MAILING;
  ID MAILING;
/*  VAR PGM_ID ERROR_NBR COUNT;*/
/*  SUM COUNT;*/
/*  SUMBY ERR_YR;*/
/*  FORMAT ERROR_NBR $ERR_CD. COUNT COMMA10.;*/
RUN;
ODS pdf CLOSE;
ODS LISTING;

/*proc print data=HERCULES.TPGMTASK_RXCLM_OVR;*/
/*  where program_id=72;*/
/*run;*/

/*TPM0*/
/*TPM2*/
/*TPM3*/
/*TPMT*/
/*TPMB*/
/*TPMA*/
/*TPMC*/
/*TPMD*/
/*TPME*/
/*TPM4*/
/*TPM5*/
/*;*/
/*proc sql;*/
/*  create table test as*/
/*  select **/
/*  from claimsa.tclient1 a,*/
/*       HERCULES.TPGMTASK_RECAP_OVR b*/
/*  where b.CARRIER_ID=a.CLIENT_CD*/
/*    and b.program_id=72;*/
/*quit;*/
