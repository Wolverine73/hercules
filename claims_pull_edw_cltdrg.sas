/*HEADER---------------------------------------------------------------------------------------------------------
|MACRO: 		CLAIMS_PULL_EDW_CLTDRG_SPECIFIC.SAS
|
|PURPOSE: 		
|
|INPUT:			
|
|LOGIC:       					
|						
|OUTPUT:			
|+-----------------------------------------------------------------------------------------------------------------
|HISTORY: 
|			    SR 01OCT2008 - Hercules Version  2.1.2.01
|26FEB2009 - Hercules Version  2.1.2.02
|G. DUDLEY - CHANGED THE FORMAT OF DATE MACRO VARIABLE USED IN ORACLE QUERIES
|G. DUDLEY - ADDED THE "MBR_REUSE_RISK_FLG" TO THE QUERY TO EXTRACT MEMBER
|            DEMOGRAPHICS FROM THE V-MBR VIEW.  THIS WILL BE USED TO EXCLUDE 
|            SUSPECT MEMBERS DUE TO POSSIBLE MEBER ID REUSE.
|25MAR2013 - M.Beezhold - Added PII-key columns and updated MBR_REUSE_RISK_FLG rule. (ITPR004354)
+-----------------------------------------------------------------------------------------------------------HEADER*/


/********************** EXAMPLE CALL *******************************/
/*
%set_sysmode(mode = test);
OPTIONS SYSPARM='initiative_id=6138 phase_seq_nb=1';
OPTIONS MLOGIC MPRINT SOURCE2;
%INCLUDE "/PRG/sastest1/hercules/hercules_in.sas";

%CLAIMS_PULL_EDW_CLTDRG_SPECIFIC
                (CLIENT_DRUG_TABLE_RX = &ORA_TMP..EXT_CLIENT_DRUG_TABLE_RX,
				 CLIENT_DRUG_TABLE_RE = &ORA_TMP..EXT_CLIENT_DRUG_TABLE_RE
                 );
*/
/********************** EXAMPLE CALL *******************************/

*SASDOC--------------------------------------------------------------------------
|26FEB2009 - Hercules Version  2.1.2.02
|G. DUDLEY - REMOVED THE MACRO PARAMETERS CLM_BEGIN_DT = %STR(&CLAIM_BEGIN_DT)
|            AND CLM_END_DT = %STR(&CLAIM_END_DT)
+------------------------------------------------------------------------SASDOC*;
%MACRO CLAIMS_PULL_EDW_CLTDRG(CLIENT_DRUG_TABLE_RX = &ORA_TMP..EXT_CLIENT_DRUG_TABLE_RX,
					                   CLIENT_DRUG_TABLE_RE = &ORA_TMP..EXT_CLIENT_DRUG_TABLE_RE);

OPTIONS MPRINT MLOGIC;

	%MACRO EDW_CLAIMS(ADJ_ENGINE=);

	PROC SQL;
		SELECT COUNT(*) 
        INTO :CNT
		FROM &&CLIENT_DRUG_TABLE_&ADJ_ENGINE
		WHERE PROGRAM_ID = &PROGRAM_ID.;
	QUIT;

	%IF &CNT >= 1 %THEN %DO;

