 /**HEADER -------------------------------------------------------------------------------------------------
  | NAME:     CHECK_DOCUMENT.SAS
  |
  | PURPOSE:  UPDATES APN_CMCTN_IDS TO FILES WAITING IN THE RESULTS AND PENDING
  |           DIRECTORIES.
  |
  |          BEFORE ANY CHECK/UPDATEs TO APNCMCTN_ID, VERIFY THAT RELEASE_STATUS_CD IS NOT 2/FINAL
  |          AND RELEASE_TS IS NULL  
  |
  |          CHECKS:
  |          1)  WHEN VALID APN_CMCTN_ID IS AVAILABLE IN THE HERCULES SETUP TABLE:
  |             --> IF APN_CMCTN_ID IS NULL THEN POPULATE IT WITH THE VALID APN_CMCTN_ID
  |             --> IF APN_CMCTN_ID IS NOT NULL, CHECK IF THE APN_CMCTN_ID IS UP TO DATE
  |                    IF NOT UPDATED, POPULATE WITH THE VALID APN_CMCTN_ID
  |             --> SET &DOC_COMPLETE_IN TO 1.  
  |          2)  APN_CMCTN_ID AVAILABLE IN THE HERCULES SETUP TABLES BUT IS NOT VALID
  |             OR NO APN_CMCTN_ID EXISTS AT ALL IN THE HERCULES SETUP TABLES:
  |             --> SET &DOC_COMPLETE_IN TO 0.
  |         
  |          3)  VERFY THE MAILING FILE TO BE RELEASED DOES NOT HAVE NULLS IN THE APN_CMCTN_ID FIELD.
  |        
  |
  | INPUT:    
  | 	MACRO VARIABLES:
  |     	1) DOCUMENT_LOC_CD
  |			2) INITIATIVE_ID 
  | 		3) PHASE_SEQ_NB
  |     INPUT TABLES:
  | 		INITIATIVE SETUP TABLES: 	TINIT_PHSE_RVE_DOM (DEFAULT TABLE FOR INITIATIVE)
  |                             		TDOCUMENT_VERSION
  |										TINIT_QL_DOC_OVR (QL)
  |										TINIT_RXCM_DOC_OVR (RXCLM)
  |										TINIT_RECP_DOC_OVR (RECAP)
  |
  | 		PROGRAM-MAINTAINENCE SETUP TABLES: 	TPGM_TASK_DOM (DEFAULT TABLE FOR PROGRAM-TASK)
  |                             				TDOCUMENT_VERSION
  |												TPGMTASK_QL_OVR (QL)
  |												TPGMTASK_RXCM_OVR (RXCLM)
  |												TPGMTASK_RECP_OVR (RECAP)
  |
  |			DATA_PND.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.
  |			DATA_RES.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.
  |
  |		OUTPUT TABLES: (BELOW MENTIONED TABLES ARE PASSED AS INPUTS, WITH APN_CMCTN_ID UPDATED WHEN OUTPUT)  
  |			DATA_PND.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.
  |			DATA_RES.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.
  | 
  |---------------------------------------------------------------------------------------------------------
  |
  | USAGE:     THIS MACRO WILL BE CALLED BY THE ALL SAS TASK-PROGRAMS AND THE FILE
  |            RELEASE PROCESS:
  |          OPTIONS SYSPARM='INITIATIVE_ID=20 PHASE_SEQ_NB=1';
  |            %INCLUDE '/PRG/SASPROD1/HERCULES/HERCULES_IN.SAS';
  |            %CHECK_DOCUMENT;
  |---------------------------------------------------------------------------------------------------------
  | HISTORY:  OCT 2003 JOHN HOU
  |           APR 2008 Suresh	- Hercules Version  2.1.2.01
  |								- CHANGES TO ACCOMODATE ALL 3 ADJUDICATIONS
  |           JUNE 2012 - E BUKOWSKI(SLIOUNKOVA) -  TARGET BY DRUG/DSA AUTOMATION
  |           ADJUSTED MODMAIL ASSIGNMENT AND INNERQUERY TO ALLOW ALL THREE ADJUDICATIONS RUN TOGETHER
  |           FOR DSA/NCQA 
  +-------------------------------------------------------------------------------------------------HEADER*/

%MACRO CHECK_DOCUMENT_rg;

%*SASDOC -----------------------------------------------------------------------
 | MV DOC_COMPLETE_IN IS SET TO GLOBAL AS THIS MV WILL BE USED BY THE CODES 
 | THAT CALL CHECK_DOCUMENT.SAS
 +-----------------------------------------------------------------------SASDOC*;
%LET ERR_FL = 0;
%GLOBAL DOC_COMPLETE_IN;

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

%*SASDOC -----------------------------------------------------------------------
 | CHECK TO SEE IF RELEASE_STATUS_CD=2 AND RELEASE_TS IS NOT NULL, 
 | IF TRUE, SET M.V. DOC_COMPLETE_IN_QL/RX/RE=1, SINCE NO DOCUMENT CHECK IS REQUIRED, AS
 | THE INITIATIVE ALREADY BEEN RELEASED
 | RUN THE DOCUMENT CHECK OTHERWISE
 +-----------------------------------------------------------------------SASDOC*;

PROC SQL NOPRINT;
	SELECT COUNT(*) INTO: RELEASE_IN
	FROM 	&HERCULES..TPHASE_RVR_FILE A 
		   ,&HERCULES..TINITIATIVE_PHASE B
	WHERE 	A.INITIATIVE_ID=&INITIATIVE_ID
		AND A.INITIATIVE_ID=B.INITIATIVE_ID
		AND A.PHASE_SEQ_NB=&PHASE_SEQ_NB
		AND A.PHASE_SEQ_NB=B.PHASE_SEQ_NB
		AND A.RELEASE_STATUS_CD=2
		AND A.RELEASE_TS IS NOT NULL
		AND B.JOB_COMPLETE_TS IS NOT NULL;
QUIT;

%SET_ERROR_FL;

%IF &RELEASE_IN=0 %THEN %DO;

 *SASDOC -----------------------------------------------------------------------
  | TEMPORARY FIX - MANUAL INSERT INTO TINIT_QL_DOC_OVR
  | SHOULD BE REMOVED AFTER THE JAVA FIXES THE BUG 
  | FIX COMMENTED : 21OCT2008 , AS FRONT END HAS TAKEN CARE OF THIS.
  +------------------------------------------------------------------------SASDOC*;

  %INCLUDE "/herc&sysmode/prg/hercules/manual_ins_ovr.sas";

 *SASDOC -----------------------------------------------------------------------
  | DOCUMENT_LOC_CD = 1  INITIATIVE SET-UP
  | INITIATIVE SETUP TABLES: 	TINIT_PHSE_RVE_DOM
  |                             TDOCUMENT_VERSION
  |								TINIT_QL_DOC_OVR (QL)
  |								TINIT_RXCM_DOC_OVR (RXCLM)
  |								TINIT_RECP_DOC_OVR (RECAP)
  +------------------------------------------------------------------------SASDOC*;

 	%IF &DOCUMENT_LOC_CD=1 %THEN %DO;

	%PUT NOTE: DOCUMENT_LOC_CD = 1  INITIATIVE SET-UP;

 *SASDOC -----------------------------------------------------------------------
  | FOR QL ADJUCICATION (TINIT_QL_DOC_OVR)
  | OUTPUT OF THE MAILING PROGRAMS CONTAINS ONLY THE CLIENT_ID AND CPGs AND
  | NOT THE HIERARCHIES. SO FOR QL, TINIT_QL_DOC_OVR IS JOINED AGAINST
  | CLAIMSA.TCPGRP_CLT_PLN_GR1 AND CLAIMSA.TRPTDT_RPT_GRP_DTL TO OBTAIN CPGs
  | TINIT_QL_DOC_OVR IS JOINED AGAINST TDOCUMENT_VERSION, TO CHECK THE VALIDITY OF
  | THE APN_CMCTN_ID 
  +------------------------------------------------------------------------SASDOC*;

 		%IF &QL_ADJ = 1 %THEN %DO;

			%LET HIERARCHY_CONS = %STR( AND A.CLIENT_ID = C.CLIENT_ID
									AND (A.GROUP_CLASS_CD = 0 OR
                 					A.GROUP_CLASS_CD = C.GROUP_CLASS_CD)
            						AND (A.GROUP_CLASS_SEQ_NB = 0 OR
                 					A.GROUP_CLASS_SEQ_NB = C.SEQUENCE_NB)
            						AND (A.BLG_REPORTING_CD = ' ' OR
                 					UPPER(LTRIM(RTRIM(A.BLG_REPORTING_CD))) = UPPER(LTRIM(RTRIM(C.BLG_REPORTING_CD))))
            						AND (A.PLAN_CD_TX = ' ' OR
                 					UPPER(LTRIM(RTRIM(A.PLAN_CD_TX))) = UPPER(LTRIM(RTRIM(C.PLAN_CD))))
            						AND (A.PLAN_EXT_CD_TX = ' ' OR
                 					UPPER(LTRIM(RTRIM(A.PLAN_EXT_CD_TX))) = UPPER(LTRIM(RTRIM(C.PLAN_EXTENSION_CD))))
            						AND (A.GROUP_CD_TX = ' ' OR
                 					UPPER(LTRIM(RTRIM(A.GROUP_CD_TX))) = UPPER(LTRIM(RTRIM(C.GROUP_CD))))
            						AND (A.GROUP_EXT_CD_TX = ' ' OR 
                 					UPPER(LTRIM(RTRIM(A.GROUP_EXT_CD_TX))) = UPPER(LTRIM(RTRIM(C.GROUP_EXTENSION_CD))))
             			     	);

			PROC SQL NOPRINT;
        		CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
				CREATE TABLE QL_DOC_OVR AS
        		SELECT * FROM CONNECTION TO DB2
   				(
				SELECT 	DISTINCT
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
						C.CLT_PLAN_GROUP_ID,
						' ' AS PLAN_NM
				FROM	&HERCULES..TINIT_QL_DOC_OVR A,
				   		&HERCULES..TDOCUMENT_VERSION B,
						(SELECT AA.CLIENT_ID, AA.CLT_PLAN_GROUP_ID,
         		   				AA.PLAN_CD, AA.PLAN_EXTENSION_CD,
			 		   			AA.GROUP_CD, AA.GROUP_EXTENSION_CD,
		 		   				AA.BLG_REPORTING_CD, 
				   				BB.GROUP_CLASS_CD, BB.SEQUENCE_NB
						FROM &CLAIMSA..TCPGRP_CLT_PLN_GR1 AA
				       		,&CLAIMSA..TRPTDT_RPT_GRP_DTL BB
				    	WHERE AA.CLT_PLAN_GROUP_ID=BB.CLT_PLAN_GROUP_ID) C
          		WHERE 	A.INITIATIVE_ID=&INITIATIVE_ID
            		AND A.PHASE_SEQ_NB=&PHASE_SEQ_NB
            		AND CURRENT DATE BETWEEN A.EFFECTIVE_DT AND A.EXPIRATION_DT 
	            	AND A.APN_CMCTN_ID=B.APN_CMCTN_ID
	            	AND CURRENT DATE BETWEEN B.PRODUCTION_DT AND B.EXPIRATION_DT 
					&HIERARCHY_CONS.
				ORDER BY A.CLIENT_ID, C.CLT_PLAN_GROUP_ID
				);
				DISCONNECT FROM DB2;
			QUIT;

			%SET_ERROR_FL;

