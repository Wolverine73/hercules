/*HEADER---------------------------------------------------------------------------------------------------------
|MACRO: CLAIMS_OUTPUT.SAS
|
|PURPOSE:
|                        RESOLVE CLAIMS INFORMATION ACROSS ALL PLATFORMS.
|
|INPUT					 INPT_TBL(GET_NDC OUTPUT TABLE),INPT_TBL2(RESOLVE_CLIENT OUTPUT TABLE),
|						 PLATFORM(IF QL IS ACTIVE, PLATFORM WILL BE DB2,IF RX/RE IS ACTIVE, PLATFORM WILL BE ORACLE)
|					     SRC_CD(IF SRC_CD EQ 72 THEN  PROCESS CREATE RX/RE CLAIMS THROUGH PROACTIVE_REFILL.SAS
|								IF SRC_CD EQ 74 THEN  PROCESS CREATE RX/RE CLAIMS THROUGH (FASTSTART)RETAIL_TO_MAIL.SAS
|								IF SRC_CD EQ 83 THEN  PROCESS CREATE QL CLAIMS THROUGH GENERIC_LAUNCH.SAS 
|								IF SRC_CD EQ 84 THEN  PROCESS CREATE RX/RE CLAIMS THROUGH GENERIC_LAUNCH.SAS)
|						 EDW_ADJ(IF EDW_ADJ = 2 THEN PROCESS ACTIVE RX INFORMATION 
|								 IF EDW_ADJ = 3 THEN PROCESS ACTIVE RE INFORMATION
|						 (CURR_FRM_ID,BEGIN_DT,END_DT,CLIENT_IDS) ARE MACRO VARIABLES COMING FROM MAIN PROGRAM.
|
|LOGIC:                 CHECK RESOLVE CLIENT EXCLUDE FLAG, IF THE FLAG IS 1 THEN ASSIGN CLIENT_COND = 'NOT EXISTS' 
|						ELSE 'EXISTS' .SIMILARLY OVRD_CLT_SETUP_IN TOO.
|						CALL DELIVERY_SYS_CHECK MACRO TO RESOLVE IF ANY OF THE DELIVERY SYSTEMS SHOULD BE EXCLUDED 
|						FROM THE INITIATIVE 
|						
|						RETRIEVE CLAIMS INFORMATION ACROSS ALL PLATFORMS.
|						G E T   T H E   T A R T G E T   C L A I M S ACROSS ALL PLATFORMS
|	FOLLOWING FIELDS POPULATED FROM DSS_CLIN TABLES.
|				   V_CLAIM_CORE_PAID.PAYER_ID
|				   V_CLAIM_CORE_PAID.ALGN_LVL_GID
|				   V_CLAIM_CORE_PAID.MBR_GID
|				   V_CLAIM_CORE_PAID.DRUG_GID
|				   V_CLAIM_CORE_PAID.PTNT_BRTH_DT(BIRTH_DT)
|				   V_CLAIM_CORE_PAID.DSPND_DATE(FILL_DT)
|				   V_CLAIM_CORE_PAID.CLAIM_TYPE(RXS)
|				   V_CLAIM_CORE_PAID.QL_CPG_ID(CLT_PLAN_GROUP_ID)
|				   V_MBR.MBR_ID
|				   V_MBR.QL_BNFCY_ID(PT_BENEFICIARY_ID)
|				   V_MBR.QL_CARDHLDR_BNFCY_ID(CDH_BENEFICIARY_ID)
|				   V_DRUG_DENORM.PRDCT_NAME(DRUG_ABBR_PROD_NM)
|				   V_DRUG_DENORM.DRUG_NDC_ID(IF RESOLVE CLIENT FLAG 1)
|				   V_DRUG_DENORM.NHU_TYPE_CD(IF RESOLVE CLIENT FLAG 1)
|				   V_DRUG_DENORM.GPI10_CD(IF RESOLVE CLIENT FLAG 1)
|				   V_DRUG_DENORM.GPI4_CD(IF RESOLVE CLIENT FLAG 1)
|				   V_ALGN_LVL_DENORM.QL_CLNT_ID(CLIENT_ID)
|				   V_ALGN_LVL_DENORM.CUST_NM(CLIENT_NM)
|				   V_ALGN_LVL_DENORM.EXTNL_LVL_ID1(CLIENT_LEVEL_1)(IF ADJ EQ RX)
|				   V_ALGN_LVL_DENORM.EXTNL_LVL_ID2(CLIENT_LEVEL_2)(IF ADJ EQ RX)
|				   V_ALGN_LVL_DENORM.EXTNL_LVL_ID3(CLIENT_LEVEL_3)(IF ADJ EQ RX)
|				   V_ALGN_LVL_DENORM.RPT_OPT1_CD(CLIENT_LEVEL_1)(IF ADJ EQ RE)
|				   V_ALGN_LVL_DENORM.EXTNL_LVL_ID1(CLIENT_LEVEL_2)(IF ADJ EQ RE)
|				   V_ALGN_LVL_DENORM.EXTNL_LVL_ID3(CLIENT_LEVEL_3)(IF ADJ EQ RE)						
|
|OUTPUT			 		TEMPORARY TABLE (TBL_NM_OUT) IS CREATED .
|+-----------------------------------------------------------------------------------------------------------------
| HISTORY: 
|FIRST RELEASE: 		10MAY2008 - K.MITTAPALLI   - Hercules Version  2.1.01
+-----------------------------------------------------------------------------------------------------------HEADER*/
%MACRO CLAIMS_OUTPUT(TBL_NM_OUT=,INPT_TBL=,INPT_TBL2=,PLATFORM=,SRC_CD=,
					 CURR_FRM_ID=,BEGIN_DT=,END_DT=,CLIENT_IDS=,SRC_SYS_CD =,
					 LTR_HIS_DT =,PROGRAM_ID=,RESOLVE_CLIENT_EXCLUDE_FLAG=,
					 OVRD_CLT_SETUP_IN=,ADJ_ENG_CD=,EDW_ADJ=,CLIENT_ID_CONDITION2=);

	DATA _NULL_;
        %IF &EDW_ADJ=2 %THEN %LET EDW_DECODE='RXCLAIM';
      		%ELSE %IF &EDW_ADJ=3 %THEN %LET EDW_DECODE='RECAP';
				%ELSE %LET EDW_DECODE='QL';
		        %IF &SRC_CD=72 %THEN %LET SRC_DECODE='PROACTIVE_REFILL';
		      		%ELSE %IF &SRC_CD=74 %THEN %LET SRC_DECODE='FASTSTART';
						%ELSE %IF &SRC_CD=83 %THEN %LET SRC_DECODE='GENERIC_LAUNCH(QL)';
							%ELSE %IF &SRC_CD=84 %THEN %LET SRC_DECODE='GENERIC_LAUNCH';
							        %IF &SRC_SYS_CD='X' %THEN %LET SYS_DECODE='RXCLAIM';
							      		%ELSE %IF &SRC_SYS_CD='R' %THEN %LET SYS_DECODE='RECAP';
											%ELSE %LET SYS_DECODE='QL';
							IF _N_=1 THEN DO;
						      PUT "TITLE:";
						      PUT @7 "PARAMETER SUMMARY FOR ADJUDICATION - &EDW_DECODE.";
						      PUT @7 55*'_';
						      PUT ' ';
						      PUT @7 'CODE_NAME' @35 'ENGIN_DECODE';
						      PUT @7 10*'-' @35 14*'-';
						    END;

						    PUT @7 'TBL_NM_OUT' @35 "&TBL_NM_OUT." /
								@7 'INPT_TBL'   @35 "&INPT_TBL."   /
								@7 'INPT_TBL2' 	@35 "&INPT_TBL2."  /
								@7 'PLATFORM'   @35 "&PLATFORM."   /
								@7 'SRC_CD'     @35 "&SRC_DECODE." /
								@7 'BEGIN_DT'   @35 "&BEGIN_DT."   /
								@7 'END_DT'     @35 "&END_DT."     /
								@7 'SRC_SYS_CD' @35 "&SYS_DECODE." /
								@7 'EDW_ADJ'    @35 "&EDW_DECODE." /
							;
						      PUT @7 55*'_';
						      PUT 'NOTE:';
						      PUT ' ';
	RUN;
