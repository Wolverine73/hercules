/***HEADER -------------------------------------------------------------------------
 |  MACRO NAME:     PULL_CLAIMS_FOR_QL.SAS
 |
 |  PURPOSE:    Pull claims for QL mailing
 |              
 |  INPUT:     
 |                         &CLAIMSA..&CLAIM_HIS_TBL
 |                         &CLAIMSA..TCLIENT1    
 |                         &CLAIMSA..TDRUG1   
 |                         
 |
 |  OUTPUT:     Standard datasets in /results and /pending directories
 |
 |
 |  HISTORY:   
 |              
 |           Apr22 2008    - Carl Starks Hercules Version 2.1.01 |
 |           This is a new macro used for QL claims logic is unchanged
 |           input and output file names are passed  
 |
 |           Nov04 2009    - Brian Stropich Hercules Version  3.0.0.00
 |           added changes to resolve the issue of particpant eligibility issue
 |
 |			01OCT2013 - S.Biletsky - Fix for QL Client Connect. F.ADJ_ENGINE_CD = 1 added
 |
 *          Dec 2013 - J.Agostinelli - BSR - Voided Claims & Other Fixes
 +-------------------------------------------------------------------------------HEADER*/
 
%MACRO pull_claims_for_ql(tbl_name_in1=, tbl_name_in2=,tbl_name_in3=,
                                 tbl_name_out1=,tbl_name_out2=,tbl_name_out3=,
                                                 ADJ_ENGINE=
                                    );          
options symbolgen mlogic mprint;
%drop_db2_table(tbl_name=&tbl_name_out1.);
%drop_db2_table(tbl_name=&tbl_name_out2.);

DATA _NULL_;

%IF &RESOLVE_CLIENT_EXCLUDE_FLAG = 1 %THEN %DO;
  
    CALL SYMPUT('CLIENT_COND',TRIM(LEFT("NOT EXISTS")));
%END;
%ELSE %IF 
      &RESOLVE_CLIENT_EXCLUDE_FLAG = 0 %THEN  %DO;
       CALL SYMPUT('CLIENT_COND',TRIM(LEFT("EXISTS")));
%END;
RUN;

%IF (&PROGRAM_ID NE 105 OR &TASK_ID NE 11) %THEN %DO;
   %IF (&TASK_ID EQ 21) %THEN %DO;
         %LET WHERECONS = %STR(     AND &CLIENT_COND. (SELECT 1 FROM &TBL_NAME_IN1. CLT
                              WHERE A.CLIENT_ID = CLT.CLIENT_ID ));
   %END;
   %ELSE %DO;
         %LET WHERECONS = %STR(     AND &CLIENT_COND. (SELECT 1 FROM &TBL_NAME_IN1. CLT
                              WHERE A.CLT_PLAN_GROUP_ID = CLT.CLT_PLAN_GROUP_ID ));
   %END;
%END;
%ELSE %DO;
		%LET WHERECONS = %STR();
%END;

%put NOTE: WHERECONS = &WHERECONS.;

/*   %LET WHERECONS = %STR(   AND &CLIENT_COND. (SELECT 1 FROM &TBL_NAME_IN1. CLT*/
/*                                  WHERE A.CLT_PLAN_GROUP_ID = CLT.CLT_PLAN_GROUP_ID ));*/

%PUT "CLIENT SET-UP WHERECONS = &WHERECONS.";

%drop_db2_table(tbl_name=&tbl_name_out1._A);

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
EXECUTE(CREATE TABLE &tbl_name_out1._A
( PRESCRIBER_ID		INTEGER	NOT NULL,
  CDH_BENEFICIARY_ID	INTEGER	NOT NULL,
  PT_BENEFICIARY_ID	INTEGER	NOT NULL,
  MBR_ID	CHARACTER(25)	NOT NULL,
  BIRTH_DT	DATE,
  DRUG_NDC_ID	DECIMAL(11,0),
  NHU_TYPE_CD	SMALLINT,
  DRG_GROUP_SEQ_NB	INTEGER,
  DRG_SUB_GRP_SEQ_NB	INTEGER,
  ADJ_ENGINE	VARCHAR(2)	,
  CLIENT_ID	INTEGER,
  CLT_PLAN_GROUP_ID2	INTEGER	NOT NULL,
  RX_COUNT_QY	INTEGER	NOT NULL,
  MEMBER_COST_AT	DECIMAL(11,2)	NOT NULL,
  LAST_FILL_DT	DATE	NOT NULL,
  RX_NB	CHARACTER(12)	,
  DISPENSED_QY	DECIMAL(12,3)	,
  DAY_SUPPLY_QY	SMALLINT	,
/* Dec 2013 BSR Voided Claims - Changed to Integer from Smallint */
  REFILL_FILL_QY	INTEGER	,
  FORMULARY_TX	CHARACTER(30)	,
  LAST_DELIVERY_SYS	SMALLINT	,
  NABP_ID	CHARACTER(7),
  CLIENT_NM	CHARACTER(30)	
  )NOT LOGGED INITIALLY) BY DB2;
   DISCONNECT FROM DB2;
