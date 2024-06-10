
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  gstp_client_letter_count.sas
|
| LOCATION: /PRG/sas&sysmode.1/hercules/reporting
|
| PURPOSE:  Used to produce a list of the client letter count
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

/**%set_sysmode(mode=test);
options sysparm='INITIATIVE_ID=5584 PHASE_SEQ_NB=1';
%let REQUEST_ID=101329;
**/

%INCLUDE "/herc&sysmode./prg/hercules/reports/hercules_rpt_in.sas";
%INCLUDE "/herc%lowcase(&SYSMODE)/prg/hercules/reports/report_in.sas"; 

libname ADM_LKP "/herc%lowcase(&SYSMODE)/data/Admin/auxtable";
libname PEND "/herc%lowcase(&SYSMODE)/data/hercules/&_program_id./pending";

%let ERR_FL=0;
%let PROGRAM_NAME=gstp_client_letter_count;

%let PPT_DATASET=t_&REQUIRED_PARMTR_ID._1_1;
%let MD2_DATASET=t_&REQUIRED_PARMTR_ID._1_2;



%let _&REQUIRED_PARMTR_nm.=&REQUIRED_PARMTR_id;
%let _&SEC_REQD_PARMTR_nm.=&SEC_REQD_PARMTR_id;
%let table_prefix=R_&REQUEST_ID;
%let RPT_FILE_NM_PPT=%str(Program_GSTP_Client_Letter_Count_PPT_&REQUIRED_PARMTR_ID.);
%let RPT_FILE_NM_MD2=%str(Program_GSTP_Client_Letter_Count_MD2_&REQUIRED_PARMTR_ID.);


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


*SASDOC-------------------------------------------------------------------------
| Update the job start timestamp.
+-----------------------------------------------------------------------SASDOC*;
%update_request_ts(start);


%macro gstp_client_count(dataset=,prefix=);

%LET HIERARCHY_CONS = %STR( AND (RULE.GROUP_CLASS_CD = 0 OR
CPG.GROUP_CLASS_CD = RULE.GROUP_CLASS_CD) 
AND (RULE.BLG_REPORTING_CD = ' ' OR
UPCASE(LEFT(TRIM(RULE.BLG_REPORTING_CD))) = UPCASE(LEFT(TRIM(CPG.BLG_REPORTING_CD))))
AND (RULE.PLAN_CD_TX = ' ' OR
UPCASE(LEFT(TRIM(RULE.PLAN_CD_TX))) = UPCASE(LEFT(TRIM(CPG.PLAN_CD))))
AND (RULE.PLAN_EXT_CD_TX = ' ' OR 
UPCASE(LEFT(TRIM(RULE.PLAN_EXT_CD_TX))) = UPCASE(LEFT(TRIM(CPG.PLAN_EXT_CD_TX))))
AND (RULE.GROUP_CD_TX = ' ' OR
UPCASE(LEFT(TRIM(RULE.GROUP_CD_TX))) = UPCASE(LEFT(TRIM(CPG.GROUP_CD))))
AND (RULE.GROUP_EXT_CD_TX = ' ' OR 
UPCASE(LEFT(TRIM(RULE.GROUP_EXT_CD_TX))) = UPCASE(LEFT(TRIM(CPG.GROUP_EXT_CD_TX))))
AND (RULE.PLAN_NM = ' ' OR 
UPCASE(LEFT(TRIM(RULE.PLAN_NM))) = UPCASE(LEFT(TRIM(CPG.PLAN_NM)))) );

proc sql;
create table TPGMTASK_QL_RUL as
select *
from HERCULES.TPGMTASK_QL_RUL a
where a.program_id=5295
  and expiration_dt > today();**
  and effective_dt < today();
quit;

