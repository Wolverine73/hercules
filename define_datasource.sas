/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Wednesday, July 14, 2004      TIME: 03:54:44 PM
   PROJECT: macros
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Tuesday, March 30, 2004      TIME: 12:45:33 PM
   PROJECT: set_user_password
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\Zeus_Migration\set_user_password.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Thursday, October 16, 2003      TIME: 01:50:49 PM
   PROJECT: macros
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Monday, June 30, 2003      TIME: 03:07:23 PM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code modified 02JUL2009 to allow V9 default for new users
   and translate from 32 bit to 64 bit on existing dataset.
   HEAT# - 03969824
---------------------------------------- */


%MACRO define_datasource(db_name=UDBSPRP,user=,password=,test=Y,delete=N);
 OPTIONS NONOTES;
LIBNAME __home V9 "$HOME";
%LET SYSDBRC=0;
%LET db_name=%UPCASE(&db_name);

%IF %UPCASE(&delete)=Y %THEN %LET test=N;
%IF %UPCASE(&db_name)=SASNODE OR %UPCASE(&db_name)=GOLD %THEN %LET test=N;
%IF %UPCASE(&test)=Y %THEN  %DO;
 LIBNAME __TEST DB2 DSN=&db_name USER=&user PASSWORD=&password;
                                   %END;

%IF &SYSDBRC=0 AND &delete=N %THEN
      %DO;
PROC SQL NOPRINT;
 SELECT COUNT(*) INTO : N_ROWS
  FROM __home.datasources
   WHERE db_name="&db_name"
;
QUIT;
   %IF &N_ROWS=0  %THEN
                                                %DO;

%tran_datasources ;
LIBNAME __home V9 "$HOME";


 PROC SQL;
 INSERT INTO   __home.datasources(db_name,user,password)
  VALUES("&db_name","&user","&password")
;
QUIT;
%IF &SQLRC=0 %THEN %PUT Data source &db_name has been added successfully;
                                                %END;
        %ELSE
                                                %DO;
PROC SQL;
 UPDATE   __home.datasources
   SET user="&user", password="&password"
  WHERE db_name="&db_name"
;
QUIT;
%IF &SQLRC=0 %THEN %PUT Data source &db_name has been updated successfully;
                                            %END;
          %END;
%IF  &delete=Y %THEN
          %DO;
 PROC SQL;
 DELETE FROM   __home.datasources
  WHERE db_name="&db_name"
;
QUIT;
          %END;

  LIBNAME __TEST CLEAR;
  LIBNAME __home CLEAR;
   %list_datasources;
OPTIONS NOTES;
%MEND;