QUIT;



 %set_error_fl;

%PUT CLAIMS_TBL=&CLAIMSA..&CLAIM_HIS_TBL;
*SASDOC--------------------------------------------------------------------------
|  The code below executes only if no drug information is required and
|  the drug group1 is all drugs
+------------------------------------------------------------------------SASDOC*;
%IF &ALL_DRUG_IN1=1 AND &DRUG_FIELDS_LIST=%STR() %THEN                   %DO;

/* Dec 2013 BSR Voided Claims begin */
/* %drop_db2_table(tbl_name=&tbl_name_out1._A);  */
/* Dec 2013 BSR Voided Claims end */

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
EXECUTE
  (ALTER TABLE &tbl_name_out1._A ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;

EXECUTE(INSERT INTO &tbl_name_out1._A
/* Dec 2013 BSR Voided Claims begin */
        WITH PTS2 AS
                (SELECT          A.NTW_PRESCRIBER_ID AS PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID,
                                 A.PT_BENEFICIARY_ID,
                                 CAST(A.PT_BENEFICIARY_ID AS CHAR(25)) AS MBR_ID,
                                 A.PT_BIRTH_DT     AS BIRTH_DT,
                                 A.DRUG_NDC_ID,
                                 A.NHU_TYPE_CD,
                                 1                 AS DRG_GROUP_SEQ_NB,
                                 1                 AS DRG_SUB_GRP_SEQ_NB,
                                 &ADJ_ENGINE as ADJ_ENGINE,
                                 A.CLIENT_ID,
                                 A.CLT_PLAN_GROUP_ID as CLT_PLAN_GROUP_ID2,
                                 A.RX_COUNT_QY ,
  				 A.MEMBER_COST_AT,
								 A.FILL_DT         AS LAST_FILL_DT,
								 A.REFILL_NB as REFILL_FILL_QY,
								 RTRIM(A.PT_BENEFICIARY_ID)||RTRIM(A.NTW_PRESCRIBER_ID)||RTRIM(A.DRUG_NDC_ID)||JULIAN_DAY(A.FILL_DT)||RTRIM(A.BENEFIT_REQUEST_ID)||RTRIM(A.REFILL_NB) AS RXKEY


                 FROM    &CLAIMSA..&CLAIM_HIS_TBL   AS A
         WHERE    A.FILL_DT BETWEEN &CLAIM_BEGIN_DT1. AND &CLAIM_END_DT1.
                  &WHERECONS.
                  &DELIVERY_SYSTEM_CONDITION.
         AND NOT EXISTS
              (SELECT 1
               FROM &CLAIMSA..&CLAIM_HIS_TBL
               WHERE A.BENEFIT_REQUEST_ID = BENEFIT_REQUEST_ID
               AND   A.BRLI_NB = BRLI_NB
               AND   BRLI_VOID_IN > 0)),

		PTS1
		AS (SELECT PRESCRIBER_ID, CDH_BENEFICIARY_ID, PT_BENEFICIARY_ID, MBR_ID, MAX(BIRTH_DT) AS BIRTH_DT, 
        DRUG_NDC_ID, NHU_TYPE_CD, DRG_GROUP_SEQ_NB, DRG_SUB_GRP_SEQ_NB, ADJ_ENGINE, CLIENT_ID, CLT_PLAN_GROUP_ID2, RX_COUNT_QY,
                MEMBER_COST_AT, LAST_FILL_DT, REFILL_FILL_QY, RXKEY
		FROM PTS2  
		GROUP BY  
		PRESCRIBER_ID, CDH_BENEFICIARY_ID, PT_BENEFICIARY_ID,
		MBR_ID, DRUG_NDC_ID, NHU_TYPE_CD, DRG_GROUP_SEQ_NB, DRG_SUB_GRP_SEQ_NB, ADJ_ENGINE, CLIENT_ID, CLT_PLAN_GROUP_ID2, RX_COUNT_QY,
                MEMBER_COST_AT, LAST_FILL_DT, REFILL_FILL_QY, RXKEY),

		PTS as (
		SELECT *
		FROM (SELECT PRESCRIBER_ID, CDH_BENEFICIARY_ID, PT_BENEFICIARY_ID,
		MBR_ID, BIRTH_DT, DRG_GROUP_SEQ_NB,	DRG_SUB_GRP_SEQ_NB, ADJ_ENGINE, CLIENT_ID, CLT_PLAN_GROUP_ID2,
		DRUG_NDC_ID, NHU_TYPE_CD, LAST_FILL_DT, REFILL_FILL_QY , RXKEY,
		      ROW_NUMBER() OVER (PARTITION BY PT_BENEFICIARY_ID, PRESCRIBER_ID, DRUG_NDC_ID, CLT_PLAN_GROUP_ID2 ORDER BY RXKEY DESC) ROW_ID
		FROM PTS1 )
		WHERE ROW_ID=1       
		)


                SELECT 
					E.PRESCRIBER_ID, 
					E.CDH_BENEFICIARY_ID, 
					E.PT_BENEFICIARY_ID, 
					E.MBR_ID, 
					E.BIRTH_DT, 
					E.DRUG_NDC_ID, 
					E.NHU_TYPE_CD, 
					E.DRG_GROUP_SEQ_NB, 
					E.DRG_SUB_GRP_SEQ_NB, 
					E.ADJ_ENGINE, 
					E.CLIENT_ID, 
					E.CLT_PLAN_GROUP_ID2,  
					E.LAST_FILL_DT, 
					E.REFILL_FILL_QY,        
				X.NABP_ID,
				X.RX_NB,
				X.RX_COUNT_QY AS  RX_COUNT_QY,
				X.DISPENSED_QY,
				X.MEMBER_COST_AT AS  MEMBER_COST_AT,                                
				X.DAY_SUPPLY_QY,
				CAST(X.FORMULARY_ID as varchar(30)) as FORMULARY_TX,
				X.DELIVERY_SYSTEM_CD as LAST_DELIVERY_SYS,
				F.CLIENT_NM
                 FROM    PTS  AS E,
			 &CLAIMSA..&CLAIM_HIS_TBL  AS X,
                         &CLAIMSA..TCLIENT1  AS F
                 WHERE   		E.CLIENT_ID = F.CLIENT_ID
/*Q2X added ADJ_ENGINE_CD since QL migrated clients change code to 2 after migration*/
				 			AND F.ADJ_ENGINE_CD = 1
				 			AND X.PT_BENEFICIARY_ID = E.PT_BENEFICIARY_ID
       						AND X.DRUG_NDC_ID = E.DRUG_NDC_ID
							AND E.RXKEY = RTRIM(X.PT_BENEFICIARY_ID)||RTRIM(X.NTW_PRESCRIBER_ID)||RTRIM(X.DRUG_NDC_ID)||JULIAN_DAY(X.FILL_DT)||RTRIM(X.BENEFIT_REQUEST_ID)||RTRIM(X.REFILL_NB)
                            AND X.RX_COUNT_QY > 0
/* Dec 2013 BSR Voided Claims end */
      ) BY DB2;
          %PUT Before reset;
          %PUT SQLXRC=&SQLXRC SYSERR=&SYSERR;
      %reset_sql_err_cd;
    DISCONNECT FROM DB2;
QUIT; 

%set_error_fl;

PROC SQL;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
CREATE TABLE &tbl_name_out1. AS

            SELECT   A.*,     
                         B.BLG_REPORTING_CD , /* NEW FIELDS FROM TCPGRP_CLT_PLN_GR1 */ 
                         B.PLAN_CD,
                         B.PLAN_EXTENSION_CD as PLAN_EXT_CD_TX,
                         B.GROUP_CD,
                         B.GROUP_EXTENSION_CD as GROUP_EXT_CD_TX,
                         B.CLIENT_ID as CLIENT_LEVEL_1 ,
                         B.GROUP_CD as CLIENT_LEVEL_2,
                         B.BLG_REPORTING_CD as CLIENT_LEVEL_3,
                         C.PHARMACY_NM,
                         D.DRUG_ABBR_STRG_NM,
                         D.DRUG_ABBR_DSG_NM,
                         D.DGH_GCN_CD AS GCN_CODE,
                         D.DRUG_BRAND_CD AS BRAND_GENERIC,
                         D.DRUG_ABBR_PROD_NM,
                         D.GENERIC_NDC_IN,
                         D.GPI_GROUP||D.GPI_CLASS||D.GPI_SUBCLASS||D.GPI_NAME||D.GPI_NAME_EXTENSION||D.GPI_FORM||D.GPI_STRENGTH AS GPI_THERA_CLS_CD,
                         E.PRESCRIBER_DEA_NB AS DEA_NB,
                         E.PRESCRIBER_NPI_NB


      FROM              &tbl_name_out1._A A 

            LEFT JOIN   &CLAIMSA..TCPGRP_CLT_PLN_GR1 B ON
/* Dec 2013 BSR Voided Claims begin */
                              A.CLT_PLAN_GROUP_ID2 = B.CLT_PLAN_GROUP_ID
/* Dec 2013 BSR Voided Claims end */

            LEFT JOIN &CLAIMSA..TPHARM_PHARMACY C ON
                              A.NABP_ID = C.NABP_ID
            LEFT JOIN &CLAIMSA..TDRUG1 D ON
                              A.DRUG_NDC_ID = D.DRUG_NDC_ID AND
                              A.NHU_TYPE_CD = D.NHU_TYPE_CD
            LEFT JOIN &CLAIMSA..TPRSCBR_PRESCRIBE1 E ON
                          A.PRESCRIBER_ID = E.PRESCRIBER_ID

;
DISCONNECT FROM DB2;
QUIT;


%set_error_fl;

%IF &err_fl=0 %THEN %PUT Created table &tbl_name_out1. ;
%runstats(TBL_NAME=&DB2_TMP..&tbl_name_out1. );

                   %END; /* End of &ALL_DRUG_IN1=1 AND &DRUG_FIELDS_LIST=%STR()*/
*SASDOC--------------------------------------------------------------------------
| Check if NDC table is provided by macro %get_ndc and if yes join claims to this table.
| If the drug information is requiered the macro also joins to the STR_TDRUG1 table.
+------------------------------------------------------------------------SASDOC*;
%drop_db2_table(tbl_name=&tbl_name_out3.);

%IF &GET_NDC_NDC_TBL_FL=1 %THEN                %DO;
%drop_db2_table(tbl_name=&tbl_name_out3._A);


PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
EXECUTE(CREATE TABLE &tbl_name_out3._A
(
/* Dec 2013 BSR Voided Claims removed RXKEY BIGINT, */
  PRESCRIBER_ID	INTEGER	NOT NULL,
  CDH_BENEFICIARY_ID	INTEGER	NOT NULL,
  PT_BENEFICIARY_ID	INTEGER	NOT NULL,
  MBR_ID	CHARACTER(25)	NOT NULL,
  BIRTH_DT	DATE,
  DRG_GROUP_SEQ_NB	INTEGER,
  DRG_SUB_GRP_SEQ_NB	INTEGER,
  ADJ_ENGINE	VARCHAR(2)	,
  CLIENT_ID	INTEGER,
  CLT_PLAN_GROUP_ID2	INTEGER	NOT NULL,
  LAST_FILL_DT	DATE	NOT NULL,
  REFILL_FILL_QY	SMALLINT	,
  RX_COUNT_QY	INTEGER	NOT NULL,
  MEMBER_COST_AT	DECIMAL(11,2)	NOT NULL,
  DISPENSED_QY	DECIMAL(12,3)	,
  DAY_SUPPLY_QY	SMALLINT	,
  FORMULARY_TX	CHARACTER(30)	,
  LAST_DELIVERY_SYS	SMALLINT	,
  NABP_ID	CHARACTER(7),
  RX_NB	CHARACTER(12)	,
  DRUG_ABBR_DSG_NM	CHARACTER(3)	,
  DRUG_ABBR_PROD_NM	CHARACTER(12)	,
  DRUG_ABBR_STRG_NM	CHARACTER(8)	,
  DRUG_NDC_ID	DECIMAL(11,0)	,
  NHU_TYPE_CD	SMALLINT	,  
  GCN_CODE	INTEGER	,
  BRAND_GENERIC	CHARACTER(1)	,
  GENERIC_NDC_IN	DECIMAL(11,0)	,
  GPI_THERA_CLS_CD	CHARACTER(14)	,
  CLIENT_NM	CHARACTER(30)	
  )NOT LOGGED INITIALLY) BY DB2;
   DISCONNECT FROM DB2;
QUIT;



%set_error_fl;


PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
EXECUTE
  (ALTER TABLE &tbl_name_out3._A ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;
EXECUTE(INSERT INTO &tbl_name_out3._A

/* Dec 2013 BSR Voided Claims begin */

    WITH PTS2 AS
	(SELECT		A.NTW_PRESCRIBER_ID    AS PRESCRIBER_ID,
			A.CDH_BENEFICIARY_ID,
			A.PT_BENEFICIARY_ID,
			CAST(A.PT_BENEFICIARY_ID as CHAR(25)) 	AS MBR_ID,
			A.PT_BIRTH_DT     AS BIRTH_DT,
			B.DRG_GROUP_SEQ_NB,
			B.DRG_SUB_GRP_SEQ_NB,
			&ADJ_ENGINE as ADJ_ENGINE,
			A.CLIENT_ID,
			A.CLT_PLAN_GROUP_ID as CLT_PLAN_GROUP_ID2,
			D.DRUG_NDC_ID,
			D.NHU_TYPE_CD,
			FILL_DT           AS  LAST_FILL_DT,
			A.REFILL_NB as REFILL_FILL_QY ,
			RTRIM(A.PT_BENEFICIARY_ID)||RTRIM(A.NTW_PRESCRIBER_ID)||RTRIM(A.DRUG_NDC_ID)||JULIAN_DAY(A.FILL_DT)||RTRIM(A.BENEFIT_REQUEST_ID)||RTRIM(A.REFILL_NB) AS RXKEY
/* Dec 2013 BSR Voided Claims end */
	FROM	&CLAIMSA..&CLAIM_HIS_TBL           AS A,
		&tbl_name_in2.                     AS B,
		&tbl_name_in3.                     AS D

                                     
	WHERE (	(B.ALL_DRUG_IN=0)
		OR (&DRUG_FIELDS_FLAG=1 AND B.ALL_DRUG_IN=1))
		AND    A.FILL_DT BETWEEN CLAIM_BEGIN_DT AND CLAIM_END_DT
		AND    B.DRG_GROUP_SEQ_NB=D.DRG_GROUP_SEQ_NB
		AND    B.DRG_SUB_GRP_SEQ_NB=D.DRG_SUB_GRP_SEQ_NB
		AND    A.DRUG_NDC_ID = D.DRUG_NDC_ID
		AND    A.NHU_TYPE_CD = D.NHU_TYPE_CD
		&WHERECONS.
		&DELIVERY_SYSTEM_CONDITION.

	AND NOT EXISTS
		(SELECT 1
		FROM &CLAIMSA..&CLAIM_HIS_TBL
		WHERE A.BENEFIT_REQUEST_ID = BENEFIT_REQUEST_ID
		AND	A.BRLI_NB = BRLI_NB
/* Dec 2013 BSR Voided Claims begin */
		AND	BRLI_VOID_IN > 0)),

	PTS1
		AS (SELECT PRESCRIBER_ID, CDH_BENEFICIARY_ID, PT_BENEFICIARY_ID, MBR_ID, MAX(BIRTH_DT) AS BIRTH_DT, 
    	    DRUG_NDC_ID, NHU_TYPE_CD, DRG_GROUP_SEQ_NB, DRG_SUB_GRP_SEQ_NB, ADJ_ENGINE, CLIENT_ID, CLT_PLAN_GROUP_ID2, LAST_FILL_DT, REFILL_FILL_QY, RXKEY
			FROM PTS2  
			GROUP BY
				PRESCRIBER_ID, 
				CDH_BENEFICIARY_ID, 
				PT_BENEFICIARY_ID,
				MBR_ID, 
				DRUG_NDC_ID, 
				NHU_TYPE_CD, 
				DRG_GROUP_SEQ_NB, 
				DRG_SUB_GRP_SEQ_NB, 
				ADJ_ENGINE, CLIENT_ID, 
				CLT_PLAN_GROUP_ID2, 
				LAST_FILL_DT, 
				REFILL_FILL_QY, 
				RXKEY),

	PTS as (
		SELECT *
		FROM (SELECT PRESCRIBER_ID, CDH_BENEFICIARY_ID, PT_BENEFICIARY_ID,
		MBR_ID, BIRTH_DT, DRG_GROUP_SEQ_NB,	DRG_SUB_GRP_SEQ_NB, ADJ_ENGINE, CLIENT_ID, CLT_PLAN_GROUP_ID2,
		DRUG_NDC_ID, NHU_TYPE_CD, LAST_FILL_DT, REFILL_FILL_QY , RXKEY,
		      ROW_NUMBER() OVER (PARTITION BY PT_BENEFICIARY_ID, PRESCRIBER_ID, DRUG_NDC_ID, CLT_PLAN_GROUP_ID2 ORDER BY RXKEY DESC) ROW_ID
		FROM PTS1 )
		WHERE ROW_ID=1       
		)

	SELECT
/***	E.RXKEY, */
/* Dec 2013 BSR Voided Claims end */
		E.PRESCRIBER_ID,
		E.CDH_BENEFICIARY_ID,
		E.PT_BENEFICIARY_ID,
		E.MBR_ID,
		E.BIRTH_DT,
		E.DRG_GROUP_SEQ_NB,
		E.DRG_SUB_GRP_SEQ_NB,
		&ADJ_ENGINE as ADJ_ENGINE,
		E.CLIENT_ID,
		E.CLT_PLAN_GROUP_ID2,
		E.LAST_FILL_DT,
		E.REFILL_FILL_QY,
		X.RX_COUNT_QY,
		X.MEMBER_COST_AT,
		X.DISPENSED_QY,
		X.DAY_SUPPLY_QY,
		CAST (X.FORMULARY_ID AS VARCHAR (30)) AS FORMULARY_TX,
		X.DELIVERY_SYSTEM_CD AS LAST_DELIVERY_SYS,
		X.NABP_ID AS NABP_ID,
/* Dec 2013 BSR Voided Claims begin */
		X.RX_NB,
/***	&DRUG_FIELDS_LIST_NDC., */
		G.DRUG_ABBR_DSG_NM, 
		G.DRUG_ABBR_PROD_NM,
		G.DRUG_ABBR_STRG_NM,
		G.DRUG_NDC_ID,
		G.NHU_TYPE_CD,
/* Dec 2013 BSR Voided Claims end */
		G.DGH_GCN_CD AS GCN_CODE,
		G.DRUG_BRAND_CD AS BRAND_GENERIC ,
		G.GENERIC_NDC_IN,
	G.GPI_GROUP||G.GPI_CLASS||G.GPI_SUBCLASS||G.GPI_NAME||G.GPI_NAME_EXTENSION||G.GPI_FORM||G.GPI_STRENGTH AS GPI_THERA_CLS_CD,
		F.CLIENT_NM
	FROM	PTS AS E,
		&CLAIMSA..&CLAIM_HIS_TBL  AS X,
		&CLAIMSA..TCLIENT1  AS F
		&STR_TDRUG1.
	WHERE	E.CLIENT_ID = F.CLIENT_ID
/*Q2X added ADJ_ENGINE_CD since QL migrated clients change code to 2 after migration*/
		AND F.ADJ_ENGINE_CD = 1
		AND X.PT_BENEFICIARY_ID = E.PT_BENEFICIARY_ID
		AND X.DRUG_NDC_ID = E.DRUG_NDC_ID
/* Dec 2013 BSR Voided Claims - changed RXKEY */
		AND E.RXKEY = RTRIM(X.PT_BENEFICIARY_ID)||RTRIM(X.NTW_PRESCRIBER_ID)||RTRIM(X.DRUG_NDC_ID)||JULIAN_DAY(X.FILL_DT)||RTRIM(X.BENEFIT_REQUEST_ID)||RTRIM(X.REFILL_NB)
		AND X.RX_COUNT_QY > 0
		&DRUG_JOIN_CONDITION.
	FETCH FIRST &MAX_ROWS_FETCHED. ROWS ONLY) BY DB2;

	  %PUT Before reset;
          %PUT SQLXRC=&SQLXRC SYSERR=&SYSERR;
          %reset_sql_err_cd;
  * DISCONNECT FROM DB2;
QUIT;
 %set_error_fl;


PROC SQL;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
CREATE TABLE &tbl_name_out3. AS

            SELECT   A.*,     
                         B.BLG_REPORTING_CD , /* NEW FIELDS FROM TCPGRP_CLT_PLN_GR1 */ 
                         B.PLAN_CD,
                         B.PLAN_EXTENSION_CD as PLAN_EXT_CD_TX,
                         B.GROUP_CD,
                         B.GROUP_EXTENSION_CD as GROUP_EXT_CD_TX,
                         B.CLIENT_ID as CLIENT_LEVEL_1 ,
                         B.GROUP_CD as CLIENT_LEVEL_2,
                         B.BLG_REPORTING_CD as CLIENT_LEVEL_3,
                         C.PHARMACY_NM,
                         E.PRESCRIBER_DEA_NB AS DEA_NB,
                         E.PRESCRIBER_NPI_NB


      FROM              &tbl_name_out3._A A 

            LEFT JOIN   &CLAIMSA..TCPGRP_CLT_PLN_GR1 B ON
                              A.CLT_PLAN_GROUP_ID2 = B.CLT_PLAN_GROUP_ID

            LEFT JOIN &CLAIMSA..TPHARM_PHARMACY C ON
                              A.NABP_ID = C.NABP_ID
            LEFT JOIN &CLAIMSA..TPRSCBR_PRESCRIBE1 E ON
                          A.PRESCRIBER_ID = E.PRESCRIBER_ID

;
DISCONNECT FROM DB2;
QUIT;
%set_error_fl;


                          
 PROC SQL NOPRINT;
  SELECT COUNT(*) INTO : COUNT_FOR_&TABLE_PREFIX.PT_DRUG_NM_ql
   FROM &tbl_name_out3.
    ;
 QUIT;

 %IF &&COUNT_FOR_&TABLE_PREFIX.PT_DRUG_NM_ql. >= &MAX_ROWS_FETCHED. %THEN
                                                                        %DO;
                                                        %LET err_fl=1;
%LET Message= The number of extracted rows exceed maximum allowed &MAX_ROWS_FETCHED.;
                                                                        %END;

%IF &err_fl=0 %THEN %PUT Created table &tbl_name_out3.;
%runstats(TBL_NAME=&tbl_name_out3. );



PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);

EXECUTE(CREATE TABLE &tbl_name_out1.
(PRESCRIBER_ID	INTEGER	NOT NULL,
 CDH_BENEFICIARY_ID	INTEGER	NOT NULL,
 PT_BENEFICIARY_ID	INTEGER	NOT NULL,
 MBR_ID	CHARACTER(25)	NOT NULL,
 BIRTH_DT	DATE ,
 DRG_GROUP_SEQ_NB	INTEGER,
 DRG_SUB_GRP_SEQ_NB	INTEGER,
 ADJ_ENGINE	VARCHAR(2) NOT NULL	,
 CLIENT_ID	INTEGER ,
 CLT_PLAN_GROUP_ID2	INTEGER	NOT NULL,
 RX_COUNT_QY	INTEGER	NOT NULL,
 MEMBER_COST_AT	DECIMAL(11,2) NOT NULL	,
 LAST_FILL_DT	DATE NOT NULL	,
 RX_NB	CHARACTER(12)	,
 DISPENSED_QY	DECIMAL(12,3)	,
 DAY_SUPPLY_QY	SMALLINT	,
 REFILL_FILL_QY	SMALLINT	,
 FORMULARY_TX	VARCHAR(30)	,
 LAST_DELIVERY_SYS	SMALLINT	,
 NABP_ID	CHARACTER(7)	,
 DRUG_ABBR_PROD_NM	CHARACTER(12)	,
 DRUG_ABBR_STRG_NM	CHARACTER(8)	,
 DRUG_NDC_ID	DECIMAL(11,0)	,
 NHU_TYPE_CD	SMALLINT	,
 DRUG_ABBR_DSG_NM	CHARACTER(3)	,
 GCN_CODE	INTEGER	,
 BRAND_GENERIC	CHARACTER(1)	,
 GENERIC_NDC_IN	DECIMAL(11,0)	,
 GPI_THERA_CLS_CD	CHARACTER(14)	,
 CLIENT_NM	CHARACTER(30) NOT NULL	,
 BLG_REPORTING_CD	CHARACTER(15)	,
 PLAN_CD	CHARACTER(8)	,
 PLAN_EXT_CD_TX	CHARACTER(8)	,
 GROUP_CD	CHARACTER(15)	,
 GROUP_EXT_CD_TX	CHARACTER(5)	,
 CLIENT_LEVEL_1	INTEGER,
 CLIENT_LEVEL_2	CHARACTER(15)	,
 CLIENT_LEVEL_3	CHARACTER(15)	,
 PHARMACY_NM	CHARACTER(30)	,
 DEA_NB	CHARACTER(9),
 PRESCRIBER_NPI_NB	CHARACTER(10)
 )NOT LOGGED INITIALLY) BY DB2;
   DISCONNECT FROM DB2;
QUIT;



PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);

