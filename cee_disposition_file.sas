/**HEADER -------------------------------------------------------------------------------------------------
  | NAME:     cee_disposition_file.sas
  |		:	  MACRO CALL NAME cee_dispositions.sas
  | PURPOSE:  CREATE PRINT DISPOSITION FILE TO BE SENT BACK TO CEE .
  |          
  |
  | LOGIC :THIS MACRO USES PENDING SAS DATASET TO CREATE DISPOSITION FILES. THIS DISPOSITION FILE
  |        IS BEING SECURE FTPed TO DESIRED LOCATION. 
  |
  | INPUT : PENDING SAS DATASET          
  |
  |OUTPUT : DISPOSITION FILE AND CONTROL FILE       
  |---------------------------------------------------------------------------------------------------------
  | HISTORY: 
  |         09AUG2010 - D. PALMER  -  modified this program for EOMS Rel 5.0 changes:
  |                 (1) Added new field - SOURCE to the Disposition file and hardcoded the 
  |                     value for the SOURCE field. Note: In a future release the SOURCE field 
  |                     must be populated with the value of the SOURCE field in the Opportunity file.
  |                     Also changed Delivery_Date_Time field length from 20 to 19.
  |                 (2) Added creation of a Control file for each Disposition file
  |                     to contain the Disposition file name and number of records
  |                     in the Disposition file. Also added another step to FTP the  
  |                     Control file to the EOMS server. 
  |                 (3) Changed Disposition file name prefix from cee to eoms and replaced
  |                     initiative id suffix with a time variable in hhmmss format. 
  |                 (4) Corrected logic bug in Data step used to extract time part for macro var &DATE1.
  |                 (5) Added DATA step to create a macro variable to hold the current
  |                     time to be used in the name of the control file and disposition file.
  |					(6) AK - rewrote the entire program. Used lesser macros.
  |                  
  +-------------------------------------------------------------------------------------------------HEADER*/



/*		FOR ADHOC RUN, UNCOMMENT OUT THE FOLLOWING THREE STEPS		*/
/*%set_sysmode(mode=dev2);*/
/*options sysparm='INITIATIVE_ID=12373 PHASE_SEQ_NB=1';*/
/*%include "/herc&sysmode/prg/hercules/hercules_in.sas";*/

LIBNAME SAVING "/herc&sysmode/data/hercules/gen_utilities/sas/cee_temp_dataset" ;
%MACRO cee_disposition_file ;



%*SASDOC -----------------------------------------------------------------------
 | GET THE COMMUNICATION ROLE CODE FROM THE RECEIVER FILE TABLE
 +----------------------------------------------------------------------SASDOC*;

DATA _NULL_;
 		SET &HERCULES..TPHASE_RVR_FILE(WHERE=(INITIATIVE_ID=&INITIATIVE_ID));
 		CALL SYMPUT('CMCTN_ROLE_CD' , TRIM(LEFT(CMCTN_ROLE_CD)));
RUN;


%PUT NOTE:VALUE OF CMCTN ROLE CODE IS &CMCTN_ROLE_CD ;
%PUT NOTE:DATASET IS  T_&INITIATIVE_ID._&PHASE_SEQ_NB._&CMCTN_ROLE_CD;



%*SASDOC -----------------------------------------------------------------------
 | THESE VALUES CAN BE CHANGED IN FUTURE.
 | THESE VARIABLES ARE USED IN THE DATA STEP ALIGNED_&initiative_id.
 | LATER IN THE PROGRAM - AK 21FEB2012
 +----------------------------------------------------------------------SASDOC*;
%LET CEE_OPT_OUT =0 ;
%LET CEE_CHANNEL_CODE=1 ;
%LET CEE_OPP_STATUS_RSN_CD = 2;
%LET OPP_SATUS_RSN_CD_VALID=1;
%LET OPP_SATUS_RSN_CD_INVALID=21;



%*SASDOC -----------------------------------------------------------------------
 | FETCHING THE DATE VALUE FROM TINITIATIVE TABLE	
 | 01Aug2011 G. DUDLEY - Corrected logic to extract release TS
 |                       instead of the HSC TS for B2G and 
 |                       Pharmacy Advisor
 +----------------------------------------------------------------------SASDOC*;

