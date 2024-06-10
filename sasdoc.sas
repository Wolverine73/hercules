%include '/home/user/qcpap020/autoexec_new.sas';
/*HEADER-----------------------------------------------------------------------
| PROGRAM:  sasdoc.sas
|
| LOCATION: /PRG/sas%lowcase(&SYSMODE)1/hercules/gen_utilities/sas/
|
| PURPOSE:  Get the file contents of files with the '*.sas' or '*.SAS' mime
|           and produce web pages of file meta data and program documentation.
|           1) Create an input file of file contents and stderr file.
|           2) Create a SAS dataset of file contents.
|           3) Apply exclusion and exception rules to file list.
|
| MODIFICATIONS:
|           1) Modify style so that the <BODY> calls an onLoad function &
|              Add additional data steps to insert custom JavaScript into
|              the html file. (QCPI134, J.Chen, 6/22/04)
+----------------------------------------------------------------------HEADER*/

/*SASDOC-----------------------------------------------------------------------
| Create global macro variable for system mode (SYSMODE).
+----------------------------------------------------------------------SASDOC*/
%let SYSMODE=prod;

/*SASDOC-----------------------------------------------------------------------
| Include parameter file for sasdoc.sas
+----------------------------------------------------------------------SASDOC*/
%include "/herc&sysmode./prg/hercules/gen_utilities/sas/sasdoc_in.sas";

/*SASDOC-----------------------------------------------------------------------
| Create an input file of file contents and stderr file.
| Assign SASDOC  libref as store for file contents data and web pages.
| Assign AUX_TAB libref as store for file exclusion patterns.
+----------------------------------------------------------------------SASDOC*/
filename DIRLST  temp;
filename ERRLST  temp;
libname  SASDOC  "&SASDOC_WEB_DIR";
libname  AUX_TAB "/herc&sysmode./data/hercules/auxtables";

proc sql noprint;
select trim(XPATH) into :DIRLST
from   DICTIONARY.EXTFILES
where  FILEREF eq 'DIRLST';

select trim(XPATH) into :ERRLST
from   DICTIONARY.EXTFILES
where  FILEREF eq 'ERRLST';
quit;

%sysexec find &SASDOC_START_DIR* -type f -name "*.%lowcase(&MIME)" -o -name "*.%upcase(&MIME)" 2>&ERRLST | xargs -i ls -l {} >&DIRLST;
/*SASDOC-----------------------------------------------------------------------
| Create a SAS dataset from file contents file.
+----------------------------------------------------------------------SASDOC*/
data WORK.FILE_ATTR
   (keep=PROGRAMPATH_PROGRAMNAME PERMISSIONS OWNER GROUP FILESIZE MOD_DT DIR_LVLS LRECL);
length MMM $3 DD $2 YYYY $4;
format MOD_DT worddate12.;
infile DIRLST truncover;
input @1 PERMISSIONS $char10. @16 OWNER $8. @25 GROUP $8. @34 FILESIZE 10.
     @45 MOD_DT_STR  $char12. @58 PROGRAMPATH_PROGRAMNAME $1024.;
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
   YYYY=substr(MOD_DT_STR,8,4);
MOD_DT=input(DD||MMM||YYYY,date9.);
DIR_LVLS=0;
if index(PROGRAMPATH_PROGRAMNAME,'/') ne 0 then
   CUR_VAR=scan(PROGRAMPATH_PROGRAMNAME,1,'/');
else
   CUR_VAR='';
do while ((CUR_VAR ne '') and (index(UPCASE(CUR_VAR),".%upcase(&MIME)") eq 0));
   DIR_LVLS=DIR_LVLS+1;
   CUR_VAR=scan(PROGRAMPATH_PROGRAMNAME,DIR_LVLS,'/');
end;
DIR_LVLS=max(0,DIR_LVLS-1);
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
   modify PROGRAMPATH_PROGRAMNAME char(&MAX_LRECL);
quit;

%macro LIKE_ESC(EXCL_TBL_NM=, KEEP=, PATTERN=);
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
          ,&KEEP    as KEEP
   from   WORK.FILE_ATTR
   where  PROGRAMPATH_PROGRAMNAME like &PATTERN escape "^";
%if not (%sysfunc(exist(&EXCL_TBL_NM))) %then
%do;
   create table &EXCL_TBL_NM like &EXCL_TBL_NM._TEMP;
