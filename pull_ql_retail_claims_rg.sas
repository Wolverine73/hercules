
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


%macro pull_ql_retail_claims_rg(tbl_name_in1=,tbl_name_in=,tbl_name_out=,
         ADJ_ENGINE=,CLIENT_IDS=);

options mprint mlogic source2 symbolgen;


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

     EXECUTE(CREATE TABLE &tbl_name_out.
                 (PT_BENEFICIARY_ID INTEGER NOT NULL,
                  CDH_BENEFICIARY_ID INTEGER NOT NULL,
                  CLIENT_ID INTEGER NOT NULL,
                  CLT_PLAN_GROUP_ID2 INTEGER NOT NULL,
				  ADJ_ENGINE CHAR(2),
                  BIRTH_DT DATE,
                  DRUG_NDC_ID DECIMAL(11) NOT NULL,
                  NHU_TYPE_CD SMALLINT NOT NULL,
                  DRUG_ABBR_PROD_NM CHAR(12),
                  DRUG_CATEGORY_ID INTEGER ) NOT LOGGED INITIALLY) BY DB2;
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
                     B.DRUG_CATEGORY_ID
           FROM    &claimsa..&claim_his_tbl A,
                   &tbl_name_in. B,
                   &claimsa..TDRUG1 C
           WHERE  A.FILL_DT BETWEEN (CURRENT DATE - &POS_REVIEW_DAYS DAYS) AND CURRENT DATE
	     AND  A.BILLING_END_DT IS NOT NULL
             AND  A.DELIVERY_SYSTEM_CD = 3
	     &WHERECONS.
             AND  A.DRUG_NDC_ID = B.DRUG_NDC_ID
             AND  A.NHU_TYPE_CD = B.NHU_TYPE_CD
             AND  A.DRUG_NDC_ID = C.DRUG_NDC_ID
             AND  A.NHU_TYPE_CD = C.NHU_TYPE_CD

             GROUP BY
                     A.PT_BENEFICIARY_ID,
                     A.CDH_BENEFICIARY_ID,
                     A.CLIENT_ID,
                     A.CLT_PLAN_GROUP_ID,
                     C.DRUG_ABBR_PROD_NM,
                     B.DRUG_CATEGORY_ID
           HAVING SUM(RX_COUNT_QY)>0
          AND PT_BENEFICIARY_ID NOT IN
                     (SELECT distinct
                             PT_BENEFICIARY_ID
                       FROM   &claimsa..&claim_his_tbl A
                       WHERE  A.FILL_DT BETWEEN (CURRENT DATE - 90 DAYS) AND CURRENT DATE
					   AND    A.BILLING_END_DT IS NOT NULL
                       AND    A.DELIVERY_SYSTEM_CD = 2  
                              &WHERECONS. )
      )BY DB2;
  DISCONNECT FROM DB2;
 QUIT;

 %set_error_fl;
 %on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");


 %RUNSTATS(TBL_NAME=&tbl_name_out.);

%mend pull_ql_retail_claims_rg;