/*DATA _NULL_;*/
/* 	SET &HERCULES..TPHASE_RVR_FILE(WHERE=(INITIATIVE_ID=&INITIATIVE_ID));*/
/* 	CALL SYMPUT('DATE1' ,TRIM(LEFT(RELEASE_TS)));						*/
/* RUN;  */
/* */
/**/
/**/
/*DATA _null_;*/
/*      tPart=put(timepart("&DATE1"),time8.); */
/*      dPart=put(datepart("&DATE1"),MMDDYY10.);*/
/*      dtPart=translate(dPart,'.','/'); */
/*    uDate = strip(dtPart)!!':'!!strip(tPart);*/
/*    call symput('date1',uDate);*/
/*run;*/
/*%PUT NOTE:DATE IS  &date1;*/




/*	AK ADDED CODE - 03/16/2012	- FORMAT THE DATETIME VARIABLE	*/

DATA _null_;
 	SET &HERCULES..TPHASE_RVR_FILE(WHERE=(INITIATIVE_ID=&INITIATIVE_ID));
	 keep release_ts tpart dtpart ;
	
	  tPart = compress(TRANSLATE(SUBSTR(left(put(release_ts, datetime25.)),11,8),'',':'));
	  dtPart = compress(translate(put(datepart(release_ts),YYMMDD10.),'','-'));

	udate = strip(dtPart)!!strip(tPart);
    call symput('date1',uDate);
RUN;  

%PUT NOTE:DATE IS  &date1;




%*SASDOC -----------------------------------------------------------------------
 | REMOVED THE TEMPORARY MACRO VARIABLES STEP. WILL EXTRACT DIRECTLY FROM 
 | THE PENDING DATASET - AK 21FEB2012
 +----------------------------------------------------------------------SASDOC*;



	%*SASDOC -----------------------------------------------------------------------
	 | REMOVED THE PROC SQL STEP THAT DEFINES THE STRUCTURE OF THE PRINT DISPOSITION FILE.
	 | WILL DO THE FORMATTING IN THE DATA STEP THAT FOLLOWS	- AK 21FEB2012
	 |
	 | PREVIOUSLY - 09Aug2010 - D.Palmer changed length of Delivery_Date_Time from 20 to 19 chars.
	 |             Added new field SOURCE = source system code where opportunity
	 |             was identified originally. This field is not currently available
	 |             in the Pending dataset, but is now required in the Disposition file.
	 +----------------------------------------------------------------------SASDOC*;

	
%*SASDOC -----------------------------------------------------------------------
	 |	REMOVED THE COMPLICATED LOOPING PROCESS OF CREATING MACRO VARIABLES PER ROW 
	 |	AND ASSIGNING CEE_OPP_STATUS_CD AND THE CEE_OPP_STATUS_RSN_CD BASED ON THE 
	 |	DATA_QUALITY_CD VARIABLE. THIS WILL BE COVERED IN THE FOLLOWING DATA STEP - AK 21FEB2012
	 |
	 +----------------------------------------------------------------------SASDOC*;



	%*SASDOC -----------------------------------------------------------------------
	 |	AK - 21FEB2012
	 |	THE DATA STEP BELOW PERFORMS THE FOLLOWING TASKS. 
	 | 1) EXTRACT OPPORTUNITY_ID RECIPIENT_ID APN_CMCTN_ID DATA_QUALITY_CD FROM PENDING SAS DATASET.
	 |
	 | 2) FORMAT THE FOLLOWING VARIABLES AS REQUIRED
	 |				APN_CMCTN_ID 
	 |			 	WP_PHONE_NUMBER			
	 |			 	SOURCE
	 |				OPPORTUNITY_ID1 
	 |				CEE_PATIENT_ID 
	 |				CEE_OPP_STATUS_CD 
	 |				CEE_OPP_STATUS_RSN_CD 
	 |				DELIVERY_DATE_TIME 
	 |
	 |	3)LEFT ALIGNS THE VARIABLES.
	 |
	 |	4)ASSIGN THE CEE_OPP_STATUS_CD AND THE CEE_OPP_STATUS_RSN_CD BASED ON 
	 |	  PROGRAM_ID AND THE DATA_QUALITY_CD.
	 |	
	 |	5) DROP AND RENAME VARIABLES AS NEEDED.
	 |
	 |	6) THE FINAL OUTPUT OF THIS STEP IS THE DATASET THAT HAS ALL THE REQUIRED VARIABLES
	 |	   THAT ARE NEEDED FOR THE DISPOSITION FILE AND ARE ALIGNED. 
	 |
	 |	
	 +----------------------------------------------------------------------SASDOC*;


