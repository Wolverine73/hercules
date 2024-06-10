
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  gstp_drug_setup.sas
|
| LOCATION: /PRG/sas&sysmode.1/hercules/reporting
|
| PURPOSE:  Used to produce a list of the drug setup
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

/** for testing
options sysparm='INITIATIVE_ID=5583 PHASE_SEQ_NB=1';
%let REQUEST_ID=101327;
**/

%INCLUDE "/herc&sysmode./prg/hercules/reports/hercules_rpt_in.sas";
%INCLUDE "/herc%lowcase(&SYSMODE)/prg/hercules/reports/report_in.sas"; 

libname ADM_LKP "/herc%lowcase(&SYSMODE)/data/Admin/auxtable";

%let ERR_FL=0;
%let PROGRAM_NAME=gstp_client_setup;

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

data _null_;
 length reportdate $8 ;
 date=put(today(),yymmdd10.);
 y1=SCAN(date,1,'-');
 m1=SCAN(date,2,'-');
 d1=SCAN(date,3,'-');
 reportdate=trim(left(y1))||trim(left(m1))||trim(left(m1));
 call symput('reportdate', trim(reportdate));
run;

%let _&REQUIRED_PARMTR_nm.=&REQUIRED_PARMTR_id;
%let _&SEC_REQD_PARMTR_nm.=&SEC_REQD_PARMTR_id;
%let table_prefix=R_&REQUEST_ID;
%let RPT_FILE_NM=%str(Program_GSTP_Drug_Setup_&reportdate.);

%put NOTE: _&REQUIRED_PARMTR_nm.=&REQUIRED_PARMTR_id;
%put NOTE: _&SEC_REQD_PARMTR_nm.=&SEC_REQD_PARMTR_id;
%put NOTE: TABLE_PREFIX=&TABLE_PREFIX;
%put NOTE: &ops_subdir;  /** 5295 57 GSTP = Patientlist - HPFPD **/
%put NOTE: reportdate = &reportdate. ;
%put NOTE: Primary_programmer_email = &Primary_programmer_email. ;

filename RPTFL "/herc&sysmode./data/hercules/5295/&RPT_FILE_NM..xls";
 
filename RPTFL FTP
   "\users\patientlist\&ops_subdir.\Reports\&RPT_FILE_NM..xls"
   mach='sfb006.psd.caremark.int' RECFM=S;



%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for report request id &request_id");

*SASDOC-------------------------------------------------------------------------
| Update the job start timestamp.
+-----------------------------------------------------------------------SASDOC*;
%update_request_ts(start);

*SASDOC-----------------------------------------------------------------------
| Assign macro variable for report path (used in footnote1).
+----------------------------------------------------------------------SASDOC*;
%let RPT_PATH=%sysfunc(pathname(RPTFL));
%PUT RPT_PATH=&RPT_PATH;

%macro gstp_drug_setup;

PROC SQL;
CREATE TABLE GSTP_PLR_DRUG_SETUP AS
SELECT 
	(CASE WHEN D.GSTP_GSA_PGMTYP_CD = 1 THEN 'TGST'
		WHEN D.GSTP_GSA_PGMTYP_CD = 2 THEN 'PGST' 
		WHEN D.GSTP_GSA_PGMTYP_CD = 3 THEN 'HPGST' 
		WHEN D.GSTP_GSA_PGMTYP_CD = 4 THEN 'CUSTOM' 
		ELSE 'OTHER' END) AS GSTP_TYPE,
	A.DRG_CLS_CATG_TX,
	A.DRG_CLS_CAT_DES_TX,
	D.DRG_CLS_SEQ_NB,
	(CASE WHEN D.DRG_DTW_CD = 1 THEN 'TARGET' 
	       WHEN D.DRG_DTW_CD = 2 THEN 'PREREQUISITE' 
				 ELSE 'OTHER' END) AS DRUG_TYPE,
	D.DRG_LABEL_NM,
	D.GSTP_GPI_NM,
	D.GSTP_GPI_CD,
	D.GSTP_GCN_CD,
	D.GSTP_DRG_NDC_ID,
	D.QL_BRND_IN,
	D.MULTI_SRC_IN,
	A.DRG_CLS_EFF_DT,
	A.DRG_CLS_EXP_DT,
	D.DRG_EFF_DT,
	D.DRG_EXP_DT
FROM HERCULES.TGSTP_DRG_CLS_DET D,
     HERCULES.TGSTP_DRG_CLS A
WHERE A.DRG_CLS_SEQ_NB = D.DRG_CLS_SEQ_NB 
	AND A.DRG_CLS_EFF_DT = D.DRG_CLS_EFF_DT
	AND A.GSTP_GSA_PGMTYP_CD = D.GSTP_GSA_PGMTYP_CD
	AND A.PROGRAM_ID = 5295
	AND A.TASK_ID = 57
GROUP BY
	D.GSTP_GSA_PGMTYP_CD,
	D.DRG_DTW_CD,
	A.DRG_CLS_CATG_TX,
	A.DRG_CLS_CAT_DES_TX,
	D.DRG_CLS_SEQ_NB,
	D.GSTP_GPI_NM,
	D.GSTP_GPI_CD,
	D.GSTP_GCN_CD,
	D.GSTP_DRG_NDC_ID,
	D.QL_BRND_IN,
	D.MULTI_SRC_IN,
	D.DRG_LABEL_NM,
	A.DRG_CLS_EFF_DT,
	A.DRG_CLS_EXP_DT,
	D.DRG_EFF_DT,
	D.DRG_EXP_DT
