/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  cee_control_file_check.sas (macro)
|
| LOCATION: /PRG/sastest1/hercules/macros
|
| PURPOSE: This macro checks for control files in the cee directory and matches 
|          the opportunity file name and record count within each control file
|          with existing opportunity files and their actual record counts. 
|          If any mismatches are found, all control files and opportunity files
|          are moved to the cee archive directory to prevent further processing
|          and this program is aborted.
| INPUT: NONE
|
| TABLE USED : Auxiliary dataset - cee_ctl_xreference (map of Control file fields)
|              Auxiliary dataset - ADM_LKP.ANALYTICS_USERS
|
| OUTPUT : SAS dataset CEE_ARC.EOMS_CONTROL_FILE_CHK_RESULTS
|          
|          PDF file -  CEE_ARC.EOMS_Control_File_Errors_&datevar
|                      Generated only if matching errors found
|
|          Global var &FILE_COUNT is updated with count of opportunity files
|                 to be processed if no matching errors are found in this program.
|                     
| CALLED PROGRAMS:
|
| CALLED BY: cee_opportunity_print.sas (macro)
+-------------------------------------------------------------------------------
| HISTORY:           
|          09AUG2010 - D. PALMER  - Created this marcro for EOMS Rel 5.0 changes
|     
|                      
+-----------------------------------------------------------------------HEADER*/ 

