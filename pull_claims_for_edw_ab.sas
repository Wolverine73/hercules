/***HEADER -------------------------------------------------------------------------
|  MACRO NAME:     PULL_CLAIMS_FOR_EDW.SAS
|
|  PURPOSE: CLAIMS FOR RXCLAIM AND RECAP
|          THIS MACRO IS USED TO PULL CLAIMS FOR SEVERAL TASKS (7, 11, 13, 19, 21).
|           THE TASKS DIFFER IN THAT THEY INCLUDE NO DRUG INFORMATION ON THE
|           FILE LAYOUT (TASK ID 11), DRUG NAME ONLY (TASK ID 19) OR DRUG AND
|           STRENGTH (TASK ID 21).  ADDITIONALLY, THESE TASKS ARE SHARED AMONG
|           DIFFERENT CAREMARK PROGRAMS.  SOME MACROS EXECUTE CONDITIONALLY
|           BASED ON PROGRAM. 
|
|  INPUT:      
|                        &DSS_CLIN..V_MBR MBR
|                        &DSS_CLIN..V_PRCTR_DENORM PRCTR
|                        &DSS_CLIN..V_ALGN_LVL_DENORM 	
|                        &DSS_CLIN..V_CLAIM_CORE_PAID
|                        &DSS_CLIN..V_PHMCY_DENORM PHMCY
|
|  OUTPUT:     STANDARD DATASETS IN /RESULTS AND /PENDING DIRECTORIES
|
|
|  HISTORY:    HERCULES VERSION  2.1.01
|  MAY 2008 - CARL STARKS THIS IS A NEW MACRO CREATED TO PULL CLAIMS FOR RXCLAIMS 
|                         AND RECAP - EDW DATA
|			- Hercules Version  2.1.2.01
|  AUG 2009 - N. Williams - Add logic for program_id(105) to include delivery system cd.
+-------------------------------------------------------------------------------HEADER*/



%MACRO PULL_CLAIMS_FOR_EDW(TBL_NAME_IN1=,
								TBL_NAME_OUT1=,
								TBL_NAME_OUT2=,
								ADJ=,
						   		ADJ2=);

OPTIONS MPRINT MLOGIC;

%PUT "TABLE TO BE DROPPED &TBL_NAME_OUT1.";
%PUT "TABLE TO BE DROPPED &TBL_NAME_OUT2.";
%DROP_ORACLE_TABLE(TBL_NAME=&TBL_NAME_OUT1.);
%DROP_ORACLE_TABLE(TBL_NAME=&TBL_NAME_OUT2.);

/** BECAUSE OF DATA ISSUES THE DATA IS ROLLED UP AT PT_BENEFICIARY_ID,
     CDH_BENEFICIARY_ID,  CLIENT_LEVEL_1/2/3, DRUG_NDC_ID ETC..
    SAME PT_BENEFICIARY_ID HAS DIFFERENT MBR_ID
    SAME CLIENT_LEVEL_1/2/3 HAS DIFFERENT ALGN_LVL_GID_KEY
    BUT THIS SHOULD BE RUN ONLY PT_BENEFICIARY_ID IS NOT NULL

    IF PT_BENEFICIARY_ID IS NULL THEN MBR_ID SHOULD BE INCLUDED IN THE GROUP BY
    OTHERWISE ALL MISSING PT_BENEFICIARY_ID WILL BE ROLLED UP TOGETHER **/

%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..TMP_EDW_PULL_&INITIATIVE_ID._&ADJ2.);

