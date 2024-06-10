%include '/home/user/qcpap020/autoexec_new.sas';
/*HEADER-----------------------------------------------------------------------
| PROGRAM:  maintain_directories.sas
|
| LOCATION: /PRG/sas%lowcase(&SYSMODE)1/hercules/gen_utilities/sas/
|
| PURPOSE:  Delete files according to the rules established in the
|           AUX_TAB.MAINTAIN_DIRECTORIES_PATTERN dataset.
|           1) A list of all the files under the directories specified in
|              the AUX_TAB.MAINTAIN_DIRECTORIES_PATTERN dataset is created.
|           2) Create a SAS dataset of file contents.
|           3) Apply exclusion and exception rules to file list.
|           4) Delete files if they are older than the maximum retain_days
|              attribute specified for the file pattern.
|           5) Create a report of the deleted files.
+----------------------------------------------------------------------HEADER*/
options mprint mlogic symbolgen;

/*SASDOC-----------------------------------------------------------------------
| Create global macro variable for system mode (SYSMODE).
+----------------------------------------------------------------------SASDOC*/
%let SYSMODE=prod;

/*SASDOC-----------------------------------------------------------------------
| Create global macro variable for delete mode (1=delete 0=no delete).
+----------------------------------------------------------------------SASDOC*/
%let DELMODE=1;

/*SASDOC-----------------------------------------------------------------------
| Create informat for converting three character month names to integers.
| Create format for displaying datetime and date vaules.
+----------------------------------------------------------------------SASDOC*/
proc format;
invalue MMM  (upcase just)
   JAN=1 FEB=2 MAR=3 APR=4 MAY=5 JUN=6 JUL=7 AUG=8 SEP=9 OCT=10 NOV=11 DEC=12;
picture dttime (default=38)
    .=' '
other='%b %0d, %0Y %0H:%0M' (datatype=datetime);
picture dt (default=12)
    .=' '
other='%b %0d, %0Y' (datatype=date);
run;

/*SASDOC-----------------------------------------------------------------------
| Create an input file of file contents and stderr files.
| Assign AUX_TAB libref as store for file exclusion patterns.
+----------------------------------------------------------------------SASDOC*/
filename DIRLST  temp;
filename DIRERR  temp;
filename DELLST  temp;
filename DELLOG  temp;
filename DELERR  temp;
libname  AUX_TAB "/herc%lowcase(&SYSMODE)/data/hercules/auxtables";

proc sql noprint;
select trim(XPATH) into :DIRLST
from   DICTIONARY.EXTFILES
where  FILEREF eq 'DIRLST';

select trim(XPATH) into :DIRERR
from   DICTIONARY.EXTFILES
where  FILEREF eq 'DIRERR';

select trim(XPATH) into :DELLST
from   DICTIONARY.EXTFILES
where  FILEREF eq 'DELLST';

select trim(XPATH) into :DELLOG
from   DICTIONARY.EXTFILES
where  FILEREF eq 'DELLOG';

select trim(XPATH) into :DELERR
from   DICTIONARY.EXTFILES
where  FILEREF eq 'DELERR';
quit;

%put DIRLST=&DIRLST;
%put DIRERR=&DIRERR;
%put DELLST=&DELLST;
%put DELLOG=&DELLOG;
%put DELERR=&DELERR;

proc sql noprint;
create table WORK.DIRLST as
select distinct DIRECTORY
from   AUX_TAB.MAINTAIN_DIRECTORIES_PATTERN;
quit;

/*SASDOC-----------------------------------------------------------------------
| Count the number of rows in WORK.DIRLST.
+----------------------------------------------------------------------SASDOC*/
proc sql noprint;
select trim(left(put(NOBS,8.)))
  into :NOBS_WORK_DIRLST
from   DICTIONARY.TABLES
where  LIBNAME eq 'WORK'
  and  MEMNAME eq 'DIRLST'
  and  MEMTYPE eq 'DATA';
quit;

%macro GET_DIRLST(NOBS_WORK_DIRLST);
%*SASDOC-----------------------------------------------------------------------
| Get list of files and attributes for each directory.
+----------------------------------------------------------------------SASDOC*;
%do NOBS=1 %to &NOBS_WORK_DIRLST;
   proc sql noprint;
   select  trim(left(DIRECTORY))
   into    :m_DIRECTORY
   from    WORK.DIRLST(firstobs=&NOBS obs=&NOBS);
   quit;
   %sysexec find %qtrim(&m_DIRECTORY) -type f -ls 2>>&DIRERR >> &DIRLST;
%end;
%mend GET_DIRLST;

%GET_DIRLST(&NOBS_WORK_DIRLST);

