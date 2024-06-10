%*HEADER-----------------------------------------------------------------------
| MACRO:    get_ndc
|
| LOCATION: /PRG/sas%lowcase(&SYSMODE)1/hercules/macros
|
| USAGE:    get_ndc_gstp
|
| Eg. options %get_ndc(DRUG_NDC_TBL=TMP55.MY_NDC,STD_IND=Y)
|           
|
| PURPOSE:  Get drug information for GSTP program
|
| LOGIC:    
|
| INPUT:   hercules GSTP tables
|
| OUTPUT:  user-defined table
+------------------------------------------------------------------------------
| HISTORY:  E.Sliounkova 11/04/2010 Original Version 
+----------------------------------------------------------------------HEADER*;


%MACRO GET_NDC_GSTP(DRUG_NDC_TBL=,STD_IND=);

%PUT STD_IND = &STD_IND;

*SASDOC-------------------------------------------------------------------------
| Macro for fields compare: character fields
+-----------------------------------------------------------------------SASDOC*;
%MACRO BLANK_OR_EQ_DB2(VAR=);
AND ((B.&VAR. IS NULL AND C.&VAR. IS NULL) 
OR (B.&VAR. ='' AND C.&VAR. IS NULL)
OR (B.&VAR. IS NULL AND C.&VAR. ='')
OR (UPPER(TRIM(B.&VAR.)) = UPPER(TRIM(C.&VAR.))))
%MEND;

*SASDOC-------------------------------------------------------------------------
| Macro for fields compare: numeric fields
+-----------------------------------------------------------------------SASDOC*;

%MACRO BLANK_OR_EQ_DB2_NUM(NMB=,NMC=);
AND ((B.&NMB. IS NULL AND C.&NMC. IS NULL) 
OR (B.&NMB. =0 AND C.&NMC. IS NULL)
OR (B.&NMB. IS NULL AND C.&NMC. =0)
OR (B.&NMB. = C.&NMC.))
%MEND;

