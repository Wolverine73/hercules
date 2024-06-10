/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  create_program_data_files.sas (macro)
|
| LOCATION: /PRG/sastest1/hercules/macros
|
| PURPOSE:  This macro will create the data files and trigger file needed for the 
|           program data in data warehouse for ibenefit initiatives.
|
|
+-------------------------------------------------------------------------------
| HISTORY:  
|
| 18DEC2008 - Sudha Yaramada - Hercules Version  2.5.01
|             Original.  
|
| 04JUN2009 - Brian Stropich - Hercules Version  2.5.03
|             Added logic for program data in DW - Change Request.
|             1.  BRND_2_GNRC_FLG
|             2.  RETAIL_2_MAIL_FLG
|             3.  NON_PRFRD_2_PRFRD
|             4.  CHRONIC_IN
|             5.  FORMULARY_STATUS_CD
|             6.  BRAND_GENERIC
|             7.  ELIGIBILITY_DATE
|             8.  Create initiative data file with additional variables and lrecl
|
+-----------------------------------------------------------------------HEADER*/ 

%MACRO CREATE_PROGRAM_DATA_FILES;

	%LET DALCDCP_LOC = /herc&sysmode/data/hercules/&PROGRAM_ID./program_data;

	%LET MAIN_DATASET   = &_DSNAME.;
	%LET DETAIL_DATASET = &_DSNAME._2;

	PROC SQL NOPRINT;
	  CREATE TABLE VARIABLES AS
	  SELECT DATEPART(RELEASE_TS) AS PROGRAM_DATE FORMAT yymmdd10., 
		 DATEPART(RELEASE_TS) + 187 AS OPPORTUNITY_END_DATE FORMAT yymmdd10., 
		 DATEPART(RELEASE_TS) AS DATE_PROCESSED FORMAT yymmdd10. 
	  FROM &HERCULES..TPHASE_RVR_FILE
	  WHERE INITIATIVE_ID     = &INITIATIVE_ID
	    AND PHASE_SEQ_NB      = &PHASE_SEQ_NB
	    AND RELEASE_STATUS_CD = 2;
	QUIT;

	PROC SQL NOPRINT;
	  SELECT PROGRAM_DATE,
		 OPPORTUNITY_END_DATE,
		 DATE_PROCESSED
	  INTO :PROGRAM_DATE, :OPPORTUNITY_END_DATE, :DATE_PROCESSED
	  FROM VARIABLES;
	QUIT;
	
	PROC SQL NOPRINT;
	  CREATE TABLE VARIABLES2 AS
	  SELECT DATEPART(JOB_COMPLETE_TS) AS ELIGIBILITY_DATE FORMAT yymmdd10.
	  FROM &HERCULES..TINITIATIVE_PHASE
	  WHERE INITIATIVE_ID     = &INITIATIVE_ID ;
	QUIT;
	
	PROC SQL NOPRINT;
	  SELECT ELIGIBILITY_DATE
	  INTO :ELIGIBILITY_DATE
	  FROM VARIABLES2;
	QUIT;

	PROC SQL NOPRINT;
	  SELECT LONG_TX AS INITIATIVE_TYPE INTO: INITIATIVE_TYPE
	  FROM &CLAIMSA..TPROGRAM
	  WHERE PROGRAM_ID = &PROGRAM_ID;
	QUIT;


	/*--------------------------------------------------------------------------------------------------
	  Create a work dataset to get all the variables needed for program data.  
	--------------------------------------------------------------------------------------------------*/
	DATA DB2_MAIN ;
	 SET &DB2_TMP..&TABLE_PREFIX._MAIN ;
	 RECIPIENT_ID=PT_BENEFICIARY_ID;
	RUN;

	DATA DB2_MAIN_DATE ;
	 SET DB2_MAIN (OBS=1 KEEP = BEGIN_PERIOD END_PERIOD) ;
	RUN;

	PROC SQL NOPRINT;
	  SELECT BEGIN_PERIOD AS BEGIN_PERIOD_DATE FORMAT yymmdd10.,
		 END_PERIOD   AS END_PERIOD_DATE   FORMAT yymmdd10.
	  INTO :BEGIN_PERIOD, :END_PERIOD
	  FROM DB2_MAIN_DATE;
	QUIT;				

	DATA DB2_DETAIL ;
	 SET &DB2_TMP..&TABLE_PREFIX._DETAIL ;
	 RECIPIENT_ID=PT_BENEFICIARY_ID;
	RUN;

	DATA SAS_MAIN ;
	 SET &MAIN_DATASET (KEEP = RECIPIENT_ID DATA_QUALITY_CD) ;
	RUN;

	PROC SQL NOPRINT;
	  CREATE TABLE WORK.PROGRAMDATA_&INITIATIVE_ID AS
	  SELECT   			 
		CASE WHEN C.ADJ_ENGINE = 'QL' THEN 'Q' 
		     WHEN C.ADJ_ENGINE = 'RX' THEN 'X'
		     WHEN C.ADJ_ENGINE = 'RE' THEN 'R'	
		     ELSE ' ' 
		END 								AS SRC_SYS_CD,
		C.RECIPIENT_ID 							AS QL_BENEFICIARY_ID,
		C.CDH_BENEFICIARY_ID 						AS QL_CARDHOLDER_ID,
		C.CLIENT_ID 							AS QL_CLIENT_ID,
		CASE WHEN C.ADJ_ENGINE = 'QL'
		     THEN B.CLT_PLAN_GROUP_ID
		     ELSE 00000000000 
		END 								AS QL_CPG_ID,
        B.GPI14 								AS GPI_CODE,
		B.DRUG_TX 							AS DRUG_NAME,
		"&PROGRAM_ID"  							AS PROGRAM_ID,
		"&PROGRAM_DATE" 						AS PROGRAM_DATE,
		"&BEGIN_PERIOD" 						AS TARGET_START_DATE,
		"&END_PERIOD" 							AS TARGET_END_DATE  ,
		CASE WHEN B.GRC_PRF_ICON_CD = 0 THEN 0 
		     WHEN B.GRC_PRF_ICON_CD = 1 THEN 1
			 WHEN B.GRC_PRF_ICON_CD = 2 THEN 2
		ELSE 0 
		END 								AS BRND_2_GNRC_FLG,
		CASE WHEN B.MAIL_ICON_CD = 0 THEN 0 
		     WHEN B.MAIL_ICON_CD = 1 THEN 1
			 WHEN B.MAIL_ICON_CD = 2 THEN 2
		ELSE 0 
		END 								AS RETAIL_2_MAIL_FLG,
		CASE WHEN B.GRC_PRF_ICON_CD = 0 THEN 0 
		     WHEN B.GRC_PRF_ICON_CD = 3 THEN 3
		     ELSE 0 
		END 								AS NON_PRFRD_2_PRFRD,
		CASE WHEN (B.MAIL_ICON_CD = 2 OR 
		     B.GRC_PRF_ICON_CD IN (2,3)) 
		     THEN 'YES'
		     ELSE 'NO' 
		END 								AS SAVINGS_OPPORTUNITY,
		B.MAIL_SAVINGS_AT 						AS PROJ_SAVINGS,
		"&INITIATIVE_ID" 						AS INITIATIVE_ID,
		"&INITIATIVE_TYPE"						AS INITIATIVE_TYPE,
		' '                                     			AS EDW_ALGN_LVL_GEN_ID,
		CASE WHEN C.ADJ_ENGINE IN ('RX', 'RE') 
				THEN C.CLIENT_HIERARCHY
			 ELSE ' '
		END 								AS CLIENT_HIERARCHY,
		' ' 								AS CUSTOMER_ID,
		CASE WHEN C.ADJ_ENGINE = 'QL' 
				THEN PUT(C.RECIPIENT_ID, 12.)
		     WHEN C.ADJ_ENGINE IN ('RX', 'RE') 
				THEN C.MEMBER_ID
			ELSE ' '
		END 								AS MEMBER_ID,
		' ' 								AS EDW_MEMBER_GEN_ID,
		' ' 								AS PHYSICIAN_ID_TYPE_CD,
		"&OPPORTUNITY_END_DATE" 					AS OPPORTUNITY_END_DATE,
		"&DATE_PROCESSED" 						AS DATE_PROCESSED,
		upcase(B.DELIVERY_SYSTEM_TX)					AS DELIVERY_SYSTEM_CODE,
		upcase(B.CHRONIC_IN)   						AS CHRONIC_IN,
		B.FORMULARY_STATUS_CD  						AS FORMULARY_STATUS_CD,
		upcase(compress(B.BRAND_GENERIC,'*'))				AS BRAND_GENERIC,
		"&ELIGIBILITY_DATE" 				    		AS ELIGIBILITY_DATE

	  FROM SAS_MAIN           A,
	       DB2_DETAIL         B,
	       DB2_MAIN           C 
	  WHERE A.RECIPIENT_ID    = B.RECIPIENT_ID
	    AND A.RECIPIENT_ID    = C.RECIPIENT_ID
	    AND A.DATA_QUALITY_CD = 1;
	QUIT;	
	
	PROC SORT DATA = WORK.PROGRAMDATA_&INITIATIVE_ID NODUPKEY;
	 BY QL_BENEFICIARY_ID DRUG_NAME GPI_CODE DELIVERY_SYSTEM_CODE CHRONIC_IN
	    FORMULARY_STATUS_CD BRAND_GENERIC;
	RUN;


	/*--------------------------------------------------------------------------------------------------
	  Reformat dates based on program data requirements.                       
	--------------------------------------------------------------------------------------------------*/
	DATA WORK.PROGRAMDATA_&INITIATIVE_ID 
     (RENAME=(PROGRAM_DATE2= PROGRAM_DATE TARGET_START_DATE2= TARGET_START_DATE TARGET_END_DATE2= TARGET_END_DATE 
              OPPORTUNITY_END_DATE2= OPPORTUNITY_END_DATE DATE_PROCESSED2= DATE_PROCESSED
              ELIGIBILITY_DATE2=ELIGIBILITY_DATE));
	 SET WORK.PROGRAMDATA_&INITIATIVE_ID ;

	 Y1=SCAN(PROGRAM_DATE,1,'-');
	 M1=SCAN(PROGRAM_DATE,2,'-');
	 D1=SCAN(PROGRAM_DATE,3,'-');
	 PROGRAM_DATE2=TRIM(Y1)||TRIM(D1)||TRIM(M1);
	 
	 Y1=SCAN(TARGET_START_DATE,1,'-');
	 M1=SCAN(TARGET_START_DATE,2,'-');
	 D1=SCAN(TARGET_START_DATE,3,'-');
	 TARGET_START_DATE2=TRIM(Y1)||TRIM(D1)||TRIM(M1);

	 Y1=SCAN(TARGET_END_DATE,1,'-');
	 M1=SCAN(TARGET_END_DATE,2,'-');
	 D1=SCAN(TARGET_END_DATE,3,'-');
	 TARGET_END_DATE2=TRIM(Y1)||TRIM(D1)||TRIM(M1);

	 Y1=SCAN(OPPORTUNITY_END_DATE,1,'-');
	 M1=SCAN(OPPORTUNITY_END_DATE,2,'-');
	 D1=SCAN(OPPORTUNITY_END_DATE,3,'-');
	 OPPORTUNITY_END_DATE2=TRIM(Y1)||TRIM(D1)||TRIM(M1);

	 Y1=SCAN(DATE_PROCESSED,1,'-');
	 M1=SCAN(DATE_PROCESSED,2,'-');
	 D1=SCAN(DATE_PROCESSED,3,'-');
	 DATE_PROCESSED2=TRIM(Y1)||TRIM(D1)||TRIM(M1);

	 Y1=SCAN(ELIGIBILITY_DATE,1,'-');
	 M1=SCAN(ELIGIBILITY_DATE,2,'-');
	 D1=SCAN(ELIGIBILITY_DATE,3,'-');
	 ELIGIBILITY_DATE2=TRIM(Y1)||TRIM(D1)||TRIM(M1);

	 DROP Y1 D1 M1 PROGRAM_DATE TARGET_START_DATE TARGET_END_DATE 
          OPPORTUNITY_END_DATE DATE_PROCESSED ELIGIBILITY_DATE;
	RUN;


	/*--------------------------------------------------------------------------------------------------
	  Get the record_count for each initiative which is needed for the trigger file. 
	--------------------------------------------------------------------------------------------------*/
	PROC SQL NOPRINT;
	  SELECT COUNT(*) INTO: RECORD_COUNT
	  FROM WORK.PROGRAMDATA_&INITIATIVE_ID;
	QUIT;

