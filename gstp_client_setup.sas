
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  gstp_client_setup.sas
|
| LOCATION: /PRG/sas&sysmode.1/hercules/reporting
|
| PURPOSE:  Used to produce a list of the client setup
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

/** for testing**/
/*options sysparm='INITIATIVE_ID=5584 PHASE_SEQ_NB=1';*/
/*%let REQUEST_ID=101325;*/


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
%let RPT_FILE_NM=%str(Program_GSTP_Client_Setup_&reportdate.);

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

%macro gstp_client_setup;
	
PROC SQL;
CREATE TABLE GSTP_PLR_CLIENT_SETUP_QL AS 
SELECT 
	A.OVR_CLIENT_NM AS GSTP_CLIENT_NAME, 
	put(A.CLIENT_ID,20.) AS LEVEL1, 
	A.BLG_REPORTING_CD, 
	A.PLAN_CD_TX AS LEVEL2, 
    A.PLAN_EXT_CD_TX,
	A.GROUP_CD_TX AS LEVEL3,
    A.GROUP_EXT_CD_TX,
	A.EFFECTIVE_DT, 
	A.EXPIRATION_DT,
	(CASE WHEN A.GSTP_GSA_PGMTYP_CD = 1 THEN 'TGST'
		  WHEN A.GSTP_GSA_PGMTYP_CD = 2 THEN 'PGST' 
		  WHEN A.GSTP_GSA_PGMTYP_CD = 3 THEN 'HPGST' 
		  WHEN A.GSTP_GSA_PGMTYP_CD = 4 THEN 'CUSTOM' 
		  ELSE 'OTHER' END) AS GSTP_TYPE,
	B.DRG_CLS_CATG_TX, 
    'QL' AS PLATFORM
FROM HERCULES.TPGMTASK_QL_RUL A,
     HERCULES.TPMTSK_GSTP_QL_RUL B
WHERE  A.PROGRAM_ID = 5295
	AND A.TASK_ID = 57
	AND A.PROGRAM_ID = B.PROGRAM_ID
	AND A.TASK_ID = B.TASK_ID
	AND A.CLIENT_ID = B.CLIENT_ID
	AND A.BLG_REPORTING_CD = B.BLG_REPORTING_CD
	AND A.PLAN_CD_TX = B.PLAN_CD_TX
	AND A.PLAN_EXT_CD_TX = B.PLAN_EXT_CD_TX
	AND A.GROUP_CD_TX = B.GROUP_CD_TX
	AND A.GROUP_EXT_CD_TX = B.GROUP_EXT_CD_TX
	AND A.GSTP_GSA_PGMTYP_CD = B.GSTP_GSA_PGMTYP_CD
	AND A.EFFECTIVE_DT = B.CLT_EFF_DT

GROUP BY A.OVR_CLIENT_NM, A.CLIENT_ID,A.BLG_REPORTING_CD, A.PLAN_CD_TX,A.PLAN_EXT_CD_TX, A.GROUP_CD_TX,A.GROUP_EXT_CD_TX,
A.GSTP_GSA_PGMTYP_CD,A.EFFECTIVE_DT, A.EXPIRATION_DT,B.DRG_CLS_CATG_TX

ORDER BY A.OVR_CLIENT_NM, A.CLIENT_ID,A.BLG_REPORTING_CD, A.PLAN_CD_TX,A.PLAN_EXT_CD_TX, A.GROUP_CD_TX,A.GROUP_EXT_CD_TX,
A.GSTP_GSA_PGMTYP_CD,A.EFFECTIVE_DT, A.EXPIRATION_DT,B.DRG_CLS_CATG_TX;
QUIT;

