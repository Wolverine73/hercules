%include '/home/user/qcpap020/autoexec_new.sas'; 
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  cee_opportunity_print.sas (macro)
|
| LOCATION: /PRG/sastest1/hercules/macros
|
| PURPOSE: This driver program will process oppportunity files sent by CEE for
|	brand to generic targetting. The two programs covered under this 
|	targetting are
|	
|	1) Targeted Generic Alternative Mailing (TGAM): The focus of the program is 
|	to move members from brand drugs to generic alternative drugs.
|	Program Ids pertaining to this program are 
|	    5252 - TGAM Default
|	    5253 - TGAM - PPI
|	    5254 - TGAM - NSA
|	    5255 - TGAM - ACE
|	    5256 - TGAM - HMG
|
|
|	2) Generic Co-Pay Incentive (GCI): The focus of the program is to move 
|	members from non-preferred brand drugs to preferred brand or generic drugs. 
|	This program differs from TGAM in that members are given an additional 
|	incentive to change drugs (waiver of the co-pay for a specific number of
|	fills). This aims to deliver opportunities to members via 
|	print and IVR channels.
|	Program Ids pertaining to this program are 
|	    5270 - GCI Default
|	    5296 - GCI Single Source Brand Generic Co-pay Waiver 
|	    5297 - GCI Multi Source Brand Generic Co-pay Waiver 
|
|
|  
| LOGIC : 	
|             1.Import opportunity file into a temprary dataset 
|             2.Divide this dataset into datasets with unique program id
|             3.Assign initiative id for each of these datasets ()
	      4.Create pending data set
|             5.Assign default template id
|             6.Read from override table to update template id 
|             7.Release file to clinical ops
| INPUT : NONE
| 
| OUPUT : Release file to clinical ops
|
+-------------------------------------------------------------------------------
| HISTORY:           
|
+-----------------------------------------------------------------------HEADER*/ 

OPTIONS MPRINT MPRINTNEST MLOGIC MLOGICNEST SYMBOLGEN SOURCE2;
options sysparm='INITIATIVE_ID=6644 PHASE_SEQ_NB=1';
%set_sysmode (mode=dev2);
%INCLUDE "/herc&sysmode/prg/hercules/hercules_in.sas";
%INCLUDE "/herc&sysmode/prg/hercules/gen_utilities/sas/cee/cee_opportunity_print_file_in.sas";

%GLOBAL FILE_COUNT  ;



*SASDOC-------------------------------------------------------------------------
| Driver program - Begins               
+-----------------------------------------------------------------------SASDOC*;

%MACRO CEE_OPPORTUNITY_PRINT_FILE ;

	%CEE_OPPORTUNITY_FILE_CHECK ;
	 

  **CHECKING FOR THE FILE COUNT	**;
