options fullstimer;

%set_sysmode;
options mprint mprintnest mlogic mlogicnest symbolgen source2;
options sysparm= 'INITIATIVE_ID=10959 PHASE_SEQ_NB=1';

%INCLUDE "/herc&sysmode/PRG/hercules/hercules_in.sas";
/*%let log_dir=%str(/PRG/sastest1/hercules/gd);*/

%PUT NOTE: PROGRAM_ID = &PROGRAM_ID;
%PUT NOTE: TASK_ID = &TASK_ID;
%PUT NOTE: TITLE_TX = &TITLE_TX;
%PUT NOTE: TRGT_RECIPIENT_CD = &TRGT_RECIPIENT_CD;
%PUT NOTE: EXT_DRUG_LIST_IN = &EXT_DRUG_LIST_IN;
%PUT NOTE: OVRD_CLT_SETUP_IN = &OVRD_CLT_SETUP_IN;
%PUT NOTE: DFLT_INCLSN_IN = &DFLT_INCLSN_IN;
%PUT NOTE: DESTINATION_CD = &DESTINATION_CD;
%PUT NOTE: DATA_CLEANSING_CD = &DATA_CLEANSING_CD;
%PUT NOTE: DOCUMENT_LOC_CD = &DOCUMENT_LOC_CD;
%PUT NOTE: PRTCPNT_PARM_IN = &PRTCPNT_PARM_IN;
%PUT NOTE: PRESCRIBER_PARM_IN = &PRESCRIBER_PARM_IN;
%PUT NOTE: DSPLY_CLT_SETUP_CD = &DSPLY_CLT_SETUP_CD;
%PUT NOTE: DRG_DEFINITION_CD= &DRG_DEFINITION_CD;
%PUT NOTE: LETTER_TYPE_QY_CD = &LETTER_TYPE_QY_CD;
%PUT NOTE: DFL_CLT_INC_EXU_IN = &DFL_CLT_INC_EXU_IN;
%PUT NOTE: DSPLY_CLT_SETUP_CD = &DSPLY_CLT_SETUP_CD;

  PROC SQL NOPRINT;
    CREATE   TABLE TPHASE_RVR_FILE  AS
    SELECT   *
    FROM     &HERCULES..TPHASE_RVR_FILE

    WHERE    INITIATIVE_ID = &INITIATIVE_ID;
  QUIT;
  PROC PRINT DATA=TPHASE_RVR_FILE;
    VAR INITIATIVE_ID PHASE_SEQ_NB CMCTN_ROLE_CD DATA_CLEANSING_CD 
        FILE_USAGE_CD DESTINATION_CD;
  RUN;

  PROC SQL NOPRINT;
    CREATE   TABLE HERC_PARMS  AS
    SELECT   A.PROGRAM_ID,
             A.TASK_ID,
             '%nrbquote('||trim(left(A.TITLE_TX))||")" as title_tx,
             A.TRGT_RECIPIENT_CD,
             A.EXT_DRUG_LIST_IN,
             A.OVRD_CLT_SETUP_IN,
             B.DFLT_INCLSN_IN,
             C.DATA_CLEANSING_CD,
             C.DESTINATION_CD,
             D.DOCUMENT_LOC_CD,
             D.PRTCPNT_PARM_IN,
             D.PRESCRIBER_PARM_IN,
             D.DSPLY_CLT_SETUP_CD,
             D.DRG_DEFINITION_CD, 
             D.LETTER_TYPE_QY_CD,
			 D.DFL_CLT_INC_EXU_IN,
			 D.DSPLY_CLT_SETUP_CD

    FROM     &HERCULES..TINITIATIVE A,
             &CLAIMSA..TPROGRAM B,
             &HERCULES..TCMCTN_PROGRAM C,
             &HERCULES..TPROGRAM_TASK D

    WHERE    A.INITIATIVE_ID = &INITIATIVE_ID  AND
             A.PROGRAM_ID = B.PROGRAM_ID       AND
             A.PROGRAM_ID = C.PROGRAM_ID       AND
             A.PROGRAM_ID = D.PROGRAM_ID       AND
             A.TASK_ID = D.TASK_ID;

    SELECT COUNT(*) INTO :INIT_CNT
    FROM HERC_PARMS;
  QUIT;