%LET SOURCE = EOMS;

DATA WORK.ALIGNED_&initiative_id.

(	RENAME	= (	APN_CMCTN_ID1 = APN_CMCTN_ID
				OPPORTUNITY_ID1 = OPPORTUNITY_ID 
				CEE_OPP_STATUS_CD = CEE_OPP_STATUS_CD
				CEE_OPP_STATUS_RSN_CD1 = CEE_OPP_STATUS_RSN_CD));

	SET DATA_PND.T_&INITIATIVE_ID._&PHASE_SEQ_NB._&CMCTN_ROLE_CD. 
	(KEEP = OPPORTUNITY_ID RECIPIENT_ID APN_CMCTN_ID DATA_QUALITY_CD);

 	
	FORMAT	APN_CMCTN_ID1 $30.
			WP_PHONE_NUMBER $10.
			SOURCE $5.
			OPPORTUNITY_ID1 $12.
			CEE_PATIENT_ID $12.
			CEE_OPP_STATUS_CD $12.
     		CEE_OPP_STATUS_RSN_CD $12.
			DELIVERY_DATE_TIME $14.;
	
	APN_CMCTN_ID1 = LEFT(APN_CMCTN_ID);
	SOURCE = LEFT("&SOURCE");
	OPPORTUNITY_ID1 = LEFT(OPPORTUNITY_ID);
	CEE_PATIENT_ID = LEFT(RECIPIENT_ID);
	CEE_CHANNEL_CODE = LEFT(&CEE_CHANNEL_CODE.);
	CEE_OPT_OUT = LEFT(&CEE_OPT_OUT.);
/*	DELIVERY_DATE_TIME = LEFT(COMPRESS(TRANSLATE("&DATE1.",'',':.')));*/
	DELIVERY_DATE_TIME = LEFT("&DATE1");

	IF DATA_QUALITY_CD IN (1,2) THEN DO;


		IF &PROGRAM_ID IN (5252 5253 5254 5255 5256 5270 5296 5297 5349
					   5350 5351 5352 5353 5354 5355 5356 5357 5368 ) THEN DO;

    					 CEE_OPP_STATUS_CD=1 ;
     					 CEE_OPP_STATUS_RSN_CD = 0;
  					END;

		ELSE IF &PROGRAM_ID=5371 THEN DO;
    					 CEE_OPP_STATUS_CD=1 ;
     					 CEE_OPP_STATUS_RSN_CD = 201;
  					END;
				END;

	ELSE IF DATA_QUALITY_CD=3 THEN DO;
 						CEE_OPP_STATUS_CD=8 ;
 						CEE_OPP_STATUS_RSN_CD = &OPP_SATUS_RSN_CD_INVALID;
 				END;

	WHERE RECIPIENT_ID NE . ;

	DROP APN_CMCTN_ID RECIPIENT_ID OPPORTUNITY_ID; 

RUN;



DATA SAVING.print_disposition_file_&initiative_id.;
SET WORK.ALIGNED_&initiative_id.;
RUN;


DATA WORK.ALIGNED_&initiative_id.;
SET WORK.ALIGNED_&initiative_id. ;
DROP DATA_QUALITY_CD;
RUN;


PROC CONTENTS VARNUM;
RUN;




%*SASDOC -----------------------------------------------------------------------
 | COUNT THE NUMBER OF OBSERVATIONS IN PENDING DATASET WITH RECEIPIENT_ID NOT NULL.
 | THIS VALUE WILL USED TO INSERT THE NUMBER OF RECORDS INTO THE CONTROL FILE
 | AK - 21FEB2012
 +----------------------------------------------------------------------SASDOC*;



PROC SQL;
SELECT COUNT(*) INTO: TOTAL
FROM DATA_PND.T_&INITIATIVE_ID._&PHASE_SEQ_NB._&CMCTN_ROLE_CD. 
where recipient_id ne .;
QUIT;

%PUT NOTE: &TOTAL RECORDS IN PENDING DATASET WITH RECEIPIENT_ID NOT NULL;