EXECUTE  (ALTER TABLE &tbl_name_out1. ACTIVATE NOT LOGGED INITIALLY) BY DB2;
EXECUTE	 (INSERT INTO &tbl_name_out1.
                        SELECT   PRESCRIBER_ID,
                                 CDH_BENEFICIARY_ID,
                                 PT_BENEFICIARY_ID,
								 MBR_ID,
                                 MAX(BIRTH_DT) AS BIRTH_DT,
                                 DRG_GROUP_SEQ_NB,
                                 DRG_SUB_GRP_SEQ_NB, 
                                 MAX(&ADJ_ENGINE) as ADJ_ENGINE,
                                 CLIENT_ID,
                                 CLT_PLAN_GROUP_ID2,
                                 RX_COUNT_QY,
                                 MEMBER_COST_AT,
                                 MAX(LAST_FILL_DT)    AS      LAST_FILL_DT,
								 RX_NB,          
	                             DISPENSED_QY,
	                             DAY_SUPPLY_QY,
	                             MAX(REFILL_FILL_QY) AS REFILL_FILL_QY,
								 FORMULARY_TX,
								 LAST_DELIVERY_SYS,
								 NABP_ID,
								 DRUG_ABBR_PROD_NM,
                                 DRUG_ABBR_STRG_NM,
                                 DRUG_NDC_ID,
                                 NHU_TYPE_CD,
	                             DRUG_ABBR_DSG_NM,
	                             GCN_CODE,
								 BRAND_GENERIC,
                                 GENERIC_NDC_IN,
							     GPI_THERA_CLS_CD,
								 CLIENT_NM,
								 BLG_REPORTING_CD , 
                                 PLAN_CD,
                                 PLAN_EXT_CD_TX ,
                                 GROUP_CD,
                                 GROUP_EXT_CD_TX,
                                 CLIENT_LEVEL_1 ,
                                 CLIENT_LEVEL_2,
                                 CLIENT_LEVEL_3,                              
								 PHARMACY_NM,                                     
                                 DEA_NB,
                                 PRESCRIBER_NPI_NB                                     

		FROM  &tbl_name_out3.
                GROUP BY         PRESCRIBER_ID,
                                 CDH_BENEFICIARY_ID,
                                 PT_BENEFICIARY_ID,
								 MBR_ID,
                                 DRG_GROUP_SEQ_NB,
                                 DRG_SUB_GRP_SEQ_NB, 
                                 CLIENT_ID,
                                 CLT_PLAN_GROUP_ID2,
								 DRUG_NDC_ID,
                                 NHU_TYPE_CD,
                                 RX_NB,          
								 RX_COUNT_QY,
                                 MEMBER_COST_AT,
	                             DISPENSED_QY,
	                             DAY_SUPPLY_QY,
								 FORMULARY_TX,
								 LAST_DELIVERY_SYS,
								 NABP_ID,
								 DRUG_ABBR_PROD_NM,
                                 DRUG_ABBR_STRG_NM,                                 
	                             DRUG_ABBR_DSG_NM,
	                             GCN_CODE,
								 BRAND_GENERIC,
                                 GENERIC_NDC_IN,
							     GPI_THERA_CLS_CD,
								 CLIENT_NM,
								 BLG_REPORTING_CD , 
                                 PLAN_CD,
                                 PLAN_EXT_CD_TX ,
                                 GROUP_CD,
                                 GROUP_EXT_CD_TX,
                                 CLIENT_LEVEL_1 ,
                                 CLIENT_LEVEL_2,
                                 CLIENT_LEVEL_3,                              
								 PHARMACY_NM,                                     
                                 DEA_NB,
                                 PRESCRIBER_NPI_NB                                     


      ) BY DB2;