%*SASDOC -----------------------------------------------------------------------
 | DATASET PLAN_NM FROM CLAIMSA.TPBW_TEMP_CNVRT TABLE FILTERED BASED ON THE
 | RULES PROVIDED IN HERCULES.TINIT_QL_DOC_OVR
 +-------------------------------------------------------------------------SASDOC;

			PROC SQL NOPRINT;
		        CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
				CREATE TABLE PLAN_NM AS
		        SELECT * FROM CONNECTION TO DB2
		   		(
			 	SELECT 	BENEFACTOR_CLT_ID AS CLIENT_ID,
			        	PCL_PBT_ID, 
			        	MOR_PBT_ID, 
			        	POS_PBT_ID, 						
						UPPER(LTRIM(RTRIM(PB_LISTING_NM))) AS PLAN_NM
			 	FROM 	&CLAIMSA..TPBW_TEMP_CNVRT A,
			      		(SELECT CLIENT_ID, PLAN_NM 
						 FROM &HERCULES..TINIT_QL_DOC_OVR RL,
						      &HERCULES..TDOCUMENT_VERSION TD
						 WHERE RL.INITIATIVE_ID=&INITIATIVE_ID
		            	   AND RL.PHASE_SEQ_NB=&PHASE_SEQ_NB
		            	   AND CURRENT DATE BETWEEN RL.EFFECTIVE_DT AND RL.EXPIRATION_DT
						   AND RL.APN_CMCTN_ID = TD.APN_CMCTN_ID
		            	   AND CURRENT DATE BETWEEN TD.PRODUCTION_DT AND TD.EXPIRATION_DT 
					  	   AND (RL.PLAN_NM IS NOT NULL AND RL.PLAN_NM <> ' ') ) B
			 	WHERE 	A.BENEFACTOR_CLT_ID = B.CLIENT_ID AND			       		
						UPPER(LTRIM(RTRIM(A.PB_LISTING_NM))) =  UPPER(LTRIM(RTRIM(B.PLAN_NM)))
				ORDER BY CLIENT_ID, PLAN_NM
		  		);
		    	DISCONNECT FROM DB2;

				SELECT COUNT(*) INTO :PLNMCNT
				FROM PLAN_NM;

			QUIT;

			%SET_ERROR_FL;

			%IF &PLNMCNT >= 1 %THEN %DO;

%*SASDOC -----------------------------------------------------------------------
 | TRANSPOSE COLUMNS PCL_PBT_ID, MOR_PBT_ID, POS_PBT_ID IN DATASET PLAN_NM AND
 | STORE IT AS PB_ID
 +-------------------------------------------------------------------------SASDOC;

			DATA TEMP1 (KEEP=CLIENT_ID PCL_PBT_ID PLAN_NM RENAME=(PCL_PBT_ID=PB_ID))
			     TEMP2 (KEEP=CLIENT_ID MOR_PBT_ID PLAN_NM RENAME=(MOR_PBT_ID=PB_ID))
			     TEMP3 (KEEP=CLIENT_ID POS_PBT_ID PLAN_NM RENAME=(POS_PBT_ID=PB_ID));
			 SET PLAN_NM;
			RUN;

			PROC SQL;
              CREATE TABLE PLAN_NM AS
			  SELECT *, 'PCL_PBT_ID' AS PBT_TYPE
			  FROM TEMP1
			  UNION
			  SELECT *, 'MOR_PBT_ID' AS PBT_TYPE
			  FROM TEMP2
			  UNION
			  SELECT *, 'POS_PBT_ID' AS PBT_TYPE
			  FROM TEMP3;
			QUIT;

			PROC SORT DATA = PLAN_NM;
				BY PBT_TYPE;
			RUN;

		%SET_ERROR_FL;

%*SASDOC -----------------------------------------------------------------------
 | RECREATE DATASET PLAN_NM BY REMOVING ROWS BASED ON DELIVERY_SYSTEM_CD EXCLUSIONS 
 | PROVIDED IN HERCULES.TDELIVERY_SYS_EXCL
 +-------------------------------------------------------------------------SASDOC;

		PROC SQL;
		 CREATE TABLE PLAN_NM2 AS
		 SELECT DISTINCT A.CLIENT_ID, A.PLAN_NM, A.PB_ID
		 FROM PLAN_NM A
		 WHERE NOT EXISTS  (SELECT 1
	           				FROM &HERCULES..TDELIVERY_SYS_EXCL B
			   				WHERE INITIATIVE_ID=&INITIATIVE_ID.
	                          AND A.PBT_TYPE = CASE WHEN DELIVERY_SYSTEM_CD = 1 THEN 'PCL_PBT_ID' 
			  			   							WHEN DELIVERY_SYSTEM_CD = 2 THEN 'POS_PBT_ID'
						   							WHEN DELIVERY_SYSTEM_CD = 3 THEN 'MOR_PBT_ID'
					                           END
							)
         ORDER BY PB_ID;
		QUIT;

		%SET_ERROR_FL;

%*SASDOC -----------------------------------------------------------------------
 | RECREATE DATASET PLAN_NM TO BRING IN CLT_PLAN_GROUP_ID FROM CLAIMSA.TCPG_PB_TRL_HIST
 +-------------------------------------------------------------------------SASDOC;

			PROC SQL;
			 CREATE TABLE PLAN_NM AS
			 SELECT DISTINCT A.CLIENT_ID, A.PLAN_NM, A.PB_ID, B.CLT_PLAN_GROUP_ID,
			        C.LTR_RULE_SEQ_NB, C.CMCTN_ROLE_CD, C.APN_CMCTN_ID
			 FROM PLAN_NM2 A,
			      &CLAIMSA..TCPG_PB_TRL_HIST B,
				  &HERCULES..TINIT_QL_DOC_OVR C
			 WHERE A.PB_ID = B.PB_ID AND
/*			       TODAY() BETWEEN B.EFF_DT AND B.EXP_DT AND*/
	               A.CLIENT_ID = C.CLIENT_ID AND
	               A.PLAN_NM = C.PLAN_NM AND
	               C.INITIATIVE_ID=&INITIATIVE_ID AND
				   C.PHASE_SEQ_NB=&PHASE_SEQ_NB AND
	               TODAY() BETWEEN C.EFFECTIVE_DT AND C.EXPIRATION_DT
             ORDER BY A.CLIENT_ID, B.CLT_PLAN_GROUP_ID;
			QUIT;

			%SET_ERROR_FL;

%*SASDOC -----------------------------------------------------------------------
 | CREATE DATASET INS_QL_DOC_OVR TO BRING IN ONLY CLT_PLAN_GROUP_ID FROM 
 | DATASET PLAN_NM THAT DOES NOT EXIST IN QL_DOC_OVR
 +-------------------------------------------------------------------------SASDOC;

			PROC SQL;
			 CREATE TABLE INS_QL_DOC_OVR AS
			 SELECT A.CLIENT_ID, A.PLAN_NM, A.PB_ID, A.CLT_PLAN_GROUP_ID,
			        A.LTR_RULE_SEQ_NB, A.CMCTN_ROLE_CD, A.APN_CMCTN_ID
			 FROM PLAN_NM A
			 WHERE NOT EXISTS (SELECT 1
			 					FROM QL_DOC_OVR B
								WHERE A.CLIENT_ID = B.CLIENT_ID AND
								      A.CLT_PLAN_GROUP_ID = B.CLT_PLAN_GROUP_ID);
	        QUIT;

			%SET_ERROR_FL;

