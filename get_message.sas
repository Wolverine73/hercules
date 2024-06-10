/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  get_message.sas (macro)
|
| LOCATION: /PRG/sastest1/hercules/87/macros
|
| PURPOSE:  Apply business rules to parse the text contained in the CELL_NM and
|           POD_NM columns.  These columns contain text that has been delimited
|           by colons.  This macro will retrieve custom message flags and text,
|           and will parse the message text according to established business
|           rules.  New Cell and Pod names/text are added to the output table.
|
| ASSUMPTIONS:
|
|           (1) Other than checking to see if &TBL_NAME_IN exists, this program
|               does not thoroughly validate parameters.
|           (2) The HERCULES and CLAIMSA DB2 libnames have been assigned.
|           (3) The CMA macros directory has been added to SASAUTOS. (The
|               %DROP_TABLE macro is used to drop the old table if it is
|               different than &TBL_NAME_OUT.)(
|           (3) The TPOD_CSTM_MESSAGE and TFRML_MESSAGE_HIST tables exist and
|               contain the appropriate/expected message flags and text.
|
| MACRO PARAMETERS:
|
|           TBL_NAME_IN  = name of the input table
|           TBL_NAME_OUT = name of the output table (or same as input)
|           CELL_NM_OUT  = name of the new/parsed CELL_NM
|           POD_NM_OUT   = name of the new/parsed POD_NM
|
| INPUT:    &TBL_NAME_IN
|           HERCULES.TPOD_CSTM_MESSAGE
|           CLAIMSA.TFRML_MESSAGE_HIST
|
| OUTPUT:   &TBL_NAME_OUT (with columns &DRG_CELL_NM and &DRG_POD_NM added)
|
+--------------------------------------------------------------------------------
| HISTORY:  20AUG2003 - T.Kalfas  - Original.
|           15OCT2003 - T.Kalfas  - Fixed bug with %IF-%THEN logic.
|           04JAN2008 - N.Williams- Hercules Version  2.0.01
|                                   Business user request to update Cell pod message 
|                                   for generic product.
+------------------------------------------------------------------------HEADER*/


*SASDOC-------------------------------------------------------------------------
| Message Processing (in order of preference):
|
| (1)  When a generic product is available and the POD is not marked in
|      TPOD_CSTM_MESSAGE (NO_GENERIC_MSG_IN = 1), change the cell text to
|      "A generic product is available for the non-preferred product".
|
| (2)  Use the retail reject message when the product is not available
|      generically and the POD is tagged in TPOD_CSTM_MESSAGE.  Only include the
|      text after the first semi-colon.  (TFRML_MESSAGE_HIST.REJECT_LNG_MSG)
|
| (3)  When the product is moving to an 'N' status, replace the cell with
|      "Product covered, however copayment may change".
|
| (4)  Omit any text after the semi-colon in the cell and pod name columns.
+-----------------------------------------------------------------------SASDOC*;

%MACRO GET_MESSAGE(TBL_NAME_IN  =,
                   TBL_NAME_OUT =,
                   CELL_NM_OUT  =DRG_CELL_NM,
                   POD_NM_OUT   =DRG_POD_NM);

  %IF %SYSFUNC(EXIST(&TBL_NAME_IN)) %THEN %DO;
    PROC SQL NOPRINT;
      %DROP_TABLE(TBL_NAME=&TBL_NAME_OUT);

      CREATE TABLE &TBL_NAME_OUT AS
      SELECT CLAIMS.*,
             CASE
               WHEN (CLAIMS.GENERIC_AVAIL_IN=1) THEN ''
               WHEN (TMSGFL.RETAIL_MSG_IN=1)    THEN ''
               WHEN (CLAIMS.NEW_FRM_STS='N')    THEN ''
               ELSE TRIM(LEFT(SCAN(POD_NM,1,':')))
             END AS &POD_NM_OUT   LENGTH=120 FORMAT=$120.,
             CASE
               WHEN (CLAIMS.GENERIC_AVAIL_IN=1 AND TMSGFL.NO_GENERIC_MSG_IN=.)
				 THEN 'Product covered; generic is available, grace period may not apply.'  /* 04JAN2008 - N.Williams */
               WHEN (TMSGFL.RETAIL_MSG_IN=1)
                 THEN TRIM(LEFT(SUBSTR(TMESSG.REJECT_LNG_MSG_TX,INDEX(TMESSG.REJECT_LNG_MSG_TX,':')+1)))
               WHEN (CLAIMS.NEW_FRM_STS='N')
                 THEN 'PRODUCT COVERED; HOWEVER, COPAYMENT MAY CHANGE'
               ELSE TRIM(LEFT(SCAN(CELL_NM,1,':')))
             END AS &CELL_NM_OUT  LENGTH=140 FORMAT=$140.
      FROM   &TBL_NAME_IN  CLAIMS
      LEFT
      JOIN   (SELECT POD_ID, RETAIL_MSG_IN, NO_GENERIC_MSG_IN
              FROM   &HERCULES..TPOD_CSTM_MESSAGE
              WHERE  DATETIME() BETWEEN EFFECTIVE_TS and EXPIRATION_TS)  TMSGFL
        ON   CLAIMS.POD_ID = TMSGFL.POD_ID
      LEFT
      JOIN   (SELECT POD_ID, REJECT_LNG_MSG_TX
              FROM   &CLAIMSA..TFRML_MESSAGE_HIST
              WHERE  TODAY() BETWEEN EFFECTIVE_DT AND EXPIRATION_DT
                AND  CLIENT_ID=0)  TMESSG
        ON   TMSGFL.POD_ID = TMESSG.POD_ID
      ;

      %IF %UPCASE(&TBL_NAME_IN)^=%UPCASE(&TBL_NAME_OUT) %THEN %DROP_TABLE(&TBL_NAME_IN);;
    QUIT;

    %RUNSTATS(TBL_NAME=&TBL_NAME_OUT);

  %END;
  %ELSE %PUT ERROR: (GET_MESSAGE): SPECIFIED TABLE &TBL_NAME_IN DOES NOT EXIST.;

%MEND GET_MESSAGE;
