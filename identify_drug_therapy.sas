/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  IDENTIFY DRUG THERAPY
|
| LOGIC:    THIS PROGRAM IS USED TO PRODUCE SEVERAL TASKS (7, 11, 13, 19, 21).
|           THE TASKS DIFFER IN THAT THEY INCLUDE NO DRUG INFORMATION ON THE
|           FILE LAYOUT (TASK ID 11), DRUG NAME ONLY (TASK ID 19) OR DRUG AND
|           STRENGTH (TASK ID 21).  ADDITIONALLY, THESE TASKS ARE SHARED AMONG
|           DIFFERENT CAREMARK PROGRAMS.  SOME MACROS EXECUTE CONDITIONALLY
|           BASED ON PROGRAM.
|
| LOCATION: /PRG/SAS&SYSMODE.1/HERCULES/
|
| INPUT:    TABLES REFERENCED BY MACROS ARE NOT LISTED HERE
|           &CLAIMSA..&CLAIM_HIS_TBL
|           &CLAIMSA..TCLIENT1
|           &CLAIMSA..TDRUG1
|
|
| OUTPUT:   STANDARD OUTPUT FILES IN /PENDING AND /RESULTS DIRECTORIES
+--------------------------------------------------------------------------------
| HISTORY:  DECEMBER 2003 - YURY VILK
|           NOV. 30, 2005 - GREGORY DUDLEY
|           ADDED MACRO VARIABLE ASSIGMENTS FOR CLAIM_BEGIN_DT AND
|           CLAIM_END_DT FOR RUN OUTSIDE OF NORMAL DATE RANGE.
|           14SEP2007     - N.WILLIAMS - HERCULES VERSION  1.5.01
|                          COMMENTED OUT CALL TO %CHECK_TBL MACRO BECAUSE ITS NOT
|                          NEEDED AND DB CHANGES WILL NOT KEEP STATISTICS OF TABLE
|                          LOADS ANYMORE.
|
|+--------------------------------------------------------------------------------
| HISTORY:  
|           APR. 22, 2008 - CARL STARKS - HERCULES VERSION 2.1.01
|
|           ADDED 3 MACRO CALLS TO GET CLAIM DATA 
|           PULL_CLAIMS_FOR_EDW IS A NEW MACRO TO PULL CLAIMS FOR RECAP AND RXCLAIM 
|           PULL_CLAIMS_FOR_QL IS A NEW MACRO ALTHOUGH THE LOGIC WAS JUST PULLED 
|           FROM IDENTIFY DRUG THERAPY AND MADE INTO A MACRO              
|           CALL NEW MACRO EDW2UNIX TO DOWNLOAD DATA TO UNIX THEN CALL               
|           NEW MACRO COMBINE_ADJ TO COMBINE ADJUDICATIONS AND DATA CONVERSION
|           ADDED LOGIC TO RUN SOME EXISTING MACROS TO RUN BASED ON ADJUDICATION 
|
| HISTORY:  
|           Sep24 2008 - CARL STARKS - Hercules Version  2.1.2.01
|
|           added a new common macro to pull claims for edw (claims_pull_edw)
|           added logic that will produce the following 2 reports
|           client_initiative_summary.sas receiver_listing.sas
|
|           Nov04 2009    - Brian Stropich Hercules Version  2.1.2.02
|           added changes to resolve the issue of particpant eligibility issue
|           22MAR2010     - N. Williams Hercules Version  2.1.2.03
|           Add logic to set nhu_type_cd in edw2unix if its value is missing.
|           JUNE 2012 - E BUKOWSKI(SLIOUNKOVA) -  TARGET BY DRUG/DSA AUTOMATION
|           CHANGED to call custom macros get_ndc_tbd.sas, claims_pull_edw_tbd.sas, pull_claims_for_edw_tbd.sas 
|           delivery_sys_check_tbd.sas. Also added logic to populate RECAP and RxClaim address tables 
|           to be able to execute invalid QL Bene id logic by create_base_file macro, and added logic
|           to remove invalid prescribers from prescriber output file
|
|	    Sep 2013  Ray Pileckis
|	    BSR - Added logic for Client Connect Recap RxClaim Eligility
|
|	    DEC 2013 J.Agostinelli BSR - Voided Claims + other fixes
----------------------------------------------------------------------------------------HEADER*/

*SASDOC-------------------------------------------------------------------------
| CALL MACRO HERCULES_IN
------------------------------------------------------------------------------SASDOC*;
%include "%SYSGET(HOME)/autoexec_new.sas";
%set_sysmode;
options mlogic mprint;

/*options sysparm='INITIATIVE_ID=9011 PHASE_SEQ_NB=1 USER=QCPI2EF';*/
/*options mlogic mlogicnest mprint mprintnest symbolgen source2;*/

%include "/herc&sysmode/prg/hercules/hercules_in.sas";

*SASDOC-------------------------------------------------------------------------
| CALL MACRO UPDATE_TASK_TS WITH INPUT PARAMETER JOB_START_TS
------------------------------------------------------------------------------SASDOC*;

%UPDATE_TASK_TS(JOB_START_TS);

%LET ERR_FL=0;
%LET PROGRAM_NAME=IDENTIFY_DRUG_THERAPY;
%LET MAX_ROWS_FETCHED=10000000;

*SASDOC-------------------------------------------------------------------------
| ASSIGN PRIMARY_PROGRAMMER_EMAIL
------------------------------------------------------------------------------SASDOC*;

PROC SQL NOPRINT;
	SELECT QUOTE(TRIM(EMAIL)) INTO :PRIMARY_PROGRAMMER_EMAIL SEPARATED BY ' '
	FROM ADM_LKP.ANALYTICS_USERS
	WHERE UPCASE(QCP_ID) IN ("&USER");
QUIT;

*SASDOC--------------------------------------------------------------------------
| C.J.S APR2008
| CALL MACRO RESOLVE_CLIENT BUT DON'T EXECUTE FOR QUALITY MAILINGS
+------------------------------------------------------------------------SASDOC*;

%RESOLVE_CLIENT(TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._QL,
  				TBL_NAME_OUT_RX=&ORA_TMP..&TABLE_PREFIX._RX,
  				TBL_NAME_OUT_RE=&ORA_TMP..&TABLE_PREFIX._RE,
  				EXECUTE_CONDITION=%STR(&PROGRAM_ID NE 105 OR &TASK_ID NE 11));
				
*SASDOC--------------------------------------------------------------------------
| Q2X
| Resolve Client for PGM-TASK 105-11 only to include QL hierarhy together with RX
+------------------------------------------------------------------------SASDOC*;
%MACRO RESOLVE_CLIENT_11_Q2X(TBL_NAME_OUT_RX = );

%IF &RX_ADJ =1 %THEN %DO;
 %if &task_id. EQ 11 %then %do;

%*SASDOC---------------------------------------------------------------------------------
 |Q2X : WE CHECK IF CLIENT MIGRATED FROM QL TO RX 
 |		AND PREPARE QL CLINT IDS to PULL CLAIMS FOR QL HISTORY
 +----------------------------------------------------------------------------SASDOC;
/*initialize migration indicators*/
	%LET CC_QL_MIGR_IND = 0;

	PROC SQL NOPRINT;
		SELECT PUT(CLAIM_BEGIN_DT,YYMMDD10.) INTO :CLAIM_BEGIN_DT 
		FROM &HERCULES..TPHASE_DRG_GRP_DT
		WHERE INITIATIVE_ID = &INITIATIVE_ID.; 
	QUIT;
	DATA _NULL_;
  		CALL SYMPUT('CLAIM_BEGIN_DT_EDW',"TO_DATE('&CLAIM_BEGIN_DT.','YYYY-MM-DD')");
  		CALL SYMPUT('TODAY_EDW',"TO_DATE('"||PUT(TODAY(),YYMMDD10.)||"','YYYY-MM-DD')");  
	RUN;

	%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._QL_MIGR);

	PROC SQL ;
	CONNECT TO ORACLE(PATH=&GOLD PRESERVE_COMMENTS);
	CREATE TABLE &ORA_TMP..&TABLE_PREFIX._QL_MIGR AS
	SELECT * FROM CONNECTION TO ORACLE 
     (SELECT  DISTINCT A.EXTNL_LVL_ID1 AS CLT_LEVEL_1
 	 	,B.TRGT_HIER_ALGN_2_ID AS CLT_LEVEL_2
		,B.TRGT_HIER_ALGN_3_ID AS CLT_LEVEL_3
		,B.SRC_HIER_ALGN_1_ID AS QL_CLT_ID
		,B.SRC_HIER_ALGN_2_ID AS CLT_PLAN_GROUP_ID
/*		,B.MGRTN_EFF_DT*/
     FROM DSS_CLIN.V_ALGN_LVL_DENORM A, DSS_CLIN.V_CLNT_CAG_MGRTN  B
     WHERE A.EXTNL_LVL_ID1=B.TRGT_HIER_ALGN_1_ID
	 	AND A.SRC_SYS_CD ='X'
		AND B.SRC_ADJD_CD ='Q'
/*	fix for future migration dates in table	*/
		AND &TODAY_EDW. >= B.MGRTN_EFF_DT
		AND &CLAIM_BEGIN_DT_EDW. <= B.MGRTN_EFF_DT
		AND B.SRC_HIER_ALGN_2_ID IS NOT NULL
 	);
	DISCONNECT FROM ORACLE;
	QUIT;

	%DROP_DB2_TABLE(TBL_NAME =&DB2_TMP..&TABLE_PREFIX._QL_MIGR);

	PROC SQL;
		CREATE TABLE &DB2_TMP..&TABLE_PREFIX._QL_MIGR AS 
		SELECT  CLT_LEVEL_1,
				CLT_LEVEL_2,
				CLT_LEVEL_3,
			INPUT(QL_CLT_ID,12.) AS QL_CLT_ID,
			INPUT(CLT_PLAN_GROUP_ID,12.) AS CLT_PLAN_GROUP_ID 
		FROM &ORA_TMP..&TABLE_PREFIX._QL_MIGR;
	QUIT;

