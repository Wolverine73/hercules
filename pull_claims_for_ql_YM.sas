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
 +-------------------------------------------------------------------------------HEADER*/
 

OPTIONS MPRINT MPRINTNEST MLOGIC MLOGICNEST SYMBOLGEN SOURCE2;

%MACRO pull_claims_for_ql_YM(tbl_name_in1=, tbl_name_in2=,tbl_name_in3=,
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
	   %LET WHERECONS = %STR( 	AND &CLIENT_COND. (SELECT 1 FROM &TBL_NAME_IN1. CLT
					WHERE A.CLIENT_ID = CLT.CLIENT_ID ));
   %END;
   %ELSE %DO;
	   %LET WHERECONS = %STR( 	AND &CLIENT_COND. (SELECT 1 FROM &TBL_NAME_IN1. CLT
					WHERE A.CLT_PLAN_GROUP_ID = CLT.CLT_PLAN_GROUP_ID ));
   %END;
%END;
%ELSE %DO;
   %LET WHERECONS = %STR();
%END;

/*   %LET WHERECONS = %STR( 	AND &CLIENT_COND. (SELECT 1 FROM &TBL_NAME_IN1. CLT*/
/*                       		WHERE A.CLT_PLAN_GROUP_ID = CLT.CLT_PLAN_GROUP_ID ));*/

%PUT "CLIENT SET-UP WHERECONS = &WHERECONS.";

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE TABLE &tbl_name_out1. AS
      (  SELECT                  A.NTW_PRESCRIBER_ID AS PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID,
                                 A.PT_BENEFICIARY_ID,
                                 A.PT_BIRTH_DT          AS BIRTH_DT,
                                 B.DRG_GROUP_SEQ_NB,
                                 B.DRG_SUB_GRP_SEQ_NB,
								 &ADJ_ENGINE AS ADJ_ENGINE,
								 A.CLIENT_ID,
								 A.CLT_PLAN_GROUP_ID as CLT_PLAN_GROUP_ID2,
                                 A.RX_COUNT_QY,
                                 A.MEMBER_COST_AT,
                                 A.FILL_DT  AS LAST_FILL_DT ,

								 D.DRUG_ABBR_PROD_NM,/* NEW FIELDS FROM TDRUG */
								 D.DRUG_ABBR_STRG_NM,
								 D.DRUG_NDC_ID,
								 D.NHU_TYPE_CD,/* EXTRA FIELD ADDED SO AS TO MATCH TABLE 3 DEFINATION WHICH IS USEFULE TO CREAT DEFINATION TABLE2 */	 

								 A.RX_NB,          /* NEW FIELDS FROM TRXCLM_BASE */
								 A.DISPENSED_QY ,
								 A.DAY_SUPPLY_QY,
								 A.REFILL_NB as REFILL_FILL_QY,
								 CAST(A.FORMULARY_ID as varchar(30)) as FORMULARY_TX,
								 
								 D.GENERIC_NDC_IN,/* NEW FIELDS FROM TDRUG */								 
								 D.DRUG_ABBR_DSG_NM,

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
							     D.DGH_GCN_CD as GCN_CODE,
								 D.DRUG_BRAND_CD as BRAND_GENERIC     ,
								 K.PRESCRIBER_DEA_NB as DEA_NB,
 								 K.PRESCRIBER_NPI_NB,
								 L.PHARMACY_NM,
								 D.GPI_GROUP||D.GPI_CLASS||D.GPI_SUBCLASS||D.GPI_NAME||D.GPI_NAME_EXTENSION||D.GPI_FORM||
  								 D.GPI_STRENGTH AS GPI_THERA_CLS_CD,
	
                                 C.CLIENT_NM /* This field is not a new field added.It is already present in code */
                          FROM  &CLAIMSA..&CLAIM_HIS_TBL AS A,
                                &tbl_name_in2.      AS B,
                                &CLAIMSA..TCLIENT1  AS C,
								&CLAIMSA..TDRUG1    AS D, /* Newly added Tables */
						        &CLAIMSA..TCPGRP_CLT_PLN_GR1 AS H,
								&CLAIMSA..TBENEFICIARY AS I,
								&CLAIMSA..TPRSCBR_PRESCRIBE1 as K,
								&CLAIMSA..TPHARM_PHARMACY AS L


      ) DEFINITION ONLY NOT LOGGED INITIALLY
               ) BY DB2;
   DISCONNECT FROM DB2;
QUIT;
 %set_error_fl;