*SASDOC-------------------------------------------------------------------------
| Get Standard or Custom GSTP Drugs
+-----------------------------------------------------------------------SASDOC*;
			%IF %UPCASE(&STD_IND.) = Y %THEN %DO;
			PROC SQL NOPRINT;
	        CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
			CREATE TABLE STD_DRUGS AS
	        SELECT * FROM CONNECTION TO DB2
	   		(  SELECT A.GSTP_GPI_CD
			        , CHAR(A.GSTP_GCN_CD) AS GSTP_GCN_CD
					, CHAR(A.GSTP_DRG_NDC_ID) AS GSTP_DRG_NDC_ID
					, A.MULTI_SRC_IN
					, A.DRG_DTW_CD
				

					FROM &HERCULES..TGSTP_DRG_CLS_DET A
/*					FROM PBATCH.TGSTP_DRG_CLS_DET A*/

			WHERE 
			      A.DRG_CLS_EFF_DT <= CURRENT DATE 
			AND   A.DRG_CLS_EXP_DT >= CURRENT DATE
			AND   A.DRG_EFF_DT <= CURRENT DATE 
			AND   A.DRG_EXP_DT >= CURRENT DATE 
		    WITH UR
			  		);

					
	    	DISCONNECT FROM DB2;

		QUIT;
		%END;
		%ELSE %DO;
	    PROC SQL NOPRINT;
	        CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
			CREATE TABLE CSTM_DRUGS_1 AS
	        SELECT * FROM CONNECTION TO DB2
	   		(  SELECT A.GSTP_GPI_CD
			        , CHAR(A.GSTP_GCN_CD) AS GSTP_GCN_CD
					, CHAR(A.GSTP_DRG_NDC_ID) AS GSTP_DRG_NDC_ID
					, A.MULTI_SRC_IN
					, A.DRG_DTW_CD
				

					FROM &HERCULES..TPMTSK_GSTP_QL_DET A
					   , &HERCULES..TPMTSK_GSTP_QL_RUL B
					   , &DB2_TMP..&TABLE_PREFIX._GSTP_CSTM_IN C

			WHERE A.GSTP_QL_RUL_ID = B.GSTP_QL_RUL_ID
			AND   B.CLIENT_ID = C.CLIENT_ID
			AND   B.CLT_EFF_DT = C.EFFECTIVE_DT
			AND   C.SRC_SYS_CD = 'Q'

			  %BLANK_OR_EQ_DB2_NUM(NMB=GROUP_CLS_CD,NMC=GROUP_CLASS_CD)
			  %BLANK_OR_EQ_DB2_NUM(NMB=GROUP_CLS_SEQ_NB,NMC=GROUP_CLASS_SEQ_NB)
			  %BLANK_OR_EQ_DB2    (VAR=BLG_REPORTING_CD)
			  %BLANK_OR_EQ_DB2    (VAR=PLAN_NM)
			  %BLANK_OR_EQ_DB2    (VAR=PLAN_CD_TX)
			  %BLANK_OR_EQ_DB2    (VAR=PLAN_EXT_CD_TX)
			  %BLANK_OR_EQ_DB2    (VAR=GROUP_CD_TX)
			  %BLANK_OR_EQ_DB2    (VAR=GROUP_EXT_CD_TX)

		    AND   B.DRG_CLS_EFF_DT <= CURRENT DATE 
			AND   B.DRG_CLS_EXP_DT >= CURRENT DATE 
			AND   A.DRG_EFF_DT    <= CURRENT DATE 
			AND   A.DRG_EXP_DT    >= CURRENT DATE 
		    WITH UR
			  		);

		CREATE TABLE CSTM_DRUGS_2 AS
	        SELECT * FROM CONNECTION TO DB2
	   		(  SELECT A.GSTP_GPI_CD
			        , CHAR(A.GSTP_GCN_CD) AS GSTP_GCN_CD
					, CHAR(A.GSTP_DRG_NDC_ID) AS GSTP_DRG_NDC_ID
					, A.MULTI_SRC_IN
					, A.DRG_DTW_CD
				

					FROM &HERCULES..TPMTSK_GSTP_RP_DET A
					   , &HERCULES..TPMTSK_GSTP_RP_RUL B
					   , &DB2_TMP..&TABLE_PREFIX._GSTP_CSTM_IN C

			WHERE A.GSTP_RECAP_RUL_ID = B.GSTP_RECAP_RUL_ID
			AND   B.INSURANCE_CD = C.INSURANCE_CD
			AND   B.CLT_EFF_DT = C.EFFECTIVE_DT
			AND   C.SRC_SYS_CD = 'R'

			  %BLANK_OR_EQ_DB2    (VAR=CARRIER_ID)
			  %BLANK_OR_EQ_DB2    (VAR=GROUP_CD)

		    AND   B.DRG_CLS_EFF_DT <= CURRENT DATE 
			AND   B.DRG_CLS_EXP_DT >= CURRENT DATE  
			AND   A.DRG_EFF_DT     <= CURRENT DATE 
			AND   A.DRG_EXP_DT     >= CURRENT DATE 
		    WITH UR
			  		);

			CREATE TABLE CSTM_DRUGS_3 AS
	        SELECT * FROM CONNECTION TO DB2
	   		(  SELECT A.GSTP_GPI_CD
			        , CHAR(A.GSTP_GCN_CD) AS GSTP_GCN_CD
					, CHAR(A.GSTP_DRG_NDC_ID) AS GSTP_DRG_NDC_ID
					, A.MULTI_SRC_IN
					, A.DRG_DTW_CD
				
					FROM &HERCULES..TPMTSK_GSTP_RX_DET A
					   , &HERCULES..TPMTSK_GSTP_RX_RUL B
					   , &DB2_TMP..&TABLE_PREFIX._GSTP_CSTM_IN C

			WHERE A.GSTP_RXCLM_RUL_ID = B.GSTP_RXCLM_RUL_ID
			AND   B.CARRIER_ID = C.CARRIER_ID
			AND   B.CLT_EFF_DT = C.EFFECTIVE_DT
			AND   C.SRC_SYS_CD = 'X'

			  %BLANK_OR_EQ_DB2    (VAR=ACCOUNT_ID)
			  %BLANK_OR_EQ_DB2    (VAR=GROUP_CD)

		    AND   B.DRG_CLS_EFF_DT <= CURRENT DATE 
			AND   B.DRG_CLS_EXP_DT >= CURRENT DATE 
			AND   A.DRG_EFF_DT     <= CURRENT DATE 
			AND   A.DRG_EXP_DT     >= CURRENT DATE 
		    WITH UR
			  		);
					
	    	DISCONNECT FROM DB2;

		QUIT;