PROC SQL NOPRINT;
	CONNECT TO ORACLE(PATH=&GOLD );
	Execute
	(
	  CREATE TABLE &ORA_TMP..TMP_EDW_PULL_&INITIATIVE_ID._&ADJ2. AS  
	  SELECT 
          E.PT_BENEFICIARY_ID,
          E.CDH_BENEFICIARY_ID,
          MAX(E.CLIENT_NM) AS CLIENT_NM,
		  E.PRESCRIBER_ID,
		  MAX(E.PRACTITIONER_ID) AS PRACTITIONER_ID,
          MAX(E.MBR_GID) AS MBR_GID,
          MAX(E.MBR_ID) AS MBR_ID, 
          MAX(E.ALGN_LVL_GID_KEY) AS ALGN_LVL_GID_KEY,
          E.CLIENT_LEVEL_1,
          E.CLIENT_LEVEL_2,
          E.CLIENT_LEVEL_3,
          MAX(E.CLIENT_ID) AS CLIENT_ID,
          MAX(E.PAYER_ID) AS PAYER_ID,
		  MAX(E.DRUG_GID) AS DRUG_GID,
          E.LTR_RULE_SEQ_NB,
		  E.ADJ_ENGINE,
          E.DRG_GROUP_SEQ_NB,
          E.DRG_SUB_GRP_SEQ_NB,
          E.DRUG_NDC_ID,
		  E.NHU_TYPE_CD,
          MAX(E.BIRTH_DT) AS BIRTH_DT,
          MAX(E.LAST_FILL_DT) AS LAST_FILL_DT,
          MAX(E.DRUG_ABBR_PROD_NM) AS DRUG_ABBR_PROD_NM,
          MAX(E.DRUG_ABBR_STRG_NM) AS DRUG_ABBR_STRG_NM,
          MAX(E.DRUG_ABBR_DSG_NM) AS DRUG_ABBR_DSG_NM,
		  MAX(E.GCN_CODE) AS GCN,
		  SUM(E.MEMBER_COST_AT) AS MEMBER_COST_AT,
		  SUM(E.RX_COUNT_QY) AS RX_COUNT_QY
		  %IF &PROGRAM_ID. = 105 %THEN %DO;
		     ,CAST(E.DELIVERY_SYSTEM_CD AS NUMBER) AS LAST_DELIVERY_SYS
		  %END;
       FROM &TBL_NAME_IN1 E
	   WHERE E.PT_BENEFICIARY_ID IS NOT NULL
       GROUP BY 
          E.PT_BENEFICIARY_ID,
          E.CDH_BENEFICIARY_ID,
/*          E.CLIENT_NM,*/
		  E.PRESCRIBER_ID,
/*		  E.PRACTITIONER_ID,*/
/*          E.MBR_GID,*/
/*          E.MBR_ID, */
/*          E.ALGN_LVL_GID_KEY,*/
          E.CLIENT_LEVEL_1,
          E.CLIENT_LEVEL_2,
          E.CLIENT_LEVEL_3,
/*          E.CLIENT_ID,*/
/*          E.PAYER_ID,*/
/*		  E.DRUG_GID,*/
          E.LTR_RULE_SEQ_NB,
		  E.ADJ_ENGINE,
          E.DRG_GROUP_SEQ_NB,
          E.DRG_SUB_GRP_SEQ_NB,
          E.DRUG_NDC_ID,
		  E.NHU_TYPE_CD
		  %IF &PROGRAM_ID. = 105 %THEN %DO;
		     ,E.DELIVERY_SYSTEM_CD
		  %END;

/*          E.BIRTH_DT,*/
/*          E.LAST_FILL_DT,*/
/*          E.DRUG_ABBR_PROD_NM,*/
/*          E.DRUG_ABBR_STRG_NM,*/
/*          E.DRUG_ABBR_DSG_NM,*/
/*		  E.GCN_CODE*/
		ORDER BY MBR_ID
	)by oracle;
	DISCONNECT FROM ORACLE;
QUIT;
%SET_ERROR_FL;

%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..TMP_EDW_PULL2_&INITIATIVE_ID._&ADJ2.);

PROC SQL NOPRINT;
	CONNECT TO ORACLE(PATH=&GOLD );
	Execute
	(
	  CREATE TABLE &ORA_TMP..TMP_EDW_PULL2_&INITIATIVE_ID._&ADJ2. AS  
	  SELECT 
          E.PT_BENEFICIARY_ID,
          E.CDH_BENEFICIARY_ID,
          MAX(E.CLIENT_NM) AS CLIENT_NM,
		  E.PRESCRIBER_ID,
		  MAX(E.PRACTITIONER_ID) AS PRACTITIONER_ID,
          MAX(E.MBR_GID) AS MBR_GID,
          E.MBR_ID, 
          MAX(E.ALGN_LVL_GID_KEY) AS ALGN_LVL_GID_KEY,
          E.CLIENT_LEVEL_1,
          E.CLIENT_LEVEL_2,
          E.CLIENT_LEVEL_3,
          MAX(E.CLIENT_ID) AS CLIENT_ID,
          MAX(E.PAYER_ID) AS PAYER_ID,
		  MAX(E.DRUG_GID) AS DRUG_GID,
          E.LTR_RULE_SEQ_NB,
		  E.ADJ_ENGINE,
          E.DRG_GROUP_SEQ_NB,
          E.DRG_SUB_GRP_SEQ_NB,
          E.DRUG_NDC_ID,
		  E.NHU_TYPE_CD,
          MAX(E.BIRTH_DT) AS BIRTH_DT,
          MAX(E.LAST_FILL_DT) AS LAST_FILL_DT,
          MAX(E.DRUG_ABBR_PROD_NM) AS DRUG_ABBR_PROD_NM,
          MAX(E.DRUG_ABBR_STRG_NM) AS DRUG_ABBR_STRG_NM,
          MAX(E.DRUG_ABBR_DSG_NM) AS DRUG_ABBR_DSG_NM,
		  MAX(E.GCN_CODE) AS GCN,
		  SUM(E.MEMBER_COST_AT) AS MEMBER_COST_AT,
		  SUM(E.RX_COUNT_QY) AS RX_COUNT_QY
		  %IF &PROGRAM_ID. = 105 %THEN %DO;
		     ,CAST(E.DELIVERY_SYSTEM_CD AS NUMBER) AS LAST_DELIVERY_SYS
		  %END;
       FROM &TBL_NAME_IN1 E
	   WHERE E.PT_BENEFICIARY_ID IS NULL
       GROUP BY 
          E.PT_BENEFICIARY_ID,
          E.CDH_BENEFICIARY_ID,
/*          E.CLIENT_NM,*/
		  E.PRESCRIBER_ID,
/*		  E.PRACTITIONER_ID,*/
/*          E.MBR_GID,*/
          E.MBR_ID, 
/*          E.ALGN_LVL_GID_KEY,*/
          E.CLIENT_LEVEL_1,
          E.CLIENT_LEVEL_2,
          E.CLIENT_LEVEL_3,
/*          E.CLIENT_ID,*/
/*          E.PAYER_ID,*/
/*		  E.DRUG_GID,*/
          E.LTR_RULE_SEQ_NB,
		  E.ADJ_ENGINE,
          E.DRG_GROUP_SEQ_NB,
          E.DRG_SUB_GRP_SEQ_NB,
          E.DRUG_NDC_ID,
		  E.NHU_TYPE_CD
/*          E.BIRTH_DT,*/
/*          E.LAST_FILL_DT,*/
/*          E.DRUG_ABBR_PROD_NM,*/
/*          E.DRUG_ABBR_STRG_NM,*/
/*          E.DRUG_ABBR_DSG_NM,*/
/*		  E.GCN_CODE*/
		  %IF &PROGRAM_ID. = 105 %THEN %DO;
		     ,E.DELIVERY_SYSTEM_CD
		  %END;

		ORDER BY MBR_ID
	)by oracle;
	DISCONNECT FROM ORACLE;