ORDER BY
	D.GSTP_GSA_PGMTYP_CD,
	D.DRG_CLS_SEQ_NB,
	A.DRG_CLS_CATG_TX,
	A.DRG_CLS_CAT_DES_TX,
	D.DRG_DTW_CD,
	D.GSTP_GPI_NM,
	D.GSTP_GPI_CD,
	D.GSTP_GCN_CD,
	D.GSTP_DRG_NDC_ID,
	D.QL_BRND_IN,
	D.MULTI_SRC_IN,
	D.DRG_LABEL_NM,
	A.DRG_CLS_EFF_DT,
	A.DRG_CLS_EXP_DT,
	D.DRG_EFF_DT,
	D.DRG_EXP_DT ;
QUIT;

*SASDOC-------------------------------------------------------------------------
| Produce a report of Drug Setup Report.
+-----------------------------------------------------------------------SASDOC*;
ods listing close;
ods html file =RPTFL ;
ods escapechar "^";
ods proclabel="Program GSTP - Drug Setup Report";
options nodate;

title1 j=r " ";
title2 j=c "^S={font_size=12pt
                font_weight=bold}Hercules Communication Engine^S={}";
title3 j=c "^S={font_size=14pt
                font_weight=bold}Program GSTP - Drug Setup Report^S={}";
title4 " ";

footnote1 j=r "^S={font_style =roman
                   font_size  =6pt
                   font_weight=bold}Caremark IT Analytics^S={}";
footnote2 j=r "^S={font_style =roman
                   font_size  =6pt
                   font_weight=bold}%sysfunc(today(),weekdate32.)^S={}";

proc report data = GSTP_PLR_DRUG_SETUP split='*' nowd headline headskip
style(report)=[ borderwidth=1 background=black font_face="times" font_size=8pt just=center ] 
style(header)=[ borderwidth=1 background=#D3D3D3 foreground=black font_face="times" font_size=8pt just=center font_weight=bold ] 
style(column)=[ borderwidth=1 background=white font_face="times" font_size=8pt just=left] ;
column

GSTP_TYPE
drg_cls_catg_tx
drg_cls_cat_des_tx
DRG_CLS_SEQ_NB
Drug_Type
DRG_LABEL_NM
GSTP_GPI_NM
GSTP_GPI_CD
GSTP_GCN_CD
GSTP_DRG_NDC_ID
QL_BRND_IN
MULTI_SRC_IN
DRG_CLS_EFF_DT
DRG_CLS_EXP_DT
DRG_EFF_DT
DRG_EXP_DT
;

define gstp_type   / display "Type"
   style=[cellwidth=0.40in
          font_weight=medium
          just=l];
define drg_cls_catg_tx   / display "Drug Class Text"
   style=[cellwidth=0.90in
          font_weight=medium
          just=l];
define drg_cls_cat_des_tx   / display "Drug Class Description"
   style=[cellwidth=2.00in
          font_weight=medium
          just=l];
define DRG_CLS_SEQ_NB   / display "Drug Class Seq Number"
   style=[cellwidth=0.50in
          font_weight=medium
          just=l];
define Drug_Type   / display "Drug Type"
   style=[cellwidth=0.60in
          font_weight=medium
          just=l];
define DRG_LABEL_NM   / display "Drug Label Name"
   style=[cellwidth=0.90in
          font_weight=medium
          just=l];
define GSTP_GPI_NM   / display "GPI Name"
   style=[cellwidth=1.50in
          font_weight=medium
          just=l];
define GSTP_GPI_CD   / display "GPI CD"
   style=[cellwidth=0.90in
          font_weight=medium
          just=l];
define GSTP_GCN_CD  / display "GCN Code"
   style=[cellwidth=0.40in
          font_weight=medium
          just=l];
define GSTP_DRG_NDC_ID   / display "NDC ID"
   style=[cellwidth=0.70in
          font_weight=medium
          just=l];
define QL_BRND_IN   / display "Brand IND"
   style=[cellwidth=0.50in
          font_weight=medium
          just=l];
define MULTI_SRC_IN   / display "Multi Source"
   style=[cellwidth=0.50in
          font_weight=medium
          just=l];
define DRG_CLS_EFF_DT   / display "Drug Class Eff Date"
   style=[cellwidth=0.70in
          font_weight=medium
          just=l];
define DRG_CLS_EXP_DT   / display "Drug Class Exp Date"
   style=[cellwidth=0.70in
          font_weight=medium
          just=l];
define DRG_EFF_DT  / display "Drug Eff Date"
   style=[cellwidth=0.70in
          font_weight=medium
          just=l];
define DRG_EXP_DT  / display "Drug Exp Date"
   style=[cellwidth=0.70in
          font_weight=medium 
          just=l];

run;

quit;
ods html close;  

%mend gstp_drug_setup;
%gstp_drug_setup;

*SASDOC-------------------------------------------------------------------------
| Update the job complete timestamp.
+-----------------------------------------------------------------------SASDOC*;
%update_request_ts(complete);

filename mymail email 'qcpap020@prdsas1';

data _null_;
   file mymail
       to=(&Primary_programmer_email.)
       subject='GSTP Drug Setup Report' ;
   put 'Hi, All:' ;
   put / "This is an automatically generated message to inform you that the drug setup report for GSTP Program has been generated.";
   put / "\\sfb006\PatientList\&ops_subdir.\Reports\&RPT_FILE_NM..xls";
   put / 'Please let us know if you have any questions.';
   put / 'Thanks,';
   put / 'HERCULES Production Support';
 run;
 quit;

