/*SASDOC------------------------------------------------------------------------
			MACRO: update_privacy_address

			PURPOSE:			To update a member's address information to the privacy address
								if available - address line 1, address line 2, state code, zip code. Also adds the privacy indicator
								column to distinguish between a privacy address and a regular address. All
								manipulations will be done to the pending dataset, just before the data quality
								check in order to validate the privacy address, for RX claim initiatives.

			LOGIC:              The macro uses the member information such as the member_id/member_gid and/or ql_bnfcy_id
								to query the dss_clin.v_mbr_mbr_acct_addr_prvt view on Oracle(EDW) to create a dataset of members and their privacy
								address information along with the indicators. This look up data set is then used to update 
								the new privacy address information and the relevant indicators on the pending dataset. There are two
								steps here - 1) Update the existing address columns. 2) Add a new column(s) with the privacy indicator.

			PARAMETERS:         The input to the macro is the pending SAS dataset that is in process of creation by the create_base_file SAS macro,
								which this macro. At this stage, the full pending dataset with the entire column layout would have been created. The 
								new column will be added to the end of the file.
								
			FIRST RELEASE: 		Arjun Kolakotla, November 2013
			
			HISTORY:			2/27/2014	- AK - Added fix for warnings that set the error flag to 1 wrongly.
+-----------------------------------------------------------------------SASDOC*/
%MACRO UPDATE_PRIVACY_ADDRESS(INPUT_TABLE=, ADJUDICATION=);
  

 %LOCAL ADJUDICATION 
	    INPUT_TABLE
	    MBR_&INPUT_TABLE._OBS
		PRIV_COUNT DUP_PRIV_COUNT
		SRC_SYS_CODE
		MBR_GID_COL
		MBR_ID_COL;


 %IF (&PROGRAM_ID NE 5368 OR &PROGRAM_ID NE 5371) AND &CMCTN_ROLE_CD = 1 AND &FILE_SEQ_NB = 1 %THEN %DO;	
 /* START - PROGRAM_ID SELECTION CONDITION*/

DATA &INPUT_TABLE.;
	SET &INPUT_TABLE.;
	PRVCY_ADDR_USE_IND = 0;		/*DEFAULT = 0*/
RUN;


PROC CONTENTS DATA = WORK.&INPUT_TABLE. OUT = CONTENTS_&INPUT_TABLE.; RUN;

PROC SQL;

SELECT ","||TRIM(LEFT(NAME)) INTO: MBR_ID_COL
FROM CONTENTS_&INPUT_TABLE. WHERE upcase(NAME) = 'MBR_ID';

SELECT COUNT(*) INTO: MBR_ID_COL1
FROM CONTENTS_&INPUT_TABLE. WHERE upcase(NAME) = 'MBR_ID';
QUIT;
                  
%IF &PROGRAM_ID = 5259 AND &TASK_ID = 59 %THEN %DO;
			%LET MBR_ID_COL = MEMBER_ID;
%END;

