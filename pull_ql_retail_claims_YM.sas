
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

%macro pull_ql_retail_claims_YM(tbl_name_in1=,tbl_name_in=,tbl_name_out=,
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
%drop_db2_table(tbl_name=&tbl_name_out.);
 PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE TABLE &tbl_name_out. AS
      (  SELECT   			     A.PT_BENEFICIARY_ID ,
                  				 A.CDH_BENEFICIARY_ID ,
                  				 A.CLIENT_ID ,
                  				 A.CLT_PLAN_GROUP_ID as CLT_PLAN_GROUP_ID2 ,
				  				 &ADJ_ENGINE AS ADJ_ENGINE,
                  				 A.PT_BIRTH_DT  AS BIRTH_DT,
                  				 C.DRUG_NDC_ID,
                			     A.NHU_TYPE_CD,
                 				 C.DRUG_ABBR_PROD_NM,
                 				 B.DRUG_CATEGORY_ID,          
								 A.RX_NB,          /* NEW FIELDS FROM TRXCLM_BASE */
								 A.DISPENSED_QY ,
								 A.DAY_SUPPLY_QY,
								 A.REFILL_NB as REFILL_FILL_QY,
								 CAST(A.FORMULARY_ID as varchar(30)) as FORMULARY_TX,
								 C.GENERIC_NDC_IN,/* NEW FIELDS FROM TDRUG */
								 C.DRUG_ABBR_STRG_NM,
								 C.DRUG_ABBR_DSG_NM,
								 H.BLG_REPORTING_CD , /* NEW FIELDS FROM TCPGRP_CLT_PLN_GR1 */ 
								 H.PLAN_CD,
								 H.PLAN_EXTENSION_CD as PLAN_EXT_CD_TX,
								 H.GROUP_CD,
								 H.GROUP_EXTENSION_CD as GROUP_EXT_CD_TX,

								 A.CLIENT_ID as CLIENT_LEVEL_1 ,
							     H.GROUP_CD as CLIENT_LEVEL_2,
								 H.BLG_REPORTING_CD as CLIENT_LEVEL_3,
								 CAST(I.BENEFICIARY_ID as varchar(25)) as MBR_ID,
								 A.DELIVERY_SYSTEM_CD as LAST_DELIVERY_SYS,
								 A.FILL_DT as LAST_FILL_DT,
							     C.DGH_GCN_CD as GCN_CODE,
								 C.DRUG_BRAND_CD as BRAND_GENERIC     ,
								 K.PRESCRIBER_DEA_NB as DEA_NB,
 								 K.PRESCRIBER_NPI_NB,
								 L.PHARMACY_NM,
								 C.GPI_GROUP||C.GPI_CLASS||C.GPI_SUBCLASS||C.GPI_NAME||C.GPI_NAME_EXTENSION||C.GPI_FORM||
  								 C.GPI_STRENGTH AS GPI_THERA_CLS_CD

								 

                          FROM  &CLAIMSA..&CLAIM_HIS_TBL     AS A,
                                &tbl_name_in.                AS B,                             
								&CLAIMSA..TDRUG1             AS C,
						        &CLAIMSA..TCPGRP_CLT_PLN_GR1 AS H,/* Newly added Tables */
								&CLAIMSA..TBENEFICIARY AS I,
								&CLAIMSA..TPRSCBR_PRESCRIBE1 as K,
								&CLAIMSA..TPHARM_PHARMACY AS L
      ) DEFINITION ONLY NOT LOGGED INITIALLY
               ) BY DB2;
   DISCONNECT FROM DB2;
