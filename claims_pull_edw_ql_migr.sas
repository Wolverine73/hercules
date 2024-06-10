%MACRO CLAIMS_PULL_EDW_QL_MIGR;
%IF &ADJ_ENGINE = RX %THEN %DO;	/*	Execute for RX only	*/

%local TRGT_RECIPIENT_CD PRSCR_CONS;

/** PRESCRIBER CONSTRAINTS TO USE
  		    NOTE: IF IT IS A PARTICIPANT ONLY OR CARDHOLDER ONLY MAILING, THE PRESCRIBER
  		          CONSTRAINT NEED NOT BE APPLIED **/

  		PROC SQL;
  			SELECT TRGT_RECIPIENT_CD INTO :TRGT_RECIPIENT_CD
  			FROM HERCULES.TPROGRAM_TASK 
  			WHERE PROGRAM_ID = &PROGRAM_ID. AND
  			TASK_ID = &TASK_ID.;
  		QUIT;

		%put &TRGT_RECIPIENT_CD;

  		%IF &TRGT_RECIPIENT_CD EQ 1 OR &TRGT_RECIPIENT_CD EQ 4 %THEN %DO;
  		  %LET PRSCR_CONS = %STR();
  		%END;
  		%ELSE %DO;
  		  %LET PRSCR_CONS = %STR(AND PRCTR.REC_SRC_FLG = 0
  							     AND PRCTR.PRCTR_ID_TYP_CD IN ('DH', 'FW', 'NP'));
  		%END;


	DATA WORK.&TABLE_PREFIX._QL_MIGR;
	SET &DB2_TMP..&TABLE_PREFIX._QL_MIGR;
	RUN;

libname dwcorp oracle path=&gold schema=dwcorp;


%DROP_ORACLE_TABLE(tbl_name=&ORA_TMP..&TABLE_PREFIX._QL_MIGR1);

%LET CLIENT_TABLE_MIGR = %STR(&ORA_TMP..&TABLE_PREFIX._QL_MIGR1 CLT);

PROC SQL NOPRINT;
CREATE TABLE &ORA_TMP..&TABLE_PREFIX._QL_MIGR1 AS
SELECT 		A.*, B.QL_CPG_ID, B.PAYER_ID, B.ALGN_LVL_GID, 
			B.QL_CLNT_NM AS CLIENT_NM, B.QL_CLNT_ID AS QL_CLIENT_ID,
			D.TRGT_HIER_ALGN_1_ID AS CLIENT_LEVEL_1,
			D.TRGT_HIER_ALGN_2_ID AS CLIENT_LEVEL_2,
			D.TRGT_HIER_ALGN_3_ID AS CLIENT_LEVEL_3


FROM 	  WORK.&TABLE_PREFIX._QL_MIGR A LEFT JOIN
		  &DSS_CLIN..V_CLNT_CPG_QL_DENORM B


ON	A.CLT_PLAN_GROUP_ID = B.QL_CPG_ID

LEFT JOIN &DSS_CLIN..V_CLNT_CAG_MGRTN D

ON trim(left(put(A.CLIENT_ID,8.))) = TRIM(left(D.SRC_HIER_ALGN_1_ID))
          AND trim(left(put(A.CLT_PLAN_GROUP_ID,8.))) = TRIM(left(D.SRC_HIER_ALGN_2_ID))

WHERE datepart(D.MGRTN_EFF_DT) <= TODAY()

;QUIT;


/*		 ,&DSS_CLIN.V_MBR_ELIG_ACTIVE C*/
/*	AND C.SRC_SYS_CD = 'Q'*/
/*	AND B.QL_CPG_ID = C.QL_CPG_ID*/
/*	AND datepart(C.ELIG_EFF_DT) <= TODAY() AND datepart(C.ELIG_END_DT) > TODAY()*/
%INCLUDE "/herc&sysmode/prg/hercules/macros/delivery_sys_check_tbd.sas";


