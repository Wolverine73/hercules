/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Monday, May 05, 2003      TIME: 12:00:38 PM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: 05Sep2001      TIME: 09:09:37 AM
   PROJECT: Disk_usage
   PROJECT PATH: /PRG/sasprod1/Admin/Disk_usage/Disk_usage.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: 04Sep2001      TIME: 11:11:57 AM
   PROJECT: Space_Monitor
   PROJECT PATH: /PRG/sasprod1/Admin/Space_monitor/Space_Monitor.seg
---------------------------------------- */
%MACRO email(email_tbl);
OPTIONS NOSYNTAXCHECK;
%GLOBAL Err_cd Message;

FILENAME mail_out EMAIL "sasadm@dalcdcp" ;  

DATA _NULL_; 
  SET &email_tbl END=last;
    ARRAY EM{3} EM_TO EM_CC EM_ATTACH;
    ARRAY EM_c{3} $ 10 _TEMPORARY_ ('!EM_TO!','!EM_CC!','!EM_ATTACH!'); 
  
  DO i=1 TO 3;
 IF EM{i} NE '' THEN  DO;
            EM{i}='(' || TRIM(LEFT(EM{i})) || ')';          
                      END;
  END;

  FILE mail_out LRECL=32000;

  PUT  '!EM_TO!' EM_TO;
  PUT  '!EM_CC!' EM_CC; 
  PUT '!EM_SUBJECT!' EM_SUBJECT ;
  PUT  EM_MSG;      
  PUT  '!EM_ATTACH!' EM_ATTACH ;
  PUT '!EM_SEND!';
  PUT '!EM_NEWMSG!';

    IF last THEN PUT '!EM_ABORT!';
	IF _ERROR_ THEN DO;
                 CALL SYMPUT('Err_cd',1);
				 CALL SYMPUT('Message',SYSMSG());
				    END;
	ELSE         CALL SYMPUT('Err_cd',0);      
RUN;
FILENAME mail_out CLEAR;
%MEND;

/* %Email(work.email_tbl); */