*SASDOC--------------------------------------------------------------------------
|26FEB2009 - Hercules Version  2.1.2.02
|G. DUDLEY - CHANGED THE FORMAT OF DATE MACRO VARIABLE USED IN ORACLE QUERIES
+------------------------------------------------------------------------SASDOC*;
		/** DATE MANIPULATIONS FOR ORACLE **/
    %LET STARTDAY=TODAY();  *** length of the most recent days a pt used RETAILS;
    DATA _NULL_;
      CALL SYMPUT('CLM_BEGIN_DT', PUT(&startday.-&RTL_HIS_DAYS,YYMMDDD10.));
		  CALL SYMPUT('CLM_END_DT', PUT(&STARTDAY,YYMMDDD10.));

    RUN;
    DATA _NULL_;
		  CALL SYMPUT('CLM_BEGIN_DT_CONV', "TO_DATE('" ||"&CLM_BEGIN_DT" || "','YYYY-MM-DD')" );
		  CALL SYMPUT('CLM_END_DT_CONV', "TO_DATE('" || "&CLM_END_DT" || "','YYYY-MM-DD')" );

		  CALL SYMPUT('CLM_BEGIN_DT_PLUS_1WK', "TO_DATE('" ||PUT(INTNX('WEEK',INPUT("&CLM_BEGIN_DT",YYMMDD10.),-1,'BEGIN'),YYMMDD10.) || "','YYYY-MM-DD')" );
		  CALL SYMPUT('CLM_END_DT_PLUS_1WK', "TO_DATE('" || PUT(INTNX('WEEK',INPUT("&CLM_END_DT",YYMMDD10.),+1,'END'),YYMMDD10.) || "','YYYY-MM-DD')" );
    RUN;

		%PUT NOTE: CLM_BEGIN_DT_CONV = &CLM_BEGIN_DT_CONV;
		%PUT NOTE: CLM_END_DT_CONV = &CLM_END_DT_CONV;
		%PUT NOTE: CLM_BEGIN_DT_PLUS_1WK = &CLM_BEGIN_DT_PLUS_1WK;
		%PUT NOTE: CLM_END_DT_PLUS_1WK = &CLM_END_DT_PLUS_1WK;

		/** CONSTRAINTS BASED ON DRUG SET-UP **/

		%LET SELECT_DRUG_SEQ = %STR(,59 AS DRUG_CATEGORY_ID  
				                    ,CLTDRG.GPI_GROUP   
                                    ,CLTDRG.GPI_CLASS);

		%LET CLIENT_DRUG_TABLE = %STR(&&CLIENT_DRUG_TABLE_&ADJ_ENGINE. CLTDRG);
		%LET CLIENT_DRUG_TABLE2 = %STR(&&CLIENT_DRUG_TABLE_&ADJ_ENGINE. CLTDRG2);


		/** IF REFILL_FILL_QTY IS POPULATED IN TFILE AND TFILE_FIELD FOR 
		    THE INITIATIVE THEN JOIN AGAINST V_CLAIM AND OBTAIN 
		    SBMTD_REFIL_ATHZD (RX) OR ATHZD_REFIL_QTY (RE) AS REFILL_FILL_QTY 
		    OTHERWISE LEAVE REFILL_FILL_QTY AS NULL  **/

				PROC SQL NOPRINT;
					SELECT COUNT(*) INTO : REFILL_FILL_QTY
					FROM &HERCULES..TFILE_FIELD AS A,
					&HERCULES..TFIELD_DESCRIPTION AS B,
					&HERCULES..TPHASE_RVR_FILE AS C
					WHERE INITIATIVE_ID=&INITIATIVE_ID
					AND PHASE_SEQ_NB=&PHASE_SEQ_NB
					AND A.FILE_ID = C.FILE_ID
					AND A.FIELD_ID = B.FIELD_ID
					AND LEFT(TRIM(FIELD_NM)) IN ('REFILL_FILL_QY')
					;
				QUIT;

				%IF &REFILL_FILL_QTY >= 1 %THEN %DO;
					%IF &ADJ_ENGINE. = RX %THEN %DO;
						%LET REFIL_QTY_CLM_TABLE = %STR(,&DSS_CLIN..V_CLAIM VCLM);
					%END;
					%ELSE %IF &ADJ_ENGINE. = RE %THEN %DO;
						%LET REFIL_QTY_CLM_TABLE = %STR(,&DSS_CLIN..V_CLAIM_ALV VCLM);
					%END;
					%LET REFIL_QTY_CLM_TABLE_CONS = %STR(AND CLAIM.CLAIM_GID = VCLM.CLAIM_GID
													 	 AND VCLM.BATCH_DATE BETWEEN &CLM_BEGIN_DT_PLUS_1WK. AND &CLM_END_DT_PLUS_1WK.);
				%END;
				%ELSE %DO;
					%LET REFIL_QTY_CLM_TABLE = %STR();
					%LET REFIL_QTY_CLM_TABLE_CONS = %STR();
					%LET REFILL_QTY = %STR(,0 AS REFILL_FILL_QY);
				%END;

		%INCLUDE "/herc&sysmode/prg/hercules/macros/delivery_sys_check.sas";

		DATA _NULL_;
			CALL SYMPUT ('START_TM',PUT(%SYSFUNC(DATETIME()), DATETIME23.));
		RUN;
		%PUT NOTE: PULL FROM CLAIMS - START TIME - &START_TM;

		%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE.);
		%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..TMP_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE.);
		%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..TMP1_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE.);
		%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..TMP2_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE.);
		%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..TMP3_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE.);

		/** PRESCRIBER CONSTRAINTS TO USE
		    NOTE: IF IT IS A PARTICIPANT ONLY OR CARDHOLDER ONLY MAILING, THE PRESCRIBER
		          CONSTRAINT NEED NOT BE APPLIED **/

		PROC SQL;
			SELECT TRGT_RECIPIENT_CD INTO :TRGT_RECIPIENT_CD
			FROM HERCULES.TPROGRAM_TASK 
			WHERE PROGRAM_ID = &PROGRAM_ID. AND
			TASK_ID = &TASK_ID.;
		QUIT;

		%IF &TRGT_RECIPIENT_CD EQ 1 OR &TRGT_RECIPIENT_CD EQ 4 %THEN %DO;
		  %LET PRSCR_CONS = %STR();
		%END;
		%ELSE %DO;
		  %LET PRSCR_CONS = %STR(AND PRCTR.REC_SRC_FLG = 0
							     AND PRCTR.PRCTR_ID_TYP_CD IN ('DH', 'FW', 'NP'));
		%END;

		%IF &ADJ_ENGINE = RX %THEN %DO;

			%LET HIERARCHY_CONS = %STR( 
										ALGN.SRC_SYS_CD = 'X'
										AND TODAY() BETWEEN DATEPART(ALGN.ALGN_GRP_EFF_DT) AND DATEPART(ALGN.ALGN_GRP_END_DT)
										AND TRIM(LEFT(UPCASE(CLTDRG.CLIENT_LEVEL_1))) = TRIM(LEFT(UPCASE(ALGN.EXTNL_LVL_ID1)))
										AND (CLTDRG.CLIENT_LEVEL_2 = ' ' OR CLTDRG.CLIENT_LEVEL_2 IS NULL OR 
										TRIM(LEFT(UPCASE(CLTDRG.CLIENT_LEVEL_2))) = TRIM(LEFT(UPCASE(ALGN.EXTNL_LVL_ID2))))
										AND (CLTDRG.CLIENT_LEVEL_3 = ' ' OR CLTDRG.CLIENT_LEVEL_3 IS NULL OR 
										TRIM(LEFT(UPCASE(CLTDRG.CLIENT_LEVEL_3))) = TRIM(LEFT(UPCASE(ALGN.EXTNL_LVL_ID3))))
			                            );


		%END;

		%IF &ADJ_ENGINE = RE %THEN %DO;

			%LET HIERARCHY_CONS = %STR( AND ALGN.SRC_SYS_CD = 'R'
										AND TODAY() BETWEEN DATEPART(ALGN.ALGN_GRP_EFF_DT) AND DATEPART(ALGN.ALGN_GRP_END_DT)
										AND TRIM(LEFT(UPCASE(CLTDRG.CLIENT_LEVEL_1))) = TRIM(LEFT(UPCASE(ALGN.RPT_OPT1_CD)))
				            			AND (CLTDRG.CLIENT_LEVEL_2 = ' ' OR CLTDRG.CLIENT_LEVEL_2 IS NULL OR 
				                 			TRIM(LEFT(UPCASE(CLTDRG.CLIENT_LEVEL_2))) = TRIM(LEFT(UPCASE(ALGN.EXTNL_LVL_ID1))))
				            			AND (CLTDRG.CLIENT_LEVEL_3 = ' ' OR CLTDRG.CLIENT_LEVEL_3 IS NULL OR 
				                 			TRIM(LEFT(UPCASE(CLTDRG.CLIENT_LEVEL_3))) = TRIM(LEFT(UPCASE(ALGN.EXTNL_LVL_ID3))))
			             	     	  );
		%END;

		/** PULL THE CLIAMS BASED ON THE CLIENT LIST FOR ALL DRUGS AND THEN
		    SUBSET THE RESULTS FOR CLIENT SPECIFIC DRUG LIST, FOR FASTER PULL **/

		%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..CLT_LST_&INITIATIVE_ID._&ADJ_ENGINE.);
		PROC SQL;
		CREATE TABLE CLTLIST AS
		SELECT 	DISTINCT PROGRAM_ID, QL_CLIENT_ID, 
				CLIENT_LEVEL_1, CLIENT_LEVEL_2, CLIENT_LEVEL_3
		FROM &CLIENT_DRUG_TABLE. 
		WHERE TODAY() BETWEEN DATEPART(EFFECTIVE_DT) AND DATEPART(EXPIRATION_DT)
			  AND PROGRAM_ID = &PROGRAM_ID.;
		QUIT;

		PROC SQL;
		 CREATE TABLE CLTLIST_GID AS
		 SELECT DISTINCT CLTDRG.*, ALGN.ALGN_LVL_GID_KEY, ALGN.CUST_NM
		 FROM CLTLIST CLTDRG
		      ,&DSS_CLIN..V_ALGN_LVL_DENORM ALGN
		 WHERE  &HIERARCHY_CONS.
		 ORDER BY ALGN_LVL_GID_KEY;
		QUIT;

		DATA &ORA_TMP..CLT_LST_&INITIATIVE_ID._&ADJ_ENGINE.;
			SET CLTLIST_GID;
		RUN;

		PROC SQL;
			CONNECT TO ORACLE(PATH=&GOLD PRESERVE_COMMENTS);
			EXECUTE
			(
				CREATE TABLE &ORA_TMP..TMP_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE. AS
				SELECT 	/* + ORDERED */
						 CLTDRG.ALGN_LVL_GID_KEY
						,CLTDRG.CUST_NM 
						,CLTDRG.CLIENT_LEVEL_1
						,CLTDRG.CLIENT_LEVEL_2
						,CLTDRG.CLIENT_LEVEL_3
						,CLAIM.PAYER_ID
						,CLAIM.MBR_GID
						,CLAIM.PHMCY_GID
						,CLAIM.PRCTR_GID
						,CLAIM.DRUG_GID
						,CLAIM.DSPND_DATE
						,CLAIM.BATCH_DATE
						,CLAIM.AMT_COPAY 
						,CLAIM.BNFT_LVL_CODE
						,CLAIM.PTNT_BRTH_DT
						,CLAIM.CLAIM_TYPE
						&REFILL_QTY.
				FROM 	
						&ORA_TMP..CLT_LST_&INITIATIVE_ID._&ADJ_ENGINE. CLTDRG
						,&DSS_CLIN..V_CLAIM_CORE_PAID CLAIM
		                &REFIL_QTY_CLM_TABLE.
						,&CLIENT_DRUG_TABLE2.
     
				WHERE	CLTDRG.PROGRAM_ID = &PROGRAM_ID.
					AND CLAIM.ALGN_LVL_GID = CLTDRG.ALGN_LVL_GID_KEY 
					AND	CLAIM.DSPND_DATE BETWEEN &CLM_BEGIN_DT_CONV. AND &CLM_END_DT_CONV. 
					AND CLAIM.BATCH_DATE IS NOT NULL
					AND	CLAIM.SRC_SYS_CD = %BQUOTE('&SRC_SYS_CD')
					AND CLAIM.CLAIM_WSHD_CD IN ('P', 'W')
					AND (CLAIM.MBR_SUFFX_FLG = 'Y' OR CLAIM.MBR_SUFFX_FLG IS NULL)
					AND CLAIM.QL_VOID_IND <= 0
					&REFIL_QTY_CLM_TABLE_CONS.
					AND CLAIM.DRUG_GID = CLTDRG2.DRUG_GID

				ORDER BY PAYER_ID, MBR_GID
			) BY ORACLE;
		DISCONNECT FROM ORACLE;
		QUIT;

		DATA _NULL_;
			CALL SYMPUT ('END_TM',PUT(%SYSFUNC(DATETIME()), DATETIME23.));
		RUN;
		%PUT NOTE: PULL FROM CLAIMS END TIME - &END_TM;


