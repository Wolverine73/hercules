
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  gstp_expanded_clients_count.sas
|
| LOCATION: /PRG/sas&sysmode.1/hercules/reporting
|
| PURPOSE:  Used to produce a list of the expanded clients count
|           for the program GSTP which is set up in the system.
|
| LOGIC:     
|
|
| INPUT:     
|
| OUTPUT:   Report is sent via email to requestor
|
+-------------------------------------------------------------------------------
| HISTORY:  Nov 2010 - B.Stropich - Original  
|
+-----------------------------------------------------------------------HEADER*/

%set_sysmode(mode=prod);
/**
%set_sysmode(mode=test);
options sysparm='INITIATIVE_ID=5584 PHASE_SEQ_NB=1';
%let REQUEST_ID=101331;
**/

%INCLUDE "/herc&sysmode./prg/hercules/reports/hercules_rpt_in.sas";
%INCLUDE "/herc%lowcase(&SYSMODE)/prg/hercules/reports/report_in.sas"; 

libname ADM_LKP "/herc%lowcase(&SYSMODE)/data/Admin/auxtable";
libname PEND "/herc%lowcase(&SYSMODE)/data/hercules/&_program_id./pending";

%let RPT_PATH=%str(\\sfb006\PatientList\&ops_subdir.\Reports);

%let ERR_FL=0;
%let PROGRAM_NAME=gstp_client_letter_count;

%let PPT_DATASET=t_&REQUIRED_PARMTR_ID._1_1;
%let MD2_DATASET=t_&REQUIRED_PARMTR_ID._1_2;


%let _&REQUIRED_PARMTR_nm.=&REQUIRED_PARMTR_id;
%let _&SEC_REQD_PARMTR_nm.=&SEC_REQD_PARMTR_id;
%let table_prefix=R_&REQUEST_ID;
%let RPT_FILE_NM=%str(Program_GSTP_Expanded_Clients_Count_&REQUIRED_PARMTR_ID.);

%put NOTE: _&REQUIRED_PARMTR_nm.=&REQUIRED_PARMTR_id;
%put NOTE: _&SEC_REQD_PARMTR_nm.=&SEC_REQD_PARMTR_id;
%put NOTE: TABLE_PREFIX=&TABLE_PREFIX;
%put NOTE: &ops_subdir;  /** 5295 57 GSTP = Patientlist - HPFPD **/
 

* ---> Set the parameters for error checking;
 PROC SQL NOPRINT;
    SELECT QUOTE(TRIM(email)) INTO :Primary_programmer_email SEPARATED BY ' '
    FROM ADM_LKP.ANALYTICS_USERS
    WHERE UPCASE(QCP_ID) IN ("&USER");
 QUIT;

%macro setup_values;
  %GLOBAL INIT_ID;
  %IF (&REQUEST_ID eq %STR()) %THEN %LET INIT_ID = &INITIATIVE_ID;
  %ELSE %LET INIT_ID = &_INITIATIVE_ID;

/*  %if %lowcase(&SYSMODE) = test %then %do;*/
/*    %let Primary_programmer_email=%str("brian.stropich2@caremark.com");*/
/*  %end;*/
%mend setup_values;
%setup_values;


%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for report request id &request_id");

*SASDOC-------------------------------------------------------------------------
| Update the job start timestamp.
+-----------------------------------------------------------------------SASDOC*;
%update_request_ts(start);


%macro gstp_expanded_client_count(dataset=);


%*SASDOC-----------------------------------------------------------------------
| Select data for report.
+----------------------------------------------------------------------SASDOC*;

