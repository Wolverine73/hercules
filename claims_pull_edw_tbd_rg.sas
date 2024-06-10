/*HEADER---------------------------------------------------------------------------------------------------------
|MACRO: 		CLAIMS_PULL_EDW_TBD.SAS
|
|PURPOSE:   EXTRACT CLAIMS FROM EDW FOR RECAP AND RXCLAIM ADJUDICATIONS 		
|           VERSION FOR TARGET BY DRUG/ DSA
|INPUT:			
|
|LOGIC:         					
|						
|OUTPUT:			
|------------------------------------------------------------------------------------------------------------------
|HISTORY: JUNE 2012 - E BUKOWSKI(SLIOUNKOVA) - CREATED - MODIFIED VERSION OF CLAIMS_PULL_EDW.SAS
+-----------------------------------------------------------------------------------------------------------HEADER*/

%MACRO CLAIMS_PULL_EDW_TBD_rg(DRUG_NDC_TABLE_RX = &ORA_TMP..&TABLE_PREFIX._NDC_RX,
					   DRUG_NDC_TABLE_RE = &ORA_TMP..&TABLE_PREFIX._NDC_RE, 
					   DRUG_RVW_DATES_TABLE = &ORA_TMP..&TABLE_PREFIX._RVW_DATES,
					   RESOLVE_CLIENT_TABLE_RX = &ORA_TMP..&TABLE_PREFIX._RX ,
					   RESOLVE_CLIENT_TABLE_RE = &ORA_TMP..&TABLE_PREFIX._RE
                       );

OPTIONS MPRINT MPRINTNEST MLOGIC MLOGICNEST SYMBOLGEN SOURCE2;

%GLOBAL LVL1_CNT; 


	%MACRO EDW_CLAIMS(ADJ_ENGINE=);
    DATA _NULL_;
		  CALL SYMPUT('CLM_BEGIN_DT_CONV', "TO_DATE('" ||"&CLM_BEGIN_DT" || "','YYYY-MM-DD')" );
		  CALL SYMPUT('CLM_END_DT_CONV', "TO_DATE('" || "&CLM_END_DT" || "','YYYY-MM-DD')" );

		  CALL SYMPUT('CLM_BEGIN_DT_PLUS_1WK', "TO_DATE('" ||PUT(INTNX('WEEK',INPUT("&CLM_BEGIN_DT",YYMMDD10.),-1,'BEGIN'),YYMMDD10.) || "','YYYY-MM-DD')" );
		  CALL SYMPUT('CLM_END_DT_PLUS_1WK', "TO_DATE('" || PUT(INTNX('WEEK',INPUT("&CLM_END_DT",YYMMDD10.),+1,'END'),YYMMDD10.) || "','YYYY-MM-DD')" );
    RUN;

		%IF %SYSFUNC(EXIST(&DRUG_RVW_DATES_TABLE.)) AND
	        %SYSFUNC(EXIST(&&DRUG_NDC_TABLE_&ADJ_ENGINE)) %THEN %DO; 
			%LET CLM_BEGIN_DT_CONV = %STR(RVWDT.CLAIM_BEGIN_DT); 
			%LET CLM_END_DT_CONV = %STR(RVWDT.CLAIM_END_DT);
			%LET CLM_BEGIN_DT_PLUS_1WK = %STR(RVWDT.CLAIM_BEGIN_DT - 7);
			%LET CLM_END_DT_PLUS_1WK = %STR(RVWDT.CLAIM_END_DT + 7);
			%LET RVW_DATES_TABLE = %STR(,&DRUG_RVW_DATES_TABLE. RVWDT);
			%LET RVW_DATES_CONS = %STR(AND NDC.DRG_GROUP_SEQ_NB = RVWDT.DRG_GROUP_SEQ_NB
			                           AND NDC.DRG_SUB_GRP_SEQ_NB = RVWDT.DRG_SUB_GRP_SEQ_NB);
		%END;
		%ELSE %DO;
			%LET RVW_DATES_TABLE = %STR();
			%LET RVW_DATES_CONS = %STR();
		%END;

		%PUT NOTE: CLM_BEGIN_DT_CONV = &CLM_BEGIN_DT_CONV;
		%PUT NOTE: CLM_END_DT_CONV = &CLM_END_DT_CONV;
		%PUT NOTE: CLM_BEGIN_DT_PLUS_1WK = &CLM_BEGIN_DT_PLUS_1WK;
		%PUT NOTE: CLM_END_DT_PLUS_1WK = &CLM_END_DT_PLUS_1WK;

		/** CONSTRAINTS BASED ON DRUG SET-UP **/

		PROC SQL NOPRINT;
		 SELECT DRG_DEFINITION_CD, 
		        DFL_CLT_INC_EXU_IN
		 INTO :DRG_DEFINITION_CD,
		      :RESOLVE_CLIENT_EXCLUDE_FLAG
		 FROM &HERCULES..TINITIATIVE INIT
		     ,&HERCULES..TPROGRAM_TASK PGMTASK
		 WHERE INIT.INITIATIVE_ID = &INITIATIVE_ID.
		   AND INIT.PROGRAM_ID = PGMTASK.PROGRAM_ID
		   AND INIT.TASK_ID = PGMTASK.TASK_ID;
		QUIT;
		
		%PUT NOTE: DRG_DEFINITION_CD = &DRG_DEFINITION_CD.;
		%PUT NOTE: RESOLVE_CLIENT_EXCLUDE_FLAG = &RESOLVE_CLIENT_EXCLUDE_FLAG.;
		%PUT &&DRUG_NDC_TABLE_&ADJ_ENGINE;