proc sql;
CONNECT TO ORACLE(PATH=&GOLD);
create table data_res.mail_claims_cltdrg_&adj_engine. as
SELECT * FROM CONNECTION TO ORACLE
      (
SELECT %bquote(/)%bquote(*) +ORDERED parallel(claim,16) %bquote(*)%bquote(/)
        %BQUOTE('&ADJ_ENGINE') AS ADJ_ENGINE,
         clt.algn_lvl_gid_key,
         clt.ql_client_id AS client_id,
         clt.cust_nm AS client_nm,
         clt.client_level_1,
         clt.client_level_2,
         clt.client_level_3,                           /* claim.QL_BNFCY_ID,*/
         claim.payer_id,
         claim.mbr_gid,
         claim.drug_gid,
         claim.phmcy_gid,
         claim.prctr_gid,
         claim.dspnd_date,
         claim.batch_date,
         claim.amt_copay AS member_cost_at,
         claim.bnft_lvl_code,
         SUBSTR (claim.ptnt_brth_dt, 1, 10) AS birth_dt,
         SUBSTR (claim.dspnd_date, 1, 10) AS last_fill_dt,
         claim.claim_type AS rx_count_qy,
         0 AS refill_fill_qy,
         0 AS ltr_rule_seq_nb,
         CLAIM.RX_NBR AS RX_NB,
         CLAIM.UNIT_QTY AS DISPENSED_QY,
         CAST (CLAIM.DAYS_SPLY AS CHAR (4)) AS DAY_SUPPLY_QY,
         CLAIM.FRMLY_GID
  FROM   DSS_CLIN.V_CLAIM_CORE_PAID CLAIM,
            DSS_HERC.CLT_LST_8301_RE CLT
WHERE    	 CLAIM.DSPND_DATE BETWEEN &MAIL_BGN_EDW_DT AND &MAIL_END_EDW_DT 
         AND clt.ALGN_LVL_GID_KEY = claim.ALGN_LVL_GID
         AND clt.payer_id = claim.payer_id
         AND claim.batch_date IS NOT NULL
         AND CLAIM.SRC_SYS_CD = 'R'
         AND claim.claim_wshd_cd IN ('P', 'W')
         AND CLAIM.PAYER_ID &PAYER_ID_CONS.
);
DISCONNECT FROM ORACLE;
quit;




		PROC SQL;
			SELECT COUNT(*) INTO :EDW_CLAIM_CNT
			FROM &ORA_TMP..TMP_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE.;
		QUIT;

		%PUT NOTE: CLAIM COUNT FROM TMP_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE. - &EDW_CLAIM_CNT;

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
				CREATE TABLE &ORA_TMP..TMP1_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE. AS
				SELECT 	/* + ORDERED */
						%BQUOTE('&ADJ_ENGINE') AS ADJ_ENGINE
						,CLAIM.ALGN_LVL_GID_KEY
						,CLTDRG.QL_CLIENT_ID AS CLIENT_ID
						,CLAIM.CUST_NM 
						,CLTDRG.CLIENT_LEVEL_1
						,CLTDRG.CLIENT_LEVEL_2
						,CLTDRG.CLIENT_LEVEL_3
						,PRCTR.PRCTR_ID AS PRACTITIONER_ID 
						,PRCTR.QL_PRSCR_ID AS PRESCRIBER_ID
						,PRCTR.ENTITY_IND
						,PRCTR.DEGR_1_CD
						,PHMCY.NABP_CODE_6
						,CLAIM.PAYER_ID
						,CLAIM.MBR_GID
						,CLAIM.PHMCY_GID
						,CLAIM.PRCTR_GID
						,CLAIM.DSPND_DATE
						,CLAIM.BATCH_DATE
						,CLAIM.AMT_COPAY AS MEMBER_COST_AT
						,CLAIM.BNFT_LVL_CODE
						,SUBSTR(CLAIM.PTNT_BRTH_DT, 1, 10) AS BIRTH_DT
						,SUBSTR(CLAIM.DSPND_DATE, 1, 10) AS LAST_FILL_DT
						,CLAIM.CLAIM_TYPE AS RX_COUNT_QY
						,DRUG.DRUG_GID
						,DRUG.GCN_CODE 
						,DRUG.GCN_NBR 
						,CAST(DRUG.QL_NHU_TYPE_CD AS INT) AS NHU_TYPE_CD
						,CAST(DRUG.NDC_CODE AS INT) AS DRUG_NDC_ID
						&SELECT_DRUG_SEQ.
						,DRUG.DSG_FORM AS DRUG_ABBR_DSG_NM
						,DRUG.BRAND_NAME AS DRUG_ABBR_PROD_NM
						,DRUG.STRGH_DESC AS DRUG_ABBR_STRG_NM
						,DRUG.QL_DRUG_BRND_CD as DRUG_BRAND_CD
						,CLAIM.REFILL_FILL_QY
						,0 AS LTR_RULE_SEQ_NB
				FROM 	
						&CLIENT_DRUG_TABLE.
						,&ORA_TMP..TMP_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE. CLAIM
						,&DSS_CLIN..V_DRUG_DENORM DRUG
						,&DSS_CLIN..V_PRCTR_DENORM PRCTR
						,&DSS_CLIN..V_PHMCY_DENORM PHMCY       
				WHERE
						CLTDRG.PROGRAM_ID = &PROGRAM_ID.
					AND CURRENT_TIMESTAMP BETWEEN CLTDRG.EFFECTIVE_DT AND CLTDRG.EXPIRATION_DT
					AND LTRIM(RTRIM(CLTDRG.CLIENT_LEVEL_1)) = LTRIM(RTRIM(CLAIM.CLIENT_LEVEL_1))
					AND LTRIM(RTRIM(NVL(CLTDRG.CLIENT_LEVEL_2,'00'))) = LTRIM(RTRIM(NVL(CLAIM.CLIENT_LEVEL_2,'00')))
					AND LTRIM(RTRIM(NVL(CLTDRG.CLIENT_LEVEL_3,'00'))) = LTRIM(RTRIM(NVL(CLAIM.CLIENT_LEVEL_3,'00')))
					AND CLAIM.DRUG_GID = CLTDRG.DRUG_GID
					AND CLAIM.PRCTR_GID = PRCTR.PRCTR_GID
					&PRSCR_CONS.
					AND CLAIM.PHMCY_GID = PHMCY.PHMCY_GID
					AND CLAIM.DRUG_GID = DRUG.DRUG_GID
					&DS_STRING_RX_RE.

				ORDER BY PAYER_ID, MBR_GID
			) BY ORACLE;
		DISCONNECT FROM ORACLE;
		QUIT;

		PROC SQL;
			SELECT COUNT(*) INTO :EDW_CLAIM_CNT
			FROM &ORA_TMP..TMP1_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE.;
		QUIT;

		%PUT NOTE: CLAIM COUNT FROM TMP1_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE. - &EDW_CLAIM_CNT;

