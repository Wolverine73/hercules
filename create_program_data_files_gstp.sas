/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  create_program_data_files_gstp.sas (macro)
|
| LOCATION: /PRG/sastest1/hercules/macros
|
| PURPOSE:  This macro will create the data files and trigger file needed for the 
|           program data in data warehouse for gstp initiatives.  The program 
|           creates both the participant (ppt) as well as the physcian (md2) extract  
|           and trigger files.  The communication role code plays a significant role
|           in the logic when deciding to perform a ppt or md2 process action.
|
|
|
+-------------------------------------------------------------------------------
| HISTORY:  
|
| 01DEC2010 - Sergey Bilesky - Hercules Version  2.5.01
|             Original.  
|
+-----------------------------------------------------------------------HEADER*/ 

%MACRO CREATE_PROGRAM_DATA_FILES_GSTP;

	%LET GSTP_DALCDCP_LOC = /herc&sysmode/data/hercules/&PROGRAM_ID./program_data;
	
	%if &cmctn_role_cd. = 1 %then %do ;  
	  %LET GSTP_FLAG    = PPT;
	  %LET PNT_DATASET=%CMPRES(&table_prefix)_%CMPRES(&cmctn_role_cd);
	%end;
	%else %if &cmctn_role_cd. = 2 %then %do ;  
	  %LET GSTP_FLAG    = MD2; 
	  %LET PHY_DATASET=%CMPRES(&table_prefix)_%CMPRES(&cmctn_role_cd);
	%end;

	/*--------------------------------------------------------------------------------------------------
	  Create a work dataset to get all the variables needed for program data.  
	--------------------------------------------------------------------------------------------------*/

	%if &cmctn_role_cd. = 1 %then %do ;  /** participant data **/

	PROC SQL NOPRINT;
	  CREATE TABLE WORK.&GSTP_FLAG._&INITIATIVE_ID AS
	  SELECT   			 