%*SASDOC -----------------------------------------------------------------------
 | INSERT INTO QL_DOC_OVR FROM INS_QL_DOC_OVR 
 +-------------------------------------------------------------------------SASDOC;

			PROC SQL;
			 INSERT INTO QL_DOC_OVR 
			 (CLIENT_ID, LTR_RULE_SEQ_NB, CMCTN_ROLE_CD, APN_CMCTN_ID,
			  CLT_PLAN_GROUP_ID, PLAN_NM)
			 SELECT CLIENT_ID, LTR_RULE_SEQ_NB, CMCTN_ROLE_CD, APN_CMCTN_ID,
			  CLT_PLAN_GROUP_ID, PLAN_NM
			 FROM INS_QL_DOC_OVR;

			SELECT COUNT(*) INTO :RCNT_QL
			FROM QL_DOC_OVR;

	        QUIT;

			%SET_ERROR_FL;

			%END;

			%ELSE %DO;

			PROC SQL;
				SELECT COUNT(*) INTO :RCNT_QL
				FROM QL_DOC_OVR;
	        QUIT;

			%SET_ERROR_FL;

			%END;
 
 		%END;

 *SASDOC -----------------------------------------------------------------------
  | FOR RXCLM ADJUCICATION (TINIT_RXCM_DOC_OVR)
  | TINIT_RXCM_DOC_OVR IS JOINED AGAINST TDOCUMENT_VERSION, TO CHECK THE VALIDITY OF
  | THE APN_CMCTN_ID 
  +------------------------------------------------------------------------SASDOC*;

 		%IF &RX_ADJ = 1 %THEN %DO;
			PROC SQL NOPRINT;
	        	CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
				CREATE TABLE RXCM_DOC_OVR AS
	        	SELECT * FROM CONNECTION TO DB2
	   			(
				SELECT 	DISTINCT
				 		A.CARRIER_ID, 
						A.ACCOUNT_ID,
			        	A.GROUP_CD,
					 	A.LTR_RULE_SEQ_NB,
					 	A.CMCTN_ROLE_CD,
				     	A.APN_CMCTN_ID
				FROM	&HERCULES..TINIT_RXCM_DOC_OVR A,
					   	&HERCULES..TDOCUMENT_VERSION B
	          	WHERE 	A.INITIATIVE_ID = &INITIATIVE_ID
	            	AND A.PHASE_SEQ_NB = &PHASE_SEQ_NB
	            	AND CURRENT DATE BETWEEN A.EFFECTIVE_DT AND A.EXPIRATION_DT 
	            	AND A.APN_CMCTN_ID=B.APN_CMCTN_ID
	            	AND CURRENT DATE BETWEEN B.PRODUCTION_DT AND B.EXPIRATION_DT 
				);
				DISCONNECT FROM DB2;

				SELECT COUNT(*) INTO :RCNT_RX
				FROM RXCM_DOC_OVR;

			QUIT;

			%SET_ERROR_FL;

 		%END;

 *SASDOC -----------------------------------------------------------------------
  | FOR RECAP ADJUCICATION (TINIT_RECP_DOC_OVR)
  | TINIT_RECP_DOC_OVR IS JOINED AGAINST TDOCUMENT_VERSION, TO CHECK THE VALIDITY OF
  | THE APN_CMCTN_ID 
  +------------------------------------------------------------------------SASDOC*;

	 	%IF &RE_ADJ = 1 %THEN %DO;
			PROC SQL NOPRINT;
	        	CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
				CREATE TABLE RECP_DOC_OVR AS
	        	SELECT * FROM CONNECTION TO DB2
	   			(
				SELECT 	DISTINCT
						A.INSURANCE_CD, 
						A.CARRIER_ID, 
			        	A.GROUP_CD,
					 	A.LTR_RULE_SEQ_NB,
					 	A.CMCTN_ROLE_CD,
				     	A.APN_CMCTN_ID
				FROM	&HERCULES..TINIT_RECP_DOC_OVR A,
					   	&HERCULES..TDOCUMENT_VERSION B
	          	WHERE 	A.INITIATIVE_ID = &INITIATIVE_ID
	            	AND A.PHASE_SEQ_NB = &PHASE_SEQ_NB
	            	AND CURRENT DATE BETWEEN A.EFFECTIVE_DT AND A.EXPIRATION_DT 
	            	AND A.APN_CMCTN_ID=B.APN_CMCTN_ID
	            	AND CURRENT DATE BETWEEN B.PRODUCTION_DT AND B.EXPIRATION_DT 
				);
				DISCONNECT FROM DB2;

				SELECT COUNT(*) INTO :RCNT_RE
				FROM RECP_DOC_OVR;

			QUIT;

			%SET_ERROR_FL;

	 	%END;

 *SASDOC -----------------------------------------------------------------------
  | OBTAIN THE COUNT APN_CMCTN_ID FROM TINIT_PHSE_RVR_DOM FOR THE INITIATIVE_ID
  | NOTE: THIS TABLE WILL BE USED TO OBTAIN APN_CMCTN_ID, FOR CLIENTS AND
  | THEIR HIERARCHIES THAT ARE NOT IN TINIT_ADJ*_DOC_OVR
  +------------------------------------------------------------------------SASDOC*;

		PROC SQL;
	        CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
			SELECT ROWCNT INTO :RCNT_DEF
	        FROM CONNECTION TO DB2
	   		(
			SELECT 	COUNT(*) AS ROWCNT
			FROM	&HERCULES..TINIT_PHSE_RVR_DOM A,
					&HERCULES..TDOCUMENT_VERSION B
	        WHERE 	A.INITIATIVE_ID = &INITIATIVE_ID
	            AND A.PHASE_SEQ_NB = &PHASE_SEQ_NB
	            AND A.APN_CMCTN_ID=B.APN_CMCTN_ID
	            AND CURRENT DATE BETWEEN B.PRODUCTION_DT AND B.EXPIRATION_DT 
			);
			DISCONNECT FROM DB2;
		QUIT;

		%SET_ERROR_FL;

 *SASDOC -----------------------------------------------------------------------
  | IF NO ROWS EXIST IN TINIT_PHSE_RVR_DOM FOR THAT INITIATIVE, GET THE 
  | APN_CMCTN_ID FROM TPGM_TASK_DOM, BASED ON PROGRAM-TASK
  +------------------------------------------------------------------------SASDOC*;
		%LET RCNT_DEF1 = &RCNT_DEF;

		%IF &RCNT_DEF1 = 0 %THEN %DO;

			PROC SQL;
		        CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
				SELECT ROWCNT INTO :RCNT_DEF
		        FROM CONNECTION TO DB2
		   		(
				SELECT 	COUNT(*) AS ROWCNT
				FROM	&HERCULES..TPGM_TASK_DOM A,
						&HERCULES..TDOCUMENT_VERSION B
		          	WHERE 	A.PROGRAM_ID=&PROGRAM_ID
		            	AND A.TASK_ID =&TASK_ID
		/*	            	AND A.PHASE_SEQ_NB = &PHASE_SEQ_NB*/
		            	AND CURRENT DATE BETWEEN A.EFFECTIVE_DT AND A.EXPIRATION_DT 
		            	AND A.APN_CMCTN_ID=B.APN_CMCTN_ID
		            	AND CURRENT DATE BETWEEN B.PRODUCTION_DT AND B.EXPIRATION_DT 
				);
				DISCONNECT FROM DB2;
			QUIT;

			%SET_ERROR_FL;

		%END;

 	%END;

 *SASDOC -----------------------------------------------------------------------
  | DOCUMENT_LOC_CD = 2  PROGRAM-MAINTAINENCE SET-UP
  | PROGRAM-MAINTAINENCE SETUP TABLES: 	TPGM_TASK_DOM
  |                             		TDOCUMENT_VERSION
  |										TPGMTASK_QL_OVR (QL)
  |										TPGMTASK_RXCM_OVR (RXCLM)
  |										TPGMTASK_RECP_OVR (RECAP)
  +------------------------------------------------------------------------SASDOC*;

	 %IF &DOCUMENT_LOC_CD=2 %THEN %DO;

	%PUT NOTE: DOCUMENT_LOC_CD = 2  PROGRAM-MAINTAINENCE SET-UP;

 *SASDOC -----------------------------------------------------------------------
  | FOR QL ADJUCICATION (TPGMTASK_QL_OVR)
  | OUTPUT OF THE MAILING PROGRAMS CONTAINS ONLY THE CLIENT_ID AND CPGs AND
  | NOT THE HIERARCHIES. SO FOR QL, TPGMTASK_QL_OVR IS JOINED AGAINST
  | CLAIMSA.TCPGRP_CLT_PLN_GR1 AND CLAIMSA.TRPTDT_RPT_GRP_DTL TO OBTAIN CPGs
  | TPGMTASK_QL_OVR IS JOINED AGAINST TDOCUMENT_VERSION, TO CHECK THE VALIDITY OF
  | THE APN_CMCTN_ID 
  +------------------------------------------------------------------------SASDOC*;

	 	%IF &QL_ADJ = 1 %THEN %DO;

			%LET HIERARCHY_CONS = %STR( AND A.CLIENT_ID = C.CLIENT_ID
									AND (A.GROUP_CLASS_CD = 0 OR
                 					A.GROUP_CLASS_CD = C.GROUP_CLASS_CD)
            						AND (A.GROUP_CLASS_SEQ_NB = 0 OR
                 					A.GROUP_CLASS_SEQ_NB = C.SEQUENCE_NB)
            						AND (A.BLG_REPORTING_CD = ' ' OR
                 					UPPER(LTRIM(RTRIM(A.BLG_REPORTING_CD))) = UPPER(LTRIM(RTRIM(C.BLG_REPORTING_CD))))
            						AND (A.PLAN_CD_TX = ' ' OR
                 					UPPER(LTRIM(RTRIM(A.PLAN_CD_TX))) = UPPER(LTRIM(RTRIM(C.PLAN_CD))))
            						AND (A.PLAN_EXT_CD_TX = ' ' OR
                 					UPPER(LTRIM(RTRIM(A.PLAN_EXT_CD_TX))) = UPPER(LTRIM(RTRIM(C.PLAN_EXTENSION_CD))))
            						AND (A.GROUP_CD_TX = ' ' OR
                 					UPPER(LTRIM(RTRIM(A.GROUP_CD_TX))) = UPPER(LTRIM(RTRIM(C.GROUP_CD))))
            						AND (A.GROUP_EXT_CD_TX = ' ' OR 
                 					UPPER(LTRIM(RTRIM(A.GROUP_EXT_CD_TX))) = UPPER(LTRIM(RTRIM(C.GROUP_EXTENSION_CD))))
             			     	);

			PROC SQL NOPRINT;
        		CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
				CREATE TABLE QL_DOC_OVR AS
        		SELECT * FROM CONNECTION TO DB2
   				(
				SELECT 	DISTINCT 
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
						C.CLT_PLAN_GROUP_ID,
						' ' AS PLAN_NM
				FROM	&HERCULES..TPGMTASK_QL_OVR A,
					   	&HERCULES..TDOCUMENT_VERSION B,
						(SELECT AA.CLIENT_ID, AA.CLT_PLAN_GROUP_ID,
         		   				AA.PLAN_CD, AA.PLAN_EXTENSION_CD,
			 		   			AA.GROUP_CD, AA.GROUP_EXTENSION_CD,
		 		   				AA.BLG_REPORTING_CD, 
				   				BB.GROUP_CLASS_CD, BB.SEQUENCE_NB
						FROM &CLAIMSA..TCPGRP_CLT_PLN_GR1 AA
				       		,&CLAIMSA..TRPTDT_RPT_GRP_DTL BB
				    	WHERE AA.CLT_PLAN_GROUP_ID=BB.CLT_PLAN_GROUP_ID) C
	          	WHERE 	A.PROGRAM_ID=&PROGRAM_ID
	            	AND A.TASK_ID =&TASK_ID
	            	AND CURRENT DATE BETWEEN A.EFFECTIVE_DT AND A.EXPIRATION_DT 
	            	AND A.APN_CMCTN_ID=B.APN_CMCTN_ID
	            	AND CURRENT DATE BETWEEN B.PRODUCTION_DT AND B.EXPIRATION_DT 
					&HIERARCHY_CONS.
				ORDER BY A.CLIENT_ID, C.CLT_PLAN_GROUP_ID
				);
				DISCONNECT FROM DB2;
			QUIT;

			%SET_ERROR_FL;