/*Added MAX(LAST_FILL_DT) for correction of MBR_REUSE_RISK_FLG rule. MB 3-2013*/
			PROC SQL;
			CONNECT TO ORACLE(PATH=&GOLD PRESERVE_COMMENTS);
			EXECUTE
			(
				CREATE TABLE &ORA_TMP..TMP2_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE. AS
			     SELECT PAYER_ID, MBR_GID, MAX(LAST_FILL_DT) as LAST_FILL_DT, COUNT(*) AS CNT /*<-- MB 3-2013*/
				 FROM &ORA_TMP..TMP1_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE.
				 GROUP BY PAYER_ID, MBR_GID
				 ORDER BY PAYER_ID, MBR_GID
			) BY ORACLE;
			DISCONNECT FROM ORACLE;
			QUIT;

			PROC SQL;
				SELECT COUNT(*) INTO :EDW_CLAIM_CNT2
				FROM &ORA_TMP..TMP2_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE.
			QUIT;
			%PUT "NOTE: CLAIM COUNT FROM &ORA_TMP..TMP2_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE. - &EDW_CLAIM_CNT2";
		
			%IF &EDW_CLAIM_CNT2. >= 25000000 
			%THEN 
				%LET AVOID_IX_LKP = %STR(/1);
			%ELSE 
				%LET AVOID_IX_LKP = %STR();

			DATA _NULL_;
				CALL SYMPUT ('START_TM',PUT(%SYSFUNC(DATETIME()), DATETIME23.));
			RUN;
			%PUT NOTE: JOIN CLAIMS WITH MBR START TIME - &START_TM;


