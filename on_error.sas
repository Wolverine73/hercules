
/* HEADER ------------------------------------------------------------------------------
 |
 | PROGRAM:    on_error
 |
 | LOCATION:   /PRG/sasprod1/hercules/macros
 |
 | PURPOSE:    
 |             
 |
 | INPUT:      
 |
 | OUTPUT:     
 |             
 |
 | CREATED:    Oct2008 - Hercules Version  2.1.2.01
 | CHANGES:    Jun2012 - P. Landis - commented out call to %email_parms since cannot 
 |                                   email confidential information as per HIPAA
 + -------------------------------------------------------------------------------HEADER*/
 %MACRO on_error(ACTION=,Err_fl_l=,EM_TO=,EM_CC=,EM_SUBJECT=,EM_MSG=,EM_ATTACH=,
					  SOCKET_TO=,SOCKET_MSG=);
  OPTIONS NOSYNTAXCHECK;
  %GLOBAL Err_fl DEBUG_FLAG _SOCKET_ERROR_MSG JAVA_CALL;
  %LOCAL prg_name0;

/*  %IF &DEBUG_FLAG=Y %THEN */
/*					%DO;*/
/*					 OPTIONS NOTES;*/
/*					 OPTIONS MLOGIC MPRINT SYMBOLGEN SOURCE2;*/
/*					%END;*/
/*  %ELSE %DO;*/
/*  OPTIONS NOTES ;*/
/*  OPTIONS NOMLOGIC NOMPRINT NOSYMBOLGEN NOSOURCE2;*/
/*  		%END;*/

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

  **SASDOC ------------------------------------------------------------------------------
   | 03OCT2008 - G. Dudley
   |  If error flag is on then set the initiative status to 6 (Failed)
   +-----------------------------------------------------------------------------SASDOC*;
  %IF &Err_fl_l=1 %THEN 
	 %DO;
         proc sql noprint;
            update &hercules..tinitiative_phase
               set initiative_sts_cd = 6,
                   hsu_ts     = datetime()
             where initiative_id = &INITIATIVE_ID  
               and phase_seq_nb  = &PHASE_SEQ_NB;
         quit;

 /* The content of &_SOCKET_ERROR_MSG will be displayed in the browser.*/
   
    %IF &JAVA_CALL.=Y AND &_SOCKET_ERROR_MSG NE %STR() %THEN 
		%DO; 
			%LET EM_TO=%STR(); 
		%END;

    %IF %SUPERQ(EM_TO) NE %STR() %THEN 
		%DO;
/*		    %email_parms(EM_TO=&EM_TO,
                         EM_CC=&EM_CC,
                    EM_SUBJECT=&EM_SUBJECT,
                        EM_MSG=&EM_MSG,
                     EM_ATTACH=&EM_ATTACH); */
		%END;

    %IF &JAVA_CALL.=Y %THEN 
		%DO; 
            %IF &_SOCKET_ERROR_MSG.= %STR() %THEN 
               %DO; 
                   %LET _SOCKET_ERROR_MSG=&SOCKET_MSG.; 
               %END;
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
%MEND;