%IF &INITIATIVE_ID. = &MIN_INITIATIVE_ID_IBNF. %THEN %DO;

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

		%PUT &FILEDATETIME1.;
		%PUT &FILEDATE1.;
		%PUT &DATETIME_LENGTH.;


		DATA TODAY1;
			FORMAT FILEDATE $8.;
			FORMAT FILETIME $6. ;
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

%END;
		%PUT &FILEDATE.;
		%PUT &FILETIME.;
	

	/*--------------------------------------------------------------------------------------------------
	  file name format    - PD_IBEN.yyyymmdd.yyyymmdd.hhmmss.initiativeid
	  trigger name format - PD_IBEN.TRIGGER 
	--------------------------------------------------------------------------------------------------*/	
	%LET FILE_NM    = PD_IBEN.&FILEDATE..&FILEDATE..&FILETIME..&INITIATIVE_ID.; 
	%LET TRIGGER_NM = PD_IBEN.TRIGGER; 

	%PUT NOTE: FILE_NM    = &FILE_NM;
	%PUT NOTE: TRIGGER_NM = &TRIGGER_NM;


	/*--------------------------------------------------------------------------------------------------
	  Create initiative  data file                                            
	--------------------------------------------------------------------------------------------------*/
	DATA _NULL_;
	  SET WORK.PROGRAMDATA_&INITIATIVE_ID ;
	  FILE "&DALCDCP_LOC./&FILE_NM." DSD RECFM = V lrecl=403;   
	  PUT   
		 @001 SRC_SYS_CD    		$1.	
		 @002 QL_BENEFICIARY_ID 	Z11.
		 @013 QL_CARDHOLDER_ID     	Z11.
		 @024 QL_CLIENT_ID		Z11.
		 @035 QL_CPG_ID			Z11.
		 @046 GPI_CODE			$14.
		 @060 DRUG_NAME 		$50.
		 @110 PROGRAM_ID		$11.
		 @121 PROGRAM_DATE 		$8.
		 @129 TARGET_START_DATE		$8.
		 @137 TARGET_END_DATE  		$8.
		 @145 BRND_2_GNRC_FLG		Z01. 	
		 @146 RETAIL_2_MAIL_FLG		Z01.
		 @147 NON_PRFRD_2_PRFRD		Z01.
		 @148 SAVINGS_OPPORTUNITY	$30.
		 @178 PROJ_SAVINGS		Z11.2
		 @189 INITIATIVE_ID		$30.
		 @219 INITIATIVE_TYPE 	    	$30.
		 @249 EDW_ALGN_LVL_GEN_ID   	$1.
		 @261 CLIENT_HIERARCHY      	$12.
		 @273 CUSTOMER_ID	    	$1.
		 @285 MEMBER_ID		    	$25.
		 @310 EDW_MEMBER_GEN_ID  	$1.       
		 @322 PHYSICIAN_ID_TYPE_CD 	$1.    
		 @342 OPPORTUNITY_END_DATE 	$8. 
		 @350 DATE_PROCESSED        	$8.  
         	 @358 DELIVERY_SYSTEM_CODE  	$14.
		 @373 CHRONIC_IN           	$3. 
		 @376 FORMULARY_STATUS_CD  	$1. 
		 @377 BRAND_GENERIC        	$18. 
		 @395 ELIGIBILITY_DATE     	$8. ;
	RUN; 

	DATA INITIATIVE_TRIGGER;
	  LENGTH
		SOURCE_NAME      $19 
		FILLER           $1 
		CREATION_DT_TIME $15
		FILE_NAME        $40  
		EXTRACT_TYPE     $1
		RECORD_LENGTH    $5
		RECORD_COUNT     8
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
		RECORD_COUNT="&RECORD_COUNT."; 
		START_DATE="&FILEDATE.";     
		END_DATE="&FILEDATE.";       
		TOTAL_AMOUNT=' ';    
		TOTAL_QUANTITY=' ';  
		PROGRAM_NAME='IBENEFIT';
		FILES="PD_IBEN.&FILEDATE..&FILEDATE..&FILETIME..&INITIATIVE_ID."; 
	RUN;

	DATA INITIATIVE_TRIGGER2;
		length FILES            $40;
		FILES="&TRIGGER_NM."; 
	RUN;

