/***HEADER -------------------------------------------------------------------------
 |  MACRO NAME:     PULL_EDW_RETAIL_CLAIMS.SAS
 |
 |  PURPOSE:    TARGETS A CLIENT WHO WOULD LIKE A CUSTOM PROACTIVE MAILING.  THIS
 |              IS A ONE TIME MAILING.
 |              -- Select clients and CPGs
 |              -- get 45 day POS claims
 |              -- do not target if Mail service was used within last 90 days
 |              -- Adjudications are Recap and Rxclaim
 |  INPUT:      
 |                        &ORA_TMP..&TABLE_PREFIX._NDC_RX
 |                        &ORA_TMP..&TABLE_PREFIX._CLT_CPG_RX
 |                         &DSS_CLIN..V_PHMCY_DENORM
 |                        &DSS_CLIN..V_CLAIM_CORE_PAID 
 |                        &DSS_CLIN..V_MBR
 |                        &DSS_CLIN..V_ALGN_LVL_DENORM 
 |
 |  OUTPUT:     Standard datasets in /results and /pending directories
 |
 |
 |  HISTORY:    MAY 2008 - CARL STARKS  Hercules Version  2.1.01
 |                        This is a new macro created to pull claims for Rxclaims 
 |                         and Recap - EDW DATA
 +-------------------------------------------------------------------------------HEADER*/
 
 %macro pull_edw_retail_claims(TBL_NAME_IN1=,TBL_NAME_IN2=,TBL_NAME_OUT=,ADJ=,
        client_level_1=,client_level_2=,client_level_3=,adj2=,
						RESOLVE_CLIENT_EXCLUDE_FLAG=,refill_qy=,CLAIM_TBL=);

  %GLOBAL chk_dt2 ELIG_DT_STREDW2 chk_dt ELIG_DT_STREDW  chk_dt2 
                       POS_REVIEW_DAYS POS_REVIEW_DAYS2  ;

options mprint mlogic source2 symbolgen;


*SASDOC --------------------------------------------------------------------
|   C.J.S MAY2008
|  This data step takes the macro variable flag passed from resolve client
|  and creates a macro variable that will be used to include or exclude
|  claims 
+--------------------------------------------------------------------SASDOC*;

data _null_;

%IF &RESOLVE_CLIENT_EXCLUDE_FLAG = 1 %THEN
                                             %DO;
  
      CALL SYMPUT('CLIENT_COND',TRIM(LEFT("NOT EXISTS")));
%END;
%ELSE %IF 
      &RESOLVE_CLIENT_EXCLUDE_FLAG = 0 %THEN  %do;
       CALL SYMPUT('CLIENT_COND',TRIM(LEFT("EXISTS")));
  %END;
run;

/*%INCLUDE "/PRG/sas&sysmode.1/hercules/macros/delivery_sys_check.sas";*/
/*commented for testing purpose-Sandeep*/
%INCLUDE "/herc&sysmode/prg/hercules/macros/delivery_sys_check.sas";

*SASDOC --------------------------------------------------------------------
|   C.J.S MAY2008
|  Identify the retail maintenance claims during the last &pos_review_days
|  who have not filled any scripts at Mail during the last 90 days. 
+--------------------------------------------------------------------SASDOC*;

      
%LET POS_REVIEW_DAYS=45; 
%let POS_REVIEW_DAYS2 = 90; 
 	
  DATA _NULL_;
  call symput('chk_dt',  "'"||put(today()-&POS_REVIEW_DAYS, YYMMDD10.)||"'");
  call symput('chk_dt2',  "'"||put(today()-&POS_REVIEW_DAYS2, YYMMDD10.)||"'");
  RUN;

 %PUT NOTE: pos dates;
 %put chk_dt =&chk_dt;
 %put chk_dt2=&chk_dt2;
 %PUT NOTE: input output tables;
 %PUT tbl_name_out = &tbl_name_out;
 %PUT tbl_name_in1 = &tbl_name_in1;
 %PUT tbl_name_in2 = &tbl_name_in2;
                        
%put "table to be dropped &tbl_name_out.";

%drop_oracle_table(tbl_name=&tbl_name_out.);


*SASDOC --------------------------------------------------------------------
|   C.J.S MAY2008
|  This proc aql step does a join against various tables in order to pull
|  the retail claims
| 
+--------------------------------------------------------------------SASDOC*;