/*SASDOC-----------------------------------------------------------------------
| Create a SAS dataset from file contents file.
+----------------------------------------------------------------------SASDOC*/
data WORK.FILE_ATTR
   (keep=PROGRAMPATH_PROGRAMNAME PERMISSIONS OWNER GROUP FILESIZE MOD_DT LRECL);
length MMM $3 DD $2 YYYY $4;
format MOD_DT worddate12.;
infile DIRLST truncover delimiter=' ';
input  IMODE        KB_SIZE    PERMISSIONS $char10.  PROTECTN_MODE  OWNER : $8.
       GROUP : $8.  FILESIZE   MOD_DT_STR  $char12.  PROGRAMPATH_PROGRAMNAME $1024.;
MMM=substr(MOD_DT_STR,1,3);
DD =substr(MOD_DT_STR,5,2);
if index(MOD_DT_STR,':') then
do;
   if input(MMM,MMM.) le month(today()) then
      YYYY=put(year(today()),4.);
   else
      YYYY=put((year(today())-1),4.);
end;
else
   YYYY=substr(MOD_DT_STR,9,4);
MOD_DT=input(DD||MMM||YYYY,date9.);
LRECL=length(trim(left(PROGRAMPATH_PROGRAMNAME)));
run;

/*SASDOC-----------------------------------------------------------------------
| Alter length of the program path program name.
+----------------------------------------------------------------------SASDOC*/
proc sql noprint;
select trim(left(put(max(LRECL),8.)))
into   :MAX_LRECL
from   WORK.FILE_ATTR;

alter table WORK.FILE_ATTR
   modify PROGRAMPATH_PROGRAMNAME char(&MAX_LRECL)
   drop LRECL;
quit;

proc sort
   data=WORK.FILE_ATTR
   out =WORK.FILE_ATTR
   nodupkey;
by PROGRAMPATH_PROGRAMNAME MOD_DT PERMISSIONS OWNER GROUP FILESIZE;
run;

%macro LIKE_ESC(EXCL_TBL_NM=, DIRECTORY=, DIRECTORY_LN=, KEEP=, PATTERN=, RETAIN_DAYS=);
%*SASDOC-----------------------------------------------------------------------
| Macro LIKE_ESC provides SQL LIKE condition ESCAPE clause functionality.
| This is a work-around because of a SAS bug wherein the "SQL LIKE condition
| ESCAPE clause" only works with literal "LIKE" arguments, is does not
| work with other sql-expressions.
| LIKE_ESC inserts the program path - program name and KEEP column
| into the EXCL_TBL_NM table where the program path - program name match
| the LIKE PATTERN.
+----------------------------------------------------------------------SASDOC*;
proc sql noprint;
%if (%sysfunc(exist(&EXCL_TBL_NM._TEMP))) %then
%do;
   drop table &EXCL_TBL_NM._TEMP;
%end;
   create table &EXCL_TBL_NM._TEMP as
   select distinct PROGRAMPATH_PROGRAMNAME
          ,MOD_DT
          ,&KEEP        as KEEP
          ,&PATTERN     as PATTERN
          ,&RETAIN_DAYS as RETAIN_DAYS
   from   WORK.FILE_ATTR
   where  substr(PROGRAMPATH_PROGRAMNAME,1,&DIRECTORY_LN) eq "&DIRECTORY"
     and  PROGRAMPATH_PROGRAMNAME like &PATTERN escape "^";
%if not (%sysfunc(exist(&EXCL_TBL_NM))) %then
%do;
   create table &EXCL_TBL_NM like &EXCL_TBL_NM._TEMP;
%end;
   insert into &EXCL_TBL_NM
      (PROGRAMPATH_PROGRAMNAME, MOD_DT, KEEP, PATTERN, RETAIN_DAYS)
   select
       PROGRAMPATH_PROGRAMNAME, MOD_DT, KEEP, PATTERN, RETAIN_DAYS
   from  &EXCL_TBL_NM._TEMP;
quit;
%mend LIKE_ESC;

%macro DRIVER_LIKE_ESC( EXCL_TBL_NAME=
                       ,NOBS_SASDOC_EXCL_PTRN=);
%*SASDOC-----------------------------------------------------------------------
| Macro DRIVER_LIKE_ESC is a driver for the LIKE_ESC macro.
| Each row in the AUX_TAB.SASDOC_EXCLUDE_PATTERN table is matched to the
| list of program path - program names.
+----------------------------------------------------------------------SASDOC*;
%if (%sysfunc(exist(&EXCL_TBL_NAME))) %then
%do;
   proc sql noprint;
   drop table &EXCL_TBL_NAME;
   quit;