/*	%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._QL_MIGR);*/

	PROC SQL NOPRINT;
		SELECT COUNT(*) INTO :QL_MGRTN_ROW_CNT 
		FROM &DB2_TMP..&TABLE_PREFIX._QL_MIGR;
	QUIT;

	%IF &QL_MGRTN_ROW_CNT NE 0 %THEN %DO;
		%LET CC_QL_MIGR_IND = 1;
	%END;

 %end;
%END;
%MEND RESOLVE_CLIENT_11_Q2X;

%RESOLVE_CLIENT_11_Q2X(TBL_NAME_OUT_RX=&ORA_TMP..&TABLE_PREFIX._RX);

/*  New RP  */

%MACRO RESOLVE_CLIENT_11_RE;


%IF &TASK_ID. = 11  OR &TASK_ID. = 35 %THEN %DO;

    /*initialize migration indicators*/
    %LET CC_RE_MIGR_IND = 0;

    PROC SQL NOPRINT;
       SELECT PUT(CLAIM_BEGIN_DT,YYMMDD10.) INTO :CLAIM_BEGIN_DT 
       FROM &HERCULES..TPHASE_DRG_GRP_DT
       WHERE INITIATIVE_ID = &INITIATIVE_ID.; 
    QUIT;
      
    DATA _NULL_;
       CALL SYMPUT('CLAIM_BEGIN_DT_EDW',"TO_DATE('&CLAIM_BEGIN_DT.','YYYY-MM-DD')");
       CALL SYMPUT('TODAY_EDW',"TO_DATE('"||PUT(TODAY(),YYMMDD10.)||"','YYYY-MM-DD')");  
    RUN;
      
    %PUT NOTE: CLAIM_BEGIN_DT_EDW = &CLAIM_BEGIN_DT_EDW. ;
    %PUT NOTE: TODAY_EDW = &TODAY_EDW. ;

    %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._RE_MIGR);

    %IF &TASK_ID. = 11 %THEN %DO;
                  PROC SQL ;
                  CONNECT TO ORACLE(PATH=&GOLD PRESERVE_COMMENTS);
                  EXECUTE
                  (
                                                CREATE TABLE &ORA_TMP..&TABLE_PREFIX._RE_MIGR AS
                                                SELECT  DISTINCT 
                                                B.SRC_ALGN_LVL_GID   AS ALGN_LVL_GID_KEY, 
                                                B.SRC_HIER_ALGN_0_ID AS INSURANCE_CD,
                                                B.SRC_HIER_ALGN_1_ID AS CARRIER_ID,
                                                B.SRC_HIER_ALGN_2_ID AS GROUP_CD,
                                                B.SRC_PLAN_CLNT_ID   AS QL_CLIENT_ID,
                                                B.SRC_PAYER_ID       AS PAYER_ID
                                                FROM DSS_CLIN.V_ALGN_LVL_DENORM A, 
                                                     DSS_CLIN.V_CLNT_CAG_MGRTN  B
                                                WHERE A.EXTNL_LVL_ID1=B.TRGT_HIER_ALGN_1_ID
                                                  AND A.SRC_SYS_CD ='X'
                                                  AND B.SRC_ADJD_CD ='R' 
                                                  AND B.SRC_HIER_ALGN_2_ID IS NOT NULL 
                                                  AND B.SRC_ALGN_LVL_GID <> -1
                                                  AND &CLAIM_BEGIN_DT_EDW. <= B.MGRTN_EFF_DT 
                              ) BY ORACLE ;
                              DISCONNECT FROM ORACLE;
                              QUIT;
      %END;
      
      %IF &TASK_ID. = 35 %THEN %DO; 
        %IF %SYSFUNC(EXIST(&ORA_TMP..&TABLE_PREFIX._RX)) %THEN %DO;
                    PROC SQL ;
                    CONNECT TO ORACLE(PATH=&GOLD PRESERVE_COMMENTS);
                    EXECUTE
                    (
                                                CREATE TABLE &ORA_TMP..&TABLE_PREFIX._RE_MIGR AS
                                                SELECT  DISTINCT 
                                                B.SRC_ALGN_LVL_GID   AS ALGN_LVL_GID_KEY, 
                                                B.SRC_HIER_ALGN_0_ID AS INSURANCE_CD,
                                                B.SRC_HIER_ALGN_1_ID AS CARRIER_ID,
                                                B.SRC_HIER_ALGN_2_ID AS GROUP_CD,
                                                B.SRC_PLAN_CLNT_ID   AS QL_CLIENT_ID,
                                                B.SRC_PAYER_ID       AS PAYER_ID
                                                FROM DSS_CLIN.V_ALGN_LVL_DENORM A, 
                                                     DSS_CLIN.V_CLNT_CAG_MGRTN  B,
                                                     &ORA_TMP..&TABLE_PREFIX._RX  C
                                                WHERE A.EXTNL_LVL_ID1=B.TRGT_HIER_ALGN_1_ID
                                                  AND A.SRC_SYS_CD ='X'
                                                  AND B.SRC_ADJD_CD ='R' 
                                                  AND B.SRC_HIER_ALGN_2_ID IS NOT NULL 
                                                  AND B.SRC_ALGN_LVL_GID <> -1
                                                  AND B.TRGT_ALGN_LVL_GID=C.ALGN_LVL_GID_KEY
                                                  AND &CLAIM_BEGIN_DT_EDW. <= B.MGRTN_EFF_DT 
                              ) BY ORACLE ;
                              DISCONNECT FROM ORACLE;
                              QUIT;
     %END;
   %END;
      
   PROC SQL NOPRINT;
      SELECT COUNT(*) INTO :RE_MGRTN_ROW_CNT 
      FROM &ORA_TMP..&TABLE_PREFIX._RE_MIGR;
   QUIT;

   %IF &RE_MGRTN_ROW_CNT NE 0 %THEN %DO;
       %LET CC_RE_MIGR_IND = 1;
   %END;
   %ELSE %DO;
    %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._RE_MIGR);
   %END;

%END;

%MEND RESOLVE_CLIENT_11_RE;

%RESOLVE_CLIENT_11_RE;

/*  New RP  */

*SASDOC--------------------------------------------------------------------------
| C.J.S APR2008
| CALL MACRO GET_NDC
+------------------------------------------------------------------------SASDOC*;
*SASDOC--------------------------------------------------------------------------
|JUNE 2012 - TARGET BY DRUG/ DSA AUTOMATION
|EB - CALL CUSTOM MACRO GET_NDC_TBD FOR PROGRAMS 105 AND 106 (TASK 21) 
+------------------------------------------------------------------------SASDOC*;

%macro get_ndc_exec;
%IF &PROGRAM_ID EQ 105 
    OR (&PROGRAM_ID EQ 106 AND &TASK_ID EQ 21) %THEN %DO;
%GET_NDC_TBD(DRUG_NDC_TBL=&DB2_TMP..&TABLE_PREFIX._NDC_QL,
         DRUG_NDC_TBL_RX=&ORA_TMP..&TABLE_PREFIX._NDC_RX,
         DRUG_NDC_TBL_RE=&ORA_TMP..&TABLE_PREFIX._NDC_RE,
         CLAIM_DATE_TBL=&DB2_TMP..&TABLE_PREFIX._RVW_DATES);