/* %IF &FILE_COUNT NE 0 %THEN %DO ;*/
	PROC SQL ;
	  CREATE TABLE CEE_FILE_NAMES_LOOP AS
	  SELECT DISTINCT FILE_NAME  
	  FROM CEE_FILE_NAMES;
	QUIT ; 
	*SASDOC-------------------------------------------------------------------------
	| DATA CHECK ADDED BY GREG D. 22JUN2009
	+-----------------------------------------------------------------------SASDOC*;
  PROC PRINT DATA=CEE_FILE_NAMES_LOOP;
  RUN;
	 **ASSIGING ALL THE FILE NAMES TO A MACRO VARIABLE FILE_NAMES**;
	*SASDOC-------------------------------------------------------------------------
	| SYMPUTX CHANGED TO SYMPUT BY GREG D. 22JUN2009
	+-----------------------------------------------------------------------SASDOC*;
	DATA _NULL_; 
	  SET CEE_FILE_NAMES_LOOP;
	  CALL SYMPUT("FILE_NAME"||LEFT(_n_), FILE_NAME);
	RUN;

	*SASDOC-------------------------------------------------------------------------
	| Loop through all the files recieved from CEE.        
	+-----------------------------------------------------------------------SASDOC*;
    	%DO K=1 %TO &FILE_COUNT ; 
           
		%LET  NAME=&&FILE_NAME&K ;
		*SASDOC-------------------------------------------------------------------------
		| DATA CHECK ADDED BY GREG D. 22JUN2009
		+-----------------------------------------------------------------------SASDOC*;
    		%PUT NOTE: FILE NAME = &NAME;
    
		*SASDOC-------------------------------------------------------------------------
		| Defining opportunity file structure. Data set cee_xreference has the mapping of
		| opportunity file v/s print vendor file, data type and sequence of fields
		+-----------------------------------------------------------------------SASDOC*;
		PROC SORT DATA = aux_tab.cee_xreference;
		  BY SEQUENCE;
		RUN;

		DATA _NULL_;
		  SET aux_tab.cee_xreference END=EOF;
		  I+1;
		  II=LEFT(PUT(I,4.));
		  CALL SYMPUT('SEQUENCE'||II,TRIM(SEQUENCE));
		  CALL SYMPUT('FORMATVARS'||II,TRIM(FORMATVARS));
		  CALL SYMPUT('CEEVARS'||II,TRIM(CEEVARS));
		  /*CALL SYMPUT('hercvars'||II,TRIM(hercvars));*/
		  IF EOF THEN CALL SYMPUT('XREFERENCETOTAL',II);
		RUN;    
		
		
		*SASDOC-------------------------------------------------------------------------
		| Create temporary data set to hold the records of opportunity file .            
		+-----------------------------------------------------------------------SASDOC*;
		DATA CEE_TEMP_DATA_&K;
			INFORMAT %DO I = 1 %TO &XREFERENCETOTAL. ;
				%IF %INDEX(&&FORMATVARS&I,MMDDYY) > 0 %THEN %DO;
                &&CEEVARS&I &&FORMATVARS&I 
				%END;
			%END;;
			FORMAT %DO I = 1 %TO &XREFERENCETOTAL. ;
			    &&CEEVARS&I &&FORMATVARS&I 
			%END;;
			INFILE "&CEEDIR&NAME " DLM='|' dsd missover lrecl=32000;
			INPUT  %DO i = 1 %TO &XREFERENCETOTAL. ;
			    &&CEEVARS&I 
			%END;;
		RUN;

       	    	PROC SORT DATA = CEE_TEMP_DATA_&K OUT = PROGRAM_ID_UNIQUE NODUPKEY;
		 	   BY PROGRAM_ID;
		RUN;
   
		
		*SASDOC-------------------------------------------------------------------------
		| Assign unique Program Ids to macro variables     
		+-----------------------------------------------------------------------SASDOC*;
		DATA _NULL_;
			  SET PROGRAM_ID_UNIQUE END=EOF;
			  I+1;
			  II=LEFT(PUT(I,4.));
			  CALL SYMPUT('PID'||II,TRIM(PROGRAM_ID));
			  IF EOF THEN CALL SYMPUT('PIDTOTAL',II);
		RUN;
		

		*SASDOC-------------------------------------------------------------------------
		| Begin loop for unique program id within each file
		+-----------------------------------------------------------------------SASDOC*;
		%DO J=1 %TO &PIDTOTAL. ;

			*SASDOC-------------------------------------------------------------------------
			 | Create JOB_4_TODAY data set with the details of the unique program. This data
			 | set will be referred by cee_insert_scheduled_initiative macro to create 
			 | the initiative
			+-----------------------------------------------------------------------SASDOC*;
			 DATA JOB_4_TODAY;
				  SET CEE_FILE_NAMES;
				  WHERE PROGRAM_ID = &&PID&J AND FILE_NAME = "&NAME.";
			  RUN;	


			
			*SASDOC-------------------------------------------------------------------------
			| Create inititive for the Program Id
			+-----------------------------------------------------------------------SASDOC*;			
			%cee_insert_scheduled_initiative ;

			*SASDOC-------------------------------------------------------------------------
			| When hercules_in is called for the first time it will not set the global
			| variables pertaining to this program/task. Once the initiaive is created
			| call the hercules_in again by passing the initiative_id to set the global 
			| variables.INITIATIVEID is a global variable created/assigned by 
			| cee_insert_scheduled_initiative macro.
			+-----------------------------------------------------------------------SASDOC*;			
			options sysparm='INITIATIVE_ID=&INITIATIVEID PHASE_SEQ_NB=1';
			%INCLUDE "/herc&sysmode/prg/hercules/hercules_in.sas";	
			
			

			*SASDOC-------------------------------------------------------------------------
			| Update the start time of the task
			+-----------------------------------------------------------------------SASDOC*;
			 %update_task_ts(START, INIT_ID=&INITIATIVE_ID,PHASE_ID=&PHASE_SEQ_NB); 
			 
			 

			*SASDOC-------------------------------------------------------------------------
			| Create pending data set for the current program id in the loop.The
			| source for creating the pending data set will be temporary data set
			+-----------------------------------------------------------------------SASDOC*;
			%cee_create_base_file;


			*SASDOC-------------------------------------------------------------------------
			| Assign the template id from Default/Override tables of Hercules based on
			| the client hierarchy.
			+-----------------------------------------------------------------------SASDOC*;			
			%cee_check_document ;

			*SASDOC-------------------------------------------------------------------------
			| Check for autorelease of file.
			+-----------------------------------------------------------------------SASDOC*;
			%autorelease_file(INIT_ID=&INITIATIVE_ID, PHASE_ID=&PHASE_SEQ_NB);  		

			%update_task_ts(FINISH,INIT_ID=&INITIATIVE_ID,PHASE_ID=&PHASE_SEQ_NB); 


			*SASDOC-------------------------------------------------------------------------
			| Insert distinct recipients into TCMCTN_PENDING if the file is not autorelease.
			| The user will receive an email with the initiative summary report.  If the
			| file is autoreleased, %release_data is called and no email is generated from
			| %insert_tcmctn_pending.
			+-----------------------------------------------------------------------SASDOC*;
			%insert_tcmctn_pending(INIT_ID=&INITIATIVE_ID, PHASE_ID=&PHASE_SEQ_NB);


			*SASDOC-------------------------------------------------------------------------
			| Auto release the file to clinical ops
			+-----------------------------------------------------------------------SASDOC*;
			%file_release_wrapper;

		%END;/*end loop each program id within each file*/

	*SASDOC-------------------------------------------------------------------------
	| Moving the opportunity file to archive folder
	+-----------------------------------------------------------------------SASDOC*;

	
	/*x"mv /DATA/sas&sysmode.1/hercules/gen_utilities/sas/cee/&NAME  /DATA/sas&sysmode.1/hercules/gen_utilities/sas/cee_archive ";*/
	/**/
	

	

	%END;/*End loop for each file*/

/*	%END ; /*END OF FILE CHECKING CONDITION*/*/


**IF NO OPPORTUNITY FILE IS PRESENT THE PROCESS WILL END BY PRINTING A MESSAGE IN THE LOG**;
/*%ELSE %PUT NOTE: NO OPPORTUNITY FILE IS PRESENT FOR THE DAY;*/

		


%mend cee_opportunity_print_file ; 

%cee_opportunity_print_file ;

*SASDOC-------------------------------------------------------------------------
| Moving the log file to another folder
+-----------------------------------------------------------------------SASDOC*;
     
       
%LET DATEVAR=%sysfunc(DATE(),YYMMDDN8.);
x"mv /herc&sysmode/prg/hercules/gen_utilities/sas/cee/cee_opportunity_print_file.log  /herc&sysmode/data/hercules/gen_utilities/sas/cee_archive/cee_opportunity_print_file_&datevar..log ";