proc sort data = TPGMTASK_QL_RUL ;
by BLG_REPORTING_CD	
CLIENT_ID 		
CLT_SETUP_DEF_CD  	
GROUP_CD_TX 		
GROUP_CLASS_CD 	
GROUP_CLASS_SEQ_NB 
GROUP_EXT_CD_TX 	
GSTP_GSA_PGMTYP_CD 
PLAN_CD_TX 		
PLAN_EXT_CD_TX 	
PLAN_NM  	
PROGRAM_ID 		
TASK_ID descending effective_dt;		
run;

proc sort data = TPGMTASK_QL_RUL nodupkey;
by BLG_REPORTING_CD	
CLIENT_ID 		
CLT_SETUP_DEF_CD  	
GROUP_CD_TX 		
GROUP_CLASS_CD 	
GROUP_CLASS_SEQ_NB 
GROUP_EXT_CD_TX 	
GSTP_GSA_PGMTYP_CD 
PLAN_CD_TX 		
PLAN_EXT_CD_TX 	
PLAN_NM  	
PROGRAM_ID 		
TASK_ID ;		
run;

proc sql;
create table client_letter_ql as
select            trim(left(CPG.CLIENT_NM))
          ||' ('||trim(left(put(CPG.CLIENT_ID,32.)))||')'
             as CLIENT_NM_ID,
	cpg.apn_cmctn_id,
	(CASE WHEN GSTP_GSA_PGMTYP_CD = 1 THEN 'TGST'
	WHEN GSTP_GSA_PGMTYP_CD = 2 THEN 'PGST' 
	WHEN GSTP_GSA_PGMTYP_CD = 3 THEN 'HPGST' 
	WHEN GSTP_GSA_PGMTYP_CD = 4 THEN 'CUSTOM' 
	ELSE 'OTHER' END) AS GSTP_TYPE,   
	count(*) as number_letters,
	count(distinct(RECIPIENT_ID)) as number_subjects
from pend.&dataset. CPG left join
     TPGMTASK_QL_RUL RULE  
on  RULE.PROGRAM_ID = 5295
	AND RULE.TASK_ID = 57
	AND ADJ_ENGINE = 'QL'
	AND RULE.PROGRAM_ID = cpg.PROGRAM_ID
	AND RULE.TASK_ID = cpg.TASK_ID
	AND RULE.CLIENT_ID = cpg.CLIENT_ID
    &HIERARCHY_CONS.
    and cpg.data_quality_cd=1 
group by cpg.client_id, cpg.client_nm, cpg.apn_cmctn_id, gstp_type;
quit;

proc sql;
create table TPGMTASK_RECAP_RUL as
select *
from HERCULES.TPGMTASK_RECAP_RUL a
where a.program_id=5295
  and expiration_dt > today();**
  and effective_dt < today();
quit;

proc sort data = TPGMTASK_RECAP_RUL ;
by carrier_id carrier_id group_cd descending effective_dt;		
run;

proc sort data = TPGMTASK_RECAP_RUL nodupkey;
by carrier_id carrier_id group_cd ;		
run;

%LET HIERARCHY_CONS = %STR( 
AND (RULE.CARRIER_ID = ' ' OR RULE.CARRIER_ID IS NULL OR
UPPER(TRIM(substr(RULE.CARRIER_ID,2))) = UPPER(TRIM(CPG.client_level_2)))
AND (RULE.GROUP_CD = ' ' OR RULE.GROUP_CD IS NULL OR
UPPER(TRIM(RULE.GROUP_CD)) = UPPER(TRIM(CPG.client_level_3)))
);

proc sql;
create table client_letter_re as
select  
    cpg.client_nm as CLIENT_NM_ID, 
	cpg.apn_cmctn_id,
	(CASE WHEN GSTP_GSA_PGMTYP_CD = 1 THEN 'TGST'
	WHEN GSTP_GSA_PGMTYP_CD = 2 THEN 'PGST' 
	WHEN GSTP_GSA_PGMTYP_CD = 3 THEN 'HPGST' 
	WHEN GSTP_GSA_PGMTYP_CD = 4 THEN 'CUSTOM' 
	ELSE 'OTHER' END) AS GSTP_TYPE,   
	count(*) as number_letters,
	count(distinct(RECIPIENT_ID)) as number_subjects
