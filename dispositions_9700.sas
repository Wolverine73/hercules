%include '/home/user/qcpap020/autoexec_new.sas'; 
/**HEADER -------------------------------------------------------------------------------------------------
  | NAME:     cee_disposition_9700.sas
  |
  | PURPOSE:  CREATE PRINT DISPOSITION FILE TO BE SENT BACK TO CEE .
  |          
  |
  | LOGIC :THIS MACRO USES PENDING SAS DATASET TO CREATE DISPOSITION FILES. THIS DISPOSITION FILE
  |        IS BEING SECURE FTPed TO DESIRED LOCATION. 
  |INPUT : PENDING SAS DATASET          
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
  |                  
  +-------------------------------------------------------------------------------------------------HEADER*/




%*SASDOC -----------------------------------------------------------------------
 | THIS LIBRARY WILL STORE THE PRINT DISPOSITION FILE FOR THE TIME BEING
 | 
 +----------------------------------------------------------------------SASDOC*;
%set_sysmode(mode=prod);
OPTIONS MPRINT SOURCE2 MPRINTNEST MLOGIC MLOGICNEST symbolgen ; 
options sysparm='INITIATIVE_ID=9852 PHASE_SEQ_NB=1';
%include "/herc&sysmode/prg/hercules/hercules_in.sas";

LIBNAME SAVING "/herc&sysmode/data/hercules/gen_utilities/sas/cee_temp_dataset" ;

data PRINT_DISPOSITION_FILE;
  set SAVING.PRINT_DISPOSITION_FILE;
run;

%MACRO cee_disposition_9700 ;
 
%*SASDOC ----------------------------------------------------------------------- | FETCHING CMCTN_ROLE_CODE
 | 
 +----------------------------------------------------------------------SASDOC*;

DATA _NULL_;
 		SET &HERCULES..TPHASE_RVR_FILE(WHERE=( INITIATIVE_ID=&INITIATIVE_ID));
 		CALL SYMPUT('CMCTN_ROLE_CD' , TRIM(LEFT(CMCTN_ROLE_CD)));
 		
 	RUN;

%LET TBL_NAME_OUT_SH_MAIN=T_&INITIATIVE_ID._&PHASE_SEQ_NB._&CMCTN_ROLE_CD._PENDING;
%PUT NOTE:VALUE OF CMCTN ROLE CODE IS &CMCTN_ROLE_CD ;
%PUT NOTE:DATASET IS  T_&INITIATIVE_ID._&PHASE_SEQ_NB._&CMCTN_ROLE_CD._PENIDNG;



%*SASDOC -----------------------------------------------------------------------
 | THESE VALUES CAN BE CHNAGED IN FUTURE
 |
 +----------------------------------------------------------------------SASDOC*;
%LET CEE_OPT_OUT =0 ;
%LET CEE_OPP_STATUS_RSN_CD = 2;
%LET CEE_CHANNEL_CODE=1 ;

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
		SET DATA_ARC.&TBL_NAME_OUT_SH_MAIN;
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
		 CREATE TABLE SAVING.PRINT_DISPOSITION_FILE 
		 (SOURCE CHAR(5),
         OPPORTUNITY_ID NUM ,
		 CEE_CHANNEL_CODE NUM ,
		 CEE_PATIENT_ID NUM ,
		 CEE_OPP_STATUS_CD NUM ,
		 CEE_OPP_STATUS_RSN_CD NUM ,
		 COMMUNICATION_ID CHAR(30) ,
		 WP_PHONE_NUMBER CHAR(10),
		 CEE_OPT_OUT NUM ,
		 DELIVERY_DATE_TIME  CHAR(19)
	  );
	 QUIT ;

%*SASDOC -----------------------------------------------------------------------
 | CALCLATING TOTAL NUMBER OF ROWS IN PENDING DATASET IN VARIABLE TOTAL
 | 
 +----------------------------------------------------------------------SASDOC*;
%LET DSID=%SYSFUNC(OPEN(DATA_ARC.&TBL_NAME_OUT_SH_MAIN)); 
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
      &PROGRAM_ID=5357 
   %then %do;
     %LET CEE_OPP_STATUS_CD=1 ;
     %LET CEE_OPP_STATUS_RSN_CD = 1;
  %end;
	%IF &PROGRAM_ID=5371 
   %then %do;
     %LET CEE_OPP_STATUS_CD=1 ;
     %LET CEE_OPP_STATUS_RSN_CD = 201;
  %end;
%END;

%*SASDOC -----------------------------------------------------------------------
 | INSERTING VALUES INTO PRINT DISPOSITION FILE
 | 01apr2010 - G. dudley - changed CEE_OPP_STATUS_CD to equal 6 instead of 2
 | 09Aug2010 - D. Palmer - Added new field SOURCE that is not currently available
 |             in the Pending dataset, but is now a required field in the Disposition
 |             file. Hardcoded the value for SOURCE since the value is not yet available.
 | 12nov2010 - G. dudley - changed CEE_OPP_STATUS_CD to equal 8 instead of 6
 +----------------------------------------------------------------------SASDOC*;
%ELSE %IF &&DATA_QUALITY_CD&Q=3 %THEN %DO ;
 %LET CEE_OPP_STATUS_CD=8 ;
 %LET CEE_OPP_STATUS_RSN_CD = &OPP_SATUS_RSN_CD_INVALID;
 %END;
 %LET SOURCE = EOMS;