QUIT;
%SET_ERROR_FL;

PROC SQL NOPRINT;
	CONNECT TO ORACLE(PATH=&GOLD );
	Execute
	(
	  CREATE TABLE &TBL_NAME_OUT1. AS  
	  SELECT * FROM &ORA_TMP..TMP_EDW_PULL_&INITIATIVE_ID._&ADJ2. 
	  UNION
	  SELECT * FROM &ORA_TMP..TMP_EDW_PULL2_&INITIATIVE_ID._&ADJ2. 
	)by oracle;
	DISCONNECT FROM ORACLE;
QUIT;

%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..TMP_EDW_PULL_&INITIATIVE_ID._&ADJ2.);
%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..TMP_EDW_PULL2_&INITIATIVE_ID._&ADJ2.);




%IF &DRUG_GROUP2_EXIST_FLAG=1 AND &ERR_FL=0 %THEN %DO;
	DATA _NULL_;
		SET &HERCULES..TINIT_DRUG_GROUP(WHERE=(INITIATIVE_ID=&INITIATIVE_ID
		                                       AND DRG_GROUP_SEQ_NB=2));
		IF  TRIM(LEFT(OPERATOR_TX))='NOT' THEN CALL SYMPUT('NULL_CONDITION','IS NULL');
		                                  ELSE CALL SYMPUT('NULL_CONDITION','IS NOT NULL');
	RUN;
	%SET_ERROR_FL;

	%PUT NULL_CONDITION=&NULL_CONDITION;

	PROC SQL NOPRINT;
		CONNECT TO ORACLE(PATH=&GOLD );
  		EXECUTE 
		(
		CREATE TABLE &TBL_NAME_OUT2. AS
        SELECT A.*
	    FROM &TBL_NAME_OUT1. A
        LEFT JOIN
	 		 (SELECT MBR_ID, COUNT(*) AS CNT
			  FROM &TBL_NAME_OUT1. 
			  WHERE DRG_GROUP_SEQ_NB=2
			  GROUP BY  MBR_ID
			  ) B
        ON A.MBR_ID=B.MBR_ID 
        WHERE  B.MBR_ID &NULL_CONDITION.
  		)BY ORACLE;
    	DISCONNECT FROM ORACLE;
	QUIT;
   %SET_ERROR_FL;

%END; /* END OF &DRUG_GROUP2_EXIST_FLAG = 1*/
%ELSE %DO;
                                                                                                                %DO;
	PROC SQL;
		CONNECT TO ORACLE(PATH=&GOLD );
   		EXECUTE
		(
		CREATE TABLE &TBL_NAME_OUT2. AS
		SELECT * FROM &TBL_NAME_OUT1. 
		) BY ORACLE;
		DISCONNECT FROM ORACLE;
	QUIT;
    %SET_ERROR_FL;

%END; /* END OF &GET_NDC_NDC_TBL_FL = 1 AND &DRUG_GROUP2*/

%DROP_ORACLE_TABLE(TBL_NAME=&TBL_NAME_OUT1.);

%END; 

%MEND PULL_CLAIMS_FOR_EDW;







