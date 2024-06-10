/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Tuesday, January 20, 2004      TIME: 11:27:09 AM
   PROJECT: Project
   PROJECT PATH: 
---------------------------------------- */
/*HEADER----------------------------------------------------------------------
PROGRAM:
   client_initiative_summary_r2.sas

LOCATION:
   /PRG/sas&sysmode.1/hercules/reports/client_initiative_summary_r2.sas

PURPOSE:
   	This reports is for a particular initiative/phase that has
   	only more than one receiver (NO_RECEIVERS>1).

	The report will not have a column attributed to receivers.
	The receiver will be specified at the top of the report along
	with other information, as follows:

	1. Initiative-Phase
	2. Program ID
	3. Task ID
	4. Title
	5. Receiver
	6. Job Completed Date.

INPUT:
	
OUTPUT:
   REPORT_FILE

AUTHOR/DATE:
   Sayeed Shariff/September 2003.

MODIFICATIONS:

------------------------------------------------------------------------*/;
*SASDOC--------------------------------------------------------------------------
| This prints the top report with all of the header information.
+------------------------------------------------------------------------SASDOC*;
proc report
   data=FCLIENT_INIT_DETAILS_1
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
   TITLE_TX
   RECEIVERS
   JC_DATE;

define L_INITIATIVE_ID     / computed
   style=[cellwidth=1.20in
          font_weight=bold
          foreground=&_hdr_clr
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
          foreground=&_hdr_clr
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
   style=[cellwidth=0.40in
          font_weight=bold
          foreground=&_hdr_clr
          just=l
          pretext="Task:"];

compute L_TASK_ID          / char length=1;
   L_TASK_ID='';
endcomp;

define F_TASK_ID           / group
   style=[cellwidth=3.20in
          just=l];

define TITLE_TX            / group page
   style=[cellwidth=7.50in
          font_weight=medium
          just=l
          pretext="^S={font_weight=bold
                       foreground =&_hdr_clr}Title:^_^S={}"];

define RECEIVERS          / group page
   style=[cellwidth=7.50in
          font_weight=medium
          just=l
          pretext="^S={font_weight=bold
                       foreground =&_hdr_clr}Receiver(s):^_^S={}"];

define JC_DATE        / group page
   style=[cellwidth=7.50in
          font_weight=medium
          just=l
          pretext="^S={font_weight=bold
                       foreground =&_hdr_clr}Job Completed Date:^_^S={}"];

run;
quit;

*SASDOC--------------------------------------------------------------------------
| This prints the bottom report with the client name and number of letters.
+------------------------------------------------------------------------SASDOC*;
proc report
   data=FCLIENT_INIT_DETAILS_1
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
   style(column)=[font_face=arial
                                  font_size   =9pt
                  font_face   =&_tbl_fnt];

 
column
        CLIENT_NM_ID
        CLIENT_CD
        F_CMCTN_ROLE_CD
        No_Letters
        No_Subjects;

define No_Letters / analysis sum
                  format=best8.
        "^S={ font_face=arial
        font_weight=bold
        background =&_hdr_bg
        just       =c}Number of Letters^S={}"
   style=[cellwidth=0.75in
          font_weight=medium
          just=c];

break after CLIENT_NM_ID   /  ol
                        summarize
                        suppress
                        skip;
compute after /
   style=[font_face=arial
          just=c];
      line "^S={font_face=arial
        font_weight=bold
        background =&_hdr_bg
        just       =c}Total Number of Letters:^S={}"
            No_Letters.sum best8.  '.';
endcomp;

compute No_Letters;
      if _break_ ne ' ' then
      call define(_col_,"format","best8.");
endcomp;

define No_Subjects        / analysis sum format=best8.
   "^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Number of Subjects^S={}"
   style=[cellwidth=0.75in
          font_weight=medium
          BORDERWIDTH=0
          just=c];

break after CLIENT_NM_ID   /  ol
                        summarize
                        suppress
                        skip;
compute No_Subjects;
      if _break_ ne ' ' then
      call define(_col_,"format","best8.");
endcomp;

define CLIENT_NM_ID     / group page
   "^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Client Name (ID)^S={}"
   style=[cellwidth=2.80in
          font_weight=bold
                 just=l];

define CLIENT_CD     / group
   "^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Client Code^S={}"
   style=[cellwidth=1.00in
          font_weight=medium
          BORDERWIDTH=0
          just=c];

define F_CMCTN_ROLE_CD    / group
   "^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Receiver(s)^S={}"
   style=[cellwidth=1.10in
          font_weight=medium
          BORDERWIDTH=0
          just=c];

run;
quit;
ods pdf close;
