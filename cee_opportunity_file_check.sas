
/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  cee_opportunity_file_check.sas (macro)
|
| LOCATION: /PRG/sastest1/hercules/macros
|
| PURPOSE: This macro checks the opportunity file and imports names of these file into 
|          a sas dataset
| 
| INPUT: NONE
|  
| TABLE USED : &hercules..tprogram_task 
|
| OUTPUT : SAS dataset CEE_FILE_NAMES
+-------------------------------------------------------------------------------
| HISTORY:           
|          09AUG2010 - D. PALMER  - Modified DATA step for CEE_DIRECTORY to only 
|                      fetch files ending in .dat for EOMS Rel 5.0 changes.
|                      Added read of preceeding var length fields in Data step
|                      to get the Program_ID from the Opportunity file.
|                      
+-----------------------------------------------------------------------HEADER*/ 

%macro cee_opportunity_file_check;

	

	%LET PATH=&CEEDIR ;
	%PUT &PATH ;
  **Open the directory of opportunity file and fetch all the file names  **;
  ** 09AUG2010 D.Palmer - added index check to fetch only files ending in .dat **;
	DATA CEE_DIRECTORY;
	  LENGTH FILE_NAME $ 200;
	  DNAME = FILENAME("DIR", "&PATH" ); 
	  D = DOPEN("dir"); /*To open the directory*/
	  N = DNUM(D); /*To count the number of members in the directory */
	    DO I = 1 TO N;
	      FILE_NAME = DREAD(D, I);
	      IF INDEX(FILE_NAME,".dat") > 0 THEN DO;
            OUTPUT;
		  END;
	    END;
	RUN;
   **Assigning the count of files to a variable count  **;
	PROC SQL NOPRINT;
	  SELECT COUNT(DISTINCT FILE_NAME) INTO: COUNT
	  FROM CEE_DIRECTORY;
	QUIT;

	%put NOTE:  Count of files:  &COUNT. ;
	
	data x; x=1; run;
	
	%IF &COUNT NE 0 %THEN %DO ;

	PROC SQL NOPRINT;
	  SELECT DISTINCT FILE_NAME 
	  INTO :FILENAME1 - :FILENAME%trim(%left(&count))
	  FROM CEE_DIRECTORY;
	QUIT;

	*SASDOC-------------------------------------------------------------------------
	| Create template dataset            
	+-----------------------------------------------------------------------SASDOC*;
	data CEE_FILE_NAMES;
	 format FILE_NAME $200. ;
	 set AUX_TAB.HERCULES_SCHEDULES (obs=0);
	run;

	*SASDOC-------------------------------------------------------------------------
	| This do loop will define all the columns and their values for cee_file_names
  | number of records in this dataset is equal to number of opportunity files
  | 09AUG2010 - D.Palmer Added read of preceeding var length fields to get Program_ID
  | 13OCT2010 - G. Dudley - added periods after the character informats in 
  |             the OPPFILE_PROGRAMIDS data step.
	+-----------------------------------------------------------------------SASDOC*;
    %DO I = 1 %TO 1; 

		DATA OPPFILE_PROGRAMIDS;
          INFILE "&PATH.&&FILENAME%TRIM(%LEFT(&I))" FIRSTOBS=1 DLM='|' dsd missover lrecl=32000;
		  FILE_NAME="&&FILENAME%TRIM(%LEFT(&I))";
		  INPUT COL1 :$5. COL2 :18. COL3 :$30. COL4 :$10. COL5 :$17. PROGRAM_ID :4. ;
/*		  DROP COL1 COL2 COL3 COL4 COL5; */
		RUN;

		proc sort data = OPPFILE_PROGRAMIDS nodupkey;
		 by PROGRAM_ID;
		run;

		data OPPFILE_PROGRAMIDS ;
         set OPPFILE_PROGRAMIDS ;
			** set default values;
			ADHOC_FLAG=0;
			DESCRIPTION='CEE Hercules Interface';
			MONTH='*';
			DAY='*';
			DAY_OF_WEEK='*';
			HOUR='20';
			MINUTE='0';
			BUS_USER_ID='QCPAP020';
			ADJ_ENGINE_CD=1;
			OBS=.;
			TASK_ID=.;
		run;

    TITLE1 'OPPFILE_PROGRAMIDS';
    PROC PRINT DATA=OPPFILE_PROGRAMIDS;
    RUN;
    TITLE1;

		*SASDOC-------------------------------------------------------------------------
		| Append opportunity file information 
		+-----------------------------------------------------------------------SASDOC*;
		proc append base = CEE_FILE_NAMES
		            data = OPPFILE_PROGRAMIDS
					force;
		run;


	%END;
	
	
		proc sort data = CEE_FILE_NAMES;
		 by program_id;
		run;		

		proc sort data = &hercules..tprogram_task 
		          out  = tprogram_task (keep = program_id task_id rename=(task_id=taskid));
		 by program_id;
		run;

      ** Updating taskid information in cee_file_names  **;
		data CEE_FILE_NAMES;
		 merge  CEE_FILE_NAMES (in=a)
		        tprogram_task  (in=b);
		 by program_id;
		 if a ;
		 if a and b then do;
		   task_id=taskid;
		 end;
		 drop taskid;
		run;	
	%END;

	%LET FILE_COUNT=%TRIM(%LEFT(&COUNT));

%mend cee_opportunity_file_check ;

