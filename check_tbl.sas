/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Thursday, June 19, 2003      TIME: 11:02:14 AM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: 10Oct2001      TIME: 03:35:54 PM
   PROJECT: copay_drug_cov
   PROJECT PATH: /PRG/sasprod1/drug_coverage/copay_drug_cov.seg
---------------------------------------- */
%MACRO check_tbl(db_name=UDBSPRP, syscat=SYSCAT,Engine=DB2,user=,password=,tbl_name=,Method=EXIST,days_pass=10,hours_pass=0,minutes_pass=0,sign=1);
%GLOBAL user_UDBSPRP password_UDBSPRP;
 %GLOBAL err_fl;
 %LOCAL err_fl_l Flag_file_name;
 
 %LET err_fl_l=1;
 %IF &err_fl= %THEN %LET err_fl=0;

 DATA _NULL_;
  LENGTH schema $ 32 tbl_name	$ 1000 tbl_name_sh	$ 1000 Method $ 32
    	 datetime_pass 8 str_Where $ 5000 str_From $ 5000 Engine $ 32
		 Datetime_var $ 32;

   Method=UPCASE(LEFT(SYMGET('Method')));
   Engine=UPCASE(LEFT(SYMGET('Engine')));
   tbl_name=LEFT(SYMGET('tbl_name'));

   pos=INDEX(TRIM(tbl_name),'.');

   IF pos=0 THEN   tbl_name_sh=tbl_name;
   ELSE 	DO;
        schema=UPCASE(SUBSTR(tbl_name,1,pos-1));
        tbl_name_sh=UPCASE(SUBSTR(tbl_name,pos+1));
            END;
	datetime_pass=24*3600*&days_pass+3600*&hours_pass+60*&minutes_pass;

	IF 		TRIM(Engine)='DB2' THEN 
						 		DO;
	str_From='tmp_sys.tables';
	str_Where='TABSCHEMA="&schema" AND TABNAME="&tbl_name_sh"';
	IF TRIM(Method)='DATE' THEN Datetime_var='stats_time';
						 		END;
	ELSE IF TRIM(Engine)='SAS' THEN
								DO;
	str_From='sashelp.vtable';
	str_Where='libname="&schema" AND memname="&tbl_name_sh"';
	IF TRIM(Method)='DATE' THEN Datetime_var='modate';
						 		END;

	IF TRIM(Method)='DATE' 
    THEN str_Where=TRIM(str_Where) ||
				   ' AND &sign*SUM(DATETIME(),-&Datetime_var,-&datetime_pass)<0' ;
						
	CALL SYMPUT('schema',TRIM(schema));
	CALL SYMPUT('tbl_name_sh',TRIM(tbl_name_sh));
	CALL SYMPUT('datetime_pass',TRIM(datetime_pass));
	CALL SYMPUT('str_From',TRIM(str_From));
	CALL SYMPUT('str_Where',TRIM(str_Where));
	CALL SYMPUT('Datetime_var',TRIM(Datetime_var));
	* PUT _ALL_;
 RUN;

 %IF &db_name =UDBSPRP AND &user= AND &password= AND &user_UDBSPRP NE AND 
&password_UDBSPRP NE  AND &password_UDBSPRP NE DUMMY
%THEN
		%DO;
	  %LET user=&user_UDBSPRP;
	  %LET password=&password_UDBSPRP;
		%END;

  %IF &user     NE %THEN %LET user=%STR(USER=&user);
  %IF &password NE %THEN %LET password=%STR(PASSWORD=&password);

%IF &Engine NE SAS %THEN %DO;
 LIBNAME tmp_sys &Engine DSN=&db_name SCHEMA=%UPCASE(&syscat) &user &password ;
						 %END;

  PROC SQL   NOPRINT  ;
    SELECT (COUNT(*)=0) INTO : err_fl_l 
       FROM  &str_From
	     WHERE &str_Where 
	 ;
  QUIT;
%IF &Engine NE SAS %THEN %DO; LIBNAME tmp_sys CLEAR; %END;

%IF (&Method=NOT_EXIST) %THEN %LET err_fl_l=%EVAL((&err_fl_l=0));
%LET err_fl=%SYSFUNC(MAX(&err_fl,&err_fl_l));

%PUT err_fl=&err_fl; 
%MEND;
