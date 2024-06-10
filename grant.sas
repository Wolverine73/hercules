*HEADER------------------------------------------------------------------------
 |
 | PROGRAM:  grants.sas
 |
 | LOCATION: /PRG/sas&sysmode.1/hercules/macros
 |
 | PURPOSE:  DB2 permission grant
 |
 |
+-------------------------------------------------------------------------------
 | HISTORY:  Hercules Version  2.0.1
 |           December 21, 2007 - G. Dudley
 |           Make poratable across all environments
 |           Add header box
 |          
+-----------------------------------------------------------------------HEADER*/;
%MACRO grant(db_name=&UDBSPRP_DB,tbl_name=,grant_opt=all,group=anladmp,user=,password=);
%GLOBAL grant_err_cd;

%IF (&db_name =UDBSPRP OR &db_name = ANARPT OR &db_name =ANARPTAD OR &db_name =ANARPTQA)
	AND &user= AND &password= AND &user_UDBSPRP NE AND 
&password_UDBSPRP NE  AND &password_UDBSPRP NE DUMMY
%THEN
		%DO;
	  %LET user=&user_UDBSPRP;
	  %LET password=&password_UDBSPRP;
		%END;


 %IF &user     NE %THEN %LET user=%STR(USER=&user);
 %IF &password NE %THEN %LET password=%STR(PASSWORD=&password);

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&db_name &user &password);
	EXECUTE(grant &grant_opt on &tbl_name to &group) BY DB2;
	 %LET SQLRC1=&SQLXRC;	
     DISCONNECT FROM DB2;
  QUIT;
		          %IF &SQLRC1=0 AND &SQLRC=0 %THEN 
									 %DO;
								%LET 	grant_err_cd=0;
									  %END;
				  %ELSE %LET 	grant_err_cd=1;

  %PUT grant_err_cd=&grant_err_cd;
%MEND;

						/* Usage examles */
/* For Zeus database (DSN=UDBSPRP) one need only to specify table name */
/* By default the macro grants ALL permissions to the group anladmp */

* %grant(tbl_name=SASADM.ACTIVE_CPG);

  /* To grant permissions to the group other then anladmp or
     to grant other then ALL permissions one need to specify 
     corresponding parameters explicitly. For example,
	 to grant only SELECT permission to the group anlsum1 
     one should use 
 */

* %grant(tbl_name=SASADM.ACTIVE_CPG,group=anlsum1,grant_opt=select);

/* For any data base other then UDBSPRP one should also specify data 
  base name, user name and password	*/
 					
* %grant(db_name=UDBSPRP,tbl_name=SASADM.ACTIVE_CPG,grant_opt=all,group=anladmp,user=sasadm,password=sasadm);
* %grant(db_name=UDBSPRP,tbl_name=SASADM.ACTIVE_CPG,grant_opt=all,group=USER QCPI514,user=sasadm,password=sasadm);
* %grant(db_name=UDBSPRP,tbl_name=SASADM.ACTIVE_CPG,grant_opt=all,group=anladmp WITH GRANT OPTION,user=sasadm,password=sasadm);


 
