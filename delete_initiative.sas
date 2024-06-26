/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  delete_initiative.sas
|
| LOCATION: /PRG/sastest1/hercules/gen_utilities
|
| PURPOSE:  Used to delete an initiative/phase.  Initiated from Summary.
|           screen (Java) through Integration Technologies.  This program
|           will eventually be implemented as a DB2 stored procedure once
|           we have DBA support.
|
| LOGIC:    When the initiative is new (phase seq nb=1), the entries in 14
|           tables are deleted.  The contents of 5 additional tables are
|           deleted for initiative based on phase seq nb.
|
| INPUT:    &INITIATIVE_ID, &PHASE_SEQ_NB
|
|
|
+-------------------------------------------------------------------------------
| HISTORY:  November 24, 2003 - P.Wonders - Original.
|           19MAR2004 - J.Chen - Commented out hard-coded %LET to set sysmode
|           07MAR2008 - N.WILLIAMS   - Hercules Version  2.0.01
|                                      1. Initial code migration into Dimensions
|                                         source safe control tool. 
|                                      2. Added references new program path.
|Hercules Version  2.1.01
|           18JUL2008 - SR           - ADDED DELETE SQLs FOR NEWLY CREATED DOCUMENT
|                                      OVERRIDE TABLES.
|           23FEB2012 - S.BILETSKY   - ADDED CHANGES TO SUBMIT IN BATCH.
|										see QCPI208
|
+-----------------------------------------------------------------------HEADER*/
%MACRO DELETE_INIT;

   %IF &PHASE_SEQ_NB =1 %THEN %DO;

        PROC SQL;
           
     /*      
		DELETE FROM &HERCULES..TINITIATIVE        WHERE INITIATIVE_ID = &INITIATIVE_ID;
	   DELETE FROM &HERCULES..TINITIATIVE_DATE   WHERE INITIATIVE_ID = &INITIATIVE_ID;
	   DELETE FROM &HERCULES..TINITIATIVE_PHASE  WHERE INITIATIVE_ID = &INITIATIVE_ID;
		*/
           DELETE FROM &HERCULES..TDELIVERY_SYS_EXCL WHERE INITIATIVE_ID = &INITIATIVE_ID;
           DELETE FROM &HERCULES..TINIT_FORMULARY    WHERE INITIATIVE_ID = &INITIATIVE_ID;
           DELETE FROM &HERCULES..TINIT_FRML_INCNTV  WHERE INITIATIVE_ID = &INITIATIVE_ID;
	       DELETE FROM &HERCULES..TINIT_EXT_FORMLY   WHERE INITIATIVE_ID = &INITIATIVE_ID;
           DELETE FROM &HERCULES..TINIT_PRSCBR_SPLTY WHERE INITIATIVE_ID = &INITIATIVE_ID;
           DELETE FROM &HERCULES..TINIT_PRSCBR_RULE  WHERE INITIATIVE_ID = &INITIATIVE_ID;
           DELETE FROM &HERCULES..TINIT_CLIENT_RULE  WHERE INITIATIVE_ID = &INITIATIVE_ID;
           DELETE FROM &HERCULES..TINIT_CLT_RULE_DEF WHERE INITIATIVE_ID = &INITIATIVE_ID;
           DELETE FROM &HERCULES..TINIT_PRTCPNT_RULE WHERE INITIATIVE_ID = &INITIATIVE_ID;
           DELETE FROM &HERCULES..TINIT_DRUG_GROUP   WHERE INITIATIVE_ID = &INITIATIVE_ID;
           DELETE FROM &HERCULES..TINIT_DRUG_SUB_GRP WHERE INITIATIVE_ID = &INITIATIVE_ID;
           DELETE FROM &HERCULES..TDRUG_SUB_GRP_DTL  WHERE INITIATIVE_ID = &INITIATIVE_ID;
           DELETE FROM &HERCULES..TCMCTN_PENDING     WHERE INITIATIVE_ID = &INITIATIVE_ID;
           DELETE FROM &HERCULES..TIBNFT_MODULE_STS  WHERE INITIATIVE_ID = &INITIATIVE_ID;
           DELETE FROM &HERCULES..TINIT_ADJUD_ENGINE WHERE INITIATIVE_ID = &INITIATIVE_ID;
           DELETE FROM &HERCULES..TINIT_MODULE_MSG   WHERE INITIATIVE_ID = &INITIATIVE_ID;
           DELETE FROM &HERCULES..TINIT_RECAP_CLT_RL WHERE INITIATIVE_ID = &INITIATIVE_ID;
           DELETE FROM &HERCULES..TINIT_RXCLM_CLT_RL WHERE INITIATIVE_ID = &INITIATIVE_ID;
 	   	   DELETE FROM &HERCULES..TINIT_IBNFT_OPTN   WHERE INITIATIVE_ID = &INITIATIVE_ID;
           DELETE FROM &HERCULES..TINIT_EXT_FORMLY   WHERE INITIATIVE_ID = &INITIATIVE_ID;   
           DELETE FROM &HERCULES..TINIT_QL_DOC_OVR   WHERE INITIATIVE_ID = &INITIATIVE_ID;
           DELETE FROM &HERCULES..TINIT_RXCM_DOC_OVR WHERE INITIATIVE_ID = &INITIATIVE_ID;   
           DELETE FROM &HERCULES..TINIT_RECP_DOC_OVR WHERE INITIATIVE_ID = &INITIATIVE_ID;        
 /*QCPI208 ADDED PSG TABLES */
		   DELETE FROM &HERCULES..TINIT_MOD3_DAT_IBEN3	WHERE INITIATIVE_ID = &INITIATIVE_ID;
		   DELETE FROM &HERCULES..TINIT_MOD3_MSG_IBEN3  WHERE INITIATIVE_ID = &INITIATIVE_ID;
           DELETE FROM &HERCULES..TINIT_MOD3_PRM_IBEN3  WHERE INITIATIVE_ID = &INITIATIVE_ID;

         QUIT;
    %END;

    PROC SQL;
           DELETE FROM &HERCULES..TINIT_PHSE_RVR_DOM WHERE INITIATIVE_ID = &INITIATIVE_ID AND PHASE_SEQ_NB = &PHASE_SEQ_NB;
           DELETE FROM &HERCULES..TINIT_PHSE_CLT_DOM WHERE INITIATIVE_ID = &INITIATIVE_ID AND PHASE_SEQ_NB = &PHASE_SEQ_NB;
           DELETE FROM &HERCULES..TPHASE_DRG_GRP_DT  WHERE INITIATIVE_ID = &INITIATIVE_ID AND PHASE_SEQ_NB = &PHASE_SEQ_NB;
           DELETE FROM &HERCULES..TPHASE_RVR_FILE    WHERE INITIATIVE_ID = &INITIATIVE_ID AND PHASE_SEQ_NB = &PHASE_SEQ_NB;
           DELETE FROM &HERCULES..TSCREEN_STATUS     WHERE INITIATIVE_ID = &INITIATIVE_ID AND PHASE_SEQ_NB = &PHASE_SEQ_NB;
           DELETE FROM &HERCULES..TIBNFT_MODULE_STS  WHERE INITIATIVE_ID = &INITIATIVE_ID AND PHASE_SEQ_NB = &PHASE_SEQ_NB;

     QUIT;

%MEND DELETE_INIT;

/*Add to delete pending dataset and unnessesary temp tables - Phase 2*/

%set_sysmode(mode=prod);

%INCLUDE "/herc&sysmode./prg/hercules/hercules_in.sas"; 

*SASDOC=====================================================================;
*  QCPI208
*  Call update_request_ts to signal the start of delete initiative in batch
*====================================================================SASDOC*;

%update_request_ts(start);

%DELETE_INIT;

*SASDOC=====================================================================;
* QCPI208
* Call update_request_ts to complete of delete initiative in batch
*====================================================================SASDOC*;

%update_request_ts(complete);


