
/***HEADER -------------------------------------------------------------------------
 |  MACRO NAME:     PULL_QL_RETAIL_CLAIMS.SAS
 |
 |  PURPOSE:    TARGETS A CLIENT WHO WOULD LIKE A CUSTOM PROACTIVE MAILING.  THIS
 |              IS A ONE TIME MAILING.
 |              -- Select clients and CPGs
 |              -- get 45 day POS claims
 |              -- do not target if Mail service was used within last 90 days
 |              -- This run for QL only
 |  INPUT:      
 |                        &claimsa..&claim_his_tbl
 |                          &claimsa..TDRUG1
 |
 |  OUTPUT:     Standard datasets in /results and /pending directories
 |
 |
 |  HISTORY:    MAY 2008 - CARL STARKS  Hercules Version  2.1.01
 |                        This is a new macro created to pull claims for QL 
 |                         the logic is the same from the original program.
 |                         the logic was move from the program and made into a macro
 |                         the only change was the input and output files names are
 |                         passed to the macro using macro variables tbl_name_out
 |                         and tnl_name_in 
 +-------------------------------------------------------------------------------HEADER*/

/* -----SAS DOC-------------------------------------------------------------------------
	IMPORTANT SAS DOC INFO: ADD COLUMNS AGD 05.31.12
	Inserted %let CURRENTDATE=%str(date('05/07/2009')) into program 
	to run in test with current test data. make sure all references to currentdate
	are removed before moving to prod and the CURRENT DATE function is put back in
---------------------------------------------------------------------------------------*/
/*%let CURRENTDATE=%str(date('05/07/2009'));*/

%macro pull_ql_retail_claims(tbl_name_in1=,tbl_name_in=,tbl_name_out=,
         ADJ_ENGINE=,CLIENT_IDS=);

/*options mprint mlogic source2 symbolgen;*/
OPTIONS  MPRINT MPRINTNEST MLOGIC MLOGICNEST SYMBOLGEN SOURCE2;

DATA _NULL_;

%IF &RESOLVE_CLIENT_EXCLUDE_FLAG = 1 %THEN %DO;
  
    CALL SYMPUT('CLIENT_COND',TRIM(LEFT("NOT EXISTS")));
%END;
%ELSE %IF 
      &RESOLVE_CLIENT_EXCLUDE_FLAG = 0 %THEN  %DO;
       CALL SYMPUT('CLIENT_COND',TRIM(LEFT("EXISTS")));
%END;
RUN;


%IF &PROGRAM_ID NE 105 %THEN %DO;
   %LET WHERECONS = %STR( 	AND &CLIENT_COND. (SELECT 1 FROM &TBL_NAME_IN1. CLT
                       		WHERE A.CLT_PLAN_GROUP_ID = CLT.CLT_PLAN_GROUP_ID ));
%END;
%ELSE %DO;
   %LET WHERECONS = %STR();
%END;

  PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
    EXECUTE(CREATE INDEX &TBL_NAME_IN.X1
          on &TBL_NAME_IN.
            (NHU_TYPE_CD,
             DRUG_NDC_ID)
          ) BY DB2;
    DISCONNECT FROM DB2;
  QUIT;
  
  %grant(tbl_name=&TBL_NAME_IN.); 
  %RUNSTATS(TBL_NAME=&TBL_NAME_IN.);  


*SASDOC --------------------------------------------------------------------
|
|  Identify the retail maintenance Rx claims during the last &pos_review_days
|  who have not filled any scripts at Mail during the last 90 days.
+--------------------------------------------------------------------SASDOC*;
%drop_db2_table(tbl_name=&tbl_name_out._1);
 PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE TABLE &tbl_name_out._1 
                 (NTW_PRESCRIBER_ID INTEGER,
				  PT_BENEFICIARY_ID INTEGER NOT NULL,
				  CDH_BENEFICIARY_ID INTEGER NOT NULL,
				  MBR_ID CHAR(25),
				  BIRTH_DT DATE,
				  DRUG_NDC_ID DECIMAL(11) NOT NULL,
                  NHU_TYPE_CD SMALLINT NOT NULL,
                  ADJ_ENGINE CHAR(2),
				  CLIENT_ID INTEGER NOT NULL,
                  CLT_PLAN_GROUP_ID2 INTEGER NOT NULL,
				  LAST_FILL_DT DATE,       
				  DRUG_CATEGORY_ID INTEGER ,         
				  REFILL_FILL_QY SMALLINT , 
				  NABP_ID CHAR(7),  
				  RX_NB CHAR(12) ,          /* NEW FIELDS FROM TRXCLM_BASE */
				  RX_COUNT_QY INTEGER,                  
				  DISPENSED_QY DECIMAL(12,3),
				  DAY_SUPPLY_QY SMALLINT,				  
				  FORMULARY_TX CHAR(30),
				  LAST_DELIVERY_SYS SMALLINT				  
			      ) NOT LOGGED INITIALLY)BY DB2;
