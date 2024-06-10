
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  gstp_client_implement_setup.sas
|
| LOCATION: /PRG/sas&sysmode.1/hercules/reporting
|
| PURPOSE:  Used to produce a list of the client implement setup
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
options sysparm='INITIATIVE_ID=5582 PHASE_SEQ_NB=1';
%let REQUEST_ID=101326;
**/

%INCLUDE "/herc&sysmode./prg/hercules/reports/hercules_rpt_in.sas";
%INCLUDE "/herc%lowcase(&SYSMODE)/prg/hercules/reports/report_in.sas"; 

%put NOTE: /DATA/sas%lowcase(&SYSMODE)1/Admin/auxtable ;
libname ADM_LKP "/herc%lowcase(&SYSMODE)/data/Admin/auxtable";

%let ERR_FL=0;
%let PROGRAM_NAME=gstp_client_implement_setup;

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
%let RPT_FILE_NM=%str(Program_GSTP_Client_Implement_Setup_&reportdate.);

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

%macro gstp_client_implement_setup;	

PROC SQL;
CREATE TABLE GSTP_PLR_CLIENT_IMPLEMENT_SETUP AS 
SELECT 
PLATFORM, 
GSTP_CLIENT_NAME, 
CLIENT_ID, 
LEVEL1, 
LEVEL2, 
LEVEL3,
GSTP_TYPE,
EFFECTIVE_DT, 
EXPIRATION_DT
FROM
(
	SELECT 
	'QL' AS PLATFORM, 
	OVR_CLIENT_NM AS GSTP_CLIENT_NAME, 
	CLIENT_ID,
	' ' AS LEVEL1,
	' ' AS LEVEL2,
	' ' AS LEVEL3,
	(CASE WHEN GSTP_GSA_PGMTYP_CD = 1 THEN 'TGST'
		WHEN GSTP_GSA_PGMTYP_CD = 2 THEN 'PGST' 
		WHEN GSTP_GSA_PGMTYP_CD = 3 THEN 'HPGST' 
		WHEN GSTP_GSA_PGMTYP_CD = 4 THEN 'CUSTOM' 
		ELSE 'OTHER' END) AS GSTP_TYPE,
	EFFECTIVE_DT, EXPIRATION_DT
	FROM HERCULES.TPGMTASK_QL_RUL
	WHERE PROGRAM_ID = 5295
		AND TASK_ID = 57

	UNION ALL

	SELECT 
		'RX' AS PLATFORM, 
		OVR_CLIENT_NM AS GSTP_CLIENT_NAME, 
		0 AS CLIENT_ID,
		CARRIER_ID AS LEVEL1, 
		ACCOUNT_ID AS LEVEL2, 
		GROUP_CD AS LEVEL3,
		(CASE WHEN GSTP_GSA_PGMTYP_CD = 1 THEN 'TGST'
			WHEN GSTP_GSA_PGMTYP_CD = 2 THEN 'PGST' 
			WHEN GSTP_GSA_PGMTYP_CD = 3 THEN 'HPGST' 
			WHEN GSTP_GSA_PGMTYP_CD = 4 THEN 'CUSTOM' 
			ELSE 'OTHER' END) AS GSTP_TYPE,
		EFFECTIVE_DT, EXPIRATION_DT
	FROM HERCULES.TPGMTASK_RXCLM_RUL
	WHERE PROGRAM_ID = 5295
		AND TASK_ID = 57

	UNION ALL

	SELECT 
		'RE' AS PLATFORM, 
		OVR_CLIENT_NM AS GSTP_CLIENT_NAME, 
		0 AS CLIENT_ID,
		INSURANCE_CD AS LEVEL1, 
		CARRIER_ID AS LEVEL2, 
		GROUP_CD AS LEVEL3,
		(CASE WHEN GSTP_GSA_PGMTYP_CD = 1 THEN 'TGST'
			WHEN GSTP_GSA_PGMTYP_CD = 2 THEN 'PGST' 
			WHEN GSTP_GSA_PGMTYP_CD = 3 THEN 'HPGST' 
			WHEN GSTP_GSA_PGMTYP_CD = 4 THEN 'CUSTOM' 
			ELSE 'OTHER' END) AS GSTP_TYPE,
		EFFECTIVE_DT, 
		EXPIRATION_DT
	FROM HERCULES.TPGMTASK_RECAP_RUL
	WHERE PROGRAM_ID = 5295
		AND TASK_ID = 57	
) AS FULL_QRY