/*		ADJ_ENGINE							AS SRC_SYS_CD,*/

	  	CASE WHEN ADJ_ENGINE = 'QL' THEN 'Q' 
       		WHEN ADJ_ENGINE = 'RX' THEN 'X'
       		WHEN ADJ_ENGINE = 'RE' THEN 'R' 
       		ELSE ' ' END         			AS SRC_SYS_CD,

		"&INITIATIVE_ID."					AS INITIATIVE_ID,
		CLIENT_LEVEL_1						AS CLNT_LVL1,
		CLIENT_LEVEL_2						AS CLNT_LVL2,
		CLIENT_LEVEL_3						AS CLNT_LVL3,
		CLIENT_NM						AS CLIENT_NAME,
		DRG_CLS_CATG_TX						AS TARGET_DRUG_CATEGORY,
		DRG_CLS_CATG_DESC_TX					AS TARGET_DRUG_CLASS_CATEGORY,
		RECIPIENT_ID 						AS QL_BENEFICIARY_ID,
		MBR_ID							AS MEMBER_ID,
		RVR_FIRST_NM						AS MEMBER_FIRST_NAME,
		RVR_LAST_NM						AS MEMBER_LAST_NAME,
		GENDER							AS MEMBER_GENDER,
		BIRTH_DT						AS MEMBER_DOB FORMAT yymmdd10.,
		ADDRESS1_TX						AS MEMBER_ADDRESS1,
		ADDRESS2_TX						AS MEMBER_ADDRESS2,
		CITY_TX							AS MEMBER_CITY,
		STATE							AS MEMBER_STATE,
		ZIP_CD							AS MEMBER_ZIP,
		TRIM(DRUG_ABBR_PROD_NM)||" "||TRIM(DRUG_ABBR_DSG_NM)
		                   ||" "||TRIM(DRUG_ABBR_STRG_NM)	AS TARGET_DRUG_NAME,
		GPI_THERA_CLS_CD					AS TARGET_GPI_CODE,
		LBL_NAME						AS TARGET_DRUG_LABEL_NAME,
		GPI_THERA_CLS_NM					AS TARGET_GPI_NAME,
		FILL_DT							AS TARGET_DRUG_DISPENSE_DATE FORMAT yymmdd10.,
		DISPENSED_QY						AS DISPENSED_QUANTITY,
		DAY_SUPPLY_QY						AS DAYS_QUANTITY,
		RX_NB							AS RX_NUMBER,
		PROGRAM_TYPE						AS PROGRAM_TYPE,
		PROGRAM_ID						AS PROGRAM_ID,		
		APN_CMCTN_ID 						AS APPLIATION_CMCTN_ID,
        	MBR_GID                           			AS MEMBER_GID,
 		PRCTR_GID						AS PRESCRIBER_GID,
 		ALGN_LVL_GID						AS ALIGN_LEVEL_GID,
 		DRUG_GID						AS DRUG_GID, 
        	QL_CPG_ID                         			AS CPG_ID,
        	"&GSTP_FLAG."						AS GSTP_FLAG

	  FROM DATA_PND.&PNT_DATASET.           
	  WHERE DATA_QUALITY_CD = 1;
	QUIT;	
	 	
	%end;
	%else %if &cmctn_role_cd. = 2 %then %do ;  /** physician data **/
	
	PROC SQL NOPRINT;
	  CREATE TABLE WORK.&GSTP_FLAG._&INITIATIVE_ID AS
	  SELECT   		  
		PRESCRIBER_NPI_NB							   AS NPI,
		"&INITIATIVE_ID."							   AS INITIATIVE_ID,
		left(put(RECIPIENT_ID,20.))						   AS PRESCRIBER_ID,
		PRCBR_FIRST_NM								   AS PRESCRIBER_FIRST_NAME,
		PRCBR_LAST_NAME								   AS PRESCRIBER_LAST_NAME,
		ADDRESS1_TX								   AS PRESCRIBER_ADDRESS_1,
		ADDRESS2_TX								   AS PRESCRIBER_ADDRESS_2,
		CITY_TX									   AS PRESCRIBER_CITY,
		STATE									   AS PRESCRIBER_STATE,
		ZIP_CD									   AS PRESCRIBER_ZIP,
		PRBR_DEGREE								   AS PRESCRIBER_DEGREE,
		PRCBR_SPEC								   AS PRESCRIBER_CATEGORY,
		CLIENT_LEVEL_1								   AS CLNT_LVL1,
		CLIENT_LEVEL_2								   AS CLNT_LVL2,
		CLIENT_LEVEL_3								   AS CLNT_LVL3,
		CLIENT_NM								   AS CLIENT_NAME,
		RECIPIENT_ID								   AS QL_BENEFICIARY_ID,
		MBR_ID									   AS MEMBER_ID,
		SBJ_FIRST_NM							   AS MEMBER_FIRST_NAME,
		SBJ_LAST_NM								   AS MEMBER_LAST_NAME,
		GENDER									   AS MEMBER_GENDER,
		BIRTH_DT 								   AS MEMBER_DOB FORMAT yymmdd10.,
		TRIM(DRUG_ABBR_PROD_NM)||" "||TRIM(DRUG_ABBR_DSG_NM)
						   ||" "||TRIM(DRUG_ABBR_STRG_NM)   	   AS TARGET_DRUG_NAME,
		GPI_THERA_CLS_CD							   AS TARGET_GPI_CODE,
		LBL_NAME								   AS TARGET_DRUG_LABEL_NAME,
		GPI_THERA_CLS_NM							   AS TARGET_DRUG_GPI_NAME,
		FILL_DT									   AS TARGET_DRUG_DISPENSE_DATE FORMAT yymmdd10.,
		DISPENSED_QY								   AS TARGET_DRUG_QUANTITY,
		DAY_SUPPLY_QY								   AS TARGET_DRUG_DAYS_SUPPLY,
		RX_NB									   AS TARGET_DRUG_RX_NUMBER,
		PROGRAM_TYPE								   AS PROGRAM_TYPE,
		DRG_CLS_CATG_TX								   AS TARGET_DRUG_CATEGORY,
		DRG_CLS_CATG_DESC_TX							   AS TARGET_DRUG_CATEGORY_DESCRIPTION,
		PROGRAM_ID								   AS PROGRAM_ID,
		APN_CMCTN_ID								   AS APPLICATION_COMMUNICATION_ID,
		MBR_GID									   AS MEMBER_GID,
		PRCTR_GID								   AS PRESCRIBER_GID,
		ALGN_LVL_GID								   AS ALIGN_LEVEL_GID,
		DRUG_GID								   AS DRUG_GID,
		QL_CPG_ID								   AS CPG_ID,
