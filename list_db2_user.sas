/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Friday, October 10, 2003      TIME: 11:48:48 AM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */

/*HEADER------------------------------------------------------------------------

 PROGRAM:  list_db2_user

 LOCATION: /PRG/sasprod1/sas_macros

 PURPOSE:   To find a status of queries in the database.
			 The utility parses a file that DB2 updates every few minutes. 
		 Consequently there may be a few minutes delay between what the utility 
		 shows and what is in the database


 INPUT:    Macro parameters:  user_id and status
 OUTPUT:   Report about status of DB2 queries

 USAGE EXAMPLES: 
1)	To see your own executing or pending queries:
 %list_db2_user;

2) To see all executing or pending query for user qcpxxxx:
  %list_db2_user(user_id=qcpxxxx);  
 
3) To see executing or pending query for all users:
 %list_db2_user(user_id=_all_);

4)	To see all connections (including Waiting, Idle and so on) for all users:
%list_db2_user(user_id=_all_, status=_all_);     
--------------------------------------------------------------------------------
 HISTORY:  Written 10Oct2003 Yury Vilk
		

+------------------------------------------------------------------------HEADER*/
%MACRO list_db2_user(user_id=,status=);
 
%LET user_id=%LOWCASE(&user_id);
%LET status=%LOWCASE(&status);
 FILENAME list_db2 PIPE "list_db2_user &user_id &status";
 %IF &user_id=_all_ %THEN %LET user_str=%STR(all users);
 %ELSE 					   %LET user_str=&user_id;

 DATA WORK.__LIST_DB2A;
     INFILE list_db2   EXPANDTABS  PAD;
	  INPUT @1 user 				$8.
			@10 Application_Name 	$15.
			@27 Application_Handle	$6.
			@60 Status 				$23.
			@84	Start_Time			$8.
				;	
	 IF VERIFY(TRIM(Application_Handle),'0123456789')=0	;
	 Start_Time=LEFT(Start_Time);
	 row_numb=_N_;	
RUN;

PROC REPORT DATA = WORK.__LIST_DB2A 
 SPLIT = '\' NOWD CENTER;
COLUMN ( "Current processes on the DB2  database UDBSPRP for &user_str" 
USER  Application_Name Application_Handle Status Start_Time
	   )
		;
DEFINE USER  / 'USER' ;
DEFINE Application_Name / 'Application \ Name';
DEFINE Application_Handle / 'Application \ Handle';
DEFINE  Status / 'Status';
DEFINE Start_Time / 'Process \ Start \ Time';
run;
QUIT;
%MEND;

 