/*-----------------------------------------------------------------------
|26FEB2009 - Hercules Version  2.1.2.02
|G. DUDLEY - ADDED THE "MBR_REUSE_RISK_FLG" TO THE QUERY TO EXTRACT MEMBER
|            DEMOGRAPHICS FROM THE V-MBR VIEW.  THIS WILL BE USED TO EXCLUDE 
|            SUSPECT MEMBERS DUE TO POSSIBLE MEBER ID REUSE.
+------------------------------------------------------------------------SASDOC**/
			PROC SQL;
				CONNECT TO ORACLE(PATH=&GOLD PRESERVE_COMMENTS);
				EXECUTE
				(
					CREATE TABLE &ORA_TMP..TMP3_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE. AS
					SELECT  
			                CLAIM.*
							,MBR.QL_BNFCY_ID AS PT_BENEFICIARY_ID
							,MBR.QL_CARDHLDR_BNFCY_ID AS CDH_BENEFICIARY_ID
							,MBR.MBR_ID AS MBR_ID
							,MBR.MBR_FIRST_NM
							,MBR.MBR_LAST_NM				
							,MBR.ADDR_LINE1_TXT			
							,MBR.ADDR_LINE2_TXT			
							,MBR.ADDR_CITY_NM				
							,MBR.ADDR_ST_CD				
							,MBR.ADDR_ZIP_CD
              ,MBR.SRC_SUFFX_PRSN_CD	
/*Added missing PII-key, below. MB 3-2013*/
              ,MBR.MBR_BRTH_DT as M_DOB
              ,MBR.MBR_GNDR_GID
              ,MBR.REL_CODE
					FROM 	
							&ORA_TMP..TMP2_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE. CLAIM     
							,&DSS_CLIN..V_MBR MBR
					WHERE
							MBR.PAYER_ID&AVOID_IX_LKP. &PAYER_ID_CONS.
						AND CLAIM.PAYER_ID&AVOID_IX_LKP. = MBR.PAYER_ID&AVOID_IX_LKP.
						AND CLAIM.MBR_GID&AVOID_IX_LKP. = MBR.MBR_GID&AVOID_IX_LKP.
/*Corrected MBR_REUSE_RISK_FLG rule. MB 3-2013*/
            AND ((MBR.MBR_REUSE_RISK_FLG IS NULL) or
            (MBR.MBR_REUSE_RISK_FLG ='Y' and TO_DATE(CLAIM.LAST_FILL_DT,'YYYY-MM-DD') > MBR.MBR_REUSE_LAST_UPDT_DT))
				) BY ORACLE;
			DISCONNECT FROM ORACLE;
			QUIT;

			PROC SQL;
				SELECT COUNT(*) INTO :EDW_CLAIM_CNT2
				FROM &ORA_TMP..TMP3_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE.
			QUIT;
			%PUT "NOTE: CLAIM COUNT FROM &ORA_TMP..TMP3_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE. - &EDW_CLAIM_CNT2";


		/** PERFORM PARTICIPANT EXCLUSIONS, IF ANY, BASED ON PROGRAM_ID BY GOING AGAINST
			PARTICIPANT_EXCLUSION TABLE IN 
			/DATA/%LOWCASE(SAS&SYSMODE.1/HERCULES/PARTICIPANT_EXCLUSIONS DIRECTORY 
			THIS IS DONE BY CALLING MACRO PARTICIPANT_EXCLUSIONS **/

			%LOAD_PARTICIPANT_EXCLUSION;
			%PARTICIPANT_EXCLUSIONS(TBL_NAME_IN = &ORA_TMP..TMP3_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE.);


			PROC SQL;
				CONNECT TO ORACLE(PATH=&GOLD PRESERVE_COMMENTS);
				EXECUTE
				(
					CREATE TABLE &ORA_TMP..CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE. AS
					SELECT  
			                CLAIM.*
							,MBR.PT_BENEFICIARY_ID
							,MBR.CDH_BENEFICIARY_ID
							,MBR.MBR_ID
							,MBR.MBR_FIRST_NM
							,MBR.MBR_LAST_NM				
							,MBR.ADDR_LINE1_TXT			
							,MBR.ADDR_LINE2_TXT			
							,MBR.ADDR_CITY_NM				
							,MBR.ADDR_ST_CD				
							,MBR.ADDR_ZIP_CD
              ,MBR.SRC_SUFFX_PRSN_CD	
/*Added missing PII-key, below. MB 3-2013*/
              ,MBR.M_DOB
              ,MBR.MBR_GNDR_GID
              ,MBR.REL_CODE
					FROM 	
							&ORA_TMP..TMP1_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE. CLAIM     
							,&ORA_TMP..TMP3_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE. MBR
					WHERE
						    CLAIM.MBR_GID = MBR.MBR_GID
						AND CLAIM.PAYER_ID = MBR.PAYER_ID
					ORDER BY
							 CLAIM.MBR_GID
						    ,CLAIM.ALGN_LVL_GID_KEY
							,CLAIM.DRUG_GID
							,CLAIM.PHMCY_GID
							,CLAIM.PRCTR_GID
				) BY ORACLE;
			DISCONNECT FROM ORACLE;
			QUIT;

			PROC SQL;
				SELECT COUNT(*) INTO :EDW_CLAIM_CNT2
				FROM &ORA_TMP..CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE.
			QUIT;
			%PUT "NOTE: FINAL CLAIM COUNT FROM &ORA_TMP..CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE. - &EDW_CLAIM_CNT2";


			DATA _NULL_;
				CALL SYMPUT ('END_TM',PUT(%SYSFUNC(DATETIME()), DATETIME23.));
			RUN;
			%PUT NOTE: JOIN CLAIMS WITH MBR END TIME - &END_TM;

		%END;

		%ELSE %DO;

			FILENAME MYMAIL EMAIL 'QCPAP020@TSTSAS1';
		   		DATA _NULL_;
		     		FILE MYMAIL
		         	TO=(&EMAIL_USR)
		         	SUBJECT="CLIENT SPECIFIC EXTERNAL DRUG LIST" ;
					PUT 'HI,' ;
		     		PUT / "THIS IS AN AUTOMATICALLY GENERATED MESSAGE TO INFORM YOU THAT CLAIMS_PULL_EDW MACRO FOR CLIENT SPECIFIC DRUG LIST RETURNED 0 ROWS FOR ADJ &ADJ_ENGINE.";
					PUT / 'PLEASE LET US KNOW OF ANY QUESTIONS.';
		    		PUT / 'THANKS,';
		     		PUT / 'HERCULES PRODUCTION SUPPORTS';
		   		RUN;