%end;
   insert into &EXCL_TBL_NM
      (PROGRAMPATH_PROGRAMNAME, KEEP)
   select
       PROGRAMPATH_PROGRAMNAME, KEEP
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
   select  trim(left(put(KEEP,8.)))
          ,"'"||trim(left(PATTERN))||"'"
   into    :EXCL_KEEP
          ,:EXCL_PATTERN
   from   AUX_TAB.SASDOC_EXCLUDE_PATTERN(firstobs=&NOBS obs=&NOBS);
   quit;
   %LIKE_ESC( EXCL_TBL_NM=&EXCL_TBL_NAME
             ,KEEP=&EXCL_KEEP, PATTERN=&EXCL_PATTERN);
%end;
%mend DRIVER_LIKE_ESC;
/*SASDOC-----------------------------------------------------------------------
| Count the number of rows in the AUX_TAB.SASDOC_EXCLUDE_PATTERN table.
+----------------------------------------------------------------------SASDOC*/
proc sql noprint;
select NOBS
  into :NOBS_SASDOC_EXCLUDE_PATTERN
from   DICTIONARY.TABLES
where  LIBNAME eq 'AUX_TAB'
  and  MEMNAME eq 'SASDOC_EXCLUDE_PATTERN'
  and  MEMTYPE eq 'DATA';
quit;

/*SASDOC-----------------------------------------------------------------------
| Create a table of program path - program names to exclude or
| unconditionally include program names.
+----------------------------------------------------------------------SASDOC*/
%DRIVER_LIKE_ESC( EXCL_TBL_NAME=WORK.EXCLUDE
                 ,NOBS_SASDOC_EXCL_PTRN=&NOBS_SASDOC_EXCLUDE_PATTERN);

/*SASDOC-----------------------------------------------------------------------
| Create a table of programs to be exluded.
+----------------------------------------------------------------------SASDOC*/
proc sql noprint;
create table WORK.EXCLUDE_PROGRAM as
select distinct PROGRAMPATH_PROGRAMNAME
from
(
select PROGRAMPATH_PROGRAMNAME
from   WORK.EXCLUDE
where  KEEP=-1
except
select PROGRAMPATH_PROGRAMNAME
from   WORK.EXCLUDE
where  KEEP=1
)
order by PROGRAMPATH_PROGRAMNAME;
quit;


/*SASDOC-----------------------------------------------------------------------
| Apply exclusion rules to file contents dataset.
+----------------------------------------------------------------------SASDOC*/
proc sql noprint;
create table WORK.FILE_ATTR as
select *
from   WORK.FILE_ATTR
where  PROGRAMPATH_PROGRAMNAME not in (select PROGRAMPATH_PROGRAMNAME
                                       from   WORK.EXCLUDE_PROGRAM)
order by PROGRAMPATH_PROGRAMNAME;

drop table  WORK.EXCLUDE
           ,WORK.EXCLUDE_PROGRAM
           ,WORK.EXCLUDE_TEMP;

/*SASDOC-----------------------------------------------------------------------
| Create global macro variables for:
|    Maximum number of directory levels                (MAX_DIR_LVLS)
|    Maximum size of program path program name column  (MAX_LRECL)
+----------------------------------------------------------------------SASDOC*/
select trim(left(put(max(DIR_LVLS),8.))),trim(left(put(max(LRECL),8.)))
into   :MAX_DIR_LVLS, :MAX_LRECL
from   WORK.FILE_ATTR;

/*SASDOC-----------------------------------------------------------------------
| Modify size of program path program name column.
+----------------------------------------------------------------------SASDOC*/
alter table WORK.FILE_ATTR
   modify PROGRAMPATH_PROGRAMNAME char(&MAX_LRECL);

quit;

/*SASDOC-----------------------------------------------------------------------
| Add columns for directory levels and program name to file contents dataset.
+----------------------------------------------------------------------SASDOC*/
data SASDOC.FILE_ATTR
   (keep=PROGRAMPATH_PROGRAMNAME PERMISSIONS OWNER GROUP FILESIZE MOD_DT DIR_LVLS LRECL
         DIR_LVL1-DIR_LVL&MAX_DIR_LVLS PROGRAM_PATH PROGRAM_NAME FILE_ATTR_TS ACTIVE_FL);