%*SASDOC -----------------------------------------------------------------------
 | DATASET PLAN_NM FROM CLAIMSA.TPBW_TEMP_CNVRT TABLE FILTERED BASED ON THE
 | RULES PROVIDED IN HERCULES.TPGMTASK_QL_OVR
 +-------------------------------------------------------------------------SASDOC;
			PROC SQL NOPRINT;
		        CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
				CREATE TABLE PLAN_NM AS
		        SELECT * FROM CONNECTION TO DB2
		   		(
			 	SELECT 	BENEFACTOR_CLT_ID AS CLIENT_ID,
			        	PCL_PBT_ID, 
			        	MOR_PBT_ID, 
			        	POS_PBT_ID, 						
						UPPER(LTRIM(RTRIM(PB_LISTING_NM))) AS PLAN_NM
			 	FROM 	&CLAIMSA..TPBW_TEMP_CNVRT A,
			      		(SELECT CLIENT_ID, PLAN_NM 
						 FROM &HERCULES..TPGMTASK_QL_OVR RL,
						      &HERCULES..TDOCUMENT_VERSION TD
						 WHERE RL.PROGRAM_ID=&PROGRAM_ID
		            	   AND RL.TASK_ID =&TASK_ID
	            		   AND CURRENT DATE BETWEEN RL.EFFECTIVE_DT AND RL.EXPIRATION_DT
						   AND RL.APN_CMCTN_ID = TD.APN_CMCTN_ID
		            	   AND CURRENT DATE BETWEEN TD.PRODUCTION_DT AND TD.EXPIRATION_DT 
					  	   AND (RL.PLAN_NM IS NOT NULL OR RL.PLAN_NM <> ' ') ) B
			 	WHERE 	A.BENEFACTOR_CLT_ID = B.CLIENT_ID AND			       		
						UPPER(LTRIM(RTRIM(A.PB_LISTING_NM))) =  UPPER(LTRIM(RTRIM(B.PLAN_NM)))

				ORDER BY CLIENT_ID, PLAN_NM
		  		);
		    	DISCONNECT FROM DB2;

				SELECT COUNT(*) INTO :PLNMCNT
				FROM PLAN_NM;

			QUIT;

			%SET_ERROR_FL;

			%IF &PLNMCNT >= 1 %THEN %DO;

%*SASDOC -----------------------------------------------------------------------
 | TRANSPOSE COLUMNS PCL_PBT_ID, MOR_PBT_ID, POS_PBT_ID IN DATASET PLAN_NM AND
 | STORE IT AS PB_ID
 +-------------------------------------------------------------------------SASDOC;

			DATA TEMP1 (KEEP=CLIENT_ID PCL_PBT_ID PLAN_NM RENAME=(PCL_PBT_ID=PB_ID))
			     TEMP2 (KEEP=CLIENT_ID MOR_PBT_ID PLAN_NM RENAME=(MOR_PBT_ID=PB_ID))
			     TEMP3 (KEEP=CLIENT_ID POS_PBT_ID PLAN_NM RENAME=(POS_PBT_ID=PB_ID));
			 SET PLAN_NM;
			RUN;

			PROC SQL;
              CREATE TABLE PLAN_NM AS
			  SELECT *, 'PCL_PBT_ID' AS PBT_TYPE
			  FROM TEMP1
			  UNION
			  SELECT *, 'MOR_PBT_ID' AS PBT_TYPE
			  FROM TEMP2
			  UNION
			  SELECT *, 'POS_PBT_ID' AS PBT_TYPE
			  FROM TEMP3;
			QUIT;

			PROC SORT DATA = PLAN_NM;
				BY PBT_TYPE;
			RUN;

		%SET_ERROR_FL;

%*SASDOC -----------------------------------------------------------------------
 | RECREATE DATASET PLAN_NM BY REMOVING ROWS BASED ON DELIVERY_SYSTEM_CD EXCLUSIONS 
 | PROVIDED IN HERCULES.TDELIVERY_SYS_EXCL
 +-------------------------------------------------------------------------SASDOC;

		PROC SQL;
		 CREATE TABLE PLAN_NM2 AS
		 SELECT DISTINCT A.CLIENT_ID, A.PLAN_NM, A.PB_ID
		 FROM PLAN_NM A
		 WHERE NOT EXISTS  (SELECT 1
	           				FROM &HERCULES..TDELIVERY_SYS_EXCL B
			   				WHERE INITIATIVE_ID=&INITIATIVE_ID.
	                          AND A.PBT_TYPE = CASE WHEN DELIVERY_SYSTEM_CD = 1 THEN 'PCL_PBT_ID' 
			  			   							WHEN DELIVERY_SYSTEM_CD = 2 THEN 'POS_PBT_ID'
						   							WHEN DELIVERY_SYSTEM_CD = 3 THEN 'MOR_PBT_ID'
					                           END
							)
         ORDER BY PB_ID;
		QUIT;

		%SET_ERROR_FL;

%*SASDOC -----------------------------------------------------------------------
 | RECREATE DATASET PLAN_NM TO BRING IN CLT_PLAN_GROUP_ID FROM CLAIMSA.TCPG_PB_TRL_HIST
 +-------------------------------------------------------------------------SASDOC;

			PROC SQL;
			 CREATE TABLE PLAN_NM AS
			 SELECT A.CLIENT_ID, A.PLAN_NM, A.PB_ID, B.CLT_PLAN_GROUP_ID,
			        C.LTR_RULE_SEQ_NB, C.CMCTN_ROLE_CD, C.APN_CMCTN_ID
			 FROM PLAN_NM2 A,
			      &CLAIMSA..TCPG_PB_TRL_HIST B,
				  &HERCULES..TPGMTASK_QL_OVR C
			 WHERE A.PB_ID = B.PB_ID AND
/*			       TODAY() BETWEEN B.EFF_DT AND B.EXP_DT AND*/
	               A.CLIENT_ID = C.CLIENT_ID AND
	               A.PLAN_NM = C.PLAN_NM AND
				   C.PROGRAM_ID=&PROGRAM_ID AND
		           C.TASK_ID =&TASK_ID AND
	               TODAY() BETWEEN C.EFFECTIVE_DT AND C.EXPIRATION_DT
             ORDER BY A.CLIENT_ID, B.CLT_PLAN_GROUP_ID;
			QUIT;

			%SET_ERROR_FL;

%*SASDOC -----------------------------------------------------------------------
 | CREATE DATASET INS_QL_DOC_OVR TO BRING IN ONLY CLT_PLAN_GROUP_ID FROM 
 | DATASET PLAN_NM THAT DOES NOT EXIST IN QL_DOC_OVR
 +-------------------------------------------------------------------------SASDOC;

			PROC SQL;
			 CREATE TABLE INS_QL_DOC_OVR AS
			 SELECT A.CLIENT_ID, A.PLAN_NM, A.PB_ID, A.CLT_PLAN_GROUP_ID,
			        A.LTR_RULE_SEQ_NB, A.CMCTN_ROLE_CD, A.APN_CMCTN_ID
			 FROM PLAN_NM A
			 WHERE NOT EXISTS (SELECT 1
			 					FROM QL_DOC_OVR B
								WHERE A.CLIENT_ID = B.CLIENT_ID AND
								      A.CLT_PLAN_GROUP_ID = B.CLT_PLAN_GROUP_ID);
	        QUIT;

			%SET_ERROR_FL;