DISCONNECT FROM DB2;
QUIT;


PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
     EXECUTE(ALTER TABLE &tbl_name_out._1
             ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;

     EXECUTE(INSERT INTO &tbl_name_out._1
             SELECT  A.NTW_PRESCRIBER_ID,
                     A.PT_BENEFICIARY_ID,
					 A.CDH_BENEFICIARY_ID,
					 CAST(A.PT_BENEFICIARY_ID as char(25))as MBR_ID,                     
  					 MAX(A.PT_BIRTH_DT),
					 A.DRUG_NDC_ID,
                     A.NHU_TYPE_CD,
					 MAX(&ADJ_ENGINE) AS ADJ_ENGINE,
					 A.CLIENT_ID,
                     A.CLT_PLAN_GROUP_ID as CLT_PLAN_GROUP_ID2,					 
					 MAX(A.FILL_DT) as LAST_FILL_DT,	
					 MAX(B.DRUG_CATEGORY_ID),
					 MAX(A.REFILL_NB) as REFILL_FILL_QY, 
					 MAX(A.NABP_ID),
					 MAX(A.RX_NB),          /* NEW FIELDS FROM TRXCLM_BASE */
					 MAX(A.RX_COUNT_QY)     AS  RX_COUNT_QY,
					 MAX(A.DISPENSED_QY) ,
					 MAX(A.DAY_SUPPLY_QY),
					 CAST(MAX(A.FORMULARY_ID) as char(30)) as FORMULARY_TX,   
					 MAX(A.DELIVERY_SYSTEM_CD) as LAST_DELIVERY_SYS					 
					 

           FROM    &claimsa..&claim_his_tbl A,
                   &tbl_name_in. B
				   
           WHERE  A.FILL_DT BETWEEN (CURRENT DATE - &POS_REVIEW_DAYS DAYS) AND CURRENT DATE
		     AND  A.BILLING_END_DT IS NOT NULL
             AND  A.DELIVERY_SYSTEM_CD = 3
	     &WHERECONS.
             AND  A.DRUG_NDC_ID = B.DRUG_NDC_ID
             AND  A.NHU_TYPE_CD = B.NHU_TYPE_CD
     		 
             GROUP BY
					 A.NTW_PRESCRIBER_ID,
                     A.PT_BENEFICIARY_ID,
                     A.CDH_BENEFICIARY_ID,
					 A.PT_BENEFICIARY_ID,
					 A.CLIENT_ID,
                     A.CLT_PLAN_GROUP_ID,
					 A.DRUG_NDC_ID,
					 A.NHU_TYPE_CD
					 

           HAVING SUM(RX_COUNT_QY)>0
                     AND PT_BENEFICIARY_ID NOT IN
                     (SELECT distinct
                             PT_BENEFICIARY_ID
                       FROM   &claimsa..&claim_his_tbl A
					   WHERE  A.FILL_DT BETWEEN (CURRENT DATE - 90 DAYS) AND CURRENT DATE
					   AND    A.BILLING_END_DT IS NOT NULL
                       AND    A.DELIVERY_SYSTEM_CD = 2  
                              &WHERECONS.)
      )BY DB2;
  DISCONNECT FROM DB2;
 QUIT;


%drop_db2_table(tbl_name=&tbl_name_out.);

PROC SQL;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
CREATE TABLE &tbl_name_out. AS
			  SELECT 
					 A.*,	 
					 H.BLG_REPORTING_CD , /* NEW FIELDS FROM TCPGRP_CLT_PLN_GR1 */ 
					 H.PLAN_CD,
					 H.PLAN_EXTENSION_CD as PLAN_EXT_CD_TX,
					 H.GROUP_CD,
					 H.GROUP_EXTENSION_CD as GROUP_EXT_CD_TX,
					 H.CLIENT_ID as CLIENT_LEVEL_1,
					 H.GROUP_CD as CLIENT_LEVEL_2,
					 H.BLG_REPORTING_CD as CLIENT_LEVEL_3,
					 L.PHARMACY_NM,
					 I.DRUG_ABBR_PROD_NM,
					 I.GENERIC_NDC_IN,/* NEW FIELDS FROM TDRUG */
					 I.DRUG_ABBR_STRG_NM,
					 I.DRUG_ABBR_DSG_NM,
					 I.DGH_GCN_CD as GCN_CODE,
					 I.DRUG_BRAND_CD as BRAND_GENERIC,
				     I.GPI_GROUP||I.GPI_CLASS||I.GPI_SUBCLASS||I.GPI_NAME||I.GPI_NAME_EXTENSION||I.GPI_FORM||I.GPI_STRENGTH AS GPI_THERA_CLS_CD,
					 K.PRESCRIBER_DEA_NB as DEA_NB,
 					 K.PRESCRIBER_NPI_NB
					 
	   FROM &tbl_name_out._1 A LEFT JOIN 
			&CLAIMSA..TCPGRP_CLT_PLN_GR1 H 
			ON  A.CLT_PLAN_GROUP_ID2 = H.CLT_PLAN_GROUP_ID	

			LEFT JOIN &CLAIMSA..TPHARM_PHARMACY L
		   	ON  A.NABP_ID = L.NABP_ID

			LEFT JOIN &CLAIMSA..TDRUG1 I
			ON A.DRUG_NDC_ID = I.DRUG_NDC_ID
				AND A.NHU_TYPE_CD = I.NHU_TYPE_CD

			LEFT JOIN &CLAIMSA..TPRSCBR_PRESCRIBE1 K
			ON A.NTW_PRESCRIBER_ID = K.PRESCRIBER_ID 
;
DISCONNECT FROM DB2;
QUIT;

/* PROC SQL;*/
/*   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);*/
/*   EXECUTE(CREATE TABLE &tbl_name_out.*/
/*                 (PT_BENEFICIARY_ID INTEGER NOT NULL,*/
/*                  CDH_BENEFICIARY_ID INTEGER NOT NULL,*/
/*                  CLIENT_ID INTEGER NOT NULL,*/
/*                  CLT_PLAN_GROUP_ID2 INTEGER NOT NULL,*/
/*				  ADJ_ENGINE CHAR(2),*/
/*                  BIRTH_DT DATE,*/
/*                  DRUG_NDC_ID DECIMAL(11) NOT NULL,*/
/*                  NHU_TYPE_CD SMALLINT NOT NULL,*/
/*                  DRUG_ABBR_PROD_NM CHAR(12),*/
/*                  DRUG_CATEGORY_ID INTEGER ,         */
/*				  RX_NB CHAR(12) ,          /* NEW FIELDS FROM TRXCLM_BASE */*/
/*				  DISPENSED_QY DECIMAL(11),*/
/*				  DAY_SUPPLY_QY SMALLINT,*/
/*				  REFILL_FILL_QY SMALLINT ,*/
/*				  FORMULARY_TX CHAR(30),*/
/*				  GENERIC_NDC_IN DECIMAL(11)    ,/* NEW FIELDS FROM TDRUG */*/
/*								 DRUG_ABBR_STRG_NM  CHAR(8) , */
/*								 DRUG_ABBR_DSG_NM CHAR(3),*/
/*								 CLIENT_LEVEL_1 INTEGER,*/
/*							     LAST_DELIVERY_SYS SMALLINT  ,*/
/*								 LAST_FILL_DT DATE,*/
/*							     GCN_CODE INTEGER,*/
/*								 BRAND_GENERIC CHAR(1)    ,*/
/*								 GPI_THERA_CLS_CD CHAR(14),	 */
/*								 NTW_PRESCRIBER_ID INTEGER,*/
/*								 NABP_ID CHAR(7),*/
/*								 BLG_REPORTING_CD CHAR(15) , /* NEW FIELDS FROM TCPGRP_CLT_PLN_GR1 */ */
/*								 PLAN_CD CHAR(8),*/
/*								 PLAN_EXT_CD_TX CHAR(8),*/
/*								 GROUP_CD CHAR(15),*/
/*								 GROUP_EXT_CD_TX CHAR(5),*/
/* 								 CLIENT_LEVEL_2 CHAR(15),*/
/*								 CLIENT_LEVEL_3 CHAR(15) ,*/
/*								 MBR_ID CHAR(25),*/
/*								 DEA_NB CHAR(9),*/
/* 								 PRESCRIBER_NPI_NB CHAR(10),*/
/*								 PHARMACY_NM CHAR(35)*/
/*								 ) NOT LOGGED INITIALLY) BY DB2;*/
/*   DISCONNECT FROM DB2;*/
/* QUIT;*/
/**/
/**/
/*PROC SQL;*/
/*    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);*/
/*     EXECUTE(ALTER TABLE &tbl_name_out.*/
/*             ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;*/
/**/
/*     EXECUTE(INSERT INTO &tbl_name_out.*/
/*             SELECT  A.*,	 */
/*					 H.BLG_REPORTING_CD , /* NEW FIELDS FROM TCPGRP_CLT_PLN_GR1 */ */
/*					 H.PLAN_CD,*/
/*					 H.PLAN_EXTENSION_CD as PLAN_EXT_CD_TX,*/
/*					 H.GROUP_CD,*/
/*					 H.GROUP_EXTENSION_CD as GROUP_EXT_CD_TX,*/
/*					 H.GROUP_CD as CLIENT_LEVEL_2,*/
/*					 H.BLG_REPORTING_CD as CLIENT_LEVEL_3,*/
/*					 CAST(I.BENEFICIARY_ID as varchar(25)) as MBR_ID,*/
/*					 K.PRESCRIBER_DEA_NB as DEA_NB,*/
/* 					 K.PRESCRIBER_NPI_NB,*/
/*					 L.PHARMACY_NM*/
/*			FROM 		&tbl_name_out._1 A*/
/*			LEFT JOIN  &CLAIMSA..TCPGRP_CLT_PLN_GR1 AS H */
/*			ON  A.CLT_PLAN_GROUP_ID2 = H.CLT_PLAN_GROUP_ID	*/
/*	*/
/*			LEFT JOIN  &CLAIMSA..TBENEFICIARY AS I*/
/*			ON A.PT_BENEFICIARY_ID = I.BENEFICIARY_ID */
/**/
/*			LEFT JOIN	&CLAIMSA..TPRSCBR_PRESCRIBE1 as K*/
/*			ON A.NTW_PRESCRIBER_ID = K.PRESCRIBER_ID */
/**/
/*			LEFT JOIN 	&CLAIMSA..TPHARM_PHARMACY AS L*/
/*		   	ON  A.NABP_ID = L.NABP_ID;*/
/**/
/*   GROUP BY  A.PT_BENEFICIARY_ID,*/
/*                     A.CDH_BENEFICIARY_ID,*/
/*                     A.CLIENT_ID,*/
/*                     A.CLT_PLAN_GROUP_ID2,*/
/*					 A.ADJ_ENGINE,*/
/*					 A.BIRTH_DT,*/
/*					 A.NHU_TYPE_CD,*/
/*                     A.DRUG_ABBR_PROD_NM,*/
/*                     A.DRUG_CATEGORY_ID,*/
/*					 A.RX_NB,          /* NEW FIELDS FROM TRXCLM_BASE */*/
/*					 A.DISPENSED_QY,*/
/*					 A.DAY_SUPPLY_QY,*/
/*					 A.REFILL_FILL_QY,*/
/*					 FORMULARY_TX ,*/
/*					 A.DRUG_NDC_ID,   /* NEW FIELDS FROM TDRUG */*/
/*					 A.GENERIC_NDC_IN,*/
/*					 A.DRUG_ABBR_PROD_NM,*/
/*					 A.DRUG_ABBR_STRG_NM,*/
/*					 A.DRUG_ABBR_DSG_NM,*/
/*					 A.CLIENT_LEVEL_1,*/
/*					 A.LAST_DELIVERY_SYS,*/
/*					 A.LAST_FILL_DT,*/
/*					 A.GCN_CODE,*/
/*					 A.BRAND_GENERIC,*/
/*					 A.GPI_THERA_CLS_CD,*/
/*					 A.NTW_PRESCRIBER_ID,*/
/*					 A.NABP_ID,*/
/*					 H.BLG_REPORTING_CD , */
/*					 H.PLAN_CD,*/
/*					 H.PLAN_EXTENSION_CD,*/
/*					 H.GROUP_CD,*/
/*					 H.GROUP_EXTENSION_CD,*/
/*					  H.GROUP_CD,*/
/*					  H.BLG_REPORTING_CD,*/
/*					 CAST(I.BENEFICIARY_ID as varchar(25)),*/
/*					  K.PRESCRIBER_DEA_NB,*/
/* 					 K.PRESCRIBER_NPI_NB,*/
/*					 L.PHARMACY_NM*/


 )BY DB2;
/*  DISCONNECT FROM DB2;*/
/* QUIT;*/
 %set_error_fl;
 %on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");


 %RUNSTATS(TBL_NAME=&tbl_name_out.);

%mend pull_ql_retail_claims;