%ELSE %DO; %LET MBR_ID_COL = MBR_ID; %END;
   

	%IF &MBR_ID_COL1 = 0 AND NOT (&PROGRAM_ID = 5259 AND &TASK_ID = 59)	OR &FILE_SEQ_NB > 1 %THEN %DO;
		%GOTO EXIT_UPD_PRVCY_MACRO; 
		%PUT NOTE:		THERE IS NO MBR_ID COLUMN AVAILABLE IN THE INPUT PENDING DATASET, AND HENCE NO UPDATES
						TO THE PENDING DATASET ARE MADE OR IF FILE_SEQ_NB > 1, THEN EXIT.
						UPDATE_PRIVACY_ADDRESS MACRO IS EXITING...;
	%END;



	%DROP_ORACLE_TABLE (TBL_NAME=&ORA_TMP..MBRS_&INPUT_TABLE.);
	/*	Create a table with just the member and client information to be used to query the Oracle table	*/
			PROC SQL NOPRINT;
				CREATE TABLE &ORA_TMP..MBRS_&INPUT_TABLE. AS
					SELECT DISTINCT 
					 CLIENT_LEVEL_1
					,CLIENT_LEVEL_2
					,CLIENT_LEVEL_3
					,&MBR_ID_COL
					&MBR_GID_COL.
					,RECIPIENT_ID
					FROM WORK.&INPUT_TABLE.
				WHERE ADJ_ENGINE= "&ADJUDICATION.";
			QUIT;

			%LET MBR_&INPUT_TABLE._OBS = &SQLOBS;
			%PUT MBR_&INPUT_TABLE._OBS = &&MBR_&INPUT_TABLE._OBS;

		%IF &&MBR_&INPUT_TABLE._OBS > 0 %THEN %DO;
			%PUT NOTE:	THERE ARE &ADJUDICATION MEMBERS IN THE FILE, AND AN ATTEMPT TO CHECK FOR PRIVACY ADDRESS WILL BE MADE.;


	/*ADJUDICATION to SRC_SYS_CD CONVERSION*/
			%IF &ADJUDICATION = QL %THEN %DO;	%LET SRC_SYS_CODE = %str('Q');	%END;
			%IF &ADJUDICATION = RX %THEN %DO;	%LET SRC_SYS_CODE = %str('X');	%END;
			%IF &ADJUDICATION = RE %THEN %DO;	%LET SRC_SYS_CODE = %str('R');	%END;

			PROC SQL NOPRINT;
			CONNECT TO ORACLE(PATH=&GOLD PRESERVE_COMMENTS=YES);	/*AK ADDED HINT FOR PERFORMANCE-FEB2014*/
			CREATE TABLE WORK.MBRS_&INPUT_TABLE._ADDRESS AS
			SELECT * FROM CONNECTION TO ORACLE(
			SELECT    DISTINCT A.*
					 ,'1' AS PRVCY_ADDR_USE_IND 
					 ,C.PRVT_ADDR_LINE1 AS ADDRESS1
					 ,C.PRVT_ADDR_LINE2 AS ADDRESS2
					 ,C.PRVT_ADDR_LINE3 AS ADDRESS3
					 ,C.PRVT_ADDR_CITY_NM AS CITY
					 ,C.PRVT_ADDR_ST_ABBR_CD AS STATE
					 ,C.PRVT_ADDR_ZIP5_CD AS ZIP1
					 ,C.EFF_DT AS PRIVACY_EFFECTIVE_DATE
					 ,C.EXPRN_DT AS PRIVACY_THROUGH_DATE
					 ,C.MBR_GID AS PRIV_MBR_GID
					 ,C.PRVT_SEQ_NBR AS PRVT_SEQ_NBR
					 ,C.MBR_ACCT_ADDR_PRVT_HIST_GID

			FROM 	&ORA_TMP..MBRS_&INPUT_TABLE. A,
					&DSS_CLIN..V_MBR_ELIG_ACTIVE B,
/*					DSS_HERC.V_MBR_ACCT_ADDR_PRVT C*/
					&DSS_CLIN..V_MBR_ACCT_ADDR_PRVT C

			WHERE 	B.SRC_SYS_CD = &SRC_SYS_CODE.
				AND	A.&MBR_ID_COL = B.MBR_ID	
				AND B.MBR_GID = C.MBR_GID
				AND TRIM(C.PRVT_TYP_CD) = 'C' 
				AND TRIM(C.STUS_CD) = 'A' 
				AND C.CURR_IND = 'Y'
				AND C.EFF_DT <= SYSDATE
				AND C.EXPRN_DT  > SYSDATE
				);
			DISCONNECT FROM ORACLE;

SELECT COUNT(*) INTO:PRIV_COUNT FROM WORK.MBRS_&INPUT_TABLE._ADDRESS

			;QUIT;


%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..MBRS_&INPUT_TABLE.);

		

		%IF &PRIV_COUNT = 0 %THEN %DO;

				%PUT NOTE:	THERE ARE NO MEMBERS THAT HAVE PRIVACY ADDRESSES, SO NO PRIVACY ADDRESS UPDATES 
						TO THE PENDING DATASET ARE MADE.
						UPDATE_PRIVACY_ADDRESS MACRO IS EXITING...;

				%GOTO EXIT_UPD_PRVCY_MACRO; 

		%END;

/*	SELECT 1 PRIVACY ADDRESS RECORD PER MEMBER BY TAKING THE ROW WITH THE HIGHEST PRVT_SEQ_NBR FOR THE MEMBER.
	ELIGIBILITY IS NOT BEING CHECKED SINCE THE DATASET IS PAST THE ELIGIBILITY_CHECK SAS MACRO. THE LATEST
	RECORD IN THE PRIVACY TABLE WOULD BE ASSOCIATED WITH THE LATEST PRIVACY ADDRESS.
*/

	

/*		PROC SORT DATA = WORK.MBRS_&INPUT_TABLE._ADDRESS NODUP;*/
/*		BY &MBR_ID_COL PRIV_MBR_GID DESCENDING PRVT_SEQ_NBR ;*/
/*		RUN;*/

