/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  initiative_results_overview.sas
|
| LOCATION: /PRG/sas%lowcase(&SYSMODE)1/hercules/reports
|
| PURPOSE:  Show all parameters that have been setup or are pending for a
|           mailing list/phase. Please refer to analytics network drive -
|           cmrdss\Analytics Team\Hercules\Java_Development\Deliverables
|           \Screen Specs.
|           The program selects descriptive and communication data for an
|           initiative/phase and produces a report.
|
| INPUT:   CLAIMSA.TPROGRAM
|          &HERCULES..TCMCTN_ENGINE_CD
|          &HERCULES..TCODE_COLUMN_XREF
|          &HERCULES..TINITIATIVE
|          &HERCULES..TINITIATIVE_PHASE
|          &HERCULES..TPHASE_RVR_FILE
|          &HERCULES..TTASK
           &HERCULES..TSCREEN_STATUS
|
| OUTPUT:   RPRT_FL (report file)
+--------------------------------------------------------------------------------
| HISTORY:  12SEP2003 - S.Shariff - based on inititative_summary_parms.sas
|           17MAR2004 - J.Chen - Comment out hard-coding of sysmode and call to
|                                the %set_sysmode macro
|           18MAR2004 - J.Chen - Add a macro called set_filename so that
|                                rptfl can be set conditionally depending on
|                                whether of not this report is being 
|                                requested by Java.
|           06JUL2004 - J.Chen - Added footer information; Added a macro to
|                                conditionally set REPORT_ID in footer
+------------------------------------------------------------------------HEADER*/

/* Select descriptive data for a initiative/phase;

%LET sysmode=test;
%set_sysmode;*/

%include "/herc%lowcase(&SYSMODE)/prg/hercules/reports/initiative_results_overview_in.sas";

proc sql noprint;
create table _TABLE_1 as
select
   A.INITIATIVE_ID     label='Initiative ID',
   A.PROGRAM_ID        label='Program ID',
   A.TASK_ID           label='Task ID',
   A.OVRD_CLT_SETUP_IN label='Override Client',
   A.BUS_RQSTR_NM      label='Business Requestor',
   A.TITLE_TX          label='Initiative Title',
   A.DESCRIPTION_TX    label='Initiative Description',
   A.HSC_USR_ID as INITIATIVE_HSC_USR_ID
                       label='Initiative Requestor',
   B.PHASE_SEQ_NB      label='Phase ID',
   B.JOB_SCHEDULED_TS  label='Job Scheduled Time',
   B.JOB_START_TS      label='Job Start Time',
   B.JOB_COMPLETE_TS   label='Job Complete Time',
   B.HSC_USR_ID as PHASE_HSC_USR_ID
                       label='Phase Requestor',
   E.CMCTN_ROLE_CD     label='Receiver',
   E.DATA_CLEANSING_CD label='Data Cleansing Code',
   E.FILE_USAGE_CD     label='File Usage Code',
   E.DESTINATION_CD    label='Destination Code',
   E.RELEASE_STATUS_CD label='Release Status Code',
   E.REJECTED_QY       label='Initial Records Rejected',
   E.ACCEPTED_QY       label='Initial Records Accepted',
   E.SUSPENDED_QY      label='Initial Records Suspended',
   E.LETTERS_SENT_QY   label='Letters Mailed Code'
 from &HERCULES..TINITIATIVE A,
      &HERCULES..TINITIATIVE_PHASE B,
      &HERCULES..TPHASE_RVR_FILE E
 where A.INITIATIVE_ID eq &INITIATIVE_ID
   and B.PHASE_SEQ_NB  eq &PHASE_SEQ_NB
   and A.INITIATIVE_ID eq B.INITIATIVE_ID
   and A.INITIATIVE_ID eq E.INITIATIVE_ID
   and B.PHASE_SEQ_NB  eq E.PHASE_SEQ_NB;
quit;

%* Add formatted variables to initiative/phase data.;
%add_fmt_vars(_TABLE_1,
              _F_TABLE_1,
              F_,
              PROGRAM_ID,
              TASK_ID,
              CMCTN_ROLE_CD,
              DATA_CLEANSING_CD,
              FILE_USAGE_CD,
              DESTINATION_CD,
              RELEASE_STATUS_CD);

