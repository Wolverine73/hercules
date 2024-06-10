
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  gstp_drug_count.sas
|
| LOCATION: /PRG/sas&sysmode.1/hercules/reporting
|
| PURPOSE:  Used to produce a list of the drug count
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
%let REQUEST_ID=101328;
**/

%INCLUDE "/herc&sysmode./prg/hercules/reports/hercules_rpt_in.sas";
%INCLUDE "/herc%lowcase(&SYSMODE)/prg/hercules/reports/report_in.sas"; 

libname ADM_LKP "/herc%lowcase(&SYSMODE)/data/Admin/auxtable";
libname PEND "/herc%lowcase(&SYSMODE)/data/hercules/&_program_id./pending";

%let ERR_FL=0;
%let PROGRAM_NAME=gstp_client_setup;

%let PPT_DATASET=t_&REQUIRED_PARMTR_ID._1_1;
%let MD2_DATASET=t_&REQUIRED_PARMTR_ID._1_2;


%let _&REQUIRED_PARMTR_nm.=&REQUIRED_PARMTR_id;
%let _&SEC_REQD_PARMTR_nm.=&SEC_REQD_PARMTR_id;
%let table_prefix=R_&REQUEST_ID;
%let RPT_FILE_NM=%str(Program_GSTP_Drug_Count_&REQUIRED_PARMTR_ID.);

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


%macro gstp_drug_count;


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
create table drug_count_ql as
select  
	(CASE WHEN GSTP_GSA_PGMTYP_CD = 1 THEN 'TGST'
	WHEN GSTP_GSA_PGMTYP_CD = 2 THEN 'PGST' 
	WHEN GSTP_GSA_PGMTYP_CD = 3 THEN 'HPGST' 
	WHEN GSTP_GSA_PGMTYP_CD = 4 THEN 'CUSTOM' 
	ELSE 'OTHER' END) AS GSTP_TYPE,
    DRG_CLS_CATG_DESC_TX as drug_class,
	DRG_CLS_CATG_TX as drug_name,
	DRUG_NDC_ID as ndc,
	GPI_THERA_CLS_CD as gpi, 
	(count(distinct RECIPIENT_ID)) as patients
from pend.&PPT_DATASET. CPG left join
     TPGMTASK_QL_RUL RULE  
on  RULE.PROGRAM_ID = 5295
	AND RULE.TASK_ID = 57
	AND RULE.PROGRAM_ID = cpg.PROGRAM_ID
	AND RULE.TASK_ID = cpg.TASK_ID
	AND RULE.CLIENT_ID = cpg.CLIENT_ID
    &HIERARCHY_CONS.
    and cpg.data_quality_cd=1 
group by gstp_type, cpg.DRG_CLS_CATG_DESC_TX, cpg.DRG_CLS_CATG_TX, DRUG_NDC_ID, GPI_THERA_CLS_CD;
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
create table drug_count_re as
select 
	(CASE WHEN GSTP_GSA_PGMTYP_CD = 1 THEN 'TGST'
	WHEN GSTP_GSA_PGMTYP_CD = 2 THEN 'PGST' 
	WHEN GSTP_GSA_PGMTYP_CD = 3 THEN 'HPGST' 
	WHEN GSTP_GSA_PGMTYP_CD = 4 THEN 'CUSTOM' 
	ELSE 'OTHER' END) AS GSTP_TYPE,
    DRG_CLS_CATG_DESC_TX as drug_class,
	DRG_CLS_CATG_TX as drug_name,
	DRUG_NDC_ID as ndc,
	GPI_THERA_CLS_CD as gpi, 
	count(*) as patients
from pend.&PPT_DATASET. CPG left join
     TPGMTASK_RECAP_RUL RULE  
on  RULE.PROGRAM_ID = 5295
	AND RULE.TASK_ID = 57
	AND ADJ_ENGINE = 'RE'
	AND RULE.PROGRAM_ID = cpg.PROGRAM_ID
	AND RULE.TASK_ID = cpg.TASK_ID
	AND UPPER(TRIM(RULE.INSURANCE_CD)) = UPPER(TRIM(CPG.client_level_1))
    &HIERARCHY_CONS.
    and cpg.data_quality_cd=1 
group by gstp_type, cpg.DRG_CLS_CATG_DESC_TX, cpg.DRG_CLS_CATG_TX, DRUG_NDC_ID, GPI_THERA_CLS_CD;
quit;

