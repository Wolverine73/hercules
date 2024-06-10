/*HEADER*************************************************************************
 Program Name     : cmctn_error_rprt.sas
 Purpose          : FTP the Communication HIstory error files from the mainframe
                    and produce an error report per application.

 Predecessors     : Mainframe programs:
          					QCPCM11D
          					QCPCM12D
          					QCPCM13D
          					QCPCM14D
          					QCPCM15D
                    
 Input files      : Mainframe files (All GDGs):
					QCPCM11D - Chicago Data Warehouse - QCPPNP.CMA.CMAEB014.ERRORS.FILE(0)
					QCPCM12D - Care Patterns          - QCPPNP.CMA.CMAEB023.ERRORS.FILE(0)
					QCPCM13D - HERCULES               - QCPPNP.CMA.CMAEB028.ERRORS.FILE(0)
					QCPCM14D - MF 10 PM               - QCPPNP.CMA.CMAEB016.ERRORS.CONC1(0)
					QCPCM15D - MF 2:30 AM             - QCPPNP.CMA.CMAEB016.ERRORS.CONC2(0)
 

 Input prg files  : cmctn_error_rprt_in.sas (parameter file).
 
 Output           : PDF reports:
                    /DATA/sas&sysmode.1/hercules/gen_utilities/sas/update_cmctn/HERCULES.PDF";
                    /DATA/sas&sysmode.1/hercules/gen_utilities/sas/update_cmctn/CAREPATTERNS.PDF";
                    /DATA/sas&sysmode.1/hercules/gen_utilities/sas/update_cmctn/QL MAINFRAME.PDF";
                    /DATA/sas&sysmode.1/hercules/gen_utilities/sas/update_cmctn/DATAWAREHOUSE.PDF";
*********************************************************************************
|	    Apr  2007    - Greg Dudley Hercules Version  1.5
* HISTORY:  20APR2007 - G. Dudley - Original
*
*************************************************************************HEADER*/

%set_sysmode(mode=prod);
         
OPTIONS NOTES MLOGIC MPRINT SYMBOLGEN SOURCE SOURCE2 NODATE FORMDLIM=' ';                                                                     
%include "/PRG/sas&sysmode.1/hercules/gen_utilities/sas/cmctn_history_error_rpt_in.sas";

*SASDOC************************************************************
* FORMART VALUES FOR ERROR CODE DESCRIPTIONS
*******************************************************************;
PROC FORMAT;
  VALUE $ERR_CD
  '0000' = 'SUCCESSFUL INSERT'
  '0001' = 'INVALID TEMPLATE'
  '0002' = 'INVALID RVR ROLE CODE'
  '0003' = 'INVALID RVR ID'
  '0004' = 'INVALID RVR NAME'
  '0005' = 'INVALID AVC CODE'
  '0006' = 'INVALID ADDRESS'
  '0007' = 'INVALID PHONE NUMBER'
  '0008' = 'INVALID EMAIL ADDRESS'
  '0009' = 'INVALID SUBJECT ROLE CODE'
  '0010' = 'INVALID SUBJECT ID'
  '0011' = 'INVALID COH ID for DELETE'
  '0012' = 'INVALID DRUG DESCRIBER CODE'
  OTHER  = 'UNKNOWN ERROR'
  ;
  VALUE $APPL
  '1' = 'DATA_WAREHOUSE'
  '2' = 'QL_MAINFRAME'
  '3' = 'CAREPATTERNS'
  '4' = 'HERCULES';
RUN;

