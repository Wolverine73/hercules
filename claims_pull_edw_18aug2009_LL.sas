
	/*HEADER---------------------------------------------------------------------------------------------------------
	|MACRO: 		CLAIMS_PULL_EDW.SAS
	|
	|PURPOSE:   EXTRACT CLAIMS FROM EDW FOR RECAP AND RXCLAIM ADJUDICATIONS 		
	|
	|INPUT:			
	|
	|LOGIC:         					
	|						
	|OUTPUT:			
	|+-----------------------------------------------------------------------------------------------------------------
	|HISTORY: SR 01OCT2008 - Hercules Version  2.1.2.01
	|26FEB2009 - Hercules Version  2.1.2.02
	|G. DUDLEY - ADDED THE "MBR_REUSE_RISK_FLG" TO THE QUERY TO EXTRACT MEMBER
	|            DEMOGRAPHICS FROM THE V-MBR VIEW.  THIS WILL BE USED TO EXCLUDE 
	|            SUSPECT MEMBERS DUE TO POSSIBLE MEBER ID REUSE.
	|G. DUDLEY - CHANGED THE FORMAT OF DATE MACRO VARIABLE USED IN ORACLE QUERIES
	+-----------------------------------------------------------------------------------------------------------HEADER*/
	
	/********************** EXAMPLE CALL *******************************/

	*SASDOC--------------------------------------------------------------------------
	|26FEB2009 - Hercules Version  2.1.2.02
	|G. DUDLEY - REMOVED THE MACRO PARAMETERS CLM_BEGIN_DT = %STR(&CLAIM_BEGIN_DT)
	|            AND CLM_END_DT = %STR(&CLAIM_END_DT)
	+------------------------------------------------------------------------SASDOC*;

	   %MACRO CLAIMS_PULL_EDW_18AUG2009(DRUG_NDC_TABLE_RX = &ORA_TMP..&TABLE_PREFIX._NDC_RX,
						   				DRUG_NDC_TABLE_RE = &ORA_TMP..&TABLE_PREFIX._NDC_RE, 
						   				DRUG_RVW_DATES_TABLE = &ORA_TMP..&TABLE_PREFIX._RVW_DATES,
						   				RESOLVE_CLIENT_TABLE_RX = &ORA_TMP..&TABLE_PREFIX._RX ,
						   				RESOLVE_CLIENT_TABLE_RE = &ORA_TMP..&TABLE_PREFIX._RE);

	   OPTIONS MPRINT MPRINTNEST MLOGIC MLOGICNEST SYMBOLGEN SOURCE2;

	  %MACRO EDW_CLAIMS(ADJ_ENGINE=);
	  *SASDOC--------------------------------------------------------------------------
	  |21JUL2009 - Hercules Version  2.1.2.03
	  |G. DUDLEY - Added coding to choose which NDC table to use based on whether 
	  |            Proactive Refill - Adj RE is executing
	  +------------------------------------------------------------------------SASDOC*;

	    %IF &ADJ_ENGINE. = RE AND &PROGRAM_ID = 72 %THEN %DO;
	      %LET DRUG_NDC_TABLE_RE = &ORA_TMP..&TABLE_PREFIX._NDC_TBL_RE72;
	    %END;

	  *SASDOC--------------------------------------------------------------------------
	  |26FEB2009 - Hercules Version  2.1.2.02
	  |G. DUDLEY - CHANGED THE FORMAT OF DATE MACRO VARIABLE USED IN ORACLE QUERIES
	  +------------------------------------------------------------------------SASDOC*;

	  		/** DATE MANIPULATIONS FOR ORACLE **/
	      DATA _NULL_;
	  		CALL SYMPUT('CLM_BEGIN_DT_CONV', "TO_DATE('" ||"&CLM_BEGIN_DT" || "','YYYY-MM-DD')" );
	  		CALL SYMPUT('CLM_END_DT_CONV', "TO_DATE('" || "&CLM_END_DT" || "','YYYY-MM-DD')" );

	  		CALL SYMPUT('CLM_BEGIN_DT_PLUS_1WK', "TO_DATE('" ||PUT(INTNX('WEEK',INPUT("&CLM_BEGIN_DT",YYMMDD10.),-1,'BEGIN'),YYMMDD10.) || "','YYYY-MM-DD')" );
	  		CALL SYMPUT('CLM_END_DT_PLUS_1WK', "TO_DATE('" || PUT(INTNX('WEEK',INPUT("&CLM_END_DT",YYMMDD10.),+1,'END'),YYMMDD10.) || "','YYYY-MM-DD')" );
	      RUN;

	  		%IF %SYSFUNC(EXIST(&DRUG_RVW_DATES_TABLE.)) AND
	  	        %SYSFUNC(EXIST(&&DRUG_NDC_TABLE_&ADJ_ENGINE)) %THEN
				%DO; 
	  			%LET CLM_BEGIN_DT_CONV     = %STR(RVWDT.CLAIM_BEGIN_DT); 
	  			%LET CLM_END_DT_CONV       = %STR(RVWDT.CLAIM_END_DT);
	  			%LET CLM_BEGIN_DT_PLUS_1WK = %STR(RVWDT.CLAIM_BEGIN_DT - 7);
	  			%LET CLM_END_DT_PLUS_1WK   = %STR(RVWDT.CLAIM_END_DT + 7);
	  			%LET RVW_DATES_TABLE       = %STR(,&DRUG_RVW_DATES_TABLE. RVWDT);
	  			%LET RVW_DATES_CONS        = %STR(AND NDC.DRG_GROUP_SEQ_NB   = RVWDT.DRG_GROUP_SEQ_NB
	  			                                  AND NDC.DRG_SUB_GRP_SEQ_NB = RVWDT.DRG_SUB_GRP_SEQ_NB);
	  			%END;
	  		%ELSE %DO;
	  		  %LET RVW_DATES_TABLE = %STR();
	  		  %LET RVW_DATES_CONS  = %STR();
	  		%END;

	  		%PUT NOTE: CLM_BEGIN_DT_CONV     = &CLM_BEGIN_DT_CONV;
	  		%PUT NOTE: CLM_END_DT_CONV       = &CLM_END_DT_CONV;
	  		%PUT NOTE: CLM_BEGIN_DT_PLUS_1WK = &CLM_BEGIN_DT_PLUS_1WK;
	  		%PUT NOTE: CLM_END_DT_PLUS_1WK   = &CLM_END_DT_PLUS_1WK;

	  		/** CONSTRAINTS BASED ON DRUG SET-UP **/

	  		PROC SQL NOPRINT;
	  		 SELECT DRG_DEFINITION_CD, DFL_CLT_INC_EXU_IN
	  		 INTO :DRG_DEFINITION_CD, :RESOLVE_CLIENT_EXCLUDE_FLAG

	  		 FROM &HERCULES..TINITIATIVE INIT,
	  		      &HERCULES..TPROGRAM_TASK PGMTASK
	  		 WHERE INIT.INITIATIVE_ID = &INITIATIVE_ID.
	  		   AND INIT.PROGRAM_ID    = PGMTASK.PROGRAM_ID
	  		   AND INIT.TASK_ID       = PGMTASK.TASK_ID;
	  		QUIT;
	  		
	  		%PUT NOTE: DRG_DEFINITION_CD           = &DRG_DEFINITION_CD.;
	  		%PUT NOTE: RESOLVE_CLIENT_EXCLUDE_FLAG = &RESOLVE_CLIENT_EXCLUDE_FLAG.;
	  		%PUT NOTE: DRUG_NDC_TABLE_ADJ_ENGINE   = &&DRUG_NDC_TABLE_&ADJ_ENGINE;

	  		%IF %SYSFUNC(EXIST(&&DRUG_NDC_TABLE_&ADJ_ENGINE)) AND &DRG_DEFINITION_CD. = 2 %THEN

			%DO;
	  			%LET DRUG_NDC_TABLE  = %STR(,&&DRUG_NDC_TABLE_&ADJ_ENGINE NDC &RVW_DATES_TABLE.);
	  			%LET DRUG_CONS       = %STR(AND CLAIM.DRUG_GID = NDC.DRUG_GID &RVW_DATES_CONS.); 
	  			%LET SELECT_DRUG_SEQ = %STR(,NDC.DRUG_CATEGORY_ID, NDC.GPI_GROUP, NDC.GPI_CLASS);
	  		%END;

	  		%ELSE %IF NOT %SYSFUNC(EXIST(&&DRUG_NDC_TABLE_&ADJ_ENGINE)) AND &DRG_DEFINITION_CD. = 2 %THEN
			%DO;
	  		 %LET DRUG_NDC_TABLE  = %STR();
	  		 %LET DRUG_CONS       = %STR();
	  		 %LET SELECT_DRUG_SEQ = %STR(,59 AS DRUG_CATEGORY_ID, '  ' AS GPI_GROUP, '  ' AS GPI_CLASS);
	  		%END;

	  		%ELSE %IF %SYSFUNC(EXIST(&&DRUG_NDC_TABLE_&ADJ_ENGINE)) %THEN
			%DO;
	  		 %LET DRUG_NDC_TABLE  = %STR(,&&DRUG_NDC_TABLE_&ADJ_ENGINE NDC &RVW_DATES_TABLE.); 
	  		 %LET DRUG_CONS       = %STR(AND CLAIM.DRUG_GID = NDC.DRUG_GID &RVW_DATES_CONS.); 
	  		 %LET SELECT_DRUG_SEQ = %STR(,NDC.DRG_GROUP_SEQ_NB, NDC.DRG_SUB_GRP_SEQ_NB);
	  		%END;

	  		%ELSE %DO;
	  		 %LET DRUG_NDC_TABLE  = %STR();
	  		 %LET DRUG_CONS       = %STR();
	  		 %LET SELECT_DRUG_SEQ = %STR(,1 AS DRG_GROUP_SEQ_NB, 1 AS DRG_SUB_GRP_SEQ_NB);
	  		%END;

	  	    PROC SQL;
	  		  SELECT TRGT_RECIPIENT_CD INTO :TRGT_RECIPIENT_CD
	  		  FROM HERCULES.TPROGRAM_TASK 
	  		  WHERE PROGRAM_ID = &PROGRAM_ID. AND TASK_ID = &TASK_ID.;
	  		QUIT;

	  		%IF &TRGT_RECIPIENT_CD EQ 1 OR &TRGT_RECIPIENT_CD EQ 4 %THEN
			%DO;
	  		  %LET PRSCR_CONS = %STR();
	  		%END;
	  		%ELSE %DO;
	  		  %LET PRSCR_CONS = %STR(AND PRCTR.REC_SRC_FLG = 0
	  							     AND PRCTR.PRCTR_ID_TYP_CD IN ('DH', 'FW', 'NP'));
	  		%END;

	  		/** CONSTRAINTS BASED ON CLIENT SET-UP **/

	  		%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..ALGN_LVL_LIST_&INITIATIVE_ID._&ADJ_ENGINE.);

	  		%IF %SYSFUNC(EXIST(&&RESOLVE_CLIENT_TABLE_&ADJ_ENGINE)) %THEN
			 %DO;
	  		   %IF &RESOLVE_CLIENT_EXCLUDE_FLAG = 1 %THEN

				%DO;
	  			 %LET CLT_JOIN      = %STR(LEFT JOIN);
	  			 %LET CLT_JOIN_CONS = %STR(AND B.ALGN_LVL_GID_KEY IS NULL);
	  		    %END;
	  			%ELSE %DO;
	  			  %LET CLT_JOIN      = %STR(INNER JOIN);
	  			  %LET CLT_JOIN_CONS = %STR();
	  			%END;

	  			PROC SQL NOPRINT;
	  				CONNECT TO ORACLE(PATH = &GOLD );
	  				CREATE TABLE DATA_RES.ALGN_LVL_LIST_&INITIATIVE_ID._&ADJ_ENGINE. AS
	  				SELECT * FROM CONNECTION TO ORACLE
	  				( 
	  				SELECT DISTINCT A.ALGN_LVL_GID_KEY &HIERARCHY_LIST.
	 						   	   ,A.QL_CLNT_ID AS QL_CLIENT_ID, A.PAYER_ID
	  							   ,A.CUST_NM AS CLIENT_NM

	  			    FROM DSS_CLIN.V_ALGN_LVL_DENORM A &CLT_JOIN.
	  				&&RESOLVE_CLIENT_TABLE_&ADJ_ENGINE B
	  				ON A.ALGN_LVL_GID_KEY = B.ALGN_LVL_GID_KEY
	  				WHERE A.SRC_SYS_CD = %BQUOTE('&SRC_SYS_CD')
	  				AND SYSDATE BETWEEN A.ALGN_GRP_EFF_DT AND A.ALGN_GRP_END_DT
	  				&CLT_JOIN_CONS.
	  				ORDER BY A.ALGN_LVL_GID_KEY);
	  			    DISCONNECT FROM ORACLE;
	  			QUIT;
	  		%END;
	  		%ELSE %DO;
	  			PROC SQL NOPRINT;
	  				CONNECT TO ORACLE(PATH = &GOLD);
	  				CREATE TABLE DATA_RES.ALGN_LVL_LIST_&INITIATIVE_ID._&ADJ_ENGINE. AS
	  				SELECT * FROM CONNECTION TO ORACLE
	  				( 
	  				SELECT DISTINCT A.ALGN_LVL_GID_KEY &HIERARCHY_LIST.,
	  						   	    A.QL_CLNT_ID AS QL_CLIENT_ID, A.PAYER_ID,
	  							    A.CUST_NM AS CLIENT_NM

	  			    FROM DSS_CLIN.V_ALGN_LVL_DENORM A
	  				WHERE A.SRC_SYS_CD = %BQUOTE('&SRC_SYS_CD')
	  				AND SYSDATE BETWEEN A.ALGN_GRP_EFF_DT AND A.ALGN_GRP_END_DT
	  				ORDER BY A.ALGN_LVL_GID_KEY);
	  			    DISCONNECT FROM ORACLE;
	  			QUIT;
	  		%END;
	  		PROC SQL;
	  		  CREATE TABLE &ORA_TMP..ALGN_LVL_LIST_&INITIATIVE_ID._&ADJ_ENGINE. AS
	  		  SELECT *
	  		  FROM DATA_RES.ALGN_LVL_LIST_&INITIATIVE_ID._&ADJ_ENGINE.;
	  		  DROP TABLE DATA_RES.ALGN_LVL_LIST_&INITIATIVE_ID._&ADJ_ENGINE.;
	  		QUIT;

	  		%LET CLIENT_TABLE = %STR(&ORA_TMP..ALGN_LVL_LIST_&INITIATIVE_ID._&ADJ_ENGINE. CLT);

	  		/** IF REFILL_FILL_QTY IS POPULATED IN TFILE AND TFILE_FIELD FOR 
	  		    THE INITIATIVE THEN JOIN AGAINST V_CLAIM AND OBTAIN 
	  		    SBMTD_REFIL_ATHZD (RX) OR ATHZD_REFIL_QTY (RE) AS REFILL_FILL_QTY 
	  		    OTHERWISE LEAVE REFILL_FILL_QTY AS NULL  **/

	  			PROC SQL NOPRINT;
	  			 SELECT COUNT(*) INTO : REFILL_FILL_QTY

	  			 FROM &HERCULES..TFILE_FIELD AS A,
	  			      &HERCULES..TFIELD_DESCRIPTION AS B,
	  			   	  &HERCULES..TPHASE_RVR_FILE AS C
	  			 WHERE INITIATIVE_ID = &INITIATIVE_ID
	  			 AND PHASE_SEQ_NB = &PHASE_SEQ_NB
	  			 AND A.FILE_ID    = C.FILE_ID
	  			 AND A.FIELD_ID   = B.FIELD_ID
	  			 AND LEFT(TRIM(FIELD_NM)) IN ('REFILL_FILL_QY');
	  			 QUIT;

	  			  %IF &REFILL_FILL_QTY >= 1 %THEN

				   %DO;
	  				  %IF &ADJ_ENGINE. = RX %THEN

						%DO;
	  					 %LET REFIL_QTY_CLM_TABLE = %STR(,&DSS_CLIN..V_CLAIM VCLM);
	  					%END;
	  				    %ELSE %IF &ADJ_ENGINE. = RE %THEN

						%DO;
	  					 %LET REFIL_QTY_CLM_TABLE = %STR(,&DSS_CLIN..V_CLAIM_ALV VCLM);
	  				    %END;

	  					%LET REFIL_QTY_CLM_TABLE_CONS = %STR(AND CLAIM.CLAIM_GID = VCLM.CLAIM_GID
	  													 	 AND VCLM.BATCH_DATE BETWEEN &CLM_BEGIN_DT_PLUS_1WK. AND &CLM_END_DT_PLUS_1WK.);
	  				%END;

	  				%ELSE %DO;
	  					%LET REFIL_QTY_CLM_TABLE      = %STR();
	  					%LET REFIL_QTY_CLM_TABLE_CONS = %STR();
	  					%LET REFILL_QTY               = %STR(,0 AS REFILL_FILL_QY);
	  				%END;

			%include "/hercdev2/prg/hercules/macros/delivery_sys_check.sas";

	  		DATA _NULL_;
	  		  CALL SYMPUT ('START_TM', PUT(%SYSFUNC(DATETIME()), DATETIME23.));
	  		RUN;

	  		%PUT NOTE: PULL FROM CLAIMS - START TIME - &START_TM;

	  *SASDOC--------------------------------------------------------------------------
	  |G.O.D. 
	  |DROP ORACLE TABLES WERE COMMENTED OUT FOR UAT.  
	  +------------------------------------------------------------------------SASDOC*;

	  	%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.);
	  	%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..TMP_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.);
	  	%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..TMP2_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.);
	  	%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..TMP3_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.);

	  *SASDOC--------------------------------------------------------------------------
	  |24MAR2009 - Hercules Version  2.1.2.02
	  |GOD - REFILL_FILL_QTY COLUMN IS SET TO ZERO
	  |    - REARRANGED THE ORDER OF THE TABLES IN THE FROM STATEMENT AND THE
	  |      CONSTRAINTS IN THE "WHERE" STATEMENT TO TAKE ADVANTAGE OF THE "ORDERED"
	  |      ORACLE HINT
	  |24MAR2009 - Hercules Version  2.1.2.02
	  |NOTE: SAS BUG FIX
	  |WHEN USING ORACLE HINTS WITHIN A SAS MACRO, THE HINT IS TREATED AS A SAS
	  |COMMENT AND NOT PASS TO ORACLE VIA THE SQL PASS-THROUGH
	  |THE FIX IS TO USE CODING SIMILAR TO %str(/)%str(*)+ ordered %str(*)%str(/)
	  +------------------------------------------------------------------------SASDOC*;
	  *SASDOC--------------------------------------------------------------------------
	  |18AUG2009 - Hercules Version  2.1.2.02
	  |GOD - Split the query up into multiple steps
	  +------------------------------------------------------------------------SASDOC*;
	  *SASDOC--------------------------------------------------------------------------
	  |18AUG2009 - Hercules Version  2.1.2.02
	  |Extract Claims per Client
	  +------------------------------------------------------------------------SASDOC*;

	  		PROC SQL;
	  			CONNECT TO ORACLE(PATH = &GOLD PRESERVE_COMMENTS);
	  			CREATE TABLE target_claims AS
	  				SELECT * FROM CONNECTION TO ORACLE
	  				( 
	          SELECT %BQUOTE('&ADJ_ENGINE') AS ADJ_ENGINE,
	              clt.algn_lvl_gid_key, clt.ql_client_id AS client_id, 
	              clt.client_nm, clt.client_level_1, clt.client_level_2, 
	              clt.client_level_3, claim.payer_id, claim.mbr_gid,
	              claim.drug_gid, claim.phmcy_gid, claim.prctr_gid, 
	              claim.dspnd_date, claim.batch_date,
	              claim.amt_copay as member_cost_at, claim.bnft_lvl_code,
	              substr(claim.ptnt_brth_dt, 1, 10) as birth_dt,
	              substr(claim.dspnd_date, 1, 10) as last_fill_dt,
	              claim.claim_type AS rx_count_qy, 
	              0 as refill_fill_qy,
	              0 as ltr_rule_seq_nb

	              FROM &DSS_CLIN..V_CLAIM_CORE_PAID CLAIM, &CLIENT_TABLE.
	              WHERE CLAIM.DSPND_DATE BETWEEN &CLM_BEGIN_DT_CONV AND &CLM_END_DT_CONV 
	              AND CLT.CLIENT_LEVEL_1 <> 'GYY' AND CLT.CLIENT_LEVEL_1 <> 'D32' 
	              AND CLT.CLIENT_LEVEL_1 <> 'GFW' AND CLT.CLIENT_LEVEL_1 <> '19021' 
	              AND CLT.CLIENT_LEVEL_1 <> 'D69' AND clt.ALGN_LVL_GID_KEY = claim.ALGN_LVL_GID
	              AND clt.payer_id = claim.payer_id AND claim.batch_date IS NOT NULL
	              AND CLAIM.SRC_SYS_CD = %BQUOTE('&SRC_SYS_CD')
	              AND claim.claim_wshd_cd IN ('P', 'W'));
	          DISCONNECT FROM ORACLE;
	  		
	  			CONNECT TO ORACLE(PATH=&GOLD PRESERVE_COMMENTS);
	  			CREATE TABLE mail_claims AS
	  				SELECT * FROM CONNECTION TO ORACLE
	  				( 
	          SELECT %BQUOTE('&ADJ_ENGINE') AS ADJ_ENGINE,
	              clt.algn_lvl_gid_key, clt.ql_client_id as client_id, 
	              clt.client_nm, clt.client_level_1, clt.client_level_2, 
	              clt.client_level_3, claim.payer_id, claim.mbr_gid,
	              claim.drug_gid, claim.phmcy_gid, claim.prctr_gid, 
	              claim.dspnd_date, claim.batch_date,
	              claim.amt_copay AS member_cost_at, 
	              claim.bnft_lvl_code,
	              substr(claim.ptnt_brth_dt, 1, 10) as birth_dt,
	              substr(claim.dspnd_date, 1, 10) as last_fill_dt,
	              claim.claim_type AS rx_count_qy, 
	              0 as refill_fill_qy,
	              0 as ltr_rule_seq_nb

	              FROM &DSS_CLIN..V_CLAIM_CORE_PAID CLAIM, &CLIENT_TABLE.
	              WHERE CLAIM.DSPND_DATE BETWEEN &MAIL_BGN_EDW_DT AND &MAIL_END_EDW_DT 
	              AND CLT.CLIENT_LEVEL_1 <> 'GYY'
	              AND clt.ALGN_LVL_GID_KEY = claim.ALGN_LVL_GID
	              AND clt.payer_id = claim.payer_id
	              AND claim.batch_date IS NOT NULL
	              AND CLAIM.SRC_SYS_CD = %BQUOTE('&SRC_SYS_CD')
	              AND claim.claim_wshd_cd IN ('P', 'W'));
	          DISCONNECT FROM ORACLE;
	  		QUIT;

	   *SASDOC--------------------------------------------------------------------------
	  |18AUG2009 - Hercules Version  2.1.2.02
	  |Extract Drug
	  +------------------------------------------------------------------------SASDOC*;

	    	PROC SQL;
	  		  CONNECT TO ORACLE(PATH=&GOLD PRESERVE_COMMENTS);
	  		 	CREATE TABLE drug AS
	  		 	SELECT * FROM CONNECTION TO ORACLE
	  				( 
	          SELECT ndc.*,
	            NME.QL_BRND_NAM_CD as DRUG_BRAND_CD,
	            NME.QL_DRUG_ABBR_DSG_NM as DRUG_ABBR_DSG_NM,
	            NME.QL_DRUG_ABBR_PROD_NM as DRUG_ABBR_PROD_NM,
	            NME.QL_DRUG_ABBR_STRG_NM as DRUG_ABBR_STRG_NM

	          FROM &DSS_CLIN..V_DRUG_DENORM NME &DRUG_NDC_TABLE.
	          WHERE NDC.DRUG_GID = NME.DRUG_GID);
	          DISCONNECT FROM ORACLE;
	  		
	  		CREATE TABLE claim_drug as
	        SELECT * FROM target_claims claim, drug drug
	        where claim.drug_gid = drug.drug_gid
	        AND DRUG.DRUG_GID IS NOT NULL;
	  	   QUIT;

	  *SASDOC--------------------------------------------------------------------------
	  |18AUG2009 - Hercules Version  2.1.2.02
	  |Extract Phamarcy
	  +------------------------------------------------------------------------SASDOC*;

	  		PROC SQL;
	  		  CONNECT TO ORACLE(PATH = &GOLD PRESERVE_COMMENTS);
	  		  	CREATE TABLE phmcy AS
	  		  	SELECT * FROM CONNECTION TO ORACLE
	  				( 
	            SELECT phmcy.phmcy_gid, phmcy.nabp_code_6

	          FROM &DSS_CLIN..V_PHMCY_DENORM PHMCY);
	          DISCONNECT FROM ORACLE;
	  		
	          create table claims_phmcy as
	          select *

	          from claim_drug c, phmcy p
	          where c.phmcy_gid = p.phmcy_gid;
	       QUIT;

	  *SASDOC--------------------------------------------------------------------------
	  |18AUG2009 - Hercules Version  2.1.2.02
	  |Extract MOR claims and delete them from claims_phcmy
	  +------------------------------------------------------------------------SASDOC*;

	    proc sql;
	       create table morclaims as
	        select p.NABP_CODE_6,mc.mbr_gid
	          from mail_claims mc, phmcy p
	          where mc.phmcy_gid = p.phmcy_gid
	          and p.NABP_CODE_6 in ('482663', '146603', '032664', '012929', '398095', '459822',
                                    '032691', '147389', '458303', '100229');
	    
	        delete FROM claims_phmcy A
	          WHERE EXISTS (
	            SELECT 1 FROM morclaims B
	            WHERE A.mbr_gid = B.mbr_gid);
	      quit;

	  *SASDOC--------------------------------------------------------------------------
	  |18AUG2009 - Hercules Version  2.1.2.02
	  |Extract Practioner
	  +------------------------------------------------------------------------SASDOC*;

	       PROC SQL;
	        CREATE TABLE &ORA_TMP..TMP_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. AS
	        SELECT *
	        FROM claims_phmcy;
	      QUIT;

	  		DATA _NULL_;
	  			CALL SYMPUT ('END_TM', PUT(%SYSFUNC(DATETIME()), DATETIME23.));
	  		RUN;

	  		%PUT NOTE: PULL FROM CLAIMS END TIME - &END_TM;

	  		PROC SQL;
	  		  SELECT COUNT(*) INTO :EDW_CLAIM_CNT
	  		  FROM &ORA_TMP..TMP_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. ;
	  		QUIT;

	  		%PUT NOTE: CLAIM COUNT - &EDW_CLAIM_CNT;

	  		%IF &EDW_CLAIM_CNT. > 0 %THEN

			  %DO;
	  			PROC SQL;
	  			CONNECT TO ORACLE(PATH = &GOLD PRESERVE_COMMENTS);
	  			EXECUTE
	  			(
	  				CREATE TABLE &ORA_TMP..TMP2_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. AS
	  			     SELECT PAYER_ID, MBR_GID, COUNT(*) AS CNT
	  				 FROM &ORA_TMP..TMP_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.
	  				 GROUP BY PAYER_ID, MBR_GID
	  				 ORDER BY PAYER_ID, MBR_GID
	  			) BY ORACLE;
	  			DISCONNECT FROM ORACLE;
	  			
	  				SELECT COUNT(*) INTO :EDW_CLAIM_CNT2
	  				FROM &ORA_TMP..TMP2_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.
	  			QUIT;

	  			%PUT NOTE: CLAIM COUNT FOR DISTINCT MBR_GID+PAYER_ID - &EDW_CLAIM_CNT2;
	  		
	  			%IF &EDW_CLAIM_CNT2. >= 25000000 
	  			%THEN 
	  			  %LET AVOID_IX_LKP = %STR(/1);
	  			%ELSE 
	  			  %LET AVOID_IX_LKP = %STR();

	  			DATA _NULL_;
	  			  CALL SYMPUT ('START_TM', PUT(%SYSFUNC(DATETIME()), DATETIME23.));
	  			RUN;

	  			%PUT NOTE: JOIN CLAIMS WITH MBR START TIME - &START_TM;

	  *SASDOC--------------------------------------------------------------------------
	  |26FEB2009 - Hercules Version  2.1.2.02
	  |G. DUDLEY - ADDED THE "MBR_REUSE_RISK_FLG" TO THE QUERY TO EXTRACT MEMBER
	  |            DEMOGRAPHICS FROM THE V-MBR VIEW.  THIS WILL BE USED TO EXCLUDE 
	  |            SUSPECT MEMBERS DUE TO POSSIBLE MEBER ID REUSE.
	  +------------------------------------------------------------------------SASDOC*;

	  			PROC SQL;
	  				CONNECT TO ORACLE(PATH = &GOLD PRESERVE_COMMENTS);
	  				EXECUTE
	  				(
	  					CREATE TABLE &ORA_TMP..TMP3_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. AS
	  					SELECT CLAIM.*, MBR.QL_BNFCY_ID AS PT_BENEFICIARY_ID
	  					,MBR.QL_CARDHLDR_BNFCY_ID AS CDH_BENEFICIARY_ID
	  					,MBR.MBR_ID AS MBR_ID, MBR.MBR_FIRST_NM
	  					,MBR.MBR_LAST_NM, MBR.ADDR_LINE1_TXT			
	  					,MBR.ADDR_LINE2_TXT, MBR.ADDR_CITY_NM				
	  					,MBR.ADDR_ST_CD, MBR.ADDR_ZIP_CD	
	                	,MBR.SRC_SUFFX_PRSN_CD
	
	  					FROM 
	  					&ORA_TMP..TMP2_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. CLAIM     
	  					,&DSS_CLIN..V_MBR MBR
	  					WHERE
	  					MBR.PAYER_ID&AVOID_IX_LKP. &PAYER_ID_CONS.
	  					AND CLAIM.PAYER_ID&AVOID_IX_LKP. = MBR.PAYER_ID&AVOID_IX_LKP.
	  					AND CLAIM.MBR_GID&AVOID_IX_LKP.  = MBR.MBR_GID&AVOID_IX_LKP.
	                    AND MBR.MBR_REUSE_RISK_FLG IS NULL
	  				) BY ORACLE;
	  			DISCONNECT FROM ORACLE;
	  			
	  				CONNECT TO ORACLE(PATH = &GOLD PRESERVE_COMMENTS);
	  				EXECUTE
	  				(
	  					CREATE TABLE &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. AS
	  					SELECT CLAIM.*, MBR.PT_BENEFICIARY_ID
	  						   ,MBR.CDH_BENEFICIARY_ID, MBR.MBR_ID
	  						   ,MBR.MBR_FIRST_NM, MBR.MBR_LAST_NM				
	  						   ,MBR.ADDR_LINE1_TXT, MBR.ADDR_LINE2_TXT			
	  						   ,MBR.ADDR_CITY_NM, MBR.ADDR_ST_CD				
	  						   ,MBR.ADDR_ZIP_CD, MBR.SRC_SUFFX_PRSN_CD

	  					FROM 	
	  					&ORA_TMP..TMP_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. CLAIM     
	  					,&ORA_TMP..TMP3_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. MBR
	  					WHERE CLAIM.MBR_GID = MBR.MBR_GID AND CLAIM.PAYER_ID = MBR.PAYER_ID
	  					ORDER BY CLAIM.MBR_GID,  CLAIM.ALGN_LVL_GID_KEY
	  							,CLAIM.DRUG_GID, CLAIM.PHMCY_GID, CLAIM.PRCTR_GID
	  				) BY ORACLE;
	  			DISCONNECT FROM ORACLE;
	  			
	  			 SELECT COUNT(*) INTO :EDW_CLAIM_FINAL

	  			 FROM &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.
	  			QUIT;

	  			%PUT NOTE: CLAIM FINAL COUNT - &EDW_CLAIM_FINAL;

	  					/** LL 11/13/2012 **/

	            libname fref "/hercdev2/data/hercules/participant_exclusions/participant_exclusion_72.csv";

				%IF (fexist(fref)) %THEN
				%DO;
				%LOAD_PARTICIPANT_EXCLUSION;
				%END;

	  			DATA _NULL_;
	  			  CALL SYMPUT ('END_TM', PUT(%SYSFUNC(DATETIME()), DATETIME23.));
	  			RUN;
	  			%PUT NOTE: JOIN CLAIMS WITH MBR END TIME - &END_TM;

	  		%END;
	  		%ELSE %DO;

	  			%LET ERR_FL = 1;

	  			%ON_ERROR(ACTION = ABORT
	  	          ,EM_TO      = &PRIMARY_PROGRAMMER_EMAIL
	  	          ,EM_SUBJECT = HCE SUPPORT: NOTIFICATION OF ABEND INITIATIVE_ID &INITIATIVE_ID
	  	          ,EM_MSG     = %STR(CLAIMS_PULL_EDW MACRO RETURNED 0 ROWS FOR ADJ &ADJ_ENGINE. 
	                             SO THE EXECUTION OF THE MAILING PROGRAM HAS BEEN FORCED TO ABORT));
	          options mprint mprintnest mlogic mlogicnest symbolgen source2;
	  		%END;

	  	%MEND EDW_CLAIMS;

		%IF &RX_ADJ. = 1 %THEN

		%DO;
			%LET SRC_SYS_CD     = %STR(X);
			%LET PAYER_ID_CONS  = %STR(< 100000);
			%LET HIERARCHY_LIST = %STR(	,A.EXTNL_LVL_ID1 AS CLIENT_LEVEL_1
						   	   			,A.EXTNL_LVL_ID2 AS CLIENT_LEVEL_2
						   	   			,A.EXTNL_LVL_ID3 AS CLIENT_LEVEL_3);
			%LET REFILL_QTY    = %STR(,VCLM.SBMTD_REFIL_ATHZD AS REFILL_FILL_QY);
			%LET CARRIER_FIELD = CLIENT_LEVEL_1;
			%EDW_CLAIMS(ADJ_ENGINE = RX);
		%END;

		%IF &RE_ADJ. = 1 %THEN

		%DO;
			%LET SRC_SYS_CD     = %STR(R);
			%LET PAYER_ID_CONS  = %STR(BETWEEN 500000 AND 2000000);
			%LET HIERARCHY_LIST = %STR(,A.RPT_OPT1_CD AS CLIENT_LEVEL_1
						   	   		   ,A.EXTNL_LVL_ID1 AS CLIENT_LEVEL_2
						   	   		   ,A.EXTNL_LVL_ID3 AS CLIENT_LEVEL_3);
			%LET REFILL_QTY = %STR(,VCLM.ATHZD_REFIL_QTY AS REFILL_FILL_QY);
			%LET CARRIER_FIELD = CLIENT_LEVEL_2;
			%EDW_CLAIMS(ADJ_ENGINE = RE);
		%END;
	%MEND CLAIMS_PULL_EDW_18AUG2009;

	