PROC SQL;
CREATE TABLE GSTP_PLR_CLIENT_SETUP_RE AS 
SELECT 
	A.OVR_CLIENT_NM AS GSTP_CLIENT_NAME,
	A.INSURANCE_CD AS LEVEL1,
	A.CARRIER_ID AS LEVEL2,
	A.GROUP_CD AS LEVEL3,
	A.EFFECTIVE_DT, 
	A.EXPIRATION_DT,
	(CASE WHEN A.GSTP_GSA_PGMTYP_CD = 1 THEN 'TGST'
		  WHEN A.GSTP_GSA_PGMTYP_CD = 2 THEN 'PGST' 
		  WHEN A.GSTP_GSA_PGMTYP_CD = 3 THEN 'HPGST' 
		  WHEN A.GSTP_GSA_PGMTYP_CD = 4 THEN 'CUSTOM' 
		  ELSE 'OTHER' END) AS GSTP_TYPE,
	B.DRG_CLS_CATG_TX, 
	'RE' AS PLATFORM
FROM HERCULES.TPGMTASK_RECAP_RUL A,
     HERCULES.TPMTSK_GSTP_RP_RUL B
WHERE A.PROGRAM_ID = 5295
	AND A.TASK_ID = 57
	AND A.PROGRAM_ID = B.PROGRAM_ID
	AND A.TASK_ID = B.TASK_ID
	AND A.INSURANCE_CD = B.INSURANCE_CD
	AND A.CARRIER_ID = B.CARRIER_ID
	AND A.GROUP_CD = B.GROUP_CD
	AND A.GSTP_GSA_PGMTYP_CD = B.GSTP_GSA_PGMTYP_CD
	AND A.EFFECTIVE_DT = B.CLT_EFF_DT
ORDER BY A.OVR_CLIENT_NM,A.INSURANCE_CD,A.CARRIER_ID, A.GROUP_CD,
         B.DRG_CLS_CATG_TX, A.GSTP_GSA_PGMTYP_CD,A.EFFECTIVE_DT, A.EXPIRATION_DT;
QUIT;

PROC SQL;
CREATE TABLE GSTP_PLR_CLIENT_SETUP_RX AS 
SELECT 
	A.OVR_CLIENT_NM AS GSTP_CLIENT_NAME, 
	A.CARRIER_ID AS LEVEL1,
	A.ACCOUNT_ID AS LEVEL2,
	A.GROUP_CD AS LEVEL3,
	A.EFFECTIVE_DT, 
	A.EXPIRATION_DT,
	(CASE WHEN A.GSTP_GSA_PGMTYP_CD = 1 THEN 'TGST'
	      WHEN A.GSTP_GSA_PGMTYP_CD = 2 THEN 'PGST' 
		  WHEN A.GSTP_GSA_PGMTYP_CD = 3 THEN 'HPGST' 
		  WHEN A.GSTP_GSA_PGMTYP_CD = 4 THEN 'CUSTOM' 
		  ELSE 'OTHER' END) AS GSTP_TYPE,
	B.DRG_CLS_CATG_TX, 
	'RX' AS PLATFORM
FROM HERCULES.TPGMTASK_RXCLM_RUL A,
     HERCULES.TPMTSK_GSTP_RX_RUL B
WHERE A.PROGRAM_ID = 5295
	AND A.TASK_ID = 57
	AND A.PROGRAM_ID = B.PROGRAM_ID
	AND A.TASK_ID = B.TASK_ID
	AND A.ACCOUNT_ID = B.ACCOUNT_ID
	AND A.CARRIER_ID = B.CARRIER_ID
	AND A.GROUP_CD = B.GROUP_CD
	AND A.GSTP_GSA_PGMTYP_CD = B.GSTP_GSA_PGMTYP_CD
	AND A.EFFECTIVE_DT = B.CLT_EFF_DT

ORDER BY A.OVR_CLIENT_NM,A.CARRIER_ID,A.ACCOUNT_ID,A.GROUP_CD,
         A.EFFECTIVE_DT, A.EXPIRATION_DT,B.DRG_CLS_CATG_TX, A.GSTP_GSA_PGMTYP_CD;
QUIT;

data gstp_plr_client_setup_all ;
 set  gstp_plr_client_setup_rx gstp_plr_client_setup_re gstp_plr_client_setup_ql;
run;

