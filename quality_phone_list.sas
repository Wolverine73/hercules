/*HEADER------------------------------------------------------------------------
 |
 | PROGRAM: QUALITY_PHONE_LIST.SAS
 |
 | PURPOSE:
 |     This report is requested when there is a Class-I-recall for a drug based on
 |     specific initiative that is already setup/or mailed.
 |
 |     Users will typically run this report after the initiative has been setup
 |     but before it runs.  The program will use the %get_ndc macro to
 |     determine the drugs/dates.
 |
 | INPUT:  DRUG_NDC_IDs and INITIATIVE_ID
 |
 | LOCATION: /PRG/sas&sysmode.1/hercules/reports
 |
 | HISTORY:
 |     John Hou, SEPT 2004, created after Peggy's adhoc Quality_mailing report.
 |
 | CALL EXAMPLE: options sysparm='REQUEST_ID=100022';
 |Hercules Version 2.1.01
 |22AUG2008 - Suresh R. - Modified report to run for all three adjudications
 |
 + --------------------------------------------------------------------  HEADER*/

%MACRO QUALITY_PHONE_LIST;

/*options sysparm='REQUEST_ID=101005' mprint mlogic;*/

proc printto log="/herc&sysmode./prg/hercules/reports/QUALITY_PHONE_LIST.log" new;
run;

/*%set_sysmode(mode = test);*/
%INCLUDE "/herc&sysmode./prg/hercules/hercules_in.sas";
%INCLUDE "/herc&sysmode./prg/hercules/reports/hercules_rpt_in.sas";

/*%LET ROWMAX = 1000;*/
%LET ROWMAX = %STR();

%LET _&REQUIRED_PARMTR_NM.=&REQUIRED_PARMTR_ID;
%LET  &REQUIRED_PARMTR_NM.=&REQUIRED_PARMTR_ID;
%LET _&SEC_REQD_PARMTR_NM.=&SEC_REQD_PARMTR_ID;
%LET &SEC_REQD_PARMTR_NM.=&SEC_REQD_PARMTR_ID;

%PUT _&REQUIRED_PARMTR_NM.=&REQUIRED_PARMTR_ID;
%PUT &REQUIRED_PARMTR_NM.=&REQUIRED_PARMTR_ID;
%PUT _&SEC_REQD_PARMTR_NM.=&SEC_REQD_PARMTR_ID;
%PUT &SEC_REQD_PARMTR_NM.=&SEC_REQD_PARMTR_ID;


%LET PROGRAM_NAME=QUALITY_PHONE_LIST.SAS;

%INCLUDE "/herc&sysmode./prg/hercules/hercules_in.sas";

* ---> Set the parameters for error checking;
/* PROC SQL NOPRINT;*/
/*    SELECT QUOTE(TRIM(email)) INTO :Primary_programmer_email SEPARATED BY ' '*/
/*    FROM ADM_LKP.ANALYTICS_USERS*/
/*    WHERE UPCASE(QCP_ID) IN ("&USER");*/
/* QUIT;*/
/**/
/*%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,*/
/*          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",*/
/*          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Report Request: &request_ID");*/

*SASDOC--------------------------------------------------------------------------
|     The get_ndc macro is expecting &EXT_DRUG_LIST_IN and &DRG_DEFINITION_CD which
|     can be created by either call hercules_in.sas or have them resolved before
|     calling macro.
+------------------------------------------------------------------------SASDOC*;
 PROC SQL NOPRINT;
     CREATE   TABLE HERC_PARMS  AS
     SELECT   D.DRG_DEFINITION_CD,
              A.EXT_DRUG_LIST_IN
     FROM     &HERCULES..TINITIATIVE A,
              &CLAIMSA..TPROGRAM B,
              &HERCULES..TCMCTN_PROGRAM C,
              &HERCULES..TPROGRAM_TASK D

     WHERE    A.INITIATIVE_ID = &_INITIATIVE_ID  AND
              A.PROGRAM_ID = B.PROGRAM_ID       AND
              A.PROGRAM_ID = C.PROGRAM_ID       AND
              A.PROGRAM_ID = D.PROGRAM_ID       AND
              A.TASK_ID = D.TASK_ID;
   QUIT;

   %LET TABLE_PREFIX=T_&_INITIATIVE_ID._1;

   DATA _NULL_;
     SET HERC_PARMS;
     CALL SYMPUT('EXT_DRUG_LIST_IN', PUT(EXT_DRUG_LIST_IN,1.));
     CALL SYMPUT('DRG_DEFINITION_CD', PUT(DRG_DEFINITION_CD,1.));
   RUN;

 
