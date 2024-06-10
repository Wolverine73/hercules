/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Tuesday, August 10, 2004      TIME: 01:44:36 PM
   PROJECT: macros
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\macros.seg
---------------------------------------- */
  %MACRO Chk_dir(dir_name); 
   DATA _NULL_;
    IF FILEEXIST("&dir_name")=0 THEN rc=SYSTEM("mkdir -p &dir_name");
	ELSE rc=0;
	CALL SYMPUT('err_cd',COMPRESS(PUT(rc,12.)));
   RUN;
   %PUT err_cd=&err_cd.;
  %MEND; 
