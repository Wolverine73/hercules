/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  file_layouts.sas
|
| LOCATION: /PRG/sas%lowcase(&SYSMODE)1/hercules/reports
|
| PURPOSE:  Produce a summary and listing of mailing file layouts.
|           This program joins mailing files with their field layouts and
|           field descriptions. It produces a list of mailing files and
|           their associated layouts and field descriptions.
|
| LOGIC:    (1) Create a dataset by joining mailing file with field layout file
|               and field description file.
|
|           (2) Create a dataset of mailing files from dataset produced
|               in step (1).
|
|           (3) Produce a report of mailing files from dataset produced in step 2.
|
|           (4) Produce a report of file layouts by mailing file, from
|               dataset produced in step 1.
|
|           (5) Create a dataset of Program-Task Descriptions.
|
|           (6) Create a dataset of Program-Task-Receiver File IDs.
|
|           (7) Produce a report of Program-Task Descriptions.
|
|           (8) Produce a report of  Program-Task-Receiver File IDs.
|
| INPUT:    &HERCULES..TFILE
|           &HERCULES..TFILE_BASE_FIELD
|           &HERCULES..TFILE_FIELD
|           &HERCULES..TFIELD_DESCRIPTION
|
| OUTPUT:   RPRT_FL (report file)
+--------------------------------------------------------------------------------
| HISTORY:  20AUG2003 - P.Wonders - Original.
|           28AUG2003 - L.Kummen  - Report all FILE_IDs
|                                 - Add comments
|           24MAR2004 - L.Kummen  - Add Program-Task Descriptions report
|           24MAR2004 - L.Kummen  - Add Program-Task-Receiver File ID report
|           09SEP2004 - J.HOU     - modified to account iBenefit mailing that
|                                   has two mailing files.
+------------------------------------------------------------------------HEADER*/

*SASDOC----------------------------------------------------------------------
| Assign hercules libref.
+----------------------------------------------------------------------SASDOC*;
%set_sysmode(mode=prod);

%macro set_libname;
 %global block_2_web;
 %if &sysmode=prod %then %do;

     %let HERCULES=HERCULES;
     %let block_2_web=; %end;
 %else %do;
       %let HERCULES=HERCULET;
         %let block_2_web=;
        %end;
 %mend set_libname;
 %set_libname;
libname &HERCULES DB2 dsn=&UDBSPRP schema=&HERCULES defer=YES;

*SASDOC----------------------------------------------------------------------
| Include file for initiative_summary_parms.sas
+----------------------------------------------------------------------SASDOC*;
%include "/herc%lowcase(&sysmode)/prg/hercules/reports/report_in.sas";

%let T1_FMT_R=font=&REPORT_FNT h=10pt j=r;
%let F1_FMT_L=font=&REPORT_FNT h=10pt j=l;
%let T3_FMT_C=font=&REPORT_FNT h=20pt j=c;
%let T5_FMT_C=font=&REPORT_FNT h=14pt j=c;

ods path sasuser.templat(read) sashelp.tmplmst(read) work.templat(update);
proc template;
define style FILE_DESC / store=WORK.TEMPLAT;
parent=STYLES.PRINTER;
style PageNo from PageNo
   "Controls page numbers" /
   font_face   = &REPORT_FNT
   font_weight = MEDIUM;
end;
run;

*SASDOC----------------------------------------------------------------------
| Create a format to display seq_nb greater or equal to 200 as blank.
+----------------------------------------------------------------------SASDOC*;
proc format;
value SEQ_NB
 200-high='                ';
run;


*SASDOC--------------------------------------------------------------------------
| Create a dataset by joining mailing file with field layout file
| and field description file:
|
| 1.1) Find the maximum sequence number in the HERCULES.TFILE_BASE_FIELD table.
|      Sequence numbers in HERCULES.TFILE_FIELD will be incremented by this
|      constant.
|
| 1.2) Append the fields from the mailing file table (HERCULES.TFILE_FIELD)
|      to the fields from the base table (HERCULES.TFILE_BASE_FIELD).
|
| 1.3) Join the results of step 1.2 to the field description table
|      (HERCULES.TFIELD_DESCRIPTION) for field names and descriptions.
+------------------------------------------------------------------------SASDOC*;

proc sql noprint;
select max(A.SEQ_NB)
  into :_MAX_BASE_SEQ_NB
  from &HERCULES..TFILE_BASE_FIELD A
 where A.SEQ_NB ne 999;

create table _TABLE_1 as
select
   A.FILE_ID  as FILE_ID   label='FILE ID',
   A.FILE_SEQ_NB LABEL='File Seq#',
   A.SHORT_TX as FILE_USE  label='FILE USE - TASKS',
   A.LONG_TX  as FILE_DSC  label='DESCRIPTION',
   A.SEQ_NB   as SEQ_NB    label='FIELD POSITION'format=SEQ_NB.,
   B.FIELD_NM as FIELD_NM  label='FIELD NAME',
   B.SHORT_TX as FIELD_DSC label='FIELD DESCRIPTION'
