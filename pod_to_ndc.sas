/*HEADER------------------------------------------------------------------------
|
| PROGRAM:     pod_to_ndc.sas (macro)
|
| LOCATION:    /PRG/sastest1/hercules/87/macros
|
| PURPOSE:     To gather a set of drugs based on parameters for formulary
|              status, effective date, and expiration date.  For CMA, these sets
|              of drugs are evaluated to determine which drugs are changing
|              formulary status over a given period.
|
| INPUT:       &CLAIMSA..TPOD_DRUG_HISTORY POD_DRUG_HIS,
|              &CLAIMSA..TCELL_POD CELL_POD,
|              &CLAIMSA..TCELL CELL,
|              &CLAIMSA..TPOD POD,
|              &CLAIMSA..TFORMULARY_POD FORM_POD
|              &CLAIMSA..TFORMULARY_CELL FORM_CELL
|
| OUTPUT:      &TBL_NAME (new table containing target drugs)
|
| CALLEDMODS:  %DROP_TABLE
|
+--------------------------------------------------------------------------------
| HISTORY:  31JUL2003 - P.Wonders - Original (as part of formulary_purge.sas).
|
|           20AUG2003 - T.Kalfas  - Created separate, external macro. Only added
|                                   a couple parameters to capture changes in
|                                   the table name and the CLAIMSA specification.
|           22JAN2007 - G. DUDLEY - Removed the parameter CLAIMSA=CLAIMSA
|
|	        Mar  2007 - Greg Dudley Hercules Version  1.0  
|
|           26JAN2009 - N.Williams - Hercules Version  2.1.2
|                                    Added PTV Code(aka P_T_PREFERRED_CD).
+------------------------------------------------------------------------HEADER*/
/*options mprint symbolgen;*/

options mlogic mlogicnest mprint mprintnest symbolgen source2;
%MACRO POD_TO_NDC(TBL_NAME=,
                  FRM_STS=,
                  EFF_DT=,
                  EXP_DT=,
/*                  CLAIMSA=CLAIMSA, **** 22JAN2007 g.o.d. *****/
                  EXTRA_CRITERIA=);

%let QCPAP020=QCPAP020;   /*ADDED BY RG FOR TESTING*/

	PROC SQL ;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
      %DROP_TABLE(&TBL_NAME);

      EXECUTE(
        CREATE TABLE &TBL_NAME
          (DRUG_NDC_ID DECIMAL(11) not null,
           NHU_TYPE_CD SMALLINT not null,
           POD_ID INTEGER,
           IN_FORMULARY_IN_CD SMALLINT,
           POD_NM CHAR(60),
           CELL_NM CHAR (60),
           GPI CHAR(14),
		   P_T_PREFERRED_CD SMALLINT 
          )
      )BY DB2;

      EXECUTE(
        INSERT INTO &TBL_NAME
        SELECT DISTINCT
               POD_DRUG_HIS.DRUG_NDC_ID,
               POD_DRUG_HIS.NHU_TYPE_CD,
               POD.POD_ID,
               POD_DRUG_HIS.IN_FORMULARY_IN_CD,
               POD.POD_NM,
               CELL.CELL_NM,
               POD.GPI_THERA_CLS_CD,
			   POD_DRUG_HIS.P_T_PREFERRED_CD /*** 26JAN2009 - N.Williams ***/
        FROM   &CLAIMSA..TPOD_DRUG_HISTORY POD_DRUG_HIS,
               &CLAIMSA..TCELL_POD CELL_POD,
               &CLAIMSA..TCELL CELL,
               &CLAIMSA..TPOD POD,  
               &CLAIMSA..TFORMULARY_POD FORM_POD,
               &CLAIMSA..TFORMULARY_CELL FORM_CELL
        WHERE  FORM_POD.FORMULARY_ID IN (&FRM_ID)
          AND  FORM_POD.POD_ID = POD_DRUG_HIS.POD_ID
          AND  FORM_POD.POD_ID = POD.POD_ID
          AND  FORM_POD.FORMULARY_ID = FORM_CELL.FORMULARY_ID
          AND  FORM_CELL.CELL_ID = CELL.CELL_ID
          AND  POD.POD_ID = CELL_POD.POD_ID
          AND  CELL_POD.CELL_ID = CELL.CELL_ID
          AND  POD_DRUG_HIS.IN_FORMULARY_IN_CD IN (&FRM_STS)
          AND  POD_DRUG_HIS.EFFECTIVE_DT &EFF_DT
          AND  POD_DRUG_HIS.EXPIRATION_DT &EXP_DT
          &EXTRA_CRITERIA
          AND  CURRENT DATE BETWEEN FORM_POD.EFFECTIVE_DT AND FORM_POD.EXPIRATION_DT
          AND  POD_DRUG_HIS.EXPIRATION_DT = (SELECT MAX(EXPIRATION_DT)
                                             FROM   &CLAIMSA..TPOD_DRUG_HISTORY POD_DRUG_HIS2
                                             WHERE  POD_DRUG_HIS2.DRUG_NDC_ID = POD_DRUG_HIS.DRUG_NDC_ID
                                               AND  POD_DRUG_HIS2.POD_ID = POD_DRUG_HIS.POD_ID
                                               AND  POD_DRUG_HIS2.NHU_TYPE_CD = POD_DRUG_HIS.NHU_TYPE_CD
                                               AND  POD_DRUG_HIS.IN_FORMULARY_IN_CD IN (&FRM_STS)
                                               AND  EXPIRATION_DT &EXP_DT)
      )BY DB2;
    DISCONNECT FROM DB2;
  QUIT;

  %SET_ERROR_FL;

  %RUNSTATS(TBL_NAME=&TBL_NAME);

%MEND POD_TO_NDC;