/*		ADJ_ENGINE								   AS SYSTEM_CODE,*/
		CASE WHEN ADJ_ENGINE = 'QL' THEN 'Q' 
       		WHEN ADJ_ENGINE = 'RX' THEN 'X'
       		WHEN ADJ_ENGINE = 'RE' THEN 'R' 
       		ELSE ' ' END         					AS SYSTEM_CODE,
		"&GSTP_FLAG."							           AS GSTP_FLAG

	  FROM DATA_PND.&PHY_DATASET.      
	  WHERE DATA_QUALITY_CD = 1;
	QUIT;
	
	%end;
	
	/*--------------------------------------------------------------------------------------------------
	  Reformat dates based on program data requirements.                       
	--------------------------------------------------------------------------------------------------*/
	DATA WORK.&GSTP_FLAG._&INITIATIVE_ID  (RENAME=(MEMBER_DOB2= MEMBER_DOB 
	                                               TARGET_DRUG_DISPENSE_DATE2=TARGET_DRUG_DISPENSE_DATE));
	 SET WORK.&GSTP_FLAG._&INITIATIVE_ID ;
	 MEMBER_DOB2=put(MEMBER_DOB,yymmdd10.);
	 Y1=SCAN(MEMBER_DOB2,1,'-');
	 M1=SCAN(MEMBER_DOB2,2,'-');
	 D1=SCAN(MEMBER_DOB2,3,'-');
	 MEMBER_DOB2=TRIM(Y1)||TRIM(D1)||TRIM(M1);
	 if left(compress(MEMBER_DOB2))="." then MEMBER_DOB2="";
	 
	 TARGET_DRUG_DISPENSE_DATE2=put(TARGET_DRUG_DISPENSE_DATE,yymmdd10.);
	 Y1=SCAN(TARGET_DRUG_DISPENSE_DATE2,1,'-');
	 M1=SCAN(TARGET_DRUG_DISPENSE_DATE2,2,'-');
	 D1=SCAN(TARGET_DRUG_DISPENSE_DATE2,3,'-');
	 TARGET_DRUG_DISPENSE_DATE2=TRIM(Y1)||TRIM(D1)||TRIM(M1);
	 if left(compress(TARGET_DRUG_DISPENSE_DATE2))="." then TARGET_DRUG_DISPENSE_DATE2="";
	
	 DROP Y1 D1 M1 MEMBER_DOB TARGET_DRUG_DISPENSE_DATE ;
	RUN;


	/*--------------------------------------------------------------------------------------------------
	  Get the record_count for each initiative which is needed for the trigger file. 
	--------------------------------------------------------------------------------------------------*/
	PROC SQL NOPRINT;
	  SELECT COUNT(*) INTO: GSTP_RECORD_COUNT
	  FROM WORK.&GSTP_FLAG._&INITIATIVE_ID;
	QUIT;


	%IF &INITIATIVE_ID. = &MIN_INITIATIVE_ID_GSTP. AND &CMCTN_ROLE_CD. = 1 %THEN %DO;

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

			%PUT NOTE: GSTP FILEDATETIME1: &FILEDATETIME1.;
			%PUT NOTE: GSTP FILEDATE1: &FILEDATE1.;
			%PUT NOTE: GSTP DATETIME_LENGTH: &DATETIME_LENGTH.;


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
				INTO :FILEDATEGSTP, :FILETIMEGSTP
				FROM TODAY1;
			QUIT;

	%END;
	
	%PUT NOTE: FILEDATEGSTP: &FILEDATEGSTP.;
	%PUT NOTE: FILETIMEGSTP: &FILETIMEGSTP.;
	

	/*--------------------------------------------------------------------------------------------------
	  file name format    - PD_GSTP.yyyymmdd.yyyymmdd.hhmmss.initiativeid
	  trigger name format - PD_GSTP.TRIGGER 
	--------------------------------------------------------------------------------------------------*/	
	%if &cmctn_role_cd. = 1 %then %do ;  
	  %LET FILE_NM    = PPT_GSTP.&FILEDATEGSTP..&FILEDATEGSTP..&FILETIMEGSTP.;
	  %LET TRIGGER_NM = PPT_GSTP.TRIGGER.&FILEDATEGSTP..&FILEDATEGSTP..&FILETIMEGSTP.; 
	%end;
	%else %if &cmctn_role_cd. = 2 %then %do ;  
	  %LET FILE_NM    = MD2_GSTP.&FILEDATEGSTP..&FILEDATEGSTP..&FILETIMEGSTP.; 
	  %LET TRIGGER_NM = MD2_GSTP.TRIGGER.&FILEDATEGSTP..&FILEDATEGSTP..&FILETIMEGSTP.; 
	%end;

	%PUT NOTE: GSTP FILE_NM    = &FILE_NM;
	%PUT NOTE: GSTP TRIGGER_NM = &TRIGGER_NM;

	DATA INITIATIVE_GSTP_TRIGGER;
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
		FILES            $50
		GSTP_FLAG        $3;

		SOURCE_NAME='HERCULES';   
		FILLER=' ';         
		CREATION_DT_TIME="&FILEDATEGSTP.&FILETIMEGSTP.";
		FILE_NAME="&FILE_NM.";      
		EXTRACT_TYPE='F';  
		%if &cmctn_role_cd. = 1 %then %do ;  
		  RECORD_LENGTH='896'; 
		%end;
		%else %if &cmctn_role_cd. = 2 %then %do ;  
		  RECORD_LENGTH='887'; 
		%end; 
		RECORD_COUNT="&GSTP_RECORD_COUNT."; 
		START_DATE="&FILEDATEGSTP.";     
		END_DATE="&FILEDATEGSTP.";       
		TOTAL_AMOUNT=' ';    
		TOTAL_QUANTITY=' ';  
		PROGRAM_NAME='GSTP';
		FILES="&FILE_NM."; 
		GSTP_FLAG="&GSTP_FLAG.";
	RUN;

	DATA INITIATIVE_GSTP_TRIGGER2;
		length FILES            $50;
		FILES="&TRIGGER_NM."; 
	RUN;

	DATA INITIATIVE_GSTP_TRIGGER;
	 SET INITIATIVE_GSTP_TRIGGER INITIATIVE_GSTP_TRIGGER2 ; 
	RUN;				

	PROC APPEND BASE = TRIGGER_GSTP
		    DATA = INITIATIVE_GSTP_TRIGGER 
		    FORCE;
	RUN;

	PROC SORT DATA = TRIGGER_GSTP ;
	 BY FILES;
	RUN;

	%IF &INITIATIVE_ID. = &MAX_INITIATIVE_ID_GSTP. /**AND &CMCTN_ROLE_CD. = 2**/ %THEN %DO;

	/*--------------------------------------------------------------------------------------------------
	  Create initiative  data file                                            
	--------------------------------------------------------------------------------------------------*/
	
	%if &cmctn_role_cd. = 1 %then %do ;  /** participant data **/

		%LET TOTALMEMNAME=0;

		DATA _NULL_;
	 		SET SASHELP.VTABLE END=EOF; 
	 		CALL SYMPUT('MEMNAME' || TRIM(LEFT(_N_)), TRIM(LEFT(MEMNAME)));
	 		IF EOF THEN CALL SYMPUT('TOTALMEMNAME', TRIM(LEFT(_N_)));
	 		WHERE LIBNAME IN ('WORK') AND SUBSTR(MEMNAME,1,3) ="&GSTP_FLAG.";
		RUN;

		DATA &GSTP_FLAG._ALL;
		 SET %DO GG = 1 %TO &TOTALMEMNAME. ;
		       &&MEMNAME&GG
			 %END;;
		RUN;
	
		DATA _NULL_;
		  SET &GSTP_FLAG._ALL ;
		  FILE "&GSTP_DALCDCP_LOC./&FILE_NM." delimiter="|" DSD RECFM = V lrecl=1000;   
		  PUT  
			SRC_SYS_CD
			INITIATIVE_ID	
			CLNT_LVL1
			CLNT_LVL2
			CLNT_LVL3
			CLIENT_NAME		
			TARGET_DRUG_CATEGORY	
			TARGET_DRUG_CLASS_CATEGORY 
			QL_BENEFICIARY_ID		
			MEMBER_ID			
			MEMBER_FIRST_NAME			
			MEMBER_LAST_NAME		
			MEMBER_GENDER		
			MEMBER_DOB 	
			MEMBER_ADDRESS1		
			MEMBER_ADDRESS2		
			MEMBER_CITY		
			MEMBER_STATE		
			MEMBER_ZIP			
			TARGET_DRUG_NAME		
			TARGET_GPI_CODE		
			TARGET_DRUG_LABEL_NAME	
			TARGET_GPI_NAME		
			TARGET_DRUG_DISPENSE_DATE  
			DISPENSED_QUANTITY		
			DAYS_QUANTITY	
			RX_NUMBER					
			PROGRAM_TYPE	
			PROGRAM_ID				
			APPLIATION_CMCTN_ID	
			MEMBER_GID		
			PRESCRIBER_GID	
			ALIGN_LEVEL_GID	
			DRUG_GID			
			CPG_ID			;
		RUN; 
	
	%end;
	%else %if &cmctn_role_cd. = 2 %then %do ;  /** physician data **/

		%LET TOTALMEMNAME=0;

		DATA _NULL_;
	 		SET SASHELP.VTABLE END=EOF; 
	 		CALL SYMPUT('MEMNAME' || TRIM(LEFT(_N_)), TRIM(LEFT(MEMNAME)));
	 		IF EOF THEN CALL SYMPUT('TOTALMEMNAME', TRIM(LEFT(_N_)));
	 		WHERE LIBNAME IN ('WORK') AND SUBSTR(MEMNAME,1,3) ="&GSTP_FLAG.";
		RUN;

		DATA &GSTP_FLAG._ALL;
		 SET %DO GG = 1 %TO &TOTALMEMNAME. ;
		       &&MEMNAME&GG
			 %END;;
		RUN;
	
		DATA _NULL_;
		  SET &GSTP_FLAG._ALL ; 
		  FILE "&GSTP_DALCDCP_LOC./&FILE_NM." DSD delimiter="|" RECFM = V lrecl=1000; 
		  PUT  
			NPI				
			INITIATIVE_ID			
			PRESCRIBER_ID			
			PRESCRIBER_FIRST_NAME		
			PRESCRIBER_LAST_NAME		
			PRESCRIBER_ADDRESS_1		
			PRESCRIBER_ADDRESS_2		
			PRESCRIBER_CITY			
			PRESCRIBER_STATE		
			PRESCRIBER_ZIP			
			PRESCRIBER_DEGREE		
			PRESCRIBER_CATEGORY		
			CLNT_LVL1			
			CLNT_LVL2			
			CLNT_LVL3			
			CLIENT_NAME			
			QL_BENEFICIARY_ID		
			MEMBER_ID			
			MEMBER_FIRST_NAME		
			MEMBER_LAST_NAME		
			MEMBER_GENDER			
			MEMBER_DOB			
			TARGET_DRUG_NAME		
			TARGET_GPI_CODE			
			TARGET_DRUG_LABEL_NAME		
			TARGET_DRUG_GPI_NAME		
			TARGET_DRUG_DISPENSE_DATE  	
			TARGET_DRUG_QUANTITY		
			TARGET_DRUG_DAYS_SUPPLY		
			TARGET_DRUG_RX_NUMBER		
			PROGRAM_TYPE			
			TARGET_DRUG_CATEGORY		
			TARGET_DRUG_CATEGORY_DESCRIPTION	
			PROGRAM_ID				
			APPLICATION_COMMUNICATION_ID	
			MEMBER_GID				
			PRESCRIBER_GID			
			ALIGN_LEVEL_GID			
			DRUG_GID				
			CPG_ID				
			SYSTEM_CODE			;
		RUN; 	
	
	%end;

	PROC SQL;
	CREATE TABLE TRIGGER_GSTP2(drop=RECORD_COUNT FILE_NAME FILES) AS
	SELECT A.*, 
    SUM(A.RECORD_COUNT) AS RECORD_COUNT1,
	FILE_NAME AS FILE_NAME1,
	FILES AS FILES1
	FROM TRIGGER_GSTP A
	WHERE GSTP_FLAG="&GSTP_FLAG.";
	QUIT;

	DATA TRIGGER_GSTP2(RENAME = (FILE_NAME1 = FILE_NAME FILES1 = FILES));
	FORMAT RECORD_COUNT $20.;
	SET TRIGGER_GSTP2;
	RECORD_COUNT = LEFT(RECORD_COUNT1);
	DROP RECORD_COUNT1;
	RUN;

	PROC SORT DATA = TRIGGER_GSTP2 NODUPKEY;
	BY FILES;
	RUN;

	/*--------------------------------------------------------------------------------------------------
	  Create trigger file                                                      
	--------------------------------------------------------------------------------------------------*/
	DATA _NULL_;
	  SET TRIGGER_GSTP2;
	  FILE "&GSTP_DALCDCP_LOC./&TRIGGER_NM." DSD RECFM = V lrecl=180; 
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
	
	%END;
	%IF &INITIATIVE_ID. = &MAX_INITIATIVE_ID_GSTP. AND &CMCTN_ROLE_CD. = 2 %THEN %DO;
	

	/*--------------------------------------------------------------------------------------------------
	  FTP data files to EDW                                           
	--------------------------------------------------------------------------------------------------*/
	
		%PUT NOTE: BEGIN FTP-ING FILES TO EDW;

		LIBNAME PGRMDATA "&GSTP_DALCDCP_LOC.";

		DATA PGRMDATA.TRIGGER_&FILEDATEGSTP.;
		 SET TRIGGER_GSTP;
		RUN;

		PROC SORT DATA = PGRMDATA.TRIGGER_&FILEDATEGSTP. NODUPKEY;
		BY FILES;
		RUN;

		%IF %SYSFUNC(EXIST(PGRMDATA.TRIGGER_&FILEDATEGSTP.)) %THEN %DO;

		%ftp_data_files(server=&EDW_FTP_HOST., 
				id=&EDW_FTP_USER., 
				pw=&EDW_FTP_PASS., 
				transfermode=ascii, 
				dataset=%str(PGRMDATA.TRIGGER_&FILEDATEGSTP),
				getrootdir=%str(&GSTP_DALCDCP_LOC.),
				putrootdir=%str(/incoming/dls/pgrmdata),
				removefiles1=%str(*.BSS), removefiles2=%str(*.BSS));

		X "compress -f &GSTP_DALCDCP_LOC./PPT_GSTP*";
		X "compress -f &GSTP_DALCDCP_LOC./MD2_GSTP*";
		
		%PUT NOTE: END FTP-ING FILES TO EDW;
		
		%PUT NOTE: BEGIN EMAILED SUMMARY OF FILES FTP-ED TO EDW;
		
		data _null_;
		  date=put(today(),weekdate29.);
		  call symput('date',date);
		run;
		
		%put NOTE:  date = &date. ;
		
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
				ods pdf file="&GSTP_DALCDCP_LOC./report_ftp_program_data_dw.pdf" NOTOC startpage=no;
				ods proclabel ' ';

				  options nodate;

				  proc print data= PGRMDATA.TRIGGER_&FILEDATEGSTP;
				    title1 font=arial color=black  h=12pt j=c  'Hercules Communication Engine';
				    title2 font=arial color=black  h=16pt j=c  'Summary of Files Transferred for Program Data in DW';
				    title3 font=arial color=black  h=16pt j=c  'GSTP Program Data in DW FTP Summary Report';
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
		%create_pddw_report;
		 

		%*SASDOC--------------------------------------------------------------------------
			| Send email to Hercules Support of the load program data in DW
			+------------------------------------------------------------------------SASDOC;
			filename mymail email 'qcpap020@dalcdcp';

			data _null_;
			    file mymail

				to =(&pddw_programmer_email)
				subject='HCE SUPPORT:  GSTP Program Data in DW FTP Summary Report'
				attach=("&GSTP_DALCDCP_LOC./report_ftp_program_data_dw.pdf" 
					 ct="application/pdf");;

			    put 'Hello:' ;
			    put / "This is an automatically generated message to inform Hercules Support of the ftp of GSTP files for Program Data in DW.";
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

				to =(&Primary_programmer_email)
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

%MEND CREATE_PROGRAM_DATA_FILES_GSTP;
