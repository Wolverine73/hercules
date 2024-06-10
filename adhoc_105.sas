
/*HEADER------------------------------------------------------------------------
|
| CREATE ADHOC MAILING LIST TO PARTICIPANTS
+--------------------------------------------------------------------------------
|   J HOU
+------------------------------------------------------------------------HEADER*/
%LET err_fl=0;
  %set_sysmode(mode=prod);
  OPTIONS SYSPARM='INITIATIVE_ID=669 PHASE_SEQ_NB=1';
%INCLUDE "/PRG/sas&sysmode.1/hercules/hercules_in.sas";



 DATA TMP105.&TABLE_PREFIX._ADHOC(BULKLOAD=YES);
      SET DATA_ARC.T_317_1_1_PENDING(WHERE=(CLIENT_ID=11955));
     rename recipient_id=pt_beneficiary_id; RUN;

  %LET ERR_FL=0;
  %let max_file_seq_nb=1;
   options mlogic;
   %let debug_flag=Y;
%create_base_file(TBL_NAME_IN=TMP105.&TABLE_PREFIX._ADHOC);

*SASDOC-------------------------------------------------------------------------
| Check for Stellent ID and add to file layout if available.  Set the
| doc_complete_in variable.
+-----------------------------------------------------------------------SASDOC*;

%check_document;

%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative Id &INITIATIVE_ID");

*SASDOC-------------------------------------------------------------------------
| Check for autorelease of file.
+-----------------------------------------------------------------------SASDOC*;
%autorelease_file(INIT_ID=&INITIATIVE_ID, PHASE_ID=&PHASE_SEQ_NB);

%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative Id &INITIATIVE_ID");

%update_task_ts(job_complete_ts);


*SASDOC-------------------------------------------------------------------------
| Insert distinct recipients into TCMCTN_PENDING if the file is not autorelease.
| The user will receive an email with the initiative summary report.  If the
| file is autoreleased, %release_data is called and no email is generated from
| %insert_tcmctn_pending.
+-----------------------------------------------------------------------SASDOC*;
%let primary_programmer_email=productionsupportanalytics@caremark.com;

%insert_tcmctn_pending(init_id=&initiative_id, phase_id=&phase_seq_nb);


%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative Id &INITIATIVE_ID");