/*		DATA WORK.MBRS_&INPUT_TABLE._ADDRESS MBRS_&INPUT_TABLE._ADDRESS_DUPES;*/
/*		SET WORK.MBRS_&INPUT_TABLE._ADDRESS;*/
/*		BY &MBR_ID_COL PRIV_MBR_GID PRVT_SEQ_NBR;*/
/*		IF LAST.PRVT_SEQ_NBR THEN OUTPUT WORK.MBRS_&INPUT_TABLE._ADDRESS ;*/
/*		ELSE OUTPUT MBRS_&INPUT_TABLE._ADDRESS_DUPES;*/
/*		RUN;*/


		PROC SORT DATA = WORK.MBRS_&INPUT_TABLE._ADDRESS NODUP;
		BY &MBR_ID_COL MBR_ACCT_ADDR_PRVT_HIST_GID;
		RUN;

		DATA WORK.MBRS_&INPUT_TABLE._ADDRESS MBRS_&INPUT_TABLE._ADDRESS_DUPES;
		SET WORK.MBRS_&INPUT_TABLE._ADDRESS;
		BY &MBR_ID_COL;
		IF LAST.&MBR_ID_COL. THEN OUTPUT WORK.MBRS_&INPUT_TABLE._ADDRESS ;
		ELSE OUTPUT MBRS_&INPUT_TABLE._ADDRESS_DUPES;
		RUN;


%macro report_dupes;

		/*	REPORTING THE DUPLICATES - AT THIS TIME THE REPORTING IS NOT BEING DONE, SINCE THERE ARE IS NO TEST DATA.
			THIS REPORTING ROUTINE NEEDS TO BE PASSED THROUGH UNIT AND QA TESTS - WILL NOT BE EXECUTING THIS MACRO AS PART
			OF FIRST HMSA PROJECT	-	NOV2013*/


		/*	Report the duplicates, if any	*/
		
		PROC SQL NOPRINT;
		SELECT COUNT(*) INTO:DUP_PRIV_COUNT FROM MBRS_&INPUT_TABLE._ADDRESS_DUPES;
		QUIT;
		%PUT &DUP_PRIV_COUNT;



/*		options mprint;*/
		%IF &DUP_PRIV_COUNT > 0 %THEN %DO;

		DATA MBRS_&INPUT_TABLE._ADDRESS_DUPES;
		SET MBRS_&INPUT_TABLE._ADDRESS_DUPES;
		FORMAT PRIV_EFF_DT DATE9. PRIV_THROUGH_DT DATE9.;
		PRIV_EFF_DT = DATEPART(PRIVACY_EFFECTIVE_DATE);
		PRIV_THROUGH_DT = DATEPART(PRIVACY_THROUGH_DATE);
		RUN;



		%let _hdr_fg =blue;
		%let _hdr_bg =lightgrey;
		%let _tbl_fnt="Arial";
		options orientation=landscape papersize=legal nodate nonumber missing='0' ;
		options leftmargin  ="0.50in"
		        rightmargin ="0.00in"
		        topmargin   ="0.75in"
		        bottommargin="0.25in";

		ods listing close;
		ods pdf file = "/herc&sysmode/data/hercules/reports/MBRS_&INPUT_TABLE._ADDR_DUP.pdf" notoc;
		ods escapechar "^";
		title1 j=c "^S={font_face=arial
		                font_size=12pt
		                font_weight=bold}PRIVACY ADDRESS DUPLICATES' REPORT^S={}";
		title2 j=c "^S={font_face=arial
		                font_size=14pt
		                font_weight=bold}Initiative ID &initiative_id. &INPUT_TABLE^S={}";
		title3 j=c "^S={font_face=arial
		                font_size=12pt
		                font_weight=bold}%sysfunc(date(),worddate19.)^S={}";
		footnote1 j=r "^S={font_face=arial
		                font_size=7pt
		                font_weight=bold}Caremark IT Analytics^S={}";
		run;


		PROC PRINT DATA=MBRS_&INPUT_TABLE._ADDRESS_DUPES noobs;
		var RECIPIENT_ID MBR_ID PRIV_EFF_DT PRIV_THROUGH_DT;
		RUN;


		ods pdf close;
		ods listing ;


		%email_parms( EM_TO="arjun.kolakotla@caremark.com"					/*Change this to Hercules Support*/
		/*      ,EM_CC="levim.quiambao@caremark.com"*/
		      ,EM_SUBJECT="HCE SUPPORT: SECUREMAIL - Duplicate Privacy Address Report Attached"
		      ,EM_MSG="Duplicate Privacy Address Report Attached - Please check for the addresses 
					   in the /herc&sysmode/data/hercules/&program_id/results directory.
					   The SAS dataset name is PRIVACY_DATA_LOGGING_&PROGRAM_ID."
		  ,EM_ATTACH="/herc&sysmode/data/hercules/reports/MBRS_&INPUT_TABLE._ADDR_DUP.pdf"  ct="application/pdf");




		/*	Logging	- append records to a logging SAS dataset	*/
			%IF %SYSFUNC(DATA_RES.PRIVACY_DATA_LOGGING_&PROGRAM_ID.) = 0 %THEN %DO;
				PROC SQL;
				CREATE TABLE DATA_RES.PRIVACY_DATA_LOGGING_&PROGRAM_ID. AS
				SELECT RECIPIENT_ID MBR_ID ADDRESS1 ADDRESS2 CITY STATE ZIP1 PRIV_EFF_DT PRIV_THROUGH_DT
				FROM MBRS_&INPUT_TABLE._ADDRESS_DUPES;
				QUIT;
			%END;

			%ELSE %IF %SYSFUNC(DATA_RES.PRIVACY_DATA_LOGGING_&PROGRAM_ID.) %THEN %DO;
				PROC SQL;
				INSERT INTO DATA_RES.PRIVACY_DATA_LOGGING_&PROGRAM_ID.
				SELECT RECIPIENT_ID MBR_ID ADDRESS1 ADDRESS2 CITY STATE ZIP1 PRIV_EFF_DT PRIV_THROUGH_DT
				FROM MBRS_&INPUT_TABLE._ADDRESS_DUPES;
				QUIT;
			%END;



		/*	End logging	*/
		%END;

		/*	End Report	*/