*SASDOC--------------------------------------------------------------------------
|JUNE 2012 - TARGET BY DRUG/ DSA AUTOMATION
|EB - ADDED NEW MACRO VARIABLE BRAND_NDC FOR BRAND-GENERIC DRUGS
+------------------------------------------------------------------------SASDOC*;
		%IF %SYSFUNC(EXIST(&&DRUG_NDC_TABLE_&ADJ_ENGINE)) AND &DRG_DEFINITION_CD. = 2 %THEN %DO;
			%LET DRUG_NDC_TABLE = %STR(,&&DRUG_NDC_TABLE_&ADJ_ENGINE NDC 
                                       &RVW_DATES_TABLE.);
			%LET DRUG_CONS = %STR(AND CLAIM.DRUG_GID = NDC.DRUG_GID
                                  &RVW_DATES_CONS.); 
			%LET SELECT_DRUG_SEQ = %STR(,NDC.DRUG_CATEGORY_ID  
					                    ,NDC.GPI_GROUP   
	                                    ,NDC.GPI_CLASS);
			%LET BRAND_NDC      = %STR(,NDC.DRUG_BRAND_CD AS BRAND_GENERIC);
		%END;
		%ELSE %IF NOT %SYSFUNC(EXIST(&&DRUG_NDC_TABLE_&ADJ_ENGINE)) AND &DRG_DEFINITION_CD. = 2 %THEN %DO;
			%LET DRUG_NDC_TABLE = %STR();
			%LET DRUG_CONS = %STR();
			%LET SELECT_DRUG_SEQ = %STR(,59 AS DRUG_CATEGORY_ID  
					                    ,'  ' AS GPI_GROUP   
	                                    ,'  ' AS GPI_CLASS);
			%IF &ADJ_ENGINE.= RX %THEN %DO;
				%LET BRAND_NDC      = %STR(,CASE WHEN DRUG.MULTI_TYPE_CODE IN ('Y') 
					      THEN 'G'
					      WHEN DRUG.MULTI_TYPE_CODE IN ('M','N','O')
					      THEN 'B'
						  ELSE ' '
					 END AS BRAND_GENERIC);
			%END;
			%ELSE %IF &ADJ_ENGINE.= RE %THEN %DO;
					%LET BRAND_NDC      = %STR(,CASE WHEN DRUG.RECAP_GNRC_FLAG IN ('1') 
					      THEN 'G'
					      WHEN DRUG.RECAP_GNRC_FLAG IN ('2')
					      THEN 'B'
						  ELSE ' '
					 END AS BRAND_GENERIC);
			%END;
		%END;
		%ELSE %IF %SYSFUNC(EXIST(&&DRUG_NDC_TABLE_&ADJ_ENGINE)) %THEN %DO;
			%LET DRUG_NDC_TABLE = %STR(,&&DRUG_NDC_TABLE_&ADJ_ENGINE NDC
									   &RVW_DATES_TABLE.); 
			%LET DRUG_CONS = %STR(AND CLAIM.DRUG_GID = NDC.DRUG_GID
								  &RVW_DATES_CONS.); 
			%LET SELECT_DRUG_SEQ = %STR(,NDC.DRG_GROUP_SEQ_NB 
					                    ,NDC.DRG_SUB_GRP_SEQ_NB);
			%LET BRAND_NDC      = %STR(,NDC.DRUG_BRAND_CD AS BRAND_GENERIC);
		%END;
		%ELSE %DO;
			%LET DRUG_NDC_TABLE = %STR();
			%LET DRUG_CONS = %STR();
			%LET SELECT_DRUG_SEQ = %STR(,1 AS DRG_GROUP_SEQ_NB
					                    ,1 AS DRG_SUB_GRP_SEQ_NB);
			%IF &ADJ_ENGINE.= RX %THEN %DO;
				%LET BRAND_NDC      = %STR(,CASE WHEN DRUG.MULTI_TYPE_CODE IN ('Y') 
					      THEN 'G'
					      WHEN DRUG.MULTI_TYPE_CODE IN ('M','N','O')
					      THEN 'B'
						  ELSE ' '
					 END AS BRAND_GENERIC);
			%END;
			%ELSE %IF &ADJ_ENGINE.= RE %THEN %DO;
					%LET BRAND_NDC      = %STR(,CASE WHEN DRUG.RECAP_GNRC_FLAG IN ('1') 
					      THEN 'G'
					      WHEN DRUG.RECAP_GNRC_FLAG IN ('2')
					      THEN 'B'
						  ELSE ' '
					 END AS BRAND_GENERIC);
			%END;
		%END;