%SET_ERROR_FL;


		DATA STD_DRUGS;
		SET CSTM_DRUGS_1
		    CSTM_DRUGS_2
			CSTM_DRUGS_3
			;
		RUN;
%SET_ERROR_FL;

		%END;

		PROC SORT DATA = STD_DRUGS NODUPKEY; BY GSTP_GPI_CD GSTP_GCN_CD GSTP_DRG_NDC_ID DRG_DTW_CD;
		RUN;
%SET_ERROR_FL;

*SASDOC-------------------------------------------------------------------------
| Handle wild-carded GPIs, create join on either GPI or NDC
+-----------------------------------------------------------------------SASDOC*;
		DATA TARGET_MEDS (DROP=TICK LEFT_PAR RIGHT_PAR LIKE AST)
             PREREQ_MEDS (DROP=TICK LEFT_PAR RIGHT_PAR LIKE AST)
        ;
		SET STD_DRUGS;

		TICK="'";
		LEFT_PAR="(";
		RIGHT_PAR=")";
		LIKE="%";

		IF GSTP_GPI_CD NE '0' THEN DO;
		   DRUG_FIELD = 'GPI';
		   DRUG_KEY   = 'GPI'||TRIM(GSTP_GPI_CD);
		   EDW_FIELD_NAME = 'GPI_CODE';
		   AST=INDEX(GSTP_GPI_CD,'*');
		   IF AST THEN DRUG_SUB=SUBSTR(GSTP_GPI_CD,1,(AST-1));ELSE DRUG_SUB=GSTP_GPI_CD;
		END;
		ELSE IF GSTP_DRG_NDC_ID NE '0' THEN DO;
			DRUG_FIELD = 'NDC';
		   DRUG_KEY   = 'NDC'||TRIM(COMPRESS(GSTP_DRG_NDC_ID,'.'));
		   EDW_FIELD_NAME = 'NDC_CODE';
		   AST=INDEX(COMPRESS(GSTP_DRG_NDC_ID,'.'),'*');
		   IF AST THEN DRUG_SUB=SUBSTR(COMPRESS(GSTP_DRG_NDC_ID,'.'),1,(AST-1));ELSE DRUG_SUB=COMPRESS(GSTP_DRG_NDC_ID,'.');
		END;
/*		ELSE DO;*/
/*			DRUG_FIELD = 'GCN';*/
/*		   DRUG_KEY   = 'GCN'||TRIM(GSTP_GCN_CD);*/
/*		   EDW_FIELD_NAME = 'GCN_CODE';*/
/*		   AST=INDEX(GSTP_GCN_CD,'*');*/
/*		   IF AST THEN DRUG_SUB=SUBSTR(GSTP_GCN_CD,1,(AST-1));ELSE DRUG_SUB=GSTP_GCN_CD;*/
/*		END;*/

GPI_MAC=TRIM(LEFT_PAR)||'DRUG.'||TRIM(EDW_FIELD_NAME)||' '||'LIKE '||TRIM(LEFT_PAR)||TRIM(TICK)||TRIM(DRUG_SUB)||TRIM(LIKE)||TRIM(TICK)||TRIM(RIGHT_PAR)||TRIM(RIGHT_PAR);
DRUG_SUB_MAC='WHEN '||TRIM(LEFT_PAR)||'DRUG.'||TRIM(EDW_FIELD_NAME)||' '||'LIKE '||TRIM(LEFT_PAR)||TRIM(TICK)||TRIM(DRUG_SUB)||TRIM(LIKE)||
TRIM(TICK)||TRIM(RIGHT_PAR)||TRIM(RIGHT_PAR)||' '||'THEN '||TRIM(TICK)||TRIM(DRUG_SUB)||TRIM(TICK);
IF DRG_DTW_CD = 1 THEN OUTPUT TARGET_MEDS;
ELSE IF DRG_DTW_CD = 2 THEN OUTPUT PREREQ_MEDS;

