/**HEADER -------------------------------------------------------------------------------------------------
  | NAME:     abpd_disposition_file.sas
  |
  | PURPOSE:  CREATE PRINT DISPOSITION FILE TO BE SENT BACK TO ABPD .
  |          
  |
  | LOGIC :THIS MACRO USES PENDING SAS DATASET TO CREATE DISPOSITION FILES. THIS DISPOSITION FILE
  |        IS BEING SECURE FTPed TO DESIRED LOCATION. 
  |INPUT : PENDING SAS DATASET          
  |
  |OUTPUT : DISPOSITION FILE AND CONTROL FILE       
  |---------------------------------------------------------------------------------------------------------
  | HISTORY: 
  |                  
  +-------------------------------------------------------------------------------------------------HEADER*/

options MPRINT;

/*%set_sysmode(mode=sit2);*/
/*options sysparm='INITIATIVE_ID=8360 PHASE_SEQ_NB=1';*/

%set_sysmode;

%include "/herc&sysmode/prg/hercules/hercules_in.sas";


%*SASDOC -----------------------------------------------------------------------
 | THIS LIBRARY WILL STORE THE PRINT DISPOSITION FILE FOR THE TIME BEING
 | 
 +----------------------------------------------------------------------SASDOC*;

LIBNAME SAVING "/herc&sysmode/data/hercules/gen_utilities/sas/cee_temp_dataset" ;

%MACRO ABPD_DISPOSITION_FILE ;
 
%*SASDOC -----------------------------------------------------------------------
 | FETCHING CMCTN_ROLE_CODE
 | 
 +----------------------------------------------------------------------SASDOC*;

DATA _NULL_;
 		SET &HERCULES..TPHASE_RVR_FILE(WHERE=( INITIATIVE_ID=&INITIATIVE_ID));
 		CALL SYMPUT('CMCTN_ROLE_CD' , TRIM(LEFT(CMCTN_ROLE_CD)));
 		
 	RUN;

%LET TBL_NAME_OUT_SH_MAIN=T_&INITIATIVE_ID._&PHASE_SEQ_NB._&CMCTN_ROLE_CD;
%PUT NOTE:VALUE OF CMCTN ROLE CODE IS &CMCTN_ROLE_CD ;
%PUT NOTE:DATASET IS  T_&INITIATIVE_ID._&PHASE_SEQ_NB._&CMCTN_ROLE_CD;



%*SASDOC -----------------------------------------------------------------------
 | THESE VALUES CAN BE CHNAGED IN FUTURE
 |
 +----------------------------------------------------------------------SASDOC*;
%LET ABPD_OPT_OUT =0 ;
%LET ABPD_OPP_STATUS_RSN_CD = 2;
%LET ABPD_CHANNEL_CODE=1 ;

%LET OPP_SATUS_RSN_CD_VALID=1;
%LET OPP_SATUS_RSN_CD_INVALID=21;

****METHOD:1  FOR FETCHING THE DATE FROM TINITIATIVE TABLE***;
%*SASDOC -----------------------------------------------------------------------
 | FETCHING THE DATE VALUE FROM TINITIATIVE TABLE	
 | 09Aug2010 D.Palmer - Corrected bug in logic used to extract time part
 +----------------------------------------------------------------------SASDOC*;
DATA _NULL_;
 		SET &HERCULES..TINITIATIVE(WHERE=( INITIATIVE_ID=&INITIATIVE_ID));
 		CALL SYMPUT('DATE1' ,TRIM(LEFT(HSU_TS)));
 		
 	RUN;  
 
**CREATING DESIRED DATE FORMAT FOR OUR DATE VALUE FROM FETCHED DATE**;

DATA _null_;
      tPart=put(timepart("&DATE1"),time8.); 
      dPart=put(datepart("&DATE1"),MMDDYY10.);
      dtPart=translate(dPart,'.','/'); 
    uDate = strip(dtPart)!!':'!!strip(tPart);
    call symput('date1',uDate);
run;
%PUT NOTE:DATE IS  &date1;