*SASDOC--------------------------------------------------------------------------
|JUNE 2012 - TARGET BY DRUG/ DSA AUTOMATION
|EB - PRESCRIBER CONSTRAINS DO NOT NEED TO BE APPLIED FOR CLAIMS PULL
|     THIS LOGIC WILL BE APPLIED INDIVIDUALLY ON PRESCRIBER FILE ONLY
+------------------------------------------------------------------------SASDOC*;
		 %LET PRSCR_CONS = %STR();

		/** CONSTRAINTS BASED ON CLIENT SET-UP **/
*SASDOC--------------------------------------------------------------------------
|JUNE 2012 - TARGET BY DRUG/ DSA AUTOMATION
|EB - FOR TARGET BY DRUG (106) CLIENT CONSTRAIN WILL BE APPLIED ON THE HIGHEST HIERARCHY
|     LEVEL ONLY, PARTIAL CLIENT LOGIC WOULD BE APPLIED DURING ELIGIBILITY PULL 
+------------------------------------------------------------------------SASDOC*;
		%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..ALGN_LVL_LIST_&INITIATIVE_ID._&ADJ_ENGINE.);

		%IF %SYSFUNC(EXIST(&&RESOLVE_CLIENT_TABLE_&ADJ_ENGINE)) %THEN %DO;

			%IF &RESOLVE_CLIENT_EXCLUDE_FLAG = 1 %THEN %DO;
				%LET CLT_JOIN = %STR(LEFT JOIN);
				%LET CLT_JOIN_CONS = %STR(AND B.ALGN_LVL_GID_KEY IS NULL);
			%END;
			%ELSE %DO;
				%LET CLT_JOIN = %STR(INNER JOIN);
				%LET CLT_JOIN_CONS = %STR();
			%END;

			PROC SQL NOPRINT;
				CONNECT TO ORACLE(PATH=&GOLD );
				CREATE TABLE DATA_RES.ALGN_LVL_LIST_&INITIATIVE_ID._&ADJ_ENGINE. AS
				SELECT * FROM CONNECTION TO ORACLE
				( 
				SELECT DISTINCT A.ALGN_LVL_GID_KEY
								&HIERARCHY_LIST.
/*						   	   ,A.QL_CLNT_ID AS QL_CLIENT_ID*/
							   ,A.PAYER_ID
							   ,A.CUST_NM AS CLIENT_NM
			    FROM  DSS_CLIN.V_ALGN_LVL_DENORM A
				&CLT_JOIN.
				      &&RESOLVE_CLIENT_TABLE_&ADJ_ENGINE B
				ON A.ALGN_LVL_GID_KEY = B.ALGN_LVL_GID_KEY
				WHERE A.SRC_SYS_CD = %BQUOTE('&SRC_SYS_CD')
/*				  AND SYSDATE BETWEEN A.ALGN_GRP_EFF_DT AND A.ALGN_GRP_END_DT*/
				  &CLT_JOIN_CONS.
				ORDER BY A.ALGN_LVL_GID_KEY
			  	) ;
			    DISCONNECT FROM ORACLE;
			QUIT;
			
			/** EVEN THOUGH QL_CLIENT_ID IS APPROPRIATELY POPULATED FOR RX IN EDW,
			    IT IS NOT POPULATED FOR RE. SO THE QL_CLIENT_ID FIELD IS 
			    OBTAINED FROM CLAIMSA.TCLIENT1 TABLE **/

			PROC SQL;
				CREATE TABLE &ORA_TMP..ALGN_LVL_LIST_&INITIATIVE_ID._&ADJ_ENGINE. AS
				SELECT DISTINCT A.*, COALESCE(B.CLIENT_ID,-1) AS QL_CLIENT_ID
				FROM DATA_RES.ALGN_LVL_LIST_&INITIATIVE_ID._&ADJ_ENGINE. A
				LEFT JOIN
				     &CLAIMSA..TCLIENT1 B
				ON TRIM(LEFT(A.&CARRIER_FIELD.)) = TRIM(LEFT(SUBSTR(B.CLIENT_CD,2)));
			QUIT;

			PROC SQL;
				DROP TABLE DATA_RES.ALGN_LVL_LIST_&INITIATIVE_ID._&ADJ_ENGINE.;
			QUIT;	
			

		%END; /*%IF %SYSFUNC(EXIST(&&RESOLVE_CLIENT_TABLE_&ADJ_ENGINE)) - true*/

*SASDOC--------------------------------------------------------------------------
|JUNE 2012 - TARGET BY DRUG/ DSA AUTOMATION
|ASSIGN CLIENT VARIABLES
+------------------------------------------------------------------------SASDOC*;
				%LET CLIENT_TABLE = %STR(&DSS_CLIN..V_ALGN_LVL_DENORM CLT); 
 			

				%IF &ADJ_ENGINE. = RX %THEN %DO;
				%LET CLIENT_VARS_1 = %STR(
									,CLT.EXTNL_LVL_ID1 AS CLIENT_LEVEL_1 );
				
				%END;

				%IF &ADJ_ENGINE. = RE %THEN %DO;
				%LET CLIENT_VARS_1 = %STR(
									,CLT.RPT_OPT1_CD AS CLIENT_LEVEL_1 );
				
				%END;	
		%PUT NOTE: CLIENT_TABLE = &CLIENT_TABLE. ;
		%PUT NOTE: CLIENT_VARS_1  = &CLIENT_VARS_1. ;
	