*SASDOC-------------------------------------------------------------------------
| Produce a report of Clients Setup Report.
+-----------------------------------------------------------------------SASDOC*;
ods listing close;
ods html file =RPTFL ;
ods escapechar "^";
ods proclabel="Program GSTP - Clients Setup Report";
options nodate;  

title1 j=r " ";
title2 j=c "^S={font_size=12pt
                font_weight=bold}Hercules Communication Engine^S={}";
title3 j=c "^S={font_size=14pt
                font_weight=bold}Program GSTP - Client Setup Report^S={}";
title4 " ";

footnote1 j=r "^S={font_style =roman
                   font_size  =6pt
                   font_weight=bold}Caremark IT Analytics^S={}";
footnote2 j=r "^S={font_style =roman
                   font_size  =6pt
                   font_weight=bold}%sysfunc(today(),weekdate32.)^S={}";

proc report data = gstp_plr_client_setup_all split='*' nowd headline headskip
style(report)=[ borderwidth=1 background=black font_face="times" font_size=7pt just=center ] 
style(header)=[ borderwidth=1 background=#D3D3D3 foreground=black font_face="times" font_size=7pt just=center font_weight=bold ] 
style(column)=[ borderwidth=1 background=white font_face="times" font_size=7pt just=left] ;
column
PLATFORM  
GSTP_CLIENT_NAME 
LEVEL1
LEVEL2 
LEVEL3
BLG_REPORTING_CD  
PLAN_EXT_CD_TX 
GROUP_EXT_CD_TX
GSTP_TYPE
DRG_CLS_CATG_TX
EFFECTIVE_DT 
EXPIRATION_DT
;
define platform   / display "Platform"
   style=[cellwidth=0.60in
          font_weight=medium
          just=l]; 
define gstp_client_name   / display "GSTP Client Name"
   style=[cellwidth=1.50in
          font_weight=medium
          just=l];
define level1   / display "Client Level 1"
   style=[cellwidth=0.75in
          font_weight=medium
          just=l];
define level2   / display "Client Level 2"
   style=[cellwidth=0.75in
          font_weight=medium
          just=l];
define level3   / display "Client Level 3"
   style=[cellwidth=0.75in
          font_weight=medium
          just=l];
define BLG_REPORTING_CD   / display "Billing Rpt Code"
   style=[cellwidth=0.80in
          font_weight=medium
          just=l];
define PLAN_EXT_CD_TX   / display "Plan Ext Code"
   style=[cellwidth=0.75in
          font_weight=medium
          just=l];
define GROUP_EXT_CD_TX  / display "Group Ext Code"
   style=[cellwidth=0.75in
          font_weight=medium
          just=l];
define gstp_type   / display "GSTP Type"
   style=[cellwidth=0.60in
          font_weight=medium
          just=l];
define DRG_CLS_CATG_TX   / display "Drug Class Category"
   style=[cellwidth=1.00in
          font_weight=medium
          just=l];
define effective_dt  / display "Effective Date"
   style=[cellwidth=0.85in
          font_weight=medium
          just=l];
define expiration_dt  / display "Expiration Date"
   style=[cellwidth=0.85in
          font_weight=medium 
          just=l];

run;
quit;
ods html close;  

%mend gstp_client_setup;
%gstp_client_setup;

*SASDOC-------------------------------------------------------------------------
| Update the job complete timestamp.
+-----------------------------------------------------------------------SASDOC*;
%update_request_ts(complete);

filename mymail email 'qcpap020@prdsas1';

data _null_;
   file mymail
       to=(&Primary_programmer_email.)
       subject='GSTP Client Setup Report' ;
   put 'Hi, All:' ;
   put / "This is an automatically generated message to inform you that the client setup report for GSTP Program has been generated.";
   put / "\\sfb006\PatientList\&ops_subdir.\Reports\&RPT_FILE_NM..xls";
   put / 'Please let us know if you have any questions.';
   put / 'Thanks,';
   put / 'HERCULES Production Support';
 run;
 quit;