%GLOBAL CLIENT_COND CLIENT_SLCT_STR PB_CLT_SLCT_STR;
%LOCAL SRC_CD CURR_FRM_ID BEGIN_DT END_DT CLIENT_IDS SRC_SYS_CD LTR_HIS_DT PROGRAM_ID PB_CLT_SLCT_STR
		CHECK_OVRD_SETUP; 
*SASDOC----------------------------------------------------------------------------------------------------------
|   CHECK RESOLVE CLIENT EXCLUDE FLAG, IF THE FLAG IS 1 THEN ASSIGN CLIENT_COND = 'NOT EXISTS' 
|													CLIENT_SLCT_STR = 'AND NOT EXISTS (RESOLVE_CLIENT O/P) TABLE' 
|													PB_CLT_SLCT_STR = 'AND NOT EXISTS (RESOLVE_CLIENT O/P) TABLE'
|									ELSE IF THE FLAG IS 0
|													CLIENT_COND = 'EXISTS' 
|													CLIENT_SLCT_STR = 'AND EXISTS (RESOLVE_CLIENT O/P) TABLE' 
|													PB_CLT_SLCT_STR = 'AND EXISTS (RESOLVE_CLIENT O/P) TABLE'
|								FOR PROGRAMS SRC_CD = 72(PROACTIVE_REFILL.SAS) AND 74(FASTSTART).		
|	10MAY2008 - K.MITTAPALLI   - HERCULES VERSION  2.1.0.1
+-----------------------------------------------------------------------------------------------------------SASDOC*;


