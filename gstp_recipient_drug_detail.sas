
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  gstp_recipient_drug_detail.sas
|
| LOCATION: /PRG/sas&sysmode.1/hercules/reporting
|
| PURPOSE:  Used to produce a list of the recipient drug detail
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
%let REQUEST_ID=101330;
**/


%INCLUDE "/herc&sysmode./prg/hercules/reports/hercules_rpt_in.sas";
%INCLUDE "/herc%lowcase(&SYSMODE)/prg/hercules/reports/report_in.sas"; 

libname ADM_LKP "/herc%lowcase(&SYSMODE)/data/Admin/auxtable";
libname PEND "/herc%lowcase(&SYSMODE)/data/hercules/&_program_id./pending";

%let ERR_FL=0;
%let PROGRAM_NAME=gstp_client_setup;

%let PPT_DATASET=t_&REQUIRED_PARMTR_ID._1_1;
%let MD2_DATASET=t_&REQUIRED_PARMTR_ID._1_2;

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
%let RPT_FILE_NM=%str(Program_GSTP_Recipient_Drug_Detail_&REQUIRED_PARMTR_ID.);

%put NOTE: _&REQUIRED_PARMTR_nm.=&REQUIRED_PARMTR_id;
%put NOTE: _&SEC_REQD_PARMTR_nm.=&SEC_REQD_PARMTR_id;
%put NOTE: TABLE_PREFIX=&TABLE_PREFIX;
%put NOTE: &ops_subdir;  /** 5295 57 GSTP = Patientlist - HPFPD **/
%put NOTE: reportdate = &reportdate. ;
%put NOTE: Primary_programmer_email = &Primary_programmer_email. ;
 
%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for report request id &request_id");

*SASDOC-------------------------------------------------------------------------
| Update the job start timestamp.
+-----------------------------------------------------------------------SASDOC*;
%update_request_ts(start);


%macro gstp_recipient_drug_detail;
	

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
create table recipient_list_ql as
select  
	(CASE WHEN GSTP_GSA_PGMTYP_CD = 1 THEN 'TGST'
	WHEN GSTP_GSA_PGMTYP_CD = 2 THEN 'PGST' 
	WHEN GSTP_GSA_PGMTYP_CD = 3 THEN 'HPGST' 
	WHEN GSTP_GSA_PGMTYP_CD = 4 THEN 'CUSTOM' 
	ELSE 'OTHER' END) AS GSTP_TYPE,
	ADJ_ENGINE,
	RECIPIENT_ID,
	APN_CMCTN_ID,
	MBR_ID as PT_EXTERNAL_ID,
	' '  as RECIPIENT_TYPE,
	RVR_LAST_NM,
	RVR_FIRST_NM,
	ADDRESS1_TX,
	ADDRESS2_TX,
	STATE_CD,
	CITY_TX,
	ZIP_CD,
	INITIATIVE_ID,
	CDH_EXTERNAL_ID,
	CPG.CLIENT_ID,
	client_level_1 as INSURANCE_CD,
	client_level_2 as CARRIER_ID,
	client_level_3 as ACCOUNT_ID,
	GROUP_CD,
    DRG_CLS_CATG_DESC_TX as drug_class,
	DRG_CLS_CATG_TX as drug_name,
	DRUG_NDC_ID as ndc,
	GPI_THERA_CLS_CD as gpi 
from pend.&ppt_dataset. CPG left join
     TPGMTASK_QL_RUL RULE  
on  RULE.PROGRAM_ID = 5295
	AND RULE.TASK_ID = 57
	AND ADJ_ENGINE = 'QL'
	AND RULE.PROGRAM_ID = cpg.PROGRAM_ID
	AND RULE.TASK_ID = cpg.TASK_ID
	AND RULE.CLIENT_ID = cpg.CLIENT_ID
    &HIERARCHY_CONS.
    and cpg.data_quality_cd=1;
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
create table recipient_list_re as
select  
	(CASE WHEN GSTP_GSA_PGMTYP_CD = 1 THEN 'TGST'
	WHEN GSTP_GSA_PGMTYP_CD = 2 THEN 'PGST' 
	WHEN GSTP_GSA_PGMTYP_CD = 3 THEN 'HPGST' 
	WHEN GSTP_GSA_PGMTYP_CD = 4 THEN 'CUSTOM' 
	ELSE 'OTHER' END) AS GSTP_TYPE,
	ADJ_ENGINE,
	RECIPIENT_ID,
	APN_CMCTN_ID,
	MBR_ID as PT_EXTERNAL_ID,
	' '  as RECIPIENT_TYPE,
	RVR_LAST_NM,
	RVR_FIRST_NM,
	ADDRESS1_TX,
	ADDRESS2_TX,
	STATE_CD,
	CITY_TX,
	ZIP_CD,
	INITIATIVE_ID,
	CDH_EXTERNAL_ID,
	CPG.CLIENT_ID,
	client_level_1 as INSURANCE_CD,
	client_level_2 as CARRIER_ID,
	client_level_3 as ACCOUNT_ID,
	CPG.GROUP_CD,
    DRG_CLS_CATG_DESC_TX as drug_class,
	DRG_CLS_CATG_TX as drug_name,
	DRUG_NDC_ID as ndc,
	GPI_THERA_CLS_CD as gpi 