PROC SQL;
CONNECT TO ORACLE(PATH=&GOLD);
CREATE TABLE &tbl_name_out. as
SELECT * FROM CONNECTION TO ORACLE 
(
 SELECT 
AAA.MBR_GID,
AAA.PAYER_ID,
AAA.PRCTR_GID, 
AAA.ALGN_LVL_GID,
E.QL_BNFCY_ID AS PT_BENEFICIARY_ID,
E.MBR_ID,
E.QL_CARDHLDR_BNFCY_ID AS CDH_BENEFICIARY_ID,
F.QL_CLNT_ID as Client_Id,
F.&client_level_1 as client_level_1,
F.&client_level_2 as client_level_2,
F.&client_level_3 as client_level_3,
&ADJ2 as ADJ_ENGINE,
SUBSTR(AAA.DSPND_DATE,1,10)as LAST_FILL_DT,
MAX(0) AS LTR_RULE_SEQ_NB,
MAX(VCLM.&refill_qy) AS refill_fill_qy,
MAX(D.DRUG_NDC_ID) as DRUG_NDC_ID,
MAX(D.NHU_TYPE_CD) as NHU_TYPE_CD
 FROM &DSS_CLIN..V_CLAIM_CORE_PAID AAA, 
	  &DSS_CLIN..V_PHMCY_DENORM PHMCY,
	  &tbl_name_in1 D,
	  &DSS_CLIN..V_MBR  E,
	  &DSS_CLIN..V_ALGN_LVL_DENORM F,
	  &CLAIM_TBL VCLM
WHERE AAA.PHMCY_GID = PHMCY.PHMCY_GID
  &RETAIL_DELVRY_CD.
  AND AAA.DRUG_GID = D.DRUG_GID
  AND AAA.MBR_GID = E.MBR_GID
  AND AAA.PAYER_ID = E.PAYER_ID
  AND AAA.ALGN_LVL_GID = F.ALGN_LVL_GID_KEY
  AND AAA.MBR_GID = VCLM.MBR_GID
  AND AAA.PAYER_ID = VCLM.PAYER_ID 
  AND AAA.PHMCY_GID = VCLM.PHMCY_GID
  AND AAA.ALGN_LVL_GID =VCLM.ALGN_LVL_GID
  AND AAA.CLAIM_GID = VCLM.CLAIM_GID
  AND F.SRC_SYS_CD IN(&ADJ)
  AND SYSDATE BETWEEN F.ALGN_GRP_EFF_DT AND F.ALGN_GRP_END_DT
  AND AAA.SRC_SYS_CD IN(&ADJ)
  AND AAA.CLAIM_WSHD_CD IN('P','W')
  AND VCLM.BATCH_DATE BETWEEN TO_DATE(&chk_dt,'yyyy-mm-dd')AND SYSDATE
  AND AAA.DSPND_DATE BETWEEN to_date(&chk_dt,'yyyy-mm-dd') AND SYSDATE
  AND AAA.BATCH_DATE IS NOT NULL
  AND &CLIENT_COND (select 1 from &tbl_name_in2  CLT
				WHERE AAA.ALGN_LVL_GID = CLT.ALGN_LVL_GID_KEY
			      AND AAA.PAYER_ID = CLT.PAYER_ID
                  AND CLT.ALGN_LVL_GID_KEY IS NOT NULL
                  AND CLT.PAYER_ID IS NOT NULL 
                                                 )
    AND NOT EXISTS
  (

 SELECT 1
 FROM &DSS_CLIN..V_CLAIM_CORE_PAID AA, 
	  &DSS_CLIN..V_MBR  BB,
 	  &tbl_name_in2  CC,
      &DSS_CLIN..V_PHMCY_DENORM PHMCY

 WHERE AAA.MBR_GID  = AA.MBR_GID
   AND AAA.PAYER_ID = BB.PAYER_ID
   AND AAA.ALGN_LVL_GID = CC.ALGN_LVL_GID_KEY
   AND AAA.PAYER_ID = CC.PAYER_ID
   AND AAA.PHMCY_GID = PHMCY.PHMCY_GID
   AND E.QL_BNFCY_ID = BB.QL_BNFCY_ID
   AND AAA.DSPND_DATE BETWEEN to_date(&chk_dt2,'yyyy-mm-dd') AND SYSDATE
   AND AAA.BATCH_DATE IS NOT NULL 
    &MAIL_DELVRY_CD.
   AND AAA.SRC_SYS_CD IN(&ADJ)
   AND AAA.CLAIM_WSHD_CD IN('P','W')
    )

 GROUP BY 
AAA.MBR_GID,
AAA.PAYER_ID,
AAA.PRCTR_GID, 
AAA.ALGN_LVL_GID,
E.QL_BNFCY_ID,
E.MBR_ID,
E.QL_CARDHLDR_BNFCY_ID,
F.QL_CLNT_ID,
F.&client_level_1,
F.&client_level_2,
F.&client_level_3,
AAA.DSPND_DATE
HAVING SUM(AAA.CLAIM_TYPE) > 0 );
DISCONNECT FROM ORACLE;
quit;


%MEND pull_edw_retail_claims;