%*SASDOC -----------------------------------------------------------------------
 | ASSIGNING TP MACRO VARIABLES 
 | 
 +----------------------------------------------------------------------SASDOC*;


	 DATA _NULL_;
		SET DATA_PND.&TBL_NAME_OUT_SH_MAIN;
		CALL SYMPUT("DATA_QUALITY_CD"||LEFT(_N_) , DATA_QUALITY_CD);
		CALL SYMPUT("APN_CMCTN_ID"||LEFT(_N_) , APN_CMCTN_ID);
		CALL SYMPUT("RECIPIENT_ID"||LEFT(_N_) , RECIPIENT_ID);
		CALL SYMPUT("OPPORTUNITY_ID"||LEFT(_N_) , OPPORTUNITY_ID);
	 		
	 RUN;

	%*SASDOC -----------------------------------------------------------------------
	 | DEFINING STRUCTURE OF PRINT DISPOSITION FILE 
	 | 09Aug2010 - D.Palmer changed length of Delivery_Date_Time from 20 to 19 chars.
	 |             Added new field SOURCE = source system code where opportunity
	 |             was identified originally. This field is not currently available
	 |             in the Pending dataset, but is now required in the Disposition file.
	 +----------------------------------------------------------------------SASDOC*;
	 PROC SQL;
		 CREATE TABLE WORK.PRINT_DISPOSITION_FILE 
		 (SOURCE CHAR(5),
     OPPORTUNITY_ID NUM ,
		 ABPD_CHANNEL_CODE NUM ,
		 ABPD_PATIENT_ID NUM ,
		 ABPD_OPP_STATUS_CD NUM ,
		 ABPD_OPP_STATUS_RSN_CD NUM ,
		 COMMUNICATION_ID CHAR(30) ,
		 WP_PHONE_NUMBER CHAR(10),
		 ABPD_OPT_OUT NUM ,
		 DELIVERY_DATE_TIME  CHAR(19)
	  );
	 QUIT ;

%*SASDOC -----------------------------------------------------------------------
 | CALCLATING TOTAL NUMBER OF ROWS IN PENDING DATASET IN VARIABLE TOTAL
 | 
 +----------------------------------------------------------------------SASDOC*;
%LET DSID=%SYSFUNC(OPEN(DATA_PND.&TBL_NAME_OUT_SH_MAIN)); 
%LET  TOT_AP_ATA=%SYSFUNC(attrn(&DSID,NOBS)); 
%LET RC=%SYSFUNC(CLOSE(&DSID));
%GLOBAL TOTAL ;
%LET TOTAL=&TOT_AP_ATA ;

%PUT NOTE:TOTAL NUMBER OF OBS IN PENDING &TOTAL ;

%*SASDOC -----------------------------------------------------------------------
 | INSERTING VALUES INTO PRINT DISPOSITION FILE
 |
 +----------------------------------------------------------------------SASDOC*;

%DO Q=1 %TO &TOTAL ;


%IF &&DATA_QUALITY_CD&Q=1 OR &&DATA_QUALITY_CD&Q=2 %THEN %DO ;
	%IF &PROGRAM_ID=5252 or &PROGRAM_ID=5253 or &PROGRAM_ID=5254 or &PROGRAM_ID=5255 or &PROGRAM_ID=5256 or 
      &PROGRAM_ID=5270 or &PROGRAM_ID=5296 or &PROGRAM_ID=5297 or &PROGRAM_ID=5349 or &PROGRAM_ID=5350 or &PROGRAM_ID=5351 or 
      &PROGRAM_ID=5352 or &PROGRAM_ID=5353 or &PROGRAM_ID=5354 or &PROGRAM_ID=5355 or &PROGRAM_ID=5356 or 
      &PROGRAM_ID=5357 or &PROGRAM_ID=5369
   %then %do;
     %LET ABPD_OPP_STATUS_CD=1 ;
     %LET ABPD_OPP_STATUS_RSN_CD = 1;
  %end;
	%IF &PROGRAM_ID=5371 
   %then %do;
     %LET ABPD_OPP_STATUS_CD=1 ;
     %LET ABPD_OPP_STATUS_RSN_CD = 201;
  %end;
%END;

%*SASDOC -----------------------------------------------------------------------
 | INSERTING VALUES INTO PRINT DISPOSITION FILE
 | 01apr2010 - G. dudley - changed ABPD_OPP_STATUS_CD to equal 6 instead of 2
 | 09Aug2010 - D. Palmer - Added new field SOURCE that is not currently available
 |             in the Pending dataset, but is now a required field in the Disposition
 |             file. Hardcoded the value for SOURCE since the value is not yet available.
 | 12nov2010 - G. dudley - changed ABPD_OPP_STATUS_CD to equal 8 instead of 6
 +----------------------------------------------------------------------SASDOC*;
%ELSE %IF &&DATA_QUALITY_CD&Q=3 %THEN %DO ;
 %LET ABPD_OPP_STATUS_CD=8 ;
 %LET ABPD_OPP_STATUS_RSN_CD = &OPP_SATUS_RSN_CD_INVALID;
 %END;
 %LET SOURCE = ABPD;