%END;
%ELSE %DO;
%GET_NDC(DRUG_NDC_TBL=&DB2_TMP..&TABLE_PREFIX._NDC_QL,
         DRUG_NDC_TBL_RX=&ORA_TMP..&TABLE_PREFIX._NDC_RX,
         DRUG_NDC_TBL_RE=&ORA_TMP..&TABLE_PREFIX._NDC_RE,
         CLAIM_DATE_TBL=&DB2_TMP..&TABLE_PREFIX._RVW_DATES);
%END;
%mend;
%get_ndc_exec;


*SASDOC--------------------------------------------------------------------------
|C.J.S Apr2008
| Added BEGIN AND END DATES IN FORMAT TO GO AGAINST ORACLE TABLES
+------------------------------------------------------------------------SASDOC*;
%MACRO DATES;
%GLOBAL CLAIM_BEGIN_DT 
		CLAIM_END_DT 
		CLAIM_BEGIN_DT1 
		CLAIM_END_DT1
		ALL_DRUG_IN1
    DRUG_GROUP2_EXIST_FLAG 
		CLM_BEGIN_DT 
		CLM_END_DT;

	%LET TBL_SRC = %STR(&DB2_TMP..&TABLE_PREFIX._RVW_DATES);

DATA _NULL_;
  SET &TBL_SRC;
  IF DRG_GROUP_SEQ_NB=1 THEN DO;
	  CALL SYMPUT('CLAIM_BEGIN_DT' || TRIM(LEFT(DRG_GROUP_SEQ_NB)), "'" || PUT(CLAIM_BEGIN_DT,yymmddd10.) || "'");
	  CALL SYMPUT('CLAIM_END_DT' || TRIM(LEFT(DRG_GROUP_SEQ_NB)), "'" || PUT(CLAIM_END_DT,yymmddd10.) || "'");

	  CALL SYMPUT('ALL_DRUG_IN' || TRIM(LEFT(DRG_GROUP_SEQ_NB)), PUT(ALL_DRUG_IN,1.));

    /** DATE MANIPULATIONS FOR ORACLE **/
	  CALL SYMPUT('CLM_BEGIN_DT', PUT(CLAIM_BEGIN_DT,YYMMDD10.));
	  CALL SYMPUT('CLM_END_DT', PUT(CLAIM_END_DT,YYMMDD10.));
  END;
  IF DRG_GROUP_SEQ_NB=2 THEN CALL SYMPUT('DRUG_GROUP2_EXIST_FLAG',PUT('1',1.));
                        ELSE CALL SYMPUT('DRUG_GROUP2_EXIST_FLAG',PUT('0',1.));
RUN;

PROC SQL NOPRINT;
 SELECT "'" || PUT(MIN(CLAIM_BEGIN_DT),yymmddd10.) || "'",
        "'" || PUT(MAX(CLAIM_END_DT),yymmddd10.) || "'"
        INTO :CLAIM_BEGIN_DT,
             :CLAIM_END_DT
 FROM &DB2_TMP..&TABLE_PREFIX._RVW_DATES;
QUIT;

%PUT NOTE: CLAIM_BEGIN_DT1 = &CLAIM_BEGIN_DT1; 
%PUT NOTE: CLAIM_END_DT1 = &CLAIM_END_DT1; 
%PUT NOTE: CLAIM_BEGIN_DT = &CLAIM_BEGIN_DT; 
%PUT NOTE: CLAIM_END_DT = &CLAIM_END_DT; 
%PUT NOTE: ALL_DRUG_IN1 = &ALL_DRUG_IN1;
%PUT NOTE: DRUG_GROUP2_EXIST_FLAG = &DRUG_GROUP2_EXIST_FLAG; 
	/*%PUT NOTE: CLAIM_BEGIN_DT_EDWPULL = &CLAIM_BEGIN_DT_EDWPULL;*/
	/*%PUT NOTE: CLAIM_END_DT_EDWPULL = &CLAIM_END_DT_EDWPULL;*/

%MEND DATES;
%DATES;

*SASDOC-------------------------------------------------------------------------
| GENERATE A LIST OF MACRO VARIABLES THAT WILL BE USED IN THE LOGIC.
+-----------------------------------------------------------------------SASDOC*;

%MACRO GET_WHERE_STRINGS;

%GLOBAL DELIVERY_SYSTEM_CONDITION 
		DRUG_FIELDS_LIST 
		DRUG_FIELDS_LIST_NDC 
		DRUG_FIELDS_FLAG 
		NDC_FIELD_FLAG 
		STR_TDRUG1 
		DRUG_JOIN_CONDITION 
		DRUG_NM_JOIN_CONDITION 
		LAST_FILL_DT_FLAG 
		ADDITIONAL_CLAIM_FIELDS 
		MESSAGE 
/* DEC 2013 BSR VOIDED CLAIMS */
		DRUG_NM_CONCAT;

%LET DS_STR=;
%LET DRUG_FIELDS_LIST=;
%LET NDC_FIELD_FLAG=0;
%LET ADDITIONAL_CLAIM_FIELDS=;

PROC SQL NOPRINT;
CREATE TABLE WORK.INITIATIVE_FIELDS AS
SELECT B.*
FROM  	&HERCULES..TFILE_FIELD AS A ,
		&HERCULES..TFIELD_DESCRIPTION AS B,
		&HERCULES..TPHASE_RVR_FILE AS C
WHERE 	INITIATIVE_ID=&INITIATIVE_ID
	AND PHASE_SEQ_NB=&PHASE_SEQ_NB
	AND A.FILE_ID = C.FILE_ID
	AND A.FIELD_ID = B.FIELD_ID;
QUIT;

PROC SQL NOPRINT;
	SELECT DISTINCT 'G.'|| COMPRESS(FIELD_NM)
	INTO : DRUG_FIELDS_LIST  SEPARATED BY ','
FROM WORK.INITIATIVE_FIELDS
WHERE FIELD_NM IN (	'DRUG_ABBR_PROD_NM',
					'DRUG_ABBR_STRG_NM',
					'DRUG_ABBR_DSG_NM',
					'DRUG_NDC_ID',
					'NHU_TYPE_CD');
QUIT;

PROC SQL NOPRINT;
	SELECT DISTINCT 'AND G.'|| COMPRESS(FIELD_NM) || '=' || 'B.' || COMPRESS(FIELD_NM)
	INTO : DRUG_NM_JOIN_CONDITION SEPARATED BY ' '
FROM WORK.INITIATIVE_FIELDS
WHERE FIELD_NM IN (	'DRUG_ABBR_PROD_NM',
					'DRUG_ABBR_STRG_NM',
					'DRUG_ABBR_DSG_NM',
					'DRUG_NDC_ID',
					'NHU_TYPE_CD');
QUIT;

/* DEC 2013 BSR VOIDED CLAIMS Begin */
PROC SQL NOPRINT;
	SELECT DISTINCT 'COALESCE(char('|| COMPRESS(FIELD_NM) || "),'')"
	INTO : DRUG_NM_CONCAT SEPARATED BY ' concat ' FROM WORK.INITIATIVE_FIELDS
WHERE FIELD_NM IN (	'DRUG_ABBR_PROD_NM',
					'DRUG_ABBR_STRG_NM',
					'DRUG_ABBR_DSG_NM',
					'DRUG_NDC_ID',
					'NHU_TYPE_CD');
QUIT;
/* DEC 2013 BSR VOIDED CLAIMS End */

PROC SQL NOPRINT;
	SELECT (COUNT(*)>0) AS  NDC_FIELD_FLAG FORMAT=1. 
	INTO  :  NDC_FIELD_FLAG
FROM WORK.INITIATIVE_FIELDS
WHERE FIELD_NM IN ('DRUG_NDC_ID');
QUIT;

PROC SQL NOPRINT;
	SELECT (COUNT(*)>0) AS  LAST_FILL_DT_FLAG FORMAT=1. 
	INTO  :  LAST_FILL_DT_FLAG
FROM WORK.INITIATIVE_FIELDS
WHERE FIELD_NM IN ('LAST_FILL_DT');
QUIT;

PROC SQL NOPRINT;
	SELECT DISTINCT 'C.' || SUBSTR(COMPRESS(SHORT_TX),6) || ' AS ' || COMPRESS(FIELD_NM)
    INTO : ADDITIONAL_CLAIM_FIELDS  SEPARATED BY ','
FROM WORK.INITIATIVE_FIELDS
WHERE FIELD_NM LIKE ('LAST_%') AND FIELD_NM NE 'LAST_FILL_DT';
QUIT;

%IF %LENGTH(&ADDITIONAL_CLAIM_FIELDS.)>0 %THEN 
	%LET ADDITIONAL_CLAIM_FIELDS=&ADDITIONAL_CLAIM_FIELDS.,;