*SASDOC-------------------------------------------------------------------------
| QL SQL for expanded client counts                           
+-----------------------------------------------------------------------SASDOC*;
proc sql noprint;
	create table expand_ql as
	select    trim(left(A.CLIENT_NM))  ||' ('||trim(left(put(A.CLIENT_ID,32.)))||')'  as CLIENT_NM_ID
			 ,A.GROUP_CLASS_SEQ_NB
	         ,A.BLG_REPORTING_CD
	         ,trim(left(compbl(A.PLAN_CD)))
	          ||" "||trim(left(compbl(A.PLAN_EXT_CD_TX)))
	          ||" "||trim(left(compbl(A.GROUP_CD)))
	          ||" "||trim(left(compbl(A.GROUP_EXT_CD_TX))) as PLAN_GRP 
	         ,count(distinct RECIPIENT_ID) as PATIENT_COUNT
	from pend.&dataset. A   
	where ADJ_ENGINE = 'QL' 
	    and a.data_quality_cd=1  
	group by  CLIENT_NM_ID
	         ,GROUP_CLASS_SEQ_NB
	         ,BLG_REPORTING_CD
	         ,PLAN_GRP 
	order by  CLIENT_NM_ID
	         ,GROUP_CLASS_SEQ_NB
	         ,BLG_REPORTING_CD
	         ,PLAN_GRP ;
quit;

*SASDOC-------------------------------------------------------------------------
| Recap SQL for expanded client counts                           
+-----------------------------------------------------------------------SASDOC*;
proc sql noprint;
	create table expand_re as
	select    trim(left(A.CLIENT_NM))  as CLIENT_NM_ID
			 ,A.client_level_1
	         ,A.client_level_2
	         ,A.client_level_3 
	         ,count(distinct RECIPIENT_ID) as PATIENT_COUNT
	from pend.&dataset. A   
	where ADJ_ENGINE = 'RE' 
	    and a.data_quality_cd=1  
	group by  CLIENT_NM_ID
	         ,client_level_1
	         ,client_level_2
	         ,client_level_3 
	order by CLIENT_NM_ID
	         ,client_level_1
	         ,client_level_2
	         ,client_level_3  ;
quit;

*SASDOC-------------------------------------------------------------------------
| Rxclaim SQL for expanded client counts                           
+-----------------------------------------------------------------------SASDOC*;
proc sql noprint;
	create table expand_rx as
	select    trim(left(A.CLIENT_NM))  as CLIENT_NM_ID
			 ,A.client_level_1
	         ,A.client_level_2
	         ,A.client_level_3 
	         ,count(distinct RECIPIENT_ID) as PATIENT_COUNT
	from pend.&dataset. A   
	where ADJ_ENGINE = 'RX' 
	    and a.data_quality_cd=1  
	group by  CLIENT_NM_ID
	         ,client_level_1
	         ,client_level_2
	         ,client_level_3 
	order by  CLIENT_NM_ID
	         ,client_level_1
	         ,client_level_2
	         ,client_level_3  ;
quit;

*SASDOC-------------------------------------------------------------------------
| Produce a report of Client / Plan-Group / - Patient Count.
+-----------------------------------------------------------------------SASDOC*;
options orientation=portrait papersize=letter nodate nonumber missing=''
        leftmargin  ="0.35in"
        rightmargin ="0.00in"
        topmargin   ="0.00in"
        bottommargin="0.00in";
ods listing close;
ods rtf file     =RPTFL;
ods escapechar "^";
title1 j=r "^S={ 
                font_style =roman
                font_size  =9pt
                font_weight=bold}%sysfunc(datetime(),datetime24.)^S={}"
            "^S={ 
                font_style =roman
                font_size  =9pt
                font_weight=bold}{     Page }{\field{\*\fldinst { PAGE }}}\~{of}\~{\field{\*\fldinst{ NUMPAGES }}}^S={}";
title2 j=c "^S={ 
                font_style =roman
                font_size=12pt
                font_weight=bold}Hercules Communication Engine^S={}";
title3 j=c "^S={
                font_style =roman
                font_size=14pt
                font_weight=bold}GSTP Expanded Clients Report^S={}";
title4 j=c "^S={
                font_style =roman
                font_size=12pt
                font_weight=bold}QL Client^S={}";
title5 " ";
title6 j=c "^S={
                font_style =roman
                font_size  =11pt 
                font_weight=medium}Initiative ID:^S={}"
           "^S={
                font_style =roman
                font_size  =11pt
                font_weight=bold} &REQUIRED_PARMTR_ID.^S={}";