/*	1)	Retail claims pull*/
PROC SQL;
  			CONNECT TO ORACLE(PATH=&GOLD preserve_comments);	
  			CREATE TABLE TARGET_CLAIMS_MIGR AS
  			SELECT 	DISTINCT
					ADJ_ENGINE,
                    ALGN_LVL_GID AS ALGN_LVL_GID_KEY,
                    CLIENT_ID, 
                    CLIENT_NM 	   informat=$60. format=$60. length=60,
                    CLIENT_LEVEL_1 informat=$22. format=$22. length=22,
                    CLIENT_LEVEL_2 informat=$22. format=$22. length=22,
                    CLIENT_LEVEL_3 informat=$22. format=$22. length=22,
                    PAYER_ID, 
                    MBR_GID,
                    DRUG_GID,
                    PHMCY_GID, 
                    PRCTR_GID, 
                    DSPND_DATE, 
                    BATCH_DATE,
                    MEMBER_COST_AT, 
                    BNFT_LVL_CODE,
                    BIRTH_DT,
                    LAST_FILL_DT,
                    RX_COUNT_QY, 
                    REFILL_FILL_QY,
                    LTR_RULE_SEQ_NB,
					RX_NB,
					DISPENSED_QY,
					DAY_SUPPLY_QY,
					FRMLY_GID,
					QL_BNFCY_ID

  				FROM CONNECTION TO ORACLE
( 
          SELECT  	%bquote(/)%bquote(*)+index(claim payer_id)%bquote(*)%bquote(/)
					'RX' AS ADJ_ENGINE,
                    CLT.ALGN_LVL_GID,
                    CLT.QL_CLIENT_ID AS CLIENT_ID, 
                    CLT.CLIENT_NM, 
                    CLT.CLIENT_LEVEL_1,
                    CLT.CLIENT_LEVEL_2, 
                    CLT.CLIENT_LEVEL_3,
                    CLAIM.PAYER_ID, 
                    CLAIM.MBR_GID,
                    CLAIM.DRUG_GID,
                    CLAIM.PHMCY_GID, 
                    CLAIM.PRCTR_GID, 
                    CLAIM.DSPND_DATE, 
                    CLAIM.BATCH_DATE,
                    CLAIM.AMT_COPAY AS MEMBER_COST_AT, 
                    CLAIM.BNFT_LVL_CODE,
                    SUBSTR (CLAIM.PTNT_BRTH_DT, 1, 10) AS BIRTH_DT,
                    SUBSTR (CLAIM.DSPND_DATE, 1, 10) AS LAST_FILL_DT,
                    CLAIM.CLAIM_TYPE AS RX_COUNT_QY, 
                    0 AS REFILL_FILL_QY,
                    0 AS LTR_RULE_SEQ_NB,
        			CLAIM.RX_NBR AS RX_NB,
        			CLAIM.UNIT_QTY AS DISPENSED_QY,
					CAST(CLAIM.DAYS_SPLY AS CHAR(4)) AS DAY_SUPPLY_QY,
					CLAIM.FRMLY_GID,
					CLAIM.QL_BNFCY_ID

			  FROM &DSS_CLIN..V_CLAIM_CORE_PAID CLAIM,
                   &CLIENT_TABLE_MIGR.

             WHERE CLAIM.DSPND_DATE BETWEEN &CLM_BEGIN_DT_CONV AND &CLM_END_DT_CONV AND
               	   CLAIM.PAYER_ID IN (SELECT DISTINCT PAYER_ID FROM  &CLIENT_TABLE_MIGR.)
			   AND CLT.ALGN_LVL_GID = CLAIM.ALGN_LVL_GID
               AND CLT.PAYER_ID = CLAIM.PAYER_ID
			   AND CLT.QL_CPG_ID = CLAIM.QL_CPG_ID
               AND CLAIM.BATCH_DATE IS NOT NULL
               AND CLAIM.SRC_SYS_CD = 'Q'
               AND CLAIM.CLAIM_WSHD_CD IN ('P')
          );
          DISCONNECT FROM ORACLE;
  		QUIT;





%DROP_ORACLE_TABLE(tbl_name=dss_herc.mail_claims_migr1_&initiative_id.);

