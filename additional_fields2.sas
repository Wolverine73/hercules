/*HEADER-------------------------------------------------------------------------------------------------------
|MACRO: additional_fields.sas
|LOCATION		: 		/PRG/sasprod1/hercules/macros
|PURPOSE		:
|                        Create Additional fields data ,selected by the user through the
|						Java Screen.
|
|INPUT			:		The tbl_name_in(WORK.&TBL_NAME_OUT_SH) is a name of input data set. 
|						
|						
|
|LOGIC			:       Create temporary table with %create_base_file data.
|						Create table with distinct recipient_ids  only from the %create_base_file
| 						Macro.
|						Create three Macro variables for each additional variable query.
|						Create a format with variable names and table names.
|						Pull all variable names from the table that has 117.
| 						variables and create a macro variable called macvar1.
| 						Also create a macro variable with all variables coming
| 						from the current SAS program.
|						
|OUTPUT			: 		Permanent Data set (WORK.&TBL_NAME_OUT_SH) is created .
|				  		The tbl_name_out is a name of output data set. It has all columns: 
|						
+--------------------------------------------------------------------------------------------------------------
| HISTORY:   
|			 DEC2006 - K . Mittapalli - Hercules Version 1.0
|			 MAR2007 - Greg Dudley 	  - Hercules Version 1.0
|			 MAR2008 - K. Mittapalli  - Hercules Version  1.0.02  
| 
|LOGIC			:       Create temporary table with %create_base_file data.
|						Create table with distinct recipient_ids  only from the %create_base_file
| 						Macro.
|						Create temporary table(&DB2_TMP..&TABLE_PREFIX._INPUT_PRMS) contains Recent Drug ids,
|						Nhu types codes,Patient Beneficiary id etc .
|						Create Four Macro variables for each additional variable query.
|						Create a format with variable names and table names.
|						Pull all variable names from the table that has 117.
| 						variables and create a macro variable called macvar1.
| 						Also create a macro variable with all variables coming
| 						from the current SAS program.		
---------------------------------------------------------------------------------------------------------------HEADER*/
%MACRO additional_fields(tbl_name_in,CLAIMSA,HERCULES,INIT_ID,PHASE_ID,tbl_name_out);    

options symbolgen mprint mlogic mprintnest mlogicnest source2;
%set_sysmode(mode=dev2);

LIBNAME DATA    "herc&sysmode/data/sasadhoc/hercules";

%GLOBAL MACVAR3 WORDCNT;
%LET MACVAR3=;
%LET WORDCNT=0;

*SASDOC ------------------------------------------------------------------------------------------------------------
 | Create temporary table with %create_base_file data.
 +------------------------------------------------------------------------------------------------------------SASDOC*;
PROC SQL NOPRINT;
CREATE TABLE DATA.RECIPIENTS_TBL AS
 SELECT *
  FROM &tbl_name_in
  order by recipient_id;
QUIT;

*SASDOC ------------------------------------------------------------------------------------------------------------
 | Create table with distinct recipient_ids  only from the %create_base_file
 | Macro.
 +-----------------------------------------------------------------------------------------------------------SASDOC*;
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL);


	PROC SQL;
	 CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	    EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL
		(RECIPIENT_ID INTEGER) NOT LOGGED INITIALLY) BY DB2;
	 DISCONNECT FROM DB2;
	QUIT;

		PROC SQL;
 INSERT INTO &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL
 	   (RECIPIENT_ID)
 SELECT DISTINCT 
		RECIPIENT_ID format = 8.
   FROM DATA.RECIPIENTS_TBL;
QUIT;
%runstats(tbl_name=&DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL);

*SASDOC ------------------------------------------------------------------------------------------------------------
 | Create temporary table(&DB2_TMP..&TABLE_PREFIX._INPUT_PRMS) contains Recent Drug ids,
 |						Nhu types codes,Patient Beneficiary id etc .
 |  NEWLY ADDED -MAR 2008 KULADEEP M
 +-----------------------------------------------------------------------------------------------------------SASDOC*;
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._INPUT_PRMS);

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS   AS
      (  SELECT                  A.NTW_PRESCRIBER_ID AS PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID,
                                 A.PT_BENEFICIARY_ID,
                                 A.RX_NB,
                                 A.FILL_DT,
                                 A.FILL_DT AS LAST_FILL_DT,
                                 F.DRUG_ABBR_DSG_NM,
                                 F.DRUG_ABBR_PROD_NM,
                                 E.PHARMACY_NM,
                                 A.DRUG_NDC_ID,
								 A.NHU_TYPE_CD,
								 A.BENEFIT_REQUEST_ID
                                 
                          FROM  &CLAIMSA..&CLAIM_HIS_TBL              AS A,
                                &CLAIMSA..TPHARM_PHARMACY             AS E,
                                &CLAIMSA..TDRUG1                      AS F
      ) DEFINITION ONLY NOT LOGGED INITIALLY
               ) BY DB2;
   DISCONNECT FROM DB2;
QUIT;

PROC SQL;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
EXECUTE (ALTER TABLE &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;
EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS
		SELECT 	DISTINCT
				 A.NTW_PRESCRIBER_ID AS PRESCRIBER_ID
          		,A.CDH_BENEFICIARY_ID
          		,A.PT_BENEFICIARY_ID
          		,MAX(A.RX_NB) AS RX_NB
          		,MAX(A.FILL_DT) AS FILL_DT
          		,A.FILL_DT AS LAST_FILL_DT
          		,E.DRUG_ABBR_DSG_NM
          		,E.DRUG_ABBR_PROD_NM                  
          		,MAX(D.PHARMACY_NM) AS PHARMACY_NM
		  		,MAX(A.DRUG_NDC_ID) AS DRUG_NDC_ID
				,MAX(A.NHU_TYPE_CD) AS NHU_TYPE_CD
				,MAX(A.BENEFIT_REQUEST_ID) AS BENEFIT_REQUEST_ID
   FROM 
	&CLAIMSA..&CLAIM_HIS_TBL					A
%if %sysfunc(exist(&CLAIM_DATES)) %then %do;
   ,&CLAIM_DATES  								B
%end;
   ,&DRUG_NDC_IDS				        		C
   ,&CLAIMSA..TPHARM_PHARMACY           		D
   ,&CLAIMSA..TDRUG1                    		E
WHERE 
%if %sysfunc(exist(&CLAIM_DATES)) %then %do;
((B.ALL_DRUG_IN=0) OR (&DRUG_FIELDS_FLAG=1 AND B.ALL_DRUG_IN=1))
  AND    A.FILL_DT BETWEEN CLAIM_BEGIN_DT AND CLAIM_END_DT
  AND    B.DRG_GROUP_SEQ_NB		= C.DRG_GROUP_SEQ_NB
  AND    B.DRG_SUB_GRP_SEQ_NB	= C.DRG_SUB_GRP_SEQ_NB
  AND
%end;
         A.DRUG_NDC_ID 			= C.DRUG_NDC_ID
  AND    A.DRUG_NDC_ID 			= E.DRUG_NDC_ID
  AND    A.NHU_TYPE_CD 			= C.NHU_TYPE_CD
  AND    A.NABP_ID 	  			= D.NABP_ID
  AND    NOT EXISTS
 (SELECT 1
  FROM &CLAIMSA..&CLAIM_HIS_TBL
 WHERE A.BENEFIT_REQUEST_ID = BENEFIT_REQUEST_ID
   AND A.BRLI_NB = BRLI_NB
   AND BRLI_VOID_IN > 0)       
       GROUP BY  A.NTW_PRESCRIBER_ID,A.CDH_BENEFICIARY_ID,A.PT_BENEFICIARY_ID,A.FILL_DT,
                   E.DRUG_ABBR_DSG_NM,E.DRUG_ABBR_PROD_NM 
      FETCH FIRST &MAX_ROWS_FETCHED. ROWS ONLY
) BY DB2;
DISCONNECT FROM DB2;
QUIT;

*SASDOC -----------------------------------------------------------------------------------------------------------
 | Create Four Macro variables for each additional variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CLIENT_ID_SEL as one Macro Variable for CLIENT_ID variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CLIENT_ID_SEL = %STR (
	A.RECIPIENT_ID,
	B.CLIENT_ID);

*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CLIENT_ID as Second Macro Variable for CLIENT_ID variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CLIENT_ID = %STR ( 
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL  A
LEFT JOIN &CLAIMSA..TBENEF_XREF 			  B);

