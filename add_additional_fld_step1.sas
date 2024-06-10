*Step 1:;
/*proc contents data=&CLAIMSA..&CLAIM_HIS_TBL varnum;*/
/*run;*/

/***************************************************************************
Additional Field Nm: 
'DRUG_ABBR_PROD_NM'
'DRUG_ABBR_STRG_NM'
'DRUG_ABBR_DSG_NM'
***************************************************************************/
%set_sysmode(mode=prod);
OPTIONS SYSPARM='initiative_id=12020 phase_seq_nb=1';
%include "/PRG/sas&sysmode.1/hercules/hercules_in.sas";

OPTIONS FULLSTIMER MPRINT MPRINTNEST MLOGIC MLOGICNEST SYMBOLGEN SOURCE2;

data data_pnd.t_&initiative_id._1_1_bkp;
  set data_pnd.t_&initiative_id._1_1;
run;


%MACRO ADDCOLS;

************************************************************************************* from the log ;
%let DRUG_JOIN_CONDITION=%str(AND E.DRUG_NDC_ID = G.DRUG_NDC_ID AND E.NHU_TYPE_CD = G.NHU_TYPE_CD);
%let DRUG_FIELDS_LIST_NDC=%str(, G.DRUG_ABBR_PROD_NM, G.DRUG_ABBR_STRG_NM, G.DRUG_ABBR_DSG_NM, G.DRUG_NDC_ID,G.NHU_TYPE_CD);
%let STR_TDRUG1=%str(, CLAIMSA.TDRUG1 AS G);
%let DELIVERY_SYSTEM_CONDITION =;
/*%let CLIENT_ID_CONDITION =;*/
%let CLIENT_ID_CONDITION = %str(AND A.CLIENT_ID  IN (22905));
%let MAX_ROWS_FETCHED = 10000000;
%let DRUG_FIELDS_FLAG=1;


**%get_ndc(DRUG_NDC_TBL=&DB2_TMP..&TABLE_PREFIX._NDC_QL,
         DRUG_NDC_TBL_rx=&ora_TMP..&TABLE_PREFIX._NDC_RX,
         DRUG_NDC_TBL_re=&ora_TMP..&TABLE_PREFIX._NDC_RE,
         CLAIM_DATE_TBL=&DB2_TMP..&TABLE_PREFIX._RVW_DATES);
         
%LET PROGRAM_NAME=identify_drug_therapy;
%LET DRUG_GROUP2_EXIST_FLAG=0; * Initialize DRUG_GROUP2_EXIST_FLAG;

proc sql;
  drop table &DB2_TMP..i&INITIATIVE_ID.;