%LET DRUG_FIELDS_FLAG=1;
%LET STR_TDRUG1=;
%LET DRUG_JOIN_CONDITION=;

%IF %LENGTH(&DRUG_FIELDS_LIST.) NE 0 %THEN %DO;
    %LET DRUG_FIELDS_LIST=,&DRUG_FIELDS_LIST ;
    %LET STR_TDRUG1=%STR(,&CLAIMSA..TDRUG1 AS G);
    %LET STR_DRUG_DNORM=%STR(,&ORA_TMP..v_DRUG AS G);                
    %LET DRUG_JOIN_CONDITION=%STR(AND E.DRUG_NDC_ID = G.DRUG_NDC_ID AND E.NHU_TYPE_CD = G.NHU_TYPE_CD);
	%IF &NDC_FIELD_FLAG.=0 %THEN 
		%LET DRUG_FIELDS_LIST_NDC=&DRUG_FIELDS_LIST,G.DRUG_NDC_ID,G.NHU_TYPE_CD ;
	%ELSE
		%LET DRUG_FIELDS_LIST_NDC=&DRUG_FIELDS_LIST;
%END;
%ELSE   
	%LET DRUG_FIELDS_FLAG=0;

PROC SQL NOPRINT;
    SELECT DELIVERY_SYSTEM_CD INTO :DS_STR SEPARATED BY ','
    FROM &HERCULES..TDELIVERY_SYS_EXCL
    WHERE INITIATIVE_ID = &INITIATIVE_ID;
QUIT;

%IF &DS_STR NE %THEN  
	%LET DELIVERY_SYSTEM_CONDITION=%STR(AND DELIVERY_SYSTEM_CD NOT IN (&DS_STR));
%ELSE  
	%LET DELIVERY_SYSTEM_CONDITION=;


%PUT DRUG_FIELDS_LIST=&DRUG_FIELDS_LIST;
%PUT DRUG_NM_JOIN_CONDITION=&DRUG_NM_JOIN_CONDITION;
%PUT NDC_FIELD_FLAG=&NDC_FIELD_FLAG.;
%PUT LAST_FILL_DT_FLAG=&LAST_FILL_DT_FLAG;
%PUT ADDITIONAL_CLAIM_FIELDS=&ADDITIONAL_CLAIM_FIELDS;
%PUT DRUG_JOIN_CONDITION=&DRUG_JOIN_CONDITION;
%PUT STR_TDRUG1=&STR_TDRUG1;
%PUT STR_DRUG_DNORM=&STR_DRUG_DNORM;
%PUT DRUG_FIELDS_FLAG=&DRUG_FIELDS_FLAG;
%PUT DRUG_FIELDS_LIST_NDC=&DRUG_FIELDS_LIST_NDC.;
%PUT DELIVERY_SYSTEM_CONDITION = &DELIVERY_SYSTEM_CONDITION;

%MEND GET_WHERE_STRINGS;

%GET_WHERE_STRINGS;

*SASDOC--------------------------------------------------------------------------
|C.J.S Apr2008
| Added BEGIN AND END DATES IN FORMAT TO GO AGAINST ORACLE TABLES
+------------------------------------------------------------------------SASDOC*;

%MACRO CLAIM_CALL;

*SASDOC--------------------------------------------------------------------------
| C.J.S APR2008
| CLAIM PULL FOR QL 
+------------------------------------------------------------------------SASDOC*;

%IF &QL_ADJ =1 %THEN %DO; 

	*SASDOC--------------------------------------------------------------------------
	| C.J.S APR2008
	| CLAIM PULL FOR QL WHICH WAS EMBEDED IN IDENTIFY_DRUG_THERAPY.SAS IS MOVED OUT
	| OF THE CODE INTO MACRO PULL_CLAIMS_FOR_QL AND IS CALLED FROM THE CODE
	+------------------------------------------------------------------------SASDOC*;


	%PULL_CLAIMS_FOR_QL(TBL_NAME_IN1=&DB2_TMP..&TABLE_PREFIX._QL,
						TBL_NAME_IN2=&DB2_TMP..&TABLE_PREFIX._RVW_DATES,
						TBL_NAME_IN3=&DB2_TMP..&TABLE_PREFIX._NDC_QL,
						TBL_NAME_OUT1=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_QL,
						TBL_NAME_OUT2=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_B_QL,
						TBL_NAME_OUT3=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_QL,
						ADJ_ENGINE = 'QL');		



%END;

*SASDOC--------------------------------------------------------------------------
| C.J.S APR2008
| CLAIM PULL FOR RXCLM OR RECAP 
+------------------------------------------------------------------------SASDOC*;

%IF &RX_ADJ =1 OR &RE_ADJ =1 %THEN %DO;

	*SASDOC--------------------------------------------------------------------------
	| C.J.S SEP2008
	| THIS IS A COMMON MACRO THAT PULLS ALL CLAIMS BASED ON THE CONDITION DEFINED 
	| IN THE HERCULES TABLES 
	+------------------------------------------------------------------------SASDOC*;
*SASDOC--------------------------------------------------------------------------
|JUNE 2012 - TARGET BY DRUG/ DSA AUTOMATION
|EB - CALL CUSTOM MACRO CLAIMS_PULL_EDW_TBD FOR PROGRAMS 105 AND 106 (TASK 21) 
|YM:OCT30.2012- %CLAIMS_PULL_EDW will have additional base fields as per Add Base col.
+------------------------------------------------------------------------SASDOC*;

	%IF &PROGRAM_ID EQ 105 
    OR (&PROGRAM_ID EQ 106 AND &TASK_ID EQ 21) %THEN %DO;
		%CLAIMS_PULL_EDW_TBD(DRUG_NDC_TABLE_RX = &ORA_TMP..&TABLE_PREFIX._NDC_RX,
	                 DRUG_NDC_TABLE_RE = &ORA_TMP..&TABLE_PREFIX._NDC_RE,
					 DRUG_RVW_DATES_TABLE = &ORA_TMP..&TABLE_PREFIX._RVW_DATES,
	                 RESOLVE_CLIENT_TABLE_RX = &ORA_TMP..&TABLE_PREFIX._RX,
	                 RESOLVE_CLIENT_TABLE_RE = &ORA_TMP..&TABLE_PREFIX._RE
	     );
	%END;
	%ELSE %DO;
		%CLAIMS_PULL_EDW(DRUG_NDC_TABLE_RX = &ORA_TMP..&TABLE_PREFIX._NDC_RX,
	                 DRUG_NDC_TABLE_RE = &ORA_TMP..&TABLE_PREFIX._NDC_RE,
	                 RESOLVE_CLIENT_TABLE_RX = &ORA_TMP..&TABLE_PREFIX._RX,
	                 RESOLVE_CLIENT_TABLE_RE = &ORA_TMP..&TABLE_PREFIX._RE,
					 RESOLVE_CLIENT_TABLE_RE_MIGR = &ORA_TMP..&TABLE_PREFIX._RE_MIGR
	                 );

	%END;

%END; 

*SASDOC--------------------------------------------------------------------------
| POST PROCESSING AFTER CLAIM PULL 
+------------------------------------------------------------------------SASDOC*;

*SASDOC--------------------------------------------------------------------------
| C.J.S APR2008
| FOR RXCLM 
+------------------------------------------------------------------------SASDOC*;
*SASDOC--------------------------------------------------------------------------
|JUNE 2012 - TARGET BY DRUG/ DSA AUTOMATION
|EB - CALL CUSTOM MACRO PULL_CLAIMS_FOR_EDW_TBD FOR PROGRAMS 105 AND 106 (TASK 21)
|YM:OCT30.2012- %PULL_CLAIMS_FOR_EDW  will have additional base fields as per Add Base col. 
+------------------------------------------------------------------------SASDOC*;

%IF &RX_ADJ =1 %THEN %DO;


    %IF &PROGRAM_ID EQ 105 
    OR (&PROGRAM_ID EQ 106 AND &TASK_ID EQ 21) %THEN %DO;
	%PULL_CLAIMS_FOR_EDW_TBD(TBL_NAME_IN1=&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX,
							  TBL_NAME_OUT1=&ORA_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_RX,
							  TBL_NAME_OUT2=&ORA_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_B_RX,
							  ADJ='X',
							  ADJ2=RX);
    %END;
	%ELSE %DO;
	%PULL_CLAIMS_FOR_EDW(TBL_NAME_IN1=&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX,
							  TBL_NAME_OUT1=&ORA_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_RX,
							  TBL_NAME_OUT2=&ORA_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_B_RX,
							  ADJ='X',
							  ADJ2=RX);
	%END;
%END;