attrib PROGRAM_PATH length=$1024 FILE_ATTR_TS format=datetime19.;
retain MAX_DIR_LVL_SZ1-MAX_DIR_LVL_SZ&MAX_DIR_LVLS
       MAX_PROGRAM_PATH_SZ MAX_PROGRAM_NAME_SZ 0 ACTIVE_FL 1;
array MAX_DIR_LVL_SZ(&MAX_DIR_LVLS) 8 MAX_DIR_LVL_SZ1-MAX_DIR_LVL_SZ&MAX_DIR_LVLS;
array DIR_LVL(&MAX_DIR_LVLS) $ 80 DIR_LVL1-DIR_LVL&MAX_DIR_LVLS;
set WORK.FILE_ATTR end=EOF_FILE_ATTR;
by PROGRAMPATH_PROGRAMNAME;
do I=1 to DIR_LVLS;
   DIR_LVL(I)=scan(PROGRAMPATH_PROGRAMNAME,I,'/');
   MAX_DIR_LVL_SZ(I)=max(MAX_DIR_LVL_SZ(I),length(trim(left(DIR_LVL(I)))));
end;
PROGRAM_NAME=scan(PROGRAMPATH_PROGRAMNAME,DIR_LVLS+1,'/');
PROGRAM_PATH=reverse(substr(reverse(PROGRAMPATH_PROGRAMNAME),
                            indexc(reverse(PROGRAMPATH_PROGRAMNAME),'/')+1));
MAX_PROGRAM_NAME_SZ=max(MAX_PROGRAM_NAME_SZ,length(trim(left(PROGRAM_NAME))));
MAX_PROGRAM_PATH_SZ=max(MAX_PROGRAM_PATH_SZ,length(trim(left(PROGRAM_PATH))));
FILE_ATTR_TS=datetime();
/*SASDOC-----------------------------------------------------------------------
| Create global macro variables for:
|    Maximum size of directory levels (MAX_DIR_LVL_SZ(directory level))
|    Program name (MAX_PROGRAM_NAME_SZ).
|    Program path (MAX_PROGRAM_PATH_SZ).
+----------------------------------------------------------------------SASDOC*/
if EOF_FILE_ATTR then
do;
   do I=1 to &MAX_DIR_LVLS;
      call symput(vname(MAX_DIR_LVL_SZ(I)),trim(left(put(MAX_DIR_LVL_SZ(I),4.))));
   end;
   call symput(vname(MAX_PROGRAM_NAME_SZ),trim(left(put(MAX_PROGRAM_NAME_SZ,4.))));
   call symput(vname(MAX_PROGRAM_PATH_SZ),trim(left(put(MAX_PROGRAM_PATH_SZ,4.))));
end;
run;

%macro MOD_FILE_ATTR(TBL_NAME_IN);
%*SASDOC-----------------------------------------------------------------------
| Modify size of directory levels and program name columns of file contents
| data set.
| Drop WORK version of file contents dataset.
+----------------------------------------------------------------------SASDOC*;
proc sql noprint;
%do I=1 %to (&MAX_DIR_LVLS);
alter table &TBL_NAME_IN
   modify DIR_LVL&I char(&&MAX_DIR_LVL_SZ&I);
%end;
alter table &TBL_NAME_IN
   modify PROGRAM_NAME char(&&MAX_PROGRAM_NAME_SZ);
alter table &TBL_NAME_IN
   modify PROGRAM_PATH char(&&MAX_PROGRAM_PATH_SZ);
drop table WORK.%scan(&TBL_NAME_IN,2,.);
quit;
%mend MOD_FILE_ATTR;
%MOD_FILE_ATTR(SASDOC.FILE_ATTR);

%macro GET_COMMENTS(IN_FILE_NAME=);
%*SASDOC-----------------------------------------------------------------------
| Parse SASDOC comments from each file.
+----------------------------------------------------------------------SASDOC*;
filename DATAFILE "&IN_FILE_NAME";
%if (%sysfunc(exist(WORK.COMMENTS))) %then
%do;
   proc sql noprint;
   drop table WORK.COMMENTS;
   quit;
%end;
data WORK.COMMENTS
   (keep=PROGRAMPATH_PROGRAMNAME COMMENT_TYPE COMMENT_TYPE_NB
         LINE_NB COMMENT);