/*	EVERYTHING FROM HERE REMAINS THE SAME AS THE ORIGINAL. THIS CREATES THE DISPOSITION AND
	CONTROL FILES AND FTPs THEM TO THE RESPECTIVE SERVERS - AK 21FEB2012*/

** This macro variable will hold the current date that is being used in the name of disposition file  ** ;
%LET DATEVAR=%SYSFUNC(DATE(),YYMMDDN08.);
** 09Aug2010 D.Palmer Added creation of TIMEVAR macro variable to be used in the name of the control and disposition files **;
DATA _null_;
     currtime = put(timepart(DATETIME()),time8.);
	 editTime = translate(currtime,'','.','',':');
	 concatTime = compress(editTime);
	 call symput('TIMEVAR',concatTime);
RUN;
%LET TIMEVAR = %sysfunc(trim(&TIMEVAR));


%*SASDOC -----------------------------------------------------------------------
 | CREATION OF DISPOSITION FILE IN .DAT FORMAT.IT IS VARIABLE LENGTH PIPE DELIMITED
 | FLAT FILES .
 | 09Aug2010 D.Palmer Changed length of Delivery_Date_Time from 20 to 19 chars.
 |           Added new field SOURCE. Added dsd and colon modifier to force
 |           output to be variable length delimited with no blank space between
 |           delimeters when there is a missing value. Changed Disposition file name 
 |           prefix from cee to eoms and replaced initiative id with a time variable.
 +----------------------------------------------------------------------SASDOC*;

** SET OPTIONS TO USE BLANK FOR MISSING NUMERIC DATA **;
OPTIONS MISSING='';

DATA _NULL_;
SET WORK.ALIGNED_&initiative_id.;
FILE "/herc&sysmode/data/hercules/gen_utilities/sas/cee_temp_dataset/eoms_print_hercules_disposition_&datevar.&timevar..dat" dlm='|' dsd;

/*FILE "/DATA/sasadhoc1/ak/eoms_print_hercules_disposition_&datevar.&timevar..dat" dlm='|' dsd;*/
PUT
SOURCE :$5.  
OPPORTUNITY_ID :$12.
CEE_CHANNEL_CODE :$12. 
CEE_PATIENT_ID :$12. 
CEE_OPP_STATUS_CD :$12. 
CEE_OPP_STATUS_RSN_CD :$12. 
APN_CMCTN_ID :$30. 
WP_PHONE_NUMBER :$10. 
CEE_OPT_OUT :$1.
DELIVERY_DATE_TIME :$14.	
;
RUN;




** RESET OPTIONS TO DEFAULT CHAR FOR MISSING NUMERIC DATA **;
OPTIONS MISSING='.';

%*SASDOC -----------------------------------------------------------------------
 | CREATE CONTROL FILE AS A VARIABLE LENGTH PIPE DELIMITED FLAT FILE.
 | NAME THE FILE USING THE SAME NAME AS THE DISPOSITION FILE BUT SUFFIX IT WITH
 | THE EXTENSION .ctl INSTEAD OF .dat.
 | 09Aug2010 D.Palmer Created this Data step 
 +----------------------------------------------------------------------SASDOC*;
** SET OPTIONS TO USE BLANK FOR MISSING NUMERIC DATA **;
OPTIONS MISSING='';
DATA _NULL_;

FILE "/herc&sysmode/data/hercules/gen_utilities/sas/cee_temp_dataset/eoms_print_hercules_disposition_&datevar.&timevar..ctl" dlm='|' dsd;

/*FILE "/DATA/sasadhoc1/ak/eoms_print_hercules_disposition_&datevar.&timevar..dat" dlm='|' dsd;*/

FILE_TYP = 'DO'; /* Delivery or Disposition  */
FILE_NM = "eoms_print_hercules_disposition_&datevar.&timevar..ctl" ;
FILE_REC_CNT = left(&TOTAL);  /* Total records in Disposition file */
SRC_LOC_CD = 'HRCLS';  /* Source where file is coming from */
SRC_TYP='I';     /* Internal to CVS Caremark */
PUT 
FILE_TYP :$2.         
FILE_NM :$80.        
FILE_REC_CNT :12.  
SRC_LOC_CD :$20.    
SRC_TYP :$1.        
TRANS_VER_ID :$20.  
TRANS_ID :$15.      
FLLR1_TXT :$80.    
FLLR2_TXT :$80.	      
;
RUN;