*SASDOC************************************************************
* COBOL error file record layout
*******************************************************************;
/*
#H2R1      05  CB004-TRANSACTION-ID      PIC 9(09)    VALUE ZEROS.
#H2R1      05  FILLER                    PIC X(01)    VALUE '|'.
#H2R1 *    05  CB004-EMAIL-ADDR          PIC X(30)    VALUE SPACES.
#H2R1      05  CB004-USER-ID             PIC X(8)     VALUE SPACES.
           05  FILLER                    PIC X(01)    VALUE '|'.
           05  CB004-ERROR-NBR           PIC 9(04)    VALUE ZEROS.
           05  FILLER                    PIC X(01)    VALUE '|'.
           05  CB004-PGM-ID              PIC 9(09)    VALUE ZEROS.
           05  FILLER                    PIC X(01)    VALUE '|'.
           05  CB004-APN-CMM-ID          PIC X(15)    VALUE SPACES.
           05  FILLER                    PIC X(01)    VALUE '|'.
           05  CB004-CMM-GEN-TS          PIC X(26)    VALUE SPACES.
           05  FILLER                    PIC X(01)    VALUE '|'.
           05  CB004-RVR-ROLE-CD         PIC 9(04)    VALUE ZEROS.
           05  FILLER                    PIC X(01)    VALUE '|'.
           05  CB004-RVR-ID              PIC 9(09)    VALUE ZEROS.
           05  FILLER                    PIC X(01)    VALUE '|'.
           05  CB004-SBJ-ROLE-CD         PIC 9(04)    VALUE ZEROS.
           05  FILLER                    PIC X(01)    VALUE '|'.
           05  CB004-SBJ-ID              PIC 9(09)    VALUE ZEROS.
           05  FILLER                    PIC X(01)    VALUE '|'.
           05  CB004-DRUG-NDC            PIC 9(09)    VALUE ZEROS.
*/

*SASDOC************************************************************
* Macro %CLEARFLS will clear the filname references before 
* processing each application error file.
*******************************************************************;
%MACRO CLEARFLS;
FILENAME ch_err1 CLEAR ; RUN ;
FILENAME ch_err2 CLEAR ; RUN ;
FILENAME ch_err3 CLEAR ; RUN ;
FILENAME ch_err4 CLEAR ; RUN ;
FILENAME ch_err5 CLEAR ; RUN ;
%MEND CLEARFLS;

*SASDOC************************************************************
* Macro %READ_ERR will loop through all of the file refs and read
  in the error file per application.
*******************************************************************;
%MACRO READ_ERR(APPLICATION=);

%DO I = 1 %TO 5;

data ERR_FILE&I.(DROP=FILLER EMAIL PGM);
  LENGTH EMAIL_ADDR $40;
  infile CH_ERR&I MISSOVER;
  input EMAIL $30. 
        FILLER $1. 
        ERROR_NBR $4. 
        FILLER $1. 
        PGM $9. 
        FILLER $1. 
        APN_CMM_ID $15. 
        FILLER $1. 
        CMM_GEN_TS $26. 
        FILLER $1. 
        RVR_ROLE_CD $4. 
        FILLER $1. 
        RVR_ID $9. 
        FILLER $1. 
        SBJ_ROLE_CD $4. 
        FILLER $1. 
        SBJ_ID $9. 
    		FILLER $1. 
        DRUG_NDC $9.;
  PGM_ID = INPUT(PGM,9.);
  *SASDOC***********************************
  * When process an error file, if the
  * email address is "NONE FOUND" change 
  * "PRODUCTIONSUPPORTANALYTICS"
  ******************************************;
  IF EMAIL = 'NONE FOUND' THEN DO;
    EMAIL = 'HERCULES.SUPPORT';
  END;
  EMAIL_ADDR=TRIM(LEFT(EMAIL)) || '@caremark.com';
  LENGTH ERR_DESC $50 EMAIL_ADDR $40;
  ERR_DESC = PUT(ERROR_NBR,$ERR_CD.);
  ERR_YR=SCAN(CMM_GEN_TS,1,'-');
  ERR_MTH=SCAN(CMM_GEN_TS,2,'-');
  LABEL EMAIL_ADDR='Email'
        ERROR_NBR='Error*Code'
        PGM_ID='Program*ID'
        APN_CMM_ID='Application*Communication*ID'
        CMM_GEN_TS='Generated*Time Stamp'
        RVR_ROLE_CD='Receiver*Role*Code'
        RVR_ID='Receiver*ID'
        SBJ_ROLE_CD='Subject*Role Code'
        SBJ_ID='Subject*ID'
        DRUG_NDC='NDC*Number'
    		ERR_DESC='Error'
        ERR_YR='YEAR OF ERROR'
        ERR_MTH='MONTH OF ERROR';