*SASDOC--------------------------------------------------------------------------
| C.J.S APR2008
| FOR RECAP 
|YM:OCT30.2012- %PULL_CLAIMS_FOR_EDW  will have additional base fields as per Add Base col. 
+------------------------------------------------------------------------SASDOC*;

%IF &RE_ADJ =1 %THEN %DO;

   %IF &PROGRAM_ID EQ 105 
    OR (&PROGRAM_ID EQ 106 AND &TASK_ID EQ 21) %THEN %DO;
	%PULL_CLAIMS_FOR_EDW_TBD(TBL_NAME_IN1=&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RE,
							  TBL_NAME_OUT1=&ORA_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_RE,
							  TBL_NAME_OUT2=&ORA_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_B_RE,
							  ADJ='R',
	                          ADJ2=RE);
	%END;
	%ELSE %DO;
	%PULL_CLAIMS_FOR_EDW(TBL_NAME_IN1=&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RE,
							  TBL_NAME_OUT1=&ORA_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_RE,
							  TBL_NAME_OUT2=&ORA_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_B_RE,
							  ADJ='R',
	                          ADJ2=RE);
	%END;

%END;

%MEND CLAIM_CALL ;
%CLAIM_CALL;

*SASDOC--------------------------------------------------------------------------
| C.J.S APR2008
| CALL THE MACRO ELIGIBILITY_CHECK FOR ALL PROGRAMS EXCEPT QUALITY MAILINGS-105.
+------------------------------------------------------------------------SASDOC*;

%ELIGIBILITY_CHECK(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_B_QL,
				   TBL_NAME_IN_RX=&ORA_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_B_RX,
				   TBL_NAME_IN_RE=&ORA_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_B_RE,
				   TBL_NAME_OUT2=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_E_QL,
				   TBL_NAME_RX_OUT2=&ORA_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_E_RX,
				   TBL_NAME_RE_OUT2=&ORA_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_E_RE,
				   EXECUTE_CONDITION=%STR(1=1),
				   TBL_RESOLVE_CLIENT=&DB2_TMP..&TABLE_PREFIX._QL);


*SASDOC--------------------------------------------------------------------------
| C.J.S  APR2008
| CALL MACRO GET_MOC_PHONE
| THIS MACRO CALL ADDS THE MAIL ORDER PHARMACY AND CUSTOMER SERVICE PHONE TO THE CPG FILE
| NOTE: FOR RXCLM AND RECAP ADJUDICATIONS THESE TWO FIELDS BEING ADDED ARE SET TO NULL
+------------------------------------------------------------------------SASDOC*;

%MACRO ADD_MOC;

*SASDOC--------------------------------------------------------------------------
| FOR QL
+------------------------------------------------------------------------SASDOC*;

%IF &QL_ADJ = 1 %THEN %DO;
   %GET_MOC_CSPHONE(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_E_QL,
                   TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_G_QL);
%END;

*SASDOC--------------------------------------------------------------------------
| FOR RX
+------------------------------------------------------------------------SASDOC*;

%IF &RX_ADJ = 1 %THEN %DO;
  %GET_MOC_CSPHONE(MODULE=RX,
				   TBL_NAME_IN=&ORA_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_E_RX,
                   TBL_NAME_OUT=&ORA_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_G_RX);
%END;

*SASDOC--------------------------------------------------------------------------
| FOR RE
+------------------------------------------------------------------------SASDOC*;

%IF &RE_ADJ = 1 %THEN %DO;
  %GET_MOC_CSPHONE(MODULE=RE,
				   TBL_NAME_IN=&ORA_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_E_RE,
                   TBL_NAME_OUT=&ORA_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_G_RE);
%END;

%MEND ADD_MOC;
%ADD_MOC;

*SASDOC--------------------------------------------------------------------------
| POST PROCESSING FOR QL CLAIMS DATA
+------------------------------------------------------------------------SASDOC*;
%MACRO CLAIM_FIELDS;
/*YM:ADDED BELOW OPTIONS FOR TEST REMOVE IT IN PROD*/
/*AS "MACROGEN(GET_MOC_CSPHONE):   OPTIONS NOMLOGIC NOMPRINT NOSYMBOLGEN"*/
/*OPTIONS  MPRINT MPRINTNEST MLOGIC MLOGICNEST SYMBOLGEN SOURCE2;*/
%IF &QL_ADJ = 1 %THEN %DO;



%DROP_DB2_TABLE(TBL_NAME=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_B_QL);
/*YM:Add Base columns: New columns are added which are pulled from PULL_CLAIMS_FOR_QL */
  PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_B_QL    AS
      (  SELECT                  G.PRESCRIBER_ID AS NTW_PRESCRIBER_ID,
                                 G.PRESCRIBER_ID,
                                 G.CDH_BENEFICIARY_ID,
                                 G.PT_BENEFICIARY_ID,
                                 G.DRG_GROUP_SEQ_NB,
                                 G.DRG_SUB_GRP_SEQ_NB,
                                 G.BIRTH_DT,
                                 G.RX_COUNT_QY,
				 				 G.MEMBER_COST_AT,
                                 G.CLIENT_ID,
				 				 B.CLT_PLAN_GROUP_ID,
                                 G.CLT_PLAN_GROUP_ID2,
                                 G.CLIENT_NM,
                                 G.LAST_FILL_DT,
                                 B.CS_AREA_PHONE,
                                 B.MOC_PHM_CD,
				 				 G.ADJ_ENGINE,
                                 0 AS LTR_RULE_SEQ_NB,
								 G.DRUG_NDC_ID,
								 G.NHU_TYPE_CD
                                 &DRUG_FIELDS_LIST.,
								 G.RX_NB,          
								 G.DISPENSED_QY,
								 G.DAY_SUPPLY_QY,
								 G.REFILL_FILL_QY,
								 G.FORMULARY_TX,
								 G.GENERIC_NDC_IN,
								 G.BLG_REPORTING_CD ,
								 G.PLAN_CD,
								 G.PLAN_EXT_CD_TX,
								 G.GROUP_CD,
								 G.GROUP_EXT_CD_TX,
								 G.CLIENT_LEVEL_1 ,
							     G.CLIENT_LEVEL_2,
								 G.CLIENT_LEVEL_3,
								 G.MBR_ID,
%if &program_id. = 106 and &LAST_FILL_DT_FLAG. = 0 %then %do ; G.LAST_DELIVERY_SYS, %end;
							     G.GCN_CODE,
								 G.BRAND_GENERIC     ,
								 G.DEA_NB,
 								 G.PRESCRIBER_NPI_NB,
								 G.PHARMACY_NM,
								 G.GPI_THERA_CLS_CD
                  FROM  &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_QL               AS G,
                        &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_G_QL          AS B
      )DEFINITION ONLY NOT LOGGED INITIALLY
   ) BY DB2;
   DISCONNECT FROM DB2;
QUIT;
%SET_ERROR_FL;

