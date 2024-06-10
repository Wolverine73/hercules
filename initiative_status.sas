%set_sysmode(mode=prod);
%include "/herc&sysmode./prg/hercules/hercules_in.sas";

PROC SQL;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
CREATE TABLE INITIATIVES AS
SELECT * FROM CONNECTION TO DB2 (
  SELECT DISTINCT (A.INITIATIVE_ID)
        ,PROGRAM_ID
        ,TASK_ID
        ,BUS_RQSTR_NM
        ,TITLE_TX
        ,JOB_SCHEDULED_TS
        ,JOB_START_TS
        ,JOB_COMPLETE_TS
        ,INITIATIVE_STS_CD
        ,ADJ_ENGINE_CD
        ,RELEASE_TS
        ,CASE
          WHEN (RELEASE_TS IS NOT NULL) THEN 'RELEASED'
          ELSE 'NOT RELEASED'
         END AS FILE_STATUS
  FROM HERCULES.TINITIATIVE_PHASE A,
       HERCULES.TINITIATIVE B,
       HERCULES.TPHASE_RVR_FILE C,
       HERCULES.TINIT_ADJUD_ENGINE D
  WHERE A.INITIATIVE_ID=B.INITIATIVE_ID
    AND A.INITIATIVE_ID=C.INITIATIVE_ID
    AND A.INITIATIVE_ID=D.INITIATIVE_ID
/*    AND PROGRAM_ID=5259*/
/*    AND A.INITIATIVE_ID IN (&initiatives)*/
/*    AND RELEASE_TS IS NOT NULL*/
/*   WHERE JOB_START_TS IS NOT NULL*/
/*     AND JOB_SCHEDULED_TS IS NOT NULL*/
/*     AND JOB_COMPLETE_TS IS NULL*/
/*  ORDER BY JOB_SCHEDULED_TS, INITIATIVE_ID */
  ORDER BY INITIATIVE_ID 
);
DISCONNECT FROM DB2;
QUIT;

proc sort nodupkey;
  by initiative_id;
run;

proc format;
  value init_sts
  1 = 'INCOMPLETE '
  2 = 'PENDING'
  3 = 'RUNNING'
  4 = 'COMPLETE'
  5 = 'SUBMITTED'
  6 = 'FAILED'
  other = 'Error'
;
  value adj_eng
  1 = 'QL'
  2 = 'RE'
  3 = 'RX'
  OTHER='ERR'
;
run;

data INITIATIVES;
  set INITIATIVES;
  RELEASE_YR = YEAR(datepart(RELEASE_TS));
/*  IF RELEASE_YR = 2009;*/
  JOB_SCHEDULED_DT = datepart(JOB_SCHEDULED_TS);
  JOB_START_DT = datepart(JOB_START_TS);
  JOB_COMPLETE_DT = datepart(JOB_COMPLETE_TS);
  JOB_RELEASE_DT = datepart(RELEASE_TS);
  FORMAT JOB_SCHEDULED_DT JOB_START_DT JOB_COMPLETE_DT JOB_RELEASE_DT mmddyy10.;
  JOB_SCHEDULED_TM = timepart(JOB_SCHEDULED_TS);
  JOB_START_TM = timepart(JOB_START_TS);
  JOB_COMPLETE_TM = timepart(JOB_COMPLETE_TS);
  FORMAT JOB_SCHEDULED_TM JOB_START_TM JOB_COMPLETE_TM timeampm11.;
  select;
    when (JOB_START_TS^=. and JOB_COMPLETE_TS^=.) init_status=1;
    when (JOB_START_TS =. and JOB_COMPLETE_TS=. and JOB_SCHEDULED_DT=.) init_status=3;
    when (JOB_START_TS^=. and JOB_COMPLETE_TS=.) init_status=5;
    when (JOB_START_TS =. and JOB_COMPLETE_TS=. and JOB_SCHEDULED_DT^=.) init_status=4;
    otherwise init_status=5;
  end;
  format INITIATIVE_STS_CD init_sts. ADJ_ENGINE_CD ADJ_ENG.;
  /**** CALCULATE WEEK ****/
  datevar=TODAY();
  FORMAT DATEVAR MMDDYY10.;
/*  INITIATIVE_YEAR=INTNX('YEAR',JOB_START_DT,0);*/
  INITIATIVE_WEEK=INTCK('WEEK',
             INTNX('YEAR',JOB_START_DT,0),
             JOB_START_DT)+1;
  ACTUAL_WEEK=INTCK('WEEK',
             INTNX('YEAR',datevar,0),
             datevar)+1;
/*  IF JOB_SCHEDULED_DT >= TODAY()-7 OR*/
/*     JOB_COMPLETE_DT >= TODAY()-7 OR*/
/*     JOB_START_DT >= TODAY()-7 OR*/
/*     JOB_RELEASE_DT >= TODAY()-7;*/
  WEEKOF = INTNX('WEEK',datevar,-1) ;
  FORMAT WEEKOF WEEKDATE29.;
  CALL SYMPUT('WEEKOF',LEFT(TRIM(PUT(WEEKOF,WEEKDATE29.))));
/*  IF month(JOB_SCHEDULED_DT) = month(TODAY())-1;*/
  IF month(JOB_SCHEDULED_DT) in (1,2,3);