%end;
%do NOBS=1 %to &NOBS_SASDOC_EXCL_PTRN;
   proc sql noprint;
   select  trim(left(DIRECTORY))
          ,trim(left(put(length(trim(left(DIRECTORY))),8.)))
          ,trim(left(put(KEEP,8.)))
          ,"'"||trim(left(PATTERN))||"'"
          ,trim(left(put(RETAIN_DAYS,8.)))
   into    :EXCL_DIRECTORY
          ,:EXCL_DIRECTORY_LN
          ,:EXCL_KEEP
          ,:EXCL_PATTERN
          ,:EXCL_RETAIN_DAYS
   from   AUX_TAB.MAINTAIN_DIRECTORIES_PATTERN(firstobs=&NOBS obs=&NOBS);
   quit;
   %LIKE_ESC( EXCL_TBL_NM=&EXCL_TBL_NAME
             ,DIRECTORY=&EXCL_DIRECTORY, DIRECTORY_LN=&EXCL_DIRECTORY_LN
             ,KEEP=&EXCL_KEEP, PATTERN=&EXCL_PATTERN, RETAIN_DAYS=&EXCL_RETAIN_DAYS);
%end;
%mend DRIVER_LIKE_ESC;

/*SASDOC-----------------------------------------------------------------------
| Count the number of rows in the AUX_TAB.MAINTAIN_DIRECTORIES_PATTERN table.
+----------------------------------------------------------------------SASDOC*/
proc sql noprint;
  select NOBS
  into :NOBS_SASDOC_EXCLUDE_PATTERN
from   DICTIONARY.TABLES
where  LIBNAME eq 'AUX_TAB'
  and  MEMNAME eq 'MAINTAIN_DIRECTORIES_PATTERN'
  and  MEMTYPE eq 'DATA';
quit;

/*SASDOC-----------------------------------------------------------------------
| Create a table of program path - program names to exclude or
| unconditionally include program names.
+----------------------------------------------------------------------SASDOC*/
%DRIVER_LIKE_ESC( EXCL_TBL_NAME=WORK.EXCLUDE
                 ,NOBS_SASDOC_EXCL_PTRN=&NOBS_SASDOC_EXCLUDE_PATTERN);

/*SASDOC-----------------------------------------------------------------------
| Create a table of files to be deleted.
+----------------------------------------------------------------------SASDOC*/
proc sql noprint;
create table WORK.DELETE_SCHEDULE as
select  PROGRAMPATH_PROGRAMNAME
       ,MOD_DT
       ,max(A.KEEP) as MAX_KEEP
       ,max(A.RETAIN_DAYS) as MAX_RETAIN_DAYS
from    WORK.EXCLUDE A
group by PROGRAMPATH_PROGRAMNAME, MOD_DT
having  max(KEEP) eq -1
   and  intck('DAYS',MOD_DT, today()) gt MAX_RETAIN_DAYS;
quit;

/*SASDOC-----------------------------------------------------------------------
| Get attributes of files to be deleted.
+----------------------------------------------------------------------SASDOC*/
proc sql noprint;
create table WORK.DELETE_SCHEDULE as
select  A.PROGRAMPATH_PROGRAMNAME
       ,A.MAX_RETAIN_DAYS as RETAIN_DAYS
       ,B.MOD_DT
       ,B.PERMISSIONS
       ,B.OWNER
       ,B.GROUP
       ,B.FILESIZE
       , . as DELETE_TS format=datetime25.6
       ,'' as DELETE_ID format=$8. length=8
from    WORK.DELETE_SCHEDULE A left join WORK.FILE_ATTR B
on      A.PROGRAMPATH_PROGRAMNAME eq B.PROGRAMPATH_PROGRAMNAME
order by PROGRAMPATH_PROGRAMNAME;
quit;

/*SASDOC-----------------------------------------------------------------------
| Build command file.
+----------------------------------------------------------------------SASDOC*/
data _NULL_;
length ACTION $512;
set WORK.DELETE_SCHEDULE(keep=PROGRAMPATH_PROGRAMNAME RETAIN_DAYS);
if symget('DELMODE') ne '1' then
   ACTION=" -ls 2>>%qtrim(&DELERR) >> ";
else
   ACTION=' | xargs -i rm -e -f {} 2>> ';
LINE_OUT='find '||trim(left(PROGRAMPATH_PROGRAMNAME))||' -mtime +'
                ||trim(left(put(RETAIN_DAYS,8.)))||compbl(ACTION)||symget('DELLOG');
file DELLST;
put @1 LINE_OUT;
run;

/*SASDOC-----------------------------------------------------------------------
| Execute command file.
+----------------------------------------------------------------------SASDOC*/
%sysexec chmod g+x &DELLST;
%sysexec . &DELLST;