retain PROGRAMPATH_PROGRAMNAME "&IN_FILE_NAME" COMMENT_TYPE .
       COMMENT_TYPE_1_NB COMMENT_TYPE_2_NB LINE_NB 0;
infile DATAFILE end=EOF_DATAFILE truncover;
input;
RX_HEADER_SASDOC=rxparse("'*HEADER'|'HEADER*'|'*SASDOC'|'SASDOC*'");
if (rxmatch(RX_HEADER_SASDOC,upcase(_INFILE_)) ne 0) then
do;
   RX_HEADER_ST=rxparse("'*HEADER'");
   RX_HEADER_EN=rxparse("'HEADER*'");
   RX_SASDOC_ST=rxparse("'*SASDOC'");
   RX_SASDOC_EN=rxparse("'SASDOC*'");
   if (rxmatch(RX_HEADER_ST,upcase(_INFILE_)) ne 0) then
   do;
      COMMENT_TYPE=1;
      LINE_NB=0;
      COMMENT_TYPE_1_NB=COMMENT_TYPE_1_NB+1;
   end;
   else
      if (rxmatch(RX_HEADER_EN,upcase(_INFILE_)) ne 0) then
         COMMENT_TYPE=.;
      else
         if (rxmatch(RX_SASDOC_ST,upcase(_INFILE_)) ne 0) then
         do;
            COMMENT_TYPE=2;
            LINE_NB=0;
            COMMENT_TYPE_2_NB=COMMENT_TYPE_2_NB+1;
         end;
         else
            if (rxmatch(RX_SASDOC_EN,upcase(_INFILE_)) ne 0) then
               COMMENT_TYPE=.;
end;
if (COMMENT_TYPE ne .) and (rxmatch(RX_HEADER_SASDOC,upcase(_INFILE_)) eq 0) then
do;
   COMMENT=_INFILE_;
   LINE_NB=LINE_NB+1;
   if (COMMENT_TYPE eq 1) then COMMENT_TYPE_NB=COMMENT_TYPE_1_NB;
   else
      if (COMMENT_TYPE eq 2) then COMMENT_TYPE_NB=COMMENT_TYPE_2_NB;
   output COMMENTS;
end;
run;

proc sql noprint;
delete
from   SASDOC.PROGRAM_COMMENTS
where  PROGRAMPATH_PROGRAMNAME eq "&IN_FILE_NAME";

insert into SASDOC.PROGRAM_COMMENTS
   ( PROGRAMPATH_PROGRAMNAME, COMMENT_TYPE, COMMENT_TYPE_NB
    ,LINE_NB ,COMMENT, HSC_USR_ID, HSC_TS)
   select PROGRAMPATH_PROGRAMNAME
         ,COMMENT_TYPE, COMMENT_TYPE_NB, LINE_NB
         ,COMMENT, "&SYSUSERID", DATETIME()
   from   WORK.COMMENTS;
quit;
%mend GET_COMMENTS;

/*SASDOC-----------------------------------------------------------------------
| Count the number of rows in the SASDOC.FILE_ATTR table.
+----------------------------------------------------------------------SASDOC*/
proc sql noprint;
select NOBS
  into :NOBS_SASDOC_FILE_ATTR
from   DICTIONARY.TABLES
where  LIBNAME eq 'SASDOC'
  and  MEMNAME eq 'FILE_ATTR'
  and  MEMTYPE eq 'DATA';
quit;

%macro DRIVER_GET_COMMENTS(NOBS_SASDOC_FILE_ATTR);
%*SASDOC-----------------------------------------------------------------------
| Macro DRIVER_GET_COMMENTS is a driver for the GET_COMMENTS macro.
| Each program path - program name in the SASDOC.FILE_ATTR table is passed
| as the calling parameter to GET_COMMENTS.
+----------------------------------------------------------------------SASDOC*;
%*SASDOC-----------------------------------------------------------------------
| Create a data set for SASDOC program comments.
+----------------------------------------------------------------------SASDOC*;
%if (%sysfunc(exist(SASDOC.PROGRAM_COMMENTS)) eq 0) %then
%do;
   proc sql noprint;
   create table SASDOC.PROGRAM_COMMENTS
      ( PROGRAMPATH_PROGRAMNAME CHAR(&MAX_LRECL)
       ,COMMENT_TYPE             NUM
       ,COMMENT_TYPE_NB          NUM
       ,LINE_NB                  NUM
       ,COMMENT                  CHAR(256)
       ,HSC_USR_ID               CHAR(8)
       ,HSC_TS                   NUM format=DATETIME25.6);
   quit;