footnote1 j=l "^S={
                   font_style =roman
                   font_size  =9pt
                   font_weight=bold}&RPT_PATH^S={}";

proc report
   data=expand_ql
   missing
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =c
                  font_size   =11.0pt
                  cellpadding =0.04in
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =8.5pt ];
column
   CLIENT_NM_ID
   BLG_REPORTING_CD
   PLAN_GRP 
   PATIENT_COUNT;
define    CLIENT_NM_ID     / group page
   "^S={font_weight=bold
        font_size  =10pt 
        just       =c}Client^S={}"
   style=[cellwidth  =2.50in
          font_weight=medium
          just=l];
define BLG_REPORTING_CD    / group
   "^S={font_weight=bold
        font_size  =10pt 
        just       =c}Billing^nReport Code^S={}"
   style=[cellwidth  =1.25in
          font_weight=medium
          just=l];
define PLAN_GRP            / group
   "^S={font_weight=bold
        font_size  =10pt 
        just       =c}Plan/Group^S={}"
   style=[cellwidth  =2.00in
          font_weight=medium
          just=l]; 
define PATIENT_COUNT       / analysis sum format=comma9.
   "^S={font_weight=bold
        font_size  =10pt 
        just       =c}Patients^S={}"
   style=[cellwidth  =0.75in
          font_weight=medium
          just       =r
          posttext   ="^S={}^_^_^_^_^S={}"];
break after CLIENT_NM_ID   / suppress page;
compute after CLIENT_NM_ID /
   style=[
          font_size  =10pt
          font_weight=bold
          font_style =roman 
          just       =l];
   line "^S={just=r}Client Total^_^_^_^_^_^_^S={}"
        PATIENT_COUNT.sum "^S={}^_^_^_^S={}";
endcomp;
run;

title3 j=c "^S={
                font_style =roman
                font_size=14pt
                font_weight=bold}GSTP Expanded Clients Report^S={}";
title4 j=c "^S={
                font_style =roman
                font_size=12pt
                font_weight=bold}RECAP Client^S={}";
title5 " ";
title6 j=c "^S={
                font_style =roman
                font_size  =11pt 
                font_weight=medium}Initiative ID:^S={}"
           "^S={
                font_style =roman
                font_size  =11pt
                font_weight=bold} &REQUIRED_PARMTR_ID.^S={}";

proc report
   data=expand_re
   missing
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =c
                  font_size   =11.0pt
                  cellpadding =0.04in
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =8.5pt ];
column
   CLIENT_NM_ID
         client_level_1
         client_level_2
         client_level_3 
   PATIENT_COUNT;
define    CLIENT_NM_ID     / group page
   "^S={font_weight=bold
        font_size  =10pt 
        just       =c}Client^S={}"
   style=[cellwidth  =2.50in
          font_weight=medium
          just=l];
define client_level_1    / group
   "^S={font_weight=bold
        font_size  =10pt 
        just       =c}Client^nLevel 1^S={}"
   style=[cellwidth  =1.00in
          font_weight=medium
          just=l];
define client_level_2            / group
   "^S={font_weight=bold
        font_size  =10pt 
        just       =c}Client^nLevel 2^S={}"
   style=[cellwidth  =1.00in
          font_weight=medium
          just=l];
define client_level_3            / group
   "^S={font_weight=bold
        font_size  =10pt 
        just       =c}Client^nLevel 3^S={}"
   style=[cellwidth  =1.00in
          font_weight=medium
          just=l]; 
define PATIENT_COUNT       / analysis sum format=comma9.
   "^S={font_weight=bold
        font_size  =10pt 
        just       =c}Patients^S={}"
   style=[cellwidth  =0.75in
          font_weight=medium
          just       =r
          posttext   ="^S={}^_^_^_^_^S={}"];