proc sql;
create table TPGMTASK_RXCLM_RUL as
select *
from HERCULES.TPGMTASK_RXCLM_RUL a
where a.program_id=5295
  and expiration_dt > today();
  *and effective_dt < today();
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
create table drug_count_rx as
select 
	(CASE WHEN GSTP_GSA_PGMTYP_CD = 1 THEN 'TGST'
	WHEN GSTP_GSA_PGMTYP_CD = 2 THEN 'PGST' 
	WHEN GSTP_GSA_PGMTYP_CD = 3 THEN 'HPGST' 
	WHEN GSTP_GSA_PGMTYP_CD = 4 THEN 'CUSTOM' 
	ELSE 'OTHER' END) AS GSTP_TYPE,
    DRG_CLS_CATG_DESC_TX as drug_class,
	DRG_CLS_CATG_TX as drug_name,
	DRUG_NDC_ID as ndc,
	GPI_THERA_CLS_CD as gpi, 
	count(*) as patients
from pend.&PPT_DATASET. CPG left join
     TPGMTASK_RXCLM_RUL RULE  
on  RULE.PROGRAM_ID = 5295
	AND RULE.TASK_ID = 57
	AND ADJ_ENGINE = 'RX'
	AND RULE.PROGRAM_ID = cpg.PROGRAM_ID
	AND RULE.TASK_ID = cpg.TASK_ID
	AND UPPER(TRIM(substr(RULE.carrier_ID,2))) = UPPER(TRIM(CPG.client_level_1))
    &HIERARCHY_CONS.
    and cpg.data_quality_cd=1 
group by gstp_type, cpg.DRG_CLS_CATG_DESC_TX, cpg.DRG_CLS_CATG_TX, DRUG_NDC_ID, GPI_THERA_CLS_CD;
quit;

data drug_count;
 set drug_count_ql
     drug_count_re
	 drug_count_rx;
run;

proc sql;
create table drug_count as
select 
	GSTP_TYPE,
    drug_class, 
    drug_name,
    ndc,
    gpi, 
	sum(patients) as patients
from drug_count  
group by gstp_type, drug_class, drug_name, ndc, gpi  ;
quit;

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
                font_weight=bold}Program GSTP - Drug Count Report^S={}";
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
ods proclabel="Program GSTP - Drug Count Report";
 
proc report data = drug_count split='*' nowd headline headskip
style(report)=[ borderwidth=1 background=black font_face="times" font_size=7pt just=center ] 
style(header)=[ borderwidth=1 background=#D3D3D3 foreground=black font_face="times" font_size=7pt just=center font_weight=bold ] 
style(column)=[ borderwidth=1 background=white font_face="times" font_size=7pt just=left] ;
column
gstp_type
drug_class
drug_name
ndc
gpi 
patients
;
define gstp_type   / display "GSTP Type"
   style=[cellwidth=0.60in
          font_weight=medium
          just=l]; 
define drug_class   / display "Therapeutic Category/Drug Class"
   style=[cellwidth=2.75in
          font_weight=medium
          just=l];  
define drug_name   / display "Drug Name"
   style=[cellwidth=1.50in
          font_weight=medium
          just=l]; 
define ndc   / display "NDC"
   style=[cellwidth=1.00in
          font_weight=medium
          just=l]; 
define gpi  / display "GPI"
   style=[cellwidth=0.85in
          font_weight=medium
          just=c];
define patients  / display "Patients"
   style=[cellwidth=0.60in
          font_weight=medium 
          just=c];

run;
quit;
ods pdf close; 
ods listing;

%mend gstp_drug_count;
*SASDOC-------------------------------------------------------------------------
| Call Report formatting macro. - November 2006 - N.Williams 
+-----------------------------------------------------------------------SASDOC*;

filename RPTFL "/herc&sysmode./data/hercules/5295/&RPT_FILE_NM..pdf";
filename RPTFL FTP  "\users\patientlist\&ops_subdir.\Reports\&RPT_FILE_NM..pdf"
         mach='sfb006.psd.caremark.int' RECFM=S;

%gstp_drug_count;

*SASDOC-------------------------------------------------------------------------
| Update the job complete timestamp.
+-----------------------------------------------------------------------SASDOC*;
%update_request_ts(complete);


filename mymail email 'qcpap020@prdsas1';

data _null_;
   file mymail
       to=(&Primary_programmer_email.)
       subject='GSTP Drug Count Report' ;
   put 'Hi, All:' ;
   put / "This is an automatically generated message to inform you that the report for GSTP Program has been generated.";
   put / "\\sfb006\PatientList\&ops_subdir.\Reports\&RPT_FILE_NM..pdf";
   put / 'Please let us know if you have any questions.';
   put / 'Thanks,';
   put / 'HERCULES Production Support';
 run;
 quit;