PROC SQL ;
INSERT INTO SAVING.PRINT_DISPOSITION_FILE 
VALUES("&SOURCE",&&OPPORTUNITY_ID&Q,&CEE_CHANNEL_CODE,&&RECIPIENT_ID&Q,&CEE_OPP_STATUS_CD,&CEE_OPP_STATUS_RSN_CD,"&&APN_CMCTN_ID&Q","",&CEE_OPT_OUT,"&DATE1");


%END;/*DO LOOP ENDS HERE*/

%*SASDOC -----------------------------------------------------------------------
 | EXPORTING THE PRINT DISPOSITION FILE
 | 09Aug2010 D. Palmer - Added DATA step to create a macro variable to hold the current
 |  time (hhmmss) to be used in the name of the control file and disposition file        
 +----------------------------------------------------------------------SASDOC*;

** This macro variable will hold the current date that is being used in the name of disposition file  ** ;
%LET DATEVAR=%sysfunc(DATE(),YYMMDDN08.);
** 09Aug2010 D.Palmer Added creation of TIMEVAR macro variable to be used in the name of the control and disposition files **;
DATA _null_;
     currtime = put(timepart(DATETIME()),time8.);
	 editTime = translate(currtime,'','.','',':');
	 concatTime = compress(editTime);
	 call symput('TIMEVAR',concatTime);
RUN;
%LET TIMEVAR = %sysfunc(trim(&TIMEVAR));

 *SASDOC -----------------------------------------------------------------------
 | 05jan2011 G. Dudley - Added the current date and time to the disposition
 | SAS dataset so reporting can be done
 +----------------------------------------------------------------------SASDOC*;
  DATA SAVING.PRINT_DISPOSITION_FILE_&initiative_id. ;
    SET SAVING.PRINT_DISPOSITION_FILE ;
  RUN;


%*SASDOC -----------------------------------------------------------------------
 | MAKING ALL THE DATAVALUES LEFT ALIGNED  .
 | 09Aug2010 - D.Palmer Added new field SOURCE.
 +----------------------------------------------------------------------SASDOC*;
DATA WORK.ALIGN;
RENAME
SOURCE1 = SOURCE
OPPORTUNITY_ID1 = OPPORTUNITY_ID
CEE_CHANNEL_CODE1 = CEE_CHANNEL_CODE
CEE_PATIENT_ID1 = CEE_PATIENT_ID
CEE_OPP_STATUS_CD1 = CEE_OPP_STATUS_CD
CEE_OPP_STATUS_RSN_CD1 = CEE_OPP_STATUS_RSN_CD
CEE_OPT_OUT1 = CEE_OPT_OUT
DELIVERY_DATE_TIME1 = DELIVERY_DATE_TIME;
drop SOURCE
OPPORTUNITY_ID
CEE_CHANNEL_CODE
CEE_PATIENT_ID
CEE_OPP_STATUS_CD
CEE_OPP_STATUS_RSN_CD
CEE_OPT_OUT
DELIVERY_DATE_TIME;

SET SAVING.PRINT_DISPOSITION_FILE  ;
SOURCE1 = left(SOURCE);
OPPORTUNITY_ID1 = left(OPPORTUNITY_ID);
CEE_CHANNEL_CODE1 = left(CEE_CHANNEL_CODE);
CEE_PATIENT_ID1 = left(CEE_PATIENT_ID);
CEE_OPP_STATUS_CD1 = left(CEE_OPP_STATUS_CD);
CEE_OPP_STATUS_RSN_CD1 = left(CEE_OPP_STATUS_RSN_CD);
CEE_OPT_OUT1 = left(CEE_OPT_OUT);
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
 |           prefix from cee to eoms and replaced initiative id with a time variable.
 +----------------------------------------------------------------------SASDOC*;
** SET OPTIONS TO USE BLANK FOR MISSING NUMERIC DATA **;
OPTIONS MISSING='';

DATA _NULL_;
SET WORK.ALIGN;
FILE "/herc&sysmode/data/hercules/gen_utilities/sas/cee_temp_dataset/eoms_print_hercules_disposition_&datevar.&timevar..dat" dlm='|' dsd;
PUT
SOURCE :$5.  
OPPORTUNITY_ID :$10.
CEE_CHANNEL_CODE :$5. 
CEE_PATIENT_ID :$20. 
CEE_OPP_STATUS_CD :$5. 
CEE_OPP_STATUS_RSN_CD :$5. 
COMMUNICATION_ID :$30. 
WP_PHONE_NUMBER :$10. 
CEE_OPT_OUT :1.
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

FILE "/herc&sysmode/data/hercules/gen_utilities/sas/cee_temp_dataset/eoms_print_hercules_disposition_&datevar.&timevar..ctl" dlm='|' dsd;
FILE_TYP = 'DO'; /* Delivery or Disposition  */
FILE_NM = "eoms_print_hercules_disposition_&datevar.&timevar..dat" ;
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


OPTIONS NOSYMBOLGEN;

 %MEND cee_disposition_9700;
** 09Aug2010 D.Palmer commented out macro call since this macro is called from update_cmctn_history **;
%cee_disposition_9700; 