%macro cee_control_file_check;
   
	%LET PATH=&CEEDIR ;
	%PUT &PATH ;
      
	** Cancel report titles on temporary output from proc print **;
    TITLE;

	** Set up email address for EOMS business user error reporting **; 
    PROC SQL NOPRINT;
      SELECT QUOTE(TRIM(EMAIL)) INTO :cee_business_user_email SEPARATED BY ' '
      FROM   ADM_LKP.ANALYTICS_USERS
      WHERE  UPCASE(QCP_ID) = "CEE_SUPP"
      AND UPCASE(Analytics_grp) = "ANLBUSP"; 
    QUIT; 
    *SASDOC-------------------------------------------------------------------------
	| Define control file structure. Data set cee_ctl_xreference has the mapping 
	| of the control files data types and sequence of fields. Before inputting
	| data, the file is sorted by sequence number first.
	+-----------------------------------------------------------------------SASDOC*;
	PROC SORT DATA = aux_tab.cee_ctl_xreference;
	  BY SEQUENCE;
	RUN;

	DATA _NULL_;
	  SET aux_tab.cee_ctl_xreference END=EOF;
	  I+1;
	  II=LEFT(PUT(I,4.));
	  CALL SYMPUT('SEQUENCE'||II,TRIM(SEQUENCE));
	  CALL SYMPUT('FORMATVARS'||II,TRIM(FORMATVARS));
	  CALL SYMPUT('INFORMATVARS'||II,TRIM(INFORMATVARS));
	  CALL SYMPUT('HERCULESVARS'||II,TRIM(HERCULESVARS));
	  IF EOF THEN CALL SYMPUT('XREFERENCETOTAL',II);
	RUN;    
			
	*SASDOC-------------------------------------------------------------------------
	| Create an empty temporary data set to hold the contents of control files            
    | and add fields for the control file name, opp file name, record count
    | and an error message.
	+-----------------------------------------------------------------------SASDOC*;
	DATA CTL_FILE_DRIVER;
	  FORMAT CTL_FILE_NM $CHAR80.;
      FORMAT %DO I = 1 %TO &XREFERENCETOTAL. ;
	    &&HERCULESVARS&I &&FORMATVARS&I 
		     %END;;
	  FORMAT OPP_FILE_NM $CHAR80.;
	  FORMAT OPP_FILE_REC_CNT 12.;
	  FORMAT ERR_MSG $CHAR200.;
	  SET _NULL_ (OBS=0);
	RUN;
    *SASDOC-------------------------------------------------------------------------
	| Open the directory of cee files and put all the control file names            
    | in a temp dataset. 
	+---------------------------------------------------------------------SASDOC*;
		
	DATA CTL_DIRECTORY;
	  LENGTH CTL_FILE_NAME $ 80;
	  DNAME = FILENAME("DIR" , "&PATH" ); 
	  D = DOPEN("dir"); /*To open the directory*/
	  N = DNUM(D); /*To count the number of members in the directory */
	    DO I = 1 TO N;
	      CTL_FILE_NAME = DREAD(D, I);
		  IF INDEX(CTL_FILE_NAME, ".ctl" ) > 0 THEN DO;
            OUTPUT;
			DROP DNAME D N I; 
          END;
		END;
	 RUN;

	 **Assign the count of all control files found to a variable count  **;
	 PROC SQL NOPRINT;
	   SELECT COUNT(CTL_FILE_NAME) INTO: CTL_FILE_COUNT
	   FROM CTL_DIRECTORY;
	 QUIT;
     
	 %IF &CTL_FILE_COUNT NE 0 %THEN %DO; /*Begin control file Do loop*/
       **Remove any duplicate control file names from the dataset **;
	     PROC SORT DATA=CTL_DIRECTORY NODUPKEY;
		  BY CTL_FILE_NAME;
		 RUN;

	   **Print the control file names found in the directory **;
	   **  PROC PRINT DATA=CTL_DIRECTORY **;
	   **  RUN **;

	   **Assign each control file name to a variable **;
	    DATA _NULL_;
	      SET CTL_DIRECTORY;
	      CALL SYMPUT( "CTL_FILE_NM" ||LEFT(_n_),CTL_FILE_NAME);
	    RUN;
	 %END; /*End control file Do loop*/
     *SASDOC-------------------------------------------------------------------------
	 | Loop through all control file names and ouput each files contents to a          
     | temp dataset. Also output the name of the control file and then append the
     | record to the control driver dataset. 
	 +---------------------------------------------------------------------SASDOC*;
	 %DO K=1 %TO &CTL_FILE_COUNT; /*Begin fetch control file contents Do loop*/

       %LET CTL_NAME = &&CTL_FILE_NM&K ;
       DATA CTL_FILE_CONTENT;
        FORMAT CTL_FILE_NM $CHAR80.;
		CTL_FILE_NM = "&CTL_NAME" ;
		INFORMAT %DO I = 1 %TO &XREFERENCETOTAL. ;
		    &&HERCULESVARS&I &&INFORMATVARS&I
			%END;;
        FORMAT %DO I = 1 %TO &XREFERENCETOTAL. ;
	        &&HERCULESVARS&I &&FORMATVARS&I 
            %END;;
				
	    INFILE "&CEEDIR&CTL_NAME "  DLM='|' dsd missover lrecl=5000;
		INPUT %DO I=1 %TO &XREFERENCETOTAL. ;
		   &&HERCULESVARS&I
		     %END;;
	   RUN;

	   ** Append each dataset created above to the main driver dataset **;
       PROC APPEND BASE=CTL_FILE_DRIVER
         DATA=CTL_FILE_CONTENT
	   FORCE; 
	   RUN;

	  
	 %END; /*End fetch control file contents process Do loop*/
        

    *SASDOC-------------------------------------------------------------------------
	| Open the directory of cee files and put all the opportunity file names            
    | in a temp dataset. 
	+---------------------------------------------------------------------SASDOC*;
		
	DATA OPP_DIRECTORY;
	  LENGTH OPP_FILE_NAME $ 80;
	  DNAME = FILENAME("DIR" , "&PATH" ); 
	  D = DOPEN("dir"); /*To open the directory*/
	  N = DNUM(D); /*To count the number of members in the directory */
	    DO I = 1 TO N;
	      OPP_FILE_NAME = DREAD(D, I);
		  IF INDEX(OPP_FILE_NAME, ".dat" ) > 0 THEN DO;
            OUTPUT;
			DROP DNAME D N I; 
          END;
		END;
	 RUN;
     **Assign the count of all opportunity files found to a variable count  **;
	 PROC SQL NOPRINT;
	   SELECT COUNT(OPP_FILE_NAME) INTO: OPP_FILE_COUNT
	   FROM OPP_DIRECTORY;
	 QUIT;
     *SASDOC-------------------------------------------------------------------------
	 |  If opportunity files exist, get the count of records in each file 
	 +---------------------------------------------------------------------SASDOC*;
	 %IF &OPP_FILE_COUNT NE 0 %THEN %DO; /*Begin Opportunity file processing  **/
       
     **Print the opportunity file names found in the directory **;
	    ** PROC PRINT DATA=OPP_DIRECTORY **;
	    ** RUN; **;

	 **Assign each opportunity file name to a variable **;
	 DATA _NULL_;
	    SET OPP_DIRECTORY;
	    CALL SYMPUT( "OPP_FILE_NM" ||LEFT(_n_),OPP_FILE_NAME);
     RUN;
        
     **Create a temp empty dataset to hold all opp file record counts **;
	 DATA OPP_FILE_REC_COUNTS_ALL;
		 FORMAT OPP_FILE_NM $CHAR80.;
		 FORMAT OPP_FILE_REC_CNT 12.;
		 SET _NULL_ (OBS=0);
	 RUN;

	
     *SASDOC-------------------------------------------------------------------------
	 | Loop through all opportunity file names and get each files record count.         
     | Write the count and the name of the opportunity file to the temp dataset and
     | append the record to another temp dataset containing all files record counts.  
	 +---------------------------------------------------------------------SASDOC*;
	 %DO K=1 %TO &OPP_FILE_COUNT; /*Begin fetch opp file record counts Do loop*/
       
       %LET OPP_NAME =%str(&&OPP_FILE_NM&K);
       FILENAME OPPFILE PIPE "wc -l &CEEDIR&OPP_NAME" ; 
       DATA OPP_FILE_REC_COUNT;
         FORMAT OPP_FILE_NM $CHAR80.;
		 FORMAT OPP_FILE_REC_CNT 12.;
		 OPP_FILE_NM = "&OPP_NAME" ;
        
	     INFILE OPPFILE PAD;
		 INPUT OPP_FILE_REC_CNT;
	   RUN;

	  ** Append each dataset created above to one new dataset **;
      PROC APPEND BASE=OPP_FILE_REC_COUNTS_ALL
         DATA=OPP_FILE_REC_COUNT
	  FORCE;
      RUN;  
      %END; /*End fetch opp file record counts Do loop*/
     
     *SASDOC-------------------------------------------------------------------------
	 | Merge the control file driver dataset with the dataset containing opportunity          
     | file names and associated record counts.
     | 1. Sort both datasets first using the same sort.
	 | 2. Update the Opp file name in the control driver dataset where there is a match.
	 | 3. Merge the datasets on the Opp file name only to update opp rec counts
	 |    and append opportunity files with no matching control files.
     | 4. Compare the merged results and update ERR_MSG with any errors found.
	 +---------------------------------------------------------------------SASDOC*;

      ** Remove any dup opportunity file names and counts and **;
	  ** sort by opportunity file name and record count **;
	  PROC SORT DATA=OPP_FILE_REC_COUNTS_ALL NODUPKEY;
          BY OPP_FILE_NM OPP_FILE_REC_CNT;
      RUN;
      ** Print the opportunity file names and counts **;
	  ** PROC PRINT DATA=OPP_FILE_REC_COUNTS_ALL **;
	  ** RUN **;
      
	  ** Sort the control driver dataset by opportunity file name and record count **;
      PROC SORT DATA=CTL_FILE_DRIVER;
          BY CTL_OPP_FILE_NM CTL_OPP_FILE_REC_CNT;
      RUN;
      ** Print the control file names and content **;
      ** PROC PRINT DATA = CTL_FILE_DRIVER **;
	  ** RUN **;

      ** Update Opp file name in control driver dataset where there is match **;
      PROC SQL;
      UPDATE CTL_FILE_DRIVER AS A
	     SET OPP_FILE_NM = CTL_OPP_FILE_NM
         WHERE A.CTL_OPP_FILE_NM IN 
      (SELECT DISTINCT B.OPP_FILE_NM FROM OPP_FILE_REC_COUNTS_ALL AS B
       WHERE A.CTL_OPP_FILE_NM = B.OPP_FILE_NM);
	  QUIT;
	 
      ** Merge the control driver dataset with the opportunity file record counts **;
      ** and write results to a perm dataset                                      **;
      DATA CEE_ARC.EOMS_CONTROL_FILE_CHK_RESULTS;
	    MERGE CTL_FILE_DRIVER OPP_FILE_REC_COUNTS_ALL;
	    BY OPP_FILE_NM;
	  RUN;
  
      ** Update error message in merged results dataset **;
      PROC SQL;
        UPDATE CEE_ARC.EOMS_CONTROL_FILE_CHK_RESULTS
          SET ERR_MSG = 
	      CASE WHEN CTL_FILE_NM EQ "" THEN 'MISSING CONTROL FILE'
		      WHEN OPP_FILE_NM EQ "" THEN 'MISSING OPPORTUNITY FILE'
			  WHEN CTL_OPP_FILE_REC_CNT <> OPP_FILE_REC_CNT THEN 'RECORD COUNTS DO NOT MATCH'
		  ELSE '' END;
	  QUIT;

     **Assign the count of file matching errors found to a variable count  **;
	 PROC SQL NOPRINT;
	   SELECT COUNT(*) INTO: ERR_MSG_COUNT
	   FROM CEE_ARC.EOMS_CONTROL_FILE_CHK_RESULTS WHERE ERR_MSG NE "" ;
	 QUIT; 
       
     %END; /*End Opportunity file processing */
   
	 *SASDOC-------------------------------------------------------------------------
	 | Wrap up program. If no errors found, update global var &FILE_COUNT with number 
     | of opportunity files in cee directory.  
	 | If errors were found, move all control and opportunity files to the
	 | archive folder, send an email of the errors found and abort this program.
     +---------------------------------------------------------------------SASDOC*;
     ** Clear titles *;
	  TITLE;

     %IF &CTL_FILE_COUNT EQ 0 AND &OPP_FILE_COUNT EQ 0 %THEN %DO;
	    %PUT NOTE: NO CONTROL FILES OR OPPORTUNITY FILES ARE PRESENT FOR THE DAY.;
        %LET FILE_COUNT=%TRIM(%LEFT(&OPP_FILE_COUNT));
     %END;
     %ELSE %DO; /* Begin wrap up processing */
        PROC PRINT DATA=CEE_ARC.EOMS_CONTROL_FILE_CHK_RESULTS;
		RUN;
		
        ** Update global var with count of opportunity files to process if no errors found**;
        %IF &ERR_MSG_COUNT EQ 0 %THEN %DO;
            %LET FILE_COUNT=%TRIM(%LEFT(&OPP_FILE_COUNT));
		%END;
		%ELSE %DO; /* Begin handle errors */ 
		   ** Move all control files and opportunity files to archive folder.**;
		   %PUT NOTE: Control files and Opportunity files do not match. Program is being aborted.;
	       x "compress /herc&sysmode/data/hercules/gen_utilities/sas/cee/*.*" ; *RG: CHANGED THE PATH;
           x "mv /herc&sysmode/data/hercules/gen_utilities/sas/cee/*.*  /herc&sysmode/data/hercules/gen_utilities/sas/cee_archive" ;
      
           ** Create report of errors found **;
           %LET DATEVAR=%SYSFUNC(DATE(),YYMMDDN8.);
		  
		   %LET CTLREPT_PATH = "/herc&sysmode/data/hercules/gen_utilities/sas/cee_archive/EOMS_Control_File_Errors_&datevar..pdf" ;
   
           OPTIONS TOPMARGIN=.5 BOTTOMMARGIN=.5 RIGHTMARGIN=.25 LEFTMARGIN=.25
		    ORIENTATION=LANDSCAPE PAPERSIZE=LETTER;
		   ods listing close;
           ods pdf file = &CTLREPT_PATH NOTOC startpage=no;
		   ods proclabel ' ';
		   TITLE1 'EOMS CONTROL FILE CHECK REPORT' ;
		   TITLE2 'Control file vs Opportunity file matching errors' ;

           PROC REPORT DATA=CEE_ARC.EOMS_CONTROL_FILE_CHK_RESULTS NOWD;
		     COLUMN CTL_FILE_NM OPP_FILE_NM CTL_OPP_FILE_REC_CNT OPP_FILE_REC_CNT ERR_MSG;
			 DEFINE CTL_FILE_NM /'Control file name' ;
			 DEFINE OPP_FILE_NM / 'Opportunity file name' ;
             DEFINE CTL_OPP_FILE_REC_CNT /'Control Opportunity file record count' ;
             DEFINE OPP_FILE_REC_CNT / 'Actual Opportunity file record count' ;
			 DEFINE ERR_MSG / 'Error Description' ;
		   QUIT;

           ods pdf close;
		   ods listing;
          
		   ** Send email with errors found **;
         filename mymail email 'qcpap020@dalcdcp' ;  