from
   (select
       A.FILE_ID,
       1 AS FILE_SEQ_NB,
       A.SHORT_TX,
       A.LONG_TX,
       B.SEQ_NB,
       B.FIELD_ID
      from &HERCULES..TFILE A left join &HERCULES..TFILE_BASE_FIELD B
        on A.FILE_ID
    union corr
    select
       B.FILE_ID,
       FILE_SEQ_NB,
       A.SHORT_TX,
       A.LONG_TX,
       case when file_seq_nb=1 then sum(B.SEQ_NB,&_MAX_BASE_SEQ_NB)
           else B.SEQ_NB end as SEQ_NB,
       B.FIELD_ID
      from &HERCULES..TFILE A right join &HERCULES..TFILE_FIELD B
        on B.FILE_ID eq A.FILE_ID
    ) A,
    &HERCULES..TFIELD_DESCRIPTION B
 where A.FIELD_ID eq B.FIELD_ID
 order by file_seq_nb, FILE_ID, FILE_USE, SEQ_NB
;

*SASDOC--------------------------------------------------------------------------
| Create a dataset of distinct mailing files from _TABLE_1.
+------------------------------------------------------------------------SASDOC*;
create table _TABLE_1_SUM as
select distinct
   FILE_ID,
   FILE_SEQ_NB,
   FILE_USE,
   FILE_DSC
from _TABLE_1
order by FILE_ID ;
quit;

*SASDOC----------------------------------------------------------------------
| Set report output location for File Layouts.
+----------------------------------------------------------------------SASDOC*;
/*&block_2_web filename RPT "/REPORTS_DOC/prod1/PUB/Project_Hercules/file_descriptions.pdf";*/
&block_2_web filename RPT "/herc%lowcase(&sysmode)/report_doc/%lowcase(&sysmode)/PUB/Project_Hercules/file_descriptions.pdf";
options orientation=portrait papersize=letter nobyline nodate number pageno=1
        topmargin=0.75 bottommargin=0.50 rightmargin=0.75 leftmargin=0.75;
ods listing close;
ods pdf
   file=RPT
   style=FILE_DESC;
ods escapechar "^";
ods proclabel " ";
title1 &T1_FMT_R "%sysfunc(datetime(),dttime.)^_^_^_^_^_Page";
title2 " ";
title3 &T3_FMT_C "HERCULES COMMUNICATION ENGINE";
title4 " ";
title5 &T5_FMT_C "STANDARD FILE LAYOUTS";
footnote1 " ";

*SASDOC--------------------------------------------------------------------------
| Produce a report of distinct mailing files (_TABLE_1_SUM).
+------------------------------------------------------------------------SASDOC*;
proc report
   contents="STANDARD FILE LAYOUTS"
   data=_TABLE_1_SUM
   nowd
   style(column)=[font_face=&REPORT_FNT]
   style(header)=[font_face=&REPORT_FNT];
column FILE_ID  FILE_USE FILE_DSC;
define FILE_ID   / 'FILE ID';
define FILE_USE  / 'FILE USE - TASKS';
define FILE_DSC  / 'DESCRIPTION';
run;
quit;

*SASDOC--------------------------------------------------------------------------
| Create a macro to produce a report of file layouts by mailing file,
| from _TABLE_1.
+------------------------------------------------------------------------SASDOC*;
%macro rpt_table_1(_FILE_ID, file_seq_nb, _FILE_USE);
ods proclabel " ";
title5 &T5_FMT_C "LAYOUT FOR FILE ID &_FILE_ID.-&file_seq_nb";
title6 &T5_FMT_C "&_FILE_USE";
footnote1 &F1_FMT_L "NOTE: FIELDS WITHOUT POSITION NUMBERS ARE FOUND ON ANALYSIS/SAMPLE FILES ONLY";
proc report
   contents="&_FILE_ID.-&file_seq_nb - &_FILE_USE"
   data=_TABLE_1(where=(FILE_ID eq &_FILE_ID and file_seq_nb=&file_seq_nb))
   nowd
   style(column)=[font_face=&REPORT_FNT]
   style(header)=[font_face=&REPORT_FNT];
column SEQ_NB FIELD_NM FIELD_DSC;
define SEQ_NB    /'FIELD POSITION';
define FIELD_NM  /'FIELD NAME';
define FIELD_DSC /'FIELD DESCRIPTION';
run;
quit;
%mend rpt_table_1;

*SASDOC--------------------------------------------------------------------------
| Use call execute to process by group values for more control of table of
| contents generation.
+------------------------------------------------------------------------SASDOC*;
PROC SORT DATA=_TABLE_1 OUT=TMP;
     BY FILE_ID file_seq_nb; RUN;


data _null_;
set TMP;
by FILE_ID file_seq_nb;
if first.FILE_seq_nb then
   call execute('%rpt_table_1('||put(FILE_ID,8.)||','||put(FILE_seq_nb,2.)||','||FILE_USE||')');
run;
ods pdf close;
ods listing;