*SASDOC--------------------------------------------------------------------------
|JUNE 2012 - TARGET BY DRUG/ DSA AUTOMATION
|EB - BELOW IS COMMENTED OUT, AS NEW FIELD IS BEING MAPPED TO REFILL_FILL_QTY
+------------------------------------------------------------------------SASDOC*;
		

		/** IF REFILL_FILL_QTY IS POPULATED IN TFILE AND TFILE_FIELD FOR 
		    THE INITIATIVE THEN JOIN AGAINST V_CLAIM AND OBTAIN 
		    SBMTD_REFIL_ATHZD (RX) OR ATHZD_REFIL_QTY (RE) AS REFILL_FILL_QTY 
		    OTHERWISE LEAVE REFILL_FILL_QTY AS NULL  **/

/*				PROC SQL NOPRINT;*/
/*					SELECT COUNT(*) INTO : REFILL_FILL_QTY*/
/*					FROM &HERCULES..TFILE_FIELD AS A,*/
/*					&HERCULES..TFIELD_DESCRIPTION AS B,*/
/*					&HERCULES..TPHASE_RVR_FILE AS C*/
/*					WHERE INITIATIVE_ID=&INITIATIVE_ID*/
/*					AND PHASE_SEQ_NB=&PHASE_SEQ_NB*/
/*					AND A.FILE_ID = C.FILE_ID*/
/*					AND A.FIELD_ID = B.FIELD_ID*/
/*					AND LEFT(TRIM(FIELD_NM)) IN ('REFILL_FILL_QY')*/
/*					;*/
/*				QUIT;*/
/**/
/*				%IF &REFILL_FILL_QTY >= 1 %THEN %DO;*/
/*					%IF &ADJ_ENGINE. = RX %THEN %DO;*/
/*						%LET REFIL_QTY_CLM_TABLE = %STR(,&DSS_CLIN..V_CLAIM VCLM);*/
/*					%END;*/
/*					%ELSE %IF &ADJ_ENGINE. = RE %THEN %DO;*/
/*						%LET REFIL_QTY_CLM_TABLE = %STR(,&DSS_CLIN..V_CLAIM_ALV VCLM);*/
/*					%END;*/
/*					%LET REFIL_QTY_CLM_TABLE_CONS = %STR(AND CLAIM.CLAIM_GID = VCLM.CLAIM_GID*/
/*													 	 AND VCLM.BATCH_DATE BETWEEN &CLM_BEGIN_DT_PLUS_1WK. AND &CLM_END_DT_PLUS_1WK.);*/
/*				%END;*/
/*				%ELSE %DO;*/
/*					%LET REFIL_QTY_CLM_TABLE = %STR();*/
/*					%LET REFIL_QTY_CLM_TABLE_CONS = %STR();*/
/*					%LET REFILL_QTY = %STR(,0 AS REFILL_FILL_QY);*/
/*				%END;*/

/*		%INCLUDE "/PRG/sas&sysmode.1/hercules/katya/macros/delivery_sys_check_tbd.sas";*/
/*		commented for testing purpose - Sandeep*/
		%INCLUDE "/herc&sysmode/prg/hercules/macros/delivery_sys_check_tbd.sas";
		%IF &ADJ_ENGINE. = RX %THEN %LET CREATE_DELIVERY_SYSTEM_CD=&CREATE_DELIVERY_SYSTEM_CD_RX. ;
		%IF &ADJ_ENGINE. = RE %THEN %LET CREATE_DELIVERY_SYSTEM_CD=&CREATE_DELIVERY_SYSTEM_CD_RE. ;
		%IF &ADJ_ENGINE. = RX %THEN %LET DS_STRING_RX_RE=&DS_STRING_RX. ;
		%IF &ADJ_ENGINE. = RE %THEN %LET DS_STRING_RX_RE=&DS_STRING_RE. ;

		%PUT NOTE: CREATE_DELIVERY_SYSTEM_CD = &CREATE_DELIVERY_SYSTEM_CD. ;
		%PUT NOTE: DS_STRING_RX_RE = &DS_STRING_RX_RE. ;