/*           filename mymail email 'qcpap020@tstsas1' ;*/
           DATA _NULL_;
	           file mymail
             to=(&cee_business_user_email.) 
/*			   to=('greg.dudley@caremark.com')*/
             cc=(&primary_programmer_email.)  
			   subject='EOMS Opportunity files rejected'
			   attach=(&CTLREPT_PATH
               ct="application/pdf") ;;
			   put "Clinical Fulfillment," ;
			   put / " This is an automatically generated message to inform you that the Opportunity files received from EOMS were NOT processed" ;
			   put  "due to errors encountered while matching the Control files to the Opportunity files. Attached is a summary report of the" ;
			   put  "errors. Please have the files corrected and resubmitted to Hercules." ;
			   put / "Thanks," ;
			   put / "Hercules Support" ;
           RUN;

           ** Abort this program **;
           %set_error_fl(err_fl_l=1);
         %on_error(ACTION=ABORT, EM_TO=&primary_programmer_email, 
/*		   %on_error(ACTION=ABORT, EM_TO='greg.dudley@caremark.com' ,*/
           EM_SUBJECT="HCE SUPPORT:  Notification of Abend - EOMS Opportunity files rejected" ,
           EM_ATTACH=&CTLREPT_PATH,
           EM_MSG="Errors detected by macro - cee_control_file_check. Control files and Opportunity files received from EOMS do not match. All files have been moved to the cee_archive directory." );
		%END; /* End handle errors */
     %END; /* End wrap up processing */
	 
%mend cee_control_file_check ;