** RESET OPTIONS TO DEFAULT CHAR FOR MISSING NUMERIC DATA **;
OPTIONS MISSING='.';


%*SASDOC -----------------------------------------------------------------------
 | DOING SECURE FTP FOR PRINT DISPOSITION FILE
 | 09Aug2010 D.Palmer Added ftp of the Control file to EOMS server
 +----------------------------------------------------------------------SASDOC*;


 **Reading  parameters for secure ftp from set_ftp table** ;
%LET DESTINATION_CD=97;
%PUT NOTE:DESTINATION_CD IS &DESTINATION_CD ;

  DATA _NULL_;
    SET AUX_TAB.SET_FTP(WHERE=(DESTINATION_CD=&DESTINATION_CD));
    CALL SYMPUT('RHOST', TRIM(LEFT(FTP_HOST)) );
    CALL SYMPUT('RUSER', TRIM(LEFT(FTP_USER)) );
	 CALL SYMPUT('DESTINATION_DIR', TRIM(LEFT(DESTINATION_ROOT_DIR)) );
  RUN;
  %PUT VALUE OF RHOST &RHOST ;
  %PUT VALUE OF RUSER &RUSER ;
  %PUT VALUE OF DEST DIR &DESTINATION_DIR ;

 **Defining parameters for secure ftp** ;

%LET SOURCE_DIR=/herc&sysmode/data/hercules/gen_utilities/sas/cee_temp_dataset/;

%LET FILE_NAME=eoms_print_hercules_disposition_&datevar.&timevar..dat ;

OPTIONS SYMBOLGEN ;
data _null_;
   file 'sftp_cmd';
   put /"lcd &SOURCE_DIR. "
      / "cd &DESTINATION_DIR."
     / "put &FILE_NAME."
     / 'quit';
run;
data _null_;
   rc = system("sftp &RUSER@&RHOST < sftp_cmd > sftp_log 2> sftp_msg");
   rc = system('rm sftp_cmd');  
   rc = system('rm sftp_log');
   rc = system('rm sftp_msg');

run;
** 09Aug2010 D.Palmer Added steps to secure ftp the associated control file to the same destination**;
%LET FILE_NAME=eoms_print_hercules_disposition_&datevar.&timevar..ctl ;

OPTIONS SYMBOLGEN ;
data _null_;
   file 'sftp_cmd';
   put /"lcd &SOURCE_DIR. "
      / "cd &DESTINATION_DIR."
     / "put &FILE_NAME."
     / 'quit';
run;
data _null_;
   rc = system("sftp &RUSER@&RHOST < sftp_cmd > sftp_log 2> sftp_msg");
   rc = system('rm sftp_cmd');  
   rc = system('rm sftp_log');
   rc = system('rm sftp_msg');

run;


/* 30APR2012 - AK ADDED CODE TO SEND EMAIL WITH THE DATA AND CONTROL FILENAMES THAT WAS SENT TO EOMS	*/
%LET CNTRL_FILE_NM = %STR(eoms_print_hercules_disposition_&datevar.&timevar..ctl);

PROC SQL NOPRINT;
SELECT datepart(HSC_TS) format = monname. INTO: FILE_MONTH 
FROM &HERCULES..TPHASE_RVR_FILE
WHERE INITIATIVE_ID = &INITIATIVE_ID.;
QUIT;

%PUT FILE_MONTH = &FILE_MONTH;

/*	SEND EMAIL TO HERCULES SUPPORT AND EOMS TEAM WITH THE NAME OF THE DISPOSITION FILE AND THE CONTROL FILE	*/

filename mymail email 'qcpap020@dalcdcp';

			data _null_;
			    file mymail
				to =('hercules.support@caremark.com')
				cc=('ClinAppsEOMSSupport@caremark.com')
				subject="HERCULES SUPPORT:  DISPOSITION FILE SENT TO EOMS - &FILE_MONTH. FILE"
				;
			    put 'Hello:' ;
			    put / "The following disposition and control files have been sent to EOMS.";
				put   "File Month: &FILE_MONTH. (Month is based on the created timestamp in Hercules)";
				put / "&FILE_NAME.";
				put / "&CNTRL_FILE_NM.";
				put / "Hercules Initiative ID: &initiative_id.";
			    put / 'Thanks,';
			    put   'Hercules Support';
				

			run;
			quit;




%mend cee_disposition_file;
