*HEADER------------------------------------------------------------------------
 |
 | PROGRAM:  runstats.sas
 |
 | LOCATION: /PRG/sas&sysmode.1/hercules/macros
 |
 | PURPOSE:  RUNSTATS is the utility in DB2® Universal Database? (DB2 UDB) 
 |           that updates catalog statistics used by the optimizer to 
 |           determine the fastest path to your data. With DB2 UDB V8.2, the 
 |           number of RUNSTATS options have increased considerably. 
 |           Understanding how to use RUNSTATS, with both the existing 
 |           options and the new ones, can help you gain optimal performance 
 |           for your database. 
 |
 |
+-------------------------------------------------------------------------------
 | HISTORY:  Hercules Version  2.0.1
 |           December 21, 2007 - G. Dudley
 |           Make poratable across all environments
 |           Add header box
 |          
+-----------------------------------------------------------------------HEADER*/;
%MACRO runstats(db_name=&UDBSPRP_DB,tbl_name=,user=,password=);
%GLOBAL user_UDBSPRP password_UDBSPRP;
 %GLOBAL stats_err_cd;
 %LOCAL stats_err_cd_l;
 %LOCAL tbl_name;


%IF (&db_name =ANARPT OR &db_name =ANARPTAD OR &db_name =ANARPTQA or &db_name =UDBSPRP)
    AND 
    (&user= AND &password= )
    AND 
    (&password_UDBSPRP NE DUMMY)
%THEN
		%DO;
	  %LET user=&user_UDBSPRP;
	  %LET password=&password_UDBSPRP;
		%END;

%IF &db_name 	NE 	%THEN %LET db_name=TO &db_name;
%IF &user 		NE 	%THEN %LET user=user ;
%IF &password 	NE 	%THEN %LET password=using %BQUOTE(')&password.%BQUOTE(');
	

  SYSTASK COMMAND "db2 connect &db_name &user &password " TASKNAME=CONNECT WAIT  CLEANUP;
  SYSTASK COMMAND "db2 RUNSTATS ON TABLE &tbl_name WITH DISTRIBUTION AND INDEXES ALL" 
                   TASKNAME=RUNSTATS WAIT  STATUS=stats_err_cd_l CLEANUP;
  SYSTASK COMMAND "db2 terminate" TASKNAME=DISCONNECT WAIT  CLEANUP;

  %LET stats_err_cd=&stats_err_cd_l;
  %PUT stats_err_cd=&stats_err_cd;
%MEND runstats;

					/* Usage examles */
	/* For Zeus database (DSN=UDBSPRP) one need only to specify 
       table name. For example, */

 /* %runstats(tbl_name=QCPI514.BITCODE);  */
	
 /* For any other data base one should also specify data base name, 
   user name and password	*/
 					
/* %runstats(db_name=UDBDWP,tbl_name=QCPI514.ACTIVE_CPG,user=qcpi514,password=mypass); */
 
