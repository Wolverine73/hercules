/*HEADER------------------------------------------------------------------------
 |
 | PROGRAM:  drop_db2_table.sas
 |
 | LOCATION: /PRG/sas&sysmode.1/hercules/macros
 |
 | PURPOSE:  Drop DB2 table 
 |
+-------------------------------------------------------------------------------
 | HISTORY:  Hercules Version  2.0.1
 |           December 21, 2007 - Ron Smith / Greg Dudley
 |           Make poratable across all environments
 |           Add header box
 |           Changed Hardcoding for UDBSPRP.  Use UDBSPRP_DB (set by hercules_in 
 |           or program specific IN.SAS.  
 | Revision: Hercules Version  2.1.01
 |           June 18, 2008 - SR
 |           Added %upcase function to convert the tablename parameter to CAPS, 
 |           as the code was not dropping the table if the keyword parameter
 |           tablename is passed in small caps
 |          
+-----------------------------------------------------------------------HEADER*/

%MACRO drop_db2_table(db_name=,tbl_name=,user=,password=);
OPTIONS NOTES;
 %LOCAL N TYPE pos Schema Tbl_name_sh;
 %LET N=0;
 %LET TYPE=T;

/*SASDOC---------------------------------------------
| 18JUN2008 - SR                                    |
| CONVERT THE TABLENAME PARAMETER TO CAPS           |
|--------------------------------------------SASDOC*/ 
 %LET tbl_name = %UPCASE(&tbl_name);

 %LET pos=%INDEX(&Tbl_name,.);
 %LET Schema=%SUBSTR(&Tbl_name,1,%EVAL(&pos-1));
 %LET Tbl_name_sh=%SUBSTR(&Tbl_name,%EVAL(&pos+1));

/*SASDOC---------------------------------------------
| 23NOV2007 - Ron Smith / Greg Dudley               |
| Assign to default Zeus database for environment   |
|--------------------------------------------SASDOC*/ 
%IF &db_name = %THEN
	%LET db_name=&UDBSPRP_DB;
  
/* if user and password are not supplied then use default Zeus values */
%IF &user= AND &password= AND &user_UDBSPRP NE AND 
&password_UDBSPRP NE AND &password_UDBSPRP NE DUMMY
%THEN
	%DO;	    
		%LET user=&user_UDBSPRP;
		%LET password=&password_UDBSPRP;
	%END;

/* if user and password are supplied then use them */
 %IF &user     NE %THEN %LET user=%STR(USER=&user);
 %IF &password NE %THEN %LET password=%STR(PASSWORD=&password);

 LIBNAME _SCHEMA DB2 DSN=&db_name SCHEMA=%UPCASE(&Schema) &user &password;

 PROC SQL NOPRINT;
  SELECT COUNT(*),MAX(TYPE)  INTO : N, :TYPE
   FROM _SCHEMA.TABLES(SCHEMA=SYSCAT)
    WHERE TABSCHEMA IN ("&schema")
	 AND TABNAME   IN ("&tbl_name_sh")
	 ;
 QUIT;

 %LET OBJECT_TYPE=TABLE;
 %IF 		&TYPE=A %THEN %DO; %LET OBJECT_TYPE=ALIAS; %END;
 %ELSE %IF 	&TYPE=V %THEN %DO; %LET OBJECT_TYPE=VIEW; %END;

/*SASDOC---------------------------------------------
| 23NOV2007 - Ron Smith / Greg Dudley               |
| Corrected typo in drop put statement and added    |
| object type in put statements.
|--------------------------------------------SASDOC*/ 
 %IF &N >0  %THEN
						%DO;
%PUT TIME_BEFORE_DROP_ATTEMPT=%SYSFUNC(PUTN(%SYSFUNC(DATETIME()),DATETIME19.));
%LET SQLRC1=0;
PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&db_name &user &password);
	EXECUTE(DROP &OBJECT_TYPE. &tbl_name) BY DB2;
	 %LET SQLRC1=&SQLXRC;	
     DISCONNECT FROM DB2;
  QUIT;
		          %IF &SQLRC1=0 AND &SQLRC=0 %THEN  %DO;
								%PUT &OBJECT_TYPE &tbl_name has been dropped;
									  %END;
  %PUT TIME_AFTER_DROP_ATTEMPT=%SYSFUNC(PUTN(%SYSFUNC(DATETIME()),DATETIME19.));
 						%END;
 %ELSE					%DO;
 		%PUT MACRO DROP_DB2_TABLE: &OBJECT_TYPE &tbl_name does not exist;
 						%END;
LIBNAME _SCHEMA CLEAR;
OPTIONS NOTES;
 %MEND drop_db2_table;
 						/* Usage examples */
 /*
 This macro checks whether the table exist and if it does the macro drops
 the table. 

  For Zeus database one must specify only the table name. 
  To overwrite defaults one need to specify corresponding parameters explicitly as 
   in the second example.

 %drop_db2_table(tbl_name=SASADM.LKP_ADMIN_FEE_CD);
 %drop_db2_table(tbl_name=SASADM.AFGHANIS);
 %drop_db2_table(db_name=UDBDWP,tbl_name=DB2_TMP.TEST,user=qcpi514,password=mypass);

*/