*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CLIENT_ID_EXT as Third Macro Variable for CLIENT_ID variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
				
 %LET CLIENT_ID_EXT = %STR (
   ON A.RECIPIENT_ID = B.BENEFICIARY_ID
  AND B.SEQ_NB  = %(SELECT MAX(C.SEQ_NB)
                     FROM &CLAIMSA..TBENEF_XREF C
					WHERE B.BENEFICIARY_ID  = C.BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CLIENT_ID_EXT2 as Fourth Macro Variable for CLIENT_ID variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CLIENT_ID_EXT2 = %STR (
					  AND B.CLIENT_ID       = C.CLIENT_ID
					  AND B.BENEF_XREF_NB   = C.BENEF_XREF_NB
					  AND B.BIRTH_DT        = C.BIRTH_DT
					  AND C.SEQ_NB > 0)%);

*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define BIRTH_DT_SEL as one Macro Variable for BIRTH_DT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET BIRTH_DT_SEL = %STR (
	A.RECIPIENT_ID,
	B.BIRTH_DT);

*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define BIRTH_DT as Second Macro Variable for BIRTH_DT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET BIRTH_DT = %STR ( 
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL  A
LEFT JOIN &CLAIMSA..TBENEF_XREF 			  B);

*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define BIRTH_DT_EXT as Third Macro Variable for BIRTH_DT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET BIRTH_DT_EXT = %STR (
   ON A.RECIPIENT_ID = B.BENEFICIARY_ID
  AND B.SEQ_NB  = %(SELECT MAX(C.SEQ_NB)
                     FROM &CLAIMSA..TBENEF_XREF C
					WHERE B.BENEFICIARY_ID  = C.BENEFICIARY_ID);

*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define BIRTH_DT_EXT2 as Fourth Macro Variable for BIRTH_DT variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET BIRTH_DT_EXT2 = %STR (
					  AND B.CLIENT_ID       = C.CLIENT_ID
					  AND B.BENEF_XREF_NB   = C.BENEF_XREF_NB
					  AND B.BIRTH_DT        = C.BIRTH_DT
					  AND C.SEQ_NB > 0)%);

*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define AGE_SEL as one Macro Variable for AGE variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET AGE_SEL = %STR (
	A.RECIPIENT_ID,
	(YEAR(CURRENT DATE)- YEAR(B.BIRTH_DT)) AS AGE);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define AGE as Second Macro Variable for AGE variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET AGE = %STR ( 
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL  A
LEFT JOIN &CLAIMSA..TBENEF_XREF 			  B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define AGE_EXT as Third Macro Variable for AGE variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET AGE_EXT = %STR (
   ON A.RECIPIENT_ID = B.BENEFICIARY_ID
  AND B.SEQ_NB  = %(SELECT MAX(C.SEQ_NB)
                     FROM &CLAIMSA..TBENEF_XREF C
					WHERE B.BENEFICIARY_ID  = C.BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define AGE_EXT2 as Fourth Macro Variable for AGE variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET AGE_EXT2 = %STR (
					  AND B.CLIENT_ID       = C.CLIENT_ID
					  AND B.BENEF_XREF_NB   = C.BENEF_XREF_NB
					  AND B.BIRTH_DT        = C.BIRTH_DT
					  AND C.SEQ_NB > 0)%);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CDH_EXTERNAL_ID_SEL as one Macro Variable for CDH_EXTERNAL_ID variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CDH_EXTERNAL_ID_SEL = %STR (
	A.RECIPIENT_ID,
	B.CDH_EXTERNAL_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CDH_EXTERNAL_ID as Second Macro Variable for CDH_EXTERNAL_ID variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CDH_EXTERNAL_ID = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CDH_EXTERNAL_ID_EXT as Third Macro Variable for CDH_EXTERNAL_ID variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CDH_EXTERNAL_ID_EXT = %STR (
LEFT JOIN &CLAIMSA..TBENEF_XREF_DN 			 B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CDH_EXTERNAL_ID_EXT2 as Fourth Macro Variable for CDH_EXTERNAL_ID variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET CDH_EXTERNAL_ID_EXT2 = %STR (
  ON A.RECIPIENT_ID = B.BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define PTL_PRF_MAIL_SEL as one Macro Variable for PTL_PRF_MAIL variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET PTL_PRF_MAIL_SEL = %STR (
	A.RECIPIENT_ID,);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define PTL_PRF_MAIL as Second Macro Variable for PTL_PRF_MAIL variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET PTL_PRF_MAIL = %STR ( 
	0 AS PTL_PRF_MAIL);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define PTL_PRF_MAIL_EXT as Third Macro Variable for PTL_PRF_MAIL variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET PTL_PRF_MAIL_EXT = %STR (
FROM);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define PTL_PRF_MAIL_EXT2 as Fourth Macro Variable for PTL_PRF_MAIL variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET PTL_PRF_MAIL_EXT2 = %STR (
  &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define PTL_PRF_RETAIL_SEL as one Macro Variable for PTL_PRF_RETAIL variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET PTL_PRF_RETAIL_SEL = %STR (
	A.RECIPIENT_ID,);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define PTL_PRF_RETAIL as Second Macro Variable for PTL_PRF_RETAIL variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET PTL_PRF_RETAIL = %STR ( 
	0 AS PTL_PRF_RETAIL);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define PTL_PRF_RETAIL_EXT as Third Macro Variable for PTL_PRF_RETAIL variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET PTL_PRF_RETAIL_EXT = %STR (
FROM);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define PTL_PRF_RETAIL_EXT2 as Fourth Macro Variable for PTL_PRF_RETAIL variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET PTL_PRF_RETAIL_EXT2 = %STR (
  &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CDH_BENEFICIARY_ID_SEL as one Macro Variable for CDH_BENEFICIARY_ID variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CDH_BENEFICIARY_ID_SEL = %STR (
	A.RECIPIENT_ID,
	B.CDH_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CDH_BENEFICIARY_ID as Second Macro Variable for CDH_BENEFICIARY_ID variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CDH_BENEFICIARY_ID = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CDH_BENEFICIARY_ID_EXT as Third Macro Variable for CDH_BENEFICIARY_ID variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CDH_BENEFICIARY_ID_EXT = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CDH_BENEFICIARY_ID_EXT2 as Fourth Macro Variable for CDH_BENEFICIARY_ID variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CDH_BENEFICIARY_ID_EXT2 = %STR (
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CLIENT_NM_SEL as one Macro Variable for CLIENT_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CLIENT_NM_SEL = %STR (
	A.RECIPIENT_ID,
	D.CLIENT_NM 
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL A
LEFT JOIN &CLAIMSA..TBENEF_XREF 			 B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CLIENT_NM as Second Macro Variable for CLIENT_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CLIENT_NM = %STR (
   ON A.RECIPIENT_ID = B.BENEFICIARY_ID
  AND B.SEQ_NB  = %(SELECT MAX(C.SEQ_NB)
                     FROM &CLAIMSA..TBENEF_XREF C
					WHERE B.BENEFICIARY_ID  = C.BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CLIENT_NM_EXT as Third Macro Variable for CLIENT_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CLIENT_NM_EXT = %STR (
					  AND B.CLIENT_ID       = C.CLIENT_ID
					  AND B.BENEF_XREF_NB   = C.BENEF_XREF_NB
					  AND B.BIRTH_DT        = C.BIRTH_DT);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CLIENT_NM_EXT2 as Fourth Macro Variable for CLIENT_NM variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CLIENT_NM_EXT2 = %STR ( 
					  AND C.SEQ_NB > 0)%
LEFT JOIN &CLAIMSA..TCLIENT1 				D
       ON B.CLIENT_ID	 = D.CLIENT_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define APPLIED_MAB_AT_SEL as one Macro Variable for APPLIED_MAB_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET APPLIED_MAB_AT_SEL  = %STR (
	A.RECIPIENT_ID,
	C.APPLIED_MAB_AT
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define APPLIED_MAB_AT as Second Macro Variable for APPLIED_MAB_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET APPLIED_MAB_AT  = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define APPLIED_MAB_AT_EXT as Third Macro Variable for APPLIED_MAB_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET APPLIED_MAB_AT_EXT  = %STR (
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL		  C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define APPLIED_MAB_AT_EXT2 as Fourth Macro Variable for APPLIED_MAB_AT variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET APPLIED_MAB_AT_EXT2  = %STR (
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID
 AND B.RX_NB 			  = C.RX_NB);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define EXCESS_MAB_AT_SEL as one Macro Variable for EXCESS_MAB_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET EXCESS_MAB_AT_SEL  = %STR (
	A.RECIPIENT_ID,	
	C.EXCESS_MAB_AT
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define EXCESS_MAB_AT as Second Macro Variable for EXCESS_MAB_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET EXCESS_MAB_AT  = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define EXCESS_MAB_AT_EXT as Third Macro Variable for EXCESS_MAB_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET EXCESS_MAB_AT_EXT  = %STR (
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL		  C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define EXCESS_MAB_AT_EXT2 as Fourth Macro Variable for EXCESS_MAB_AT variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET EXCESS_MAB_AT_EXT2  = %STR (
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID
 AND B.RX_NB 			  = C.RX_NB);

*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRUG_NDC_ID_SEL as one Macro Variable for DRUG_NDC_ID variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRUG_NDC_ID_SEL  = %STR (
	A.RECIPIENT_ID,
	B.DRUG_NDC_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRUG_NDC_ID as Second Macro Variable for DRUG_NDC_ID variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRUG_NDC_ID  = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL  A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRUG_NDC_ID_EXT as Third Macro Variable for DRUG_NDC_ID variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRUG_NDC_ID_EXT  = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRUG_NDC_ID_EXT2 as Fourth Macro Variable for DRUG_NDC_ID variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRUG_NDC_ID_EXT2  = %STR (
ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define NHU_TYPE_CD_SEL as one Macro Variable for NHU_TYPE_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET NHU_TYPE_CD_SEL  = %STR (
	A.RECIPIENT_ID,
	B.NHU_TYPE_CD);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define NHU_TYPE_CD as Second Macro Variable for NHU_TYPE_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET NHU_TYPE_CD  = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL  A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define NHU_TYPE_CD_EXT as Third Macro Variable for NHU_TYPE_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET NHU_TYPE_CD_EXT  = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define NHU_TYPE_CD_EXT2 as Fourth Macro Variable for NHU_TYPE_CD variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET NHU_TYPE_CD_EXT2  = %STR (
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);

*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DISPENSED_QY_SEL as one Macro Variable for DISPENSED_QY variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DISPENSED_QY_SEL  = %STR (
	A.RECIPIENT_ID,
	C.DISPENSED_QY
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL    A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DISPENSED_QY as Second Macro Variable for DISPENSED_QY variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DISPENSED_QY  = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DISPENSED_QY_EXT as Third Macro Variable for DISPENSED_QY variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DISPENSED_QY_EXT  = %STR (
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL		  C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DISPENSED_QY_EXT2 as Fourth Macro Variable for DISPENSED_QY variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DISPENSED_QY_EXT2  = %STR (
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID
 AND B.RX_NB 			  = C.RX_NB);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DAY_SUPPLY_QY_SEL as one Macro Variable for DAY_SUPPLY_QY variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DAY_SUPPLY_QY_SEL  = %STR (
 	A.RECIPIENT_ID,
	C.DAY_SUPPLY_QY
	FROM
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DAY_SUPPLY_QY as Second Macro Variable for DAY_SUPPLY_QY variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DAY_SUPPLY_QY  = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DAY_SUPPLY_QY_EXT as Third Macro Variable for DAY_SUPPLY_QY variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DAY_SUPPLY_QY_EXT  = %STR (
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL		  C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DAY_SUPPLY_QY_EXT2 as Fourth Macro Variable for DAY_SUPPLY_QY variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET DAY_SUPPLY_QY_EXT2  = %STR (
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID
 AND B.RX_NB 			  = C.RX_NB);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define FILL_DT_SEL as one Macro Variable for FILL_DT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET FILL_DT_SEL  = %STR (
	A.RECIPIENT_ID,
	B.FILL_DT);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define FILL_DT as Second Macro Variable for FILL_DT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET FILL_DT  = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL  A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define FILL_DT_EXT as Third Macro Variable for FILL_DT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET FILL_DT_EXT  = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define FILL_DT_EXT2 as Fourth Macro Variable for FILL_DT variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET FILL_DT_EXT2  = %STR (
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define LAST_FILL_DT_SEL as one Macro Variable for LAST_FILL_DT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET LAST_FILL_DT_SEL  = %STR (
	A.RECIPIENT_ID,
	B.FILL_DT AS LAST_FILL_DT);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define LAST_FILL_DT as Second Macro Variable for LAST_FILL_DT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET LAST_FILL_DT  = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL  A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define LAST_FILL_DT_EXT as Third Macro Variable for LAST_FILL_DT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET LAST_FILL_DT_EXT  = %STR (       
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define LAST_FILL_DT_EXT2 as Fourth Macro Variable for LAST_FILL_DT variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET LAST_FILL_DT_EXT2  = %STR (       
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DELIVERY_SYSTEM_TX_SEL as one Macro Variable for DELIVERY_SYSTEM_TX variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DELIVERY_SYSTEM_TX_SEL  = %STR (
	A.RECIPIENT_ID,
	CASE 
	WHEN C.DELIVERY_SYSTEM_CD IN (1,3) THEN 'RETAIL'
    ELSE 'MAIL' 
	END AS DELIVERY_SYSTEM_TX);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DELIVERY_SYSTEM_TX as Second Macro Variable for DELIVERY_SYSTEM_TX variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DELIVERY_SYSTEM_TX  = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL  A
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DELIVERY_SYSTEM_TX_EXT as Third Macro Variable for DELIVERY_SYSTEM_TX variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DELIVERY_SYSTEM_TX_EXT  = %STR (
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL		  C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DELIVERY_SYSTEM_TX_EXT2 as Fourth Macro Variable for DELIVERY_SYSTEM_TX variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DELIVERY_SYSTEM_TX_EXT2  = %STR (
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID
 AND B.RX_NB 			  = C.RX_NB);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DELIVERY_SYSTEM_SEL as one Macro Variable for DELIVERY_SYSTEM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DELIVERY_SYSTEM_SEL  = %STR (
	A.RECIPIENT_ID,
	CASE 
	WHEN C.DELIVERY_SYSTEM_CD IN (3) THEN 'POS'
    WHEN C.DELIVERY_SYSTEM_CD IN (2) THEN 'MAIL'
	ELSE 'PAPER' 
	END AS DELIVERY_SYSTEM);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DELIVERY_SYSTEM as Second Macro Variable for DELIVERY_SYSTEM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DELIVERY_SYSTEM  = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL  A
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DELIVERY_SYSTEM_EXT as Third Macro Variable for DELIVERY_SYSTEM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DELIVERY_SYSTEM_EXT  = %STR (
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL		  C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DELIVERY_SYSTEM_EXT2 as Fourth Macro Variable for DELIVERY_SYSTEM variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DELIVERY_SYSTEM_EXT2  = %STR (
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID
 AND B.RX_NB 			  = C.RX_NB);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define LAST_DELIVERY_SYS_SEL as one Macro Variable for LAST_DELIVERY_SYS variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET LAST_DELIVERY_SYS_SEL  = %STR (
	A.RECIPIENT_ID,
    C.DELIVERY_SYSTEM_CD AS LAST_DELIVERY_SYS
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define LAST_DELIVERY_SYS as Second Macro Variable for LAST_DELIVERY_SYS variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET LAST_DELIVERY_SYS  = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define LAST_DELIVERY_SYS_EXT as Third Macro Variable for LAST_DELIVERY_SYS variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET LAST_DELIVERY_SYS_EXT  = %STR (
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL		  C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define LAST_DELIVERY_SYS_EXT2 as Fourth Macro Variable for LAST_DELIVERY_SYS variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET LAST_DELIVERY_SYS_EXT2  = %STR (
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID
 AND B.RX_NB 			  = C.RX_NB);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DAW_TYPE_CD_SEL as one Macro Variable for DAW_TYPE_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DAW_TYPE_CD_SEL  = %STR (
	A.RECIPIENT_ID,
	C.DAW_TYPE_CD
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DAW_TYPE_CD as Second Macro Variable for DAW_TYPE_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DAW_TYPE_CD  = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DAW_TYPE_CD_EXT as Third Macro Variable for DAW_TYPE_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DAW_TYPE_CD_EXT  = %STR (        
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL		  C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DAW_TYPE_CD_EXT2 as Fourth Macro Variable for DAW_TYPE_CD variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DAW_TYPE_CD_EXT2  = %STR (        
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID
 AND B.RX_NB 			  = C.RX_NB);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DEDUCTIBLE_AT_SEL as one Macro Variable for DEDUCTIBLE_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DEDUCTIBLE_AT_SEL  = %STR (
	A.RECIPIENT_ID,
	C.DEDUCTIBLE_AT
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DEDUCTIBLE_AT as Second Macro Variable for DEDUCTIBLE_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DEDUCTIBLE_AT  = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DEDUCTIBLE_AT_EXT as Third Macro Variable for DEDUCTIBLE_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DEDUCTIBLE_AT_EXT  = %STR (       
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL		  C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DEDUCTIBLE_AT_EXT2 as Fourth Macro Variable for DEDUCTIBLE_AT variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DEDUCTIBLE_AT_EXT2  = %STR (       
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID
 AND B.RX_NB 			  = C.RX_NB);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define COPAY_AT_SEL as one Macro Variable for COPAY_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET COPAY_AT_SEL  = %STR (
	A.RECIPIENT_ID,
	C.COPAY_AT
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define COPAY_AT as Second Macro Variable for COPAY_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET COPAY_AT  = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define COPAY_AT_EXT as Third Macro Variable for COPAY_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET COPAY_AT_EXT  = %STR (
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL		  C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define COPAY_AT_EXT2 as Fourth Macro Variable for COPAY_AT variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET COPAY_AT_EXT2  = %STR (
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID
 AND B.RX_NB 			  = C.RX_NB);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define NET_COST_AT_SEL as one Macro Variable for NET_COST_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET NET_COST_AT_SEL  = %STR (
	A.RECIPIENT_ID,
	C.NET_COST_AT
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define NET_COST_AT as Second Macro Variable for NET_COST_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET NET_COST_AT  = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS   B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define NET_COST_AT_EXT as Third Macro Variable for NET_COST_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET NET_COST_AT_EXT  = %STR (        
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL		  C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define NET_COST_AT_EXT2 as Fourth Macro Variable for NET_COST_AT variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET NET_COST_AT_EXT2  = %STR (        
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID
 AND B.RX_NB 			  = C.RX_NB);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define MEMBER_COST_AT_SEL as one Macro Variable for MEMBER_COST_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET MEMBER_COST_AT_SEL  = %STR (
	A.RECIPIENT_ID,
	C.MEMBER_COST_AT
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define MEMBER_COST_AT as Second Macro Variable for MEMBER_COST_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET MEMBER_COST_AT  = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS   B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define MEMBER_COST_AT_EXT as Third Macro Variable for MEMBER_COST_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET MEMBER_COST_AT_EXT  = %STR (        
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL		    C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define MEMBER_COST_AT_EXT2 as Fourth Macro Variable for MEMBER_COST_AT variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET MEMBER_COST_AT_EXT2  = %STR (        
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID
 AND B.RX_NB 			  = C.RX_NB);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define RX_COUNT_QY_SEL as one Macro Variable for RX_COUNT_QY variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET RX_COUNT_QY_SEL  = %STR (
	A.RECIPIENT_ID,
	C.RX_COUNT_QY
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define RX_COUNT_QY as Second Macro Variable for RX_COUNT_QY variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET RX_COUNT_QY  = %STR ( 
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS   B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define RX_COUNT_QY_EXT as Third Macro Variable for RX_COUNT_QY variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET RX_COUNT_QY_EXT  = %STR (        
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL		    C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define RX_COUNT_QY_EXT2 as Fourth Macro Variable for RX_COUNT_QY variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET RX_COUNT_QY_EXT2  = %STR (        
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID
 AND B.RX_NB 			  = C.RX_NB);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define FORMULARY_TX_SEL as one Macro Variable for FORMULARY_TX variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET FORMULARY_TX_SEL  = %STR (
	A.RECIPIENT_ID,
    CASE C.FORMULARY_IN
    WHEN 3 THEN 'PREFERRED'
    WHEN 4 THEN 'PREFERRED'
    WHEN 5 THEN 'NON-PREFERRED'
    ELSE 'PREFERRED'
    END AS FORMULARY_TX);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define FORMULARY_TX as Second Macro Variable for FORMULARY_TX variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET FORMULARY_TX  = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS   B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define FORMULARY_TX_EXT as Third Macro Variable for FORMULARY_TX variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET FORMULARY_TX_EXT  = %STR (
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL		    C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define FORMULARY_TX_EXT2 as Fourth Macro Variable for FORMULARY_TX variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET FORMULARY_TX_EXT2  = %STR (
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID
 AND B.RX_NB 			  = C.RX_NB);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define BLG_REPORTING_CD_SEL as one Macro Variable for BLG_REPORTING_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET BLG_REPORTING_CD_SEL  = %STR (
	A.RECIPIENT_ID,
	MAX(C.BLG_REPORTING_CD) AS BLG_REPORTING_CD
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define BLG_REPORTING_CD as Second Macro Variable for BLG_REPORTING_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET BLG_REPORTING_CD  = %STR ( 
LEFT JOIN	&CLAIMSA..TELIG_DETAIL_HIS			B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID
LEFT JOIN	&CLAIMSA..TCPGRP_CLT_PLN_GR1		C);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define BLG_REPORTING_CD_EXT as third Macro Variable for BLG_REPORTING_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET BLG_REPORTING_CD_EXT  = %STR (
  ON B.CLT_PLAN_GROUP_ID = C.CLT_PLAN_GROUP_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define BLG_REPORTING_CD_EXT2 as Fourth Macro Variable for BLG_REPORTING_CD variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET BLG_REPORTING_CD_EXT2  = %STR (
	GROUP BY A.RECIPIENT_ID);

*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CALC_GROSS_COST_SEL as one Macro Variable for CALC_GROSS_COST variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CALC_GROSS_COST_SEL  = %STR (
	A.RECIPIENT_ID,
	C.CALC_GROSS_COST
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CALC_GROSS_COST as Second Macro Variable for CALC_GROSS_COST variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CALC_GROSS_COST  = %STR ( 
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS   B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CALC_GROSS_COST_EXT as Third Macro Variable for CALC_GROSS_COST variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CALC_GROSS_COST_EXT  = %STR (        
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL		    C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CALC_GROSS_COST_EXT2 as Fourth Macro Variable for CALC_GROSS_COST variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CALC_GROSS_COST_EXT2  = %STR (        
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID
 AND B.RX_NB 			  = C.RX_NB);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CDH_DAW_DIFF_AT_SEL as one Macro Variable for CDH_DAW_DIFF_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CDH_DAW_DIFF_AT_SEL  = %STR (
	A.RECIPIENT_ID,
	C.CDH_DAW_DIFF_AT
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CDH_DAW_DIFF_AT as Second Macro Variable for CDH_DAW_DIFF_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CDH_DAW_DIFF_AT  = %STR ( 
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS   B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CDH_DAW_DIFF_AT_EXT as Third Macro Variable for CDH_DAW_DIFF_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CDH_DAW_DIFF_AT_EXT  = %STR (     
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL		    C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CDH_DAW_DIFF_AT_EXT2 as Fourth Macro Variable for CDH_DAW_DIFF_AT variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CDH_DAW_DIFF_AT_EXT2  = %STR (     
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID
 AND B.RX_NB 			  = C.RX_NB);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DEA_NB_SEL as one Macro Variable for DEA_NB variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DEA_NB_SEL  = %STR (
 	A.RECIPIENT_ID,
	C.PRESCRIBER_DEA_NB	AS DEA_NB
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DEA_NB as Second Macro Variable for DEA_NB variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DEA_NB  = %STR ( 
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS   B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DEA_NB_EXT as Third Macro Variable for DEA_NB variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DEA_NB_EXT  = %STR (
LEFT JOIN	&CLAIMSA..TPRSCBR_PRESCRIBE1		C);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DEA_NB_EXT2 as Fourth Macro Variable for DEA_NB variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DEA_NB_EXT2  = %STR (
  ON B.PRESCRIBER_ID = C.PRESCRIBER_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRG_POD_NM_SEL as one Macro Variable for DRG_POD_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRG_POD_NM_SEL  = %STR (
	 A.RECIPIENT_ID,
	 D.POD_NM 	AS DRG_POD_NM
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRG_POD_NM as Second Macro Variable for DRG_POD_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRG_POD_NM  = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS   B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL			C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRG_POD_NM_EXT as Third Macro Variable for DRG_POD_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET DRG_POD_NM_EXT  = %STR (
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRG_POD_NM_EXT2 as Fourth Macro Variable for DRG_POD_NM variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRG_POD_NM_EXT2  = %STR (
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID
 AND B.RX_NB 			  = C.RX_NB
LEFT JOIN	&CLAIMSA..TPOD						D
  ON C.POD_ID = D.POD_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRG_CELL_NM_SEL as one Macro Variable for DRG_CELL_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRG_CELL_NM_SEL  = %STR (
	A.RECIPIENT_ID,
	MAX(F.CELL_NM)	AS DRG_CELL_NM
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS   B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRG_CELL_NM as Second Macro Variable for DRG_CELL_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRG_CELL_NM  = %STR (
LEFT JOIN	&CLAIMSA..TDENIAL_CLAIM				D
  ON B.BENEFIT_REQUEST_ID = D.BENEFIT_REQUEST_ID
LEFT JOIN	&CLAIMSA..TFORMULARY_CELL			E);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRG_CELL_NM_EXT as Third Macro Variable for DRG_CELL_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRG_CELL_NM_EXT  = %STR (
  ON D.FORMULARY_ID = E.FORMULARY_ID
LEFT JOIN	&CLAIMSA..TCELL						F
  ON E.CELL_ID = F.CELL_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRG_CELL_NM_EXT2 as Fourth Macro Variable for DRG_CELL_NM variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRG_CELL_NM_EXT2  = %STR (
	GROUP BY A.RECIPIENT_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRUG_ABBR_DSG_NM_SEL as one Macro Variable for DRUG_ABBR_DSG_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRUG_ABBR_DSG_NM_SEL = %STR (
	A.RECIPIENT_ID,
	B.DRUG_ABBR_DSG_NM);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRUG_ABBR_DSG_NM as Second Macro Variable for DRUG_ABBR_DSG_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRUG_ABBR_DSG_NM = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL  A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRUG_ABBR_DSG_NM_EXT as Third Macro Variable for DRUG_ABBR_DSG_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRUG_ABBR_DSG_NM_EXT = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRUG_ABBR_DSG_NM_EXT2 as Fourth Macro Variable for DRUG_ABBR_DSG_NM variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRUG_ABBR_DSG_NM_EXT2 = %STR (
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRUG_ABBR_PROD_NM_SEL as one Macro Variable for DRUG_ABBR_PROD_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRUG_ABBR_PROD_NM_SEL = %STR (
	A.RECIPIENT_ID,
	B.DRUG_ABBR_PROD_NM);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRUG_ABBR_PROD_NM as Second Macro Variable for DRUG_ABBR_PROD_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRUG_ABBR_PROD_NM = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL  A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRUG_ABBR_PROD_NM_EXT as Third Macro Variable for DRUG_ABBR_PROD_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRUG_ABBR_PROD_NM_EXT = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRUG_ABBR_PROD_NM_EXT2 as Fourth Macro Variable for DRUG_ABBR_PROD_NM variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRUG_ABBR_PROD_NM_EXT2 = %STR (
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRUG_ABBR_STRG_NM_SEL as one Macro Variable for DRUG_ABBR_STRG_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRUG_ABBR_STRG_NM_SEL = %STR (
	A.RECIPIENT_ID,
	MAX(C.DRUG_ABBR_STRG_NM) AS DRUG_ABBR_STRG_NM);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRUG_ABBR_STRG_NM as Second Macro Variable for DRUG_ABBR_STRG_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRUG_ABBR_STRG_NM = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL  A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRUG_ABBR_STRG_NM_EXT as Third Macro Variable for DRUG_ABBR_STRG_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRUG_ABBR_STRG_NM_EXT = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID
LEFT JOIN &CLAIMSA..TDRUG1 					  C);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRUG_ABBR_STRG_NM_EXT2 as Fourth Macro Variable for DRUG_ABBR_STRG_NM variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRUG_ABBR_STRG_NM_EXT2 = %STR (
  ON B.DRUG_NDC_ID       = C.DRUG_NDC_ID
 AND B.NHU_TYPE_CD		 = C.NHU_TYPE_CD
 AND B.DRUG_ABBR_PROD_NM = C.DRUG_ABBR_PROD_NM
 AND B.DRUG_ABBR_DSG_NM  = C.DRUG_ABBR_DSG_NM
GROUP BY A.RECIPIENT_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRUG_TX_SEL as one Macro Variable for DRUG_TX variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRUG_TX_SEL = %STR (
	A.RECIPIENT_ID,
	MAX(C.GPI_GROUP||C.GPI_CLASS||C.GPI_SUBCLASS) AS DRUG_TX);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRUG_TX as Second Macro Variable for DRUG_TX variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRUG_TX = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL  A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRUG_TX_EXT as Third Macro Variable for DRUG_TX variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRUG_TX_EXT = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID
LEFT JOIN &CLAIMSA..TDRUG1 					  C);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DRUG_TX_EXT2 as Fourth Macro Variable for DRUG_TX variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DRUG_TX_EXT2 = %STR (
  ON B.DRUG_NDC_ID       = C.DRUG_NDC_ID
 AND B.NHU_TYPE_CD       = C.NHU_TYPE_CD
 AND B.DRUG_ABBR_PROD_NM = C.DRUG_ABBR_PROD_NM
 AND B.DRUG_ABBR_DSG_NM  = C.DRUG_ABBR_DSG_NM
GROUP BY A.RECIPIENT_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define EXCESS_OOP_AT_SEL as one Macro Variable for EXCESS_OOP_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET EXCESS_OOP_AT_SEL  = %STR (
	A.RECIPIENT_ID,	
	MAX(D.EXCESS_OOP_AT ) AS EXCESS_OOP_AT 
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define EXCESS_OOP_AT as Second Macro Variable for EXCESS_OOP_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET EXCESS_OOP_AT  = %STR ( 
LEFT JOIN	&DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define EXCESS_OOP_AT_EXT as Third Macro Variable for EXCESS_OOP_AT variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET EXCESS_OOP_AT_EXT  = %STR (
LEFT JOIN	&CLAIMSA..TRXCLM_BASE_EXT			D
  ON B.BENEFIT_REQUEST_ID = D.BENEFIT_REQUEST_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define EXCESS_OOP_AT_EXT2 as Fourth Macro Variable for EXCESS_OOP_AT variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET EXCESS_OOP_AT_EXT2  = %STR (
	GROUP BY A.RECIPIENT_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define GPI_THERA_CLS_NM_SEL as one Macro Variable for GPI_THERA_CLS_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET GPI_THERA_CLS_NM_SEL  = %STR (
	A.RECIPIENT_ID,
	MAX(E.GPI_THERA_CLS_NM) AS GPI_THERA_CLS_NM
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS   B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define GPI_THERA_CLS_NM as Second Macro Variable for GPI_THERA_CLS_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET GPI_THERA_CLS_NM  = %STR (
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL		    C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define GPI_THERA_CLS_NM_EXT as Third Macro Variable for GPI_THERA_CLS_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET GPI_THERA_CLS_NM_EXT  = %STR (
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID
 AND B.RX_NB 			  = C.RX_NB
LEFT JOIN	&CLAIMSA..TPOD						D);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define GPI_THERA_CLS_NM_EXT2 as Fourth Macro Variable for GPI_THERA_CLS_NM variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET GPI_THERA_CLS_NM_EXT2  = %STR (
  ON C.POD_ID = D.POD_ID
LEFT JOIN	&CLAIMSA..TGPITC_GPI_THR_CLS		E
  ON D.GPI_THERA_CLS_CD = E.GPI_THERA_CLS_CD
	GROUP BY A.RECIPIENT_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define INCENTIVE_TYPE_CD_SEL as one Macro Variable for INCENTIVE_TYPE_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET INCENTIVE_TYPE_CD_SEL  = %STR (
	A.RECIPIENT_ID,
	MAX(D.INCENTIVE_TYPE_CD) AS INCENTIVE_TYPE_CD
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A
LEFT JOIN	&DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define INCENTIVE_TYPE_CD as Second Macro Variable for INCENTIVE_TYPE_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET INCENTIVE_TYPE_CD  = %STR (
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID
LEFT JOIN	&CLAIMSA..TPOS_REBATE				D);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define INCENTIVE_TYPE_CD_EXT as Third Macro Variable for INCENTIVE_TYPE_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET INCENTIVE_TYPE_CD_EXT  = %STR (
  ON B.BENEFIT_REQUEST_ID = D.BENEFIT_REQUEST_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define INCENTIVE_TYPE_CD_EXT2 as Fourth Macro Variable for INCENTIVE_TYPE_CD variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET INCENTIVE_TYPE_CD_EXT2  = %STR (
	GROUP BY A.RECIPIENT_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define MOC_PHM_CD_SEL as one Macro Variable for MOC_PHM_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET MOC_PHM_CD_SEL  = %STR (
 	A.RECIPIENT_ID,
	D.MOC_PHM_CD
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define MOC_PHM_CD as Second Macro Variable for MOC_PHM_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET MOC_PHM_CD  = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS   B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL		    C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define MOC_PHM_CD_EXT as Third Macro Variable for MOC_PHM_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET MOC_PHM_CD_EXT  = %STR (
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define MOC_PHM_CD_EXT2 as Fourth Macro Variable for MOC_PHM_CD variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET MOC_PHM_CD_EXT2  = %STR (
 AND B.RX_NB 			  = C.RX_NB
LEFT JOIN	&CLAIMSA..TMAIL_ORD_PB_RLS			D
  ON C.PB_ID = D.PB_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CS_AREA_PHONE_SEL as one Macro Variable for CS_AREA_PHONE variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CS_AREA_PHONE_SEL  = %STR (
	A.RECIPIENT_ID,
	MAX('(' || D.TALX_PHN_SAR_NB || ')' ||
    SUBSTR(D.TALX_PHN_NB, 1,3)|| '-' ||
    SUBSTR(D.TALX_PHN_NB, 4)) AS CS_AREA_PHONE
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CS_AREA_PHONE as Second Macro Variable for CS_AREA_PHONE variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CS_AREA_PHONE  = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS   B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL		    C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CS_AREA_PHONE_EXT as Third Macro Variable for CS_AREA_PHONE variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CS_AREA_PHONE_EXT  = %STR (
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define CS_AREA_PHONE_EXT2 as Fourth Macro Variable for CS_AREA_PHONE variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET CS_AREA_PHONE_EXT2  = %STR (
 AND B.RX_NB 			  = C.RX_NB
LEFT JOIN	&CLAIMSA..TMAIL_ORD_PB_RLS			D
  ON C.PB_ID = D.PB_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define PHARMACY_NM_SEL as one Macro Variable for PHARMACY_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET PHARMACY_NM_SEL  = %STR (
 	A.RECIPIENT_ID,
	B.PHARMACY_NM);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define PHARMACY_NM as Second Macro Variable for PHARMACY_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET PHARMACY_NM  = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL  A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define PHARMACY_NM_EXT as Third Macro Variable for PHARMACY_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET PHARMACY_NM_EXT  = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define PHARMACY_NM_EXT2 as Fourth Macro Variable for PHARMACY_NM variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET PHARMACY_NM_EXT2  = %STR (
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define PLAN_CD_SEL as one Macro Variable for PLAN_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET PLAN_CD_SEL  = %STR (
	A.RECIPIENT_ID,
	D.PLAN_CD
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define PLAN_CD as Second Macro Variable for PLAN_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET PLAN_CD  = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS   B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL		    C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define PLAN_CD_EXT as Third Macro Variable for PLAN_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET PLAN_CD_EXT  = %STR (
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define PLAN_CD_EXT2 as Fourth Macro Variable for PLAN_CD variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET PLAN_CD_EXT2  = %STR (
 AND B.RX_NB 			  = C.RX_NB
LEFT JOIN	&CLAIMSA..TCPGRP_CLT_PLN_GR1		D
  ON C.CLT_PLAN_GROUP_ID = D.CLT_PLAN_GROUP_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define GROUP_CD_SEL as one Macro Variable for GROUP_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

%LET GROUP_CD_SEL  = %STR (
	A.RECIPIENT_ID,
	D.GROUP_CD
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define GROUP_CD as Second Macro Variable for GROUP_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET GROUP_CD  = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS   B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID
LEFT JOIN	&CLAIMSA..&CLAIM_HIS_TBL		    C
  ON B.BENEFIT_REQUEST_ID = C.BENEFIT_REQUEST_ID
 AND B.DRUG_NDC_ID        = C.DRUG_NDC_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define GROUP_CD_EXT as Third Macro Variable for GROUP_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET GROUP_CD_EXT  = %STR (
 AND B.FILL_DT            = C.FILL_DT
 AND B.PRESCRIBER_ID 	  = C.NTW_PRESCRIBER_ID
 AND B.CDH_BENEFICIARY_ID = C.CDH_BENEFICIARY_ID
 AND B.PT_BENEFICIARY_ID  = C.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define GROUP_CD_EXT2 as Fourth Macro Variable for GROUP_CD variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET GROUP_CD_EXT2  = %STR (
 AND B.RX_NB 			  = C.RX_NB
LEFT JOIN	&CLAIMSA..TCPGRP_CLT_PLN_GR1		D
  ON C.CLT_PLAN_GROUP_ID = D.CLT_PLAN_GROUP_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define PRESCRIBER_NM_SEL as one Macro Variable for PRESCRIBER_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET PRESCRIBER_NM_SEL  = %STR (
	A.RECIPIENT_ID,
	C.PRESCRIBER_NM
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define PRESCRIBER_NM as Second Macro Variable for PRESCRIBER_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET PRESCRIBER_NM  = %STR (
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS   B
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define PRESCRIBER_NM_EXT as Third Macro Variable for PRESCRIBER_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET PRESCRIBER_NM_EXT  = %STR (
LEFT JOIN	&CLAIMSA..TPRSCBR_PRESCRIBE1		C);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define PRESCRIBER_NM_EXT2 as Fourth Macro Variable for PRESCRIBER_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET PRESCRIBER_NM_EXT2  = %STR (
  ON B.PRESCRIBER_ID = C.PRESCRIBER_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define RX_NB_SEL as one Macro Variable for RX_NB variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET RX_NB_SEL  = %STR (
 	A.RECIPIENT_ID,
	B.RX_NB);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define RX_NB as Second Macro Variable for RX_NB variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET RX_NB  = %STR ( 
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL  A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define RX_NB_EXT as Third Macro Variable for RX_NB variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET RX_NB_EXT  = %STR (        
LEFT JOIN &DB2_TMP..&TABLE_PREFIX._INPUT_PRMS B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define RX_NB_EXT2 as Fourth Macro Variable for RX_NB variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET RX_NB_EXT2  = %STR (        
  ON A.RECIPIENT_ID = B.PT_BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SUBJECT_ID_SEL as one Macro Variable for SUBJECT_ID variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET SUBJECT_ID_SEL = %STR (
	A.RECIPIENT_ID,
	MAX(D.SUBJECT_ID) AS SUBJECT_ID
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL  A
LEFT JOIN &CLAIMSA..TBENEF_XREF 			  B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SUBJECT_ID as Second Macro Variable for SUBJECT_ID variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SUBJECT_ID = %STR (
       ON A.RECIPIENT_ID = B.BENEFICIARY_ID
      AND B.SEQ_NB  = %(SELECT MAX(C.SEQ_NB)
                     FROM &CLAIMSA..TBENEF_XREF C
					WHERE B.BENEFICIARY_ID  = C.BENEFICIARY_ID
					  AND B.CLIENT_ID       = C.CLIENT_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SUBJECT_ID_EXT as Third Macro Variable for SUBJECT_ID variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SUBJECT_ID_EXT = %STR (
					  AND B.BENEF_XREF_NB   = C.BENEF_XREF_NB
					  AND B.BIRTH_DT        = C.BIRTH_DT
					  AND C.SEQ_NB > 0)%);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SUBJECT_ID_EXT2 as Fourth Macro Variable for SUBJECT_ID variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SUBJECT_ID_EXT2 = %STR (
LEFT JOIN	&CLAIMSA..TCMCTN_SUBJECT_DRG		D
  ON B.BENEFICIARY_ID = D.SUBJECT_ID
	GROUP BY A.RECIPIENT_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_ADDRESS1_TX_SEL as one Macro Variable for SBJ_ADDRESS1_TX variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SBJ_ADDRESS1_TX_SEL = %STR (
	A.RECIPIENT_ID,
	B.ADDRESS_LINE1_TX	AS SBJ_ADDRESS1_TX);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_ADDRESS1_TX as Second Macro Variable for SBJ_ADDRESS1_TX variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SBJ_ADDRESS1_TX = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_ADDRESS1_TX_EXT as Third Macro Variable for SBJ_ADDRESS1_TX variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SBJ_ADDRESS1_TX_EXT = %STR (
LEFT JOIN	&CLAIMSA..TBENEF_ADDRESS_DN			B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_ADDRESS1_TX_EXT2 as Fourth Macro Variable for SBJ_ADDRESS1_TX variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SBJ_ADDRESS1_TX_EXT2 = %STR (
  ON A.RECIPIENT_ID = B.BENEFICIARY_ID);
 %LET SBJ_CITY_TX_SEL = %STR (
	A.RECIPIENT_ID,
	B.CITY_TX	AS SBJ_CITY_TX);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_CITY_TX_SEL as First Macro Variable for SBJ_CITY_TX variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SBJ_CITY_TX_SEL = %STR (
	A.RECIPIENT_ID,
	B.CITY_TX	AS SBJ_CITY_TX);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_CITY_TX as Second Macro Variable for SBJ_CITY_TX variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SBJ_CITY_TX = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_CITY_TX_EXT as Third Macro Variable for SBJ_CITY_TX variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SBJ_CITY_TX_EXT = %STR (
LEFT JOIN	&CLAIMSA..TBENEF_ADDRESS_DN			B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_CITY_TX_EXT2 as Fourth Macro Variable for SBJ_CITY_TX variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SBJ_CITY_TX_EXT2 = %STR (
  ON A.RECIPIENT_ID = B.BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_STATE_SEL as one Macro Variable for SBJ_STATE variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SBJ_STATE_SEL = %STR (
	A.RECIPIENT_ID,
	B.STATE	AS SBJ_STATE);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_STATE as Second Macro Variable for SBJ_STATE variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SBJ_STATE = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_STATE_EXT as Third Macro Variable for SBJ_STATE variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SBJ_STATE_EXT = %STR (
LEFT JOIN	&CLAIMSA..TBENEF_ADDRESS_DN			B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_STATE_EXT2 as Fourth Macro Variable for SBJ_STATE variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SBJ_STATE_EXT2 = %STR (
  ON A.RECIPIENT_ID = B.BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_ZIP_CD_SEL as one Macro Variable for SBJ_ZIP_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SBJ_ZIP_CD_SEL = %STR (
	A.RECIPIENT_ID,
	B.ZIP_CD	AS SBJ_ZIP_CD);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_ZIP_CD as Second Macro Variable for SBJ_ZIP_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SBJ_ZIP_CD = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_ZIP_CD_EXT as Third Macro Variable for SBJ_ZIP_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SBJ_ZIP_CD_EXT = %STR (
LEFT JOIN	&CLAIMSA..TBENEF_ADDRESS_DN			B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_ZIP_CD_EXT2 as Fourth Macro Variable for SBJ_ZIP_CD variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SBJ_ZIP_CD_EXT2 = %STR (
  ON A.RECIPIENT_ID = B.BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_ZIP_SUFFIX_CD_SEL as one Macro Variable for SBJ_ZIP_SUFFIX_CD_SEL variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SBJ_ZIP_SUFFIX_CD_SEL = %STR (
	A.RECIPIENT_ID,
	B.ZIP_SUFFIX_CD	AS SBJ_ZIP_SUFFIX_CD);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_ZIP_SUFFIX_CD as Second Macro Variable for SBJ_ZIP_SUFFIX_CD_SEL variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET SBJ_ZIP_SUFFIX_CD = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_ZIP_SUFFIX_CD_EXT as Third Macro Variable for SBJ_ZIP_SUFFIX_CD_SEL variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET SBJ_ZIP_SUFFIX_CD_EXT = %STR (
LEFT JOIN	&CLAIMSA..TBENEF_ADDRESS_DN			B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_ZIP_SUFFIX_CD_EXT2 as Fourth Macro Variable for SBJ_ZIP_SUFFIX_CD_SEL variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SBJ_ZIP_SUFFIX_CD_EXT2 = %STR (
  ON A.RECIPIENT_ID = B.BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_FIRST_NM_SEL as one Macro Variable for SBJ_FIRST_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET SBJ_FIRST_NM_SEL = %STR (
	A.RECIPIENT_ID,
	B.BNF_FIRST_NM	AS SBJ_FIRST_NM);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_FIRST_NM as Second Macro Variable for SBJ_FIRST_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SBJ_FIRST_NM = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_FIRST_NM_EXT as Third Macro Variable for SBJ_FIRST_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SBJ_FIRST_NM_EXT = %STR (
LEFT JOIN	&CLAIMSA..TBENEFICIARY				B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_FIRST_NM_EXT2 as Fourth Macro Variable for SBJ_FIRST_NM variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET SBJ_FIRST_NM_EXT2 = %STR (
  ON A.RECIPIENT_ID = B.BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_LAST_NM_SEL as one Macro Variable for SBJ_LAST_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET SBJ_LAST_NM_SEL = %STR (
	A.RECIPIENT_ID,
	B.BNF_LAST_NM	AS SBJ_LAST_NM);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_LAST_NM as Second Macro Variable for SBJ_LAST_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET SBJ_LAST_NM = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_LAST_NM_EXT as Third Macro Variable for SBJ_LAST_NM variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET SBJ_LAST_NM_EXT = %STR (
LEFT JOIN	&CLAIMSA..TBENEFICIARY				B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define SBJ_LAST_NM_EXT2 as Fourth Macro Variable for SBJ_LAST_NM variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET SBJ_LAST_NM_EXT2 = %STR (
  ON A.RECIPIENT_ID = B.BENEFICIARY_ID);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DATA_QUALITY_CD_SEL as one Macro Variable for DATA_QUALITY_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

 %LET DATA_QUALITY_CD_SEL = %STR (
	A.RECIPIENT_ID,
	B.DATA_QUALITY_CD);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DATA_QUALITY_CD as Second Macro Variable for DATA_QUALITY_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET DATA_QUALITY_CD = %STR (
FROM &DB2_TMP..&TABLE_PREFIX._RECIPIENTS_TBL	A);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DATA_QUALITY_CD_EXT as Third Macro Variable for DATA_QUALITY_CD variable.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET DATA_QUALITY_CD_EXT = %STR (
LEFT JOIN	&CLAIMSA..TBENEF_ADDRESS_DN			B);
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Define DATA_QUALITY_CD_EXT2 as Fourth Macro Variable for DATA_QUALITY_CD variable.
 |Update : Added one more Macro variable -MAR 2008 KULADEEP M
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 %LET DATA_QUALITY_CD_EXT2 = %STR (
  ON A.RECIPIENT_ID = B.BENEFICIARY_ID);

*SASDOC ------------------------------------------------------------------------------------------------------------
 | Create a format with variable names and table names.
 | Update : Added format name as TABEXI - MAR 2008 KULADEEP M
 +-----------------------------------------------------------------------------------------------------------SASDOC*;

PROC FORMAT;
   VALUE $TBLNAM
   	  'APPLIED_MAB_AT'	  	=	"&APPLIED_MAB_AT"
 
   	  'BIRTH_DT'			=	"&BIRTH_DT" 
   	  'AGE'					=	"&AGE" 
	  'BLG_REPORTING_CD'	= 	"&BLG_REPORTING_CD"

	  'CALC_GROSS_COST'		= 	"&CALC_GROSS_COST"
   	  'CDH_BENEFICIARY_ID'	=	"&CDH_BENEFICIARY_ID"
	  'CDH_DAW_DIFF_AT'		=	"&CDH_DAW_DIFF_AT"
	  'CDH_EXTERNAL_ID'	  	=	"&CDH_EXTERNAL_ID" 
   	  'CLIENT_ID'		  	=	"&CLIENT_ID" 
   	  'CLIENT_NM'			=	"&CLIENT_NM"
	  'COPAY_AT'			=	"&COPAY_AT"
	  'CS_AREA_PHONE'		=	"&CS_AREA_PHONE"

	  'DEA_NB'				=	"&DEA_NB" 
   	  'DEDUCTIBLE_AT'		=	"&DEDUCTIBLE_AT"
	  'DATA_QUALITY_CD'		=	"&DATA_QUALITY_CD" 
   	  'DELIVERY_SYSTEM'		=	"&DELIVERY_SYSTEM"
	  'LAST_DELIVERY_SYS'	=	"&LAST_DELIVERY_SYS"
   	  'DELIVERY_SYSTEM_TX'	=	"&DELIVERY_SYSTEM_TX"
   	  'DISPENSED_QY'		=	"&DISPENSED_QY"
   	  'DRG_CELL_NM'			=	"&DRG_CELL_NM"
   	  'DRG_POD_NM'			=	"&DRG_POD_NM"
   	  'DRUG_ABBR_DSG_NM'	=	"&DRUG_ABBR_DSG_NM"
   	  'DRUG_ABBR_PROD_NM'	=	"&DRUG_ABBR_PROD_NM"
	  'DRUG_ABBR_STRG_NM'	=	"&DRUG_ABBR_STRG_NM"
   	  'DRUG_NDC_ID'			=	"&DRUG_NDC_ID"
	  'DRUG_TX'				=	"&DRUG_TX"
 
   	  'EXCESS_MAB_AT'		=	"&EXCESS_MAB_AT" 
   	  'EXCESS_OOP_AT'		=	"&EXCESS_OOP_AT" 

   	  'FILL_DT'				=	"&FILL_DT"
	  'LAST_FILL_DT'		=	"&LAST_FILL_DT"
   	  'FORMULARY_TX'		=	"&FORMULARY_TX"

	  'GPI_THERA_CLS_NM'	=	"&GPI_THERA_CLS_NM"
	  'GROUP_CD'			=	"&GROUP_CD"

	  'INCENTIVE_TYPE_CD'	=	"&INCENTIVE_TYPE_CD"
	  'MEMBER_COST_AT'		=	"&MEMBER_COST_AT"
	  'MOC_PHM_CD'			=	"&MOC_PHM_CD"
	  'NET_COST_AT'			=	"&NET_COST_AT"

   	  'PHARMACY_NM'			=	"&PHARMACY_NM" 
	  'PLAN_CD'				=	"&PLAN_CD" 
   	  'PRESCRIBER_NM'		=	"&PRESCRIBER_NM"
	  'PTL_PRF_MAIL'		=	"&PTL_PRF_MAIL"
	  'PTL_PRF_RETAIL'		=	"&PTL_PRF_RETAIL"


   	  'RX_COUNT_QY'			=	"&RX_COUNT_QY"
	  'RX_NB'				=	"&RX_NB" 
   	  'SUBJECT_ID'			=	"&SUBJECT_ID" 
   	  'SBJ_ADDRESS1_TX'		=	"&SBJ_ADDRESS1_TX" 
	  'SBJ_CITY_TX'			=	"&SBJ_CITY_TX"
   	  'SBJ_ZIP_CD'			=	"&SBJ_ZIP_CD"
   	  'SBJ_ZIP_SUFFIX_CD'	=	"&SBJ_ZIP_SUFFIX_CD"

      OTHER					=	'Invalid Variable Name' 
      ;   
RUN;


PROC FORMAT;
   VALUE $TABSEL
   	  'APPLIED_MAB_AT'		=	"&APPLIED_MAB_AT_SEL"
 
   	  'BIRTH_DT'			=	"&BIRTH_DT_SEL" 
   	  'AGE'					=	"&AGE_SEL" 
	  'BLG_REPORTING_CD'	= 	"&BLG_REPORTING_CD_SEL"

	  'CALC_GROSS_COST'		= 	"&CALC_GROSS_COST_SEL"
   	  'CDH_BENEFICIARY_ID'	=	"&CDH_BENEFICIARY_ID_SEL"
	  'CDH_DAW_DIFF_AT'		=	"&CDH_DAW_DIFF_AT_SEL"
	  'CDH_EXTERNAL_ID'	  	=	"&CDH_EXTERNAL_ID_SEL" 
   	  'CLIENT_ID'		  	=	"&CLIENT_ID_SEL" 
   	  'CLIENT_NM'			=	"&CLIENT_NM_SEL"
	  'COPAY_AT'			=	"&COPAY_AT_SEL"
	  'CS_AREA_PHONE'		=	"&CS_AREA_PHONE_SEL"

	  'DEA_NB'				=	"&DEA_NB_SEL" 
   	  'DEDUCTIBLE_AT'		=	"&DEDUCTIBLE_AT_SEL"
	  'DATA_QUALITY_CD'		=	"&DATA_QUALITY_CD_SEL" 
   	  'DELIVERY_SYSTEM'		=	"&DELIVERY_SYSTEM_SEL"
	  'DELIVERY_SYSTEM_TX'	=	"&DELIVERY_SYSTEM_TX_SEL"
	  'LAST_DELIVERY_SYS'	=	"&LAST_DELIVERY_SYS_SEL"
   	  'DISPENSED_QY'		=	"&DISPENSED_QY_SEL"
   	  'DRG_CELL_NM'			=	"&DRG_CELL_NM_SEL"
   	  'DRG_POD_NM'			=	"&DRG_POD_NM_SEL"
   	  'DRUG_ABBR_DSG_NM'	=	"&DRUG_ABBR_DSG_NM_SEL"
   	  'DRUG_ABBR_PROD_NM'	=	"&DRUG_ABBR_PROD_NM_SEL"
	  'DRUG_ABBR_STRG_NM'	=	"&DRUG_ABBR_STRG_NM_SEL"
   	  'DRUG_NDC_ID'			=	"&DRUG_NDC_ID_SEL"
	  'DRUG_TX'				=	"&DRUG_TX_SEL"
 
   	  'EXCESS_MAB_AT'		=	"&EXCESS_MAB_AT_SEL" 
   	  'EXCESS_OOP_AT'		=	"&EXCESS_OOP_AT_SEL" 

   	  'FILL_DT'				=	"&FILL_DT_SEL"
	  'LAST_FILL_DT'		=	"&LAST_FILL_DT_SEL"
   	  'FORMULARY_TX'		=	"&FORMULARY_TX_SEL"

	  'GPI_THERA_CLS_NM'	=	"&GPI_THERA_CLS_NM_SEL"
	  'GROUP_CD'			=	"&GROUP_CD_SEL"

	  'INCENTIVE_TYPE_CD'	=	"&INCENTIVE_TYPE_CD_SEL"

	  'MEMBER_COST_AT'		=	"&MEMBER_COST_AT_SEL"
	  'MOC_PHM_CD'			=	"&MOC_PHM_CD_SEL"

	  'NET_COST_AT'			=	"&NET_COST_AT_SEL"

   	  'PHARMACY_NM'			=	"&PHARMACY_NM_SEL" 
	  'PLAN_CD'				=	"&PLAN_CD_SEL" 
   	  'PRESCRIBER_NM'		=	"&PRESCRIBER_NM_SEL"
	  'PTL_PRF_MAIL'		=	"&PTL_PRF_MAIL_SEL"
	  'PTL_PRF_RETAIL'		=	"&PTL_PRF_RETAIL_SEL"

   	  'RX_COUNT_QY'			=	"&RX_COUNT_QY_SEL"
	  'RX_NB'				=	"&RX_NB_SEL" 

   	  'SUBJECT_ID'			=	"&SUBJECT_ID_SEL" 
   	  'SBJ_ADDRESS1_TX'		=	"&SBJ_ADDRESS1_TX_SEL" 
	  'SBJ_CITY_TX'			=	"&SBJ_CITY_TX_SEL"
   	  'SBJ_ZIP_CD'			=	"&SBJ_ZIP_CD_SEL"
   	  'SBJ_ZIP_SUFFIX_CD'	=	"&SBJ_ZIP_SUFFIX_CD_SEL"

      OTHER					=	'Invalid Variable Name' 
      ;   
RUN;

PROC FORMAT;
   VALUE $TABEXT
   	  'APPLIED_MAB_AT'		=	"&APPLIED_MAB_AT_EXT"
 
   	  'BIRTH_DT'			=	"&BIRTH_DT_EXT" 
   	  'AGE'					=	"&AGE_EXT" 
	  'BLG_REPORTING_CD'	= 	"&BLG_REPORTING_CD_EXT"

	  'CALC_GROSS_COST'		= 	"&CALC_GROSS_COST_EXT"
   	  'CDH_BENEFICIARY_ID'	=	"&CDH_BENEFICIARY_ID_EXT"
	  'CDH_DAW_DIFF_AT'		=	"&CDH_DAW_DIFF_AT_EXT"
	  'CDH_EXTERNAL_ID'	  	=	"&CDH_EXTERNAL_ID_EXT" 
   	  'CLIENT_ID'		  	=	"&CLIENT_ID_EXT" 
   	  'CLIENT_NM'			=	"&CLIENT_NM_EXT"
	  'COPAY_AT'			=	"&COPAY_AT_EXT"
	  'CS_AREA_PHONE'		=	"&CS_AREA_PHONE_EXT"

	  'DEA_NB'				=	"&DEA_NB_EXT" 
   	  'DEDUCTIBLE_AT'		=	"&DEDUCTIBLE_AT_EXT"
	  'DATA_QUALITY_CD'		=	"&DATA_QUALITY_CD_EXT" 
   	  'DELIVERY_SYSTEM'		=	"&DELIVERY_SYSTEM_EXT"
	  'DELIVERY_SYSTEM_TX'	=	"&DELIVERY_SYSTEM_TX_EXT"
	  'LAST_DELIVERY_SYS'	=	"&LAST_DELIVERY_SYS_EXT"
   	  'DISPENSED_QY'		=	"&DISPENSED_QY_EXT"
   	  'DRG_CELL_NM'			=	"&DRG_CELL_NM_EXT"
   	  'DRG_POD_NM'			=	"&DRG_POD_NM_EXT"
   	  'DRUG_ABBR_DSG_NM'	=	"&DRUG_ABBR_DSG_NM_EXT"
   	  'DRUG_ABBR_PROD_NM'	=	"&DRUG_ABBR_PROD_NM_EXT"
	  'DRUG_ABBR_STRG_NM'	=	"&DRUG_ABBR_STRG_NM_EXT"
   	  'DRUG_NDC_ID'			=	"&DRUG_NDC_ID_EXT"
	  'DRUG_TX'				=	"&DRUG_TX_EXT"
 
   	  'EXCESS_MAB_AT'		=	"&EXCESS_MAB_AT_EXT" 
   	  'EXCESS_OOP_AT'		=	"&EXCESS_OOP_AT_EXT" 

   	  'FILL_DT'				=	"&FILL_DT_EXT"
	  'LAST_FILL_DT'		=	"&LAST_FILL_DT_EXT"
   	  'FORMULARY_TX'		=	"&FORMULARY_TX_EXT"

	  'GPI_THERA_CLS_NM'	=	"&GPI_THERA_CLS_NM_EXT"
	  'GROUP_CD'			=	"&GROUP_CD_EXT"

	  'INCENTIVE_TYPE_CD'	=	"&INCENTIVE_TYPE_CD_EXT"
	  'MEMBER_COST_AT'		=	"&MEMBER_COST_AT_EXT"
	  'MOC_PHM_CD'			=	"&MOC_PHM_CD_EXT"

	  'NET_COST_AT'			=	"&NET_COST_AT_EXT"

   	  'PHARMACY_NM'			=	"&PHARMACY_NM_EXT" 
	  'PLAN_CD'				=	"&PLAN_CD_EXT" 
   	  'PRESCRIBER_NM'		=	"&PRESCRIBER_NM_EXT"
	  'PTL_PRF_MAIL'		=	"&PTL_PRF_MAIL_EXT"
	  'PTL_PRF_RETAIL'		=	"&PTL_PRF_RETAIL_EXT"

   	  'RX_COUNT_QY'			=	"&RX_COUNT_QY_EXT"
	  'RX_NB'				=	"&RX_NB_EXT" 
   	  'SUBJECT_ID'			=	"&SUBJECT_ID_EXT" 
   	  'SBJ_ADDRESS1_TX'		=	"&SBJ_ADDRESS1_TX_EXT" 
	  'SBJ_CITY_TX'			=	"&SBJ_CITY_TX_EXT"
   	  'SBJ_ZIP_CD'			=	"&SBJ_ZIP_CD_EXT"
   	  'SBJ_ZIP_SUFFIX_CD'	=	"&SBJ_ZIP_SUFFIX_CD_EXT"

      OTHER					=	'Invalid Variable Name' 
      ;   
RUN;

PROC FORMAT;
   VALUE $TABEXI
   	  'APPLIED_MAB_AT'		=	"&APPLIED_MAB_AT_EXT2"
 
   	  'BIRTH_DT'			=	"&BIRTH_DT_EXT2" 
   	  'AGE'					=	"&AGE_EXT2" 
	  'BLG_REPORTING_CD'	= 	"&BLG_REPORTING_CD_EXT2"

	  'CALC_GROSS_COST'		= 	"&CALC_GROSS_COST_EXT2"
   	  'CDH_BENEFICIARY_ID'	=	"&CDH_BENEFICIARY_ID_EXT2"
	  'CDH_DAW_DIFF_AT'		=	"&CDH_DAW_DIFF_AT_EXT2"
	  'CDH_EXTERNAL_ID'	  	=	"&CDH_EXTERNAL_ID_EXT2" 
   	  'CLIENT_ID'		  	=	"&CLIENT_ID_EXT2" 
   	  'CLIENT_NM'			=	"&CLIENT_NM_EXT2"
	  'COPAY_AT'			=	"&COPAY_AT_EXT2"
	  'CS_AREA_PHONE'		=	"&CS_AREA_PHONE_EXT2"

	  'DEA_NB'				=	"&DEA_NB_EXT2" 
   	  'DEDUCTIBLE_AT'		=	"&DEDUCTIBLE_AT_EXT2"
	  'DATA_QUALITY_CD'		=	"&DATA_QUALITY_CD_EXT2" 
   	  'DELIVERY_SYSTEM'		=	"&DELIVERY_SYSTEM_EXT2"
	  'DELIVERY_SYSTEM_TX'	=	"&DELIVERY_SYSTEM_TX_EXT2"
	  'LAST_DELIVERY_SYS'	=	"&LAST_DELIVERY_SYS_EXT2"
   	  'DISPENSED_QY'		=	"&DISPENSED_QY_EXT2"
   	  'DRG_CELL_NM'			=	"&DRG_CELL_NM_EXT2"
   	  'DRG_POD_NM'			=	"&DRG_POD_NM_EXT2"
   	  'DRUG_ABBR_DSG_NM'	=	"&DRUG_ABBR_DSG_NM_EXT2"
   	  'DRUG_ABBR_PROD_NM'	=	"&DRUG_ABBR_PROD_NM_EXT2"
	  'DRUG_ABBR_STRG_NM'	=	"&DRUG_ABBR_STRG_NM_EXT2"
   	  'DRUG_NDC_ID'			=	"&DRUG_NDC_ID_EXT2"
	  'DRUG_TX'				=	"&DRUG_TX_EXT2"
 
   	  'EXCESS_MAB_AT'		=	"&EXCESS_MAB_AT_EXT2" 
   	  'EXCESS_OOP_AT'		=	"&EXCESS_OOP_AT_EXT2" 

   	  'FILL_DT'				=	"&FILL_DT_EXT2"
	  'LAST_FILL_DT'		=	"&LAST_FILL_DT_EXT2"
   	  'FORMULARY_TX'		=	"&FORMULARY_TX_EXT2"

	  'GPI_THERA_CLS_NM'	=	"&GPI_THERA_CLS_NM_EXT2"
	  'GROUP_CD'			=	"&GROUP_CD_EXT2"

	  'INCENTIVE_TYPE_CD'	=	"&INCENTIVE_TYPE_CD_EXT2"
	  'MEMBER_COST_AT'		=	"&MEMBER_COST_AT_EXT2"
	  'MOC_PHM_CD'			=	"&MOC_PHM_CD_EXT2"

	  'NET_COST_AT'			=	"&NET_COST_AT_EXT2"

   	  'PHARMACY_NM'			=	"&PHARMACY_NM_EXT2" 
	  'PLAN_CD'				=	"&PLAN_CD_EXT2" 
   	  'PRESCRIBER_NM'		=	"&PRESCRIBER_NM_EXT2"
	  'PTL_PRF_MAIL'		=	"&PTL_PRF_MAIL_EXT2"
	  'PTL_PRF_RETAIL'		=	"&PTL_PRF_RETAIL_EXT2"

   	  'RX_COUNT_QY'			=	"&RX_COUNT_QY_EXT2"
	  'RX_NB'				=	"&RX_NB_EXT2" 
   	  'SUBJECT_ID'			=	"&SUBJECT_ID_EXT2" 
   	  'SBJ_ADDRESS1_TX'		=	"&SBJ_ADDRESS1_TX_EXT2" 
	  'SBJ_CITY_TX'			=	"&SBJ_CITY_TX_EXT2"
   	  'SBJ_ZIP_CD'			=	"&SBJ_ZIP_CD_EXT2"
   	  'SBJ_ZIP_SUFFIX_CD'	=	"&SBJ_ZIP_SUFFIX_CD_EXT2"

      OTHER					=	'Invalid Variable Name' 
      ;   
RUN;

*SASDOC -----------------------------------------------------------------------------------------------------------
 | Create table with  all the available variable names from the table 
 |whose file_id = 99 and file_seq_nb = 1
 +----------------------------------------------------------------------------------------------------------SASDOC*;

PROC SQL NOPRINT;
CREATE TABLE TOTOL_VARIABLES	AS
SELECT B.FIELD_NM				AS ONE
  FROM &HERCULES..TFILE_FIELD			A
  	  ,&HERCULES..TFIELD_DESCRIPTION	B
 WHERE	A.FIELD_ID		=	B.FIELD_ID
   AND	A.FILE_ID		= 	99
   AND  A.FILE_SEQ_NB	= 	1
;
*SASDOC -----------------------------------------------------------------------------------------------------------
 | Create table with  available variables exists on &tbl_name_in.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

CREATE TABLE ORIGINAL_DATA 		AS
SELECT NAME  					AS ONE                
  FROM DICTIONARY.COLUMNS
 WHERE LIBNAME = "WORK"
   AND MEMNAME = "RECIPIENTS_TBL"
;
*SASDOC ------------------------------------------------------------------------------------------------------------
 | Create table with  Additional variables selected by the user
 | through the Java Screen.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
 
CREATE TABLE ADDITIONAL_VARIABLES	AS
SELECT B.FIELD_NM				AS ONE
  FROM &HERCULES..TINIT_ADHOC_FIELD		A
  	  ,&HERCULES..TFIELD_DESCRIPTION	B
 WHERE	A.FIELD_ID		=	B.FIELD_ID
   AND	A.INITIATIVE_ID	in(&INIT_ID);
QUIT;
*SASDOC ------------------------------------------------------------------------------------------------------------
 | Create Macro Variable For the additional variables selected by the user
 | through the Java Screen.
 +-----------------------------------------------------------------------------------------------------------SASDOC*;
PROC SQL;
SELECT B.FIELD_NM				
  INTO :MACVAR3 SEPARATED BY ' '
  FROM &HERCULES..TINIT_ADHOC_FIELD		A
  	  ,&HERCULES..TFIELD_DESCRIPTION	B
 WHERE	A.FIELD_ID		=	B.FIELD_ID
   AND	A.INITIATIVE_ID	in(&INIT_ID);
QUIT;
%PUT MACVAR3=&MACVAR3;
%MACRO WORDCNT(STRING);
%GLOBAL WORDCNT;                    
%LOCAL L;                           
%DO L= 1 %TO 100;                    
 %IF  %SCAN(&STRING,&L)= %THEN %DO; 
 %LET WORDCNT = %EVAL(&L-1);       
  %LET L=100;                       
  %END;                             
%END;                                                                   
%LET WORDCNT = &WORDCNT;                                                
%MEND WORDCNT;  
 
%MACRO CHEKVARS;                                       
PROC SORT DATA = TOTOL_VARIABLES;BY ONE;RUN;
PROC SORT DATA = ORIGINAL_DATA;BY ONE;RUN;
PROC SORT DATA = ADDITIONAL_VARIABLES;BY ONE;RUN;
PROC SORT DATA = DATA.RECIPIENTS_TBL;BY RECIPIENT_ID;RUN;

PROC SQL NOPRINT;
CREATE TABLE VARFMT	AS
SELECT B.FIELD_NM				AS ONE
	  ,B.FORMAT_SAS_TX			AS FMT
  FROM &HERCULES..TFILE_FIELD			A
  	  ,&HERCULES..TFIELD_DESCRIPTION	B
 WHERE	A.FIELD_ID		=	B.FIELD_ID
   AND	A.FILE_ID		= 	99
   AND  A.FILE_SEQ_NB	= 	1
;QUIT;

PROC SORT DATA = VARFMT;BY ONE;RUN;
FILENAME FMTFL '/DATA/sasadhoc/hercules/sas_formats/formats.txt';                                         
DATA _NULL_;
   		 MERGE VARFMT(IN = IN1)             
      TOTOL_VARIABLES(IN = IN2);     
   BY ONE;                                
FILE FMTFL;                                             
   IF IN1 AND IN2 THEN DO;
      PUT @01 ONE $32. @35 FMT $32. ;
   END;                                                             
RUN;                                                                   
FILENAME FMTFL clear;                
DATA FINAL2;
    FORMAT %INCLUDE '/DATA/sasadhoc/hercules/sas_formats/formats.txt';
RUN;
%IF &MACVAR3 NE %THEN %DO;
   %WORDCNT(&MACVAR3);
   %LET MACVAR3 = "&MACVAR3";
   %DO K = 1 %TO &WORDCNT;

      DATA _NULL_;
	     FORMAT VARNAME TBLNAME TBLNAME2 TBLNAM3 TBLNAM4 $1000.;
         VARNAME=SCAN(&MACVAR3,&K);
         TBLNAME=PUT(VARNAME,$TBLNAM.);
		 TBLNAME2=PUT(VARNAME,$TABSEL.);
		 TBLNAME3=PUT(VARNAME,$TABEXT.);
		 TBLNAME4=PUT(VARNAME,$TABEXI.);
         CALL SYMPUT('VARNAME',COMPRESS(VARNAME)); 
         CALL SYMPUT('TBLNAM'|| LEFT(&K),TBLNAME);
		 CALL SYMPUT('TBLNAM2'|| LEFT(&K),TBLNAME2);
		 CALL SYMPUT('TBLNAM3'|| LEFT(&K),TBLNAME3);
		 CALL SYMPUT('TBLNAM4'|| LEFT(&K),TBLNAME4);

      RUN;	 
PROC SQL NOPRINT;
  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
    CREATE TABLE WORK.TBLNAME&K AS
    SELECT * FROM CONNECTION TO DB2      
        (SELECT DISTINCT &&TBLNAM2&K &&TBLNAM&K &&TBLNAM3&K &&TBLNAM4&K);
DISCONNECT FROM DB2;
QUIT;
   %END;


         %DO K= 1 %TO &WORDCNT; 
            PROC SORT DATA = TBLNAME&K;BY RECIPIENT_ID;RUN;
         %END;

   DATA X;
      MERGE DATA.RECIPIENTS_TBL
         %DO K= 1 %TO &WORDCNT; 
            TBLNAME&K
         %END;
		 ;
      BY RECIPIENT_ID;
   RUN;
%END;
%ELSE %DO;
   DATA X;
      SET DATA.RECIPIENTS_TBL; 
   RUN;
%END;
DATA &tbl_name_out;
  IF _N_ = 1 THEN SET FINAL2;
 SET X;
RUN;

%MEND CHEKVARS;
%CHEKVARS;

PROC SQL;
 DROP TABLE DATA.RECIPIENTS_TBL;
 DROP TABLE TOTOL_VARIABLES;
 DROP TABLE ORIGINAL_DATA;
 DROP TABLE ADDITIONAL_VARIABLES;
 DROP TABLE MERG;
 DROP TABLE FINAL2;
 DROP TABLE X;
 QUIT;RUN;
 		 %IF &MACVAR3 NE %THEN %DO;
         %DO K= 1 %TO &WORDCNT; 
            PROC SQL;
			DROP TABLE TBLNAME&K;QUIT;
         %END;
		 %END;

%MEND additional_fields;
%additional_fields(WORK.&TBL_NAME_OUT_SH.,CLAIMSA,&HERCULES,&INITIATIVE_ID,&PHASE_SEQ_NB,WORK.&TBL_NAME_OUT_SH.);