*SASDOC--------------------------------------------------------------------------
|JUNE 2012 - TARGET BY DRUG/ DSA AUTOMATION
|EB - PULL OUT HIGHEST HIERARCHY LEVEL - THIS WOULD BE USED IN CLAIM QUERY
+------------------------------------------------------------------------SASDOC*;
		%IF %SYSFUNC(EXIST(&ORA_TMP..ALGN_LVL_LIST_&INITIATIVE_ID._&ADJ_ENGINE.))
		%THEN %DO;
				PROC SQL NOPRINT;
	  			SELECT COUNT(*) INTO :LVL1_CNT SEPARATED BY ','
	  			FROM &ORA_TMP..ALGN_LVL_LIST_&INITIATIVE_ID._&ADJ_ENGINE.;
				QUIT;

				PROC SQL NOPRINT;
	  			SELECT DISTINCT "'" || CLIENT_LEVEL_1 ||"'" INTO :LVL1_STR SEPARATED BY ','
	  			FROM &ORA_TMP..ALGN_LVL_LIST_&INITIATIVE_ID._&ADJ_ENGINE.;
				QUIT;

				%IF %EVAL(&LVL1_CNT.) GT 0 %THEN %DO;
				     %IF &ADJ_ENGINE. = RX %THEN %DO;
					     %LET CTL_STR_TBD = %STR(AND CLT.EXTNL_LVL_ID1 IN (&LVL1_STR.));
					 %END;
				     %ELSE %IF &ADJ_ENGINE. = RE %THEN %DO;
					 	 %LET CTL_STR_TBD = %STR(AND CLT.RPT_OPT1_CD IN (&LVL1_STR.));
					 %END;
					%ELSE %DO;
						%LET CTL_STR_TBD = %STR();
					%END; 
				%END;
				%ELSE %DO;
				%LET CTL_STR_TBD = %STR();
				%LET LVL1_CNT = 0;
				%END;
		%END;
		%ELSE %DO;
			%LET CTL_STR_TBD = %STR();
			%LET LVL1_CNT = 0;
		%END;

		%PUT NOTE: CTL_STR_TBD = &CTL_STR_TBD. ;
		%PUT NOTE: LVL1_CNT = &LVL1_CNT. ;

		DATA _NULL_;
			CALL SYMPUT ('START_TM',PUT(%SYSFUNC(DATETIME()), DATETIME23.));
		RUN;
		%PUT NOTE: PULL FROM CLAIMS - START TIME - &START_TM;

		%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.);
		%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..TMP_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.);
		%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..TMP2_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.);
		%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..TMP3_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.);

*SASDOC--------------------------------------------------------------------------
|24MAR2009 - Hercules Version  2.1.2.02
|G. DUDLEY - REMOVED LOGIC TO EXTRACT DATA FOR REFILL_FILL_QTY AND SET COLUMN
|            TO ZERO INSTEAD
+------------------------------------------------------------------------SASDOC*;

*SASDOC--------------------------------------------------------------------------
|JUNE 2012 - TARGET BY DRUG/ DSA AUTOMATION
|EB - NEW FIELDS ARE BEING PULLED IN THE QUERY, SELECTION LOGIC IS ADJUSTED
|	  CLIENT AND MEMBER FIELDS ARE COMMENTED OUT FOR TARGET BY DRUG (106)
|	  AS THEY WILL BE PULLED IN ELIGIBILITY QUERY
+------------------------------------------------------------------------SASDOC*;


		PROC SQL;
			CONNECT TO ORACLE(PATH=&GOLD PRESERVE_COMMENTS);
			     CREATE TABLE WORK.TMP_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE AS
        SELECT * FROM CONNECTION TO ORACLE