%PUT Before reset;
%PUT SQLXRC=&SQLXRC SYSERR=&SYSERR;
 %reset_sql_err_cd;
* DISCONNECT FROM DB2;
QUIT;

%set_error_fl;
%IF &err_fl=0 %THEN %PUT Updated table &tbl_name_out1.;
%runstats(TBL_NAME=&tbl_name_out1. );

*SASDOC--------------------------------------------------------------------------
| Check for existence of drug group 2 and if it exist execute code based on
| whether the therapy rule is include or exclude.
+------------------------------------------------------------------------SASDOC*;
%IF &DRUG_GROUP2_EXIST_FLAG=1 AND &err_fl=0 %THEN
                                                                        %DO;
DATA _NULL_;
  SET &HERCULES..TINIT_DRUG_GROUP(WHERE=(       INITIATIVE_ID=&INITIATIVE_ID
                                           AND DRG_GROUP_SEQ_NB=2));
IF  TRIM(LEFT(OPERATOR_TX))='NOT' THEN CALL SYMPUT('NULL_CONDITION','IS NULL');
ELSE                                   CALL SYMPUT('NULL_CONDITION','IS NOT NULL');
RUN;
%set_error_fl;


%PUT NULL_CONDITION=&NULL_CONDITION;

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
   EXECUTE(CREATE TABLE &tbl_name_out2. AS
      (  SELECT  * FROM &tbl_name_out1.
      ) DEFINITION ONLY NOT LOGGED INITIALLY
               ) BY DB2;
   EXECUTE
  (ALTER TABLE &tbl_name_out2. ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;
        EXECUTE(INSERT INTO &tbl_name_out2. 
     WITH PTS  AS
                        ( SELECT PT_BENEFICIARY_ID,COUNT(*) AS COUNT
                   FROM &tbl_name_out1. 
                                        WHERE DRG_GROUP_SEQ_NB=2
                                          GROUP BY  PT_BENEFICIARY_ID
                                )
           SELECT A.*
                 FROM &tbl_name_out1. AS A        LEFT JOIN
                 PTS                                                                            AS B
         ON A.PT_BENEFICIARY_ID=B.PT_BENEFICIARY_ID
         WHERE  B.PT_BENEFICIARY_ID &NULL_CONDITION
                        ) BY DB2;
%PUT Before reset;
%PUT SQLXRC=&SQLXRC SYSERR=&SYSERR;
%reset_sql_err_cd;
* DISCONNECT FROM DB2;
QUIT;
%set_error_fl;
%runstats(TBL_NAME=&tbl_name_out2. );
                                                        %END; /* End of &DRUG_GROUP2_EXIST_FLAG = 1*/
%ELSE
                                                                                                                %DO;

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
   EXECUTE(CREATE ALIAS &tbl_name_out2. FOR
                                                &tbl_name_out1.
           ) BY DB2;
        DISCONNECT FROM DB2;
QUIT;
%set_error_fl;
                                                                %END; /* End of &GET_NDC_NDC_TBL_FL = 1 AND &DRUG_GROUP2*/

                                   %END; /* End of &GET_NDC_NDC_TBL_FL = 1 */
%ELSE
                        %DO;
PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE ALIAS &tbl_name_out3.  FOR
                                                &tbl_name_out1. 
           ) BY DB2;
        DISCONNECT FROM DB2;
QUIT;
%set_error_fl;

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE ALIAS &tbl_name_out2. FOR
                                                &tbl_name_out1. 
           ) BY DB2;
        DISCONNECT FROM DB2;
QUIT;
%set_error_fl;
                        %END; /* End of &GET_NDC_NDC_TBL_FL NE 1 */

%IF &err_fl=0 %THEN
                                        %DO;
    %PUT Created table &tbl_name_out3. ;
        %PUT Created table &tbl_name_out2. ;
                                        %END;

/*%table_properties(TBL_NAME=&tbl_name_out1. );*/
/*%table_properties(TBL_NAME=&tbl_name_out3. );*/
/*%table_properties(TBL_NAME=&tbl_name_out2. );*/
%MEND pull_claims_for_ql;