ORDER BY PLATFORM, GSTP_CLIENT_NAME, CLIENT_ID, LEVEL1, LEVEL2, LEVEL3,GSTP_TYPE,EFFECTIVE_DT, EXPIRATION_DT;
QUIT;

*SASDOC-------------------------------------------------------------------------
| Produce a report of Clients Implement Setup Report.
+-----------------------------------------------------------------------SASDOC*;
ods listing close;
ods html file =RPTFL ;
ods escapechar "^";
ods proclabel="Program GSTP - Client Implement Setup Report";
options nodate;  

title1 j=r " ";
title2 j=c "^S={font_size=12pt
                font_weight=bold}Hercules Communication Engine^S={}";
title3 j=c "^S={font_size=14pt
                font_weight=bold}Program GSTP - Client Implement Setup Report^S={}";
title4 " ";

footnote1 j=r "^S={font_style =roman
                   font_size  =6pt
                   font_weight=bold}Caremark IT Analytics^S={}";
footnote2 j=r "^S={font_style =roman
                   font_size  =6pt
                   font_weight=bold}%sysfunc(today(),weekdate32.)^S={}";

proc report data = GSTP_PLR_CLIENT_IMPLEMENT_SETUP split='*' nowd headline  
style(report)=[ borderwidth=1 background=black font_face="times" font_size=8pt just=center ] 
style(header)=[ borderwidth=1 background=#D3D3D3 foreground=black font_face="times" font_size=8pt just=center font_weight=bold ] 
style(column)=[ borderwidth=1 background=white font_face="times" font_size=8pt just=left] ;

column
PLATFORM 
CLIENT_ID
GSTP_CLIENT_NAME 
LEVEL1
LEVEL2 
LEVEL3
GSTP_TYPE
EFFECTIVE_DT 
EXPIRATION_DT
;

define platform   / display "Platform"
   style=[cellwidth=0.60in
          font_weight=medium
          just=l];
define client_id  / display "Client ID"
   style=[cellwidth=0.60in
          font_weight=medium
          just=l];
define gstp_client_name   / display "GSTP Client Name"
   style=[cellwidth=1.50in
          font_weight=medium
          just=l];
define level1   / display "Client Level 1"
   style=[cellwidth=0.70in
          font_weight=medium
          just=l];
define level2   / display "Client Level 2"
   style=[cellwidth=0.70in
          font_weight=medium
          just=l];
define level3   / display "Client Level 3"
   style=[cellwidth=0.70in
          font_weight=medium
          just=l];
define gstp_type   / display "GSTP Type"
   style=[cellwidth=0.60in
          font_weight=medium
          just=l];
define effective_dt  / display "Effective Date"
   style=[cellwidth=0.75in
          font_weight=medium
          just=l];
define expiration_dt  / display "Expiration Date"
   style=[cellwidth=0.75in
          font_weight=medium 
          just=l];

run;
quit;
ods html close;  

%mend gstp_client_implement_setup;
%gstp_client_implement_setup;

*SASDOC-------------------------------------------------------------------------
| Update the job complete timestamp.
+-----------------------------------------------------------------------SASDOC*;
%update_request_ts(complete);


filename mymail email 'qcpap020@prdsas1';

data _null_;
   file mymail
       to=(&Primary_programmer_email.)
       subject='GSTP Client Implement Setup Report' ; 
   put 'Hi, All:' ;
   put / "This is an automatically generated message to inform you that the client implement setup report for GSTP Program has been generated.";
   put / "\\sfb006\PatientList\&ops_subdir.\Reports\&RPT_FILE_NM..xls";
   put / 'Please let us know if you have any questions.';
   put / 'Thanks,';
   put / 'HERCULES Production Support';
 run;
 quit;

