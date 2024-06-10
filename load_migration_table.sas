/*HEADER------------------------------------------------------------------------
| PROGRAM NAME: LOAD_MIGRATION_TABLE.SAS
|
| PURPOSE:
|       FOR CLIENT CONNECT WAVE 4 WE NEED TO LOAD MIGRATION TABLE
|		FOR HCE WEB APPLICATION TO BE ABLE TO ACCESS MIGRATED CLIENTS INFO ON ZEUS.
|
|		ONCE HCE WEB APPLICATION WILL HAVE ACCESS TO EDW,
|		WE WILL MODIFY JAVA CODE AND THIS PROCESS WILL BECOME OBSOLETE
|
| INPUT:  
|       DSS_CLIN.V_CLNT_CAG_MGRTN on EDW
| OUTPUT: 
|    	QCPAP020.T_CLNT_CAG_MGRTN on ZEUS
|
|---------------------------------------------------------------------------------
| HISTORY: 28JUN2012 - S.Biletsky	- INITIAL RELEASE
|---------------------------------------------------------------------------------
+---------------------------------------------------------------------------------*HEADER*/

%MACRO REFRESH_MIGR_TBL;

PROC SQL;
DELETE FROM QCPAP020.T_CLNT_CAG_MGRTN ;
QUIT;

PROC SQL;
INSERT INTO QCPAP020.T_CLNT_CAG_MGRTN
(CLNT_CAG_MGRTN_GID, BEA_ID, SRC_PLAN_CLNT_CD, SRC_PLAN_CLNT_ID, TRGT_PLAN_CLNT_CD, 
TRGT_PLAN_CLNT_ID, MGRTN_EFF_DT, MGRTD_CD, BEG_ID, SRC_ADJD_CD, SRC_HIER_ALGN_0_ID, 
SRC_HIER_ALGN_1_ID, SRC_HIER_ALGN_2_ID, SRC_HIER_ALGN_3_ID, SRC_HIER_ALGN_4_ID, SRC_ALGN_LVL_GID, 
SRC_PAYER_ID, SRC_CUST_ID, HIER_IND, CMS_CNTRC_ID, CMS_PBP_ID, CLNT_ACT_NB, AR_NB, BA_NB, PLCY_NB, 
TRGT_ADJD_CD, TRGT_HIER_ALGN_0_ID, TRGT_HIER_ALGN_1_ID, TRGT_HIER_ALGN_2_ID, TRGT_HIER_ALGN_3_ID, 
TRGT_HIER_ALGN_4_ID, TRGT_ALGN_LVL_GID, TRGT_PAYER_ID, TRGT_CUST_ID, SRC_EFF_DT, SRC_END_DT, 
REC_ADD_TS)
SELECT * FROM DSS_CLIN.V_CLNT_CAG_MGRTN;
QUIT;

%PUT NOTE: EDW_COUNT = &EDW_COUNT;
%PUT NOTE: QCPAP020_COUNT = &QCPAP020_COUNT;

%email_parms( 
	EM_TO="Hercules.Support@cvscaremark.com"
	,EM_CC="Sergey.Biletsky@cvscaremark.com"
	,EM_SUBJECT="Migration Table on Zeus was refreshed"
	,EM_MSG="The new and old count difference is &DIFFERENCE_COUNT. . The log file is located at /DATA/sas&sysmode.1/hercules/gen_utilities/sas/load_migration_table/load_migration_table.saslog" );

%MEND REFRESH_MIGR_TBL;

%MACRO CHECK_MIGR_TBL;

PROC SQL;
SELECT COUNT(*) INTO :EDW_COUNT SEPARATED BY ' '
FROM DSS_CLIN.V_CLNT_CAG_MGRTN;

SELECT COUNT(*) INTO :QCPAP020_COUNT SEPARATED BY ' '
FROM QCPAP020.T_CLNT_CAG_MGRTN;
QUIT;

%LET DIFFERENCE_COUNT = &EDW_COUNT - &QCPAP020_COUNT;

%PUT NOTE: DIFFERENCE_COUNT = &DIFFERENCE_COUNT; 

%IF &DIFFERENCE_COUNT NE 0 %THEN %DO;
	%REFRESH_MIGR_TBL;
%END;
%ELSE %DO;
	%email_parms( 
		EM_TO="Hercules.Support@cvscaremark.com"
		,EM_CC="Sergey.Biletsky@cvscaremark.com"
		,EM_SUBJECT="Migration Table on Zeus was not refreshed"
		,EM_MSG="There were 0 rows inserted into Migration Table on Zeus. The log file is located at /DATA/sas&sysmode.1/hercules/gen_utilities/sas/load_migration_table/load_migration_table.saslog" );
%END;
%MEND CHECK_MIGR_TBL;

/* UNCOMMENT next line for prod */
%set_sysmode;

/* COMMENT next line for prod */
*%set_sysmode(mode=test);

%INCLUDE "/PRG/sas&sysmode.1/hercules/hercules_in.sas"; 

OPTIONS MLOGIC MPRINT;

%CHECK_MIGR_TBL;

