/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  create_program_data_noibenfiles.sas (macro)
|
| LOCATION: /PRG/sastest1/hercules/macros
|
| PURPOSE:  This macro will create the data files and trigger file needed for the 
|           program data in data warehouse for ibenefit initiatives.
|
|
+-------------------------------------------------------------------------------
| HISTORY:  18DEC2008 - Sudha Yaramada - Hercules Version  2.5.01
|                       Original.          
|
+-----------------------------------------------------------------------HEADER*/ 


%MACRO CREATE_PROGRAM_DATA_NOIBENFILES;

%IF &COMPLETED_INITIATIVES_COUNT = 0 OR &COMPLETED_INIT_CNT_IBNF = 0 %THEN %DO;

	%LET DALCDCP_LOC = /herc&sysmode/data/hercules/5259/program_data;

  %*SASDOC----------------------------------------------------------------------
  | define EDW FTP destinations
  +----------------------------------------------------------------------SASDOC*;

  DATA _NULL_;
    SET AUX_TAB.SET_FTP(WHERE=(DESTINATION_ROOT_DIR=upcase("&SYSMODE")
                           and DESTINATION_CD in (98,99)));
    CALL SYMPUT('EDW_FTP_HOST', TRIM(LEFT(FTP_HOST)) );
    CALL SYMPUT('EDW_FTP_USER', TRIM(LEFT(FTP_USER)) );
    CALL SYMPUT('EDW_FTP_PASS', TRIM(LEFT(FTP_PASS)) );
  RUN;  
  
  %put NOTE: EDW_FTP_HOST = &EDW_FTP_HOST. ;
  %put NOTE: EDW_FTP_USER = &EDW_FTP_USER. ;
  %put NOTE: EDW_FTP_PASS = &EDW_FTP_PASS. ;  

	*SASDOC--------------------------------------------------------------------------
	* THERE ARE NO IBENEFIT FILES TO PROCESS. SO, HARD CODING INITIATIVE_ID TO 0000
	+-----------------------------------------------------------------------SASDOC*;
	%LET INITIATIVE_ID = %STR(0000);
	%PUT &INITIATIVE_ID;

	*SASDOC--------------------------------------------------------------------------
	* DATE AND TIME FORMAT
	+-----------------------------------------------------------------------SASDOC*;
 		DATA TODAY;
			FORMAT FILEDATETIME DATETIME.;
			FORMAT DATETIME_LENGTH $20.;
			FORMAT FILEDATE yymmdd10.;
				X=DATETIME();
				FILEDATETIME=X;
				DATETIME_LENGTH = LENGTH(FILEDATETIME);
				FILEDATE = DATEPART(FILEDATETIME);
		RUN;

		PROC SQL NOPRINT;
			SELECT FILEDATETIME, FILEDATE, DATETIME_LENGTH
			INTO :FILEDATETIME1 , :FILEDATE1, :DATETIME_LENGTH
			FROM TODAY;
		QUIT;

		%PUT &FILEDATETIME1;
		%PUT &FILEDATE1;
		%PUT &DATETIME_LENGTH;


		DATA TODAY1;
			FORMAT FILEDATE $8.;
			FORMAT FILETIME $6.;
				FILEDATETIME1="&FILEDATETIME1.";
				FILEDATE1 = "&FILEDATE1."; 
				DATETIME_LENGTH = "&DATETIME_LENGTH.";
				FILEDATE=COMPRESS(FILEDATE1,'-');
				FILETIME=COMPRESS(SUBSTR(FILEDATETIME1,9,DATETIME_LENGTH),':');
		RUN;

		PROC SQL NOPRINT;
			SELECT COMPRESS(TRIM(FILEDATE)), COMPRESS(TRIM(FILETIME))
			INTO :FILEDATE, :FILETIME
			FROM TODAY1;
		QUIT;

		%PUT &FILEDATE.;
		%PUT &FILETIME.;
	
		*SASDOC--------------------------------------------------------------------------
		* FILE NAME FORMAT    - PD_IBEN.YYYYMMDD.YYYYMMDD.HHMMSS.INITIATIVE_ID
		* TRIGGER NAME FORMAT - PD_IBEN.TRIGGER 
		+-----------------------------------------------------------------------SASDOC*;

		%LET FILE_NM    = %STR(PD_IBEN.&FILEDATE..&FILEDATE..&FILETIME..&INITIATIVE_ID.); 
		%LET TRIGGER_NM = PD_IBEN.TRIGGER; 

		%PUT NOTE: FILE_NM    = &FILE_NM;
		%PUT NOTE: TRIGGER_NM = &TRIGGER_NM;

		*SASDOC--------------------------------------------------------------------------
		* CREATE DATA FILE  
		+-----------------------------------------------------------------------SASDOC*;

		DATA _NULL_;
		  FILE "&DALCDCP_LOC./&FILE_NM." DSD RECFM = V lrecl=372;   
		RUN; 

		DATA INITIATIVE_TRIGGER;
		  LENGTH
			SOURCE_NAME      $19 
			FILLER           $1 
			CREATION_DT_TIME $15
			FILE_NAME        $40  
			EXTRACT_TYPE     $1
			RECORD_LENGTH    $5
			RECORD_COUNT     $8
			START_DATE       $8
			END_DATE         $8 
			TOTAL_AMOUNT     $1  
			TOTAL_QUANTITY   $1  
			PROGRAM_NAME     $24
			FILES            $40;

			SOURCE_NAME='HERCULES';   
			FILLER=' ';         
			CREATION_DT_TIME="&FILEDATE.&FILETIME.";
			FILE_NAME="PD_IBEN.&FILEDATE..&FILEDATE..&FILETIME..&INITIATIVE_ID.";      
			EXTRACT_TYPE='F';   
			RECORD_LENGTH='372'; 
			RECORD_COUNT="0"; 
			START_DATE="&FILEDATE.";     
			END_DATE="&FILEDATE.";       
			TOTAL_AMOUNT=' ';    
			TOTAL_QUANTITY=' ';  
			PROGRAM_NAME='IBENEFIT';
			FILES="PD_IBEN.&FILEDATE..&FILEDATE..&FILETIME..&INITIATIVE_ID."; 
		RUN;

		DATA INITIATIVE_TRIGGER2;
			LENGTH FILES            $40;
			FILES="&TRIGGER_NM."; 
		RUN;

		DATA INITIATIVE_TRIGGER;
		 SET INITIATIVE_TRIGGER INITIATIVE_TRIGGER2 ; 
		RUN;				

		PROC APPEND BASE = TRIGGER
			    DATA = INITIATIVE_TRIGGER
			    FORCE;
		RUN;

		PROC SORT DATA = TRIGGER NODUPKEY;
		 BY FILES;
		RUN;

		*SASDOC--------------------------------------------------------------------------
		* FOLLOWING STEPS ARE NEEDED AS WE NEED ONLY 1 RECORD IN TRIGGER FILE EACH AND 
		* EVERY TIME THE PROCESS IS RUN
		+-----------------------------------------------------------------------SASDOC*;
		PROC SQL;
		CREATE TABLE TRIGGER1(DROP = FILE_NAME FILES) AS
		SELECT A.*, 
		SUBSTR(FILE_NAME,1,32) AS FILE_NAME1,
		SUBSTR(FILES,1,32) AS FILES1
		FROM TRIGGER A;
		QUIT;

		DATA TRIGGER1(RENAME = (FILE_NAME1 = FILE_NAME FILES1 = FILES));
		SET TRIGGER1;
		RUN;

		PROC SORT DATA = TRIGGER1 NODUPKEY;
		BY FILES;
		RUN;

		*SASDOC--------------------------------------------------------------------------
		*CREATE TRIGGER FILE
		+-----------------------------------------------------------------------SASDOC*;

		DATA _NULL_;
		  SET TRIGGER1;
		  FILE "&DALCDCP_LOC./&TRIGGER_NM." DSD RECFM = V lrecl=180; 
		  WHERE FILE_NAME NE '';
		  PUT 				
			@1	SOURCE_NAME      	$19. 
			@20	FILLER           	$1.
			@21	CREATION_DT_TIME 	$14.
			@35	FILLER           	$1.
			@36	FILE_NAME        	$40.
			@76	FILLER           	$1.
			@77	EXTRACT_TYPE     	$1.
			@78	FILLER           	$1.
			@79	RECORD_LENGTH    	$5.
			@84	FILLER           	$1.
			@85	RECORD_COUNT     	$20.
			@105	FILLER          $1.
			@106	START_DATE      $8.
			@114	FILLER          $1.
			@115	END_DATE        $8.
			@123	FILLER          $1.
			@124	TOTAL_AMOUNT    $15.
			@139	FILLER          $1.
			@140	TOTAL_QUANTITY  $15.
			@155	FILLER          $1.
			@156	PROGRAM_NAME 	$24. ;
		RUN; 	

		PROC SQL NOPRINT;
		  SELECT QUOTE(TRIM(EMAIL)) INTO :PDDW_PROGRAMMER_EMAIL SEPARATED BY ' '
		  FROM ADM_LKP.ANALYTICS_USERS
		  WHERE FIRST_NAME='PDDW'
		    AND LAST_NAME='PDDW'  ;
		QUIT;

		%PUT NOTE:  PDDW_PROGRAMMER_EMAIL = &PDDW_PROGRAMMER_EMAIL.;

		%MACRO CREATE_PDDW_REPORT;

		*SASDOC--------------------------------------------------------------------------
		* CREATE LOAD PROGRAM DATA IN DW REPORT 
		+------------------------------------------------------------------------SASDOC;
		OPTIONS  TOPMARGIN=.5 BOTTOMMARGIN=.5 RIGHTMARGIN=.5 LEFTMARGIN=.5
		ORIENTATION =PORTRAIT  PAPERSIZE=LETTER;

		ODS LISTING CLOSE;
		ODS PDF FILE="&DALCDCP_LOC./REPORT_FTP_PROGRAM_DATA_DW.PDF" NOTOC STARTPAGE=NO;
		ODS PROCLABEL ' ';

		OPTIONS NODATE;

			PROC PRINT DATA= PGRMDATA.TRIGGER_&FILEDATE;
				TITLE1 FONT=ARIAL COLOR=BLACK  H=12PT J=C  'HERCULES COMMUNICATION ENGINE';
				TITLE2 FONT=ARIAL COLOR=BLACK  H=16PT J=C  'SUMMARY OF FILES TRANSFERRED FOR PROGRAM DATA IN DW';
				TITLE3 FONT=ARIAL COLOR=BLACK  H=16PT J=C  'PROGRAM DATA IN DW FTP SUMMARY REPORT';
				TITLE4 " ";
				TITLE5 " ";
				TITLE6 " ";  
				TITLE7 " "; 
				VAR FILES ;
				FOOTNOTE1 H=8PT J=R  "HERCULES COMMUNICATION ENGINE" ;
				FOOTNOTE2 H=8PT J=R  "&DATE." ;    
			RUN;

		ODS PDF CLOSE;
		ODS LISTING;

		%MEND CREATE_PDDW_REPORT;
		
		*SASDOC--------------------------------------------------------------------------
		* FTP DATA FILES TO EDW  
		+------------------------------------------------------------------------SASDOC;

		%PUT NOTE: BEGIN FTP-ING FILES TO EDW;

		LIBNAME PGRMDATA "&DALCDCP_LOC.";

		DATA PGRMDATA.TRIGGER_&FILEDATE;
			SET TRIGGER;
		RUN;

		%IF %SYSFUNC(EXIST(PGRMDATA.TRIGGER_&FILEDATE.)) %THEN %DO;

			%ftp_data_files(server=&EDW_FTP_HOST., 
					id=&EDW_FTP_USER., 
					pw=&EDW_FTP_PASS., 
					transfermode=ascii, 
					dataset=%str(PGRMDATA.TRIGGER_&FILEDATE),
					getrootdir=%str(&DALCDCP_LOC.),
					putrootdir=%str(/incoming/dls/pgrmdata),
					removefiles1=%str(*.BSS), removefiles2=%str(*.BSS));

			X "compress -f &DALCDCP_LOC./PD_IBEN*";
			
			%PUT NOTE: END FTP-ING FILES TO EDW;
			
			%PUT NOTE: BEGIN EMAILED SUMMARY OF FILES FTP-ED TO EDW;
			
			DATA _NULL_;
			  DATE=PUT(TODAY(),WEEKDATE29.);
			  CALL SYMPUT('DATE',DATE);
			RUN;
			
			%PUT NOTE: DATE = &DATE. ;
		
			%CREATE_PDDW_REPORT;

			%PUT NOTE: END EMAILED SUMMARY OF FILES FTP-ED TO EDW;
		%END;

		%ELSE %DO;

				FILENAME MYMAIL EMAIL 'QCPAP020@DALCDCP';

				DATA _NULL_;
				    FILE MYMAIL

					TO =(&PDDW_PROGRAMMER_EMAIL)
					SUBJECT='HCE SUPPORT:  PROGRAM DATA IN DW FAILURE NOTICE';
					
				    PUT 'HELLO:';
				    PUT / "THIS IS AN AUTOMATICALLY GENERATED MESSAGE TO INFORM HERCULES SUPPORT THAT A PROBLEM WAS ENCOUNTERED IN FTP-ING THE 0 BYTE FILE AND THE TRIGGER FILE FOR PROGRAM DATA IN DW. ";
					PUT / "PLEASE CHECK THE LOG ASSOCIATED WITH THE PROGRAM.";
					PUT / 'THANKS,';
				    PUT   'HERCULES SUPPORT';
				RUN;
		%END;

%END;
%MEND CREATE_PROGRAM_DATA_NOIBENFILES;