run;

*SASDOC************************************************************
* Since a weeks worth of data is appended into one file,
* duplicates error records need to be removed
*******************************************************************;
PROC SORT DATA=ERR_FILE&I. NODUPKEY ;
  BY ERR_YR PGM_ID ERROR_NBR APN_CMM_ID CMM_GEN_TS RVR_ROLE_CD RVR_ID SBJ_ROLE_CD SBJ_ID DRUG_NDC ;
RUN;

*SASDOC************************************************************
* Produce the error report per application
* send error file to patientlist folder
* n. williams made a change to title1
*******************************************************************;

 %IF &I=5 %THEN %DO ;

	DATA _NULL_;
	  CALL SYMPUT('MTH',TRIM(LEFT(PUT(TODAY(),MONNAME3.))));
	  CALL SYMPUT('DAY',TRIM(LEFT(PUT(TODAY(),DAY.))));
	  CALL SYMPUT('YR',TRIM(LEFT(PUT(TODAY(),YEAR.))));
	  CALL SYMPUT('WK',TRIM(LEFT(PUT(TODAY(),WEEKDATE.))));
	RUN;     

    DATA FINAL_ERR;
		SET 
		%do J = 1 %TO 5;
          ERR_FILE&J. 
 
		%END;
        ;
	RUN;

	PROC SORT DATA=FINAL_ERR NODUPKEY ;
	  BY ERR_YR PGM_ID ERROR_NBR APN_CMM_ID CMM_GEN_TS RVR_ROLE_CD RVR_ID SBJ_ROLE_CD SBJ_ID DRUG_NDC ;
	RUN;

	filename RPTFL "/DATA/sas&sysmode.1/hercules/gen_utilities/sas/update_cmctn/&APPLICATION._ERROR_COUNT_&MTH.&DAY.&YR..PDF";

/*	filename RPTFL ftp "/users/patientlist/Comm_history_error_reports/&APPLICATION._&MTH.&DAY.&YR..PDF"*/
/*	        USER=patientlist PASS=patient1 mach='sfb006.psd.caremark.int' RECFM=V DEBUG;*/

*SASDOC************************************************************
* Produce Frequency count of Errors
*******************************************************************;
  PROC FREQ DATA=FINAL_ERR;
    BY ERR_YR;
    TABLE PGM_ID*ERROR_NBR / MISSING OUT=&APPLICATION._ERROR_COUNT;
	  FORMAT ERROR_NBR $ERR_CD.; 
  RUN;
  PROC TRANSPOSE DATA=&APPLICATION._ERROR_COUNT;
    BY ERR_YR PGM_ID;
	  FORMAT ERROR_NBR $ERR_CD.; 
  RUN;



*SASDOC************************************************************
* Produce a PDF report per application
*******************************************************************;
	ODS LISTING CLOSE;
	ODS PDF FILE=RPTFL;
	OPTIONS ORIENTATION=LANDSCAPE LS=256;
	TITLE1 "Weekly Communication History";
	TITLE2 'Transaction Error Counts';
	TITLE3 "Application - &APPLICATION";
	TITLE4 "&WK";
  PROC PRINT DATA=&APPLICATION._ERROR_COUNT SPLIT='*';
    BY ERR_YR;
    PAGEBY ERR_YR;
    ID ERR_YR;
    VAR PGM_ID ERROR_NBR COUNT;
    SUM COUNT;
    SUMBY ERR_YR;
    FORMAT ERROR_NBR $ERR_CD. COUNT COMMA10.;
  RUN;
	ODS PDF CLOSE;
	ODS LISTING;
  DATA &APPLICATION._ERROR_COUNT;
    SET &APPLICATION._ERROR_COUNT;
    format percent percent10.;
  RUN;
 %END;