from pend.&dataset. CPG left join
     TPGMTASK_RECAP_RUL RULE  
on  RULE.PROGRAM_ID = 5295
	AND RULE.TASK_ID = 57
	AND ADJ_ENGINE = 'RE'
	AND RULE.PROGRAM_ID = cpg.PROGRAM_ID
	AND RULE.TASK_ID = cpg.TASK_ID
	AND UPPER(TRIM(RULE.INSURANCE_CD)) = UPPER(TRIM(CPG.client_level_1))
    &HIERARCHY_CONS.
    and cpg.data_quality_cd=1 
group by cpg.client_id, cpg.client_nm, cpg.apn_cmctn_id, gstp_type;
quit;

proc sql;
create table TPGMTASK_RXCLM_RUL as
select *
from HERCULES.TPGMTASK_RXCLM_RUL a
where a.program_id=5295
  and expiration_dt > today();**
  and effective_dt < today();
quit;

proc sort data = TPGMTASK_RXCLM_RUL ;
by carrier_id carrier_id group_cd descending effective_dt;		
run;

proc sort data = TPGMTASK_RXCLM_RUL nodupkey;
by carrier_id carrier_id group_cd ;		
run;

%LET HIERARCHY_CONS = %STR( 
AND (RULE.account_ID = ' ' OR RULE.account_ID IS NULL OR
UPPER(TRIM(RULE.account_ID)) = UPPER(TRIM(CPG.client_level_2)))
AND (RULE.GROUP_CD = ' ' OR RULE.GROUP_CD IS NULL OR
UPPER(TRIM(RULE.GROUP_CD)) = UPPER(TRIM(CPG.client_level_3)))
);


proc sql;
create table client_letter_rx as
select  
    cpg.client_nm as CLIENT_NM_ID, 
	cpg.apn_cmctn_id,
	(CASE WHEN GSTP_GSA_PGMTYP_CD = 1 THEN 'TGST'
	WHEN GSTP_GSA_PGMTYP_CD = 2 THEN 'PGST' 
	WHEN GSTP_GSA_PGMTYP_CD = 3 THEN 'HPGST' 
	WHEN GSTP_GSA_PGMTYP_CD = 4 THEN 'CUSTOM' 
	ELSE 'OTHER' END) AS GSTP_TYPE,   
	count(*) as number_letters,
	count(distinct(RECIPIENT_ID)) as number_subjects
from pend.&dataset. CPG left join
     TPGMTASK_RXCLM_RUL RULE  
on  RULE.PROGRAM_ID = 5295
	AND RULE.TASK_ID = 57
	AND ADJ_ENGINE = 'RX'
	AND RULE.PROGRAM_ID = cpg.PROGRAM_ID
	AND RULE.TASK_ID = cpg.TASK_ID
	AND UPPER(TRIM(substr(RULE.carrier_ID,2))) = UPPER(TRIM(CPG.client_level_1))
    &HIERARCHY_CONS.
    and cpg.data_quality_cd=1 
group by cpg.client_id, cpg.client_nm, cpg.apn_cmctn_id, gstp_type;
quit;

data client_letter_ppt;
 set client_letter_ql
     client_letter_re
	 client_letter_rx;
run; 

ods listing close;
ods pdf file =RPTFL
        startpage=off 
        notoc ;
ods escapechar "^";
options nodate; 
OPTIONS  NOCENTER  ORIENTATION = LANDSCAPE ;

title1 j=r " ";
title2 j=c "^S={font_size=12pt
                font_weight=bold}Hercules Communication Engine^S={}";
