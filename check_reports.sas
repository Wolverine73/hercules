
%MACRO CHECK_REPORTS;

PROC SQL;

CONNECT TO DB2 AS DB2(DSN=&UDBSPRP); 
	create table check_reports as
	select * from connection to db2 (
	SELECT DISTINCT 1
  	FROM &HERCULES..TREPORT_REQUEST REQ
 	WHERE REQ.JOB_REQUESTED_TS IS NOT NULL
       AND REQ.JOB_START_TS IS NULL
       AND REQ.JOB_COMPLETE_TS IS NULL
       AND REQ.REPORT_ID IN (30,31,32,1)
	   AND TIMESTAMPDIFF (4,(CHAR(CURRENT TIMESTAMP - REQ.JOB_REQUESTED_TS))) < 30
 ); 

DISCONNECT FROM DB2;
QUIT;
/*1 = Microseconds 2 = Seconds 4 = Minutes*/
/*8 = Hours 16 = Days 32 = Weeks*/
/*64 = Months 128 = Quarters 256 = Years*/
%NOBS(check_reports);
%IF &NOBS %THEN %DO;
	%email_parms( 
		EM_TO="Sergey.Biletsky@cvscaremark.com"
/*		,EM_CC="Sergey.Biletsky@cvscaremark.com"*/
		,EM_SUBJECT="Report(s) requested"
		,EM_MSG="Reports were requested." );
%END;

%MEND CHECK_REPORTS;

%include '/user1/qcpap020/autoexec_new.sas';

%set_sysmode;

%INCLUDE "/herc&sysmode./prg/hercules/hercules_in.sas"; 

OPTIONS MLOGIC MPRINT;
/*options fullstimer mprint mlogic symbolgen source2 mprintnest mlogicnest;*/

%CHECK_REPORTS;