/*	2)	Mail claims	*/
	PROC SQL;
  			CONNECT TO ORACLE(PATH=&GOLD PRESERVE_COMMENTS);	
  			CREATE TABLE dss_herc.mail_claims_migr1_&initiative_id. AS
  				SELECT * FROM CONNECTION TO ORACLE
  				( 
          SELECT  	%bquote(/)%bquote(*)+index(claim payer_id)%bquote(*)%bquote(/)
					'RX' AS ADJ_ENGINE,
                    clt.algn_lvl_gid,
                    clt.ql_client_id AS client_id, 
                    clt.client_nm, 
                    clt.client_level_1,
                    clt.client_level_2, 
                    clt.client_level_3,
                    claim.QL_BNFCY_ID,
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
					CAST(CLAIM.DAYS_SPLY as char(4)) as DAY_SUPPLY_QY,
					CLAIM.FRMLY_GID

              FROM &DSS_CLIN..V_CLAIM_CORE_PAID CLAIM 
		           ,&CLIENT_TABLE_MIGR.
				
             WHERE CLAIM.DSPND_DATE BETWEEN &MAIL_BGN_EDW_DT AND &MAIL_END_EDW_DT 
			   AND claim.payer_id in (select distinct payer_id from  &CLIENT_TABLE_MIGR.)
			   AND clt.ALGN_LVL_GID = claim.ALGN_LVL_GID
               AND clt.payer_id = claim.payer_id
			   AND clt.ql_cpg_id = claim.ql_cpg_id
			   AND claim.batch_date IS NOT NULL
               AND CLAIM.SRC_SYS_CD = 'Q'
               AND claim.claim_wshd_cd IN ('P')
          );
          DISCONNECT FROM ORACLE;
  		QUIT;

/*SASDOC____________________________________________________________________________________
|Fetch member information from DSS_CLIN.V_MBR view and 										
|	all the RX mbr_gids from the DSS_CLIN.V_MBR_ELIG_ACTIVE view								
|	for the mail claims dataset. 															
|	This assumes that the  members have migrated to RXclaim, otherwise the member			
|	will be dropped. Assumes that QL_BNFCY_ID is the same throughout the migration, 		
|	and through the internal member movement.												
|
|	Steps: (joins explained)
|	Join V_MBR on Bene ID					
|	Joining to ELIG view to get latest gids 
|	Fetch client_levels 1,2,3 			
|	MBR.SRC_SYS_CD = 'X'
|	Pick all the mbr_gids for the person available, to be used later in MOR check.
|_____________________________________________________________________________________SASDOC*/

	PROC SQL;
	CONNECT TO ORACLE(PATH=&GOLD PRESERVE_COMMENTS);		
  			CREATE TABLE data_res.mail_claims_migr_&initiative_id. AS
			select * from connection to oracle
			(
	          SELECT  	%bquote(/)%bquote(*)+ordered index(MBR ql_bnfcy_id) use_hash(MBR) %bquote(*)%bquote(/)
			  DISTINCT
						      CLAIM.ADJ_ENGINE,
						      C.ALGN_LVL_GID,
						      CLAIM.CLIENT_ID,
						      CLAIM.CLIENT_NM,
						      ALG.EXTNL_LVL_ID1 AS CLIENT_LEVEL_1,
						      ALG.EXTNL_LVL_ID2 AS CLIENT_LEVEL_2,
						      ALG.EXTNL_LVL_ID3 AS CLIENT_LEVEL_3,
						      C.PAYER_ID,
						      C.MBR_GID,
						      CLAIM.DRUG_GID,
						      CLAIM.PHMCY_GID,
						      CLAIM.PRCTR_GID,
						      CLAIM.DSPND_DATE,
						      CLAIM.BATCH_DATE,
						      CLAIM.MEMBER_COST_AT,
						      CLAIM.BNFT_LVL_CODE,
						      CLAIM.BIRTH_DT,
						      CLAIM.LAST_FILL_DT,
						      CLAIM.RX_COUNT_QY,
						      CLAIM.REFILL_FILL_QY,
						      CLAIM.LTR_RULE_SEQ_NB,
						      CLAIM.RX_NB,
						      CLAIM.DISPENSED_QY,
						      CLAIM.DAY_SUPPLY_QY,
						      CLAIM.FRMLY_GID

              FROM  &ORA_TMP..MAIL_CLAIMS_MIGR1_&INITIATIVE_ID. CLAIM 

LEFT JOIN		&DSS_CLIN..V_MBR MBR				ON CLAIM.QL_BNFCY_ID = MBR.QL_BNFCY_ID		
INNER JOIN		&DSS_CLIN..V_MBR_ELIG_ACTIVE C		ON MBR.MBR_GID 		 = C.MBR_GID					
LEFT JOIN		&DSS_CLIN..V_ALGN_LVL_DENORM ALG	ON MBR.ALGN_LVL_GID  = ALG.ALGN_LVL_GID_KEY 

			WHERE  	 MBR.SRC_SYS_CD = 'X'					
          );
          DISCONNECT FROM ORACLE;
  		QUIT;