RUN;
%SET_ERROR_FL;

DATA EMPTY_CASE;
GPI_MAC = "(DRUG.GPI_CODE LIKE ('A%'))";
DRUG_SUB_MAC = "WHEN (DRUG.GPI_CODE LIKE ('A%')) THEN 'A'";
DRUG_FIELD = 'GPI';
DRUG_SUB= 'A';
OUTPUT;
GPI_MAC = "(DRUG.GPI_CODE LIKE ('A%'))";
DRUG_SUB_MAC = "WHEN (DRUG.GPI_CODE LIKE ('A%')) THEN 'A'";
DRUG_FIELD = 'NDC';
DRUG_SUB= 'A';
OUTPUT;


DATA TARGET_MEDS;
SET TARGET_MEDS
EMPTY_CASE;
RUN;

DATA PREREQ_MEDS;
SET PREREQ_MEDS
EMPTY_CASE;
RUN;


PROC SORT DATA = TARGET_MEDS NODUPKEY; BY DRUG_SUB DRUG_FIELD;
RUN;
%SET_ERROR_FL;


PROC SORT DATA = PREREQ_MEDS NODUPKEY; BY DRUG_SUB DRUG_FIELD;
RUN;
%SET_ERROR_FL;
*SASDOC-------------------------------------------------------------------------
| Create macro variables for case and join statement used in drug query
+-----------------------------------------------------------------------SASDOC*;

PROC SQL NOPRINT;
SELECT DISTINCT GPI_MAC
   INTO :MEDS_TARG_GPI SEPARATED BY ' OR '
   FROM TARGET_MEDS
WHERE DRUG_FIELD = 'GPI';
   QUIT;

PROC SQL NOPRINT;
SELECT DISTINCT DRUG_SUB_MAC
   INTO :MEDS_SUB_TARG_GPI SEPARATED BY ' '
   FROM TARGET_MEDS
WHERE DRUG_FIELD = 'GPI';
   QUIT;

   PROC SQL NOPRINT;
SELECT DISTINCT GPI_MAC
   INTO :MEDS_PRE_GPI SEPARATED BY ' OR '
   FROM PREREQ_MEDS
WHERE DRUG_FIELD = 'GPI';
   QUIT;

PROC SQL NOPRINT;
SELECT DISTINCT DRUG_SUB_MAC
   INTO :MEDS_SUB_PRE_GPI SEPARATED BY ' '
   FROM PREREQ_MEDS
WHERE DRUG_FIELD = 'GPI';
   QUIT;

   PROC SQL NOPRINT;
SELECT DISTINCT GPI_MAC
   INTO :MEDS_TARG_NDC SEPARATED BY ' OR '
   FROM TARGET_MEDS
WHERE DRUG_FIELD = 'NDC';
   QUIT;

PROC SQL NOPRINT;
SELECT DISTINCT DRUG_SUB_MAC
   INTO :MEDS_SUB_TARG_NDC SEPARATED BY ' '
   FROM TARGET_MEDS
WHERE DRUG_FIELD = 'NDC';
   QUIT;

   PROC SQL NOPRINT;
SELECT DISTINCT GPI_MAC
   INTO :MEDS_PRE_NDC SEPARATED BY ' OR '
   FROM PREREQ_MEDS
WHERE DRUG_FIELD = 'NDC';
   QUIT;

PROC SQL NOPRINT;
SELECT DISTINCT DRUG_SUB_MAC
   INTO :MEDS_SUB_PRE_NDC SEPARATED BY ' '
   FROM PREREQ_MEDS
WHERE DRUG_FIELD = 'NDC';
   QUIT;

 

*SASDOC-------------------------------------------------------------------------
| Pull Information from DSS_CLIN.V_DRUG_DENORM
+-----------------------------------------------------------------------SASDOC*;
%MACRO PULL_DRUGS(PRE=);

