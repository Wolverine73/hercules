/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Monday, September 22, 2003      TIME: 04:40:20 PM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */
%MACRO reorg(db_name=UDBSPRP,tbl_name=,index_name=,user=,password=);
%GLOBAL user_UDBSPRP password_UDBSPRP;
 %GLOBAL reorg_err_cd;
 %LOCAL reorg_err_cd_l;
 %LOCAL tbl_name;

 %IF &db_name =UDBSPRP AND &user= AND &password= AND &user_UDBSPRP NE AND 
&password_UDBSPRP NE  AND &password_UDBSPRP NE DUMMY
%THEN
		%DO;
	  %LET user=&user_UDBSPRP;
	  %LET password=&password_UDBSPRP;
		%END;

%IF &db_name 	NE 	%THEN %LET db_name=TO &db_name;
%IF &user 		NE 	%THEN %LET user=user &user;
%IF &password 	NE 	%THEN using %BQUOTE(')&password.%BQUOTE(');

  SYSTASK COMMAND "db2 connect &db_name &user &password " TASKNAME=CONNECT WAIT  CLEANUP;
  SYSTASK COMMAND "db2 REORG TABLE &tbl_name INDEX &index_name" 
                   TASKNAME=RUNreorg WAIT  STATUS=reorg_err_cd_l CLEANUP;
  SYSTASK COMMAND "db2 terminate" TASKNAME=DISCONNECT WAIT  CLEANUP;
  %LET reorg_err_cd=&reorg_err_cd_l;
  %PUT reorg_err_cd=&reorg_err_cd;
%MEND;

							/* Usage examles */
	/* For Zeus database (DSN=UDBSPRP) one need only to specify 
       table name and index name. For example, */

/*
 %reorg(tbl_name=SASADM.ACTIVE_CPG,index_name=SASADM.ACTIVE_CPG_INDEX);
 %reorg(tbl_name=QCPI514.PB_DR_COV_M_COV_R,index_name=QCPI514.MON_PB_R_PB_M_DR);
*/
	
 /* For any other data base one should also specify data base name, 
   user name and password	
*/

* %reorg(db_name=UDBDWP,tbl_name=SASADM.ACTIVE_CPG,index_name=SASADM.ACTIVE_CPG_INDEX,user=qcpi514,password=mypass);
 					
