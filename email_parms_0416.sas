/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Monday, May 05, 2003      TIME: 11:58:31 AM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: 21Sep2001      TIME: 04:47:23 PM
   PROJECT: copay_drug_cov
   PROJECT PATH: /PRG/sasprod1/drug_coverage/copay_drug_cov.seg
---------------------------------------- */

%MACRO email_parms(EM_TO=,EM_CC=,EM_SUBJECT=,EM_MSG=,EM_ATTACH=);
/*OPTIONS NOSYNTAXCHECK;*/
%GLOBAL Err_cd Message;

FILENAME mail_out EMAIL "sasadm@dalcdcp" ;  

DATA _NULL_;
   ARRAY EM{3} $ 5000 EM_TO EM_CC EM_ATTACH  ; 
   LENGTH EM_SUBJECT $ 5000 EM_MSG $32000 ; 

    EM_TO=LEFT(SYMGET('EM_TO'));
	EM_CC=LEFT(SYMGET('EM_CC'));
	EM_SUBJECT=LEFT(SYMGET('EM_SUBJECT'));
	EM_MSG=LEFT(SYMGET('EM_MSG'));
	EM_ATTACH=LEFT(SYMGET('EM_ATTACH'));

 DO i=1 TO 3;
  IF DEQUOTE(EM{i})='' THEN EM{i}='';
  IF  EM{i} NE '' THEN  
                      DO;
  IF INDEX(EM{i},'"')=0 AND INDEX(EM{i},"'")=0 THEN EM{i}=QUOTE(EM{i});
            EM{i}='(' || TRIM(LEFT(EM{i})) || ')';          
                      END;
 END;
  FILE mail_out LRECL=32000;

  PUT   '!EM_TO!' EM_TO;
  PUT   '!EM_CC!' EM_CC; 
  PUT   '!EM_SUBJECT!' EM_SUBJECT ;
  PUT   EM_MSG;      
  PUT   '!EM_ATTACH!' EM_ATTACH ;
  PUT   '!EM_SEND!';
  PUT   '!EM_NEWMSG!';

    PUT '!EM_ABORT!';
	IF _ERROR_ THEN DO;
                 CALL SYMPUT('Err_cd',1);
				 CALL SYMPUT('Message',SYSMSG());
				    END;
	ELSE         CALL SYMPUT('Err_cd',0);      
RUN;
FILENAME mail_out CLEAR;
%MEND;

/* %Email(work.email_tbl); */