DATA _NULL_;
TICK = "'";

FIELD_NM = TRIM(LEFT("&PRE."));
CALL SYMPUT('DRUG_FIELD',TICK||LEFT(TRIM(FIELD_NM))||TICK);
RUN;

PROC SQL NOPRINT;
		CONNECT TO ORACLE(PATH=&GOLD );
		CREATE TABLE DRUG_DENORM_T_&PRE. AS
	        SELECT * FROM CONNECTION TO ORACLE
		(
      	 SELECT DISTINCT 
  DRUG.DRUG_GID ,                      
  SUBSTR(DRUG.NDC_CODE,1,11)          AS NDC,
  DRUG.LBL_NAME                       AS LABEL_NAME,
  DRUG.RECAP_GNRC_CLASS_NBR           AS GEN_CODE,
  DRUG.GPI_CODE,                       
  DRUG.BRAND_NAME                     AS DRUG_NAME, 
  DRUG.GPI_NAME,   
  DRUG.RECAP_GNRC_FLAG,
  DRUG.MS_GNRC_FLAG,
  DRUG.QL_DRUG_MULTI_SRC_IN, 
  DRUG.RECAP_MULTI_TYPE_CODE            AS MS_SS_CD,
  DRUG.MULTI_TYPE_CODE                  AS MDDB_MS_SS_CD,
  DRUG.QL_DRUG_ABBR_PROD_NM,
  DRUG.QL_DRUG_ABBR_DSG_NM,
  DRUG.QL_DRUG_ABBR_STRG_NM,
  DRUG.DSG_FORM,
  DRUG.DSG_FORM_DESC,
  DRUG.STRGH_DESC,
  DRUG.STRGH_NBR,
  DRUG.STRGH_UNIT,
  DRUG.GCN_CODE,

  CASE
  &&MEDS_SUB_TARG_&PRE.
  END AS DRUG_SUB ,
  &DRUG_FIELD. AS DRUG_FIELD
  FROM  &DSS_CLIN..V_DRUG_DENORM       DRUG 
 WHERE DRUG.DRUG_VLD_FLG = 'Y'
 AND &&MEDS_TARG_&PRE.

 ORDER BY  22   
  		);
	DISCONNECT FROM ORACLE;
	QUIT;
%SET_ERROR_FL;


			PROC SQL NOPRINT;
		CONNECT TO ORACLE(PATH=&GOLD );
		CREATE TABLE DRUG_DENORM_P_&PRE. AS
	        SELECT * FROM CONNECTION TO ORACLE
		(
      	 SELECT DISTINCT 
  DRUG.DRUG_GID ,                      
  SUBSTR(DRUG.NDC_CODE,1,11)          AS NDC,
  DRUG.LBL_NAME                       AS LABEL_NAME,
  DRUG.RECAP_GNRC_CLASS_NBR           AS GEN_CODE,
  DRUG.GPI_CODE,                       
  DRUG.BRAND_NAME                     AS DRUG_NAME, 
  DRUG.GPI_NAME,   
  DRUG.RECAP_GNRC_FLAG,
  DRUG.MS_GNRC_FLAG,
  DRUG.QL_DRUG_MULTI_SRC_IN, 
  DRUG.RECAP_MULTI_TYPE_CODE            AS MS_SS_CD,
  DRUG.MULTI_TYPE_CODE                  AS MDDB_MS_SS_CD,
  DRUG.QL_DRUG_ABBR_PROD_NM,
  DRUG.QL_DRUG_ABBR_DSG_NM,
  DRUG.QL_DRUG_ABBR_STRG_NM,
  DRUG.DSG_FORM,
  DRUG.DSG_FORM_DESC,
  DRUG.STRGH_DESC,
  DRUG.STRGH_NBR,
  DRUG.STRGH_UNIT,
  DRUG.GCN_CODE,

  CASE
  &&MEDS_SUB_PRE_&PRE.
  END AS DRUG_SUB ,
   &DRUG_FIELD. AS DRUG_FIELD
  FROM  &DSS_CLIN..V_DRUG_DENORM       DRUG 
 WHERE DRUG.DRUG_VLD_FLG = 'Y'
 AND &&MEDS_PRE_&PRE.

 ORDER BY  22   
  		);
	DISCONNECT FROM ORACLE;
	QUIT;
