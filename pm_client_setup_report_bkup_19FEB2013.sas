/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  PM_CLIENT_SETUP_REPORT.SAS
|
| LOCATION: /hercprod/prg/hercules/reports
|
| PURPOSE:  Produces a summary report of all parameters 
|			from PM Client Setup screens for all
|			Adjudication Engines at once.
|
|
| INPUT:    &CLAIMSA..TCLIENT1
|           &HERCULES..TPGMTASK_RXCLM_RUL
|           &HERCULES..TPGMTASK_RECAP_RUL
|           &HERCULES..TPGMTASK_QL_RUL
|           &HERCULES..TCARRIER_INSUR_MAP
|           &HERCULES..TPROGRAM_TASK
|			&HERCULES..TTASK
|
|
| OUTPUT:   three separate reports by e-mail in PDF format.
+-------------------------------------------------------------------------------
|
| HISTORY:  
|
| 31JAN2013 - Radhika Gadde/Sergey Biletsky  - Original
| 
+-----------------------------------------------------------------------HEADER*/

%set_sysmode;

/*%set_sysmode(mode=sit2);*/
/*OPTIONS SYSPARM='RPT_PROGRAM_ID=105 RPT_TASK_ID=11 HSC_USR_ID=QCPI208 REQUEST_ID=102204';*/

%include "/herc&sysmode/prg/hercules/hercules_in.sas";

/*OPTIONS FULLSTIMER MPRINT MLOGIC SYMBOLGEN SOURCE2 MPRINTNEST MLOGICNEST;*/

OPTIONS FULLSTIMER MPRINT MLOGIC;

%update_request_ts(start);

FOOTNOTE1;
FOOTNOTE2;
FOOTNOTE3;
%let prg_id_chk= %str(AND CLT.PROGRAM_ID=&RPT_PROGRAM_ID);
%put _user_;

PROC SQL NOPRINT;
        SELECT QUOTE(TRIM(email)) INTO :_em_to_user SEPARATED BY ' '
        FROM ADM_LKP.ANALYTICS_USERS
        WHERE UPCASE(QCP_ID) IN ("&HSC_USR_ID");
QUIT;

DATA _NULL_;
  TODAY_DT=TODAY();
  CALL SYMPUT('REPORT_DATE',PUT(TODAY_DT, yymmdd10.));
  CALL SYMPUT('CURRENT_DT',"'" || PUT(TODAY_DT, yymmdd10.) || "'"); 

RUN;
TITLE4 "as of &REPORT_DATE";
%PUT NOTE: &REPORT_DATE;
%PUT NOTE: &CURRENT_DT;

PROC SQL;
	SELECT (CASE DFL_CLT_INC_EXU_IN
			WHEN 0 THEN 'DEFAULT INCLUDE'
			WHEN 1 THEN 'DEFAULT EXCLUDE'
			ELSE 'NO DEFAULT'
			END) INTO :DFL_CLT_INC_EXU_IN
	FROM &HERCULES..TPROGRAM_TASK
	WHERE TASK_ID = &RPT_TASK_ID;
QUIT;

PROC SQL;
	SELECT A.LONG_TX, B.SHORT_TX 
	INTO :RPT_PROGRAM_NAME, :RPT_TASK_NAME
	FROM CLAIMSA.TPROGRAM A, HERCULES.TTASK B, HERCULES.TPROGRAM_TASK C
	WHERE A.PROGRAM_ID = C.PROGRAM_ID 
	AND B.TASK_ID=C.TASK_ID
	AND B.TASK_ID = &RPT_TASK_ID. ;
QUIT;

%put note: &RPT_PROGRAM_NAME. &RPT_TASK_NAME.;