break after CLIENT_NM_ID   / suppress page;
compute after CLIENT_NM_ID /
   style=[
          font_size  =10pt
          font_weight=bold
          font_style =roman 
          just       =l];
   line "^S={just=r}Client Total^_^_^_^_^_^_^S={}"
        PATIENT_COUNT.sum "^S={}^_^_^_^S={}";
endcomp;
run;

title3 j=c "^S={
                font_style =roman
                font_size=14pt
                font_weight=bold}GSTP Expanded Clients Report^S={}";
title4 j=c "^S={
                font_style =roman
                font_size=12pt
                font_weight=bold}RXCLAIM Client^S={}";
title5 " ";
title6 j=c "^S={
                font_style =roman
                font_size  =11pt 
                font_weight=medium}Initiative ID:^S={}"
           "^S={
                font_style =roman
                font_size  =11pt
                font_weight=bold} &REQUIRED_PARMTR_ID.^S={}";

proc report
   data=expand_rx
   missing
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =c
                  font_size   =11.0pt
                  cellpadding =0.04in
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =8.5pt ];
column
   CLIENT_NM_ID
         client_level_1
         client_level_2
         client_level_3 
   PATIENT_COUNT;
define    CLIENT_NM_ID     / group page
   "^S={font_weight=bold
        font_size  =10pt 
        just       =c}Client^S={}"
   style=[cellwidth  =2.50in
          font_weight=medium
          just=l];
define client_level_1    / group
   "^S={font_weight=bold
        font_size  =10pt 
        just       =c}Client^nLevel 1^S={}"
   style=[cellwidth  =1.00in
          font_weight=medium
          just=l];
define client_level_2            / group
   "^S={font_weight=bold
        font_size  =10pt 
        just       =c}Client^nLevel 2^S={}"
   style=[cellwidth  =1.00in
          font_weight=medium
          just=l];
define client_level_3            / group
   "^S={font_weight=bold
        font_size  =10pt 
        just       =c}Client^nLevel 3^S={}"
   style=[cellwidth  =1.00in
          font_weight=medium
          just=l]; 
define PATIENT_COUNT       / analysis sum format=comma9.
   "^S={font_weight=bold
        font_size  =10pt 
        just       =c}Patients^S={}"
   style=[cellwidth  =0.75in
          font_weight=medium
          just       =r
          posttext   ="^S={}^_^_^_^_^S={}"];
break after CLIENT_NM_ID   / suppress page;
compute after CLIENT_NM_ID /
   style=[
          font_size  =10pt
          font_weight=bold
          font_style =roman 
          just       =l];
   line "^S={just=r}Client Total^_^_^_^_^_^_^S={}"
        PATIENT_COUNT.sum "^S={}^_^_^_^S={}";
endcomp;
run;


quit;
ods rtf close;
ods listing;

%mend gstp_expanded_client_count;


*SASDOC-------------------------------------------------------------------------
| Call Report formatting macro. - November 2006 - N.Williams 
+-----------------------------------------------------------------------SASDOC*;
filename RPTFL "/herc&sysmode./data/hercules/5295/&RPT_FILE_NM..rtf";
filename RPTFL FTP  "\users\patientlist\&ops_subdir.\Reports\&RPT_FILE_NM..rtf"
         mach='sfb006.psd.caremark.int' RECFM=S; 

%gstp_expanded_client_count(dataset=&PPT_DATASET.);


*SASDOC-------------------------------------------------------------------------
| Update the job complete timestamp.
+-----------------------------------------------------------------------SASDOC*;
%update_request_ts(complete);

filename mymail email 'qcpap020@prdsas1';

data _null_;
   file mymail
       to=(&Primary_programmer_email.)
       subject='GSTP Expanded Clients Count Report' ;
   put 'Hi, All:' ;
   put / "This is an automatically generated message to inform you that the report for GSTP Program has been generated.";
   put / "\\sfb006\PatientList\&ops_subdir.\Reports\&RPT_FILE_NM..rtf"; 
   put / 'Please let us know if you have any questions.';
   put / 'Thanks,';
   put / 'HERCULES Production Support';
 run;
 quit;