%PUT CLAIMS_TBL=&CLAIMSA..&CLAIM_HIS_TBL;
*SASDOC--------------------------------------------------------------------------
|  The code below executes only if no drug information is required and
|  the drug group1 is all drugs
+------------------------------------------------------------------------SASDOC*;
%IF &ALL_DRUG_IN1=1 AND &DRUG_FIELDS_LIST=%STR() %THEN
                   %DO;

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
EXECUTE
  (ALTER TABLE &tbl_name_out1. ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;

EXECUTE(INSERT INTO &tbl_name_out1.
        WITH PTS AS
                (SELECT          A.NTW_PRESCRIBER_ID AS PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID,
                                 A.PT_BENEFICIARY_ID,
                                 MAX(A.PT_BIRTH_DT)     AS BIRTH_DT,
                                 MAX(1)                 AS DRG_GROUP_SEQ_NB,
                                 MAX(1)                 AS DRG_SUB_GRP_SEQ_NB,
                                 MAX(&ADJ_ENGINE) as ADJ_ENGINE,
                                 A.CLIENT_ID,
								 A.CLT_PLAN_GROUP_ID as CLT_PLAN_GROUP_ID2,
                                 SUM(A.RX_COUNT_QY)     AS  RX_COUNT_QY,
                                 SUM(A.MEMBER_COST_AT)  AS  MEMBER_COST_AT,
                                 MAX(A.FILL_DT)         AS LAST_FILL_DT,

								 D.DRUG_ABBR_PROD_NM,/* NEW FIELDS FROM TDRUG */
								 D.DRUG_ABBR_STRG_NM,
								 D.DRUG_NDC_ID,
								 D.NHU_TYPE_CD,/* EXTRA FIELD ADDED SO AS TO MATCH TABLE 3 DEFINATION WHICH IS USEFULE TO CREAT DEFINATION TABLE2 */	 

								 A.RX_NB,          /* NEW FIELDS FROM TRXCLM_BASE */
								 A.DISPENSED_QY ,
								 A.DAY_SUPPLY_QY,
								 A.REFILL_NB as REFILL_FILL_QY,
								 CAST(A.FORMULARY_ID as varchar(30)) as FORMULARY_TX,
								 
								 D.GENERIC_NDC_IN,/* NEW FIELDS FROM TDRUG */								 
								 D.DRUG_ABBR_DSG_NM,

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
							     D.DGH_GCN_CD as GCN_CODE,
								 D.DRUG_BRAND_CD as BRAND_GENERIC     ,
								 K.PRESCRIBER_DEA_NB as DEA_NB,
 								 K.PRESCRIBER_NPI_NB,
								 L.PHARMACY_NM,
								 D.GPI_GROUP||D.GPI_CLASS||D.GPI_SUBCLASS||D.GPI_NAME||D.GPI_NAME_EXTENSION||D.GPI_FORM||
  								 D.GPI_STRENGTH AS GPI_THERA_CLS_CD
								
                 FROM    &CLAIMSA..&CLAIM_HIS_TBL     AS A,
						 &CLAIMSA..TDRUG1             AS D,/* Newly added Tables */
						 &CLAIMSA..TCPGRP_CLT_PLN_GR1 AS H,
						 &CLAIMSA..TBENEFICIARY AS I,
						 &CLAIMSA..TPRSCBR_PRESCRIBE1 as K,
						 &CLAIMSA..TPHARM_PHARMACY AS L
         WHERE  A.DRUG_NDC_ID = D.DRUG_NDC_ID AND /* Newly added CONDITION FOR JOINING TABLES */
				A.CLT_PLAN_GROUP_ID = H.CLT_PLAN_GROUP_ID AND
				A.PT_BENEFICIARY_ID = I.BENEFICIARY_ID AND
				A.NTW_PRESCRIBER_ID = K.PRESCRIBER_ID AND
				A.NABP_ID = L.NABP_ID AND
                A.FILL_DT BETWEEN &CLAIM_BEGIN_DT1. AND &CLAIM_END_DT1./* ORIGINAL PROGRAM CONDITION  */
                  &WHERECONS.
                  &DELIVERY_SYSTEM_CONDITION.
         AND NOT EXISTS
              (SELECT 1
               FROM &CLAIMSA..&CLAIM_HIS_TBL
               WHERE A.BENEFIT_REQUEST_ID = BENEFIT_REQUEST_ID
               AND   A.BRLI_NB = BRLI_NB
               AND   BRLI_VOID_IN > 0)
                        GROUP BY A.NTW_PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID,
                                 A.PT_BENEFICIARY_ID,
                                 A.CLIENT_ID,
								 A.CLT_PLAN_GROUP_ID,

								 D.DRUG_ABBR_PROD_NM,/* NEW FIELDS FROM TDRUG */
								 D.DRUG_ABBR_STRG_NM,
								 D.DRUG_NDC_ID,
								 D.NHU_TYPE_CD,/* EXTRA FIELD ADDED SO AS TO MATCH TABLE 3 DEFINATION WHICH IS USEFULE TO CREAT DEFINATION TABLE2 */	 

								 A.RX_NB,          /* NEW FIELDS FROM TRXCLM_BASE */
								 A.DISPENSED_QY,
								 A.DAY_SUPPLY_QY,
								 A.REFILL_NB,
								 CAST(A.FORMULARY_ID as varchar(30)),
								 
								 D.GENERIC_NDC_IN,/* NEW FIELDS FROM TDRUG */								 
								 D.DRUG_ABBR_DSG_NM,

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
							     D.DGH_GCN_CD,
								 D.DRUG_BRAND_CD,
								 K.PRESCRIBER_DEA_NB,
 								 K.PRESCRIBER_NPI_NB,
								 L.PHARMACY_NM,
								 D.GPI_GROUP,D.GPI_CLASS,D.GPI_SUBCLASS,
								 D.GPI_NAME,D.GPI_NAME_EXTENSION,D.GPI_FORM,
  								 D.GPI_STRENGTH
                )
                SELECT E.*,
                           F.CLIENT_NM
                        FROM    PTS                                     AS E,
                                        &CLAIMSA..TCLIENT1              AS F
                      WHERE   E.CLIENT_ID = F.CLIENT_ID

      ) BY DB2;
          %PUT Before reset;
          %PUT SQLXRC=&SQLXRC SYSERR=&SYSERR;
      %reset_sql_err_cd;
   *  DISCONNECT FROM DB2;
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

%IF &GET_NDC_NDC_TBL_FL=1 %THEN
                                        %DO;
   PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE TABLE &tbl_name_out3.      AS
      (  SELECT  A.NTW_PRESCRIBER_ID AS PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID,
                                 A.PT_BENEFICIARY_ID,
                                 A.PT_BIRTH_DT AS BIRTH_DT,
                                 D.DRG_GROUP_SEQ_NB,
                                 D.DRG_SUB_GRP_SEQ_NB,
								 &ADJ_ENGINE AS ADJ_ENGINE,
                                 A.CLIENT_ID,
								 A.CLT_PLAN_GROUP_ID as CLT_PLAN_GROUP_ID2,
                                 A.RX_COUNT_QY,
                                 A.MEMBER_COST_AT,
                                 A.FILL_DT            AS LAST_FILL_DT                             
                                 &DRUG_FIELDS_LIST_NDC.,

								 A.RX_NB,          /* NEW FIELDS FROM TRXCLM_BASE */
								 A.DISPENSED_QY ,
								 A.DAY_SUPPLY_QY,
				                 A.REFILL_NB as REFILL_FILL_QY,
								 CAST(A.FORMULARY_ID as varchar(30)) as FORMULARY_TX,

								 G.GENERIC_NDC_IN,
								 G.DRUG_ABBR_DSG_NM,

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
							     G.DGH_GCN_CD as GCN_CODE,
								 G.DRUG_BRAND_CD as BRAND_GENERIC     ,
								 K.PRESCRIBER_DEA_NB as DEA_NB,
 								 K.PRESCRIBER_NPI_NB,
								 L.PHARMACY_NM,
								 G.GPI_GROUP||G.GPI_CLASS||G.GPI_SUBCLASS||G.GPI_NAME||G.GPI_NAME_EXTENSION||G.GPI_FORM||
  								 G.GPI_STRENGTH AS GPI_THERA_CLS_CD,

								 C.CLIENT_NM /* This field is not a new field added.It is already present in code */
                          FROM  &CLAIMSA..&CLAIM_HIS_TBL                        AS A,
                                &CLAIMSA..TCLIENT1                              AS C,
                                &tbl_name_in2.                                  AS D,								
								&CLAIMSA..TDRUG1                                AS G,
								&CLAIMSA..TCPGRP_CLT_PLN_GR1                    AS H, /* Newly added Tables */
								&CLAIMSA..TBENEFICIARY AS I,
								&CLAIMSA..TPRSCBR_PRESCRIBE1 as K,
								&CLAIMSA..TPHARM_PHARMACY AS L
      )DEFINITION ONLY NOT LOGGED INITIALLY
               ) BY DB2;
   DISCONNECT FROM DB2;