PROC SQL;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   CREATE TABLE QL_CLIENT AS
   SELECT * FROM CONNECTION TO DB2
     (
SELECT A.CLIENT_ID as Client_ID,
       A.GROUP_CLASS_CD as RPT_GRP,
       A.GROUP_CLASS_SEQ_NB as SEQ,
       A.BLG_REPORTING_CD as BLG_RPT_CD,
       A.PLAN_NM as Plan_Name,
       A.PLAN_CD_TX as Plan_CD,
       A.PLAN_EXT_CD_TX as Plan_Ext_CD,
       A.GROUP_CD_TX as Group_CD,
       A.GROUP_EXT_CD_TX as Group_Ext_CD,
	    (CASE A.CLT_SETUP_DEF_CD
        WHEN 1 THEN 'ENTIRE CLIENT'
		WHEN 2 THEN 'CLIENT WITH EXCLUSION'
		WHEN 3 THEN 'PARTIAL'
		ELSE 'ENTIRE CLIENT EXCLUSION'
        END)as Setup_Type,
       A.EFFECTIVE_DT as Effective_Date,
       A.EXPIRATION_DT as Expiration_Date,
       B.CLIENT_NM as Client_Name
  FROM &HERCULES..TPGMTASK_QL_RUL A,
       &CLAIMSA..TCLIENT1 B
WHERE PROGRAM_ID = &RPT_PROGRAM_ID.
       AND A.TASK_ID =&RPT_TASK_ID.
       AND A.CLIENT_ID = B.CLIENT_ID
       AND A.EXPIRATION_DT >= &CURRENT_DT.
);
DISCONNECT FROM DB2;
QUIT;


OPTIONS ORIENTATION=LANDSCAPE LS=256 PAPERSIZE=LEGAL PAGESIZE=50 NODATE;
filename RPTFL "/herc&sysmode/data/hercules/reports/ql_client_setup_&RPT_PROGRAM_ID._&RPT_TASK_ID..pdf";

ODS LISTING CLOSE;
ODS pdf FILE=RPTFL;
TITLE1 "Hercules Program Maintenance";
TITLE2 "QL Client Setup";
TITLE3 "For Mailing Progam: &RPT_PROGRAM_NAME";
TITLE4 "For Task: &RPT_TASK_NAME";
TITLE5 "&DFL_CLT_INC_EXU_IN";
TITLE6 "as of &REPORT_DATE";
PROC PRINT DATA=QL_CLIENT SPLIT='_' ROWS=PAGE
Style(HEADER ) = {background=yellow} style (DATA)= [ background = white ];
RUN;
ODS pdf CLOSE;
ODS LISTING;

PROC SQL;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   CREATE TABLE RX_CLIENT AS
   SELECT * FROM CONNECTION TO DB2
   (
SELECT A.CARRIER_ID as Carrier_ID,
       A.ACCOUNT_ID as Account_ID,
       A.GROUP_CD as Group_CD,
	   (CASE A.CLT_SETUP_DEF_CD
        WHEN 1 THEN 'ENTIRE CLIENT'
		WHEN 2 THEN 'CLIENT WITH EXCLUSION'
		WHEN 3 THEN 'PARTIAL'
		ELSE 'ENTIRE CLIENT EXCLUSION'
		END)as Setup_Type,
       A.EFFECTIVE_DT as Effective_Date,
       A.EXPIRATION_DT as Expiration_Date,
       B.CLIENT_NM as Client_Name
  FROM &HERCULES..TPGMTASK_RXCLM_RUL A
       LEFT JOIN
       &CLAIMSA..TCLIENT1 B
       ON LTRIM (RTRIM (A.CARRIER_ID)) = LTRIM (RTRIM (B.CLIENT_CD))
WHERE A.PROGRAM_ID = &RPT_PROGRAM_ID.
       AND A.TASK_ID = &RPT_TASK_ID.
/*       AND A.EFFECTIVE_DT <= &CURRENT_DT.*/
       AND A.EXPIRATION_DT >= &CURRENT_DT.
);
DISCONNECT FROM DB2;
QUIT;

OPTIONS ORIENTATION=LANDSCAPE LS=256 PAPERSIZE=LEGAL PAGESIZE=50;
filename RPTFL "/herc&sysmode/data/hercules/reports/rx_client_setup_&RPT_PROGRAM_ID._&RPT_TASK_ID..pdf";