%IF &RESOLVE_CLIENT_EXCLUDE_FLAG = 1 %THEN %DO;
					DATA _NULL_;
					CALL SYMPUT('CLIENT_COND',(LEFT('AND NOT EXISTS')));
					RUN;
					%LET CLIENT_SLCT_STR = %str(AND NOT EXISTS (SELECT * FROM &INPT_TBL2 CLT
															WHERE ALGN.ALGN_LVL_GID_KEY = CLT.ALGN_LVL_GID_KEY
													 		  AND ALGN.PAYER_ID = CLT.PAYER_ID
															  AND CLT.ALGN_LVL_GID_KEY IS NOT NULL
															  AND CLT.PAYER_ID IS NOT NULL
															AND (mbr.payer_id <= 100000 /* Rx claim members */ 
											              OR mbr.payer_id BETWEEN 500000 AND 2000000 /* Recap members */
															));
					%LET PB_CLT_SLCT_STR = %str(AND NOT EXISTS (SELECT * FROM &INPT_TBL2 CLT
															WHERE ALGN.ALGN_LVL_GID_KEY = CLT.ALGN_LVL_GID_KEY
													 		  AND ALGN.PAYER_ID = CLT.PAYER_ID
															  AND CLT.ALGN_LVL_GID_KEY IS NOT NULL
															  AND CLT.PAYER_ID IS NOT NULL
															AND (mbr.payer_id <= 100000 /* Rx claim members */ 
											              OR mbr.payer_id BETWEEN 500000 AND 2000000 /* Recap members */
															));
%END;

%ELSE %IF &RESOLVE_CLIENT_EXCLUDE_FLAG = 0 %THEN %DO;
					DATA _NULL_;
					CALL SYMPUT('CLIENT_COND',(LEFT('AND EXISTS')));
					RUN;
					%LET CLIENT_SLCT_STR=%STR(AND EXISTS (SELECT * FROM &INPT_TBL2 CLT
															WHERE ALGN.ALGN_LVL_GID_KEY = CLT.ALGN_LVL_GID_KEY
													 		  AND ALGN.PAYER_ID = CLT.PAYER_ID
															  AND CLT.ALGN_LVL_GID_KEY IS NOT NULL
															  AND CLT.PAYER_ID IS NOT NULL
															  AND (mbr.payer_id <= 100000 /* Rx claim members */ 
											              OR mbr.payer_id BETWEEN 500000 AND 2000000 /* Recap members */
															));
					%LET PB_CLT_SLCT_STR=%STR(AND EXISTS (SELECT * FROM &INPT_TBL2 CLT
															WHERE ALGN.ALGN_LVL_GID_KEY = CLT.ALGN_LVL_GID_KEY
													 		  AND ALGN.PAYER_ID = CLT.PAYER_ID
															  AND CLT.ALGN_LVL_GID_KEY IS NOT NULL
															  AND CLT.PAYER_ID IS NOT NULL
															  AND (mbr.payer_id <= 100000 /* Rx claim members */ 
											              OR mbr.payer_id BETWEEN 500000 AND 2000000 /* Recap members */
															));

%END;

%PUT NOTE:	CLIENT_COND 	= &CLIENT_COND;
%PUT NOTE:	CLIENT_SLCT_STR = &CLIENT_SLCT_STR;
%PUT NOTE:	PB_CLT_SLCT_STR = &PB_CLT_SLCT_STR;


*SASDOC----------------------------------------------------------------------------------------------------------
|   CALL DELIVERY_SYS_CHECK MACRO TO RESOLVE IF ANY OF THE DELIVERY SYSTEMS SHOULD BE EXCLUDED FROM THE
|						INITIATIVE.  IF SO, FORM A STRING THAT WILL BE INSERTED INTO THE SQL THAT
|						QUERIES CLAIMS.
|	10MAY2008 - K.MITTAPALLI   - HERCULES VERSION  2.1.0.1
+-----------------------------------------------------------------------------------------------------------SASDOC*;

%INCLUDE "/herc&sysmode/prg/hercules/macros/delivery_sys_check.sas";

*SASDOC----------------------------------------------------------------------------------------------------------
|   G E T   T H E   T A R T G E T   C L A I M S ACROSS ALL PLATFORMS
|   PROCESS CREATE RX/RE CLAIMS THROUGH PROACTIVE_REFILL.SAS,GENERIC_LAUNCH.SAS,FASTSTART.SAS
|	FOLLOWING FIELDS POPULATED FROM DSS_CLIN TABLES.
|				   V_CLAIM_CORE_PAID.PAYER_ID
|				   V_CLAIM_CORE_PAID.ALGN_LVL_GID
|				   V_CLAIM_CORE_PAID.MBR_GID
|				   V_CLAIM_CORE_PAID.DRUG_GID
|				   V_CLAIM_CORE_PAID.PTNT_BRTH_DT(BIRTH_DT)
|				   V_CLAIM_CORE_PAID.DSPND_DATE(FILL_DT)
|				   V_CLAIM_CORE_PAID.CLAIM_TYPE(RXS)
|				   V_CLAIM_CORE_PAID.QL_CPG_ID(CLT_PLAN_GROUP_ID)
|				   V_MBR.MBR_ID
|				   V_MBR.QL_BNFCY_ID(PT_BENEFICIARY_ID)
|				   V_MBR.QL_CARDHLDR_BNFCY_ID(CDH_BENEFICIARY_ID)
|				   GET_NDC.DRUG_NDC_ID(IF RESOLVE CLIENT FLAG 0)
|				   GET_NDC.NHU_TYPE_CD(IF RESOLVE CLIENT FLAG 0)
|				   GET_NDC.GPI10_CD(IF RESOLVE CLIENT FLAG 0)
|				   GET_NDC.GPI4_CD(IF RESOLVE CLIENT FLAG 0)
|				   V_DRUG_DENORM.PRDCT_NAME(DRUG_ABBR_PROD_NM)
|				   V_DRUG_DENORM.DRUG_NDC_ID(IF RESOLVE CLIENT FLAG 1)
|				   V_DRUG_DENORM.NHU_TYPE_CD(IF RESOLVE CLIENT FLAG 1)
|				   V_DRUG_DENORM.GPI10_CD(IF RESOLVE CLIENT FLAG 1)
|				   V_DRUG_DENORM.GPI4_CD(IF RESOLVE CLIENT FLAG 1)
|				   V_ALGN_LVL_DENORM.QL_CLNT_ID(CLIENT_ID)
|				   V_ALGN_LVL_DENORM.CUST_NM(CLIENT_NM)
|				   V_ALGN_LVL_DENORM.EXTNL_LVL_ID1(CLIENT_LEVEL_1)(IF ADJ EQ RX)
|				   V_ALGN_LVL_DENORM.EXTNL_LVL_ID2(CLIENT_LEVEL_2)(IF ADJ EQ RX)
|				   V_ALGN_LVL_DENORM.EXTNL_LVL_ID3(CLIENT_LEVEL_3)(IF ADJ EQ RX)
|				   V_ALGN_LVL_DENORM.RPT_OPT1_CD(CLIENT_LEVEL_1)(IF ADJ EQ RE)
|				   V_ALGN_LVL_DENORM.EXTNL_LVL_ID1(CLIENT_LEVEL_2)(IF ADJ EQ RE)
|				   V_ALGN_LVL_DENORM.EXTNL_LVL_ID3(CLIENT_LEVEL_3)(IF ADJ EQ RE)
|
|	10MAY2008 - K.MITTAPALLI   - HERCULES VERSION  2.1.0.1
+-----------------------------------------------------------------------------------------------------------SASDOC*;
%drop_oracle_table(tbl_name=&TBL_NM_OUT.);
%drop_db2_table(tbl_name=&TBL_NM_OUT.);
PROC SQL;
	%IF (&SRC_CD=83) %THEN %DO;
   		CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
    %END;
		%IF (&SRC_CD=72 or &SRC_CD=74 or &SRC_CD=84) %THEN %DO;
   			CONNECT TO ORACLE(PATH=&GOLD);
    	%END;
 CREATE TABLE &TBL_NM_OUT. AS
SELECT * FROM CONNECTION TO &PLATFORM
           (SELECT DISTINCT
			%IF &SRC_CD=83 %THEN %DO;
											 A.CDH_BENEFICIARY_ID,
							                 A.PT_BENEFICIARY_ID,
							                 B.BIRTH_DT,
							                 A.CLIENT_ID,
							                 C.CLIENT_NM
							            FROM  &CLAIMSA..&CLAIM_HIS_TBL A,
							                  &CLAIMSA..TBENEFICIARY   B,
							                  &CLAIMSA..TCLIENT1 	   C
							            %IF %SYSFUNC(EXIST(&INPT_TBL)) %THEN %DO;
							                 ,&INPT_TBL 			   D
							            %END;
										WHERE
							            %IF %SYSFUNC(EXIST(&INPT_TBL)) %THEN %DO;
							            	  A.DRUG_NDC_ID = D.DRUG_NDC_ID    
							            AND   A.NHU_TYPE_CD = D.NHU_TYPE_CD   
							            AND 
							            %END;
							                  A.PT_BENEFICIARY_ID = B.BENEFICIARY_ID
							            AND   A.CLIENT_ID = C.CLIENT_ID
							            AND   A.FILL_DT BETWEEN &BEGIN_DT AND &END_DT
										&CLIENT_ID_CONDITION2
										&DS_STRING
										AND NOT EXISTS
							              (SELECT 1
							               FROM CLAIMSA.TRXCLM_CLMS_HISEXT
							               WHERE A.BENEFIT_REQUEST_ID = BENEFIT_REQUEST_ID
							               AND   A.BRLI_NB = BRLI_NB
							               AND   BRLI_VOID_IN > 0)
			%END;
			%IF (&SRC_CD EQ 72 or &SRC_CD EQ 74 or &SRC_CD EQ 84) %THEN %DO;
										   CLAIM.PAYER_ID 				AS PAYER_ID
										  ,CLAIM.ALGN_LVL_GID 			AS ALGN_LVL_GID_KEY 
										  ,CLAIM.MBR_GID				AS MBR_GID
										  ,MBR.MBR_ID					AS MBR_ID
										  ,MBR.QL_BNFCY_ID				AS PT_BENEFICIARY_ID
										  ,MBR.QL_CARDHLDR_BNFCY_ID		AS CDH_BENEFICIARY_ID
						%IF &SRC_CD EQ 74 %THEN %DO;
										  ,MAX(SUBSTR(MBR.MBR_ID,1,9))	AS MBR_ID9
										  ,MBR.MBR_LAST_NM				AS MBR_LAST_NM
										  ,MBR.ADDR_LINE1_TXT			AS ADDR_LINE1_TXT
										  ,MBR.ADDR_LINE2_TXT			AS ADDR_LINE2_TXT
										  ,MBR.ADDR_CITY_NM				AS ADDR_CITY_NM
										  ,MBR.ADDR_ST_CD				AS ADDR_ST_CD
										  ,MBR.ADDR_ZIP_CD				AS ADDR_ZIP_CD
						%END;
										  ,MAX(CLAIM.DRUG_GID)			AS DRUG_GID
						            %IF %SYSFUNC(EXIST(&INPT_TBL)) %THEN %DO;
												%IF &SRC_CD EQ 72 %THEN %DO;
										                  ,DRUG.DRUG_NDC_ID				AS DRUG_NDC_ID
														  ,DRUG.NHU_TYPE_CD				AS NHU_TYPE_CD
														  ,MAX(SUBSTR(DRUG.DRUG_NDC_ID,1,10))   AS GPI10_CD
														  ,MAX(SUBSTR(DRUG.DRUG_NDC_ID,1,4))	AS GPI4_CD
												%END;
												%IF (&SRC_CD EQ 74 or &SRC_CD EQ 84) %THEN %DO;
										                  ,MAX(DRUG.DRUG_NDC_ID)		 AS DRUG_NDC_ID
														  ,MAX(DRUG.NHU_TYPE_CD)		 AS NHU_TYPE_CD
														  ,MAX(SUBSTR(DRUG.DRUG_NDC_ID,1,10)) AS GPI10_CD
														  ,MAX(SUBSTR(DRUG.DRUG_NDC_ID,1,4))  AS GPI4_CD
												%END;
						            %END;
									%ELSE %DO;
						                  ,MAX(SUBSTR(DRG.NDC_CODE,1,11)) 	AS DRUG_NDC_ID
										  ,MAX(1)							AS NHU_TYPE_CD
										  ,MAX(SUBSTR(DRG.NDC_CODE,1,10))	AS GPI10_CD
										  ,MAX(SUBSTR(DRG.NDC_CODE,1,4))	AS GPI4_CD
									%END;
										  ,MAX(DRG.PRDCT_NAME)			AS DRUG_ABBR_PROD_NM
						                  ,ALGN.QL_CLNT_ID				AS CLIENT_ID
										  ,CLAIM.QL_CPG_ID				AS CLT_PLAN_GROUP_ID
									%IF (&SRC_CD EQ 72 or &SRC_CD EQ 74) %THEN %DO;
										  ,MAX(ALGN.CUST_NM)				    AS CLIENT_NM
						                  ,MAX(SUBSTR(CLAIM.PTNT_BRTH_DT,1,10)) AS BIRTH_DT
									%END;
										%IF &EDW_ADJ EQ 2 %THEN %DO;
											  ,MAX(ALGN.EXTNL_LVL_ID1)		AS CLIENT_LEVEL_1
											  ,MAX(ALGN.EXTNL_LVL_ID2)		AS CLIENT_LEVEL_2
											  ,MAX(ALGN.EXTNL_LVL_ID3)		AS CLIENT_LEVEL_3
											  ,MAX('RX')					AS ADJ_ENGINE
											  %IF &SRC_CD EQ 72 %THEN %DO;
											  ,MAX(VCLM.SBMTD_REFIL_ATHZD)  AS REFILL_FILL_QY
											  %END;
										%END;
										%IF &EDW_ADJ EQ 3 %THEN %DO;
											  ,MAX(ALGN.RPT_OPT1_CD)		AS CLIENT_LEVEL_1
											  ,MAX(ALGN.EXTNL_LVL_ID1)		AS CLIENT_LEVEL_2
											  ,MAX(ALGN.EXTNL_LVL_ID3)		AS CLIENT_LEVEL_3
											  ,MAX('RE')					AS ADJ_ENGINE
											  %IF &SRC_CD EQ 72 %THEN %DO;
											  ,MAX(VALV.ATHZD_REFIL_QTY)    AS REFILL_FILL_QY
											  %END;
										%END;
									 %IF &SRC_CD EQ 84 %THEN %DO;
											  ,ALGN.CUST_NM				       		AS CLIENT_NM
							                  ,CLAIM.PTNT_BRTH_DT 					AS PTNT_BRTH_DT
											  ,MAX(SUBSTR(CLAIM.PTNT_BRTH_DT,1,10)) AS BIRTH_DT
									 %END;
						                  ,MAX(SUBSTR(CLAIM.DSPND_DATE,1,10))   AS LAST_FILL_DT
						                  ,SUM(CLAIM.CLAIM_TYPE)				AS RXS
						            FROM  
									%IF %SYSFUNC(EXIST(&INPT_TBL)) %THEN %DO;
								                 &INPT_TBL		SAMPLE(1.0)    		DRUG  		JOIN 
												 &DSS_CLIN..V_DRUG_DENORM  			DRG
												ON DRG.DRUG_GID = DRUG.DRUG_GID 		  		JOIN
												 &DSS_CLIN..V_CLAIM_CORE_PAID	    CLAIM
												ON CLAIM.DRUG_GID = DRG.DRUG_GID		  		JOIN
												 &DSS_CLIN..V_ALGN_LVL_DENORM 		ALGN
												ON CLAIM.ALGN_LVL_GID = ALGN.ALGN_LVL_GID_KEY 	JOIN
												 &DSS_CLIN..V_PHMCY_DENORM         	PHMCY
												ON CLAIM.PHMCY_GID = PHMCY.PHMCY_GID			JOIN
												 &DSS_CLIN..V_MBR			 		MBR
												ON CLAIM.MBR_GID = MBR.MBR_GID
								  			   AND CLAIM.PAYER_ID = MBR.PAYER_ID				
											%IF (&EDW_ADJ EQ 2 AND &SRC_CD EQ 72) %THEN %DO;
												 JOIN &DSS_CLIN..V_CLAIM			 		VCLM
												ON CLAIM.MBR_GID = VCLM.MBR_GID
								  			   AND CLAIM.PAYER_ID = VCLM.PAYER_ID	
											   AND CLAIM.PHMCY_GID = VCLM.PHMCY_GID
											   AND CLAIM.ALGN_LVL_GID =VCLM.ALGN_LVL_GID
											   AND CLAIM.CLAIM_GID = VCLM.CLAIM_GID
											%END;
													%IF (&EDW_ADJ EQ 3 AND &SRC_CD EQ 72) %THEN %DO;
													JOIN &DSS_CLIN..V_CLAIM_ALV		 		VALV
														ON CLAIM.MBR_GID = VALV.MBR_GID
										  			   AND CLAIM.PAYER_ID = VALV.PAYER_ID	
													   AND CLAIM.PHMCY_GID = VALV.PHMCY_GID
													   AND CLAIM.ALGN_LVL_GID =VALV.ALGN_LVL_GID
													   AND CLAIM.CLAIM_GID = VALV.CLAIM_GID
													%END;
						            %END;
									%ELSE %DO;
												 &DSS_CLIN..V_DRUG_DENORM  SAMPLE(1.0) DRG      JOIN
												 &DSS_CLIN..V_CLAIM_CORE_PAID	    CLAIM
												ON CLAIM.DRUG_GID = DRG.DRUG_GID		  		JOIN
												 &DSS_CLIN..V_ALGN_LVL_DENORM 		ALGN
												ON CLAIM.ALGN_LVL_GID = ALGN.ALGN_LVL_GID_KEY 	JOIN
												 &DSS_CLIN..V_PHMCY_DENORM         	PHMCY
												ON CLAIM.PHMCY_GID = PHMCY.PHMCY_GID			JOIN
												 &DSS_CLIN..V_MBR			 		MBR
												ON CLAIM.MBR_GID = MBR.MBR_GID
								  			   AND CLAIM.PAYER_ID = MBR.PAYER_ID
								  			   AND CLAIM.PAYER_ID = MBR.PAYER_ID				
											%IF (&EDW_ADJ EQ 2 AND &SRC_CD EQ 72) %THEN %DO;
												 JOIN &DSS_CLIN..V_CLAIM			 		VCLM
												ON CLAIM.MBR_GID = VCLM.MBR_GID
								  			   AND CLAIM.PAYER_ID = VCLM.PAYER_ID	
											   AND CLAIM.PHMCY_GID = VCLM.PHMCY_GID
											   AND CLAIM.ALGN_LVL_GID =VCLM.ALGN_LVL_GID
											   AND CLAIM.CLAIM_GID = VCLM.CLAIM_GID
											%END;
													%IF (&EDW_ADJ EQ 3 AND &SRC_CD EQ 72) %THEN %DO;
														 JOIN &DSS_CLIN..V_CLAIM_ALV		 		VALV
														ON CLAIM.MBR_GID = VALV.MBR_GID
										  			   AND CLAIM.PAYER_ID = VALV.PAYER_ID	
													   AND CLAIM.PHMCY_GID = VALV.PHMCY_GID
													   AND CLAIM.ALGN_LVL_GID =VALV.ALGN_LVL_GID
													   AND CLAIM.CLAIM_GID = VALV.CLAIM_GID
													%END;
									%END;
						            WHERE DRG.DRUG_VLD_FLG = 'Y'
									  AND CLAIM.SRC_SYS_CD IN(&SRC_SYS_CD)
									  AND ALGN.SRC_SYS_CD IN(&SRC_SYS_CD)
									  AND CLAIM.CLAIM_WSHD_CD IN('P','W')
									  AND SYSDATE BETWEEN ALGN.ALGN_GRP_EFF_DT AND ALGN.ALGN_GRP_END_DT
						              AND (CLAIM.DSPND_DATE BETWEEN TO_DATE(&BEGIN_DT,'yyyy-mm-dd')
								      AND TO_DATE(&END_DT,'yyyy-mm-dd'))
									  AND (NVL(CLAIM.MBR_SUFFX_FLG, 'Y') = 'Y')
									  %IF &SRC_CD EQ 72 %THEN %DO;
									  				%IF &EDW_ADJ EQ 2 %THEN %DO;
									  			  AND (VCLM.BATCH_DATE BETWEEN TO_DATE(&BEGIN_DT,'yyyy-mm-dd')
												  AND TO_DATE(&END_DT,'yyyy-mm-dd'))
												  	%END;
												  				%IF &EDW_ADJ EQ 3 %THEN %DO;
												  			  AND (VALV.BATCH_DATE BETWEEN TO_DATE(&BEGIN_DT,'yyyy-mm-dd')
															  AND TO_DATE(&END_DT,'yyyy-mm-dd'))
															  	%END;
									              &RETAIL_DELVRY_CD
												  AND PHMCY.NABP_CODE_6 NOT IN('1138317')
												  &CLIENT_COND
												  (SELECT 
												  /*+ FULL(CLT) NO_MERGE HASH_SJ HASH_AJ */
														* 
												  	 FROM &INPT_TBL2	 					CLT
													WHERE ALGN.ALGN_LVL_GID_KEY = CLT.ALGN_LVL_GID_KEY
												      AND ALGN.PAYER_ID = CLT.PAYER_ID
													  AND CLT.ALGN_LVL_GID_KEY IS NOT NULL
													  AND CLT.PAYER_ID IS NOT NULL
												   )
									            GROUP BY CLAIM.PAYER_ID,
														 CLAIM.ALGN_LVL_GID,	
														 CLAIM.MBR_GID,
														 MBR.MBR_ID,
														 MBR.QL_BNFCY_ID,
														 MBR.QL_CARDHLDR_BNFCY_ID	
												%IF %SYSFUNC(exist(&INPT_TBL)) %THEN %DO;
									                    ,DRUG.DRUG_NDC_ID
														,DRUG.NHU_TYPE_CD
												%END;
														,ALGN.QL_CLNT_ID
														,CLAIM.QL_CPG_ID
									            HAVING SUM(CLAIM.CLAIM_TYPE) > 0
									  %END;

									  %IF &SRC_CD EQ 74 %THEN %DO; 
												  &RETAIL_DELVRY_CD
												  &CLIENT_SLCT_STR
									            GROUP BY CLAIM.PAYER_ID,
														 CLAIM.ALGN_LVL_GID,	
														 CLAIM.MBR_GID,
														 MBR.MBR_ID,
														 MBR.QL_BNFCY_ID,
														 MBR.QL_CARDHLDR_BNFCY_ID,
										  				 MBR.MBR_LAST_NM,
										  				 MBR.ADDR_LINE1_TXT,
										  				 MBR.ADDR_LINE2_TXT,
										  				 MBR.ADDR_CITY_NM,
										  				 MBR.ADDR_ST_CD,
										  			     MBR.ADDR_ZIP_CD,
														 ALGN.QL_CLNT_ID,
														 CLAIM.QL_CPG_ID	
									            HAVING SUM(CLAIM.CLAIM_TYPE) > 0
									  %END;
									  %IF &SRC_CD EQ 84 %THEN %DO; 
														  &DS_STRING_RX_RE
														  &CLIENT_SLCT_STR
											            GROUP BY CLAIM.PAYER_ID,
																 CLAIM.ALGN_LVL_GID,	
																 CLAIM.MBR_GID,
																 MBR.MBR_ID,
																 MBR.QL_BNFCY_ID,
																 MBR.QL_CARDHLDR_BNFCY_ID,
																 ALGN.QL_CLNT_ID,
																 CLAIM.QL_CPG_ID,
																 ALGN.CUST_NM,
																 CLAIM.PTNT_BRTH_DT	
											            HAVING SUM(CLAIM.CLAIM_TYPE) > 0
									  %END;
		%END;
);
  DISCONNECT FROM &PLATFORM;
QUIT;

%MEND CLAIMS_OUTPUT;