%*SASDOC -----------------------------------------------------------------------
 | INSERT INTO QL_DOC_OVR FROM INS_QL_DOC_OVR 
 +-------------------------------------------------------------------------SASDOC;

			PROC SQL;
			 INSERT INTO QL_DOC_OVR 
			 (CLIENT_ID, LTR_RULE_SEQ_NB, CMCTN_ROLE_CD, APN_CMCTN_ID,
			  CLT_PLAN_GROUP_ID, PLAN_NM)
			 SELECT CLIENT_ID, LTR_RULE_SEQ_NB, CMCTN_ROLE_CD, APN_CMCTN_ID,
			  CLT_PLAN_GROUP_ID, PLAN_NM
			 FROM INS_QL_DOC_OVR;

			SELECT COUNT(*) INTO :RCNT_QL
			FROM QL_DOC_OVR;

	        QUIT;

			%SET_ERROR_FL;

			%END;   %*&PLNMCNT >= 1;

			%ELSE %DO;

			PROC SQL;
				SELECT COUNT(*) INTO :RCNT_QL
				FROM QL_DOC_OVR;
	        QUIT;

			%SET_ERROR_FL;

			%END;

	 	%END;  %*&QL_ADJ = 1;

 *SASDOC -----------------------------------------------------------------------
  | FOR RXCLM ADJUCICATION (TPGMTASK_RXCLM_OVR)
  | TPGMTASK_RXCLM_OVR IS JOINED AGAINST TDOCUMENT_VERSION, TO CHECK THE VALIDITY OF
  | THE APN_CMCTN_ID 
  +------------------------------------------------------------------------SASDOC*;

	 	%IF &RX_ADJ = 1 %THEN %DO;
			PROC SQL NOPRINT;
	        	CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
				CREATE TABLE RXCM_DOC_OVR AS
	        	SELECT * FROM CONNECTION TO DB2
	   			(
				SELECT 	DISTINCT 
						A.CARRIER_ID, 
						A.ACCOUNT_ID,
			        	A.GROUP_CD,
					 	A.LTR_RULE_SEQ_NB,
					 	A.CMCTN_ROLE_CD,
				     	A.APN_CMCTN_ID
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

	 	%END;

 *SASDOC -----------------------------------------------------------------------
  | FOR RECAP ADJUCICATION (TPGMTASK_RECAP_OVR)
  | TPGMTASK_RECAP_OVR IS JOINED AGAINST TDOCUMENT_VERSION, TO CHECK THE VALIDITY OF
  | THE APN_CMCTN_ID 
  +------------------------------------------------------------------------SASDOC*;

	 	%IF &RE_ADJ = 1 %THEN %DO;
			PROC SQL NOPRINT;
	        	CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
				CREATE TABLE RECP_DOC_OVR AS
	        	SELECT * FROM CONNECTION TO DB2
	   			(
				SELECT 	DISTINCT 
						A.INSURANCE_CD, 
						A.CARRIER_ID, 
			        	A.GROUP_CD,
					 	A.LTR_RULE_SEQ_NB,
					 	A.CMCTN_ROLE_CD,
				     	A.APN_CMCTN_ID
				FROM	&HERCULES..TPGMTASK_RECAP_OVR A,
					   	&HERCULES..TDOCUMENT_VERSION B
	          	WHERE 	A.PROGRAM_ID=&PROGRAM_ID
	            	AND A.TASK_ID =&TASK_ID
	            	AND CURRENT DATE BETWEEN A.EFFECTIVE_DT AND A.EXPIRATION_DT 
	            	AND A.APN_CMCTN_ID=B.APN_CMCTN_ID
	            	AND CURRENT DATE BETWEEN B.PRODUCTION_DT AND B.EXPIRATION_DT 
				);
				DISCONNECT FROM DB2;

				SELECT COUNT(*) INTO :RCNT_RE
				FROM RECP_DOC_OVR;

			QUIT;

			%SET_ERROR_FL;

	 	%END;

 *SASDOC -----------------------------------------------------------------------
  | OBTAIN THE COUNT APN_CMCTN_ID FROM TPGM_TASK_DOM FOR THE PROGRAM-TASK
  | NOTE: THIS TABLE WILL BE USED TO OBTAIN APN_CMCTN_ID, FOR CLIENTS AND
  | THEIR HIERARCHIES THAT ARE NOT IN TPGMTASK_ADJ*_OVR
  +------------------------------------------------------------------------SASDOC*;

		PROC SQL;
	        CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
			SELECT ROWCNT INTO :RCNT_DEF
	        FROM CONNECTION TO DB2
	   		(
			SELECT 	COUNT(*) AS ROWCNT
			FROM	&HERCULES..TPGM_TASK_DOM A,
					&HERCULES..TDOCUMENT_VERSION B
	          	WHERE 	A.PROGRAM_ID=&PROGRAM_ID
	            	AND A.TASK_ID =&TASK_ID
/*	            	AND A.PHASE_SEQ_NB = &PHASE_SEQ_NB*/
	            	AND CURRENT DATE BETWEEN A.EFFECTIVE_DT AND A.EXPIRATION_DT 
	            	AND A.APN_CMCTN_ID=B.APN_CMCTN_ID
	            	AND CURRENT DATE BETWEEN B.PRODUCTION_DT AND B.EXPIRATION_DT 
			);
			DISCONNECT FROM DB2;
		QUIT;

		%SET_ERROR_FL;

		%LET RCNT_DEF1 = &RCNT_DEF;

	 %END;

*SASDOC -----------------------------------------------------------------------------------
  | SET M.V. DOC_COMPLETE_IN_ADJ* = 0/1 BASED ON THE COUNTS FROM ADJ*_DOC_OVR TABLE
  | AND THE DEFAULT OVERRIDE TABLE
  | NOTE: THIS M.V. DOC_COMPLETE_IN_ADJ* IS PASSED ON TO THE CODE THAT CALLS CHECK_DOCUMENT
  +--------------------------------------------------------------------------------SASDOC*;

	%IF &QL_ADJ = 1 %THEN %DO;
		%IF &RCNT_QL >= 1 OR &RCNT_DEF >= 1 %THEN %DO;
       		%LET DOC_COMPLETE_IN_QL = 1;
       		%PUT NOTE:(&SYSMACRONAME) INITIATIVE &INITIATIVE_ID HAS EFFECTIVE APN_CMCTN_IDS;
       		%PUT NOTE:(&SYSMACRONAME) THE RESULT FILES PREFIXED WITH %STR(%'&TABLE_PREFIX%') ARE EFFECTIVE AS OF &SYSDATE9.;
		%END;
		%ELSE %DO;
       		%LET DOC_COMPLETE_IN_QL = 0;
       		%PUT NOTE:(&SYSMACRONAME) INITIATIVE &INITIATIVE_ID HAS NO EFFECTIVE APN_CMCTN_IDS;
       		%PUT NOTE:(&SYSMACRONAME) VERIFY BEFORE RELEASING THE FILE;
		%END;
	%END;

	%IF &RX_ADJ = 1 %THEN %DO;
		%IF &RCNT_RX >= 1 OR &RCNT_DEF >= 1 %THEN %DO;
       		%LET DOC_COMPLETE_IN_RX = 1;
       		%PUT NOTE:(&SYSMACRONAME) INITIATIVE &INITIATIVE_ID HAS EFFECTIVE APN_CMCTN_IDS;
       		%PUT NOTE:(&SYSMACRONAME) THE RESULT FILES PREFIXED WITH %STR(%'&TABLE_PREFIX%') ARE EFFECTIVE AS OF &SYSDATE9.;
		%END;
		%ELSE %DO;
       		%LET DOC_COMPLETE_IN_RX = 0;
       		%PUT NOTE:(&SYSMACRONAME) INITIATIVE &INITIATIVE_ID HAS NO EFFECTIVE APN_CMCTN_IDS;
       		%PUT NOTE:(&SYSMACRONAME) VERIFY BEFORE RELEASING THE FILE;
		%END;
	%END;

	%IF &RE_ADJ = 1 %THEN %DO;
		%IF &RCNT_RE >= 1 OR &RCNT_DEF >= 1 %THEN %DO;
       		%LET DOC_COMPLETE_IN_RE = 1;
       		%PUT NOTE:(&SYSMACRONAME) INITIATIVE &INITIATIVE_ID HAS EFFECTIVE APN_CMCTN_IDS;
       		%PUT NOTE:(&SYSMACRONAME) THE RESULT FILES PREFIXED WITH %STR(%'&TABLE_PREFIX%') ARE EFFECTIVE AS OF &SYSDATE9.;
		%END;
		%ELSE %DO;
       		%LET DOC_COMPLETE_IN_RE = 0;
       		%PUT NOTE:(&SYSMACRONAME) INITIATIVE &INITIATIVE_ID HAS NO EFFECTIVE APN_CMCTN_IDS;
       		%PUT NOTE:(&SYSMACRONAME) VERIFY BEFORE RELEASING THE FILE;
		%END;
	%END;

*SASDOC -----------------------------------------------------------------------------------
  | DERIVE MV DOC_COMPLETE_IN BASED ON DOC_COMPLETE_IN_QL, DOC_COMPLETE_IN_RX,
  | DOC_COMPLETE_IN_RE
  +--------------------------------------------------------------------------------SASDOC*;

	%IF &DOC_COMPLETE_IN_QL = 1 AND 
	    &DOC_COMPLETE_IN_RX = 1 AND 
	    &DOC_COMPLETE_IN_RE = 1 
	%THEN  %LET DOC_COMPLETE_IN = 1;
	%ELSE  %LET DOC_COMPLETE_IN = 0;

	%PUT NOTE: DOC_COMPLETE_IN = &DOC_COMPLETE_IN;

*SASDOC -----------------------------------------------------------------------------------
  | MACRO DOC_UPDT CONTAINS THE SET OF QUERIES THAT NEEDS TO BE EXECUTED FOR ALL 3
  | ADJUDICATIONS. THIS MACRO WILL BE CALLED BASED ON THE ADJUDICATIONS THAT ARE TURNED ON 
  | FOR THE CORRESPONDING INITIATIVE / PROGRAM-TASK
  +--------------------------------------------------------------------------------SASDOC*;

	%MACRO DOC_UPDT (RCNT_ADJ=, RCNT_DEF=, ADJ_ENGINE=);

	%PUT &ADJ_ENGINE;

	%*SASDOC -----------------------------------------------------------------------
 	| OBTAIN THE LIST OF CMCTN_ROLE_CDS CORRESPONDING TO THE INITIATIVE_ID.
 	| ALSO GET THE COUNT OF CMCTN_ROLE_CD ASSOCIATED WITH THE INITIATIVE_ID.
 	| NOTE: BASED ON THE COUNT THOSE MANY INPUT/OUTPUT TABLES ARE PROCESSED
 	+-------------------------------------------------------------------------SASDOC;

	DATA _NULL_;
		SET &HERCULES..TPHASE_RVR_FILE(WHERE=(INITIATIVE_ID=&INITIATIVE_ID AND PHASE_SEQ_NB=&PHASE_SEQ_NB)) END=EOF;
		CALL SYMPUT('CMCTN_ROLE_CD' || TRIM(LEFT(PUT(_N_,1.) )), TRIM(LEFT(PUT(CMCTN_ROLE_CD,1.) )));
		IF EOF THEN CALL SYMPUT('N_FILES', PUT(_N_,1.) );
	RUN;
	%PUT NOTE: COUNT OF CMCTN_ROLE_CD ASSOCIATED WITH INITIATIVE_ID &INITIATIVE_ID IS &N_FILES;

	%*SASDOC -----------------------------------------------------------------------
 	| LOOP THE UPDATE PROCESS TO RUN FOR ALL CMCTN_ROLE_CD
 	+-------------------------------------------------------------------------SASDOC;

	%DO I=1 %TO &N_FILES;

	%*SASDOC ----------------------------------------------------------------------------
 	| NOTE: THIS CHECK WAS ADDED SO THAT THE CHECK DOCUMENT CAN ALSO RUN FOR
	|       MAILING PROGRAMS THAT HAS NOT BEEN MODIFIED FOR HERCULES II
	|       MODIFICATIONS MADE TO HERCULES II INCLUDE ALL ADJUDICATIONS AND 
	|       ALSO TO HIERARCHIES OTHER THAN CLIENT_ID FOR QL. SO THE LOGIC USES 
	|       FIELD ADJ_ENGINE, CLIENT_LEVEL_1 ETC WHEN IT RUNS FOR MODIFIED MAILING
	|       CODES.        
 	+------------------------------------------------------------------------------SASDOC;

	%*SASDOC ----------------------------------------------------------------------------
 	| Validate if client_level_1 variable exists within dataset
 	+------------------------------------------------------------------------------SASDOC;
	PROC SQL;
	 SELECT COUNT(*) INTO :CLIENTVARIABLE
	 FROM DICTIONARY.COLUMNS
	 WHERE LIBNAME= "DATA_PND" 
	       AND MEMNAME = "%UPCASE(&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.)"
		   AND UPCASE(NAME) = "CLIENT_LEVEL_1";
	QUIT;

	%*SASDOC ----------------------------------------------------------------------------
 	| Validate the values of client_level_1 variable within dataset
 	+------------------------------------------------------------------------------SASDOC;
		%IF &CLIENTVARIABLE. > 0 %THEN %DO;
		PROC SQL;
		 SELECT MAX(CLIENT_LEVEL_1) INTO :MODMAIL
		 FROM DATA_PND.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.;
		QUIT;
	%END;
	%ELSE %DO;
	    %LET MODMAIL = ;
	%END;

	%SET_ERROR_FL;

	%IF &CLIENTVARIABLE. > 0 AND %SYSFUNC(EXIST(DATA_PND.CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.))
    %THEN %DO;
		PROC SQL;
		 SELECT MAX(CLIENT_LEVEL_1) INTO :MODMAIL1
		 FROM DATA_PND.CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.;
		QUIT;
	%END;
	%ELSE %DO;
	    %LET MODMAIL1 = ;
	%END;


	%SET_ERROR_FL;

    %put NOTE:  CLIENTVARIABLE = &CLIENTVARIABLE. ;
	%put NOTE:  MODMAIL        = &MODMAIL. ;
	%put NOTE:  MODMAIL1        = &MODMAIL1. ;

	%IF (&PROGRAM_ID EQ 5295 OR &PROGRAM_ID EQ 105 OR (&PROGRAM_ID EQ 106 AND &TASK_ID EQ 21)) %THEN %DO;
		%IF &MODMAIL. EQ AND &MODMAIL1. NE %THEN %DO;
			%LET MODMAIL = 1;
		%END;
	%END;


	%*SASDOC ----------------------------------------------------------------------------
 	| If the client_level_1 variable exists and has valid values assign macro variables
 	+------------------------------------------------------------------------------SASDOC;
	%IF &CLIENTVARIABLE. > 0 AND &MODMAIL. NE %THEN %DO;
		%LET ADJ_CONS = %STR(AND A.ADJ_ENGINE = "&ADJ_ENGINE.");
		%LET CPG_CONS = %STR(AND A.CLIENT_LEVEL_1  = LEFT(PUT(B.CLT_PLAN_GROUP_ID,20.))
                             );
		%LET RX_CONS =  %STR(AND substr(B.CARRIER_ID,2,20) = A.CLIENT_LEVEL_1
            				AND (B.ACCOUNT_ID = ' ' OR 
                 			UPCASE(LEFT(TRIM(B.ACCOUNT_ID))) = UPCASE(LEFT(TRIM(A.CLIENT_LEVEL_2))))
            				AND (B.GROUP_CD = ' ' OR 
                 			UPCASE(LEFT(TRIM(B.GROUP_CD))) = UPCASE(LEFT(TRIM(A.CLIENT_LEVEL_3))))
             			     );
		%LET RE_CONS = %STR(AND B.INSURANCE_CD = A.CLIENT_LEVEL_1
            				AND (B.CARRIER_ID = ' ' OR 
                 			UPCASE(LEFT(TRIM(substr(B.CARRIER_ID,2,20)))) = UPCASE(LEFT(TRIM(A.CLIENT_LEVEL_2))))
            				AND (B.GROUP_CD = ' ' OR 
                 			UPCASE(LEFT(TRIM(B.GROUP_CD))) = UPCASE(LEFT(TRIM(A.CLIENT_LEVEL_3))))
             			     );
		%LET RX_RE_CLT_CONS = %STR();

		/*********************************************************************/
		/** keep only CPGs associated to the participants for the initiative */
		/*********************************************************************/
		%IF %SYSFUNC(EXIST(DATA_PND.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.))
             AND &QL_ADJ = 1 %THEN %DO;
		
			DATA QL_DOC_OVR;
			  SET QL_DOC_OVR;
			  CLIENT_LEVEL_1=LEFT(PUT(CLT_PLAN_GROUP_ID,20.));
			RUN;

			PROC SORT DATA = QL_DOC_OVR;
			 BY CLIENT_LEVEL_1;
			RUN;
			
			PROC SORT DATA = DATA_PND.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.
				  OUT  = TEMP001 (KEEP = CLIENT_LEVEL_1) NODUPKEY;
			 BY CLIENT_LEVEL_1;
			RUN;
			
			DATA QL_DOC_OVR (DROP = CLIENT_LEVEL_1);
			 MERGE QL_DOC_OVR (IN=A)
			       TEMP001    (IN=B);
			 BY CLIENT_LEVEL_1;
			 IF A AND B;
			RUN;			
		%END;


	%END;
	%*SASDOC ----------------------------------------------------------------------------
 	| If the client_level_1 variable is not a factor assign macro variables to null
 	+------------------------------------------------------------------------------SASDOC;
	%ELSE %DO;
		%LET ADJ_CONS = %STR( );
		%LET CPG_CONS = %STR( );
		%LET RX_CONS =  %STR( );
		%LET RE_CONS =  %STR( );

%*SASDOC -----------------------------------------------------------------------
  | MACRO CHK_DOC_CLTID_FIX, DETERMINES THE CLIENT_ID ASSOCIATED TO A CARRIER_ID OR AN INSURANCE_CD
  | FOR RXCLM/RECAP CLIENTS, WHEN THE CLIENT HIERARCHIES ARE NOT POPULATED
  | IN THE PENDING DATASET FOR RX/RE INITIATIVES
 +-----------------------------------------------------------------------SASDOC*;

		%CHK_DOC_CLTID_FIX;

		%IF &ADJ_ENGINE=QL %THEN %DO;

			PROC SORT DATA = QL_DOC_OVR (KEEP = CLIENT_ID APN_CMCTN_ID LTR_RULE_SEQ_NB CMCTN_ROLE_CD) NODUPKEY;
				BY  CLIENT_ID CMCTN_ROLE_CD LTR_RULE_SEQ_NB;
			RUN;

		%END;

		%IF &ADJ_ENGINE=RX %THEN %DO;

			PROC SORT DATA = RXCM_DOC_OVR (KEEP = CLIENT_ID APN_CMCTN_ID LTR_RULE_SEQ_NB CMCTN_ROLE_CD) NODUPKEY;
				BY  CLIENT_ID CMCTN_ROLE_CD LTR_RULE_SEQ_NB;
			RUN;

		%END;

		%IF &ADJ_ENGINE=RE %THEN %DO;

			PROC SORT DATA = RECP_DOC_OVR (KEEP = CLIENT_ID APN_CMCTN_ID LTR_RULE_SEQ_NB CMCTN_ROLE_CD) NODUPKEY;
				BY  CLIENT_ID CMCTN_ROLE_CD LTR_RULE_SEQ_NB;
			RUN;

		%END;

		%LET RX_RE_CLT_CONS = %STR(A.CLIENT_ID = B.CLIENT_ID AND);

	%END;

	%PUT NOTE: CPG_CONS = &CPG_CONS;
	%PUT NOTE: RX_CONS = &RX_CONS;
	%PUT NOTE: RE_CONS = &RE_CONS;
	%PUT NOTE: ADJ_CONS = &ADJ_CONS;

	%*SASDOC -----------------------------------------------------------------------
 	| SET MVs OVR_TBL_IN, HIERARCHY_OVR_CONS BASED ON THE ADJUDICATION
	| ENGINE. THESE MACRO VARIABLES WILL BE REFERENCED IN THE QUERIES BELOW
 	+-------------------------------------------------------------------------SASDOC;

	%IF &ADJ_ENGINE = QL %THEN %DO;
		%LET OVR_TBL_IN = QL_DOC_OVR;
		%LET HIERARCHY_OVR_CONS = %STR( A.CLIENT_ID = B.CLIENT_ID 
										AND B.CMCTN_ROLE_CD = &&CMCTN_ROLE_CD&I.
										&CPG_CONS.
             			     			);
	%END;

	%IF &ADJ_ENGINE = RX %THEN %DO;
		%LET OVR_TBL_IN = RXCM_DOC_OVR;
		%LET HIERARCHY_OVR_CONS = %STR( &RX_RE_CLT_CONS.
										B.CMCTN_ROLE_CD = &&CMCTN_ROLE_CD&I.
										&RX_CONS.
             			     			);
	%END;
	%IF &ADJ_ENGINE = RE %THEN %DO;
		%LET OVR_TBL_IN = RECP_DOC_OVR;
		%LET HIERARCHY_OVR_CONS = %STR( &RX_RE_CLT_CONS.
										B.CMCTN_ROLE_CD = &&CMCTN_ROLE_CD&I.
										&RE_CONS.
             			     			);
	%END;

	%*SASDOC -----------------------------------------------------------------------
 	| SET MVs INNERQUERY BASED ON THE DOCUMENT_LOC_CD
	| THIS MACRO VARIABLE WILL BE REFERENCED IN THE QUERIES BELOW
 	+-------------------------------------------------------------------------SASDOC;

	%IF &DOCUMENT_LOC_CD = 1 AND &RCNT_DEF1 > 0 %THEN
		%LET INNERQUERY = %STR(	SELECT DISTINCT BBB.LTR_RULE_SEQ_NB, BBB.APN_CMCTN_ID
					  			FROM &HERCULES..TINIT_PHSE_RVR_DOM BBB,
					       		 	 &HERCULES..TDOCUMENT_VERSION CCC
	                   			WHERE BBB.INITIATIVE_ID = &INITIATIVE_ID
	                     	  	  AND BBB.PHASE_SEQ_NB = &PHASE_SEQ_NB
						 	  	  AND BBB.CMCTN_ROLE_CD = &&CMCTN_ROLE_CD&I
	                     	  	  AND BBB.APN_CMCTN_ID = CCC.APN_CMCTN_ID
	                     	  	  AND TODAY() BETWEEN CCC.PRODUCTION_DT AND CCC.EXPIRATION_DT);

	%IF &DOCUMENT_LOC_CD = 1 AND &RCNT_DEF1 = 0 %THEN
		%LET INNERQUERY = %STR( SELECT DISTINCT BBB.LTR_RULE_SEQ_NB, BBB.APN_CMCTN_ID 
						   	    FROM &HERCULES..TPGM_TASK_DOM BBB,
									 &HERCULES..TDOCUMENT_VERSION CCC
	          			   		WHERE BBB.PROGRAM_ID=&PROGRAM_ID
	            			 	  AND BBB.TASK_ID =&TASK_ID
	            			 	  AND BBB.PHASE_SEQ_NB = &PHASE_SEQ_NB
	            			 	  AND TODAY() BETWEEN BBB.EFFECTIVE_DT AND BBB.EXPIRATION_DT 
	            			 	  AND BBB.APN_CMCTN_ID=CCC.APN_CMCTN_ID
	            			 	  AND TODAY() BETWEEN CCC.PRODUCTION_DT AND CCC.EXPIRATION_DT);


	%IF &DOCUMENT_LOC_CD = 2 %THEN
		%LET INNERQUERY = %STR( SELECT DISTINCT BBB.LTR_RULE_SEQ_NB, BBB.APN_CMCTN_ID 
						   	    FROM &HERCULES..TPGM_TASK_DOM BBB,
									 &HERCULES..TDOCUMENT_VERSION CCC
	          			   		WHERE BBB.PROGRAM_ID=&PROGRAM_ID
	            			 	  AND BBB.TASK_ID =&TASK_ID
	            			 	  AND BBB.PHASE_SEQ_NB = &PHASE_SEQ_NB
	            			 	  AND TODAY() BETWEEN BBB.EFFECTIVE_DT AND BBB.EXPIRATION_DT 
	            			 	  AND BBB.APN_CMCTN_ID=CCC.APN_CMCTN_ID
	            			 	  AND TODAY() BETWEEN CCC.PRODUCTION_DT AND CCC.EXPIRATION_DT);

	%IF &DOCUMENT_LOC_CD = 2 AND (&PROGRAM_ID EQ 5295 OR &PROGRAM_ID EQ 105 
                              OR (&PROGRAM_ID EQ 106 AND &TASK_ID EQ 21)) %THEN		
			%LET INNERQUERY = %STR( SELECT DISTINCT BBB.LTR_RULE_SEQ_NB, BBB.APN_CMCTN_ID 
							   	    FROM &HERCULES..TPGM_TASK_DOM BBB,
										 &HERCULES..TDOCUMENT_VERSION CCC
		          			   		WHERE BBB.PROGRAM_ID=&PROGRAM_ID
		            			 	  AND BBB.TASK_ID =&TASK_ID
		            			 	  AND BBB.PHASE_SEQ_NB = &PHASE_SEQ_NB
									  AND BBB.CMCTN_ROLE_CD = &&CMCTN_ROLE_CD&I
		            			 	  AND TODAY() BETWEEN BBB.EFFECTIVE_DT AND BBB.EXPIRATION_DT 
		            			 	  AND BBB.APN_CMCTN_ID=CCC.APN_CMCTN_ID
	            			 	  AND TODAY() BETWEEN CCC.PRODUCTION_DT AND CCC.EXPIRATION_DT);
    %PUT &INNERQUERY;

	%*SASDOC ----------------------------------------------------------------------------
 	| IF DATASET DATA_PND.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I EXISTS, RENAME THE DATASET
	| WITH PREFIX CHKDOC_RN_&SYSJOBID._
 	+------------------------------------------------------------------------------SASDOC;


		%IF %SYSFUNC(EXIST(DATA_PND.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.)) AND 
            NOT %SYSFUNC(EXIST(DATA_PND.CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.)) %THEN %DO;
				PROC DATASETS LIBRARY = DATA_PND;
					CHANGE &TABLE_PREFIX._&&CMCTN_ROLE_CD&I. = CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.;
				QUIT; RUN;
		%END;

		%IF %SYSFUNC(EXIST(DATA_PND.CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.)) %THEN %DO;

	%*SASDOC ----------------------------------------------------------------------------
 	| CREATE DATASET &TABLE_PREFIX._&&CMCTN_ROLE_CD&I._&ADJ_ENGINE_CD. FROM 
	| DATA_PND.CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I. WITH UPDATED
	| APN_CMCTN_ID SPECIFIED IN THE DEFAULT DOCUMENT TABLES, 
	| IF NO ROWS EXISTS IN OVERRIDE TABLES
 	+------------------------------------------------------------------------------SASDOC;

  			%IF &RCNT_DEF >= 1 AND &RCNT_ADJ = 0 %THEN %DO;

         		PROC SQL;
         			CREATE TABLE DATA_RES.&ADJ_ENGINE._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I. AS
       				SELECT A.*, AA.APN_CMCTN_ID
         			FROM DATA_PND.CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I. (DROP=APN_CMCTN_ID) A ,
                     	 (&INNERQUERY.) AA
          			WHERE A.LTR_RULE_SEQ_NB = AA.LTR_RULE_SEQ_NB
				  	  &ADJ_CONS.;
				QUIT; 

				%SET_ERROR_FL;

			%END;

	%*SASDOC ----------------------------------------------------------------------------
 	| CREATE DATASET &TABLE_PREFIX._&&CMCTN_ROLE_CD&I._&ADJ_ENGINE_CD. FROM 
	| DATA_PND.CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I. WITH UPDATED
	| APN_CMCTN_ID SPECIFIED IN THE OVERRIDE AND DEFAULT DOCUMENT TABLES, 
	| IF ROWS EXISTS IN OVERRIDE TABLES
 	+------------------------------------------------------------------------------SASDOC;

  			%IF &RCNT_DEF >= 1 AND &RCNT_ADJ >= 1 %THEN %DO;

				PROC SQL;
	        		CREATE TABLE DATA_RES.&ADJ_ENGINE._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I. AS

       				SELECT A.*, AA.APN_CMCTN_ID
         			FROM DATA_PND.CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I. (DROP=APN_CMCTN_ID) A ,
                     	 (&INNERQUERY.) AA
          			WHERE A.LTR_RULE_SEQ_NB = AA.LTR_RULE_SEQ_NB
				  	  &ADJ_CONS.
				  	  AND NOT EXISTS (SELECT 1
				                  	  FROM &OVR_TBL_IN. B
								  	  WHERE &HIERARCHY_OVR_CONS.)

	         		UNION ALL

	         		SELECT A.*, B.APN_CMCTN_ID 
	          		FROM DATA_PND.CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I. (DROP=APN_CMCTN_ID) A,
                     	 &OVR_TBL_IN. B
	         		WHERE A.LTR_RULE_SEQ_NB=B.LTR_RULE_SEQ_NB
	           	  	  AND B.CMCTN_ROLE_CD=&&CMCTN_ROLE_CD&I
				  	  &ADJ_CONS.
                  	  AND &HIERARCHY_OVR_CONS.;
	        	QUIT;

				%SET_ERROR_FL;

			%END;

			PROC APPEND BASE = DATA_PND.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.
			            DATA = DATA_RES.&ADJ_ENGINE._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.;
			RUN;

			PROC SQL;
				DROP TABLE DATA_RES.&ADJ_ENGINE._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.;
			QUIT;

			%SET_ERROR_FL;


		%END; /* END OF PENDING DATASET EXIST LOOP */

	%*SASDOC ----------------------------------------------------------------------------
 	| IF DATASET DATA_RES.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I EXISTS, RENAME THE DATASET
	| WITH PREFIX CHKDOC_RN_&SYSJOBID._
 	+------------------------------------------------------------------------------SASDOC;

		%IF %SYSFUNC(EXIST(DATA_RES.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.)) AND 
            NOT %SYSFUNC(EXIST(DATA_RES.CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.)) %THEN %DO;
				PROC DATASETS LIBRARY = DATA_RES;
					CHANGE &TABLE_PREFIX._&&CMCTN_ROLE_CD&I. = CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.;
				QUIT; RUN;
		%END;

		%IF %SYSFUNC(EXIST(DATA_RES.CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.)) %THEN %DO;

	%*SASDOC ----------------------------------------------------------------------------
 	| CREATE DATASET &TABLE_PREFIX._&&CMCTN_ROLE_CD&I._&ADJ_ENGINE_CD. FROM 
	| DATA_PND.CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I. WITH UPDATED
	| APN_CMCTN_ID SPECIFIED IN THE DEFAULT DOCUMENT TABLES, 
	| IF NO ROWS EXISTS IN OVERRIDE TABLES
 	+------------------------------------------------------------------------------SASDOC;

  			%IF &RCNT_DEF >= 1 AND &RCNT_ADJ = 0 %THEN %DO;

         		PROC SQL;
         			CREATE TABLE DATA_RES.&ADJ_ENGINE._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I. AS
       				SELECT A.*, AA.APN_CMCTN_ID
         			FROM DATA_RES.CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I. (DROP=APN_CMCTN_ID) A ,
                     	 (&INNERQUERY.) AA
          			WHERE A.LTR_RULE_SEQ_NB = AA.LTR_RULE_SEQ_NB
				  	  &ADJ_CONS.;
				QUIT; 

				%SET_ERROR_FL;

			%END;


	%*SASDOC ----------------------------------------------------------------------------
 	| CREATE DATASET &TABLE_PREFIX._&&CMCTN_ROLE_CD&I._&ADJ_ENGINE_CD. FROM 
	| DATA_PND.CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I. WITH UPDATED
	| APN_CMCTN_ID SPECIFIED IN THE OVERRIDE AND DEFAULT DOCUMENT TABLES, 
	| IF ROWS EXISTS IN OVERRIDE TABLES
 	+------------------------------------------------------------------------------SASDOC;

  			%IF &RCNT_DEF >= 1 AND &RCNT_ADJ >= 1 %THEN %DO;

				PROC SQL;
	        		CREATE TABLE DATA_RES.&ADJ_ENGINE._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I. AS

       				SELECT A.*, AA.APN_CMCTN_ID
         			FROM DATA_RES.CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I. (DROP=APN_CMCTN_ID) A ,
                     	 (&INNERQUERY.) AA
          			WHERE A.LTR_RULE_SEQ_NB = AA.LTR_RULE_SEQ_NB
				  	  &ADJ_CONS.
				  	  AND NOT EXISTS (SELECT 1
				                  	  FROM &OVR_TBL_IN. B
								  	  WHERE &HIERARCHY_OVR_CONS.)

	         		UNION ALL

	         		SELECT A.*, B.APN_CMCTN_ID 
	          		FROM DATA_RES.CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I. (DROP=APN_CMCTN_ID) A,
                     	 &OVR_TBL_IN. B
	         		WHERE A.LTR_RULE_SEQ_NB=B.LTR_RULE_SEQ_NB
	           	  	  AND B.CMCTN_ROLE_CD=&&CMCTN_ROLE_CD&I
				  	  &ADJ_CONS.
                  	  AND &HIERARCHY_OVR_CONS.;
	        	QUIT;

				%SET_ERROR_FL;

			%END;
				

			PROC APPEND BASE = DATA_RES.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.
			            DATA = DATA_RES.&ADJ_ENGINE._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.;
			RUN;

			%SET_ERROR_FL;

			PROC SQL;
				DROP TABLE DATA_RES.&ADJ_ENGINE._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.;
			QUIT;


		%END; /* END OF RESOLVED DATASET EXIST LOOP */

	%*SASDOC ----------------------------------------------------------------------------------
 	| IF ERROR_CD = 1 THEN REPLACE THE ORIGINAL PENDING / RESOLVED BACK
 	+------------------------------------------------------------------------------------SASDOC;

		%IF &ERR_FL =1 %THEN %DO;
				PROC SQL;
				 DROP TABLE DATA_PND.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.;
				QUIT;
				PROC SQL;
				 DROP TABLE DATA_RES.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.;
				QUIT;

				PROC DATASETS LIBRARY = DATA_PND;
					CHANGE CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I. = &TABLE_PREFIX._&&CMCTN_ROLE_CD&I.;
				QUIT; RUN;

				PROC DATASETS LIBRARY = DATA_RES;
					CHANGE CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I. = &TABLE_PREFIX._&&CMCTN_ROLE_CD&I.;
				QUIT; RUN;
		%END;



	%*SASDOC ----------------------------------------------------------------------------------
 	| FINAL VERFY THE MAILING FILE TO BE RELEASED DOES NOT HAVE NULLS IN THE APN_CMCTN_ID FIELD
 	+------------------------------------------------------------------------------------SASDOC;

		PROC SQL NOPRINT;
     		SELECT COUNT(*) INTO: APN_ID_NULL_CNT
     		FROM DATA_PND.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I A
     		WHERE A.APN_CMCTN_ID IS NULL 
                  &ADJ_CONS.; 
		QUIT;

		%SET_ERROR_FL;

		DATA _NULL_;
     		SET &HERCULES..TPHASE_RVR_FILE(WHERE=(INITIATIVE_ID=&INITIATIVE_ID));
     		CALL SYMPUT('FILE_USAGE_CD', PUT(FILE_USAGE_CD, 1.));
      		CALL SYMPUT('RELEASE_STATUS_CD', PUT(RELEASE_STATUS_CD, 1.));
     	RUN;

		%PUT APN_ID_NULL_CNT=&APN_ID_NULL_CNT, FILE_USAGE_CD= &FILE_USAGE_CD;

		%IF &APN_ID_NULL_CNT>0 AND &FILE_USAGE_CD =1 AND &RELEASE_STATUS_CD=2 %THEN %DO;
     		%LET DOC_COMPLETE_IN=0;
     		%PUT HERC_NOTE: FILE DATA_PND.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I HAS NULLS ON APN_CMCTN_ID FIELD. FOR ADJ &ADJ_ENGINE.;
     		%PUT HERC_NOTE: DOC_COMPLETE_IN HAS BEEN SET TO 0 AND MAILING FILE WILL NOT BE CREATED. ;

	%*SASDOC ----------------------------------------------------------------------------------
 	| BECAUSE THERE WERE NULL APN_CMCTN_ID IN THE DATASET, THE ORIGINAL DATASET THAT GOT RENAMED
	| WITH PREFIX CHKDOC_RN_&SYSJOBID._ IS RENAMED BACK TO THE DATASET NAME AS IT WAS PRIOR 
	| BEFORE THE PROCESS STARTED
 	+------------------------------------------------------------------------------------SASDOC;
			%IF %SYSFUNC(EXIST(DATA_PND.CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.)) %THEN %DO;
				PROC DATASETS LIBRARY = DATA_PND;
					CHANGE CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I. = &TABLE_PREFIX._&&CMCTN_ROLE_CD&I.;
				QUIT; RUN;
			%END;

			%IF %SYSFUNC(EXIST(DATA_RES.CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I.)) %THEN %DO;
				PROC DATASETS LIBRARY = DATA_RES;
					CHANGE CHKDOC_RN_&SYSJOBID._&TABLE_PREFIX._&&CMCTN_ROLE_CD&I. = &TABLE_PREFIX._&&CMCTN_ROLE_CD&I.;
				QUIT; RUN;
			%END;

			%SET_ERROR_FL;


	%*SASDOC ----------------------------------------------------------------------------------
 	| BECAUSE THERE WERE NULL APN_CMCTN_ID IN THE DATASET, THE PROCESS IS FORCED TO FAIL
	| WITH AN ERROR MESSAGE SENT TO HERCULES SUPPORT.
 	+------------------------------------------------------------------------------------SASDOC;
			%LET ERR_FL = 1;

			%ON_ERROR( ACTION=ABORT
	          ,EM_TO=&PRIMARY_PROGRAMMER_EMAIL
	          ,EM_SUBJECT=HCE SUPPORT: NOTIFICATION OF ABEND INITIATIVE_ID &INITIATIVE_ID
	          ,EM_MSG=%STR(A PROBLEM WAS ENCOUNTERED AT THE CHECK DOCUMENT MACRO BECAUSE FILE DATA_PND.&TABLE_PREFIX._&&CMCTN_ROLE_CD&I HAS NULLS ON APN_CMCTN_ID FIELD. FOR ADJ &ADJ_ENGINE.));

		%END;

	%END; /* END OF DO LOOP */

	%MEND DOC_UPDT;

*SASDOC -----------------------------------------------------------------------------------
  | MACRO DOC_UPDT IS CALLED FOR ALL 3 ADJUDICATIONS
  +--------------------------------------------------------------------------------SASDOC*;

	%IF &QL_ADJ = 1 %THEN 
		%DOC_UPDT(RCNT_ADJ=&RCNT_QL,RCNT_DEF=&RCNT_DEF,ADJ_ENGINE=QL);
	%IF &RX_ADJ = 1 %THEN 
		%DOC_UPDT(RCNT_ADJ=&RCNT_RX,RCNT_DEF=&RCNT_DEF,ADJ_ENGINE=RX);
	%IF &RE_ADJ = 1 %THEN 
		%DOC_UPDT(RCNT_ADJ=&RCNT_RE,RCNT_DEF=&RCNT_DEF,ADJ_ENGINE=RE);

/*	%IF &DOC_COMPLETE_IN_QL >= 1 %THEN */
/*		%DOC_UPDT(RCNT_ADJ=&RCNT_QL,RCNT_DEF=&RCNT_DEF,ADJ_ENGINE=QL);*/
/*	%IF &DOC_COMPLETE_IN_RX >= 1 %THEN */
/*		%DOC_UPDT(RCNT_ADJ=&RCNT_RX,RCNT_DEF=&RCNT_DEF,ADJ_ENGINE=RX);*/
/*	%IF &DOC_COMPLETE_IN_RE >= 1 %THEN */
/*		%DOC_UPDT(RCNT_ADJ=&RCNT_RE,RCNT_DEF=&RCNT_DEF,ADJ_ENGINE=RE);*/

*SASDOC -----------------------------------------------------------------------------------
  | DROP THE TABLES THAT WERE RENAMED DURING UPDATES IF NO ERROS WERE ENCOUNTERED.
  | IF ERRORS, REPLACE THE CHKDOC_RN_&SYSJOBID._ DATASET THAT WAS CREATED BY RENAMING
  | THE ORIGINAL DATASET, BACK TO THE ORIGINAL DATASET
  +--------------------------------------------------------------------------------SASDOC*;

	%LET CHKDOCCNT = 0;
	DATA _NULL_;
 		SET SASHELP.VTABLE END=EOF;
 		CALL SYMPUT('LIBNAME' || TRIM(LEFT(_N_)), TRIM(LEFT(LIBNAME)));
 		CALL SYMPUT('MEMNAME' || TRIM(LEFT(_N_)), TRIM(LEFT(MEMNAME)));
 		IF EOF THEN CALL SYMPUT('CHKDOCCNT', TRIM(LEFT(_N_)));
 		WHERE LIBNAME IN ('DATA_PND','DATA_RES')
          AND MEMNAME LIKE "CHKDOC_RN_&SYSJOBID._%";
	RUN;

	%IF &CHKDOCCNT >= 1 %THEN %DO;
		%DO I = 1 %TO &CHKDOCCNT;
			PROC SQL;
			 DROP TABLE &&LIBNAME&I...&&MEMNAME&I.;
			QUIT;
		%END;
	%END;

%END; /** &RELEASE_IN=0 **/

%ELSE %DO;
     %LET DOC_COMPLETE_IN = 1;

     %PUT NOTE: (&SYSMACRONAME) THE INITIATIVE &INITIATIVE_ID HAS ALREADY RELEASED FILE(S) AS FINAL RELEASES.;
     %PUT NOTE: (&SYSMACRONAME) NO UPDATING ON APN_CMCTN_ID IS NEEDED. APPROPRIATE DOC_COMPLETE_IN HAS BEEN SET TO 1;

%END; /** &RELEASE_IN>0 **/

%MEND CHECK_DOCUMENT_rg;

/*****
OPTIONS SYSPARM='INITIATIVE_ID=1100, PHASE_SEQ_NB=1';
 %INCLUDE '/PRG/SASTEST1/HERCULES/HERCULES_IN.SAS';
 %CHECK_DOCUMENT;
***/
