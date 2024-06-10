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

/**** added 11/12/2007 R Smith ****/
%put NOTE: Running from Paul Landis library; *Hercules Macro library;

%global sysparm sysmode prg_root data_root rpt_root adhoc_root HERCULES PP;
%if %length(&mode) >0  %then %let sysmode=&mode;
%else %do; *else1;
   
   	 %if %LENGTH(&SYSPARM) >0 	%then %do; %GETPARMS; %end;
     %if %length(&sysmode) >0   %then %do; %let sysmode=&sysmode;	%end;

     %else %do;  *else2;
 
     FILENAME _pwd PIPE "echo $PWD";

     DATA _NULL_;
          INFILE _pwd;
          INPUT;
%*          CALL SYMPUT('CRNTDIR',TRIM(_INFILE_));
     /**** PL: added 5/23/12 for testing hercdev2 - REMOVE LATER ****/
     %let CRNTDIR=test;				  ****************set DEFAULT;
	 %let CRNTDIR=test;
	 %let CRNTDIR=test;
	 /**** PL: end testing hercdev2 changes ****/
     RUN;


       %if %INDEX("&CRNTDIR", prod)>0 %then %do;
           %let sysmode=prod;
           %end;
       %else %if %INDEX("&CRNTDIR", test)>0 %then %do;
             %let sysmode=test;
           %end;
       %else %if %INDEX("&CRNTDIR", qat)>0 %then %do; /*** added 1/8/2007 god ****/
             %let sysmode=qat;
           %end;

      %else %do;
	            /**** added 1/8/2007 god ****/
	            %PUT NOTE: ERROR - INVALID DIRECTORY PATH.;
			    ABORT;
                /*     %let SYSMODE=test;*/
            %end;
      %end; *else2;

    %end; *else1;

  %if &SYSMODE=prod %then %do;
   		                      %let HERCULES=HERCULES;
                              %let PP=PP; 
                          %end;
  %else 
  %if &SYSMODE=test %then %do;
                  	          %let HERCULES=HERCULES;
                              %let PP=PPT;
                          %end;
/**** added 1/8/2007 god ****/
  %else 
  %if &SYSMODE=qat %then %do;
                             %let HERCULES=HERCULES;
                             %let PP=PPQ;
                         %end;
  %else
       %*** Default setting ***; 
       %do;
 	       %let HERCULES=HERCULES;
           %let PP=PPT; 
       %end;

  %let PRG_ROOT=%STR(/PRG/sas&SYSMODE);
  %let DATA_ROOT=%STR(/DATA/sas&SYSMODE);
  %let RPT_ROOT=%STR(/REPORTS_DOC/&SYSMODE);
  %let ADHOC_ROOT=/DATA/sasadhoc;


%put NOTE: %nrstr(&SYSMODE)=&SYSMODE;
%put NOTE: %nrstr(&PRG_ROOT)=&PRG_ROOT;
%put NOTE: %nrstr(&DATA_ROOT)=&DATA_ROOT;
%put NOTE: %nrstr(&RPT_ROOT)=&RPT_ROOT;

%mend set_sysmode;