%macro set_filename;
%global JAVA_CALL release_data_ok;
%IF (&JAVA_CALL = %STR() OR (&JAVA_CALL NE %STR() AND &release_data_ok NE %STR())) %THEN %DO;
filename RPTFL "/herc&sysmode/report_doc/hercules/general/&INITIATIVE_ID._initiative_results_overview.pdf";
/*filename RPTFL "/herc%lowcase(&sysmode)/report_doc/hercules/general/&INITIATIVE_ID._initiative_results_overview.pdf";*/
%END;
%mend;
%set_filename;

%macro set_rpt_id;
%global REPORT_ID;
%IF &REPORT_ID = %STR() %THEN %DO;
/* This macro assigns a hard-coded REPORT_ID if the report is
   requested via the Program Maintenance Screen */
%LET REPORT_ID=9;
%END;
%mend;
%set_rpt_id;

%let _hdr_fg =blue;
%let _hdr_bg =lightgrey;
%let _tbl_fnt="Arial";
options orientation=portrait papersize=letter nodate nonumber;
options leftmargin  ="0.50in"
        rightmargin ="0.00in"
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
                font_weight=bold}Initiative Results Overview Report^S={}";
footnote1 j=r "^S={font_face=arial
                font_size=7pt
                font_weight=bold}Caremark IT Analytics^S={}";
footnote2 j=r "^S={font_face=arial
                font_size=7pt
                font_weight=bold}Report Generated: %sysfunc(datetime(),datetime19.)^S={}";
footnote3 j=r "^S={font_face=arial
                font_size=7pt
                font_weight=bold}Report ID: &REPORT_ID ^S={}";
ods proclabel="Initiative Results Overview Report";
proc report
   contents='Initiative Summary'
   data=_F_TABLE_1
   missing
   noheader
   nowd
   split="*"
   style(report)=[rules       =none
                  frame       =void
                  just        =l
                  cellspacing =0.00in
                  cellpadding =0.00in
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =10pt
                  font_face   =&_tbl_fnt];
column
   L_INITIATIVE_ID
   INITIATIVE_ID
   L1_DASH_1
   PHASE_SEQ_NB
   L_PROGRAM_ID
   PROGRAM_ID
   L1_DASH_2
   F_PROGRAM_ID
   L_TASK_ID
   F_TASK_ID
   L_BUS_RQSTR_NM
   BUS_RQSTR_NM
   TITLE_TX
   L_DESCRIPTION_TX
   DESCRIPTION_TX
   INITIATIVE_HSC_USR_ID
   PHASE_HSC_USR_ID
   JOB_SCHEDULED_TS
   JOB_START_TS
   JOB_COMPLETE_TS;

define L_INITIATIVE_ID     / computed
   style=[cellwidth=1.20in
          font_weight=bold
          foreground=&_hdr_fg
          just=l
          pretext="Initiative - Phase:"];
compute L_INITIATIVE_ID    / char length=1;
   L_INITATIVE_ID='';
endcomp;
define INITIATIVE_ID       / group
   style=[cellwidth=0.40in
          just=r];
define L1_DASH_1           / computed
   style=[cellwidth=0.15in
          font_weight=bold
          just=c];
compute L1_DASH_1          / char length=1;
   L1_DASH_1="-";
endcomp;
define PHASE_SEQ_NB        / group
   style=[cellwidth=0.40in
          just=l];
define L_PROGRAM_ID        / computed
   style=[cellwidth=1.00in
          font_weight=bold
          foreground=&_hdr_fg
          just=r
          pretext="Program:"];
compute L_PROGRAM_ID / char length=1;
   L_PROGRAM_ID=' ';
endcomp;
define PROGRAM_ID          / group
   style=[cellwidth=0.45in
          just=r];
define L1_DASH_2    / computed
   style=[cellwidth=0.15in
          font_weight=bold
          just=c];
compute L1_DASH_2   / char length=1;
   L1_DASH_2="-";
endcomp;
define F_PROGRAM_ID        / group
   style=[cellwidth=3.75in
          just=l];
define L_TASK_ID           / computed page
   style=[cellwidth  =0.40in
          font_weight=bold
          foreground =&_hdr_fg
          just=l
          pretext="Task:"];
compute L_TASK_ID          / char length=1;
   L_TASK_ID='';
endcomp;
define F_TASK_ID           / group
   style=[cellwidth=3.20in
          just     =l];
define L_BUS_RQSTR_NM      / computed
   style=[cellwidth  =1.55in
          font_weight=bold
          foreground =&_hdr_fg
          just       =l
          pretext    ="^S={}^_^_Business Requestor:^S={}"];