from pend.&ppt_dataset. CPG left join
     TPGMTASK_RECAP_RUL RULE  
on  RULE.PROGRAM_ID = 5295
	AND RULE.TASK_ID = 57
	AND ADJ_ENGINE = 'RE'
	AND RULE.PROGRAM_ID = cpg.PROGRAM_ID
	AND RULE.TASK_ID = cpg.TASK_ID
	AND UPPER(TRIM(RULE.INSURANCE_CD)) = UPPER(TRIM(CPG.client_level_1))
    &HIERARCHY_CONS.
    and cpg.data_quality_cd=1 ;
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
create table recipient_list_rx as
select  
	(CASE WHEN GSTP_GSA_PGMTYP_CD = 1 THEN 'TGST'
	WHEN GSTP_GSA_PGMTYP_CD = 2 THEN 'PGST' 
	WHEN GSTP_GSA_PGMTYP_CD = 3 THEN 'HPGST' 
	WHEN GSTP_GSA_PGMTYP_CD = 4 THEN 'CUSTOM' 
	ELSE 'OTHER' END) AS GSTP_TYPE,
	ADJ_ENGINE,
	RECIPIENT_ID,
	APN_CMCTN_ID,
	MBR_ID as PT_EXTERNAL_ID,
	' '  as RECIPIENT_TYPE,
	RVR_LAST_NM,
	RVR_FIRST_NM,
	ADDRESS1_TX,
	ADDRESS2_TX,
	STATE_CD,
	CITY_TX,
	ZIP_CD,
	INITIATIVE_ID,
	CDH_EXTERNAL_ID,
	CPG.CLIENT_ID,
	client_level_1 as INSURANCE_CD,
	client_level_2 as CARRIER_ID,
	client_level_3 as ACCOUNT_ID,
	CPG.GROUP_CD,
    DRG_CLS_CATG_DESC_TX as drug_class,
	DRG_CLS_CATG_TX as drug_name,
	DRUG_NDC_ID as ndc,
	GPI_THERA_CLS_CD as gpi 
from pend.&ppt_dataset. CPG left join
     TPGMTASK_RXCLM_RUL RULE  
on  RULE.PROGRAM_ID = 5295
	AND RULE.TASK_ID = 57
	AND ADJ_ENGINE = 'RX'
	AND RULE.PROGRAM_ID = cpg.PROGRAM_ID
	AND RULE.TASK_ID = cpg.TASK_ID
	AND UPPER(TRIM(substr(RULE.carrier_ID,2))) = UPPER(TRIM(CPG.client_level_1))
    &HIERARCHY_CONS.
    and cpg.data_quality_cd=1 ;
quit;

data recipient_list;
 set recipient_list_ql
     recipient_list_re
	 recipient_list_rx;
run;

*SASDOC-------------------------------------------------------------------------
| Produce a report of Clients Setup Report.
+-----------------------------------------------------------------------SASDOC*;
ods listing close;
ods html file =RPTFL ;
options nodate;  

proc print data = recipient_list;
run;

quit;
ods html close;  

%mend gstp_recipient_drug_detail;

filename RPTFL "/herc&sysmode./data/hercules/5295/&RPT_FILE_NM..xls";
filename RPTFL FTP "\users\patientlist\&ops_subdir.\Reports\&RPT_FILE_NM..xls"
         mach='sfb006.psd.caremark.int' RECFM=S;

%gstp_recipient_drug_detail;

*SASDOC-------------------------------------------------------------------------
| Update the job complete timestamp.
+-----------------------------------------------------------------------SASDOC*;
%update_request_ts(complete);

filename mymail email 'qcpap020@prdsas1';

data _null_;
   file mymail
       to=(&Primary_programmer_email.)
       subject='GSTP Recipient Drug Detail Report' ;
   put 'Hi, All:' ;
   put / "This is an automatically generated message to inform you that the client setup report for GSTP Program has been generated.";
   put / "\\sfb006\PatientList\&ops_subdir.\Reports\&RPT_FILE_NM..xls";
   put / 'Please let us know if you have any questions.';
   put / 'Thanks,';
   put / 'HERCULES Production Support';
 run;
 quit;