PROC SQL;
	CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);

	EXECUTE(
		ALTER TABLE &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_B_QL 
		ACTIVATE NOT LOGGED INITIALLY  
	) BY DB2;

	EXECUTE(
		INSERT INTO &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_B_QL
			SELECT           
			G.PRESCRIBER_ID AS NTW_PRESCRIBER_ID,
			G.PRESCRIBER_ID,
			G.CDH_BENEFICIARY_ID,
			G.PT_BENEFICIARY_ID,
			G.DRG_GROUP_SEQ_NB,
			G.DRG_SUB_GRP_SEQ_NB,
			MAX(G.BIRTH_DT) AS BIRTH_DT,
			G.RX_COUNT_QY,
			G.MEMBER_COST_AT,
			G.CLIENT_ID,
			B.CLT_PLAN_GROUP_ID,
			G.CLT_PLAN_GROUP_ID2,
			G.CLIENT_NM,
			MAX(G.LAST_FILL_DT) AS LAST_FILL_DT,
			CS_AREA_PHONE,
			MOC_PHM_CD,
			G.ADJ_ENGINE,
			0 AS LTR_RULE_SEQ_NB,
			G.DRUG_NDC_ID,
            G.NHU_TYPE_CD
			&DRUG_FIELDS_LIST.,
     		G.RX_NB,         
			G.DISPENSED_QY,
			G.DAY_SUPPLY_QY,
			G.REFILL_FILL_QY,
			G.FORMULARY_TX,
		    G.GENERIC_NDC_IN,
			G.BLG_REPORTING_CD ,
			G.PLAN_CD,
			G.PLAN_EXT_CD_TX,
			G.GROUP_CD,
			G.GROUP_EXT_CD_TX,
     		G.CLIENT_LEVEL_1 ,
			G.CLIENT_LEVEL_2,
			G.CLIENT_LEVEL_3,
			G.MBR_ID,
%if &program_id. = 106 and &LAST_FILL_DT_FLAG. = 0 %then %do ; G.LAST_DELIVERY_SYS, %end;
			G.GCN_CODE,
			G.BRAND_GENERIC     ,
			G.DEA_NB,
 			G.PRESCRIBER_NPI_NB,
			G.PHARMACY_NM,
			G.GPI_THERA_CLS_CD
		FROM  &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_QL AS G,
			  &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_G_QL AS B
		WHERE G.PRESCRIBER_ID=B.PRESCRIBER_ID
          	  AND G.CDH_BENEFICIARY_ID=B.CDH_BENEFICIARY_ID
		  AND G.PT_BENEFICIARY_ID=B.PT_BENEFICIARY_ID		  
		GROUP BY G.PRESCRIBER_ID,
				 G.DRG_GROUP_SEQ_NB,
				 G.DRG_SUB_GRP_SEQ_NB,
				 G.CDH_BENEFICIARY_ID,
				 G.PT_BENEFICIARY_ID,
				 G.RX_COUNT_QY,
				 G.MEMBER_COST_AT,
				 G.CLIENT_ID,
				 B.CLT_PLAN_GROUP_ID,
				 G.CLT_PLAN_GROUP_ID2,
				 G.CLIENT_NM,
				 CS_AREA_PHONE,
				 MOC_PHM_CD,
				 G.ADJ_ENGINE,
				 G.DRUG_NDC_ID,
				 G.NHU_TYPE_CD
				 &DRUG_FIELDS_LIST.,
				 G.RX_NB,         
				 G.DISPENSED_QY,
				 G.DAY_SUPPLY_QY,
				 G.REFILL_FILL_QY,
				 G.FORMULARY_TX,
				 G.GENERIC_NDC_IN,
				 G.DRUG_ABBR_DSG_NM,
				 G.BLG_REPORTING_CD ,
				 G.PLAN_CD,
				 G.PLAN_EXT_CD_TX,
				 G.GROUP_CD,
				 G.GROUP_EXT_CD_TX,
				 G.CLIENT_LEVEL_1 ,
				 G.CLIENT_LEVEL_2,
                 G.CLIENT_LEVEL_3,
				 G.MBR_ID,
%if &program_id. = 106 and &LAST_FILL_DT_FLAG. = 0 %then %do ; G.LAST_DELIVERY_SYS, %end;
				 G.GCN_CODE,
				 G.BRAND_GENERIC     ,
				 G.DEA_NB,
 				 G.PRESCRIBER_NPI_NB,
				 G.PHARMACY_NM,
				 G.GPI_THERA_CLS_CD
	) BY DB2;

%PUT SQLXRC=&SQLXRC SYSERR=&SYSERR;
%RESET_SQL_ERR_CD;
*DISCONNECT FROM DB2;
QUIT;



%MACRO ADD_LAST_CLAIM_FIELDS;

 %GLOBAL CREATE_BASE_FILE_TBL_IN;
 %LET CREATE_BASE_FILE_TBL_IN=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_B_QL;
 %DROP_DB2_TABLE(TBL_NAME=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_C_QL);
 %IF &LAST_FILL_DT_FLAG. > 0 %THEN %DO;

/* DEC 2013 BSR VOIDED CLAIMS Begin */
	proc contents	data = &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_B_QL 
			out = temp01_b noprint;
	run;

	proc sort data = temp01_b;
		by varnum;
	run;

	PROC SQL NOPRINT;
		SELECT 'G.'|| COMPRESS(name) 
		INTO : SELECT_G SEPARATED BY ', '
	FROM WORK.temp01_b ;
	QUIT;

	%put NOTE: SELECT_G = &SELECT_G. ;
/* DEC 2013 BSR VOIDED CLAIMS end */

	 PROC SQL;
	   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	   EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_C_QL    AS
/* DEC 2013 BSR VOIDED CLAIMS begin */
	      (SELECT  &SELECT_G. ,
	               &ADDITIONAL_CLAIM_FIELDS.
	               (1.0E16) AS RECORD_ID, 0 as ROW_NUMBER
/* DEC 2013 BSR VOIDED CLAIMS end */
		FROM    &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_B_QL AS G,
	               &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_QL AS B,
	               &CLAIMSA..&CLAIM_HIS_TBL AS C
	      )DEFINITION ONLY NOT LOGGED INITIALLY
	   ) BY DB2;
	   DISCONNECT FROM DB2;
	   QUIT;

	PROC SQL;
	   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
		EXECUTE(
				ALTER TABLE &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_C_QL 
				ACTIVATE NOT LOGGED INITIALLY  
				) BY DB2;
		EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_C_QL

/* DEC 2013 BSR VOIDED CLAIMS begin - removing duplicates */
				WITH DRUG_NM_B_QL AS
				(SELECT &DRUG_NM_CONCAT. AS DRUG_NM_JOIN, G.*
				FROM &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_B_QL AS G),

				DRUG_NM_QL AS
				(SELECT &DRUG_NM_CONCAT. AS DRUG_NM_JOIN, B.*
				FROM &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_QL AS B),

	            PT_NDC2 AS

	            (SELECT   &SELECT_G. ,
	                      &ADDITIONAL_CLAIM_FIELDS.
	                      (10000.00*C.BENEFIT_REQUEST_ID +C.BRLI_NB)    AS RECORD_ID
			     FROM    DRUG_NM_B_QL AS G,
	                     DRUG_NM_QL AS B,
/****		     FROM    &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_B_QL AS G, */
/****	                     &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_QL AS B,   */
	                     &CLAIMSA..&CLAIM_HIS_TBL AS C
		 WHERE   G.NTW_PRESCRIBER_ID=B.PRESCRIBER_ID
	               AND   G.CDH_BENEFICIARY_ID=B.CDH_BENEFICIARY_ID
	               AND   G.PT_BENEFICIARY_ID=B.PT_BENEFICIARY_ID
	               AND   G.LAST_FILL_DT=B.LAST_FILL_DT
			AND   G.drug_nm_join=B.drug_nm_join
/****	               &DRUG_NM_JOIN_CONDITION. */
			&DELIVERY_SYSTEM_CONDITION.
	               AND   B.PRESCRIBER_ID=C.NTW_PRESCRIBER_ID
	               AND   B.PT_BENEFICIARY_ID=C.PT_BENEFICIARY_ID
	               AND   B.DRUG_NDC_ID = C.DRUG_NDC_ID
	               AND   B.NHU_TYPE_CD = C.NHU_TYPE_CD
	               AND   B.LAST_FILL_DT=C.FILL_DT
	               AND   C.RX_NB = G.RX_NB
	               AND   B.RX_NB = G.RX_NB
	               AND   C.CLT_PLAN_GROUP_ID = G.CLT_PLAN_GROUP_ID2
	               AND   C.FILL_DT BETWEEN &CLAIM_BEGIN_DT. AND &CLAIM_END_DT.
	               AND NOT EXISTS (SELECT 1
	                              FROM &CLAIMSA..&CLAIM_HIS_TBL
	                              WHERE   C.BENEFIT_REQUEST_ID = BENEFIT_REQUEST_ID
	                                AND   C.BRLI_NB = BRLI_NB
	                                AND   BRLI_VOID_IN > 0)
	                               ) ,
	               PT_NDC as (
	               SELECT *
	               FROM (SELECT B.*,
	                     ROW_NUMBER() OVER (PARTITION BY PT_BENEFICIARY_ID, PRESCRIBER_ID, DRUG_NDC_ID, CLT_PLAN_GROUP_ID2 ORDER BY LAST_FILL_DT DESC) ROW_ID
	               	      FROM PT_NDC2 B) WHERE ROW_ID=1)
/* DEC 2013 BSR VOIDED CLAIMS end */
		       SELECT G.* FROM PT_NDC AS G

	              ) BY DB2;
  %PUT SQLXRC=&SQLXRC SYSERR=&SYSERR;
  %RESET_SQL_ERR_CD;
   * DISCONNECT FROM DB2;
QUIT;

%SET_ERROR_FL;

%LET CREATE_BASE_FILE_TBL_IN=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_C_QL;


%END;

%MEND ADD_LAST_CLAIM_FIELDS; 
%ADD_LAST_CLAIM_FIELDS;

%END;     /* END THE QL PROCESS FOR CLAIM FIELDS*/

%MEND CLAIM_FIELDS;
%CLAIM_FIELDS;

%let err_fl=0;

*SASDOC--------------------------------------------------------------------------
| C.J.S  JUN2008
| CALL THE MACRO TO DOWNLOAD EDW TO UNIX IN ORDER TO COMBINE THE ADJUDICATIONS
| N. Williams 22MAR2010 - Add logic to set nhu_type_cd in edw2unix if its value
| is missing. 
+------------------------------------------------------------------------SASDOC*;