/*  IF INITIATIVE_WEEK=52;*/
/*  if '01DEC2010'd <= JOB_SCHEDULED_DT<='31DEC2010'd;*/
/*  if MONTH(JOB_START_DT)=MONTH(today())-1;*/
/*  if JOB_SCHEDULED_DT='21DEC2011'd;*/
  if YEAR(JOB_SCHEDULED_DT)=YEAR(today());
  processing_month=month(JOB_SCHEDULED_DT);
run;

proc sql;
  select processing_month, count(initiative_id) as nbr_inits
  from INITIATIVES
  group by processing_month;
quit;

DATA getweek;
  datevar=TODAY();
  INITIATIVE_YEAR=INTNX('YEAR',datevar,0);
  week=INTCK('WEEK',
             INTNX('YEAR',datevar,0),
             datevar)+1;
  FORMAT INITIATIVE_YEAR DATEVAR MMDDYY10.;
RUN;


/*data FAILED_INITIATIVES;*/
/*  set FAILED_INITIATIVES;*/
/*  JOB_SCHEDULED_DT = datepart(JOB_SCHEDULED_TS);*/
/*  JOB_START_DT = datepart(JOB_START_TS);*/
/*  JOB_COMPLETE_DT = datepart(JOB_COMPLETE_TS);*/
/*  FORMAT JOB_SCHEDULED_DT JOB_START_DT JOB_COMPLETE_DT mmddyy10.;*/
/*  JOB_SCHEDULED_TM = timepart(JOB_SCHEDULED_TS);*/
/*  JOB_START_TM = timepart(JOB_START_TS);*/
/*  JOB_COMPLETE_TM = timepart(JOB_COMPLETE_TS);*/
/*  FORMAT JOB_SCHEDULED_TM JOB_START_TM JOB_COMPLETE_TM timeampm11.;*/
/*  init_status=3;*/
/*  format init_status init_sts.;*/
/*run;*/

%PUT SYSDATE=&SYSDATE;

OPTION LS=256 ORIENTATION=LANDSCAPE nodate;
ods listing close; 
ods escapechar='^';
ods rtf file="/user1/qcpap020/&sysmode._initiative_status_&SYSDATE..rtf"; 
ods html file="/user1/qcpap020/&sysmode._initiative_status_&SYSDATE..html"; 
ods pdf file="/user1/qcpap020/&sysmode._initiative_status_&SYSDATE..pdf notc";
title1;
title2;
/*title1 'HERCULES COMMUNICATION ENGINE';*/
/*title2 'Initiative Status';*/
/*proc print data=INITIATIVES;*/
/*  var INITIATIVE_ID PROGRAM_ID TASK_ID BUS_RQSTR_NM TITLE_TX INITIATIVE_STS_CD */
/*      ADJ_ENGINE_CD;*/
/*run;*/
/*footnote1;*/
/*footnote2;*/
/*ods _all_ close; */
/*ods listing;*/
/*title1;*/
/*title2;*/

/*%macro skipit;*/
DATA _NULL_;
  SET INITIATIVES;
/*  IF INIT_STATUS=5;*/
  FILE PRINT HEADER=HEADER_LINE NOTITLES LS=256 PS=30 LINESLEFT=LL;
  IF LL<7 THEN PUT _PAGE_;
  PUT @06 INITIATIVE_ID @20 PROGRAM_ID @28 TASK_ID @36 JOB_SCHEDULED_DT @52 JOB_SCHEDULED_TM @71 JOB_START_DT @85 JOB_START_TM 
      @98 JOB_COMPLETE_DT @112 JOB_COMPLETE_TM @127 INITIATIVE_STS_CD @139 FILE_STATUS 
      @154 JOB_RELEASE_DT;
RETURN;
HEADER_LINE:
  PUT _PAGE_
       @55 '^S={font_weight=bold font_size=06}HERCULES COMMUNICATION ENGINE' /
/*       @56   '^S={font_weight=bold font_size=06}Initiative for V9 Shakeout' / */
       @56   '^S={font_weight=bold font_size=06}Initiative Status Report' / 
/*       @56   "^S={font_weight=bold font_size=06}iBenefits 2.0 and MSS (PSG)" / */
       @56   "^S={font_weight=bold font_size=06}WEEK OF &WEEKOF" / 
       @02 'INITIATIVE' @17 'PROGRAM' @27 'TASK' @33 'JOB SCHEDULED' @49 'JOB SCHEDULED' @72 'JOB START' @85 'JOB START' 
       @97 'JOB COMPLETE' @111 'JOB COMPLETE' @124 'INITIATIVE' @137 'VENDOR FILE' 
       @154 'Mail Date' /
       @06 'ID' @20 'ID' @28 'ID' @37 'DATE' @52 'TIME' @74 'DATE' @87 'TIME' 
         @102 'DATE' @115 'TIME' @126 'STATUS' @140 'STATUS'/
       @01 167*'_';
RETURN;
RUN;

/*PROC FREQ DATA=INITIATIVES;*/
/*  TABLE INITIATIVE_STS_CD*FILE_STATUS / MISSING;*/
/*RUN;*/
/*PROC FREQ DATA=INITIATIVES;*/
/*  TABLE PROGRAM_ID*INITIATIVE_STS_CD / MISSING;*/
/*RUN;*/
/*%mend skipit;*/
ods listing;