%SET_ERROR_FL;

%MEND;

%PULL_DRUGS(PRE=GPI);
%PULL_DRUGS(PRE=NDC);



*SASDOC-------------------------------------------------------------------------
| Merge back with GSTP sas dataset to get GSTP information 
+-----------------------------------------------------------------------SASDOC*;
DATA MEDS_T;
SET DRUG_DENORM_T_GPI
    DRUG_DENORM_T_NDC
	;
RUN;

DATA MEDS_P;
SET DRUG_DENORM_P_GPI
    DRUG_DENORM_P_NDC
	;
RUN;

PROC SORT DATA = MEDS_T; BY DRUG_SUB DRUG_FIELD;
RUN;

PROC SORT DATA = MEDS_P; BY DRUG_SUB DRUG_FIELD;
RUN;



DATA MEDS_T;
MERGE MEDS_T(IN=A) TARGET_MEDS(IN=B);
BY DRUG_SUB DRUG_FIELD;
IF A AND B;
  IF MULTI_SRC_IN=0 THEN DO;
   IF (DRUG_FIELD='NDC' OR MDDB_MS_SS_CD='N' );
 END; ELSE IF MULTI_SRC_IN=1  THEN DO;
  IF (DRUG_FIELD='NDC' OR MDDB_MS_SS_CD='Y');
 END;
RUN;

DATA MEDS_P;
MERGE MEDS_P(IN=A) PREREQ_MEDS(IN=B);
BY DRUG_SUB DRUG_FIELD;
IF A AND B;
  IF MULTI_SRC_IN=0 THEN DO;
   IF (DRUG_FIELD='NDC' OR MDDB_MS_SS_CD='N' );
 END; ELSE IF MULTI_SRC_IN=1  THEN DO;
  IF (DRUG_FIELD='NDC' OR MDDB_MS_SS_CD='Y');
 END;
RUN;


*SASDOC-------------------------------------------------------------------------
| Handle Name, Dosage and Strength Information 
+-----------------------------------------------------------------------SASDOC*;
DATA MEDS (DROP=DSG_FORM DSG_FORM_DESC STRGH_DESC STRGH_NBR STRGH_UNIT);
SET MEDS_T
    MEDS_P;
IF QL_DRUG_ABBR_PROD_NM = '' THEN QL_DRUG_ABBR_PROD_NM = DRUG_NAME;
IF QL_DRUG_ABBR_DSG_NM = '' THEN DO;
   IF DSG_FORM_DESC NE '' THEN QL_DRUG_ABBR_DSG_NM = DSG_FORM_DESC;
   ELSE QL_DRUG_ABBR_DSG_NM = DSG_FORM;
END;
IF QL_DRUG_ABBR_STRG_NM = '' THEN DO;
   IF STRGH_DESC NE '' THEN QL_DRUG_ABBR_STRG_NM = COMPRESS(STRGH_DESC);
   ELSE QL_DRUG_ABBR_STRG_NM = LEFT(PUT(STRGH_NBR,6.))||TRIM(STRGH_UNIT);
END;
RUN;

PROC SORT DATA = MEDS NODUPKEY; BY DRUG_GID DRUG_KEY DRG_DTW_CD;
RUN;
%SET_ERROR_FL;