%MACRO EDW2UNIX_CALL;
 %DROP_DB2_TABLE(TBL_NAME=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_C_QL2);
/* %include "/PRG/sas&sysmode.1/hercules/katya/macros/edw2unix.sas";*/

%IF &QL_ADJ EQ 1 %THEN %DO;

/*	DATA &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_C_QL2(DROP = CLT_PLAN_GROUP_ID2);*/
/*	 FORMAT CLIENT_LEVEL_1 $22. CLIENT_LEVEL_2 $22. CLIENT_LEVEL_3 $22.;*/
/*	 SET &CREATE_BASE_FILE_TBL_IN. ;*/
/*	 CLIENT_LEVEL_1 = PUT(CLT_PLAN_GROUP_ID2,$22.);*/
/*     CLIENT_LEVEL_2 = '';*/
/*     CLIENT_LEVEL_3 = '';*/
/*	RUN;*/

	DATA &DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_C_QL2(DROP = CLT_PLAN_GROUP_ID2);
	 FORMAT CLIENT_LEVEL_2 $22. CLIENT_LEVEL_3 $22.;
	 SET &CREATE_BASE_FILE_TBL_IN. ;
	 CLIENT_LEVEL_1 = CLT_PLAN_GROUP_ID2;
     CLIENT_LEVEL_2 = '';
     CLIENT_LEVEL_3 = '';	 
	 IF MISSING(NHU_TYPE_CD) THEN NHU_TYPE_CD=1;
	RUN;

	%EDW2UNIX(TBL_NM_IN=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_NM_C_QL2
			 ,TBL_NM_OUT=DATA.&TABLE_PREFIX._PT_DRUG_NM_C_QL2
	         ,ADJ_ENGINE=1  );
%END;

%IF &RX_ADJ EQ 1 %THEN %DO;

	%EDW2UNIX(TBL_NM_IN=&ORA_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_G_RX
			 ,TBL_NM_OUT=DATA.&TABLE_PREFIX._PT_DRUG_GROUP_G_RX
	         ,ADJ_ENGINE=2   );

%END;
%IF &RE_ADJ EQ 1 %THEN %DO;

	%EDW2UNIX(TBL_NM_IN=&ORA_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_G_RE
			 ,TBL_NM_OUT=DATA.&TABLE_PREFIX._PT_DRUG_GROUP_G_RE
	         ,ADJ_ENGINE=3  );

%END;

%MEND EDW2UNIX_CALL;
%EDW2UNIX_CALL;

*SASDOC--------------------------------------------------------------------------
| CALL THE MACRO COMBINE_ADJ 
+------------------------------------------------------------------------SASDOC*;

%COMBINE_ADJ(TBL_NM_QL=DATA.&TABLE_PREFIX._PT_DRUG_NM_C_QL2,
             TBL_NM_RX=DATA.&TABLE_PREFIX._PT_DRUG_GROUP_G_RX,
             TBL_NM_RE=DATA.&TABLE_PREFIX._PT_DRUG_GROUP_G_RE,
             TBL_NM_OUT=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB); 


*SASDOC--------------------------------------------------------------------------
|JUNE 2012 - TARGET BY DRUG/ DSA AUTOMATION
|EB - CONSOLIDATE MULTIPLE CLAIMS FOR THE SAME PRSN_CURR_KEY FOR DSA/NCQA (105)
| DO NOT CONSOLIDATE IF PRSN_CURR_KEY IS NOT POPULATED
+------------------------------------------------------------------------SASDOC*;

%MACRO WRAP_PLAN_CNSLD;
%IF (&PROGRAM_ID EQ 105) AND (&RE_ADJ. EQ 1 OR &RX_ADJ. EQ 1) 
 AND %SYSFUNC(EXIST(&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB)) /*prevent execution if tables not there */
 %THEN %DO;
DATA CLMS_AFTER_SORT_TEMP1 
CLMS_AFTER_SORT_TEMP2;
SET &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB;
IF PRSN_CURR_KEY = . THEN OUTPUT CLMS_AFTER_SORT_TEMP1;
ELSE OUTPUT CLMS_AFTER_SORT_TEMP2;

PROC SORT DATA = CLMS_AFTER_SORT_TEMP2;
BY 
%IF (&TRGT_RECIPIENT_CD EQ 2 OR &TRGT_RECIPIENT_CD EQ 3)
 %THEN %DO;
PRACTITIONER_ID 
 %END;
PRSN_CURR_KEY 
DRUG_NDC_ID 
LAST_FILL_DT 
CLIENT_LEVEL_1;
RUN;

DATA CLMS_AFTER_SORT_TEMP3 (DROP=MEMBER_COST_AT RX_COUNT_QY DISPENSED_QY DAY_SUPPLY_QY);
SET CLMS_AFTER_SORT_TEMP2;
RETAIN TOT_MEMBER_COST_AT TOT_RX_COUNT_QY TOT_DISPENSED_QY TOT_DAY_SUPPLY_QY 0;
BY 
%IF (&TRGT_RECIPIENT_CD EQ 2 OR &TRGT_RECIPIENT_CD EQ 3)
 %THEN %DO;
PRACTITIONER_ID 
 %END;
PRSN_CURR_KEY 
DRUG_NDC_ID;
IF FIRST.DRUG_NDC_ID THEN DO;
	TOT_MEMBER_COST_AT = 0;
	TOT_RX_COUNT_QY    = 0;
	TOT_DISPENSED_QY       = 0;
	TOT_DAY_SUPPLY_QY      = 0;
END;
	TOT_MEMBER_COST_AT = TOT_MEMBER_COST_AT + MEMBER_COST_AT;
	TOT_RX_COUNT_QY    = TOT_RX_COUNT_QY + RX_COUNT_QY;
	TOT_DISPENSED_QY   = TOT_DISPENSED_QY + DISPENSED_QY;
    TOT_DAY_SUPPLY_QY  = TOT_DAY_SUPPLY_QY + DAY_SUPPLY_QY;
IF LAST.DRUG_NDC_ID THEN OUTPUT;
RUN;


PROC DATASETS LIBRARY=WORK NOLIST;
MODIFY CLMS_AFTER_SORT_TEMP3;
RENAME 
TOT_MEMBER_COST_AT     = MEMBER_COST_AT
	TOT_RX_COUNT_QY    = RX_COUNT_QY
	TOT_DISPENSED_QY   = DISPENSED_QY
    TOT_DAY_SUPPLY_QY  = DAY_SUPPLY_QY;
QUIT;


DATA CLMS_AFTER_SORT;
SET CLMS_AFTER_SORT_TEMP1
CLMS_AFTER_SORT_TEMP3;
RUN;

%DROP_DB2_TABLE(TBL_NAME=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB);

DATA &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB;
SET CLMS_AFTER_SORT;
RUN;


%END;

%MEND WRAP_PLAN_CNSLD;

%WRAP_PLAN_CNSLD;
*SASDOC--------------------------------------------------------------------------
| CALL THE MACRO PARTICIPANT_PARMS.
+------------------------------------------------------------------------SASDOC*;

/*%include "/PRG/sas&sysmode.1/hercules/katya/macros/participant_parms.sas";*/
 %PARTICIPANT_PARMS(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB,
                    TBL_NAME_OUT2=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB_B);

*SASDOC--------------------------------------------------------------------------
| CALL THE MACRO PRESCRIBER_PARMS 
+------------------------------------------------------------------------SASDOC*;

 %PRESCRIBER_PARMS(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB_B,
                   TBL_NAME_OUT2=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB_C);

*SASDOC--------------------------------------------------------------------------
|JUNE 2012 - TARGET BY DRUG/ DSA AUTOMATION
|EB - Create and populate tables for RE and RX for members with missing QL BENE ID 
+------------------------------------------------------------------------SASDOC*;


%MACRO POPULATE_ADDR_TABLES;
%IF ((&PROGRAM_ID EQ 106 AND &TASK_ID EQ 21) OR &PROGRAM_ID EQ 105) AND (&RE_ADJ. EQ 1 OR &RX_ADJ. EQ 1) 
 AND %SYSFUNC(EXIST(&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB_C)) /*prevent execution if tables not there */
 %THEN %DO;