/*			EXECUTE*/
			(
/*				CREATE TABLE &ORA_TMP..TMP_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. AS*/		
				SELECT 	/* + ORDERED */
						%BQUOTE('&ADJ_ENGINE') AS ADJ_ENGINE
						&CLIENT_VARS_1.
						,PRCTR.PRCTR_ID AS PRACTITIONER_ID 
						,PRCTR.QL_PRSCR_ID AS PRESCRIBER_ID
						,PRCTR.ENTITY_IND
						,PRCTR.DEGR_1_CD
						,PRCTR.REC_SRC_FLG as prctr_rec_src
						,PRCTR.TERM_REAS_CD  as prctr_term_reas_cd
						,PHMCY.NABP_CODE_6
						,CLAIM.PAYER_ID
						,CLAIM.MBR_GID
						,CLAIM.PHMCY_GID
						,CLAIM.PRCTR_GID
						,CLAIM.DSPND_DATE
						,CLAIM.BATCH_DATE
						,CLAIM.AMT_COPAY AS MEMBER_COST_AT
						,CLAIM.BNFT_LVL_CODE
						,SUBSTR(CLAIM.RX_NBR,1,7)             AS RX_NBR
						,CLAIM.EXTNL_CLAIM_ID                 AS DOC_NB
						,CLAIM.EXTNL_CLAIM_SEQ_NBR            AS DOC_NB_SEQ
						,SUBSTR(CLAIM.DSPND_DATE, 1, 10) AS LAST_FILL_DT
						,CLAIM.CLAIM_TYPE AS RX_COUNT_QY
						,CLAIM.UNIT_QTY 
						,CLAIM.DAYS_SPLY
						,DRUG.DRUG_GID
					    ,&GCN_CODE.
						,CAST(DRUG.QL_NHU_TYPE_CD AS INT) AS NHU_TYPE_CD
						,CAST(DRUG.NDC_CODE AS INT) AS DRUG_NDC_ID
						,CAST(SUBSTR(DRUG.GPI_CODE,01,14) AS CHAR(14)) AS GPI
						&SELECT_DRUG_SEQ.
						,DRUG.DSG_FORM AS DRUG_ABBR_DSG_NM
						,DRUG.BRAND_NAME AS DRUG_ABBR_PROD_NM
						,DRUG.STRGH_DESC AS DRUG_ABBR_STRG_NM
						,DRUG.QL_DRUG_BRND_CD as DRUG_BRAND_CD
						/*            ,&REFILL_QTY.*/
						,CAST(CLAIM.NEW_REFIL_CODE AS INT) AS REFILL_FILL_QY
						,0 AS LTR_RULE_SEQ_NB
						,PRCTR.PRCTR_NPI_ID AS PRESCRIBER_NPI_NB
						,PHMCY.PHMCY_NAME AS PHARMACY_NM
						&BRAND_NDC.  
						,FRMLY.FRMLY_NB AS FORMULARY_TX
						,PRCTR1.PRCTR_ID AS DEA_NB
						,&CREATE_DELIVERY_SYSTEM_CD.
				FROM 	
						 &CLIENT_TABLE.
						,&DSS_CLIN..V_CLAIM_CORE_PAID CLAIM

				LEFT JOIN &DSS_CLIN..V_FRMLY_HDR FRMLY
				     ON CLAIM.FRMLY_GID = FRMLY.FRMLY_GID

/*		                 &REFIL_QTY_CLM_TABLE.*/
						 &DRUG_NDC_TABLE.
						,DSS_HERC.V_DRUG_DENORM DRUG
						,&DSS_CLIN..V_PRCTR_DENORM PRCTR

				LEFT JOIN &DSS_CLIN..V_PRCTR_DENORM PRCTR1
				   ON PRCTR.PRCTR_NPI_ID = PRCTR1.PRCTR_NPI_ID
				   AND PRCTR1.PRCTR_ID_TYP_CD = 'DH'
				   AND PRCTR1.PRCTR_ID <> PRCTR1.PRCTR_NPI_ID


						,&DSS_CLIN..V_PHMCY_DENORM PHMCY   
				
	

				WHERE	CLAIM.DSPND_DATE BETWEEN &CLM_BEGIN_DT_CONV AND &CLM_END_DT_CONV 				
					AND	CLAIM.SRC_SYS_CD = %BQUOTE('&SRC_SYS_CD')
					&CTL_STR_TBD.
					AND CLAIM.CLAIM_WSHD_CD IN ('P')
					AND DRUG.DRUG_VLD_FLG = 'Y'
					AND CLAIM.ADJD_SRC_CD not in ('M')

					AND CLAIM.ALGN_LVL_GID = CLT.ALGN_LVL_GID_KEY  
					AND CLAIM.PRCTR_GID = PRCTR.PRCTR_GID
					&PRSCR_CONS.
					&DRUG_CONS.
					AND CLAIM.PHMCY_GID = PHMCY.PHMCY_GID
					AND CLAIM.DRUG_GID = DRUG.DRUG_GID
/*					&DS_STRING_RX_RE.*/
/*					&REFIL_QTY_CLM_TABLE_CONS.*/
				
				ORDER BY PAYER_ID, MBR_GID
			) 
/*			BY ORACLE*/
			;
		DISCONNECT FROM ORACLE;
		QUIT;
		

		%put _all_;

		DATA _NULL_;
			CALL SYMPUT ('END_TM',PUT(%SYSFUNC(DATETIME()), DATETIME23.));
		RUN;
		%PUT NOTE: PULL FROM CLAIMS END TIME - &END_TM;

		DATA &ORA_TMP..TMP_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.;
		SET WORK.TMP_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.;
		&DS_STRING_SAS.
		RUN;


		PROC SQL;
			SELECT COUNT(*) INTO :EDW_CLAIM_CNT
			FROM &ORA_TMP..TMP_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. ;
		QUIT;

		%PUT NOTE: &ORA_TMP..TMP_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. - &EDW_CLAIM_CNT.;

		/** IF EDW_CLAIM_CNT > 0 THEN PROCEED TO JOIN AGAINST V_MBR TABLE
		    TO GET MEMBER INFORMATION. OTHERWISE GENERATE AN ERROR AND 
		    SEND OUT AN EMAIL
			NOTE: THE JOIN AGAINST V_MBR IS SEPARATED OUT AS THE JOIN AGAINST
		          THIS TABLE TAKES A LOT OF TIME.
		          SO A TEMP TABLE IS CREATED WITH DISTINCT MBR_GID AND PAYER_ID
		          AND JOINED AGAINST V_MBR TABLE, WHICH HAS DRASTICALLY IMPROVED 
		          THE PERFORMANCE.
		          ALSO IF THE DISTINCT COUNT OF MBR_GID AND PAYER_ID IN TEMP TABLE
		          IS GREATER THAN 10MIL THEN INDEX LOOKUP IS AVAOIDED AND SO FULL SCAN
		          IS ENABLED
		**/

		%IF &EDW_CLAIM_CNT. > 0 %THEN %DO;

			PROC SQL;
			CONNECT TO ORACLE(PATH=&GOLD PRESERVE_COMMENTS);
			EXECUTE
			(
				CREATE TABLE &ORA_TMP..TMP2_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. AS
			     SELECT PAYER_ID, MBR_GID, COUNT(*) AS CNT
				 FROM &ORA_TMP..TMP_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.
				 GROUP BY PAYER_ID, MBR_GID
				 ORDER BY PAYER_ID, MBR_GID
			) BY ORACLE;
			DISCONNECT FROM ORACLE;
			QUIT;

			PROC SQL;
				SELECT COUNT(*) INTO :EDW_CLAIM_CNT2
				FROM &ORA_TMP..TMP2_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.
			QUIT;
			%PUT "NOTE: CLAIM COUNT FOR DISTINCT MBR_GID+PAYER_ID - &EDW_CLAIM_CNT2";

			PROC SQL;
				SELECT COUNT(*) INTO :EDW_CLAIM_CNT
				FROM &ORA_TMP..TMP2_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. ;
			QUIT;

			%PUT NOTE: &ORA_TMP..TMP2_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. - &EDW_CLAIM_CNT;
		
			%IF &EDW_CLAIM_CNT2. >= 25000000 
			%THEN 
				%LET AVOID_IX_LKP = %STR(/1);
			%ELSE 
				%LET AVOID_IX_LKP = %STR();

			DATA _NULL_;
				CALL SYMPUT ('START_TM',PUT(%SYSFUNC(DATETIME()), DATETIME23.));
			RUN;
			%PUT NOTE: JOIN CLAIMS WITH MBR START TIME - &START_TM;

