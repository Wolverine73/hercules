 /**HEADER -------------------------------------------------------------------------------------------------
  | NAME:     CHECK_DOCUMENT.SAS
  |
  | PURPOSE:  UPDATES APN_CMCTN_IDS TO FILES WAITING IN THE RESULTS AND PENDING
  |           DIRECTORIES.
  |
  |           BEFORE ANY CHECK/UPDATEs TO APNCMCTN_ID, 
  |
  | 
  | INPUT : PENDING SAS DATASET 
  | TABLES USED :
  |               &HERCULES..TPGMTASK_QL_OVR 
  |		  &HERCULES..TDOCUMENT_VERSION
  |                &HERCULES..TPGMTASK_RXCLM_OVR 
  |	           &HERCULES..TPGMTASK_RECP_OVR 
  | OUTPUT : DATASET WITH TEMPLATE ID
  |         
  |---------------------------------------------------------------------------------------------------------
  | HISTORY: 09AUG2010 D.Palmer Modified logic to not reassign the template id, but to validate it only.  
  +-------------------------------------------------------------------------------------------------HEADER*/

%MACRO ABPD_CHECK_DOCUMENT;

	%*SASDOC -----------------------------------------------------------------------
	 | MV DOC_COMPLETE_IN IS SET TO GLOBAL AS THIS MV WILL BE USED BY THE CODES 
	 | THAT CALL CHECK_DOCUMENT.SAS
	 +-----------------------------------------------------------------------SASDOC*;
	%LET ERR_FL = 0;
	%GLOBAL DOC_COMPLETE_IN;
	%GLOBAL LTR_RULE_SEQ_NB;
	%GLOBAL  CMCTN_ROLE_CD;

	%*SASDOC -----------------------------------------------------------------------
	 | MVs DOC_COMPLETE_IN_QL, DOC_COMPLETE_IN_RX, DOC_COMPLETE_IN_RE  ARE SET TO 
	 | LOCAL AS THESE MVs ARE USED ONLY IN CHECK_DOCUMENT.SAS AND WILL BE USED TO
	 | DERIVE DOC_COMPLETE_IN
	 +-----------------------------------------------------------------------SASDOC*;

	%LOCAL DOC_COMPLETE_IN_QL DOC_COMPLETE_IN_RX DOC_COMPLETE_IN_RE;
	%LET DOC_COMPLETE_IN_QL = 1;
	%LET DOC_COMPLETE_IN_RX = 1;
	%LET DOC_COMPLETE_IN_RE = 1;

	%LET MAC_NAME=CHECK_DOCUMENT;

	/*Need to get this one from tprogram*/
	%LET LTR_RULE_SEQ_NB=0;

 	 	
	DATA WORK.TPHASE_RVR_FILE;
		SET &HERCULES..TPHASE_RVR_FILE(WHERE=( INITIATIVE_ID=&INITIATIVE_ID
		AND PHASE_SEQ_NB=&PHASE_SEQ_NB))
		END=LAST;
		KEEP CMCTN_ROLE_CD FILE_ID;
		RUN;
		DATA _NULL_;
		SET WORK.TPHASE_RVR_FILE;
		CALL SYMPUT('CMCTN_ROLE_CD' , TRIM(LEFT(CMCTN_ROLE_CD)));

	RUN;




	DATA WORK.TPGM_LETTER_RULE;
		SET &HERCULES..TPGM_TASK_LTR_RULE(WHERE=( PROGRAM_ID=&PROGRAM_ID
		AND TASK_ID=&TASK_ID))
		END=LAST;

	RUN;

	DATA _NULL_;
		SET WORK.TPGM_LETTER_RULE;
		CALL SYMPUT('LTR_RULE_SEQ_NB' , TRIM(LEFT(LTR_RULE_SEQ_NB)));

	RUN;
 	


	%LET TBL_NAME_OUT_SH_MAIN=T_&INITIATIVE_ID._&PHASE_SEQ_NB._&CMCTN_ROLE_CD;

	 *SASDOC-------------------------------------------------------------------------
	 | Create temporary dataset QL_DOC_OVR for QL override           
	 +-----------------------------------------------------------------------SASDOC*;


		PROC SQL NOPRINT;
			CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
			CREATE TABLE QL_DOC_OVR AS
			SELECT * FROM CONNECTION TO DB2
				(
				SELECT 	DISTINCT 
						A.PROGRAM_ID,
						A.TASK_ID,
						A.CLIENT_ID, 
						A.PLAN_CD_TX,
						A.PLAN_EXT_CD_TX,
						A.GROUP_CD_TX,
						A.GROUP_EXT_CD_TX,
						A.BLG_REPORTING_CD,
						A.GROUP_CLASS_CD, 
						A.GROUP_CLASS_SEQ_NB,
						A.LTR_RULE_SEQ_NB,
						A.CMCTN_ROLE_CD,
						A.APN_CMCTN_ID,
						A.PLAN_NM,
						'QL' AS ADJ_ENGINE
				FROM	&HERCULES..TPGMTASK_QL_OVR A,
					&HERCULES..TDOCUMENT_VERSION B
				WHERE 	A.PROGRAM_ID=&PROGRAM_ID
				AND A.TASK_ID =&TASK_ID
				AND CURRENT DATE BETWEEN A.EFFECTIVE_DT AND A.EXPIRATION_DT 
				AND A.APN_CMCTN_ID=B.APN_CMCTN_ID
				AND CURRENT DATE BETWEEN B.PRODUCTION_DT AND B.EXPIRATION_DT 
					ORDER BY A.CLIENT_ID
				);
				DISCONNECT FROM DB2;
		QUIT;

		%SET_ERROR_FL;

	 *SASDOC-------------------------------------------------------------------------
	 | Create temporary dataset RXCM_DOC_OVR for RX override           
	 +-----------------------------------------------------------------------SASDOC*;
		PROC SQL NOPRINT;
			CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
				CREATE TABLE RXCM_DOC_OVR AS
			SELECT * FROM CONNECTION TO DB2
				(
				SELECT 	DISTINCT
					A.PROGRAM_ID,
					A.TASK_ID,
					A.CARRIER_ID, 
					A.ACCOUNT_ID,
					A.GROUP_CD,
					A.LTR_RULE_SEQ_NB,
					A.CMCTN_ROLE_CD,
					A.APN_CMCTN_ID,
					'RX' AS ADJ_ENGINE
				FROM	&HERCULES..TPGMTASK_RXCLM_OVR A,
					&HERCULES..TDOCUMENT_VERSION B
				WHERE 	A.PROGRAM_ID=&PROGRAM_ID
				AND A.TASK_ID =&TASK_ID
				AND CURRENT DATE BETWEEN A.EFFECTIVE_DT AND A.EXPIRATION_DT 
				AND A.APN_CMCTN_ID=B.APN_CMCTN_ID
				AND CURRENT DATE BETWEEN B.PRODUCTION_DT AND B.EXPIRATION_DT 
				);
				DISCONNECT FROM DB2;

				SELECT COUNT(*) INTO :RCNT_RX
				FROM RXCM_DOC_OVR;

		QUIT;


	%SET_ERROR_FL;

	*SASDOC-------------------------------------------------------------------------
	 | Create temporary dataset RECP_DOC_OVR for RE override           
	 +-----------------------------------------------------------------------SASDOC*;
	 PROC SQL NOPRINT;
			CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
				CREATE TABLE RECP_DOC_OVR AS
			SELECT * FROM CONNECTION TO DB2
				(
				SELECT 	DISTINCT
					A.PROGRAM_ID,
					A.TASK_ID,
					A.INSURANCE_CD, 
					A.CARRIER_ID, 
					A.GROUP_CD,
					A.LTR_RULE_SEQ_NB,
					A.CMCTN_ROLE_CD,
					A.APN_CMCTN_ID,
					'RE' AS ADJ_ENGINE
				FROM	&HERCULES..TPGMTASK_RECAP_OVR A,
					&HERCULES..TDOCUMENT_VERSION B
				WHERE 	A.PROGRAM_ID=&PROGRAM_ID
				AND A.TASK_ID =&TASK_ID
				AND CURRENT DATE BETWEEN A.EFFECTIVE_DT AND A.EXPIRATION_DT 
				AND A.APN_CMCTN_ID=B.APN_CMCTN_ID
				AND CURRENT DATE BETWEEN B.PRODUCTION_DT AND B.EXPIRATION_DT 

				);
				DISCONNECT FROM DB2;

		QUIT;



	%SET_ERROR_FL;

	 *SASDOC-------------------------------------------------------------------------
	 | Create temporary dataset DOC_DEFAULT  for applying default template id         
	 +-----------------------------------------------------------------------SASDOC*;
	PROC SQL NOPRINT;
			CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
				CREATE TABLE DOC_DEFAULT AS
			SELECT * FROM CONNECTION TO DB2
				(
				SELECT 	DISTINCT 
					A.PROGRAM_ID,
					A.APN_CMCTN_ID as DEFAULT_APN_CMCTN_ID 	
				FROM	&HERCULES..TPGM_TASK_DOM A,
					&HERCULES..TDOCUMENT_VERSION B
				WHERE 	A.PROGRAM_ID=&PROGRAM_ID
				AND A.TASK_ID =&TASK_ID
				AND CURRENT DATE BETWEEN A.EFFECTIVE_DT AND A.EXPIRATION_DT 
				AND A.APN_CMCTN_ID=B.APN_CMCTN_ID
				AND CURRENT DATE BETWEEN B.PRODUCTION_DT AND B.EXPIRATION_DT 
				);
				DISCONNECT FROM DB2;

			QUIT;

		%SET_ERROR_FL;

		;

 	*SASDOC-------------------------------------------------------------------------
	 | Performing the row count on pending sasdataset before template id is applied       
	 +-----------------------------------------------------------------------SASDOC*;
     PROC SQL ;
     SELECT COUNT(*) INTO : FIRST_ROW_COUNT  
     FROM  DATA_PND.&TBL_NAME_OUT_SH_MAIN   ;
     QUIT ;

    %LET BEFORE_TEMPLATE_ROW_COUNT =%LEFT(%TRIM(&FIRST_ROW_COUNT));
    %PUT NOTE: VALUE OF ROWCOUNT BEFORE TEMPLATE ID  IS APPLIED &BEFORE_TEMPLATE_ROW_COUNT ;




	 *SASDOC-------------------------------------------------------------------------
	 |	 reassign as null and drop variable if they exist
	 |   this will allow for a fresh new assignment and prevent the previous
	 |   runs assignment from being assigned 
     |   09AUG2010 - D.Palmer  Changed to not reassign template id received from EOMS  
	 +-----------------------------------------------------------------------SASDOC*;

	data DATA_PND.&TBL_NAME_OUT_SH_MAIN;
		 set DATA_PND.&TBL_NAME_OUT_SH_MAIN;
		/* APN_CMCTN_ID=''; */
		 drop DEFAULT_APN_CMCTN_ID RECAP_APN_CMCTN_ID RXCLAIM_APN_CMCTN_ID QL_APN_CMCTN_ID NEW_APN_CMCTN_ID;
	run;




	 *SASDOC-------------------------------------------------------------------------
	 |	 Attach Default Template        
	 +-----------------------------------------------------------------------SASDOC*;