%end;

%*SASDOC-----------------------------------------------------------------------
| Get SASDOC comments from each program in the file contents dataset.
+----------------------------------------------------------------------SASDOC*;
%do NOBS=1 %to &NOBS_SASDOC_FILE_ATTR;
   proc sql noprint;
   select  trim(left(PROGRAMPATH_PROGRAMNAME))
   into    :PROGRAMPATH_PROGRAMNAME
   from    SASDOC.FILE_ATTR(firstobs=&NOBS obs=&NOBS);
   quit;
   %GET_COMMENTS(IN_FILE_NAME=&PROGRAMPATH_PROGRAMNAME);
%end;
%mend DRIVER_GET_COMMENTS;
%DRIVER_GET_COMMENTS(&NOBS_SASDOC_FILE_ATTR);

/*SASDOC-----------------------------------------------------------------------
| Join file contents dataset with program comments dataset.
+----------------------------------------------------------------------SASDOC*/
proc sql noprint;
create table WORK.FILE_ATTR_PROGRAM_COMMENTS as
select  A.*
       ,B.COMMENT_TYPE
       ,B.COMMENT_TYPE_NB
       ,B.LINE_NB
       ,B.COMMENT
       ,B.HSC_USR_ID
       ,B.HSC_TS
from   SASDOC.FILE_ATTR A left join SASDOC.PROGRAM_COMMENTS B
on     A.PROGRAMPATH_PROGRAMNAME eq B.PROGRAMPATH_PROGRAMNAME
order by PROGRAMPATH_PROGRAMNAME, COMMENT_TYPE, COMMENT_TYPE_NB, LINE_NB;
quit;

options missing=' ';
/*SASDOC-----------------------------------------------------------------------
| Modify SASDOC comments.
+----------------------------------------------------------------------SASDOC*/
data WORK.MARKUP;
length COMMENT_LABEL $8;
set WORK.FILE_ATTR_PROGRAM_COMMENTS;
by PROGRAMPATH_PROGRAMNAME COMMENT_TYPE COMMENT_TYPE_NB LINE_NB;
if COMMENT_TYPE=1 then
   COMMENT_LABEL='Header';
else
   if COMMENT_TYPE=. then
   COMMENT_LABEL='';
   else
      COMMENT_LABEL='Spec'||put(COMMENT_TYPE_NB,3.);
if (index(COMMENT,'--------------------') ne 0) then
   COMMENT='&nbsp';