/*	RX drug targeting table	*/
%let DRUG_NDC_TABLE_RX = %str(&ORA_TMP..&TABLE_PREFIX._NDC_RX);

/*	Extract drugs	*/
	PROC SQL;
  			CONNECT TO ORACLE(PATH=&GOLD PRESERVE_COMMENTS);
  				CREATE TABLE drug_migr AS
  			SELECT   
				  DRUG_NDC_ID 
                 ,DRUG_GID 
				 ,DRUG_CATEGORY_ID
				 ,GPI14 
                 ,DRUG_BRAND_CD
                 ,DRUG_ABBR_DSG_NM informat=$30. format= $30. length=30
                 ,DRUG_ABBR_PROD_NM informat=$30. format= $30. length=30
                 ,DRUG_ABBR_STRG_NM informat=$30. format= $30. length=30
				 ,GCN_CODE 
				 ,GCN_NBR 
				 ,BRAND_GENERIC
									FROM CONNECTION TO ORACLE
  				( 
          SELECT  NDC.DRUG_NDC_ID
                 ,NDC.DRUG_GID
				 ,NDC.DRUG_CATEGORY_ID
				 ,NME.GPI_CODE AS GPI14
                 ,NME.QL_BRND_NAM_CD as DRUG_BRAND_CD 
                 ,NME.QL_DRUG_ABBR_DSG_NM as DRUG_ABBR_DSG_NM
                 ,NME.QL_DRUG_ABBR_PROD_NM as DRUG_ABBR_PROD_NM
                 ,NME.QL_DRUG_ABBR_STRG_NM as DRUG_ABBR_STRG_NM
				 ,NME.GCN_CODE
				 ,NME.GCN_NBR
				 ,CASE WHEN NME.RECAP_GNRC_FLAG = '2' OR MULTI_TYPE_CODE IN ('M','O','N') 
							        THEN 'B'
						            ELSE 'G'
						      END AS BRAND_GENERIC

          FROM  &DSS_CLIN..V_DRUG_DENORM NME
                ,&DRUG_NDC_TABLE_RX. NDC
          WHERE NDC.DRUG_GID=NME.DRUG_GID
          );
          DISCONNECT FROM ORACLE;
  		QUIT;


		PROC SQL;
  			CREATE TABLE claim_drug_migr AS
        SELECT * FROM target_claims_migr claim,
                      drug_migr drug
        where claim.drug_gid = drug.drug_gid
          AND DRUG.DRUG_GID IS NOT NULL;
  		QUIT;



/*	Extract pharmacy	*/
PROC SQL;
  		  CREATE TABLE phmcy_migr AS				
          SELECT phmcy.phmcy_gid, 
				 phmcy.nabp_code_6, 
				 PHMCY.PHMCY_NAME AS PHARMACY_NM,
				 INPUT(PHMCY.PHMCY_DSPNS_TYPE, 3.) AS LAST_DELIVERY_SYS,
				 &CREATE_DELIVERY_SYSTEM_CD_RX. informat=$30. format=$30. length=30
              FROM &DSS_CLIN..V_PHMCY_DENORM PHMCY;         
  		QUIT;


   proc sql;
       create table claims_phmcy_migr as
        select *
          from claim_drug_migr c,
               phmcy_migr p
          where c.phmcy_gid = p.phmcy_gid
  	  ;quit;



%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..TMP_CLM_PULL_&INITIATIVE_ID._QLMGR);
%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..TMP_CLAIMS_PULL_&INITIATIVE_ID._QL_MIGR);
%DROP_ORACLE_TABLE(TBL_NAME =&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._QL_MIGR);


      PROC SQL;
        CREATE TABLE &ORA_TMP..TMP_CLM_PULL_&INITIATIVE_ID._QLMGR AS
        SELECT *
        FROM CLAIMS_PHMCY_MIGR;
      QUIT;