/*			%LET ERR_FL = 1;*/
/**/
/*			%ON_ERROR( ACTION=ABORT*/
/*	          ,EM_TO=&PRIMARY_PROGRAMMER_EMAIL*/
/*	          ,EM_SUBJECT=HCE SUPPORT: NOTIFICATION OF ABEND INITIATIVE_ID &INITIATIVE_ID*/
/*	          ,EM_MSG=%STR(CLAIMS_PULL_EDW MACRO RETURNED 0 ROWS FOR ADJ &ADJ_ENGINE. */
/*                           SO THE EXECUTION OF THE MAILING PROGRAM HAS BEEN FORCED TO ABORT));*/

		%END;

		%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..TMP_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE.);
		%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..TMP1_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE.);
		%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..TMP2_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE.);
		%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..TMP3_CLM_CLTDRG_LST_&INITIATIVE_ID._&ADJ_ENGINE.);
		%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..CLT_LST_&INITIATIVE_ID._&ADJ_ENGINE.);

    %END;

	%MEND EDW_CLAIMS;

	%IF &RX_ADJ. = 1 AND %SYSFUNC(EXIST(&CLIENT_DRUG_TABLE_RX.)) %THEN %DO;
		%LET SRC_SYS_CD = %STR(X);
		%LET PAYER_ID_CONS = %STR(< 100000);
		%LET REFILL_QTY = %STR(,VCLM.SBMTD_REFIL_ATHZD AS REFILL_FILL_QY);
		%LET CARRIER_FIELD = CLIENT_LEVEL_1;
		%EDW_CLAIMS(ADJ_ENGINE = RX);
	%END;

	%IF &RE_ADJ. = 1 %SYSFUNC(EXIST(&CLIENT_DRUG_TABLE_RE.)) %THEN %DO;
		%LET SRC_SYS_CD = %STR(R);
		%LET PAYER_ID_CONS = %STR(BETWEEN 500000 AND 2000000);
		%LET REFILL_QTY = %STR(,VCLM.ATHZD_REFIL_QTY AS REFILL_FILL_QY);
		%LET CARRIER_FIELD = CLIENT_LEVEL_2;
		%EDW_CLAIMS(ADJ_ENGINE = RE);
	%END;

%MEND CLAIMS_PULL_EDW_CLTDRG;