/*	proc sql;*/
/*		CREATE TABLE DATA_PND.&TBL_NAME_OUT_SH_MAIN AS */
/*		SELECT A.* , B.DEFAULT_APN_CMCTN_ID*/
/*		FROM DATA_PND.&TBL_NAME_OUT_SH_MAIN  A*/
/*		LEFT JOIN DOC_DEFAULT  B */
/*		ON  B.program_id = A.program_id ;*/
/*	quit;*/

	 *SASDOC-------------------------------------------------------------------------
	 | Hierarchy assignment for RECAP        
	 +-----------------------------------------------------------------------SASDOC*;
	 *SASDOC-------------------------------------------------------------------------
	 |	 Attach Recap Override Template        
	 +-----------------------------------------------------------------------SASDOC*;
	
	
	*--INSURANCE-------------------------------------;

	DATA INSURANCE_DEFINITION;
	   SET RECP_DOC_OVR;
	   IF INSURANCE_CD NE '' AND CARRIER_ID ='' AND GROUP_CD ='';
	RUN;
	
	proc sort data = INSURANCE_DEFINITION nodupkey ;
	 by ADJ_ENGINE PROGRAM_ID INSURANCE_CD CARRIER_ID GROUP_CD ;
	run;

	PROC SQL;
	 CREATE TABLE DATA_PND.&TBL_NAME_OUT_SH_MAIN AS
	 SELECT A.*, B.APN_CMCTN_ID AS RECAP_APN_CMCTN_ID
	 from       DATA_PND.&TBL_NAME_OUT_SH_MAIN  A
	 left join  INSURANCE_DEFINITION            B
	 on 	
		B.ADJ_ENGINE=A.ADJ_ENGINE
		AND B.PROGRAM_ID = A.PROGRAM_ID
		AND B.INSURANCE_CD = A.CLIENT_LEVEL_1 ;
	QUIT;	
	
	*--CARRIER-------------------------------------;

	DATA CARRIER_DEFINITION;
	   SET RECP_DOC_OVR;
	   IF INSURANCE_CD NE '' AND CARRIER_ID NE '' AND GROUP_CD ='';
	RUN;
	
	proc sort data = CARRIER_DEFINITION nodupkey ;
	 by ADJ_ENGINE PROGRAM_ID INSURANCE_CD CARRIER_ID GROUP_CD ;
	run;

	PROC SQL;
	 CREATE TABLE DATA_PND.&TBL_NAME_OUT_SH_MAIN AS
	 SELECT A.*, B.APN_CMCTN_ID AS APN_CMCTN_ID_HCE
	 from       DATA_PND.&TBL_NAME_OUT_SH_MAIN  A
	 left join  CARRIER_DEFINITION              B
	 on 	
		B.ADJ_ENGINE=A.ADJ_ENGINE
		AND B.PROGRAM_ID = A.PROGRAM_ID
		AND B.INSURANCE_CD = A.CLIENT_LEVEL_1 
		AND UPCASE(LEFT(TRIM(SUBSTR(B.CARRIER_ID,2)))) = UPCASE(LEFT(TRIM(A.CLIENT_LEVEL_2)))
		AND B.GROUP_CD = '';
	QUIT;
	
	DATA DATA_PND.&TBL_NAME_OUT_SH_MAIN;
	 SET DATA_PND.&TBL_NAME_OUT_SH_MAIN;
	 if APN_CMCTN_ID_HCE ne '' then RECAP_APN_CMCTN_ID=APN_CMCTN_ID_HCE;
	 drop APN_CMCTN_ID_HCE;
	run;
	
	*--GROUP-------------------------------------;

	DATA GROUP_DEFINITION;
	SET RECP_DOC_OVR;
	IF INSURANCE_CD NE '' AND CARRIER_ID NE '' AND GROUP_CD NE '';
	RUN;
	
	proc sort data = GROUP_DEFINITION nodupkey ;
	 by ADJ_ENGINE PROGRAM_ID INSURANCE_CD CARRIER_ID GROUP_CD ;
	run;

	PROC SQL;
	 CREATE TABLE DATA_PND.&TBL_NAME_OUT_SH_MAIN AS
	 SELECT A.*, B.APN_CMCTN_ID AS APN_CMCTN_ID_HCE
	 from       DATA_PND.&TBL_NAME_OUT_SH_MAIN  A
	 left join  GROUP_DEFINITION                B
	 on 	
		B.ADJ_ENGINE=A.ADJ_ENGINE
		AND B.PROGRAM_ID = A.PROGRAM_ID
		AND B.INSURANCE_CD = A.CLIENT_LEVEL_1 
		AND UPCASE(LEFT(TRIM(SUBSTR(B.CARRIER_ID,2)))) = UPCASE(LEFT(TRIM(A.CLIENT_LEVEL_2)))
		AND UPCASE(LEFT(TRIM(       B.GROUP_CD     ))) = UPCASE(LEFT(TRIM(A.CLIENT_LEVEL_3)));
	QUIT;
	
	DATA DATA_PND.&TBL_NAME_OUT_SH_MAIN;
	 SET DATA_PND.&TBL_NAME_OUT_SH_MAIN;
	 if APN_CMCTN_ID_HCE ne '' then RECAP_APN_CMCTN_ID=APN_CMCTN_ID_HCE;
	 drop APN_CMCTN_ID_HCE;
	run;	

	 *SASDOC-------------------------------------------------------------------------
	 | Hierarchy assignment for RXCLM      
	 +-----------------------------------------------------------------------SASDOC*;
	 *SASDOC-------------------------------------------------------------------------
	 | Attach Rxclaim Override Template        
	 +-----------------------------------------------------------------------SASDOC*;

	
	*--CARRIER-------------------------------------;

	DATA CARRIER_DEFINITION;
	SET RXCM_DOC_OVR;
	IF CARRIER_ID NE '' AND ACCOUNT_ID ='' AND GROUP_CD ='';
	RUN;
	
	proc sort data = CARRIER_DEFINITION nodupkey ;
	 by ADJ_ENGINE PROGRAM_ID CARRIER_ID ACCOUNT_ID GROUP_CD ;
	run;

	PROC SQL;
	 CREATE TABLE DATA_PND.&TBL_NAME_OUT_SH_MAIN AS
	 SELECT A.*, B.APN_CMCTN_ID AS RXCLAIM_APN_CMCTN_ID
	 from       DATA_PND.&TBL_NAME_OUT_SH_MAIN  A
	 left join  CARRIER_DEFINITION              B
	 on 	
		B.ADJ_ENGINE=A.ADJ_ENGINE
		AND B.PROGRAM_ID = A.PROGRAM_ID
		AND SUBSTR(B.CARRIER_ID,2) = A.CLIENT_LEVEL_1 ;
	QUIT;	
	
	*--ACCOUNT--------------------------------------;

	DATA ACCOUNT_DEFINITION;
	SET RXCM_DOC_OVR;
	IF CARRIER_ID NE '' AND ACCOUNT_ID NE '' AND GROUP_CD ='';
	RUN;
	
	proc sort data = ACCOUNT_DEFINITION nodupkey ;
	 by ADJ_ENGINE PROGRAM_ID CARRIER_ID ACCOUNT_ID GROUP_CD ;
	run;

	PROC SQL;
	 CREATE TABLE DATA_PND.&TBL_NAME_OUT_SH_MAIN AS
	 SELECT A.*, B.APN_CMCTN_ID AS APN_CMCTN_ID_HCE
	 from       DATA_PND.&TBL_NAME_OUT_SH_MAIN  A
	 left join  ACCOUNT_DEFINITION B
	 on 
		B.ADJ_ENGINE=A.ADJ_ENGINE
		AND B.PROGRAM_ID = A.PROGRAM_ID
		AND SUBSTR(B.CARRIER_ID,2) = A.CLIENT_LEVEL_1		
		AND UPCASE(LEFT(TRIM(B.ACCOUNT_ID))) = UPCASE(LEFT(TRIM(A.CLIENT_LEVEL_2)))
	    	AND B.GROUP_CD='';
	QUIT;

	DATA DATA_PND.&TBL_NAME_OUT_SH_MAIN;
	 SET DATA_PND.&TBL_NAME_OUT_SH_MAIN;
	 if APN_CMCTN_ID_HCE ne '' then RXCLAIM_APN_CMCTN_ID=APN_CMCTN_ID_HCE;
	 drop APN_CMCTN_ID_HCE;
	run;
	
	*--GROUP--------------------------------------;

	DATA GROUP_DEFINITION;
	SET RXCM_DOC_OVR;
	IF CARRIER_ID NE '' AND ACCOUNT_ID NE '' AND GROUP_CD NE '';
	RUN;
	
	proc sort data = GROUP_DEFINITION nodupkey ;
	 by ADJ_ENGINE PROGRAM_ID CARRIER_ID ACCOUNT_ID GROUP_CD ;
	run;

	PROC SQL;
	 CREATE TABLE DATA_PND.&TBL_NAME_OUT_SH_MAIN AS
	 SELECT A.*, B.APN_CMCTN_ID AS APN_CMCTN_ID_HCE
	 from       DATA_PND.&TBL_NAME_OUT_SH_MAIN  A
	 left join  GROUP_DEFINITION B
	 on 
		B.ADJ_ENGINE=A.ADJ_ENGINE
		AND B.PROGRAM_ID = A.PROGRAM_ID
		AND SUBSTR(B.CARRIER_ID,2) = A.CLIENT_LEVEL_1		
		AND UPCASE(LEFT(TRIM(B.ACCOUNT_ID))) = UPCASE(LEFT(TRIM(A.CLIENT_LEVEL_2)))
	    	AND UPCASE(LEFT(TRIM(B.GROUP_CD  ))) = UPCASE(LEFT(TRIM(A.CLIENT_LEVEL_3)))  ;
	QUIT;

	DATA DATA_PND.&TBL_NAME_OUT_SH_MAIN;
	 SET DATA_PND.&TBL_NAME_OUT_SH_MAIN;
	 if APN_CMCTN_ID_HCE ne '' then RXCLAIM_APN_CMCTN_ID=APN_CMCTN_ID_HCE;
	 drop APN_CMCTN_ID_HCE;
	run;	

	*SASDOC-------------------------------------------------------------------------
	 | Hierarchy assignment for QL         
	 +-----------------------------------------------------------------------SASDOC*;
	 *SASDOC-------------------------------------------------------------------------
	 | Attach QL Override Template        
	 +-----------------------------------------------------------------------SASDOC*;

	*--CLIENT-------------------------------------;

	DATA CLIENT_DEFINITION;
	SET QL_DOC_OVR;
	IF CLIENT_ID > 0 AND PLAN_CD_TX  ='' AND PLAN_EXT_CD_TX  ='' 
	                 AND GROUP_CD_TX ='' AND GROUP_EXT_CD_TX =''
	                 AND BLG_REPORTING_CD = '' AND GROUP_CLASS_CD = 0 AND GROUP_CLASS_SEQ_NB = 0;
	RUN;
	
	proc sort data = CLIENT_DEFINITION nodupkey ;
	 by ADJ_ENGINE PROGRAM_ID CLIENT_ID GROUP_CD_TX GROUP_EXT_CD_TX 
	    PLAN_CD_TX PLAN_EXT_CD_TX ;
	run;

	PROC SQL;
	 CREATE TABLE DATA_PND.&TBL_NAME_OUT_SH_MAIN AS
	 SELECT A.*, B.APN_CMCTN_ID AS QL_APN_CMCTN_ID
	 from       DATA_PND.&TBL_NAME_OUT_SH_MAIN  A
	 left join  CLIENT_DEFINITION               B
	 on 
		A.ADJ_ENGINE=B.ADJ_ENGINE
		AND A.PROGRAM_ID = B.PROGRAM_ID
		AND INPUT(A.CLIENT_LEVEL_1 ,14.)=B.CLIENT_ID ;
	QUIT;


	*--GROUP--------------------------------------;

	DATA GROUP_DEFINITION;
	SET QL_DOC_OVR;
	IF CLIENT_ID > 0 AND GROUP_CD_TX  NE ''  
	                 AND PLAN_CD_TX    = '' AND PLAN_EXT_CD_TX  = ''
	                 AND BLG_REPORTING_CD = '' AND GROUP_CLASS_CD = 0 AND GROUP_CLASS_SEQ_NB = 0;
	RUN;
	
	proc sort data = GROUP_DEFINITION nodupkey ;
	 by ADJ_ENGINE PROGRAM_ID CLIENT_ID GROUP_CD_TX GROUP_EXT_CD_TX 
	    PLAN_CD_TX PLAN_EXT_CD_TX ;
	run;

	PROC SQL;
	 CREATE TABLE DATA_PND.&TBL_NAME_OUT_SH_MAIN AS
	 SELECT A.*, B.APN_CMCTN_ID_HCE
	 from       DATA_PND.&TBL_NAME_OUT_SH_MAIN  A
	 left join  GROUP_DEFINITION (rename=(APN_CMCTN_ID=APN_CMCTN_ID_HCE)) B
	 on 
	   (
		A.ADJ_ENGINE=B.ADJ_ENGINE
		AND A.PROGRAM_ID = B.PROGRAM_ID
		AND INPUT(A.CLIENT_LEVEL_1 ,14.)=B.CLIENT_ID
	    	AND A.CLIENT_LEVEL_3=B.GROUP_CD_TX 
	    	AND B.GROUP_EXT_CD_TX=' ');
  QUIT;

	DATA DATA_PND.&TBL_NAME_OUT_SH_MAIN;
	 SET DATA_PND.&TBL_NAME_OUT_SH_MAIN;
	 if APN_CMCTN_ID_HCE ne '' then QL_APN_CMCTN_ID=APN_CMCTN_ID_HCE;
	 drop APN_CMCTN_ID_HCE;
	run;	
	

	*--PLAN---------------------------------------;

	DATA PLAN_DEFINITION;
	SET QL_DOC_OVR;
	IF CLIENT_ID > 0 AND PLAN_CD_TX  NE ''  
	                 AND GROUP_CD_TX  = '' AND GROUP_EXT_CD_TX  = ''
	                 AND BLG_REPORTING_CD = '' AND GROUP_CLASS_CD = 0 AND GROUP_CLASS_SEQ_NB = 0;
	RUN;
	
	proc sort data = PLAN_DEFINITION nodupkey ;
	 by ADJ_ENGINE PROGRAM_ID CLIENT_ID GROUP_CD_TX GROUP_EXT_CD_TX 
	    PLAN_CD_TX PLAN_EXT_CD_TX ;
	run;

	PROC SQL;
	 CREATE TABLE DATA_PND.&TBL_NAME_OUT_SH_MAIN AS
	 SELECT A.*, B.APN_CMCTN_ID_HCE
	 from       DATA_PND.&TBL_NAME_OUT_SH_MAIN  A
	 left join  PLAN_DEFINITION (rename=(APN_CMCTN_ID=APN_CMCTN_ID_HCE)) B
	 on 
	   (
		A.ADJ_ENGINE=B.ADJ_ENGINE
		AND A.PROGRAM_ID = B.PROGRAM_ID
		AND INPUT(A.CLIENT_LEVEL_1 ,14.)=B.CLIENT_ID	 
	     	AND A.CLIENT_LEVEL_2=B.PLAN_CD_TX  
	     	AND B.PLAN_EXT_CD_TX=' ')
	    OR
	    (
		A.ADJ_ENGINE=B.ADJ_ENGINE
		AND A.PROGRAM_ID = B.PROGRAM_ID
		AND INPUT(A.CLIENT_LEVEL_1 ,14.)=B.CLIENT_ID	   
	    	AND A.CLIENT_LEVEL_2=B.PLAN_CD_TX);
	QUIT;

	DATA DATA_PND.&TBL_NAME_OUT_SH_MAIN;
	 SET DATA_PND.&TBL_NAME_OUT_SH_MAIN;
	 if APN_CMCTN_ID_HCE ne '' then QL_APN_CMCTN_ID=APN_CMCTN_ID_HCE;
	 drop APN_CMCTN_ID_HCE;
	run;	
	
	*--GROUP AND PLAN-----------------------------;
	*--3 TYPES -----------------------------------;
	*----GROUP PLAN ------------------------------;
	*----GROUP GROUP EXT PLAN --------------------;
	*----GROUP PLAN PLAN EXT ---------------------;

	DATA GROUP_PLAN_DEFINITION;
	SET QL_DOC_OVR;
	IF CLIENT_ID > 0 AND PLAN_CD_TX NE '' AND GROUP_CD_TX NE '' 
	                 AND BLG_REPORTING_CD = '' AND GROUP_CLASS_CD = 0 AND GROUP_CLASS_SEQ_NB = 0;
	IF CLIENT_ID > 0 AND PLAN_CD_TX   NE '' AND PLAN_EXT_CD_TX  NE '' 
	                 AND GROUP_CD_TX  NE '' AND GROUP_EXT_CD_TX NE ''  THEN DELETE;	                 
	RUN;
	
	proc sort data = GROUP_PLAN_DEFINITION nodupkey ;
	 by ADJ_ENGINE PROGRAM_ID CLIENT_ID GROUP_CD_TX GROUP_EXT_CD_TX 
	    PLAN_CD_TX PLAN_EXT_CD_TX ;
	run;

	PROC SQL;
	 CREATE TABLE DATA_PND.&TBL_NAME_OUT_SH_MAIN AS
	 SELECT A.*, B.APN_CMCTN_ID_HCE
	 from       DATA_PND.&TBL_NAME_OUT_SH_MAIN  A
	 left join  GROUP_PLAN_DEFINITION (rename=(APN_CMCTN_ID=APN_CMCTN_ID_HCE)) B
	 on 
	   (
		A.ADJ_ENGINE=B.ADJ_ENGINE
		AND A.PROGRAM_ID = B.PROGRAM_ID
		AND INPUT(A.CLIENT_LEVEL_1 ,14.)=B.CLIENT_ID
	    	AND A.CLIENT_LEVEL_3=B.GROUP_CD_TX 
	    	AND B.GROUP_EXT_CD_TX=' ' 
	    	AND A.CLIENT_LEVEL_2=B.PLAN_CD_TX 
	    	AND B.PLAN_EXT_CD_TX=' ');
	QUIT;

	DATA DATA_PND.&TBL_NAME_OUT_SH_MAIN;
	 SET DATA_PND.&TBL_NAME_OUT_SH_MAIN;
	 if APN_CMCTN_ID_HCE ne '' then QL_APN_CMCTN_ID=APN_CMCTN_ID_HCE;
	 drop APN_CMCTN_ID_HCE;
	run;
	
	PROC SQL;
	 CREATE TABLE DATA_PND.&TBL_NAME_OUT_SH_MAIN AS
	 SELECT A.*, B.APN_CMCTN_ID_HCE
	 from       DATA_PND.&TBL_NAME_OUT_SH_MAIN  A
	 left join  GROUP_PLAN_DEFINITION (rename=(APN_CMCTN_ID=APN_CMCTN_ID_HCE)) B
	 on 
	   (
		A.ADJ_ENGINE=B.ADJ_ENGINE
		AND A.PROGRAM_ID = B.PROGRAM_ID
		AND INPUT(A.CLIENT_LEVEL_1 ,14.)=B.CLIENT_ID
	    	AND A.CLIENT_LEVEL_3=B.GROUP_CD_TX 
	    	AND A.CLIENT_LEVEL_2=B.PLAN_CD_TX 
	    	AND B.PLAN_EXT_CD_TX=' ');
	QUIT;

	DATA DATA_PND.&TBL_NAME_OUT_SH_MAIN;
	 SET DATA_PND.&TBL_NAME_OUT_SH_MAIN;
	 if APN_CMCTN_ID_HCE ne '' then QL_APN_CMCTN_ID=APN_CMCTN_ID_HCE;
	 drop APN_CMCTN_ID_HCE;
	run;
	
	PROC SQL;
	 CREATE TABLE DATA_PND.&TBL_NAME_OUT_SH_MAIN AS
	 SELECT A.*, B.APN_CMCTN_ID_HCE
	 from       DATA_PND.&TBL_NAME_OUT_SH_MAIN  A
	 left join  GROUP_PLAN_DEFINITION (rename=(APN_CMCTN_ID=APN_CMCTN_ID_HCE)) B
	 on 
	   (
		A.ADJ_ENGINE=B.ADJ_ENGINE
		AND A.PROGRAM_ID = B.PROGRAM_ID
		AND INPUT(A.CLIENT_LEVEL_1 ,14.)=B.CLIENT_ID
	    	AND A.CLIENT_LEVEL_3=B.GROUP_CD_TX 
	    	AND B.GROUP_EXT_CD_TX=' ' 
	    	AND A.CLIENT_LEVEL_2=B.PLAN_CD_TX);
	QUIT;

	DATA DATA_PND.&TBL_NAME_OUT_SH_MAIN;
	 SET DATA_PND.&TBL_NAME_OUT_SH_MAIN;
	 if APN_CMCTN_ID_HCE ne '' then QL_APN_CMCTN_ID=APN_CMCTN_ID_HCE;
	 drop APN_CMCTN_ID_HCE;
	run;

	*--ALL----------------------------------------;
	
	DATA ALL_DEFINITION;
	SET QL_DOC_OVR;
	IF CLIENT_ID > 0 AND PLAN_CD_TX    NE '' AND PLAN_EXT_CD_TX  NE '' 
	                 AND GROUP_CD_TX   NE '' AND GROUP_EXT_CD_TX NE ''
                         AND BLG_REPORTING_CD =  '' AND GROUP_CLASS_CD  = 0 AND GROUP_CLASS_SEQ_NB = 0;
	RUN;
	
	proc sort data = ALL_DEFINITION nodupkey ;
	 by ADJ_ENGINE PROGRAM_ID CLIENT_ID GROUP_CD_TX GROUP_EXT_CD_TX 
	    PLAN_CD_TX PLAN_EXT_CD_TX ;
	run;

	PROC SQL;
	 CREATE TABLE DATA_PND.&TBL_NAME_OUT_SH_MAIN AS
	 SELECT A.*, B.APN_CMCTN_ID_HCE
	 from       DATA_PND.&TBL_NAME_OUT_SH_MAIN  A
	 left join  ALL_DEFINITION (rename=(APN_CMCTN_ID=APN_CMCTN_ID_HCE)) B
	 on 
	   (
		A.ADJ_ENGINE=B.ADJ_ENGINE
		AND A.PROGRAM_ID = B.PROGRAM_ID
		AND INPUT(A.CLIENT_LEVEL_1 ,14.)=B.CLIENT_ID
	    	AND A.CLIENT_LEVEL_3=B.GROUP_CD_TX 
	    	AND A.CLIENT_LEVEL_2=B.PLAN_CD_TX );
	QUIT;

	DATA DATA_PND.&TBL_NAME_OUT_SH_MAIN;
	 SET DATA_PND.&TBL_NAME_OUT_SH_MAIN;
	 if APN_CMCTN_ID_HCE ne '' then QL_APN_CMCTN_ID=APN_CMCTN_ID_HCE;
	 drop APN_CMCTN_ID_HCE;
	run;

	 *SASDOC-------------------------------------------------------------------------
	 |	 Assign Recap, Rxclaim, QL, and default templates
	 |   09AUG2010 - D.Palmer Changed logic to not assign the template id, but only 
	 |               validate it.
   |   11OCT2010 - G. DUDLEY - STILL NEEDS WORK -- COMMENTED OUT FOR NOW
	 +-----------------------------------------------------------------------SASDOC*;
