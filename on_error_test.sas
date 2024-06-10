/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Wednesday, April 21, 2004      TIME: 01:11:40 PM
   PROJECT: macros
   PROJECT PATH: M:\qcpi514\Caremark\EG_projects\EG_projects_20\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Tuesday, January 20, 2004      TIME: 02:06:38 PM
   PROJECT: macros
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Monday, January 19, 2004      TIME: 05:46:13 PM
   PROJECT: macros
   PROJECT PATH: M:\qcpi514\Caremark\EG_projects\EG_projects_20\macros.seg
---------------------------------------- */
 %MACRO on_error_test(ACTION=,Err_fl_l=,EM_TO=,EM_CC=,EM_SUBJECT=,EM_MSG=,EM_ATTACH=,
					  SOCKET_TO=,SOCKET_MSG=);
  OPTIONS NOSYNTAXCHECK;
  %GLOBAL Err_fl program_name DEBUG_FLAG _SOCKET_ERROR_MSG JAVA_CALL;
  %LOCAL prg_name0;

  %IF &DEBUG_FLAG=Y %THEN 
					%DO;
					 OPTIONS NOTES;
					 OPTIONS MLOGIC MPRINT SYMBOLGEN SOURCE2;
					%END;
%ELSE %DO;
  OPTIONS NONOTES ;
  OPTIONS NOMLOGIC NOMPRINT NOSYMBOLGEN NOSOURCE2;
  		%END;

  %IF &Err_fl= 		%THEN %LET Err_fl=0;
  %IF &Err_fl_l= 	%THEN %LET Err_fl_l=&Err_fl;
  %IF &ACTION= 		%THEN %LET str_ACTION=CONTINUE;
  %ELSE					  %LET str_ACTION=&ACTION;

  

  %IF &Err_fl=0 %THEN
				%DO;
		%LET _SOCKET_ERROR_MSG=%STR();
				%END;

  DATA _NULL_;
   LENGTH prg_name0 $ 2000 program_name $ 2000;
     prg_name0 =GETOPTION("SYSIN");
     program_name =LEFT(SYMGET('program_name'));

	 IF prg_name0 NE '' THEN CALL SYMPUT('ACTION',"&ACTION RETURN");
	 IF program_name='' THEN CALL SYMPUT('program_name',TRIM(prg_name0));
    
  RUN;


  %IF &EM_SUBJECT= 	%THEN %LET EM_SUBJECT=%STR(Error in program &program_name);
  %IF &EM_MSG= 		%THEN %LET EM_MSG=%STR(Error in program &program_name.. &str_ACTION &program_name.. See log for detail.);
  %IF &SOCKET_MSG=  %THEN %LET SOCKET_MSG=&EM_MSG.;

  %IF &Err_fl_l=1 %THEN 
						%DO;
 /* The content of &_SOCKET_ERROR_MSG will be displayed in the browser.*/
   
    %IF &JAVA_CALL.=Y AND &_SOCKET_ERROR_MSG NE %STR() %THEN %DO; %LET EM_TO=%STR(); %END;

       %IF %SUPERQ(EM_TO) NE %STR() %THEN 
									%DO;
%email_parms(EM_TO=&EM_TO,EM_CC=&EM_CC,EM_SUBJECT=&EM_SUBJECT,EM_MSG=&EM_MSG,EM_ATTACH=&EM_ATTACH);
									%END;

 %IF &JAVA_CALL.=Y %THEN 
						%DO; 
%IF &_SOCKET_ERROR_MSG.= %STR() %THEN %DO; %LET _SOCKET_ERROR_MSG=&SOCKET_MSG.; %END;
%PUT _SOCKET_ERROR_MSG="&_SOCKET_ERROR_MSG.";
					OPTIONS OBS=0; 
						%END;
%ELSE
					   %DO;
					DATA _NULL_;
		       PUT "&str_ACTION &program_name..";
		             &ACTION.;
					  RUN;
					   %END;

         	   	%END; /*End of err_fl=1 */
	
         OPTIONS NOTES DATE;
		 OPTIONS NOMLOGIC NOMPRINT NOSYMBOLGEN;
%MEND;