/*Extract Practioner and join to claims*/



PROC SQL;
		CONNECT TO ORACLE(PATH=&GOLD);
		EXECUTE (
		CREATE TABLE &ORA_TMP..TMP_CLAIMS_PULL_&INITIATIVE_ID._QL_MIGR AS
  		 SELECT c.*,
				prctr.prctr_id AS practitioner_id,
                prctr.ql_prscr_id AS prescriber_id, 
                prctr.entity_ind,
                prctr.degr_1_cd,
				PRCTR.PRCTR_NPI_ID as PRESCRIBER_NPI_NB
				,CASE WHEN SUBSTR(PRCTR.PRCTR_ID,1,1) NOT IN
							   ('1','2','3','4','5','6','7','8','9','0') AND
							   SUBSTR(PRCTR.PRCTR_ID,2,1) NOT IN
							   ('1','2','3','4','5','6','7','8','9','0')
							   THEN PRCTR.PRCTR_ID
							   ELSE ' '
						     END AS DEA_NB

/*              FROM &ORA_TMP..TMP_CLAIMS_PULL_&INITIATIVE_ID._QL_1_MIGR C*/
              FROM &ORA_TMP..TMP_CLM_PULL_&INITIATIVE_ID._QLMGR C

		LEFT JOIN &DSS_CLIN..V_PRCTR_DENORM PRCTR
			  on C.PRCTR_GID = PRCTR.PRCTR_GID
				&PRSCR_CONS.
				)
		BY ORACLE;
		DISCONNECT FROM ORACLE;			
		QUIT;


		PROC SQL;
  			SELECT COUNT(*) INTO :EDW_CLAIM_CNT_QL_MIGR
  			FROM &ORA_TMP..TMP_CLAIMS_PULL_&INITIATIVE_ID._QL_MIGR;
  		QUIT;

  		%PUT NOTE: CLAIM COUNT - MIGRATED QL CLIENT HISTORY CLAIMS - &EDW_CLAIM_CNT_MIGR;


  		%IF &EDW_CLAIM_CNT_QL_MIGR. > 0 %THEN %DO;


/*	Extract member information	*/