PROC SQL ;
INSERT INTO WORK.PRINT_DISPOSITION_FILE 
VALUES("&SOURCE",&&OPPORTUNITY_ID&Q,&ABPD_CHANNEL_CODE,&&RECIPIENT_ID&Q,&ABPD_OPP_STATUS_CD,&ABPD_OPP_STATUS_RSN_CD,"&&APN_CMCTN_ID&Q","",&ABPD_OPT_OUT,"&DATE1");


%END;/*DO LOOP ENDS HERE*/

DATA SAVING.PRINT_DISPOSITION_FILE_&INITIATIVE_ID. ;
SET WORK.PRINT_DISPOSITION_FILE ;
RUN;


%*SASDOC -----------------------------------------------------------------------
 | EXPORTING THE PRINT DISPOSITION FILE
 | 09Aug2010 D. Palmer - Added DATA step to create a macro variable to hold the current
 |  time (hhmmss) to be used in the name of the control file and disposition file        
 +----------------------------------------------------------------------SASDOC*;

** These macro variables will hold the current date/time-stamps used in the name of disposition file  ** ;

%global DATEVAR1 DATEVAR2 TIMEVAR;

DATA _NULL_;
 		SET &HERCULES..TINITIATIVE(WHERE=( INITIATIVE_ID=&INITIATIVE_ID));
 		CALL SYMPUT('DATE2' ,TRIM(LEFT(HSU_TS)));
 		
RUN;

%LET DATEVAR1=%sysfunc(DATE(),YYMMDDN08.);

DATA _null_;
    datadate=put(datepart("&DATE2"),YYMMDDN08.);
    call symput('DATEVAR2',datadate);
run;

%put NOTE: DATEVAR1=&DATEVAR1;
%put NOTE: DATEVAR2=&DATEVAR2;

DATA _null_;
     currtime = put(timepart(DATETIME()),time8.);
	 editTime = translate(currtime,'','.','',':');
	 concatTime = compress(editTime);
	 call symput('TIMEVAR',concatTime);
RUN;
%LET TIMEVAR = %sysfunc(trim(&TIMEVAR));
%put TIMEVAR = &TIMEVAR;

%*SASDOC -----------------------------------------------------------------------
 | MAKING ALL THE DATAVALUES LEFT ALIGNED  .
 | 09Aug2010 - D.Palmer Added new field SOURCE.
 +----------------------------------------------------------------------SASDOC*;
DATA WORK.ALIGN;
RENAME
SOURCE1 = SOURCE
OPPORTUNITY_ID1 = OPPORTUNITY_ID
ABPD_CHANNEL_CODE1 = ABPD_CHANNEL_CODE
ABPD_PATIENT_ID1 = ABPD_PATIENT_ID
ABPD_OPP_STATUS_CD1 = ABPD_OPP_STATUS_CD
ABPD_OPP_STATUS_RSN_CD1 = ABPD_OPP_STATUS_RSN_CD
ABPD_OPT_OUT1 = ABPD_OPT_OUT
DELIVERY_DATE_TIME1 = DELIVERY_DATE_TIME;
drop SOURCE
OPPORTUNITY_ID
ABPD_CHANNEL_CODE
ABPD_PATIENT_ID
ABPD_OPP_STATUS_CD
ABPD_OPP_STATUS_RSN_CD
ABPD_OPT_OUT
DELIVERY_DATE_TIME;

SET WORK.PRINT_DISPOSITION_FILE  ;
SOURCE1 = left(SOURCE);
OPPORTUNITY_ID1 = left(OPPORTUNITY_ID);
ABPD_CHANNEL_CODE1 = left(ABPD_CHANNEL_CODE);
ABPD_PATIENT_ID1 = left(ABPD_PATIENT_ID);
ABPD_OPP_STATUS_CD1 = left(ABPD_OPP_STATUS_CD);
ABPD_OPP_STATUS_RSN_CD1 = left(ABPD_OPP_STATUS_RSN_CD);
ABPD_OPT_OUT1 = left(ABPD_OPT_OUT);
DELIVERY_DATE_TIME1 = left(DELIVERY_DATE_TIME);
RUN;

PROC CONTENTS VARNUM;
RUN;

%*SASDOC -----------------------------------------------------------------------
 | CREATION OF DISPOSITION FILE IN .DAT FORMAT.IT IS VARIABLE LENGTH PIPE DELIMITED
 | FLAT FILES .
 | 09Aug2010 D.Palmer Changed length of Delivery_Date_Time from 20 to 19 chars.
 |           Added new field SOURCE. Added dsd and colon modifier to force
 |           output to be variable length delimited with no blank space between
 |           delimeters when there is a missing value. Changed Disposition file name 
 |           prefix from cee to ABPD and replaced initiative id with a time variable.
 +----------------------------------------------------------------------SASDOC*;