%get_ndc(DRUG_NDC_TBL=&DB2_TMP..&TABLE_PREFIX._NDC_QL4, 
DRUG_NDC_TBL_RX=&ORA_TMP..&TABLE_PREFIX._NDC_RX, 
DRUG_NDC_TBL_RE=&ORA_TMP..&TABLE_PREFIX._NDC_RE, 
CLAIM_DATE_TBL=&DB2_TMP..&TABLE_PREFIX._RVW_DATES);

%MACRO QL_ADJ(ADJ=QL);

	PROC SQL;
	CONNECT TO DB2 AS DB2 (DSN=&UDBSPRP);
	CREATE TABLE RECALL_&_INITIATIVE_ID AS
	SELECT * FROM CONNECTION TO DB2
	  (SELECT          CASE WHEN C.DELIVERY_SYSTEM_CD = 3 THEN 'MAIL'
	                        ELSE 'RETAIL'
					   END AS DELIVERY_SYSTEM,
	                   CLT.CLIENT_NM,
	                   C.DELIVERY_SYSTEM_CD,
	                   B.CLIENT_ID,
	                   B.BNF_FIRST_NM,
	                   B.BNF_LAST_NM,
	                   B.DAY_AREA_CODE_NB,
	                   B.DAY_PHONE_NB,
	                   B.NIGHT_AREA_CODE_NB,
	                   B.NIGHT_PHONE_NB,
	                   B.CDH_EXTERNAL_ID,
	                   B.ADDRESS_LINE1_TX,
	                   B.ADDRESS_LINE2_TX,
	                   B.CITY_TX,
	                   B.STATE,
	                   B.ZIP_CD,
	                   C.NABP_ID,
	                   C.RX_NB,
	                   CHAR(C.FILL_DT) AS FILL_DT,
	                   D.PRESCRIBER_NM,
	                   D.AREA_CODE_NB AS PBR_PHONE_AC,
	                   D.PHONE_NB AS PBR_NB
	   FROM &CLAIMSA..VBENEF_BENEFICIAR2 B,
	                &CLAIMSA..&CLAIM_HIS_TBL C,
	                &CLAIMSA..TPRSCBR_PRESCRIBE1 D,
	                &DB2_TMP..&&TABLE_PREFIX._NDC_QL4 E,
	                &DB2_TMP..&TABLE_PREFIX._RVW_DATES F,
	                &CLAIMSA..TCLIENT1 CLT
	   WHERE B.BENEFICIARY_ID = C.PT_BENEFICIARY_ID
	   AND   C.NTW_PRESCRIBER_ID = D.PRESCRIBER_ID
	   AND   FILL_DT BETWEEN CLAIM_BEGIN_DT AND CLAIM_END_DT
	   AND   BILLING_END_DT > CLAIM_BEGIN_DT
	   AND   E.DRUG_NDC_ID = C.DRUG_NDC_ID
	   AND   E.NHU_TYPE_CD = C.NHU_TYPE_CD
	   AND   E.DRG_GROUP_SEQ_NB = F.DRG_GROUP_SEQ_NB
	   AND   CLT.CLIENT_ID=B.CLIENT_ID

	   AND   (BRLI_VOID_IN = 0 OR BRLI_VOID_IN IS NULL)
	/*        AND NOT EXISTS*/
	/*                (SELECT 1 FROM &CLAIMSA..&CLAIM_HIS_TBL*/
	/*                 WHERE C.BENEFIT_REQUEST_ID = BENEFIT_REQUEST_ID*/
	/*                 AND   C.BRLI_NB = BRLI_NB*/
	/*                 AND   BRLI_VOID_IN > 0)*/

	    AND NOT EXISTS
	        (SELECT 1 FROM &HERCULES..TDELIVERY_SYS_EXCL
	             WHERE C.DELIVERY_SYSTEM_CD = DELIVERY_SYSTEM_CD
	             AND INITIATIVE_ID =&_INITIATIVE_ID
	             )

		ORDER BY CLIENT_NM, BNF_LAST_NM, BNF_FIRST_NM
	/*   ORDER BY B.CLIENT_ID,*/
	/*                   B.BNF_FIRST_NM,*/
	/*                   B.BNF_LAST_NM*/

	);
	DISCONNECT FROM DB2;
	QUIT;


	/* PROC SQL;*/
	/*      CREATE TABLE RECALL_&_INITIATIVE_ID(DROP=CLIENT_ID) AS*/
	/*      SELECT CASE WHEN DELIVERY_SYSTEM_CD=2 THEN 'MAIL'*/
	/*             ELSE 'RETAIL' END AS DELIVERY_SYSTEM, A.CLIENT_NM, B.**/
	/*      FROM CLAIMSA.TCLIENT1 A, RECALL&REQUEST_ID B*/
	/*      WHERE A.CLIENT_ID=B.CLIENT_ID*/
	/*      ORDER BY CLIENT_NM, BNF_LAST_NM, BNF_FIRST_NM;*/
	/* QUIT;*/