PROC SQL;
	CONNECT TO ORACLE(PATH=&GOLD preserve_comments);
		EXECUTE
  			(
			CREATE TABLE &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._QL_MIGR AS

SELECT   %bquote(/)%bquote(*)+ordered%bquote(*)%bquote(/)
					 distinct
					 A.ADJ_ENGINE,
			         C.ALGN_LVL_GID,
			         A.CLIENT_ID,
			         A.CLIENT_NM,
			         ALG.EXTNL_LVL_ID1 AS CLIENT_LEVEL_1,
			         ALG.EXTNL_LVL_ID2 AS CLIENT_LEVEL_2,
			         ALG.EXTNL_LVL_ID3 AS CLIENT_LEVEL_3,
			         A.DRUG_GID,
			         C.PAYER_ID AS CLM_PAYER,
			         C.MBR_GID ,
			         A.QL_BNFCY_ID,
			         A.PHMCY_GID,
			         A.PRCTR_GID,
			         A.DSPND_DATE,
			         A.BATCH_DATE,
			         A.MEMBER_COST_AT,
			         A.BNFT_LVL_CODE,
			         A.BIRTH_DT,
			         A.LAST_FILL_DT,
			         A.RX_COUNT_QY,
			         A.REFILL_FILL_QY,
			         A.LTR_RULE_SEQ_NB,
			         A.RX_NB,
			         A.DISPENSED_QY,
			         A.DAY_SUPPLY_QY,
			         A.FRMLY_GID,
			         A.DRUG_NDC_ID,
			         A.DRUG_CATEGORY_ID,
			         A.GPI14,
			         A.DRUG_BRAND_CD,
			         A.DRUG_ABBR_DSG_NM,
			         A.DRUG_ABBR_PROD_NM,
			         A.DRUG_ABBR_STRG_NM,
			         A.GCN_CODE,
			         A.GCN_NBR,
			         A.BRAND_GENERIC,
			         A.NABP_CODE_6,
			         A.PHARMACY_NM,
			         A.LAST_DELIVERY_SYS,
			         A.DELIVERY_SYSTEM,
			         A.DEA_NB,
			         A.PRESCRIBER_NPI_NB,
			         A.PRESCRIBER_ID,
			         A.PRACTITIONER_ID,
			         A.ENTITY_IND,
			         A.DEGR_1_CD,
			         MBR.PAYER_ID,
			         MBR.QL_BNFCY_ID AS PT_BENEFICIARY_ID,
			         MBR.QL_CARDHLDR_BNFCY_ID AS CDH_BENEFICIARY_ID,
			         MBR.MBR_ID AS MBR_ID,
			         MBR.MBR_FIRST_NM,
			         MBR.MBR_LAST_NM,
			         MBR.ADDR_LINE1_TXT,
			         MBR.ADDR_LINE2_TXT,
			         MBR.ADDR_CITY_NM,
			         MBR.ADDR_ST_CD,
			         MBR.ADDR_ZIP_CD,
			         MBR.SRC_SUFFX_PRSN_CD,
			         MBR.ALT_INS_MBR_ID,
			         MBR.MBR_BRTH_DT AS M_DOB,
			         MBR.MBR_GNDR_GID,
			         MBR.REL_CODE,
			         FRMLY.FRMLY_NB AS FORMULARY_TX


		FROM 	 &ORA_TMP..TMP_CLAIMS_PULL_&INITIATIVE_ID._QL_MIGR A 

LEFT JOIN 		 &DSS_CLIN..V_MBR MBR				ON	 	A.QL_BNFCY_ID = MBR.QL_BNFCY_ID 

INNER JOIN 	 	 &DSS_CLIN..V_MBR_ELIG_ACTIVE C 	ON 	 	MBR.MBR_GID   = C.MBR_GID

LEFT JOIN    	 &DSS_CLIN..V_FRMLY_HDR FRMLY   	ON  	A.FRMLY_GID	  = FRMLY.FRMLY_GID

LEFT JOIN   	 &DSS_CLIN..V_ALGN_LVL_DENORM ALG   ON 		MBR.ALGN_LVL_GID = ALG.ALGN_LVL_GID_KEY

	WHERE 	 MBR.SRC_SYS_CD = 'X'
		AND	 C.ELIG_EFF_DT <= SYSDATE 
	    AND  ((MBR.MBR_REUSE_RISK_FLG IS NULL) or
             (MBR.MBR_REUSE_RISK_FLG ='Y' and TO_DATE(A.LAST_FILL_DT,'YYYY-MM-DD') > MBR.MBR_REUSE_LAST_UPDT_DT))

	) BY ORACLE;
  DISCONNECT FROM ORACLE;
QUIT;

	
  		%END;
  		%ELSE %DO;

  			

  			%ON_ERROR( EM_TO=&PRIMARY_PROGRAMMER_EMAIL
  	          ,EM_SUBJECT=HCE SUPPORT: NOTIFICATION OF ABEND INITIATIVE_ID &INITIATIVE_ID
  	          ,EM_MSG=%STR(CLAIMS_PULL_EDW MACRO RETURNED 0 ROWS FOR QL MIGRATED CLAIMS MACRO));
          

  		%END;



			%LOAD_PARTICIPANT_EXCLUSION;
%IF %SYSFUNC(EXIST(&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._QL_MIGR)) %THEN %DO;
			%PARTICIPANT_EXCLUSIONS(TBL_NAME_IN = &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._QL_MIGR);
%END;

%IF %SYSFUNC(EXIST(&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX)) AND %SYSFUNC(EXIST(&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._QL_MIGR)) %THEN %DO;

/*	Combining the historical QL claims with the RXclaim table	*/
%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._B4_QL_MIGR);

	PROC SQL;
		CONNECT TO ORACLE (PATH = &GOLD.);
		EXECUTE
		(

			CREATE TABLE &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._B4_QL_MIGR AS
		    SELECT * FROM &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX

		)BY ORACLE;
		DISCONNECT FROM ORACLE;
	QUIT;