** SET OPTIONS TO USE BLANK FOR MISSING NUMERIC DATA **;
OPTIONS MISSING='';

DATA _NULL_;
SET WORK.ALIGN;
FILE "/%sysfunc(pathname(SAVING))/ABPD_DISP.&DATEVAR1..&DATEVAR2..&TIMEVAR..dat" dlm='|' dsd;
PUT
/*SOURCE :$5.  */
OPPORTUNITY_ID :$10.
ABPD_CHANNEL_CODE :$5. 
ABPD_PATIENT_ID :$20. 
ABPD_OPP_STATUS_CD :$5. 
ABPD_OPP_STATUS_RSN_CD :$5. 
COMMUNICATION_ID :$30. 
WP_PHONE_NUMBER :$10. 
ABPD_OPT_OUT :1.
DELIVERY_DATE_TIME :$19.	
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

FILE "/%sysfunc(pathname(SAVING))/ABPD_DISP.&DATEVAR1..&DATEVAR2..&TIMEVAR..TRIGGER" dlm='|' dsd;
FILE_TYP = 'DO'; /* Delivery or Disposition  */
FILE_NM = "ABPD_DISP.&DATEVAR1..&DATEVAR2..&TIMEVAR..dat" ;
FILE_REC_CNT = left(&TOTAL);  /* Total records in Disposition file */
*SRC_LOC_CD = 'HRCLS';  /* Source where file is coming from */
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

%macro SendFile(DESTINATION_CD=);
** RESET OPTIONS TO DEFAULT CHAR FOR MISSING NUMERIC DATA **;
OPTIONS MISSING='.';

%*SASDOC -----------------------------------------------------------------------
 | DOING SECURE FTP FOR PRINT DISPOSITION FILE
 | 09Aug2010 D.Palmer Added ftp of the Control file to ABPD server
 +----------------------------------------------------------------------SASDOC*;


 **Reading  parameters for secure ftp from set_ftp table** ;

%PUT NOTE:DESTINATION_CD IS &DESTINATION_CD ;

  DATA _NULL_;
    SET AUX_TAB.SET_FTP(WHERE=(DESTINATION_CD=&DESTINATION_CD));
    CALL SYMPUT('RHOST', TRIM(LEFT(FTP_HOST)) );
    CALL SYMPUT('RUSER', TRIM(LEFT(FTP_USER)) );
    CALL SYMPUT('PW', TRIM(LEFT(FTP_PASS)) );
	 CALL SYMPUT('DESTINATION_DIR', TRIM(LEFT(DESTINATION_ROOT_DIR)) );
  RUN;
  %PUT VALUE OF RHOST &RHOST ;
  %PUT VALUE OF RUSER &RUSER ;
  %PUT VALUE OF DEST DIR &DESTINATION_DIR ;

 **Defining parameters for secure ftp** ;

%LET SOURCE_DIR=/%sysfunc(pathname(SAVING))/;

%LET FILE_NAME=ABPD_DISP.&DATEVAR1..&DATEVAR2..&TIMEVAR..dat;

OPTIONS SYMBOLGEN ;
data _null_;
   file 'sftp_cmd';
   put /"lcd &SOURCE_DIR"
       /"&PW "
      / "cd &DESTINATION_DIR"
     / "put &FILE_NAME"
     / 'quit';
run;
data _null_;
   rc = system("sftp &RUSER@&RHOST < sftp_cmd > sftp_log 2> sftp_msg");
   /*
   rc = system('rm sftp_cmd');  
   rc = system('rm sftp_log');
   rc = system('rm sftp_msg');
  */
run;
** 09Aug2010 D.Palmer Added steps to secure ftp the associated control file to the same destination**;
%LET FILE_NAME=ABPD_DISP.&DATEVAR1..&DATEVAR2..&TIMEVAR..TRIGGER ;

OPTIONS SYMBOLGEN ;
data _null_;
   file 'sftp_cmd';
   put /"lcd &SOURCE_DIR"
       /"&PW "
      / "cd &DESTINATION_DIR"
     / "put &FILE_NAME"
     / 'quit';
run;
data _null_;
   rc = system("sftp &RUSER@&RHOST < sftp_cmd > sftp_log 2> sftp_msg");
   /*
   rc = system('rm sftp_cmd');  
   rc = system('rm sftp_log');
   rc = system('rm sftp_msg');
   */

run;
%mend SendFile;

OPTIONS NOSYMBOLGEN;

 %MEND ABPD_DISPOSITION_FILE;
 %abpd_disposition_file; 
 %SendFile(DESTINATION_CD=95); /*99=TEST 98=PROD*/