QUIT;
%set_error_fl;


PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
EXECUTE
  (ALTER TABLE &tbl_name_out3. ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;
EXECUTE(INSERT INTO &tbl_name_out3.
                WITH PTS AS
        (SELECT                  A.NTW_PRESCRIBER_ID    AS PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID,
                                 A.PT_BENEFICIARY_ID,
                                 MAX(A.PT_BIRTH_DT)     AS BIRTH_DT,
                                 B.DRG_GROUP_SEQ_NB,
                                 B.DRG_SUB_GRP_SEQ_NB,
                                 MAX(&ADJ_ENGINE) as ADJ_ENGINE,
                                 A.CLIENT_ID,
								 A.CLT_PLAN_GROUP_ID as CLT_PLAN_GROUP_ID2,
                                 D.DRUG_NDC_ID,
                                 D.NHU_TYPE_CD,
                                 SUM(A.RX_COUNT_QY) AS  RX_COUNT_QY,
                                 SUM(A.MEMBER_COST_AT)  AS  MEMBER_COST_AT,
                                 MAX(FILL_DT)           AS  LAST_FILL_DT,

								 A.RX_NB,          /* NEW FIELDS FROM TRXCLM_BASE */
								 A.DISPENSED_QY ,
								 A.DAY_SUPPLY_QY ,
				 				 A.REFILL_NB as REFILL_FILL_QY ,
				                 CAST(A.FORMULARY_ID as varchar(30)) as FORMULARY_TX,

								 G.GENERIC_NDC_IN,
								 G.DRUG_ABBR_DSG_NM,

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
							     G.DGH_GCN_CD as GCN_CODE,
								 G.DRUG_BRAND_CD as BRAND_GENERIC     ,
								 K.PRESCRIBER_DEA_NB as DEA_NB,
 								 K.PRESCRIBER_NPI_NB,
								 L.PHARMACY_NM,
								 G.GPI_GROUP||G.GPI_CLASS||G.GPI_SUBCLASS||G.GPI_NAME||G.GPI_NAME_EXTENSION||G.GPI_FORM||
  								 G.GPI_STRENGTH AS GPI_THERA_CLS_CD

                 FROM    &CLAIMSA..&CLAIM_HIS_TBL           AS A,
                         &tbl_name_in2.                     AS B,
                         &tbl_name_in3.                     AS D,						 
						 &CLAIMSA..TDRUG1                   AS G,/* Newly added Tables */
						 &CLAIMSA..TCPGRP_CLT_PLN_GR1       AS H,
						 &CLAIMSA..TBENEFICIARY AS I,
						 &CLAIMSA..TPRSCBR_PRESCRIBE1 as K,
						 &CLAIMSA..TPHARM_PHARMACY AS L
        WHERE (   (B.ALL_DRUG_IN=0)
                           OR (&DRUG_FIELDS_FLAG=1 AND B.ALL_DRUG_IN=1))
                   AND    A.FILL_DT BETWEEN CLAIM_BEGIN_DT AND CLAIM_END_DT
                   AND    B.DRG_GROUP_SEQ_NB=D.DRG_GROUP_SEQ_NB
                   AND    B.DRG_SUB_GRP_SEQ_NB=D.DRG_SUB_GRP_SEQ_NB
                   AND    A.DRUG_NDC_ID = D.DRUG_NDC_ID
                   AND    A.NHU_TYPE_CD = D.NHU_TYPE_CD
				   AND    A.DRUG_NDC_ID = G.DRUG_NDC_ID /* Newly added CONDITION FOR JOINING TABLES */
				   AND    A.CLT_PLAN_GROUP_ID = H.CLT_PLAN_GROUP_ID
				   AND    A.PT_BENEFICIARY_ID = I.BENEFICIARY_ID
				   AND    A.NTW_PRESCRIBER_ID = K.PRESCRIBER_ID 
				   AND    A.NABP_ID = L.NABP_ID 
                  &WHERECONS.
                  &DELIVERY_SYSTEM_CONDITION.
         AND NOT EXISTS
              (SELECT 1
               FROM &CLAIMSA..&CLAIM_HIS_TBL
               WHERE A.BENEFIT_REQUEST_ID = BENEFIT_REQUEST_ID
               AND   A.BRLI_NB = BRLI_NB
               AND   BRLI_VOID_IN > 0)
                       GROUP BY  A.NTW_PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID,
                                 A.PT_BENEFICIARY_ID,
                                 B.DRG_GROUP_SEQ_NB,
                                 B.DRG_SUB_GRP_SEQ_NB,
                                 D.DRUG_NDC_ID,
                                 D.NHU_TYPE_CD,
                                 A.CLIENT_ID,
								 A.CLT_PLAN_GROUP_ID,
								 A.RX_NB,          /* NEW FIELDS FROM TRXCLM_BASE */
								 A.DISPENSED_QY,
								 A.DAY_SUPPLY_QY,
				 				 A.REFILL_NB,
				                 CAST(A.FORMULARY_ID as varchar(30)),
                                 G.GENERIC_NDC_IN,  /* NEW FIELDS FROM TDRUG1 */
								 G.DRUG_ABBR_DSG_NM,
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
							     G.DGH_GCN_CD,
								 G.DRUG_BRAND_CD,
								 K.PRESCRIBER_DEA_NB,
 								 K.PRESCRIBER_NPI_NB,
								 L.PHARMACY_NM,
								 G.GPI_GROUP,G.GPI_CLASS,G.GPI_SUBCLASS,
								 G.GPI_NAME,G.GPI_NAME_EXTENSION,G.GPI_FORM,
  								 G.GPI_STRENGTH


           FETCH FIRST &MAX_ROWS_FETCHED. ROWS ONLY )
                 SELECT          E.PRESCRIBER_ID,
                                 E.CDH_BENEFICIARY_ID,
                                 E.PT_BENEFICIARY_ID,
                                 E.BIRTH_DT,
                                 E.DRG_GROUP_SEQ_NB,
                                 E.DRG_SUB_GRP_SEQ_NB,
								 &ADJ_ENGINE as ADJ_ENGINE,
                                 E.CLIENT_ID,
                                 E.CLT_PLAN_GROUP_ID2,
                                 E.RX_COUNT_QY,
                                 E.MEMBER_COST_AT,
                                 E.LAST_FILL_DT                                 
                                 &DRUG_FIELDS_LIST_NDC.,
							     E.RX_NB,          /* NEW FIELDS FROM TRXCLM_BASE BUT HERE IT IS PULLED FROM PTS (E) */
								 E.DISPENSED_QY,
								 E.DAY_SUPPLY_QY,
				                 E.REFILL_FILL_QY,
				                 E.FORMULARY_TX,
								 E.GENERIC_NDC_IN, /* NEW FIELDS FROM TDRUG1 BUT HERE IT IS PULLED FROM PTS (E) */
								 E.DRUG_ABBR_DSG_NM,
								 E.BLG_REPORTING_CD , /* NEW FIELDS FROM TCPGRP_CLT_PLN_GR1 BUT HERE IT IS PULLED FROM PTS (E) */ 
								 E.PLAN_CD,
								 E.PLAN_EXT_CD_TX,
								 E.GROUP_CD,
								 E.GROUP_EXT_CD_TX,

								 E.CLIENT_LEVEL_1 ,
							     E.CLIENT_LEVEL_2,
								 E.CLIENT_LEVEL_3,
								 E.MBR_ID,
								 E.LAST_DELIVERY_SYS,
							     E.GCN_CODE,
								 E.BRAND_GENERIC,
								 E.DEA_NB,
 								 E.PRESCRIBER_NPI_NB,
								 E.PHARMACY_NM,
                                 E.GPI_THERA_CLS_CD,
								 F.CLIENT_NM
                        FROM    PTS                 AS E,
                                &CLAIMSA..TCLIENT1  AS F
                                &STR_TDRUG1.
                      WHERE  E.CLIENT_ID = F.CLIENT_ID
                                &DRUG_JOIN_CONDITION.

      FETCH FIRST &MAX_ROWS_FETCHED. ROWS ONLY) BY DB2;
          %PUT Before reset;
          %PUT SQLXRC=&SQLXRC SYSERR=&SYSERR;
          %reset_sql_err_cd;
  * DISCONNECT FROM DB2;
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
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
EXECUTE
  (ALTER TABLE &tbl_name_out1. ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;
EXECUTE(INSERT INTO &tbl_name_out1.
                        SELECT   PRESCRIBER_ID,
                                 CDH_BENEFICIARY_ID,
                                 PT_BENEFICIARY_ID,
                                 MAX(BIRTH_DT) AS BIRTH_DT,
                                 DRG_GROUP_SEQ_NB,
                                 DRG_SUB_GRP_SEQ_NB, 
                                 MAX(&ADJ_ENGINE) as ADJ_ENGINE,
                                 CLIENT_ID,
                                 CLT_PLAN_GROUP_ID2,
                                 SUM(RX_COUNT_QY)   AS    RX_COUNT_QY,
                                 SUM(MEMBER_COST_AT)  AS  MEMBER_COST_AT,
                                 MAX(LAST_FILL_DT)    AS      LAST_FILL_DT,

								 DRUG_ABBR_PROD_NM,/* NEW FIELDS FROM TDRUG */
								 DRUG_ABBR_STRG_NM,
								 DRUG_NDC_ID,
								 NHU_TYPE_CD,/* EXTRA FIELD ADDED SO AS TO MATCH TABLE 3 DEFINATION WHICH IS USEFULE TO CREAT DEFINATION TABLE2 */	 

								 RX_NB,          /* NEW FIELDS FROM TRXCLM_BASE */
								 DISPENSED_QY,
								 DAY_SUPPLY_QY,
								 REFILL_FILL_QY,
								 FORMULARY_TX,
								 
								 GENERIC_NDC_IN,/* NEW FIELDS FROM TDRUG */								 
								 DRUG_ABBR_DSG_NM,

								 BLG_REPORTING_CD , /* NEW FIELDS FROM TCPGRP_CLT_PLN_GR1 */ 
								 PLAN_CD,
								 PLAN_EXT_CD_TX ,
								 GROUP_CD,
								 GROUP_EXT_CD_TX,

								 CLIENT_LEVEL_1 ,
							     CLIENT_LEVEL_2,
								 CLIENT_LEVEL_3,
								 MBR_ID,
								 LAST_DELIVERY_SYS,
							     GCN_CODE,
								 BRAND_GENERIC     ,
								 DEA_NB,
 								 PRESCRIBER_NPI_NB,
								 PHARMACY_NM,
								 GPI_THERA_CLS_CD,

                                 MAX(CLIENT_NM) AS CLIENT_NM /* This field is not a new field added.It is already present in code */
                 FROM  &tbl_name_out3.
                        GROUP BY         PRESCRIBER_ID,
                                         CDH_BENEFICIARY_ID,
                                         PT_BENEFICIARY_ID,
                                         DRG_GROUP_SEQ_NB,
                                         DRG_SUB_GRP_SEQ_NB,
                                         CLIENT_ID,
                                         CLT_PLAN_GROUP_ID2,
										 DRUG_ABBR_PROD_NM,/* NEW FIELDS FROM TDRUG */
								         DRUG_ABBR_STRG_NM,
								         DRUG_NDC_ID,
								         NHU_TYPE_CD,/* EXTRA FIELD ADDED SO AS TO MATCH TABLE 3 DEFINATION WHICH IS USEFULE TO CREAT DEFINATION TABLE2 */	 
										 RX_NB,          /* NEW FIELDS FROM TRXCLM_BASE */
										 DISPENSED_QY,
										 DAY_SUPPLY_QY,
										 REFILL_FILL_QY,
										 FORMULARY_TX,
								 		 GENERIC_NDC_IN,/* NEW FIELDS FROM TDRUG */								 
								    	 DRUG_ABBR_DSG_NM,
  						        		 BLG_REPORTING_CD , /* NEW FIELDS FROM TCPGRP_CLT_PLN_GR1 */ 
							        	 PLAN_CD,
							        	 PLAN_EXT_CD_TX,
								         GROUP_CD,
								         GROUP_EXT_CD_TX,
										 CLIENT_LEVEL_1 ,
							     		 CLIENT_LEVEL_2,
								 		 CLIENT_LEVEL_3,
								 	 	 MBR_ID,
								 		 LAST_DELIVERY_SYS,
/*								 		 LAST_FILL_DATE,*/
							     		 GCN_CODE,
								 		 BRAND_GENERIC     ,
								 		 DEA_NB,
 								 		 PRESCRIBER_NPI_NB,
										 PHARMACY_NM,
								 		 GPI_THERA_CLS_CD


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

%table_properties(TBL_NAME=&tbl_name_out1. );
%table_properties(TBL_NAME=&tbl_name_out3. );
%table_properties(TBL_NAME=&tbl_name_out2. );
%MEND pull_claims_for_ql_YM;