/*	PROC SORT DATA = DATA_PND.&TBL_NAME_OUT_SH_MAIN ; */
/*	  BY ADJ_ENGINE; */
/*	RUN;*/

/*	DATA DATA_PND.&TBL_NAME_OUT_SH_MAIN;*/
/*		 SET DATA_PND.&TBL_NAME_OUT_SH_MAIN;*/
/*		 if      ADJ_ENGINE='RE' and RECAP_APN_CMCTN_ID   ne '' then NEW_CMCTN_ID=RECAP_APN_CMCTN_ID;*/
/*		 else if ADJ_ENGINE='RX' and RXCLAIM_APN_CMCTN_ID ne '' then NEW_CMCTN_ID=RXCLAIM_APN_CMCTN_ID; */
/*		 else if ADJ_ENGINE='QL' and QL_APN_CMCTN_ID      ne '' then NEW_CMCTN_ID=QL_APN_CMCTN_ID; */
/*		 else NEW_CMCTN_ID=DEFAULT_APN_CMCTN_ID;*/
/*		 IF APN_CMCTN_ID ne NEW_CMCTN_ID THEN do;*/
/*             PUT 'NOTE: ' ADJ_ENGINE ' EOMS COMMUNICATION ID ' APN_CMCTN_ID 'is INVALID' ; */
/*		 END;*/
/*	RUN;*/
	

	*SASDOC-------------------------------------------------------------------------
	 |	 Dropping extra columns
	 +-----------------------------------------------------------------------SASDOC*;
	DATA DATA_PND.&TBL_NAME_OUT_SH_MAIN ;
		SET DATA_PND.&TBL_NAME_OUT_SH_MAIN ;
		DROP DEFAULT_APN_CMCTN_ID RECAP_APN_CMCTN_ID RXCLAIM_APN_CMCTN_ID QL_APN_CMCTN_ID NEW_CMCTN_ID ;
	RUN;
	
	*SASDOC-------------------------------------------------------------------------
	 | Performing the row count  sasdataset after template id is applied       
	 +-----------------------------------------------------------------------SASDOC*;
     PROC SQL ;
     SELECT COUNT(*) INTO : LAST_ROW_COUNT  
     FROM  DATA_PND.&TBL_NAME_OUT_SH_MAIN    ;
     QUIT ;

    %LET AFTER_TEMPLATE_ROW_COUNT =%LEFT(%TRIM(&LAST_ROW_COUNT));
    %PUT NOTE: VALUE OF ROWCOUNT AFTER TEMPLATE ID  IS APPLIED &AFTER_TEMPLATE_ROW_COUNT ;

     *SASDOC-------------------------------------------------------------------------
	 | Stop the process if row count is not same      
	 +-----------------------------------------------------------------------SASDOC*;
	 %IF &AFTER_TEMPLATE_ROW_COUNT NE &BEFORE_TEMPLATE_ROW_COUNT %THEN %DO;
      %set_error_fl;
         %on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative Id &INITIATIVE_ID");
     %END ;

%MEND ABPD_CHECK_DOCUMENT;


		














