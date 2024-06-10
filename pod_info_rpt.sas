*%let sysmode=test;
*LIBNAME HERCULET DB2 DSN=&UDBSPRP SCHEMA=HERCULET DEFER=YES;
*LIBNAME HERCULES DB2 DSN=&UDBSPRP SCHEMA=HERCULES DEFER=YES;

*%LET hercules = herculet;
*%LET _SOCKET_ERROR_MSG = Test Error;

/* HEADER ----------------------------------------------------------------------
|  PROGRAM:  pod_info_rpt.sas
|
|  LOCATION: /PRG/sas&sysmode.1/hercules/reports/pod_info_rpt.sas
|
|  PURPOSE:
|  This report will provide overall cell/pod information to the user while
|  the user is doing program maintenance.  In the Program Maint - POD screen,
|  the user will be updating the TPOD_CSTM_MESSAGE table.  Before or after
|  performing an update, the user will be able to print the report to see
|  current custom messages.
|
|  INPUT:
|         &hercules..tpod_cstm_message
|         claimsa.tpod
|         claimsa.tcell_pod
|         claimsa.tcell
|         claimsa.tformulary_pod
|
|  OUTPUT:
|        This report will be generated in response to a call from the JAVA
|        Program Maint - POD screen.  A PDF file will be created and sent
|        to the browser.
|
|  AUTHOR/DATE: Justin Chen/February 18, 2004
|
|  MODIFICATIONS: 
|                 
|      1) Added code so that Report ID would appear in the footer (QCPI134,
|         J.Chen, 7/6/2004)
|
|------------------------------------------------------------------------HEADER */;

*SASDOC--------------------------------------------------------------------------
| Selection of data for the report.
+------------------------------------------------------------------------SASDOC*;
PROC SQL;
   CREATE TABLE WORK.CELL_POD_DATA AS
     select distinct
         cell_nm,
       a.pod_id,
         pod_nm,
       case retail_msg_in
                  when 1 then 'Y'
                  else        ' '
                  end  as  ret_msg,
       case no_generic_msg_in
                  when 1 then 'Y'
                  else        ' '
                  end  as  no_gen_msg
     from       &hercules..tpod_cstm_message a,
         claimsa.tpod b,
         claimsa.tcell_pod c,
         claimsa.tcell d,
         claimsa.tformulary_pod e
     where      a.pod_id = b.pod_id
     and        b.pod_id = c.pod_id
     and          c.cell_id = d.cell_id
     and           a.pod_id = e.pod_id
     and           e.effective_dt <= today()
     and           e.expiration_dt > today()
     order by ret_msg, cell_nm, pod_nm, pod_id;
QUIT;

PROC SQL;
 CREATE TABLE WORK.USE_RETAIL_MSG AS
   select
         cell_nm,
         pod_id,
         pod_nm
   from
         work.cell_pod_data
   where ret_msg = "Y";
QUIT;

PROC SQL;
 CREATE TABLE WORK.SUPPRESS_GENERIC_MSG AS
   select
         cell_nm,
         pod_id,
         pod_nm
   from
         work.cell_pod_data
   where no_gen_msg = "Y";
QUIT;

*****ONLY FOR TEST******;
*filename RPTFL "/user1/qcpi134/pod_cell_rpt.pdf";
*********FOR TEST*******;

%macro set_rpt_id;
%global REPORT_ID;
%IF &REPORT_ID = %STR() %THEN %DO;
/* This macro assigns a hard-coded REPORT_ID if the report is
   requested via the Program Maintenance Screen */
%LET REPORT_ID=7;
%END;
%mend;
%set_rpt_id;

%let _hdr_clr=blue;
%let _col_clr=black;
%let _hdr_fg =blue;
%let _hdr_bg =lightgrey;
%let _tbl_fnt="Arial";
options orientation=portrait papersize=letter nodate number pageno=1
                leftmargin  ="0.00"
        rightmargin ="0.00"
        topmargin   ="0.75in"
        bottommargin="0.25in";
ods listing close;
ods pdf file=RPTFL
        startpage=off
        style=my_pdf
                notoc;
ods escapechar "^";
title1 j=c "^S={font_face=arial
                font_size=12pt
                font_weight=bold}Hercules Communication Engine^S={}";
title2 j=c "^S={font_face=arial
                font_size=14pt
                font_weight=bold}Cell/Pod Custom Message Report^S={}";
title3 " ";

footnote1 j=r "^S={font_face=arial
                font_size=7pt
                font_weight=bold}Caremark IT Analytics^S={}";
footnote2 j=r "^S={font_face=arial
                font_size=7pt
                font_weight=bold}Report Generated: %sysfunc(datetime(),datetime19.)^S={}";
footnote3 j=r "^S={font_face=arial
                font_size=7pt
                font_weight=bold}Report ID: &REPORT_ID ^S={}";

*SASDOC--------------------------------------------------------------------------
| This prints the report in PDF format.
+------------------------------------------------------------------------SASDOC*;

proc report
   data=WORK.SUPPRESS_GENERIC_MSG
   missing
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =c
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_face=arial
                  font_size   =9pt
                  font_face   =&_tbl_fnt];


title4 j=c "^S={font_face=arial
                font_size=12pt
                font_weight=bold}Suppress Generic Message^S={}";

column
        CELL_NM
        POD_ID
        POD_NM;

define CELL_NM  / display group order=data
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}CELL NAME^S={}"
   style=[just     =l];


define POD_ID  / display order=data
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}POD ID^S={}"
   style=[just     =c];


define POD_NM  / display order=data
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}POD NAME^S={}"
   style=[just     =l];

run;
quit;

ods pdf startpage=yes;
ods pdf startpage=off;

proc report
   data=WORK.USE_RETAIL_MSG
   missing
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =c
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_face=arial
                  font_size   =9pt
                  font_face   =&_tbl_fnt];

title4 j=c "^S={font_face=arial
                font_size=12pt
                font_weight=bold}Use Retail Message^S={}";

column
        CELL_NM
        POD_ID
        POD_NM;

define CELL_NM  / display group order=data
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}CELL NAME^S={}"
   style=[just     =l];


define POD_ID  / display order=data
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}POD ID^S={}"
   style=[just     =c];


define POD_NM  / display order=data
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}POD NAME^S={}"
   style=[just     =l];

run;
quit;

ods pdf close;

*SASDOC--------------------------------------------------------------------------
| Clean Up - Removes the dataset that was generated in work
+------------------------------------------------------------------------SASDOC*;

PROC SQL;
        DROP TABLE WORK.CELL_POD_DATA;
        DROP TABLE USE_RETAIL_MSG;
        DROP TABLE SUPPRESS_GENERIC_MSG;
QUIT;