/*	Insert into the regular claims pull table	*/
	PROC SQL;
		CONNECT TO ORACLE (PATH = &GOLD.);
		EXECUTE
		(
	INSERT INTO &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX	
				(ADJ_ENGINE,	ALGN_LVL_GID_KEY, CLIENT_ID, CLIENT_NM,	CLIENT_LEVEL_1,	CLIENT_LEVEL_2,	CLIENT_LEVEL_3,	PRACTITIONER_ID,
				PRESCRIBER_ID, ENTITY_IND, DEGR_1_CD, NABP_CODE_6, PAYER_ID, MBR_GID, PHMCY_GID, PRCTR_GID, DSPND_DATE, BATCH_DATE,
				MEMBER_COST_AT, BNFT_LVL_CODE, BIRTH_DT, LAST_FILL_DT, RX_COUNT_QY, DRUG_GID, GCN_CODE, GCN_NBR, DRUG_NDC_ID,
				DRUG_CATEGORY_ID, DRUG_ABBR_DSG_NM, DRUG_ABBR_PROD_NM, DRUG_ABBR_STRG_NM, DRUG_BRAND_CD, GPI14, REFILL_FILL_QY,
				LTR_RULE_SEQ_NB, RX_NB, DISPENSED_QY, DAY_SUPPLY_QY, PHARMACY_NM, DELIVERY_SYSTEM, FRMLY_GID, LAST_DELIVERY_SYS,				BRAND_GENERIC,
				PRESCRIBER_NPI_NB, DEA_NB, PT_BENEFICIARY_ID, CDH_BENEFICIARY_ID, MBR_ID, MBR_FIRST_NM, MBR_LAST_NM, ADDR_LINE1_TXT,
				ADDR_LINE2_TXT, ADDR_CITY_NM, ADDR_ST_CD, ADDR_ZIP_CD, SRC_SUFFX_PRSN_CD, FORMULARY_TX,MBR_GNDR_GID, M_DOB, REL_CODE)

	SELECT		ADJ_ENGINE,	ALGN_LVL_GID, CLIENT_ID, CLIENT_NM,	CLIENT_LEVEL_1,	CLIENT_LEVEL_2,	CLIENT_LEVEL_3,	PRACTITIONER_ID,
				PRESCRIBER_ID, ENTITY_IND, DEGR_1_CD, NABP_CODE_6, PAYER_ID, MBR_GID, PHMCY_GID, PRCTR_GID, DSPND_DATE, BATCH_DATE,
				MEMBER_COST_AT, BNFT_LVL_CODE, BIRTH_DT, LAST_FILL_DT, RX_COUNT_QY, DRUG_GID, GCN_CODE, GCN_NBR, DRUG_NDC_ID,
				DRUG_CATEGORY_ID, DRUG_ABBR_DSG_NM, DRUG_ABBR_PROD_NM, DRUG_ABBR_STRG_NM, DRUG_BRAND_CD, GPI14, REFILL_FILL_QY,
				LTR_RULE_SEQ_NB, RX_NB, DISPENSED_QY, DAY_SUPPLY_QY, PHARMACY_NM, DELIVERY_SYSTEM, FRMLY_GID, LAST_DELIVERY_SYS,				BRAND_GENERIC,
				PRESCRIBER_NPI_NB, DEA_NB, PT_BENEFICIARY_ID, CDH_BENEFICIARY_ID, MBR_ID, MBR_FIRST_NM, MBR_LAST_NM, ADDR_LINE1_TXT,
				ADDR_LINE2_TXT, ADDR_CITY_NM, ADDR_ST_CD, ADDR_ZIP_CD, SRC_SUFFX_PRSN_CD, FORMULARY_TX,MBR_GNDR_GID, M_DOB, REL_CODE

	FROM &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._QL_MIGR 
		)BY ORACLE;
		DISCONNECT FROM ORACLE;
	QUIT;

%END;