*SASDOC-------------------------------------------------------------------------
| Create and Populate Drug Output Table  
+-----------------------------------------------------------------------SASDOC*;
%DROP_ORACLE_TABLE(TBL_NAME=&DRUG_NDC_TBL.); 

			PROC SQL NOPRINT;
					CONNECT TO ORACLE(PATH=&GOLD );
		  			EXECUTE 
					(
					CREATE TABLE &DRUG_NDC_TBL.
					(DRUG_GID                    NUMBER
					 ,NDC                        VARCHAR2(11)
                     ,LABEL_NAME                 VARCHAR2(30)
					 ,GEN_CODE                   VARCHAR2(5)
					 ,GPI_CODE                   VARCHAR2(14)
					 ,DRUG_NAME                  VARCHAR2(60)
					 ,GPI_NAME                   VARCHAR2(60)
					 ,RECAP_GNRC_FLAG            VARCHAR2(1)
				     ,MS_GNRC_FLAG               NUMBER
					 ,QL_DRUG_MULTI_SRC_IN       VARCHAR2(7)
					 ,MS_SS_CD                   VARCHAR2(1)
					 ,MDDB_MS_SS_CD              VARCHAR2(1)
					 ,QL_DRUG_ABBR_PROD_NM       VARCHAR2(30)
  					 ,QL_DRUG_ABBR_DSG_NM        VARCHAR2(30)
  					 ,QL_DRUG_ABBR_STRG_NM       VARCHAR2(30)
					 ,GCN_CODE                   NUMBER
					 ,DRUG_KEY                   VARCHAR2(20)
					 ,DRG_DTW_CD                 NUMBER
					 )
		  			) BY ORACLE;
		    		DISCONNECT FROM ORACLE;
				QUIT;
				RUN;
%SET_ERROR_FL;

				PROC SQL;

				INSERT INTO &DRUG_NDC_TBL.
				SELECT DRUG_GID       
					 ,NDC      
                     ,LABEL_NAME             
					 ,GEN_CODE                 
					 ,GPI_CODE                
					 ,DRUG_NAME           
					 ,GPI_NAME                 
					 ,RECAP_GNRC_FLAG         
				     ,MS_GNRC_FLAG             
					 ,QL_DRUG_MULTI_SRC_IN     
					 ,MS_SS_CD                
					 ,MDDB_MS_SS_CD  
                     ,QL_DRUG_ABBR_PROD_NM
					 ,QL_DRUG_ABBR_DSG_NM
					 ,QL_DRUG_ABBR_STRG_NM
					 ,GCN_CODE
					 ,DRUG_KEY 
                     ,DRG_DTW_CD 
                FROM MEDS
				WHERE DRG_DTW_CD = 1;
				QUIT;
				RUN;
%SET_ERROR_FL;


*SASDOC-------------------------------------------------------------------------
| Create Index and Run Runstats on Drug Output Table  
+-----------------------------------------------------------------------SASDOC*;
PROC SQL;
 CONNECT TO ORACLE(PATH=&GOLD );
  EXECUTE (
    CREATE INDEX &DRUG_NDC_TBL._I1
    ON &DRUG_NDC_TBL.(DRUG_GID)
	)
  BY ORACLE;
  DISCONNECT FROM ORACLE;
QUIT;
%SET_ERROR_FL;

%LET POS=%INDEX(&DRUG_NDC_TBL,.);
%LET SCHEMA_NDC=%SUBSTR(&DRUG_NDC_TBL,1,%EVAL(&POS-1));
%LET TBL_NDC=%SUBSTR(&DRUG_NDC_TBL,%EVAL(&POS+1));

DATA _NULL_;
TICK = "'";
COMMA=",";
DB_ID = TRIM(LEFT("&SCHEMA_NDC."));
TBL_NM = TRIM(LEFT("&TBL_NDC."));
CALL SYMPUT('ORA_STR1',TICK||LEFT(TRIM(DB_ID))||TICK||COMMA);
CALL SYMPUT('ORA_STR2',TICK||LEFT(TRIM(TBL_NM))||TICK);
RUN;
%SET_ERROR_FL;


DATA _NULL_;
CALL SYMPUT('ORA_STRB',TRIM(LEFT("&ORA_STR1"))||TRIM(LEFT("&ORA_STR2")));
RUN;


PROC SQL;
  CONNECT TO ORACLE(PATH=&GOLD );
EXECUTE(EXEC DBMS_STATS.GATHER_TABLE_STATS(&ORA_STRB.)) BY ORACLE;
DISCONNECT FROM ORACLE;
 QUIT;
RUN;
%SET_ERROR_FL;

%MEND;