ODS LISTING CLOSE;
ODS pdf FILE=RPTFL;
TITLE1 "Hercules Program Maintenance";
TITLE2 "RxClaim Client Setup";
TITLE3 "For Mailing Progam: &RPT_PROGRAM_NAME";
TITLE4 "For Task: &RPT_TASK_NAME";
TITLE5 "&DFL_CLT_INC_EXU_IN";
TITLE6 "as of &REPORT_DATE";
PROC PRINT DATA=RX_CLIENT SPLIT='_' ROWS=PAGE
Style(HEADER ) = {background=yellow} style (DATA)= [ background = white ];
RUN;
ODS pdf CLOSE;
ODS LISTING;

PROC SQL;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   CREATE TABLE RE_CLIENT AS
   SELECT * FROM CONNECTION TO DB2
   (
SELECT DISTINCT
       A.INSURANCE_CD as Insurance_CD,
       A.CARRIER_ID as Carrier_ID,
       A.GROUP_CD as Group_CD,
	   (CASE A.CLT_SETUP_DEF_CD
        WHEN 1 THEN 'ENTIRE CLIENT'
		WHEN 2 THEN 'CLIENT WITH EXCLUSION'
		WHEN 3 THEN 'PARTIAL'
		ELSE 'ENTIRE CLIENT EXCLUSION'
		END)as Setup_Type,
       A.EFFECTIVE_DT as Effective_Date,
       A.EXPIRATION_DT  as Expiration_Date,
       B.INSURANCE_NM as Insurance_Name
  FROM &HERCULES..TPGMTASK_RECAP_RUL A,
       &HERCULES..TCARRIER_INSUR_MAP B
WHERE A.PROGRAM_ID = &RPT_PROGRAM_ID.
       AND A.TASK_ID = &RPT_TASK_ID.
       AND A.INSURANCE_CD = B.INSURANCE_CD
       AND A.EXPIRATION_DT >= &CURRENT_DT.
);
DISCONNECT FROM DB2;
QUIT;



OPTIONS ORIENTATION=LANDSCAPE LS=256 PAPERSIZE=LEGAL PAGESIZE=50;
filename RPTFL "/herc&sysmode/data/hercules/reports/re_client_setup_&RPT_PROGRAM_ID._&RPT_TASK_ID..pdf";

ODS LISTING CLOSE;
ODS pdf FILE=RPTFL;
TITLE1 "Hercules Program Maintenance";
TITLE2 "Recap Client Setup";
TITLE3 "For Mailing Progam: &RPT_PROGRAM_NAME";
TITLE4 "For Task: &RPT_TASK_NAME";
TITLE5 "&DFL_CLT_INC_EXU_IN";
TITLE6 "as of &REPORT_DATE";
PROC PRINT DATA=RE_CLIENT SPLIT='_' ROWS=PAGE
Style(HEADER ) = {background=yellow} style (DATA)= [ background = white ];
RUN;
ODS pdf CLOSE;
ODS LISTING;

%update_request_ts(complete);

%email_parms( EM_TO=&_em_to_user
      ,EM_CC="Hercules.Support@caremark.com"
      ,EM_SUBJECT="QL Client Setup Report for &RPT_PROGRAM_ID. and &RPT_TASK_ID."
      ,EM_MSG="The report you requested is attached"
  ,EM_ATTACH="/herc&sysmode/data/hercules/reports/ql_client_setup_&RPT_PROGRAM_ID._&RPT_TASK_ID..pdf"  
	ct="application/pdf");


%email_parms( EM_TO=&_em_to_user
      ,EM_CC="Hercules.Support@caremark.com"
      ,EM_SUBJECT="RxClaim Client Setup Report for &RPT_PROGRAM_ID. and &RPT_TASK_ID."
      ,EM_MSG="The report you requested is attached"
  ,EM_ATTACH="/herc&sysmode/data/hercules/reports/rx_client_setup_&RPT_PROGRAM_ID._&RPT_TASK_ID..pdf"  
	ct="application/pdf");

%email_parms( EM_TO=&_em_to_user
      ,EM_CC="Hercules.Support@caremark.com"
      ,EM_SUBJECT="Recap Client Setup Report for &RPT_PROGRAM_ID. and &RPT_TASK_ID."
      ,EM_MSG="The report you requested is attached"
  ,EM_ATTACH="/herc&sysmode/data/hercules/reports/re_client_setup_&RPT_PROGRAM_ID._&RPT_TASK_ID..pdf"  
	ct="application/pdf");