/*SASDOC-----------------------------------------------------------------------
| Update timestamp and delete ID where files were deleted.
+----------------------------------------------------------------------SASDOC*/
proc sql noprint;
update  WORK.DELETE_SCHEDULE
set     DELETE_TS = datetime()
       ,DELETE_ID = "&SYSUSERID"
where   not fileexist(PROGRAMPATH_PROGRAMNAME);
quit;

/*SASDOC-----------------------------------------------------------------------
| Modify ODS template.
+----------------------------------------------------------------------SASDOC*/
ods path sasuser.templat(read) sashelp.tmplmst(read) work.templat(update);
proc template;
define style MAIN_DIR / store=WORK.TEMPLAT;
   parent=styles.minimal;
     style TABLE /
       rules = NONE
       frame = VOID
       cellpadding = 0
       cellspacing = 0
       borderwidth = 1pt;
   end;
run;

/*SASDOC-----------------------------------------------------------------------
| Produce Maintain Directories report.
+----------------------------------------------------------------------SASDOC*/
%let RPT_DTTM=%sysfunc(translate(%sysfunc(datetime(),datetime19.),'.',':'));
filename RPT "/herc%lowcase(&SYSMODE)/data/hercules/gen_utilities/sas/maintain_directories/&RPT_DTTM..xls";

ods listing close;
ods html
   file =RPT
   style=MAIN_DIR;
title1 j=l "Maintain Directories Report Generated: &RPT_DTTM";
proc print
   data=WORK.DELETE_SCHEDULE
   noobs;
var PROGRAMPATH_PROGRAMNAME RETAIN_DAYS MOD_DT PERMISSIONS
    OWNER GROUP FILESIZE DELETE_TS DELETE_ID;
format MOD_DT dt.;
sum FILESIZE;
run;
quit;
ods html close;
ods listing;
run;
quit;

%macro VERIFY_DELETE;
%*SASDOC-----------------------------------------------------------------------
| Verify deletions.
+----------------------------------------------------------------------SASDOC*;
proc sql noprint;
select trim(left(put(count(*),8.)))
into   :NOT_DELETED
from   WORK.DELETE_SCHEDULE
where  DELETE_TS is missing;
quit;

%if ((&NOT_DELETED ne 0) and (&DELMODE eq 1)) %then
%do;
%*SASDOC-----------------------------------------------------------------------
| Set the parameters for error reporting.
+----------------------------------------------------------------------SASDOC*;
   %local PRIMARY_PROGRAMMER_EMAIL;
   libname ADM_LKP "/herc%lowcase(&SYSMODE)/data/hercules/auxtables";

   proc sql noprint;
   select quote(trim(left(email)))
   into   :PRIMARY_PROGRAMMER_EMAIL separated by ' '
   from   ADM_LKP.ANALYTICS_USERS
   where  upcase(QCP_ID) in ("&USER")
     and  index(upcase(email),'SUPPORT') > 0
     and  first_name='ADM';
   quit;

%*SASDOC-----------------------------------------------------------------------
| Produce report of undeleted files.
+----------------------------------------------------------------------SASDOC*;
   filename RPTDEL temp;
   ods listing close;
   ods html
      file =RPTDEL
      style=MAIN_DIR;
   title1 j=l "Undeleted Files Report Generated: &RPT_DTTM";

   proc print
      data=WORK.DELETE_SCHEDULE
      noobs;
   where  DELETE_TS is missing;
   var PROGRAMPATH_PROGRAMNAME RETAIN_DAYS MOD_DT PERMISSIONS
       OWNER GROUP FILESIZE DELETE_TS DELETE_ID;
   format MOD_DT dt.;
   sum FILESIZE;
   run;
   quit;
   ods html close;
   ods listing;
   run;
   quit;

   %let RPTDEL=%sysfunc(PATHNAME(RPTDEL));
   %let RPT   =%sysfunc(PATHNAME(RPT));

   filename NOTDEL email
      to=&PRIMARY_PROGRAMMER_EMAIL
      subject="HCE SUPPORT: Maintain Directories - Notification of Undeleted Files"
      type="text/plain"
      attach=( "&RPTDEL" ct='application/xls' ext='xls' );

   data _null_;
   file NOTDEL;
   put "Attached is a list of %trim(&NOT_DELETED) File(s) that were eligible for deletion, but NOT deleted.";
   put "A complete list of deleted and nondeleted files is found in the Maintain Directories Report Generated: &RPT_DTTM";
   put "located in &RPT.";
   run;
%end;
%mend VERIFY_DELETE;

%VERIFY_DELETE;

** update the timestamps on the auxtables to prevent removal;
data _null_;
  x "touch /herc%lowcase(&SYSMODE)/data/hercules/auxtables/*";
/*  x "touch /DATA/sastest1/hercules/auxtables/*";*/
run;