%macro file_release_wrapper(init_id=&initiative_id,
                            phase_id=&phase_seq_nb,
                            com_cd=&cmctn_role_cd,
                            doc_cd=&document_loc_cd,
			    dbg_flg=1);
			    
  options replace;			  

  %if &dbg_flg %then %do;
    options mprint symbolgen mlogic notes source source2 stimer fullstimer;
    %let debug_flag=Y;
  %end;


   %let init_id=%cmpres(&init_id);
   %let phase_id=%cmpres(&phase_id);
   %let com_cd=%cmpres(&com_cd);
   %let doc_cd=%cmpres(&doc_cd);

  %*SASDOC=====================================================================;
  %* This program is being executed by Java/SAS-IT testing, so the log
  %* information must specifically be directed to a disk file.  The program
  %* task log is handled by the Hercules Task Master and is stored in the
  %* &DATA_LOG directory.  This "wrapper" log will also be stored in the
  %* &DATA_LOG directory, but it will incorporate the &CMCTN_ROLE_CD in the
  %* log file name.
  %*====================================================================SASDOC*;

  %put NOTE: (&SYSMACRONAME): Re-routing log to &log_dir/t_&init_id._&phase_id._&com_cd._rls.log.;

/*  proc printto log="&log_dir/t_&init_id._&phase_id._&com_cd._rls.log" new;*/
/*  run;*/

  %if &dbg_flg %then %do;
    /*proc options;
     run;*/
  %end;

  %*SASDOC=====================================================================;
  %* Call update_request_ts to signal the start of executing file release in batch
  %* 
  %*====================================================================SASDOC*;
  %update_request_ts(start);

    %*SASDOC===================================================================;
    %* Initiate the CHECK DOCUMENT process.  NOTE: Indirect inheritance of the
    %* the following global macro variables occurs:  INITIATIVE_ID,
    %* PHASE_SEQ_NB, CMCTN_ROLE_CD, and DOCUMENT_LOC_CD.  Problems may arise
    %* if these variables are not assigned.
  	%* 09AUG2010 D.Palmer - replaced call to cee_check_document with check_document
    %*==================================================================SASDOC*;

     %if (&PROGRAM_ID=5252 or &PROGRAM_ID=5253 or &PROGRAM_ID=5254 or &PROGRAM_ID=5255 or &PROGRAM_ID=5256 or &PROGRAM_ID=5270 or &PROGRAM_ID=5296 or &PROGRAM_ID=5297 or
         &PROGRAM_ID=5349 or &PROGRAM_ID=5350 or &PROGRAM_ID=5351 or &PROGRAM_ID=5352 or &PROGRAM_ID=5353 or &PROGRAM_ID=5354 or &PROGRAM_ID=5355 or &PROGRAM_ID=5371)
    %then %do;
	    %cee_check_document;    	
    %end;
     %if (&PROGRAM_ID=5369)
     %then %do;
	   	%abpd_check_document;
    %end;
    %else %do;
      %if &program_id ne 72 and &program_id ne 5295 %then %do;
/*    	%check_document;*/
    	%end;
      %if &program_id=5246 %then %do;	
		 data DATA_PND.T_&initiative_id._1_1;
		   format PREFERRED_MEMBER 15.;
		   set DATA_PND.T_&initiative_id._1_1 ;
		   FORMULARY_TX=FORMULARY_ID;
		   ORG_FRM_STS=LANGUAGE_INDICATOR;
		   SENIOR_IN=PAYER_ID;      
		   PREFERRED_MEMBER = MBR_GID; 
		   PRFR_DRUG_NM1 = MBR_ID;
		   CDH_EXTERNAL_ID=CDH_EXT_ID;
		   PRFR_DRUG_NM2=CMS_CNTRCT_ID; 
		   PRFR_DRUG_NM3=CMS_PLAN_ID;
		 run;
	  %end;
    %end; 


    %*SASDOC===================================================================;
    %* Initiate the COMPLETE DATA CLEANSING process.
    %*==================================================================SASDOC*;
    %complete_data_cleansing(init_id=&init_id, phase_id=&phase_id, com_cd=&com_cd);


    %*SASDOC===================================================================;
    %* Initiate the RELEASE DATA process.
    %*==================================================================SASDOC*;
    %release_data_new(init_id=&init_id, phase_id=&phase_id, com_cd=&com_cd);

  %*SASDOC=====================================================================;
  %* Call update_request_ts to signal the start of executing file release in batch
  %* 
  %*====================================================================SASDOC*;
  %update_request_ts(complete);
  
  %*SASDOC=====================================================================;
  %* Redirect the log output back to its default.
  %*====================================================================SASDOC*;

  %put NOTE: (&SYSMACRONAME): Re-routing log output back to default.;

/*  proc printto;*/
/*  run;*/

%mend file_release_wrapper;

%file_release_wrapper(init_id=&INITIATIVE_ID, phase_id=1, com_cd=1, doc_cd=1, dbg_flg=1);

%macro updt_rts;

  proc sql;
  connect to db2 as db2(dsn=&UDBSPRP);
  execute(
   update hercules.tphase_rvr_file
     set RELEASE_TS = '2011-08-08-20.00.00.000000'
     where initiative_id in (&INITIATIVE_ID)
  ) by db2;
  disconnect from db2;
  quit;

%mend updt_rts;

%updt_rts;