*SASDOC--------------------------------------------------------------------------
|26FEB2009 - Hercules Version  2.1.2.02
|G. DUDLEY - ADDED THE "MBR_REUSE_RISK_FLG" TO THE QUERY TO EXTRACT MEMBER
|            DEMOGRAPHICS FROM THE V-MBR VIEW.  THIS WILL BE USED TO EXCLUDE 
|            SUSPECT MEMBERS DUE TO POSSIBLE MEBER ID REUSE.
+------------------------------------------------------------------------SASDOC*;
*SASDOC--------------------------------------------------------------------------
|JUNE 2012 - TARGET BY DRUG/ DSA AUTOMATION
|EB - MBR RE-USE LOGIC IS ADJUSTED
+------------------------------------------------------------------------SASDOC*;
			PROC SQL;
				CONNECT TO ORACLE(PATH=&GOLD PRESERVE_COMMENTS);
				EXECUTE
				(
					CREATE TABLE &ORA_TMP..TMP3_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. AS
					SELECT CLAIM.*

							,MBR.MBR_ID AS MBR_ID
							,MBR.MBR_REUSE_RISK_FLG	
							,SUBSTR(MBR.MBR_REUSE_LAST_UPDT_DT,1,10) AS MBR_REUSE_LAST_UPDT_DT
							,MBR.MBR_GNDR_GID
							,MBR.PRSN_CURR_KEY
							,MBR.MBR_BRTH_DT AS M_DOB
							,MBR.REL_CODE
					FROM 	
							&ORA_TMP..TMP2_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. CLAIM     
							,&DSS_CLIN..V_MBR MBR
					WHERE
							MBR.PAYER_ID&AVOID_IX_LKP. &PAYER_ID_CONS.
						AND CLAIM.PAYER_ID&AVOID_IX_LKP. = MBR.PAYER_ID&AVOID_IX_LKP.
						AND CLAIM.MBR_GID&AVOID_IX_LKP. = MBR.MBR_GID&AVOID_IX_LKP.
/*            AND MBR.MBR_REUSE_RISK_FLG IS NULL*/

				) BY ORACLE;
			DISCONNECT FROM ORACLE;
			QUIT;

			PROC SQL;
				SELECT COUNT(*) INTO :EDW_CLAIM_CNT
				FROM &ORA_TMP..TMP3_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. ;
			QUIT;

			%PUT NOTE: &ORA_TMP..TMP3_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. - &EDW_CLAIM_CNT;


		/** PERFORM PARTICIPANT EXCLUSIONS, IF ANY, BASED ON PROGRAM_ID BY GOING AGAINST
			PARTICIPANT_EXCLUSION TABLE IN 
			/DATA/%LOWCASE(SAS&SYSMODE.1/HERCULES/PARTICIPANT_EXCLUSIONS DIRECTORY 
			THIS IS DONE BY CALLING MACRO PARTICIPANT_EXCLUSIONS **/

