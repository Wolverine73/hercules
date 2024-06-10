/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Friday, June 27, 2003      TIME: 02:09:03 PM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */
 %MACRO list_datasources;
  TITLE "LIST OF DEFINED DATASOURCES";
   LIBNAME __home V8 "$HOME";
   PROC SQL;
    SELECT db_name AS DB_NAME
	 FROM __home.datasources
	;
 QUIT;
 TITLE;
  LIBNAME __home CLEAR;
 %MEND;

 