*SASDOC--------------------------------------------------------------------------
| Create a dataset of Program-Task Descriptions.
+------------------------------------------------------------------------SASDOC*;
proc sql noprint;
create table PROGRAM_TASK as
select   trim(A.LONG_TX) || ' (' || trim(left(put(A.PROGRAM_ID,4.))) || ')' as PROGRAM LABEL='PROGRAM'
        ,C.SHORT_TX as TASK LABEL='TASK'
        ,C.LONG_TX as DESCRIPTION LABEL='TASK DESCRIPTION'
from     CLAIMSA.TPROGRAM A
        ,&HERCULES..TPROGRAM_TASK B
        ,&HERCULES..TTASK C
where    A.PROGRAM_ID eq B.PROGRAM_ID
  and    B.TASK_ID    eq C.TASK_ID
order by A.LONG_TX, C.SHORT_TX;
quit;


*SASDOC--------------------------------------------------------------------------
| Create a dataset of Program-Task-Receiver File IDs.
+------------------------------------------------------------------------SASDOC*;
proc sql noprint;
create table PGM_TASK_RVR_FILE as
select  trim(A.LONG_TX) || ' (' || trim(left(put(A.PROGRAM_ID,4.))) || ')' as PROGRAM LABEL='PROGRAM'
       ,C.SHORT_TX as TASK LABEL='TASK'
       ,G.SHORT_TX as RECEIVER LABEL='RECEIVER'
       ,D.FILE_ID
from   CLAIMSA.TPROGRAM A
      ,&HERCULES..TPROGRAM_TASK B
      ,&HERCULES..TTASK C
      ,&HERCULES..TPGM_TASK_RVR_FILE D
      ,&HERCULES..TFILE E
      ,&HERCULES..TCODE_COLUMN_XREF F
      ,&HERCULES..TCMCTN_ENGINE_CD G
where  A.PROGRAM_ID         eq B.PROGRAM_ID
  and  B.TASK_ID            eq C.TASK_ID
  and  B.PROGRAM_ID         eq D.PROGRAM_ID
  and  B.TASK_ID            eq D.TASK_ID
  and  D.FILE_ID            eq E.FILE_ID
  and  F.CMCTN_ENGN_TYPE_CD eq G.CMCTN_ENGN_TYPE_CD
  and  F.COLUMN_NM          eq 'CMCTN_ROLE_CD'
  and  G.CMCTN_ENGINE_CD    eq D.CMCTN_ROLE_CD
order by A.LONG_TX, C.SHORT_TX, G.SHORT_TX;
quit;


*SASDOC----------------------------------------------------------------------
| Set report output location for Program-Task Descriptions.
+----------------------------------------------------------------------SASDOC*;
/*&block_2_web filename RPT "/REPORTS_DOC/prod1/PUB/Project_Hercules/program_task_description.pdf";*/
&block_2_web filename RPT "/herc%lowcase(&sysmode)/report_doc/%lowcase(&sysmode)/PUB/Project_Hercules/program_task_description.pdf";
options pageno=1;
ods listing close;
ods pdf
   file=RPT
   style=FILE_DESC
   NOTOC;
ods escapechar "^";
ods proclabel " ";
title5 &T5_FMT_C "Program-Task Description";
footnote1 " ";

*SASDOC--------------------------------------------------------------------------
| Produce a report of Program-Task Descriptions.
+------------------------------------------------------------------------SASDOC*;
proc report
   data=PROGRAM_TASK
   nowd
   style(column)=[font_face=&REPORT_FNT]
   style(header)=[font_face=&REPORT_FNT];
column PROGRAM TASK DESCRIPTION;
define PROGRAM      / 'PROGRAM' group;
define TASK         / 'TASK';
define DESCRIPTION  / 'TASK DESCRIPTION';
run;
quit;
ods pdf close;

*SASDOC----------------------------------------------------------------------
| Set report output location for Program-Task-Receiver File IDs.
+----------------------------------------------------------------------SASDOC*;
/*&block_2_web  filename RPT "/REPORTS_DOC/prod1/PUB/Project_Hercules/program_task_receiver_file.pdf";*/
&block_2_web  filename RPT "/herc%lowcase(&sysmode)/report_doc/%lowcase(&sysmode)/PUB/Project_Hercules/program_task_receiver_file.pdf";
options pageno=1;
ods listing close;
ods pdf
   file=RPT
   style=FILE_DESC
   NOTOC;
ods escapechar "^";
ods proclabel " ";
title5 &T5_FMT_C "Program-Task-Receiver File ID";
footnote1 " ";

*SASDOC--------------------------------------------------------------------------
| Produce a report of Program-Task-Receiver File IDs..
+------------------------------------------------------------------------SASDOC*;
proc report
   data=PGM_TASK_RVR_FILE
   nowd
   style(column)=[font_face=&REPORT_FNT]
   style(header)=[font_face=&REPORT_FNT];
column PROGRAM TASK RECEIVER FILE_ID;
define PROGRAM  / 'PROGRAM'  group;
define TASK     / 'TASK'     group;
define RECEIVER / 'RECEIVER' group;
define FILE_ID  / 'FILE ID';
run;
quit;
ods pdf close;
ods listing;
run;
quit;
