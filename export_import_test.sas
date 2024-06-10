/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Monday, October 07, 2002      TIME: 10:34:15 AM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Wednesday, June 19, 2002      TIME: 04:52:04 PM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */
%MACRO export_import_test(db_name_in=,tbl_name_in=, File_type_in=,str_Where_in="",user_in=, password_in=,
                     db_name_out=,tbl_name_out=,File_type_out=,str_Where_out="",user_out=, password_out=,
                     fields="*",Engine=SAS_EXP_IMP,Import_Method=REPLACE_CREATE,keys=) ;

  %GLOBAL err_fl err_cd message DEBUG_FLAG SQLRC SYSDBRC SYSDBMSG;
  %LET DEBUG_FLAG=Y;

  %LET err_cd=0;
  %LET err_fl=0;
  %LET message=;
  %LET SQLRC=0;
  %LET SYSDBRC=0;
  %LET SYSDBMSG=;

%IF &DEBUG_FLAG=Y %THEN 
					%DO;
					 OPTIONS NOTES;
					 OPTIONS MLOGIC MPRINT SYMBOLGEN SOURCE2;
					%END;
%ELSE %DO;
  OPTIONS NONOTES ;
  OPTIONS NOMLOGIC NOMPRINT NOSYMBOLGEN NOSOURCE2;
  PROC PRINTTO LOG=DUMMY NEW;
  RUN;
  		%END;

  					 %LET err_cd=0;
	%IF &Engine= 		%THEN %LET Engine=SAS_EXP_IMP;
	%IF &Import_Method= %THEN %LET Import_Method=REPLACE_CREATE;

 DATA _NULL_;
   LENGTH  db_name_in  $ 1000 tbl_name_in  $ 1000 File_type_in $ 32 str_Where_in $ 1000
           user_in $ 32 password_in $ 32
           db_name_out $ 1000 tbl_name_out $ 1000 File_type_out $ 32 str_Where_out $ 1000
           user_out $ 32 password_out $ 32
           fields $ 30000 Engine $ 32 Import_Method $ 32 Keys $ 300;
   LENGTH fst_char $ 1 lst_char $ 1 pos 3 Engine_tmp $ 32;

    ARRAY parms{*}  db_name_in tbl_name_in  File_type_in str_Where_in user_in password_in
                    db_name_out tbl_name_out File_type_out str_Where_out user_out password_out
                    fields Engine Import_Method Keys ;
    
    
      CALL SYMPUT('err_cd','0');
      CALL SYMPUT('Message',' ');

	  Engine_tmp=UPCASE(TRIM(LEFT(SYMGET('Engine'))));

      DO i=1 TO DIM(parms);
       parms{i}='';                                           
       parms{i}=COMPBL(LEFT(SYMGET(VNAME(parms{i}))) ); 
       
       fst_char=SUBSTR(parms{i},1,1);     
       pos=LENGTH(TRIM(parms{i}));            
       IF pos >1 AND fst_char IN ("'",'"') THEN 
                      DO;      
       lst_char=SUBSTR(parms{i},pos,1);
       IF   fst_char=lst_char AND   
		((VNAME(parms{i}) NOT IN ('tbl_name_in','tbl_name_out') 
			OR TRIM(Engine_tmp) NE 'SAS_EXP_IMP') )
	       THEN
                             DO;
              IF pos=2 THEN parms{i}='';
              ELSE parms{i}=SUBSTR(TRIM(parms{i}),2,pos-2);
                             END;
                       END;
       
       IF VNAME(parms{i}) IN ('File_type_in','File_type_out','Engine','Import_Method')
        THEN parms{i}=UPCASE(parms{i}); 

       CALL SYMPUT(VNAME(parms{i}),TRIM(parms{i}));
        IF _ERROR_ THEN PUT 'Export_import Main:' i=  parms{i}=; 
      END;
                                                 
        IF Engine NOT IN('SAS_EXP_IMP', 'DB2_EXP_IMP')
        THEN    DO;
             CALL SYMPUT('err_cd','1');
             CALL SYMPUT('Message',"Invalid Engine name &Engine");
              STOP;
                END;

        ELSE    DO;
             CALL SYMPUT('Engine_macro','%'  || TRIM(LEFT(Engine)));
                END;

       IF _ERROR_  THEN    DO;
                        CALL SYMPUT('err_cd','1');;
                        CALL SYMPUT('Message',SYSMSG());
                         STOP;
                           END;
    PUT _ALL_; 
  RUN;

      %IF   &err_cd=0 %THEN %db2_exp_imp_test; 

	   PROC PRINTTO ;
  	   RUN;	QUIT;
 
      %IF &Err_cd=0 %THEN
                          %DO;
         %LET Message=EXPORT/Import O.K.;
         %PUT "EXPORT/Import O.K."; 
                          %END;
                          
       %ELSE              %DO;
                   %LET err_fl=&err_cd;
                   %PUT Err_cd=&err_cd;
                   %PUT err_fl=&err_fl;
                   %LET Message=%SUPERQ(Message);
                   %PUT Message=&Message;
                          %END;
         OPTIONS NOTES DATE;
		 OPTIONS NOMLOGIC NOMPRINT NOSYMBOLGEN;
 %MEND; 