%MEND QL_ADJ;

%MACRO RXRE_ADJ(ADJ=, SRC_SYS_CD=);

	%INCLUDE "/herc&sysmode./prg/hercules/macros/delivery_sys_check.sas";

	%DROP_DB2_TABLE(TBL_NAME=&DB2_TMP..RECALL&REQUEST_ID);

	PROC SQL;
	CONNECT TO ORACLE (PATH=&GOLD.);
	CREATE TABLE &DB2_TMP..RECALL&REQUEST_ID AS
	SELECT * FROM CONNECTION TO ORACLE
	(
		SELECT PHMCY.NABP_CODE AS NABP_ID, 
		       &EDW_DELIVERY_SYSTEM.,
		       CLAIM.RX_NBR AS RX_NB, 
			   SUBSTR(CLAIM.DSPND_DATE,1,10) AS FILL_DT,
		       TO_NUMBER(MBR.QL_BNFCY_ID) AS PT_BENEFICIARY_ID,
			   TO_NUMBER(PRCTR.QL_PRSCR_ID) AS NTW_PRESCRIBER_ID
		FROM &DSS_CLIN..V_CLAIM_CORE_PAID CLAIM
		    ,&DSS_CLIN..V_MBR MBR
		    ,&DSS_CLIN..V_PHMCY_DENORM PHMCY
			,&DSS_CLIN..V_PRCTR_DENORM PRCTR
			,&ORA_TMP..&&TABLE_PREFIX._NDC_&ADJ. NDC
			,&ORA_TMP..&TABLE_PREFIX._RVW_DATES RVWDT
		WHERE CLAIM.SRC_SYS_CD = &SRC_SYS_CD. AND
			  (CLAIM.QL_VOID_IND = 0 OR CLAIM.QL_VOID_IND IS NULL) AND
			  CLAIM.DSPND_DATE BETWEEN RVWDT.CLAIM_BEGIN_DT AND RVWDT.CLAIM_END_DT AND
			  CLAIM.BATCH_DATE IS NOT NULL AND
		      CLAIM.DRUG_GID = NDC.DRUG_GID AND
		      CLAIM.MBR_GID = MBR.MBR_GID AND
		      CLAIM.PAYER_ID = MBR.PAYER_ID AND
		      CLAIM.PHMCY_GID = PHMCY.PHMCY_GID AND
		      CLAIM.PRCTR_GID = PRCTR.PRCTR_GID
		      &DS_STRING_RX_RE.
			  &ROWMAX.
	);
	DISCONNECT FROM ORACLE;
	QUIT;

	PROC SQL;
	CONNECT TO DB2 AS DB2 (DSN=&UDBSPRP);
	CREATE TABLE RECALL_&_INITIATIVE_ID AS
	SELECT * FROM CONNECTION TO DB2
	  (SELECT          DELIVERY_SYSTEM
	                   ,E.CLIENT_NM
					   ,CASE WHEN DELIVERY_SYSTEM = 'MAIL' THEN 3
					         ELSE 2
						END AS DELIVERY_SYSTEM_CD
	                   ,B.CLIENT_ID
	                   ,B.BNF_FIRST_NM
	                   ,B.BNF_LAST_NM
	                   ,B.DAY_AREA_CODE_NB
	                   ,B.DAY_PHONE_NB
	                   ,B.NIGHT_AREA_CODE_NB
	                   ,B.NIGHT_PHONE_NB
	                   ,B.CDH_EXTERNAL_ID
	                   ,B.ADDRESS_LINE1_TX
	                   ,B.ADDRESS_LINE2_TX
	                   ,B.CITY_TX
	                   ,B.STATE
	                   ,B.ZIP_CD
	                   ,C.NABP_ID
	                   ,C.RX_NB
	                   ,C.FILL_DT
	                   ,D.PRESCRIBER_NM
	                   ,D.AREA_CODE_NB AS PBR_PHONE_AC
	                   ,D.PHONE_NB AS PBR_NB
	   FROM 	&CLAIMSA..VBENEF_BENEFICIAR2 B
	            ,&DB2_TMP..RECALL&REQUEST_ID C
	            ,&CLAIMSA..TPRSCBR_PRESCRIBE1 D
				,&CLAIMSA..TCLIENT1 E
	   WHERE B.BENEFICIARY_ID = C.PT_BENEFICIARY_ID
	   AND   C.NTW_PRESCRIBER_ID = D.PRESCRIBER_ID
	   AND   B.CLIENT_ID=E.CLIENT_ID
	   ORDER BY B.CLIENT_ID
	            ,B.BNF_FIRST_NM
	            ,B.BNF_LAST_NM);
	DISCONNECT FROM DB2;
	QUIT;