title3 j=c "^S={font_size=14pt
                font_weight=bold}Program GSTP - Client Letter Count Report^S={}";
title4 j=c "^S={font_size=12pt
                font_weight=bold}Initiative ID = &REQUIRED_PARMTR_ID. ^S={}";
title5 " ";
footnote1 j=r "^S={font_style =roman
                   font_size  =6pt
                   font_weight=bold}Caremark IT Analytics^S={}";
footnote2 j=r "^S={font_style =roman
                   font_size  =6pt
                   font_weight=bold}%sysfunc(today(),weekdate32.)^S={}";

*SASDOC-------------------------------------------------------------------------
| Produce a report of Drug Count Report.
+-----------------------------------------------------------------------SASDOC*;
ods proclabel="Program GSTP - Client Letter Count Report";
 
proc report data = client_letter_ppt split='*' nowd headline headskip
style(report)=[ borderwidth=1 background=black font_face="times" font_size=7pt just=center ] 
style(header)=[ borderwidth=1 background=#D3D3D3 foreground=black font_face="times" font_size=7pt just=center font_weight=bold ] 
style(column)=[ borderwidth=1 background=white font_face="times" font_size=7pt just=left] ;
column
CLIENT_NM_ID
gstp_type 
apn_cmctn_id
number_letters
number_subjects 
; 
define CLIENT_NM_ID   / display "Client Name"
   style=[cellwidth=3.50in
          font_weight=medium
          just=l]; 
define gstp_type   / display "GSTP Type"
   style=[cellwidth=1.00in
          font_weight=medium
          just=l]; 
define apn_cmctn_id   / display "APN_CMCTN_ID"
   style=[cellwidth=1.00in
          font_weight=medium
          just=l]; 
define number_letters  / display "Number-Letters"
   style=[cellwidth=1.00in
          font_weight=medium
          just=c];
define number_subjects  / display "Number-Subjects"
   style=[cellwidth=1.00in
          font_weight=medium 
          just=c];

run;
quit;
ods pdf close; 
ods listing;

%mend gstp_client_count;


*SASDOC-------------------------------------------------------------------------
| Call Report formatting macro. - November 2006 - N.Williams 
+-----------------------------------------------------------------------SASDOC*;

filename RPTFL "/herc&sysmode./data/hercules/5295/&RPT_FILE_NM_PPT..pdf";
filename RPTFL FTP  "\users\patientlist\&ops_subdir.\Reports\&RPT_FILE_NM_PPT..pdf"
         mach='sfb006.psd.caremark.int' RECFM=S;
%gstp_client_count(dataset=&ppt_dataset., prefix=ppt);

filename RPTFL "/herc&sysmode.1/data/hercules/5295/&RPT_FILE_NM_MD2..pdf";
filename RPTFL FTP  "\users\patientlist\&ops_subdir.\Reports\&RPT_FILE_NM_MD2..pdf"
         mach='sfb006.psd.caremark.int' RECFM=S;
%gstp_client_count(dataset=&md2_dataset., prefix=md2); 

*SASDOC-------------------------------------------------------------------------
| Update the job complete timestamp.
+-----------------------------------------------------------------------SASDOC*;
%update_request_ts(complete);

/**&EMAIL_USR_rpt**/

filename mymail email 'qcpap020@prdsas1';

data _null_;
   file mymail
       to=(&Primary_programmer_email.)
       subject='GSTP Client Letter Count Report' ;
   put 'Hi, All:' ;
   put / "This is an automatically generated message to inform you that the report for GSTP Program has been generated.";
   put / "\\sfb006\PatientList\&ops_subdir.\Reports\&RPT_FILE_NM_PPT..pdf";
   put / "\\sfb006\PatientList\&ops_subdir.\Reports\&RPT_FILE_NM_MD2..pdf";
   put / 'Please let us know if you have any questions.';
   put / 'Thanks,';
   put / 'HERCULES Production Support';
 run;
 quit;