/*	DATA INITIATIVE_TRIGGER;*/
/*	 SET INITIATIVE_TRIGGER INITIATIVE_TRIGGER2 ; */
/*	RUN;				*/

	PROC APPEND BASE = TRIGGER 
		    DATA = INITIATIVE_TRIGGER 
		    FORCE;
	RUN;

	PROC APPEND BASE = TRIGGER2 
		    DATA = INITIATIVE_TRIGGER2
		    FORCE;
	RUN;

	PROC SORT DATA = TRIGGER NODUPKEY;
	 BY FILES;
	RUN;

	%IF &INITIATIVE_ID. = &MAX_INITIATIVE_ID_IBNF. %THEN %DO;

	PROC SQL;
	CREATE TABLE TRIGGER1(drop=RECORD_COUNT FILE_NAME FILES) AS
	SELECT A.*, 
    SUM(A.RECORD_COUNT) AS RECORD_COUNT1,
	SUBSTR(FILE_NAME,1,32) AS FILE_NAME1,
	SUBSTR(FILES,1,32) AS FILES1
	FROM TRIGGER A;
	QUIT;

	DATA TRIGGER1(RENAME = (FILE_NAME1 = FILE_NAME FILES1 = FILES));
	FORMAT RECORD_COUNT $20.;
	SET TRIGGER1;
	RECORD_COUNT = LEFT(RECORD_COUNT1);
	DROP RECORD_COUNT1;
	RUN;

	PROC SORT DATA = TRIGGER1 NODUPKEY;
	BY FILES;
	RUN;

	/*--------------------------------------------------------------------------------------------------
	  Create trigger file                                                      
	--------------------------------------------------------------------------------------------------*/
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

		%macro create_pddw_report;

				%*SASDOC--------------------------------------------------------------------------
				| Create load program data in DW report 
				+------------------------------------------------------------------------SASDOC;
				options  TOPMARGIN=.5 BOTTOMMARGIN=.5 RIGHTMARGIN=.5 LEFTMARGIN=.5
					 ORIENTATION =PORTRAIT  PAPERSIZE=LETTER;

				ods listing close;
				ods pdf file="&DALCDCP_LOC./report_ftp_program_data_dw.pdf" NOTOC startpage=no;
				ods proclabel ' ';

				  options nodate;

				  proc print data= PGRMDATA.TRIGGER_&FILEDATE;
				    title1 font=arial color=black  h=12pt j=c  'Hercules Communication Engine';
				    title2 font=arial color=black  h=16pt j=c  'Summary of Data Files Transferred for Program Data in DW';
				    title3 font=arial color=black  h=16pt j=c  'Program Data in DW FTP Summary Report';
				    title4 " ";
				    title5 " ";
				    title6 " ";  
				    title7 " "; 
				    var files ;
				    footnote1 h=8pt j=r  "Hercules Communication Engine" ;
				    footnote2 h=8pt j=r  "&date." ;    
				  run;

				ods pdf close;
				ods listing;

				run;
				quit;

		%mend create_pddw_report;

	/*--------------------------------------------------------------------------------------------------
	  FTP data files to EDW                                           
	--------------------------------------------------------------------------------------------------*/

		%PUT NOTE: BEGIN FTP-ING FILES TO EDW;

		LIBNAME PGRMDATA "&DALCDCP_LOC.";

		DATA PGRMDATA.TRIGGER_&FILEDATE;
		 SET TRIGGER;
		RUN;

		DATA PGRMDATA.TRIGGER2;
		 SET TRIGGER2;
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

		data _null_;
 			x sleep 70;
		run;

		%ftp_data_files(server=&EDW_FTP_HOST., 
				id=&EDW_FTP_USER., 
				pw=&EDW_FTP_PASS., 
				transfermode=ascii, 
				dataset=%str(PGRMDATA.TRIGGER2),
				getrootdir=%str(&DALCDCP_LOC.),
				putrootdir=%str(/incoming/dls/pgrmdata),
				removefiles1=%str(*.BSS), removefiles2=%str(*.BSS));


		X "compress -f &DALCDCP_LOC./PD_IBEN*";
		
		%PUT NOTE: END FTP-ING FILES TO EDW;
		
		%PUT NOTE: BEGIN EMAILED SUMMARY OF FILES FTP-ED TO EDW;
		
		data _null_;
		  date=put(today(),weekdate29.);
		  call symput('date',date);
		run;
		
		%put NOTE:  date = &date. ;
		
		
		%create_pddw_report;

		%*SASDOC--------------------------------------------------------------------------
			| Send email to Hercules Support of the load program data in DW
			+------------------------------------------------------------------------SASDOC;
			filename mymail email 'qcpap020@dalcdcp';

			data _null_;
			    file mymail

				to ='hercules.support@caremark.com'
				subject='HCE SUPPORT:  Program Data in DW FTP Summary Report'
				attach=("&DALCDCP_LOC./report_ftp_program_data_dw.pdf" 
					 ct="application/pdf");;

			    put 'Hello:' ;
			    put / "This is an automatically generated message to inform Hercules Support of the ftp of files for Program Data in DW.";
			    put / "The report will contain a list of new files that became available and were ftp-ed to the EDW. ";
			    put / "Attached is the report that summarizes the ftp information.";
			    put / 'Thanks,';
			    put   'Hercules Support';
			run;
			quit;

		%PUT NOTE: END EMAILED SUMMARY OF FILES FTP-ED TO EDW;

		%END;

		%ELSE %DO;

			filename mymail email 'qcpap020@dalcdcp';

			data _null_;
			    file mymail

				to ='hercules.support@caremark.com'
				subject='HCE SUPPORT:  Program Data in DW Failure Notice'
				;

			    put 'Hello:' ;
			    put / "This is an automatically generated message to inform Hercules Support that a problem was encountered in ftp-ing the files for Program Data in DW. ";
				put / "Please check the log associated with the program.";
				put / 'Thanks,';
			    put   'Hercules Support';
			run;
			quit;

		%END;

	%END;

%MEND CREATE_PROGRAM_DATA_FILES;
