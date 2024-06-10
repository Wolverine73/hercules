/*HEADER------------------------------------------------------------------------
|
| PROGRAM:     pod_to_ndc61.sas (macro)
|
| LOCATION:    /PRG/sastest1/hercules/87/macros
|
| PURPOSE:     To gather a set of drugs based on parameters for formulary_id=61
|              formulary status, P_T_PREFERRED_CD(aka PTV_CD), effective date,
|              and expiration date.  For CMA, these sets of drugs are
|              evaluated to determine which drugs are changing formulary status
|              over a given period.
|              
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
| HISTORY:  09NOV2006 - N.Williams - Original (as part of formulary_purge.sas)
|                                    modified copy of pod_to_ndc for formulary_id
|                                    61. Add rule to include P_T_PREFERRED_CD in  
|                                    determining a change.
|          
|
+------------------------------------------------------------------------HEADER*/



%MACRO POD_TO_NDC61(TBL_NAME=,
                  FRM_STS=,
				  PTVCODE=,
                  EFF_DT=,
                  EXP_DT=,
                  CLAIMSA=CLAIMSA,
                  EXTRA_CRITERIA=);


 


  PROC SQL;
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
P_T_PREFERRED_CD SMALLINT,
EFFECTIVE_DT DATE,
EXPIRATION_DT DATE )) BY DB2;

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
               POD_DRUG_HIS.P_T_PREFERRED_CD,
		       POD_DRUG_HIS.EFFECTIVE_DT,
		       POD_DRUG_HIS.EXPIRATION_DT
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
		  AND  POD_DRUG_HIS.P_T_PREFERRED_CD   IN (&PTVCODE)
          AND  POD_DRUG_HIS.EFFECTIVE_DT &EFF_DT
          AND  POD_DRUG_HIS.EXPIRATION_DT &EXP_DT
          &EXTRA_CRITERIA
          AND  CURRENT DATE BETWEEN FORM_POD.EFFECTIVE_DT AND FORM_POD.EXPIRATION_DT
          AND  POD_DRUG_HIS.EXPIRATION_DT = (SELECT MAX(EXPIRATION_DT)
                                             FROM   &CLAIMSA..TPOD_DRUG_HISTORY POD_DRUG_HIS2
                                             WHERE  POD_DRUG_HIS2.DRUG_NDC_ID        = POD_DRUG_HIS.DRUG_NDC_ID
                                               AND  POD_DRUG_HIS2.POD_ID             = POD_DRUG_HIS.POD_ID
                                               AND  POD_DRUG_HIS2.NHU_TYPE_CD        = POD_DRUG_HIS.NHU_TYPE_CD
                                               AND  POD_DRUG_HIS.IN_FORMULARY_IN_CD IN (&FRM_STS)
											   AND  POD_DRUG_HIS.P_T_PREFERRED_CD   IN (&PTVCODE)
                                               AND  EXPIRATION_DT &EXP_DT)
      )BY DB2;
	  %reset_sql_err_cd;
    DISCONNECT FROM DB2;
  QUIT;

  %SET_ERROR_FL;

  %RUNSTATS(TBL_NAME=&TBL_NAME);

%MEND POD_TO_NDC61;