%MEND RXRE_ADJ;

%MACRO OUTDSN;

  %IF NOT %SYSFUNC(EXIST (FRECALL_&_INITIATIVE_ID)) %THEN %DO;

		  PROC SQL;
			CREATE TABLE FRECALL_&_INITIATIVE_ID
			(
				DELIVERY_SYSTEM CHAR(10)
				,CLIENT_NM CHAR(30)
				,DELIVERY_SYSTEM_CD INT
				,CLIENT_ID INT
				,BNF_FIRST_NM CHAR(30)
				,BNF_LAST_NM CHAR(30)
				,DAY_AREA_CODE_NB CHAR(3)
				,DAY_PHONE_NB CHAR(7)
				,NIGHT_AREA_CODE_NB CHAR(3)
				,NIGHT_PHONE_NB CHAR(7)
				,CDH_EXTERNAL_ID CHAR(20)
				,ADDRESS_LINE1_TX CHAR(40)
				,ADDRESS_LINE2_TX CHAR(40)
				,CITY_TX CHAR(40)
				,STATE CHAR(2)
				,ZIP_CD CHAR(5)
				,NABP_ID CHAR(20)
				,RX_NB CHAR(20)
				,FILL_DT CHAR(10)
				,PRESCRIBER_NM CHAR(60)
				,PBR_PHONE_AC CHAR(3)
				,PBR_NB CHAR(7)
			);
		  QUIT;

  %END;

  %IF %EVAL(&QL_ADJ + &RX_ADJ + &RE_ADJ) > 1 %THEN %DO;
  	PROC APPEND BASE=FRECALL_&_INITIATIVE_ID DATA=RECALL_&_INITIATIVE_ID;
  	RUN;
  	%LET FINALDSN = FRECALL_&_INITIATIVE_ID;
  %END;
  %ELSE %DO;
  	%LET FINALDSN = RECALL_&_INITIATIVE_ID;
  %END;
