
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
|
+-----------------------------------------------------------------------HEADER*/

%MACRO DELETE_INIT;

   %IF &PHASE_SEQ_NB =1 %THEN %DO;

        PROC SQL;
           
	       DELETE FROM &HERCULES..TINITIATIVE        WHERE INITIATIVE_ID = &INITIATIVE_ID;
		   DELETE FROM &HERCULES..TINITIATIVE_DATE   WHERE INITIATIVE_ID = &INITIATIVE_ID;
		   DELETE FROM &HERCULES..TINITIATIVE_PHASE  WHERE INITIATIVE_ID = &INITIATIVE_ID;
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
           DELETE FROM QCPAP020.TEOB_FILTER_DTL  	 WHERE INITIATIVE_ID = &INITIATIVE_ID;
 
         QUIT;
    %END;

    PROC SQL;
           /*                                     
           DELETE FROM &HERCULES..TINITIATIVE_PHASE  WHERE INITIATIVE_ID = &INITIATIVE_ID AND PHASE_SEQ_NB = &PHASE_SEQ_NB;
	*/
           DELETE FROM &HERCULES..TINIT_PHSE_RVR_DOM WHERE INITIATIVE_ID = &INITIATIVE_ID AND PHASE_SEQ_NB = &PHASE_SEQ_NB;
           DELETE FROM &HERCULES..TINIT_PHSE_CLT_DOM WHERE INITIATIVE_ID = &INITIATIVE_ID AND PHASE_SEQ_NB = &PHASE_SEQ_NB;
           DELETE FROM &HERCULES..TPHASE_DRG_GRP_DT  WHERE INITIATIVE_ID = &INITIATIVE_ID AND PHASE_SEQ_NB = &PHASE_SEQ_NB;
           DELETE FROM &HERCULES..TPHASE_RVR_FILE    WHERE INITIATIVE_ID = &INITIATIVE_ID AND PHASE_SEQ_NB = &PHASE_SEQ_NB;
           DELETE FROM &HERCULES..TSCREEN_STATUS     WHERE INITIATIVE_ID = &INITIATIVE_ID AND PHASE_SEQ_NB = &PHASE_SEQ_NB;
           DELETE FROM &HERCULES..TIBNFT_MODULE_STS  WHERE INITIATIVE_ID = &INITIATIVE_ID AND PHASE_SEQ_NB = &PHASE_SEQ_NB;
               
/*ADDED PSG TABLES */
		   DELETE FROM &HERCULES..TINIT_MOD3_DAT_IBEN3	WHERE INITIATIVE_ID = &INITIATIVE_ID AND PHASE_SEQ_NB = &PHASE_SEQ_NB;
		   DELETE FROM &HERCULES..TINIT_MOD3_MSG_IBEN3  WHERE INITIATIVE_ID = &INITIATIVE_ID AND PHASE_SEQ_NB = &PHASE_SEQ_NB;
           DELETE FROM &HERCULES..TINIT_MOD3_PRM_IBEN3  WHERE INITIATIVE_ID = &INITIATIVE_ID AND PHASE_SEQ_NB = &PHASE_SEQ_NB;


     QUIT;

	 
%MEND DELETE_INIT;

%include '/home/user/qcpap020/autoexec_new.sas';
%set_sysmode(mode=dev2);
%macro DoInitiativeLoop(InitiativeListVar);

%let z=0;
%let InitiativeList=%str(&InitiativeListVar);
%do %while (%scan(&InitiativeList., &z+1) ne );

	%let z=%eval(&z+1);
	%let InitiativeId=%scan(&InitiativeList. ,&z);
	
	OPTIONS SYSPARM="INITIATIVE_ID=&InitiativeId. PHASE_SEQ_NB=1";
	%INCLUDE "/herc&sysmode/prg/hercules/hercules_in.sas";
	%put _user_ ;
	%DELETE_INIT;

%end;

%mend DoInitiativeLoop;

OPTIONS MPRINT MLOGIC;

%let sysmode=dev2;

%DoInitiativeLoop(8072);
%DoInitiativeLoop(8073);
%DoInitiativeLoop(8074);
%DoInitiativeLoop(8075);