%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RE); 
%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX); 



			PROC SQL NOPRINT;
					CONNECT TO ORACLE(PATH=&GOLD );
		  			EXECUTE 
					(
					CREATE TABLE &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RE
					(MBR_ID                     VARCHAR2(25)
                    ,MBR_GID                    NUMBER
					,MBR_FIRST_NM               VARCHAR2(40)
					,MBR_LAST_NM                VARCHAR2(40)
					,ADDR_LINE1_TXT             VARCHAR2(60)
					,ADDR_LINE2_TXT             VARCHAR2(60)
					,ADDR_CITY_NM               VARCHAR2(60)
					,ADDR_ST_CD                 VARCHAR2(3)
					,ADDR_ZIP_CD                VARCHAR2(20)
					)
		  			) BY ORACLE;

			  			EXECUTE 
					(
					CREATE TABLE &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX
					(MBR_ID                     VARCHAR2(25)
                    ,MBR_GID                    NUMBER
					,MBR_FIRST_NM               VARCHAR2(40)
					,MBR_LAST_NM                VARCHAR2(40)
					,ADDR_LINE1_TXT             VARCHAR2(60)
					,ADDR_LINE2_TXT             VARCHAR2(60)
					,ADDR_CITY_NM               VARCHAR2(60)
					,ADDR_ST_CD                 VARCHAR2(3)
					,ADDR_ZIP_CD                VARCHAR2(20)
					)
		  			) BY ORACLE;
		    		DISCONNECT FROM ORACLE;
				QUIT;
				RUN;
%SET_ERROR_FL;

DATA FINAL_CLAIMS;
SET &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB_C;
RUN;



				PROC SQL;
				INSERT INTO &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RE
				SELECT MBR_ID, MBR_GID, MBR_FIRST_NM, MBR_LAST_NM, ADDR_LINE1_TXT, ADDR_LINE2_TXT,
                       ADDR_CITY_NM, ADDR_ST_CD, ADDR_ZIP_CD
                FROM FINAL_CLAIMS
				WHERE ADJ_ENGINE = 'RE';
				QUIT;
				RUN;



	
				PROC SQL;
				INSERT INTO &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX
				SELECT MBR_ID, MBR_GID, MBR_FIRST_NM, MBR_LAST_NM, ADDR_LINE1_TXT, ADDR_LINE2_TXT,
                       ADDR_CITY_NM, ADDR_ST_CD, ADDR_ZIP_CD
                FROM FINAL_CLAIMS
				WHERE ADJ_ENGINE = 'RX';
				QUIT;
				RUN;

%END;
%MEND POPULATE_ADDR_TABLES;


%POPULATE_ADDR_TABLES;


*SASDOC--------------------------------------------------------------------------
| CALL THE MACRO CREATE_BASE_FILE
+------------------------------------------------------------------------SASDOC*;

 %CREATE_BASE_FILE(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB_C);



*SASDOC-------------------------------------------------------------------------
| Remove duplicate records based on participant and drug, since one letter per ndc
| will be sent. We will keep only the maximum last_fill_dt value
| per participant per NDC - AK - JAN2013
+-----------------------------------------------------------------------SASDOC*;

%macro del_dupes;

%IF %SYSFUNC(EXIST(DATA_PND.&TABLE_PREFIX._1)) %THEN %DO;
%delete_duplicates(TBL_IN=DATA_PND.&TABLE_PREFIX._1);
%delete_duplicates(TBL_IN=DATA_RES.&TABLE_PREFIX._1);



%END;

%IF %SYSFUNC(EXIST(DATA_PND.&TABLE_PREFIX._2)) %THEN %DO;
%delete_duplicates(TBL_IN=DATA_PND.&TABLE_PREFIX._2);
%delete_duplicates(TBL_IN=DATA_RES.&TABLE_PREFIX._2);
%END;
%mend del_dupes;
%del_dupes;


*SASDOC-------------------------------------------------------------------------
| CHECK MACRO CHECK_DOCUMENT
+-----------------------------------------------------------------------SASDOC*;

 %CHECK_DOCUMENT;
*SASDOC--------------------------------------------------------------------------
|JUNE 2012 - TARGET BY DRUG/ DSA AUTOMATION
|EB - Remove invalid provider records 
+------------------------------------------------------------------------SASDOC*;
%let TABLE_PREFIX_LOWCASE = %lowcase(&TABLE_PREFIX.);
%MACRO POST_PROCESSING;

%IF ((&PROGRAM_ID EQ 106 AND &TASK_ID EQ 21) OR &PROGRAM_ID EQ 105) 
AND (&RE_ADJ. EQ 1 OR &RX_ADJ. EQ 1)
AND (&TRGT_RECIPIENT_CD EQ 2 OR &TRGT_RECIPIENT_CD EQ 3)
 %THEN %DO;

DATA DATA_PND.&TABLE_PREFIX_LOWCASE._2;
SET  DATA_PND.&TABLE_PREFIX_LOWCASE._2;
IF prctrmail =1 OR &QL_ADJ. EQ 1 THEN OUTPUT;
RUN;
%SET_ERROR_FL;

DATA DATA_RES.&TABLE_PREFIX_LOWCASE._2;
SET  DATA_RES.&TABLE_PREFIX_LOWCASE._2;
IF prctrmail =1 OR &QL_ADJ. EQ 1 THEN OUTPUT;
RUN;
%SET_ERROR_FL;

%END;

%MEND POST_PROCESSING;

%POST_PROCESSING;

*SASDOC-------------------------------------------------------------------------
| CHECK MACRO AUTORELEASE_FILE
+-----------------------------------------------------------------------SASDOC*;
 %AUTORELEASE_FILE(INIT_ID=&INITIATIVE_ID, PHASE_ID=&PHASE_SEQ_NB);


*SASDOC-------------------------------------------------------------------------
| CALL MACRO INSERT_TCMCTN_PENDING
------------------------------------------------------------------------------SASDOC*;
%INSERT_TCMCTN_PENDING(INIT_ID=&INITIATIVE_ID, PHASE_ID=&PHASE_SEQ_NB);

*SASDOC-------------------------------------------------------------------------
| CALL MACRO UPDATE_TASK_TS WITH INPUT PARAMETER JOB_COMPLETE_TS
------------------------------------------------------------------------------SASDOC*;

%UPDATE_TASK_TS(JOB_COMPLETE_TS);


**SASDOC -----------------------------------------------------------------------------
 | Generate client_initiative_summary report
 + ----------------------------------------------------------------------------SASDOC*;

 PROC SQL;
	 SELECT MAX(REQUEST_ID) INTO :MAX_ID
	 FROM HERCULES.TREPORT_REQUEST;
 QUIT;
 %PUT  &MAX_ID;

 PROC SQL;
	INSERT INTO HERCULES.TREPORT_REQUEST
	(REQUEST_ID, REPORT_ID, REQUIRED_PARMTR_ID, SEC_REQD_PARMTR_ID, JOB_REQUESTED_TS,
	 JOB_START_TS, JOB_COMPLETE_TS, HSC_USR_ID , HSC_TS , HSU_USR_ID , HSU_TS )

	VALUES
	(%EVAL(&MAX_ID.+1), 11, &INITIATIVE_ID., &PHASE_SEQ_NB., %SYSFUNC(DATETIME()), %SYSFUNC(DATETIME()), 
	 NULL, 'QCPAP020' , %SYSFUNC(DATETIME()), 'QCPAP020', %SYSFUNC(DATETIME()));
 QUIT;

 OPTIONS SYSPARM="REQUEST_ID=%EVAL(&MAX_ID.+1)" ;

 %INCLUDE "/%LOWCASE(herc&sysmode/prg/hercules/reports/client_initiative_summary.sas)";
**SASDOC -----------------------------------------------------------------------------
 | Generate receiver_listing report
 + ----------------------------------------------------------------------------SASDOC*;

 PROC SQL;
	 SELECT MAX(REQUEST_ID) INTO :MAX_ID
	 FROM HERCULES.TREPORT_REQUEST;
 QUIT;
 %PUT  &MAX_ID;

 PROC SQL;
	INSERT INTO HERCULES.TREPORT_REQUEST
	(REQUEST_ID, REPORT_ID, REQUIRED_PARMTR_ID, SEC_REQD_PARMTR_ID, JOB_REQUESTED_TS,
	 JOB_START_TS, JOB_COMPLETE_TS, HSC_USR_ID , HSC_TS , HSU_USR_ID , HSU_TS )

	VALUES
	(%EVAL(&MAX_ID.+1), 15, &INITIATIVE_ID., &PHASE_SEQ_NB., %SYSFUNC(DATETIME()), %SYSFUNC(DATETIME()), 
	 NULL, 'QCPAP020' , %SYSFUNC(DATETIME()), 'QCPAP020', %SYSFUNC(DATETIME()));
 QUIT;

 OPTIONS SYSPARM="REQUEST_ID=%EVAL(&MAX_ID.+1)" ;
 %INCLUDE "/%LOWCASE(herc&sysmode/prg/hercules/reports/receiver_listing.sas)";