%END;


%MEND READ_ERR;

*SASDOC************************************************************
* Allocate file refs to the mainframe files and process them.
*******************************************************************;

*SASDOC************************************************************
* DATA WAREHOUSE ERROR FILE
*******************************************************************;
FILENAME ch_err1 FTP "'QCPPNP.CMA.CMAEB014.ERRORS.FILE(0)'" lrecl=128 host='mainframe.psd.caremark.int'
   USER="&FTP_user" PASS="&FTP_pass" rcmd='site rdw recfm=fb lrecl=128' DEBUG;

FILENAME ch_err2 FTP "'QCPPNP.CMA.CMAEB014.ERRORS.FILE(-1)'" lrecl=128 host='mainframe.psd.caremark.int'
   USER="&FTP_user" PASS="&FTP_pass" rcmd='site rdw recfm=fb lrecl=128' DEBUG;

FILENAME ch_err3 FTP "'QCPPNP.CMA.CMAEB014.ERRORS.FILE(-2)'" lrecl=128 host='mainframe.psd.caremark.int'
   USER="&FTP_user" PASS="&FTP_pass" rcmd='site rdw recfm=fb lrecl=128' DEBUG;

FILENAME ch_err4 FTP "'QCPPNP.CMA.CMAEB014.ERRORS.FILE(-3)'" lrecl=128 host='mainframe.psd.caremark.int'
   USER="&FTP_user" PASS="&FTP_pass" rcmd='site rdw recfm=fb lrecl=128' DEBUG;

FILENAME ch_err5 FTP "'QCPPNP.CMA.CMAEB014.ERRORS.FILE(-4)'" lrecl=128 host='mainframe.psd.caremark.int'
   USER="&FTP_user" PASS="&FTP_pass" rcmd='site rdw recfm=fb lrecl=128' DEBUG;

%READ_ERR(APPLICATION=DATA_WAREHOUSE);
%CLEARFLS;


*SASDOC************************************************************
* QL MAINFRAME ERROR FILES
*******************************************************************;
*FILENAME ch_err2 FTP "'QCPPNP.CMA.CMAEB016.ERRORS.CONC1(0)'" lrecl=128 host='mainframe.psd.caremark.int'
   USER="&FTP_user" PASS="&FTP_pass" rcmd='site rdw recfm=fb lrecl=128' DEBUG;
FILENAME ch_err1 FTP "'QCPPNP.CMA.CMAEB016.ERRORS.CONC2(0)'" lrecl=128 host='mainframe.psd.caremark.int'
   USER="&FTP_user" PASS="&FTP_pass" rcmd='site rdw recfm=fb lrecl=128' DEBUG;
FILENAME ch_err2 FTP "'QCPPNP.CMA.CMAEB016.ERRORS.CONC2(-1)'" lrecl=128 host='mainframe.psd.caremark.int'
   USER="&FTP_user" PASS="&FTP_pass" rcmd='site rdw recfm=fb lrecl=128' DEBUG;
FILENAME ch_err3 FTP "'QCPPNP.CMA.CMAEB016.ERRORS.CONC2(-2)'" lrecl=128 host='mainframe.psd.caremark.int'
   USER="&FTP_user" PASS="&FTP_pass" rcmd='site rdw recfm=fb lrecl=128' DEBUG;
FILENAME ch_err4 FTP "'QCPPNP.CMA.CMAEB016.ERRORS.CONC2(-3)'" lrecl=128 host='mainframe.psd.caremark.int'
   USER="&FTP_user" PASS="&FTP_pass" rcmd='site rdw recfm=fb lrecl=128' DEBUG;
