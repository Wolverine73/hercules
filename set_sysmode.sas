/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  set_sysmode.sas (macro)
|
| LOCATION: /PRG/sasprod1/sas_macros
|
| PURPOSE:  This macro determine the system mode
|           location (unix directory) where the SAS program is executing.
|
| ASSUMPTIONS:
|
|   The &SYSMODE is assigned in the following manner:
|          e.g. when the program is run in directory '/PRG/sasprod1/anysubfolder'
|                                                             ----
|          the &sysmode will have the value of prod. Else &sysmode become test or tests 
|
| OUTPUT:  sas macro variable: &sysmode which has one of the three possible values
|          prod, test or tests
| 
|           prod - for production job,
|           test - for sas program running in the test directory
|           tests - for system test when it become available
|     note: one can overide/assign value to sysmode by using: 
|           e.g. if you want to have the sysmode set to test while running is the
|           production mode use %let sysmode=test;    
|         
| EXAMPLE: %set_sysmode;
|          libname my_lib "/DATA/&sysmode.1/mydata_folder";
|
+--------------------------------------------------------------------------------
| HISTORY:  SEP2003 - J.Hou & Yury Vilk - Original.
|           23NOV2007 - Ron Smith / Greg Dudley - Hercules Version  1.5.01
|           Added code for QAT.  Autoexec.sas must be changed for each user
|           in order to execute macros in hercules macro library first 
+------------------------------------------------------------------------HEADER*/

%macro set_sysmode(mode=);


%put NOTE: Running from Hercules Macro library herc&sysmode;

%global sysparm sysmode prg_root data_root rpt_root adhoc_root HERCULES PP;
%if %length(&mode) >0  %then %let sysmode=&mode;
%ELSE %do;
   
   	 %IF %LENGTH(&SYSPARM) >0 	%THEN %DO; %GETPARMS; %END;
     %IF %length(&sysmode) >0   %THEN %DO; %LET sysmode=&sysmode;	%END;

     %else %do;
 
     FILENAME _pwd PIPE "echo $PWD";

     DATA _NULL_;
          INFILE _pwd;
          INPUT;
          CALL SYMPUT('CRNTDIR',TRIM(_INFILE_));
     RUN;

%put "&CRNTDIR";

       %IF %INDEX("&CRNTDIR", prod)>0 %then %do;
           %let sysmode=prod;
           %END;
       %ELSE %IF %INDEX("&CRNTDIR", dev2)>0 %then %do;
             %let sysmode=dev2;
           %END;
       %ELSE %IF %INDEX("&CRNTDIR", sit2)>0 %then %do; /*** added 1/8/2007 god ****/
             %let sysmode=sit2;
           %END;
	   %else %if %index("&CRNTDIR", dev2)>0 %then %do;
             %let sysmode=dev2;
		   %end;
      %else %DO;
	  /**** added 1/8/2007 god ****/
	         %PUT NOTE: ERROR - INVALID DIRECTORY PATH.;
			 %ABORT;
/*            %LET SYSMODE=test;*/
            %END;
      %end;

    %end;

  %IF &SYSMODE=prod %THEN %DO;
   		%LET HERCULES=HERCULES;
        %LET PP=PP; 
  %END;
  %ELSE %IF &SYSMODE=dev2 %THEN %DO;
   	%LET HERCULES=HERCULES;
    %LET PP=PPT;
  %END;
/**** added 1/8/2007 god ****/
/*  %ELSE %IF &SYSMODE=qat %THEN %DO;*/
/*   	%LET HERCULES=HERCULES;*/
/*    %LET PP=PPQ;*/
/*  %END;*/
  %ELSE %IF &SYSMODE=sit2 %THEN %DO;
   	%LET HERCULES=HERCULES;
    %LET PP=PPQ;
  %END;
  %ELSE %DO;
 	%LET HERCULES=HERCULES;
    %LET PP=PPT; 
  %END;

  *%LET PRG_ROOT=%STR(/PRG/sas&SYSMODE);	*orig;
  %let PRG_ROOT=%str(/herc&SYSMODE/prg);
  *%LET DATA_ROOT=%STR(/DATA/sas&SYSMODE);	*orig;
  %let DATA_ROOT=%str(/herc&SYSMODE/data);
  *%LET RPT_ROOT=%STR(/REPORT_DOC/&SYSMODE);	*orig;
  %let RPT_ROOT=%str(/herc&SYSMODE/report_doc);
  *%LET ADHOC_ROOT=/DATA/sasadhoc;			*orig;
  %let ADHOC_ROOT=%str(/herc&SYSMODE/data/sasadhoc);


%put NOTE: %nrstr(&SYSMODE)=&SYSMODE;
%put NOTE: %nrstr(&PRG_ROOT)=&PRG_ROOT;
%put NOTE: %nrstr(&DATA_ROOT)=&DATA_ROOT;
%put NOTE: %nrstr(&RPT_ROOT)=&RPT_ROOT;

%mend set_sysmode;