%ELSE %IF %SYSFUNC(EXIST(&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX)) = 0 %THEN %DO;


	PROC SQL;
		CONNECT TO ORACLE (PATH = &GOLD.);
		EXECUTE
			(
		CREATE TABLE &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX
( 		  "ADJ_ENGINE" VARCHAR2(2), 
		  "ALGN_LVL_GID" NUMBER(12,0) NOT NULL ENABLE, 
		  "CLIENT_ID" NUMBER, 
		  "CLIENT_NM" VARCHAR2(60), 
		  "CLIENT_LEVEL_1" VARCHAR2(20), 
		  "CLIENT_LEVEL_2" VARCHAR2(20), 
		  "CLIENT_LEVEL_3" VARCHAR2(20), 
		  "DRUG_GID" NUMBER, 
		  "CLM_PAYER" NUMBER(12,0) NOT NULL ENABLE, 
		  "MBR_GID" NUMBER NOT NULL ENABLE, 
		  "QL_BNFCY_ID" NUMBER, 
		  "PHMCY_GID" NUMBER, 
		  "PRCTR_GID" NUMBER, 
		  "DSPND_DATE" DATE, 
		  "BATCH_DATE" DATE, 
		  "MEMBER_COST_AT" NUMBER, 
		  "BNFT_LVL_CODE" VARCHAR2(10), 
		  "BIRTH_DT" VARCHAR2(10), 
		  "LAST_FILL_DT" VARCHAR2(10), 
		  "RX_COUNT_QY" NUMBER, 
		  "REFILL_FILL_QY" NUMBER, 
		  "LTR_RULE_SEQ_NB" NUMBER, 
		  "RX_NB" VARCHAR2(20), 
		  "DISPENSED_QY" NUMBER, 
		  "DAY_SUPPLY_QY" VARCHAR2(4), 
		  "FRMLY_GID" NUMBER, 
		  "DRUG_NDC_ID" NUMBER(13,0), 
		  "DRUG_CATEGORY_ID" NUMBER(12,0), 
		  "GPI14" VARCHAR2(19), 
		  "DRUG_BRAND_CD" VARCHAR2(1), 
		  "DRUG_ABBR_DSG_NM" VARCHAR2(30), 
		  "DRUG_ABBR_PROD_NM" VARCHAR2(30), 
		  "DRUG_ABBR_STRG_NM" VARCHAR2(30), 
		  "GCN_CODE" NUMBER(7,0), 
		  "GCN_NBR" NUMBER(6,0), 
		  "BRAND_GENERIC" VARCHAR2(1), 
		  "NABP_CODE_6" VARCHAR2(15), 
		  "PHARMACY_NM" VARCHAR2(60), 
		  "LAST_DELIVERY_SYS" NUMBER, 
		  "DELIVERY_SYSTEM" VARCHAR2(30), 
		  "DEA_NB" VARCHAR2(20), 
		  "PRESCRIBER_NPI_NB" VARCHAR2(20), 
		  "PRESCRIBER_ID" VARCHAR2(11), 
		  "PRACTITIONER_ID" VARCHAR2(20), 
		  "ENTITY_IND" CHAR(1), 
		  "DEGR_1_CD" CHAR(3), 
		  "PAYER_ID" NUMBER(12,0) NOT NULL ENABLE, 
		  "PT_BENEFICIARY_ID" NUMBER, 
		  "CDH_BENEFICIARY_ID" VARCHAR2(20), 
		  "MBR_ID" VARCHAR2(25), 
		  "MBR_FIRST_NM" VARCHAR2(40), 
		  "MBR_LAST_NM" VARCHAR2(40), 
		  "ADDR_LINE1_TXT" VARCHAR2(60), 
		  "ADDR_LINE2_TXT" VARCHAR2(60), 
		  "ADDR_CITY_NM" VARCHAR2(60), 
		  "ADDR_ST_CD" VARCHAR2(3), 
		  "ADDR_ZIP_CD" VARCHAR2(20), 
		  "SRC_SUFFX_PRSN_CD" VARCHAR2(3), 
		  "ALT_INS_MBR_ID" VARCHAR2(25), 
		  "M_DOB" DATE, 
		  "MBR_GNDR_GID" NUMBER, 
		  "REL_CODE" VARCHAR2(2), 
		  "FORMULARY_TX" VARCHAR2(10)    ) 
	
		)BY ORACLE;
		DISCONNECT FROM ORACLE;
	QUIT;

%END;

%END;	/*	End- Run for RX only*/
%MEND CLAIMS_PULL_EDW_QL_MIGR; 

/*%let adj_engine=RX;*/
/*%CLAIMS_PULL_EDW_QL_MIGR;*/