/*			%LOAD_PARTICIPANT_EXCLUSION;*/
/*			%PARTICIPANT_EXCLUSIONS(TBL_NAME_IN = &ORA_TMP..TMP3_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.);*/

			PROC SQL;
				CONNECT TO ORACLE(PATH=&GOLD PRESERVE_COMMENTS);
				EXECUTE
				(
					CREATE TABLE &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. AS
					SELECT  
			                CLAIM.*
							,MBR.MBR_ID
			 				,MBR.MBR_GNDR_GID
			 				,MBR.PRSN_CURR_KEY
							,MBR.M_DOB
							,MBR.REL_CODE

					FROM 	
							&ORA_TMP..TMP_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. CLAIM     
							,&ORA_TMP..TMP3_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. MBR
					WHERE
						    CLAIM.MBR_GID = MBR.MBR_GID
						AND CLAIM.PAYER_ID = MBR.PAYER_ID
						AND ((MBR.MBR_REUSE_RISK_FLG IS NULL) or
			(MBR.MBR_REUSE_RISK_FLG ='Y' and CLAIM.LAST_FILL_DT > MBR.MBR_REUSE_LAST_UPDT_DT))
					ORDER BY
							 CLAIM.MBR_GID
						    ,CLAIM.CLIENT_LEVEL_1
							,CLAIM.DRUG_GID
							,CLAIM.PHMCY_GID
							,CLAIM.PRCTR_GID
				) BY ORACLE;
			DISCONNECT FROM ORACLE;
			QUIT;

			PROC SQL;
				SELECT COUNT(*) INTO :EDW_CLAIM_CNT
				FROM &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. ;
			QUIT;

			%PUT NOTE: &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. - &EDW_CLAIM_CNT;

			DATA _NULL_;
				CALL SYMPUT ('END_TM',PUT(%SYSFUNC(DATETIME()), DATETIME23.));
			RUN;
			%PUT NOTE: JOIN CLAIMS WITH MBR END TIME - &END_TM;

		%END;
		%ELSE %IF (&QL_ADJ. = 0) and 
                  ((&SRC_SYS_CD. = X and &RE_ADJ. = 0) OR (&SRC_SYS_CD. = R and &RX_ADJ. = 0))
		%THEN %DO;

			%LET ERR_FL = 1;

			%ON_ERROR( ACTION=ABORT
	          ,EM_TO=&PRIMARY_PROGRAMMER_EMAIL
	          ,EM_SUBJECT=HCE SUPPORT: NOTIFICATION OF ABEND INITIATIVE_ID &INITIATIVE_ID
	          ,EM_MSG=%STR(CLAIMS_PULL_EDW MACRO RETURNED 0 ROWS FOR ADJ &ADJ_ENGINE. 
                           SO THE EXECUTION OF THE MAILING PROGRAM HAS BEEN FORCED TO ABORT));

		%END;
		%ELSE %IF &SRC_SYS_CD. = X %THEN %DO;
			%LET RX_ADJ = 0;	
			%put NOTE:  Turn off Rxclaim adjudication indicator.;	
		%END;
		%ELSE %IF &SRC_SYS_CD. = R %THEN %DO;
			%LET RE_ADJ = 0;
			%put NOTE:  Turn off Recap adjudication indicator.;	
		%END;		


		%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..TMP_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.);
		%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..TMP2_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.);
		%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..TMP3_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.);
		**%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..ALGN_LVL_LIST_&INITIATIVE_ID._&ADJ_ENGINE.);


	%MEND EDW_CLAIMS;
	%put NOTE: Executing edw_claims;
	%put RX_adj: &rx_adj;

*SASDOC--------------------------------------------------------------------------
|JUNE 2012 - TARGET BY DRUG/ DSA AUTOMATION
|EB - GCN_CODE MACRO VAR IS SETUP TO BE PLATFORM DEPENDENT
+------------------------------------------------------------------------SASDOC*;
	%IF &RX_ADJ. = 1 %THEN %DO;
		%LET SRC_SYS_CD = %STR(X);
		%LET PAYER_ID_CONS = %STR(< 100000);
		%LET HIERARCHY_LIST = %STR(	,A.EXTNL_LVL_ID1 AS CLIENT_LEVEL_1
					   	   			,A.EXTNL_LVL_ID2 AS CLIENT_LEVEL_2
					   	   			,A.EXTNL_LVL_ID3 AS CLIENT_LEVEL_3	);
/*		%LET REFILL_QTY = %STR(,VCLM.SBMTD_REFIL_ATHZD AS REFILL_FILL_QY);*/
		%LET GCN_CODE = %STR(DRUG.GCN_NBR AS GCN_CODE);
		%LET CARRIER_FIELD = CLIENT_LEVEL_1;
		%EDW_CLAIMS(ADJ_ENGINE = RX);
	%END;

	%IF &RE_ADJ. = 1 %THEN %DO;
		%LET SRC_SYS_CD = %STR(R);
		%LET PAYER_ID_CONS = %STR(BETWEEN 500000 AND 2000000);
		%LET HIERARCHY_LIST = %STR(	,A.RPT_OPT1_CD AS CLIENT_LEVEL_1
					   	   			,A.EXTNL_LVL_ID1 AS CLIENT_LEVEL_2
					   	   			,A.EXTNL_LVL_ID3 AS CLIENT_LEVEL_3	);
/*		%LET REFILL_QTY = %STR(,VCLM.ATHZD_REFIL_QTY AS REFILL_FILL_QY);*/
		%LET GCN_CODE = %STR(CAST(DRUG.RECAP_GNRC_CLASS_NBR AS INT) AS GCN_CODE);
		%LET CARRIER_FIELD = CLIENT_LEVEL_2;
		%EDW_CLAIMS(ADJ_ENGINE = RE);
	%END;


%MEND CLAIMS_PULL_EDW_TBD_rg; 