quit;

 PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);

     EXECUTE(CREATE TABLE &DB2_TMP..i&INITIATIVE_ID.
                 (PRESCRIBER_ID INTEGER NOT NULL,
        				  PT_BENEFICIARY_ID INTEGER NOT NULL,
                  CDH_BENEFICIARY_ID INTEGER NOT NULL,
                  CLIENT_ID INTEGER NOT NULL,
                  BIRTH_DT DATE,
                  GPI_GROUP CHAR(2),
                  GPI_CLASS CHAR(2),
                  GPI_SUBCLASS CHAR(2),
                  GPI_NAME CHAR(2),
                  GPI_NAME_EXTENSION  CHAR(2),
                  GPI_FORM CHAR(2),
                  GPI_STRENGTH CHAR(2),
                  DRUG_NDC_ID DECIMAL(11) NOT NULL,
                  NHU_TYPE_CD SMALLINT NOT NULL, 
		              DISPENSED_QY INTEGER,
                  DAY_SUPPLY_QY INTEGER,
/*		              RX_NB CHAR(9),*/
                  DELIVERY_SYSTEM_CD INTEGER,
                  DRUG_ABBR_PROD_NM CHAR (12),
                  DRUG_ABBR_STRG_NM CHAR (8),
                  DRUG_ABBR_DSG_NM  CHAR (3)

                  
           ) NOT LOGGED INITIALLY) BY DB2;
   DISCONNECT FROM DB2;
 QUIT;

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
   EXECUTE
  (ALTER TABLE &DB2_TMP..i&INITIATIVE_ID. ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;
   EXECUTE(INSERT INTO &DB2_TMP..i&INITIATIVE_ID.
           SELECT    
         A.NTW_PRESCRIBER_ID AS PRESCRIBER_ID, 
    		 A.PT_BENEFICIARY_ID,
    		 A.CDH_BENEFICIARY_ID,
    		 A.CLIENT_ID    AS  CLIENT_ID,
    		 A.PT_BIRTH_DT  AS  BIRTH_DT,
         E.GPI_GROUP,
         E.GPI_CLASS,
         E.GPI_SUBCLASS,
         E.GPI_NAME,
         E.GPI_NAME_EXTENSION ,
         E.GPI_FORM,
         E.GPI_STRENGTH,
    		 A.DRUG_NDC_ID  AS  DRUG_NDC_ID,
    		 A.NHU_TYPE_CD, 
    		 A.DISPENSED_QY AS  DISPENSED_QY,
         A.DAY_SUPPLY_QY,
/*    		 max(A.RX_NB)        AS RX_NB,*/
         A.DELIVERY_SYSTEM_CD,
         E.DRUG_ABBR_PROD_NM,
         E.DRUG_ABBR_STRG_NM,
         E.DRUG_ABBR_DSG_NM 
                                           
        FROM     &CLAIMSA..&CLAIM_HIS_TBL               AS A,
                 &DB2_TMP..&TABLE_PREFIX._RVW_DATES     AS B,
/*                 &DB2_TMP..&TABLE_PREFIX._NDC_QL        AS D,*/
                 &CLAIMSA..TDRUG1                       AS E

        WHERE    ((B.ALL_DRUG_IN=0)  OR (&DRUG_FIELDS_FLAG=1 AND B.ALL_DRUG_IN=1))
          AND    A.FILL_DT BETWEEN CLAIM_BEGIN_DT AND CLAIM_END_DT
/*          AND    B.DRG_GROUP_SEQ_NB=D.DRG_GROUP_SEQ_NB*/
/*          AND    B.DRG_SUB_GRP_SEQ_NB=D.DRG_SUB_GRP_SEQ_NB*/
/*          AND    A.DRUG_NDC_ID = D.DRUG_NDC_ID*/
/*          AND    A.NHU_TYPE_CD = D.NHU_TYPE_CD*/
          AND    A.DRUG_NDC_ID = E.DRUG_NDC_ID
          AND    A.NHU_TYPE_CD = E.NHU_TYPE_CD
	   /*and A.PT_BENEFICIARY_ID=11408282*/
                  &CLIENT_ID_CONDITION
                  &DELIVERY_SYSTEM_CONDITION
         AND NOT EXISTS
              (SELECT 1
               FROM &CLAIMSA..&CLAIM_HIS_TBL
               WHERE A.BENEFIT_REQUEST_ID = BENEFIT_REQUEST_ID
               AND   A.BRLI_NB = BRLI_NB
               AND   BRLI_VOID_IN > 0)

/*group by*/
/*         A.NTW_PRESCRIBER_ID, */
/*    		 A.PT_BENEFICIARY_ID,*/
/*    		 A.CDH_BENEFICIARY_ID,*/
/*    		 A.CLIENT_ID,*/
/*    		 A.PT_BIRTH_DT,*/
/*         E.GPI_GROUP,*/
/*         E.GPI_CLASS,*/
/*         E.GPI_SUBCLASS,*/
/*         E.GPI_NAME,*/
/*         E.GPI_NAME_EXTENSION ,*/
/*         E.GPI_FORM,*/
/*         E.GPI_STRENGTH,*/
/*    		 D.DRUG_NDC_ID,*/
/*    		 D.NHU_TYPE_CD */
           

      )BY DB2;
  DISCONNECT FROM DB2;
 QUIT;
 
proc sql;
select count(*)
from &DB2_TMP..i&INITIATIVE_ID.;
quit;

/*data i&INITIATIVE_ID.;*/
/*set &DB2_TMP..i&INITIATIVE_ID.;*/
/*run; */


%MEND ADDCOLS;

%ADDCOLS;
OPTIONS NOMPRINT NOMPRINTNEST NOMLOGIC NOMLOGICNEST NOSYMBOLGEN NOSOURCE2;