COMMENT=tranwrd(trim(COMMENT),'%|','&nbsp&nbsp');
COMMENT=tranwrd(trim(COMMENT),'%*','
&nbsp&nbsp');
COMMENT=tranwrd(trim(COMMENT),'| ','&nbsp&nbsp');
COMMENT=tranwrd(trim(COMMENT),'|','&nbsp');
COMMENT=tranwrd(trim(COMMENT),' ','&nbsp');
run;

proc sort
   data=WORK.MARKUP
   out =WORK.MARKUP;
by PROGRAMPATH_PROGRAMNAME COMMENT_LABEL LINE_NB;
run;

/*SASDOC-----------------------------------------------------------------------
| Modify ODS template.
+----------------------------------------------------------------------SASDOC*/
ods path sasuser.templat(read) sashelp.tmplmst(read) work.templat(update);
proc template;
define style TOC_COMMENTS / store=WORK.TEMPLAT;
parent=STYLES.SASWEB;

style ContentTitle from ContentTitle
   "Controls the title of the Contents file." /
    pretext    = 'SAS Program Documentation'
    just       = center
    LeftMargin = 20pt
    foreground = blue
    font_face  =helvetica
    font_size  =09pt
    font_weight=bold;

style Frame from Document /
   ListEntryAnchor=yes
   ContentSize = 2.50in
   LeftMargin = 0
   TopMargin = 0
   Foreground = blue
   font_face="arial, helvetica"
   font_size=08pt
   FrameBorder = on
   FrameBorderWidth = 0.010in
   FrameSpacing = 0.010in
   ListEntryDblSpace = off
   prehtml = '<NOBR>'
   posthtml ='</NOBR>'
   pagebreakhtml=_undef_;

style Contents from Document /
   ListEntryAnchor=yes
   Foreground = blue
   font_face="arial, helvetica"
   font_size=08pt
   LeftMargin = 0
   TopMargin = 0
   ListEntryDblSpace = off
   prehtml = _undef_
   posthtml = _undef_
   pagebreakhtml=_undef_
   tagattr = ' link="blue" vlink="navy" onLoad="collapseAll(''UL'',0)"';

style ContentFolder from ContentFolder /
   Foreground = blue
   font_face="arial, helvetica"
   font_size=09pt
   prehtml = _undef_
   ListEntryDblSpace = off
   LeftMargin = 3pt
   TopMargin = 0
   prehtml = '<NOBR>'
   posthtml ='</NOBR>'
   pagebreakhtml=_undef_;

style ContentProcLabel from ContentProcLabel /
   ListEntryAnchor=yes
   prehtml = _undef_
   Foreground = blue
   font_face="arial, helvetica"
   font_size=08pt
   bullet = none
   LeftMargin = 0
   TopMargin = 0
   ListEntryDblSpace = off
   prehtml = '<NOBR>'
   posthtml ='</NOBR>'
   pagebreakhtml=_undef_
   pretext="<div style='text-decoration:none'>"
   posttext="</div>";

style ContentItem from ContentItem /
   font_face="arial, helvetica"
   font_size=09pt
   Foreground = blue
   ListEntryDblSpace = off
   bullet = 'disc'
   LeftMargin = 3pt
   TopMargin = 0
   htmlclass='ContentItem {margin-left:5}'
   prehtml = '<NOBR>'
   posthtml ='</NOBR>'
   pagebreakhtml=_undef_
   pretext="<div style='text-decoration:none'>"
   posttext="</div>";

style ContentProcName from ContentProcName /
   bullet=none
   ListEntryAnchor=yes;

style SysTitleAndFooterContainer from Container
   "Controls container for system page title and system page footer." /
   bordercolor = gray
   borderwidth = 1pt
   cellpadding = 1pt
   cellspacing = 0
   frame = box
   rules = none
   outputwidth = 100%;
style SystemTitle from TitlesAndFooters
   "Controls system title text." /
   font_face = verdana
   font_size = 9pt
   font_weight = medium nobreakspace = on
   foreground = blue;
style SystemFooter from TitlesAndFooters
   "Controls system footer text." /
   font_face = verdana
   font_size = 9pt
   font_weight = medium nobreakspace = on
   foreground = blue;
end;
run;

options nobyline;
options nocenter;
options pagesize=32767;
ods listing close;
ods escapechar "^";

filename RPT "&SASDOC_WEB_DIR";

ods html
   file="&prg_nm._b.html"
   style=TOC_COMMENTS
   stylesheet="temp.css"(url="temp.css")
   headtext="<title>SAS DOCUMENTATION</title>"
   path=RPT (url=none)
   contents="&prg_nm._c.html"
   frame="&prg_nm..html"
   newfile=proc;

%macro SASDOC_RPT(PROGRAMPATH_PROGRAMNAME, PROGRAM_PATH, PROGRAM_NAME, PERMISSIONS, OWNER, GROUP, FILESIZE, MOD_DT, FILE_ATTR_TS);
%*SASDOC-----------------------------------------------------------------------
| Create a report for each file.
+----------------------------------------------------------------------SASDOC*;
%let PROG_PATH_NAME=%substr(%sysfunc(translate(&PROGRAMPATH_PROGRAMNAME,'.','/')),2);
ods proclabel "&PROGRAMPATH_PROGRAMNAME";
ods html anchor="&PROGRAM_NAME";
ods html file="&PROG_PATH_NAME..html" path=RPT (url=none);
title1 j=l "^S={}%str(&PROGRAMPATH_PROGRAMNAME)^S={}";
title2 j=l "^S={}%str(&PERMISSIONS)%nrstr(&nbsp&nbsp)%str(&OWNER)%nrstr(&nbsp&nbsp)%str(&GROUP)%nrstr(&nbsp&nbsp)%str(&FILESIZE)%nrstr(&nbsp&nbsp)%str(&MOD_DT)^S={}";
footnote1 j=l "^S={}sasdoc updated %str(&FILE_ATTR_TS)^S={}";

proc report
   data=WORK.MARKUP(where=(PROGRAMPATH_PROGRAMNAME="&PROGRAMPATH_PROGRAMNAME"))
   nowd
   style(report)=[rules=none
                  frame=void
                  background  =_undef_
                  just        =l
                  cellspacing =0.00in
                  cellpadding =0.00in
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=0.00in
                  borderwidth =0.00in
                  asis        =off]
   style(column)=[font_size   =09pt
                  font_face   ='Lucida Console']
   contents='';
column COMMENT_LABEL LINE_NB COMMENT;

define COMMENT_LABEL / ' '  group page
   style=[cellwidth=1.00in
          foreground=blue
          font_face  =helvetica
          font_size  =08pt
          font_weight=bold
          prehtml = '<NOBR>'
          posthtml ='</NOBR>'
          just=l];
define LINE_NB  / ' ' noprint group order=data;

define COMMENT       / ' ' group
   style=[cellwidth=100%
          font_face  ='Lucida Console'
          font_size  =10pt
          prehtml = '<NOBR>'
          posthtml ='</NOBR>'
          asis     =off
          cellspacing =0.00in
          cellpadding =0.00in
          leftmargin  =0.00in
          rightmargin =0.00in
          topmargin   =0.00in
          bottommargin=0.00in
          font_weight=medium];

compute after  COMMENT_LABEL /
   style=[cellwidth=8in
          cellheight=2pt
          background =_undef_
          foreground =blue
          font_size=2pt
          cellspacing =0.00in
          cellpadding =0.00in
          leftmargin  =0.00in
          rightmargin =0.00in
          topmargin   =0.00in
          bottommargin=0.00in

          borderwidth =0.00in
          just       =l];
  line "<HR size=2>";
endcomp;

run;
quit;
%mend SASDOC_RPT;


/*SASDOC-----------------------------------------------------------------------
| Count the number of rows in the SASDOC.FILE_ATTR table.
+----------------------------------------------------------------------SASDOC*/
proc sql noprint;
select NOBS
  into :NOBS_SASDOC_FILE_ATTR
from   DICTIONARY.TABLES
where  LIBNAME eq 'SASDOC'
  and  MEMNAME eq 'FILE_ATTR'
  and  MEMTYPE eq 'DATA';
quit;


%macro DRIVER_SASDOC_RPT(NOBS_SASDOC_FILE_ATTR);
%*SASDOC-----------------------------------------------------------------------
| Macro DRIVER_SASDOC_RPT is a driver for the SASDOC_RPT macro.
| Each program path - program name in the SASDOC.FILE_ATTR table is passed
| as the calling parameter to SASDOC_RPT.
+----------------------------------------------------------------------SASDOC*;
%do NOBS=1 %to &NOBS_SASDOC_FILE_ATTR;
   proc sql noprint;
   select  trim(left(PROGRAMPATH_PROGRAMNAME))
          ,trim(left(PROGRAM_PATH))
          ,trim(left(PROGRAM_NAME))
          ,substr(PERMISSIONS,2,9), OWNER, GROUP, FILESIZE, MOD_DT format=worddate12.
          ,put(datepart(FILE_ATTR_TS),worddate12.)||put(timepart(FILE_ATTR_TS),time13.2)
   into    :m_PROGRAMPATH_PROGRAMNAME
          ,:m_PROGRAM_PATH
          ,:m_PROGRAM_NAME
          ,:m_PERMISSIONS, :m_OWNER, :m_GROUP, :m_FILESIZE, :m_MOD_DT
          ,:m_FILE_ATTR_TS
   from   SASDOC.FILE_ATTR(firstobs=&NOBS obs=&NOBS);
   quit;
   %SASDOC_RPT(&m_PROGRAMPATH_PROGRAMNAME
              ,&m_PROGRAM_PATH
              ,&m_PROGRAM_NAME
              ,&m_PERMISSIONS, &m_OWNER, &m_GROUP, &m_FILESIZE, %quote(&m_MOD_DT)
              ,%quote(&m_FILE_ATTR_TS));

%end;
%mend DRIVER_SASDOC_RPT;


%DRIVER_SASDOC_RPT(&NOBS_SASDOC_FILE_ATTR);

ods html close;
ods listing;
run;
quit;

proc sort
   data=WORK.FILE_ATTR_PROGRAM_COMMENTS
        (keep=DIR_LVL1-DIR_LVL&MAX_DIR_LVLS PROGRAMPATH_PROGRAMNAME
              PROGRAM_PATH PROGRAM_NAME COMMENT_TYPE)
   out =WORK.FILE_ATTR
   nodupkey;
by DIR_LVL1-DIR_LVL&MAX_DIR_LVLS PROGRAM_PATH PROGRAM_NAME COMMENT_TYPE;
run;

%macro ADD_TOC;
%*SASDOC-----------------------------------------------------------------------
| Macro ADD_TOC creates the contents based on the directory structure in
| the SASDOC.FILE_ATTR table and writes the html to MARKUP_2.
+----------------------------------------------------------------------SASDOC*;
data MARKUP_2(keep=TOC);
length TOC $ 512;
array DIR_LVL(&MAX_DIR_LVLS) $ 80 DIR_LVL1-DIR_LVL&MAX_DIR_LVLS;
set WORK.FILE_ATTR end=EOF;
by DIR_LVL1-DIR_LVL&MAX_DIR_LVLS PROGRAM_PATH PROGRAM_NAME;
if COMMENT_TYPE = . then
   LINK_UL=' style="text-decoration:none"';
else
   LINK_UL='';

%do I=1 %to &MAX_DIR_LVLS;
   DIR_NAME=DIR_LVL&I;
   if (first.DIR_LVL&I) and DIR_LVL&I ne '' then do;
      TOC='<ul class="ContentFolder"><li class="ContentFolder">/'||trim(left(DIR_LVL&I))||'<br><ul class="ContentFolder">';
      output;
   end;
%end;

if first.PROGRAM_PATH then
do;
   TOC='<ul class="ContentItem">';
   output;
end;

if first.PROGRAM_NAME then
do;
   DIR_NAME=PROGRAM_NAME;
   TOC='<li class="ContentItem"><NOBR><A HREF="'||trim(left(substr(translate(PROGRAMPATH_PROGRAMNAME,'.','/'),2)))||
        '.html#'||trim(left(PROGRAM_NAME))||'"'||trim(LINK_UL)||' TARGET="body">'||trim(left(PROGRAM_NAME))||'</a></NOBR><br>';
   output;
end;

if last.PROGRAM_PATH then
do;
   TOC='</ul>';
   output;
end;

%do I=1 %to &MAX_DIR_LVLS;
   DIR_NAME=DIR_LVL&I;
   if (last.DIR_LVL&I) and DIR_LVL&I ne '' then
   do;
      TOC='</ul>';
      output;
      output;
   end;
%end;
if EOF then
do;
   TOC='</BODY></HTML>';
   output;
end;
run;
%mend ADD_TOC;
%ADD_TOC;
/*SASDOC-----------------------------------------------------------------------
| The MARKUP_1 data step reads the original contents created by SASDOC_RPT.
| The original script is kept, but not the contents.
+----------------------------------------------------------------------SASDOC*/
filename TOC "&SASDOC_WEB_DIR.&PRG_NM._c.html" lrecl=32767;

Data MARKUP_1;
infile TOC truncover;
input;
if index(_INFILE_,'</span>') then
do;
   TOC=substr(_INFILE_,1,index(_INFILE_,'</span>')+6);
   output;
   stop;
end;
else
   TOC=_INFILE_;
output;
run;

/*SASDOC-----------------------------------------------------------------------
| MARKUP_1 is split up so that custom JavaScript can be inserted
| into the <SCRIPT></SCRIPT> portion of the HTML which was created
| by SAS.  The custom JavaScript resides in a file called sasdoc_addtl.sas.
+----------------------------------------------------------------------SASDOC*/

Data Markup_s1;
set markup_1;
if _n_ > 221 then delete;
run;


Data Markup_s2;
set markup_1;
if _n_ < 221 then delete;
run;

filename JS "&SASDOC_WEB_DIR.sasdoc_addtl.js";

Data Markup_js;
infile JS truncover;
input;
   TOC=_INFILE_;
output;
run;

/*SASDOC-----------------------------------------------------------------------
| Output post-processed contents frame.
+----------------------------------------------------------------------SASDOC*/
data _NULL_;
*set MARKUP_1 MARKUP_2;
set MARKUP_s1 MARKUP_JS MARKUP_s2 MARKUP_2;
file TOC;
put @1 TOC;
run;