%MEND OUTDSN;

%IF &QL_ADJ = 1 %THEN %DO;
	%ql_adj(ADJ = QL);
	%OUTDSN;
%END;

%IF &RX_ADJ = 1 %THEN %DO;
	%RXRE_ADJ(ADJ = RX, SRC_SYS_CD='X');
	%OUTDSN;
%END;

%IF &RE_ADJ = 1 %THEN %DO;
	%RXRE_ADJ(ADJ = RE, SRC_SYS_CD='R');
	%OUTDSN;
%END;

/**/
/*  %export_sas_to_txt(tbl_name_in=&FINALDSN,*/
/*                     tbl_name_out=ftp_txt,*/
/*                     l_file="layout_out",*/
/*                     File_type_out='DEL|',*/
/*                     Col_in_fst_row=Y);*/
/**/
/*  %SET_ERROR_FL;*/
/**/
/*%macro exit_end;*/
/**/
/*   %if &err_fl=0 %then %do;*/
/**/
/*proc sql noprint;*/
/*     select count(*) into:rcrds_cnt*/
/*     from &FINALDSN; quit;*/
/**/
/**/
/*     filename mymail email 'qcpap020@dalcdcp';*/
/*   %if &rcrds_cnt >0 %then %do;*/
/*     data _null_;*/
/*       file mymail*/
/*           to=(&EMAIL_USR_rpt)*/
/*           subject="&rpt_display_nm" ;*/
/**/
/*       put 'Hi, All:' ;*/
/*       put / "This is an automatically generated message to inform you that your request &request_id has been processed.";*/
/*       put "There are %cmpres(&rcrds_cnt) records in the file and can be accessed by clicking the link: ";*/
/*   %if &ops_subdir =%str(GENERAL_REPORTS) %THEN %STR(put / "\\sfb006\PatientList\&ops_subdir\&rpt_file_nm..txt";);*/
/*   %ELSE %STR(put / "\\sfb006\PatientList\&ops_subdir\Reports\&rpt_file_nm..txt";);*/
/*       put / 'Please let us know of any questions.';*/
/*       put / 'Thanks,';*/
/*       put / 'HERCULES Production Supports';*/
/*     run;*/
/*     quit;*/
/*   %end; /** end of &rcrds_cnt>0 **/*/
/**/
/*     %if &rcrds_cnt =0 %then %do;*/
/*     data _null_;*/
/*       file mymail*/
/*           to=(&EMAIL_USR_rpt)*/
/*           subject="&rpt_display_nm" ;*/
/**/
/*       put 'Hi, All:' ;*/
/*       put / "This is an automatically generated message to inform you that your request &request_id has been processed.";*/
/*       put "The request resulted 0 record and no file was created. ";*/
/*       put / 'Please let us know of any questions.';*/
/*       put / 'Thanks,';*/
/*       put / 'HERCULES Production Supports';*/
/*     run;*/
/**/
/*    %end; /** end of &rcrds_cnt=0 **/*/
/**/
/*   %update_request_ts(complete);*/
/**/
/*  %end;*/
/* %mend EXIT_END;*/
/*  %EXIT_END;*/
/**/
/*    * ---> Set the parameters for error checking;*/
/*     PROC SQL NOPRINT;*/
/*        SELECT QUOTE(TRIM(email)) INTO :Primary_programmer_email*/
/*        FROM ADM_LKP.ANALYTICS_USERS*/
/*        WHERE UPCASE(QCP_ID) IN ("&USER");*/
/*     QUIT;*/
/**/
/*  %SET_ERROR_FL;*/
/**/
/*  %on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,*/
/*             EM_SUBJECT="HCE SUPPORT:  Notification of Abend",*/
/*             EM_MSG="A problem was encountered.  See LOG file - quality_phone_list.log for REQUEST ID &REQUEST_ID");*/
;
%MEND QUALITY_PHONE_LIST;
%QUALITY_PHONE_LIST;