FILENAME ch_err5 FTP "'QCPPNP.CMA.CMAEB016.ERRORS.CONC2(-4)'" lrecl=128 host='mainframe.psd.caremark.int'
   USER="&FTP_user" PASS="&FTP_pass" rcmd='site rdw recfm=fb lrecl=128' DEBUG;

%READ_ERR(APPLICATION=QL_MAINFRAME);
%CLEARFLS;


*SASDOC************************************************************
* CAREPATTERNS ERROR FILE
*******************************************************************;
FILENAME ch_err1 FTP "'QCPPNP.CMA.CMAEB023.ERRORS.FILE(0)'" lrecl=128 host='mainframe.psd.caremark.int'
   USER="&FTP_user" PASS="&FTP_pass" rcmd='site rdw recfm=fb lrecl=128' DEBUG;
FILENAME ch_err2 FTP "'QCPPNP.CMA.CMAEB023.ERRORS.FILE(-1)'" lrecl=128 host='mainframe.psd.caremark.int'
   USER="&FTP_user" PASS="&FTP_pass" rcmd='site rdw recfm=fb lrecl=128' DEBUG;
FILENAME ch_err3 FTP "'QCPPNP.CMA.CMAEB023.ERRORS.FILE(-2)'" lrecl=128 host='mainframe.psd.caremark.int'
   USER="&FTP_user" PASS="&FTP_pass" rcmd='site rdw recfm=fb lrecl=128' DEBUG;
FILENAME ch_err4 FTP "'QCPPNP.CMA.CMAEB023.ERRORS.FILE(-3)'" lrecl=128 host='mainframe.psd.caremark.int'
   USER="&FTP_user" PASS="&FTP_pass" rcmd='site rdw recfm=fb lrecl=128' DEBUG;
FILENAME ch_err5 FTP "'QCPPNP.CMA.CMAEB023.ERRORS.FILE(-4)'" lrecl=128 host='mainframe.psd.caremark.int'
   USER="&FTP_user" PASS="&FTP_pass" rcmd='site rdw recfm=fb lrecl=128' DEBUG;

%READ_ERR(APPLICATION=CAREPATTERNS);
%CLEARFLS;

*SASDOC************************************************************
* HERCULES ERROR FILE
*******************************************************************;
FILENAME ch_err1 FTP "'QCPPNP.CMA.CMAEB028.ERRORS.FILE(0)'" lrecl=128 host='mainframe.psd.caremark.int'
   USER="&FTP_user" PASS="&FTP_pass" rcmd='site rdw recfm=fb lrecl=128' DEBUG;
FILENAME ch_err2 FTP "'QCPPNP.CMA.CMAEB028.ERRORS.FILE(-1)'" lrecl=128 host='mainframe.psd.caremark.int'
   USER="&FTP_user" PASS="&FTP_pass" rcmd='site rdw recfm=fb lrecl=128' DEBUG;
FILENAME ch_err3 FTP "'QCPPNP.CMA.CMAEB028.ERRORS.FILE(-2)'" lrecl=128 host='mainframe.psd.caremark.int'
   USER="&FTP_user" PASS="&FTP_pass" rcmd='site rdw recfm=fb lrecl=128' DEBUG;
FILENAME ch_err4 FTP "'QCPPNP.CMA.CMAEB028.ERRORS.FILE(-3)'" lrecl=128 host='mainframe.psd.caremark.int'
   USER="&FTP_user" PASS="&FTP_pass" rcmd='site rdw recfm=fb lrecl=128' DEBUG;
FILENAME ch_err5 FTP "'QCPPNP.CMA.CMAEB028.ERRORS.FILE(-4)'" lrecl=128 host='mainframe.psd.caremark.int'
   USER="&FTP_user" PASS="&FTP_pass" rcmd='site rdw recfm=fb lrecl=128' DEBUG;

%READ_ERR(APPLICATION=HERCULES);
%CLEARFLS;

%PUT 'NOTE: SYSCC= ' &SYSCC;
%PUT 'NOTE: SYSRC= ' &SYSRC;
