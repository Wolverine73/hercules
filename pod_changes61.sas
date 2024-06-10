/*HEADER------------------------------------------------------------------------
|
| PROGRAM:     pod_changes61.sas (macro)
|
| LOCATION:    /PRG/sastest1/hercules/87/macros
|
| PURPOSE:     Compares two SAS datasets for matching NDCs and PODs to determine
|              a change in formulary status. Records are inserted into the
|              DB2 table that was supplied as the TBL_OUT.  Thus, it is expected
|              that the table exists when this macro is called.
|
| INPUT:       &CLAIMSA.TDRUG1,
|               &TBL1_IN, &TBL2_IN
|
| OUTPUT:      &TBL_NAME (new table containing target drugs)
|
| CALLEDMODS:  %DROP_TABLE
|
+--------------------------------------------------------------------------------
| HISTORY:  09NOV2006 - N.Williams - Original
|
|
|
+------------------------------------------------------------------------HEADER*/

 %MACRO POD_CHANGES61(TBL1_IN=, TBL2_IN=, TBL_OUT=, EXECD=);
 

   PROC SQL NOPRINT;
     CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   %IF &EXECD EQ %STR() %THEN %DO ;
     EXECUTE(INSERT INTO &TBL_OUT
             SELECT T1.DRUG_NDC_ID,
                    T1.NHU_TYPE_CD,
                    T1.POD_ID,
                    T1.POD_NM,
                    T1.CELL_NM,
                    D.DRUG_ABBR_PROD_NM,
                    D.DRUG_ABBR_DSG_NM,
                    D.DRUG_ABBR_STRG_NM,
                    D.GENERIC_AVAIL_IN,
                    CASE SUBSTR(T1.GPI, 1,2)
                          WHEN '00' THEN NULL
                          ELSE SUBSTR(T1.GPI, 1, 2)
                    END,
                    CASE SUBSTR(T1.GPI, 3,2)
                          WHEN '00' THEN NULL
                          ELSE SUBSTR(T1.GPI, 3, 2)
                    END,
                    CASE SUBSTR(T1.GPI, 5,2)
                          WHEN '00' THEN NULL
                          ELSE SUBSTR(T1.GPI, 5, 2)
                    END,
                    CASE SUBSTR(T1.GPI, 7,2)
                          WHEN '00' THEN NULL
                          ELSE SUBSTR(T1.GPI, 7, 2)
                    END,
                    CASE SUBSTR(T1.GPI, 9,2)
                          WHEN '00' THEN NULL
                          ELSE SUBSTR(T1.GPI, 5, 2)
                    END,
                    CASE SUBSTR(T1.GPI, 11,2)
                          WHEN '00' THEN NULL
                          ELSE SUBSTR(T1.GPI, 11, 2)
                    END,
                    CASE SUBSTR(T1.GPI, 13,2)
                          WHEN '00' THEN NULL
                          ELSE SUBSTR(T1.GPI, 13, 2)
                    END,
                    CASE T2.IN_FORMULARY_IN_CD
                      WHEN 3 THEN 'Y'
                      WHEN 4 THEN 'Z'
                      WHEN 5 THEN 'X'
                      ELSE 'N'
                    END AS ORG_FRM_STS,
                    CASE T1.IN_FORMULARY_IN_CD
                      WHEN 3 THEN 'Y'
                      WHEN 4 THEN 'Z'
                      WHEN 5 THEN 'X'
                      ELSE 'N'
                    END AS NEW_FRM_STS,
					T2.P_T_PREFERRED_CD AS ORG_PTV_CD,
                    T1.P_T_PREFERRED_CD AS NEW_PTV_CD

             FROM   &CLAIMSA..TDRUG1 D,
			 		&TBL1_IN T1

			 INNER JOIN 
                    &TBL2_IN T2
					ON  T1.DRUG_NDC_ID       = T2.DRUG_NDC_ID
					AND T1.POD_ID            = T2.POD_ID
		            AND T2.EXPIRATION_DT     < T1.EFFECTIVE_DT
		            AND T1.EXPIRATION_DT     > T2.EXPIRATION_DT	                      

             WHERE T1.DRUG_NDC_ID = T2.DRUG_NDC_ID
			 AND   T1.POD_ID      = T2.POD_ID
             AND   T1.NHU_TYPE_CD = T2.NHU_TYPE_CD
             AND   T1.DRUG_NDC_ID = D.DRUG_NDC_ID
             AND   T1.NHU_TYPE_CD = D.NHU_TYPE_CD
             AND   D.DRUG_BRAND_CD = 'B') BY DB2;
			 %reset_sql_err_cd;
	 %END ;
     DISCONNECT FROM DB2;
   QUIT;

   %RUNSTATS(TBL_NAME=&TBL_OUT);


 %MEND POD_CHANGES61;
