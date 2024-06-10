%include '/user1/qcpap020/autoexec_new.sas';

/***HEADER -------------------------------------------------------------------------
 |  PROGRAM NAME:     REQUEST_INITIATIVE_SUMMARY_PARM.SAS
 |
 |  PURPOSE:    Insert report request row in order to produce Initiative Summary Parms Reports
 |              -- PARM - Initiative_Id 
 |              -- Determine if report request row is present for Initiative ID
 |              -- Update report request row if found
 |              -- Insert report request row if not found  
 |
 |  INPUT:      UDB Tables accessed by macros are not listed               
 |                 &hercules..TINITIATIVE_PHASE, 
 |                 &hercules..TREPORT_REQUEST
 |
 |  OUTPUT:     Report request row in Hercules.TREPORT_REQUEST for Initiative Summary Parms Report 
 |
 |  HISTORY:    March 15, 2012 - Ron Smith - Hercules Version 2.1.01
 |                                           New Macro - Initial implementation
 |
 +-------------------------------------------------------------------------------HEADER*/

/* Call syntax  %REQUEST_INITIATIVE_SUMMARY_PARM(INITIATIVE_ID=&INITIATIVE_ID.); */
/* This program assumes Hercules_in.sas was called prior to executing this macro */

/* options sysparm='INITIATIVE_ID=6078 PHASE_SEQ_NB=1'; */

options mprint nolabel;

%LET ERR_FL=0;
%LET PROGRAM_NAME=REQUEST_INITIATIVE_SUMMARY_PARM;

*SASDOC-------------------------------------------------------------------------
| Update/Insert Report Request for Initiative ID provided
+-----------------------------------------------------------------------SASDOC*;

%MACRO REQUEST_INITIATIVE_SUMMARY_PARM(INITIATIVE_ID=);

PROC SQL NOPRINT;
  SELECT COUNT(*) INTO :REQUEST_COUNT
  FROM &HERCULES..TREPORT_REQUEST
  WHERE REQUEST_ID = &INITIATIVE_ID.;
QUIT;

%PUT NOTE: Report request id found count = &REQUEST_COUNT;

%set_error_fl2; /* No rows found is ok */
%on_error(ACTION=ABORT, EM_TO=&EMAIL_IT,
	EM_SUBJECT="HCE SUPPORT:  Notification of Abend - Request_Initiative_Summary_Parm Macro",
	EM_MSG="A problem was encountered locating request id for initiative.  See LOG file for Initiative_ID &Initiative_ID");

%IF &REQUEST_COUNT. GT 0 %THEN
	%DO;
		PROC SQL;
  			CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
  			EXECUTE(UPDATE HERCULES.TREPORT_REQUEST
				SET REPORT_ID = 998
				    ,REQUIRED_PARMTR_ID = 1
					,SEC_REQD_PARMTR_ID = 0
					,JOB_START_TS = NULL
					,JOB_COMPLETE_TS = NULL 
					,HSU_TS = CURRENT TIMESTAMP
				WHERE REQUEST_ID = &INITIATIVE_ID.
 	 	   	) BY DB2; 
  			DISCONNECT FROM DB2;
		QUIT;
				
		%set_error_fl2; 
		%on_error(ACTION=ABORT, EM_TO=&EMAIL_IT,
			EM_SUBJECT="HCE SUPPORT:  Notification of Abend - Request_Initiative_Summary_Parm Macro",
			EM_MSG="A problem was encountered updating report request.  See LOG file for Initiative ID &Initiative_ID");

	%END;
%ELSE
	%DO;
		PROC SQL NOPRINT;
  			SELECT HSU_USR_ID INTO :HSU_USR_ID
  			FROM &HERCULES..TINITIATIVE_PHASE
  			WHERE INITIATIVE_ID = &INITIATIVE_ID.;
		QUIT;

		%PUT NOTE: HSU_USR_ID = &HSU_USR_ID.;
		
		%set_error_fl;
		%on_error(ACTION=ABORT, EM_TO=&EMAIL_IT,
			EM_SUBJECT="HCE SUPPORT:  Notification of Abend - Request_Initiative_Summary_Parm Macro",
			EM_MSG="A problem was encountered selecting user id for request.  See LOG file for Initiative ID &Initiative_ID");

		PROC SQL;
  			CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
  			EXECUTE(INSERT INTO HERCULES.TREPORT_REQUEST
					(REQUEST_ID, REPORT_ID, REQUIRED_PARMTR_ID, SEC_REQD_PARMTR_ID, JOB_REQUESTED_TS,
    				JOB_START_TS, JOB_COMPLETE_TS, HSC_USR_ID , HSC_TS , HSU_USR_ID , HSU_TS)
					VALUES	(&INITIATIVE_ID.
							,998
							,1
							,0
							,CURRENT TIMESTAMP
							,Null
							,Null
							,%BQUOTE('%TRIM(&HSU_USR_ID.)')
							,CURRENT TIMESTAMP
							,%BQUOTE('%TRIM(&HSU_USR_ID.)')
							,CURRENT TIMESTAMP)				
 	 	   	) BY DB2; 
  			DISCONNECT FROM DB2;
		QUIT;

		%set_error_fl;
		%on_error(ACTION=ABORT, EM_TO=&EMAIL_IT,
			EM_SUBJECT="HCE SUPPORT:  Notification of Abend - Request_Initiative_Summary_Parm Macro",
			EM_MSG="A problem was encountered inserting report request.  See LOG file for Initiative ID &Initiative_ID");

	%END;

%MEND REQUEST_INITIATIVE_SUMMARY_PARM;