compute L_BUS_RQSTR_NM     / char length=1;
   L_BUS_RQSTR_NM='';
endcomp;
define BUS_RQSTR_NM        / group
   style=[cellwidth=2.35in
          just     =l];
define TITLE_TX            / group page
   style=[cellwidth  =7.50in
          font_weight=medium
          just       =l
          pretext    ="^S={font_weight=bold
                           foreground =&_hdr_fg}Title:^_^S={}"];
define L_DESCRIPTION_TX    / computed page
   style=[cellwidth  =0.85in
          font_weight=bold
          foreground =&_hdr_fg
          just       =l
          pretext    ="Description:"];
compute L_DESCRIPTION_TX   / char length=1;
   L_DESCRIPTION_TX='';
endcomp;
define DESCRIPTION_TX      /  group
   style=[cellwidth=6.65in
          just     =l];
define INITIATIVE_HSC_USR_ID/ group page
   style=[cellwidth  =2.75in
          font_weight=medium
          just       =l
          pretext    ="^S={font_weight=bold
                           foreground=&_hdr_fg}Initiative Requestor:^_^_^S={}"];
define PHASE_HSC_USR_ID     / group
   style=[cellwidth  =4.75in
          font_weight=medium
          just       =l
          pretext    ="^S={font_weight=bold
                           foreground =&_hdr_fg}Phase Requestor:^_^_^S={}"];
define JOB_SCHEDULED_TS    / group format=dttime.
   style=[cellwidth  =2.75in
          font_weight=medium
          just       =l
          pretext    ="^S={font_weight=bold
                           foreground =&_hdr_fg}Job Scheduled:^_^_^S={}"];
define JOB_START_TS        / group format=dttime.
   style=[cellwidth  =2.40in
          font_weight=medium
          just       =l
          pretext    ="^S={font_weight=bold
                           foreground =&_hdr_fg}Job Start:^_^_^S={}"];
define JOB_COMPLETE_TS     / group format=dttime.
   style=[cellwidth  =2.35in
          font_weight=medium
          just       =l
          pretext    ="^S={font_weight=bold
                           foreground =&_hdr_fg}Job Complete:^_^_^S={}"];
run;
quit;

ods proclabel=" ";
proc report
   contents='Receiver Component'
   data=_F_TABLE_1
   missing
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =9pt
                  font_face   =&_tbl_fnt];
column
   F_CMCTN_ROLE_CD
   F_DATA_CLEANSING_CD
   F_FILE_USAGE_CD
   F_DESTINATION_CD
   F_RELEASE_STATUS_CD
   F_CMCTN_ROLE_CD
   REJECTED_QY
   ACCEPTED_QY
   SUSPENDED_QY
   LETTERS_SENT_QY;
define F_CMCTN_ROLE_CD      / display page
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Receiver^S={}"
   style=[cellwidth=1.05in
          font_weight=bold
          just=l];
define F_DATA_CLEANSING_CD  / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Data Cleansing^S={}"
   style=[cellwidth=1.62in
          font_weight=medium
          just=l];
define F_FILE_USAGE_CD      / display
   "^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}File Usage^S={}"
   style=[cellwidth=1.63in
          font_weight=medium
          just=l];
define F_DESTINATION_CD     / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Desination^S={}"
   style=[cellwidth=1.75in
          font_weight=medium
          just=l];
define F_RELEASE_STATUS_CD  / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Release Status^S={}"
   style=[cellwidth=1.45in
          font_weight=medium
          just=l];
define REJECTED_QY          / analysis format=comma14.
   "^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Initial Records Rejected^S={}"
   style=[cellwidth=1.62in
          font_size=10pt
          font_weight=medium
          just=c];
define ACCEPTED_QY          / analysis format=comma14.
   "^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Initial Records Accepted^S={}"
   style=[cellwidth=1.63in
          font_size=10pt
          font_weight=medium
          just=c];
define SUSPENDED_QY         / analysis format=comma14.
   "^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Initial Records Suspended^S={}"
   style=[cellwidth=1.75in
          font_size=10pt
          font_weight=medium
          just=c];
define LETTERS_SENT_QY      / analysis format=comma14.
   "^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Letters Mailed^S={}"
   style=[cellwidth=1.45in
          font_size=10pt
          font_weight=medium
          rightmargin=0.50in
          just=c];
run;
quit;

proc sql;
drop table
                _TABLE_1,
                _F_TABLE_1;
quit;
ods pdf close;