%mend report_dupes;
/*	END REPORT DUPES	*/

	
/*	UPDATE STEP	*/

		PROC SQL NOPRINT; 
		UPDATE &INPUT_TABLE. A
		SET PRVCY_ADDR_USE_IND = 1,
			ADDRESS1_TX = (SELECT ADDRESS1 FROM WORK.MBRS_&INPUT_TABLE._ADDRESS B WHERE COMPRESS(A.&MBR_ID_COL,'-') = COMPRESS(B.&MBR_ID_COL,'-')),
			ADDRESS2_TX = (SELECT ADDRESS2 FROM WORK.MBRS_&INPUT_TABLE._ADDRESS C WHERE COMPRESS(A.&MBR_ID_COL,'-') = COMPRESS(C.&MBR_ID_COL,'-')),
			ADDRESS3_TX = ' ',
			CITY_TX  	= (SELECT CITY FROM WORK.MBRS_&INPUT_TABLE._ADDRESS D WHERE COMPRESS(A.&MBR_ID_COL,'-') = COMPRESS(D.&MBR_ID_COL,'-')),
			STATE 	    = (SELECT STATE FROM WORK.MBRS_&INPUT_TABLE._ADDRESS E WHERE COMPRESS(A.&MBR_ID_COL,'-') = COMPRESS(E.&MBR_ID_COL,'-')), 
			ZIP_CD    	= (SELECT ZIP1 FROM WORK.MBRS_&INPUT_TABLE._ADDRESS F WHERE COMPRESS(A.&MBR_ID_COL,'-') = COMPRESS(F.&MBR_ID_COL,'-'))
		WHERE A.&MBR_ID_COL. 	IN	 (SELECT DISTINCT &MBR_ID_COL. FROM WORK.MBRS_&INPUT_TABLE._ADDRESS)
		;QUIT;


	%SET_ERROR_FL;

%IF &SYSERR <= 4 %THEN %LET ERR_FL = 0;	/*	SYSERR = 0(NO ERROR). SYSERR = 4 (WARNING) - ERR_FL IS RESET TO 0 FOR WARNINGS TO CONTINUE THE PROGRAM - AK - 2/27/2014	*/

	%IF  &ERR_FL = 1 %THEN %DO;
/*	%email_parms( EM_TO="hercules.support@caremark.com"					*/
/*		      ,EM_SUBJECT="HCE SUPPORT: SECUREMAIL - Duplicate Privacy Address Prcess Failed"*/
/*		      ,EM_MSG="There was an error updating the privacy addresses. Please check the log for the error. */
/*					   The PRVCY_ADDR_USE_IND may not have been updated.");*/
	%END;

		%END;



		%ELSE %IF &&MBR_&INPUT_TABLE._OBS = 0 %THEN %DO; 
			%PUT NOTE:	THERE ARE NO &ADJUDICATION MEMBERS IN THE FILE, SO NO PRIVACY ADDRESS UPDATES TO THE PENDING DATASET ARE MADE.
								UPDATE_PRIVACY_ADDRESS MACRO IS EXITING...;
				%GOTO EXIT_UPD_PRVCY_MACRO; 
		%END;
	




 %END;														/* END - PROGRAM_ID SELECTION CONDITION*/


%EXIT_UPD_PRVCY_MACRO: %MEND UPDATE_PRIVACY_ADDRESS;


/*OPTIONS MPRINT MLOGIC SYMBOLGEN MPRINTNEST MLOGICNEST;*/
/*%set_sysmode(mode=dev2);*/
/*options sysparm='INITIATIVE_ID=9019 PHASE_SEQ_NB=1';*/
/*%include "/herc&sysmode./prg/hercules/hercules_in_oak.sas" /nosource nosource2; */

/*%UPDATE_PRIVACY_ADDRESS(INPUT_TABLE=&TBL_NAME_OUT_SH., ADJUDICATION=RX);*/