QUIT;

 PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
     EXECUTE(ALTER TABLE &tbl_name_out.
             ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;

     EXECUTE(INSERT INTO &tbl_name_out.
             SELECT
                     A.PT_BENEFICIARY_ID,
                     A.CDH_BENEFICIARY_ID,
                     A.CLIENT_ID,
                     A.CLT_PLAN_GROUP_ID as CLT_PLAN_GROUP_ID2,					 
					 MAX(&ADJ_ENGINE) AS ADJ_ENGINE,
                     MAX(A.PT_BIRTH_DT),
                     MAX(A.DRUG_NDC_ID),
                     MAX(A.NHU_TYPE_CD),
                     C.DRUG_ABBR_PROD_NM,
                     B.DRUG_CATEGORY_ID,

					 A.RX_NB,          /* NEW FIELDS FROM TRXCLM_BASE */
					 A.DISPENSED_QY ,
					 A.DAY_SUPPLY_QY,
					 A.REFILL_NB as REFILL_FILL_QY,
					 CAST(A.FORMULARY_ID as varchar(30)) as FORMULARY_TX,   
					 C.GENERIC_NDC_IN,/* NEW FIELDS FROM TDRUG */
					 C.DRUG_ABBR_STRG_NM,
					 C.DRUG_ABBR_DSG_NM,
					 H.BLG_REPORTING_CD , /* NEW FIELDS FROM TCPGRP_CLT_PLN_GR1 */ 
					 H.PLAN_CD,
					 H.PLAN_EXTENSION_CD as PLAN_EXT_CD_TX,
					 H.GROUP_CD,
					 H.GROUP_EXTENSION_CD as GROUP_EXT_CD_TX,
					 A.CLIENT_ID as CLIENT_LEVEL_1 ,
					 H.GROUP_CD as CLIENT_LEVEL_2,
					 H.BLG_REPORTING_CD as CLIENT_LEVEL_3,
					 CAST(I.BENEFICIARY_ID as varchar(25)) as MBR_ID,
					 A.DELIVERY_SYSTEM_CD as LAST_DELIVERY_SYS,
					 A.FILL_DT as LAST_FILL_DT,
					 C.DGH_GCN_CD as GCN_CODE,
					 C.DRUG_BRAND_CD as BRAND_GENERIC     ,
					 K.PRESCRIBER_DEA_NB as DEA_NB,
 					 K.PRESCRIBER_NPI_NB,
					 L.PHARMACY_NM,
					 C.GPI_GROUP||C.GPI_CLASS||C.GPI_SUBCLASS||C.GPI_NAME||C.GPI_NAME_EXTENSION||C.GPI_FORM||
  					 C.GPI_STRENGTH AS GPI_THERA_CLS_CD

           FROM    &claimsa..&claim_his_tbl A,
                   &tbl_name_in. B,
                   &claimsa..TDRUG1 C,
				   &CLAIMSA..TCPGRP_CLT_PLN_GR1 AS H,/* Newly added Tables */
				   &CLAIMSA..TBENEFICIARY AS I,
				   &CLAIMSA..TPRSCBR_PRESCRIBE1 as K,
				   &CLAIMSA..TPHARM_PHARMACY AS L
				   
           WHERE  A.FILL_DT BETWEEN (CURRENT DATE - &POS_REVIEW_DAYS DAYS) AND CURRENT DATE
/*		     WHERE  A.FILL_DT BETWEEN (&CURRENTDATE - &POS_REVIEW_DAYS DAYS) AND &CURRENTDATE*/
	     AND  A.BILLING_END_DT IS NOT NULL
             AND  A.DELIVERY_SYSTEM_CD = 3
	     &WHERECONS.
             AND  A.DRUG_NDC_ID = B.DRUG_NDC_ID
             AND  A.NHU_TYPE_CD = B.NHU_TYPE_CD
             AND  A.DRUG_NDC_ID = C.DRUG_NDC_ID
             AND  A.NHU_TYPE_CD = C.NHU_TYPE_CD
     		 AND  A.CLT_PLAN_GROUP_ID = H.CLT_PLAN_GROUP_ID  /* Newly added CONDITION FOR JOINING TABLES */
			 AND  A.PT_BENEFICIARY_ID = I.BENEFICIARY_ID 
			 AND  A.NTW_PRESCRIBER_ID = K.PRESCRIBER_ID 
			 AND  A.NABP_ID = L.NABP_ID 
             GROUP BY
                     A.PT_BENEFICIARY_ID,
                     A.CDH_BENEFICIARY_ID,
                     A.CLIENT_ID,
                     A.CLT_PLAN_GROUP_ID,
                     C.DRUG_ABBR_PROD_NM,
                     B.DRUG_CATEGORY_ID,
					 A.RX_NB,          /* NEW FIELDS FROM TRXCLM_BASE */
					 A.DISPENSED_QY,
					 A.DAY_SUPPLY_QY,
					 A.REFILL_NB,
					 CAST(A.FORMULARY_ID as varchar(30)) ,
					 C.DRUG_NDC_ID,   /* NEW FIELDS FROM TDRUG */
					 C.GENERIC_NDC_IN,
					 C.DRUG_ABBR_PROD_NM,
					 C.DRUG_ABBR_STRG_NM,
					 C.DRUG_ABBR_DSG_NM,
					 H.BLG_REPORTING_CD , /* NEW FIELDS FROM TCPGRP_CLT_PLN_GR1 */ 
					 H.PLAN_CD,
					 H.PLAN_EXTENSION_CD,
					 H.GROUP_CD,
					 H.GROUP_EXTENSION_CD,
					 A.CLIENT_ID,
					 H.GROUP_CD,
					 H.BLG_REPORTING_CD,
					 CAST(I.BENEFICIARY_ID as varchar(25)),
					 A.DELIVERY_SYSTEM_CD,
					 A.FILL_DT,
					 C.DGH_GCN_CD,
					 C.DRUG_BRAND_CD,
					 K.PRESCRIBER_DEA_NB,
 					 K.PRESCRIBER_NPI_NB,
					 L.PHARMACY_NM,
					 C.GPI_GROUP,C.GPI_CLASS,C.GPI_SUBCLASS,
					 C.GPI_NAME,C.GPI_NAME_EXTENSION,C.GPI_FORM,
  					 C.GPI_STRENGTH

           HAVING SUM(RX_COUNT_QY)>0
          AND PT_BENEFICIARY_ID NOT IN
                     (SELECT distinct
                             PT_BENEFICIARY_ID
                       FROM   &claimsa..&claim_his_tbl A
/*                       WHERE  A.FILL_DT BETWEEN (&CURRENTDATE - 90 DAYS) AND &CURRENTDATE*/
					   WHERE  A.FILL_DT BETWEEN (CURRENT DATE - 90 DAYS) AND CURRENT DATE
					   AND    A.BILLING_END_DT IS NOT NULL
                       AND    A.DELIVERY_SYSTEM_CD = 2  
                              &WHERECONS.)
      )BY DB2;
  DISCONNECT FROM DB2;
 QUIT;

 %set_error_fl;
 %on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");


 %RUNSTATS(TBL_NAME=&tbl_name_out.);

%mend pull_ql_retail_claims_YM;
