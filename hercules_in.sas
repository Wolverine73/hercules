/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  hercules_in.sas
|
| LOCATION: /PRG/sas&sysmode.1/hercules
|
| PURPOSE:  To define a standard environment and common parameters for Hercules
|           Communication Engine programs.
|
|           Including:
|           1) Parse &SYSPARM to get INITIATIVE_ID and PHASE_SEQ_NB
|           2) Query HERCULES setup tables, and resolve macro parameters for the
|              initiative. There are:
|              SYSMODE
|              PROGRAM_ID,          TASK_ID,            EXT_DRUG_LIST_IN,
|              DFLT_INCLSN_IN,      DOCUMENT_LOC_CD,    PRT_CPNT_PARM_IN,
|              PRESCRIBER_PARM_IN,  TRGT_RECIPIENT_CD,  DSPLY_CLT_SETUP_CD,
|              DRG_DEFINITION_CD,   Email_USR,          EMAIL_IT,
|              PRG_DIR,             DATA_DIR,           RPT_DIR,   LOG_DIR,
|              TITLE_TX,            HERCULES ,          INITIATIVE_ID,
|              DESTINATION_CD       FTP_HOST,           FTP_USER,
|              FTP_PASS,            CLAIM_HIS_TBL,      TABLE_PREFIX  DB2_TMP,
|              LETTER_TYPE_QY_CD    OVRD_CLT_SETUP_IN
|           3) Define system mode and global directory and libname.
|           4) Define destination (macro string) for file release including,
|              pending files, final files and email.
|
|
| INPUT:    Parameters:  SYSPARM INITIATIVE_ID, PHASE_SEQ_NB, MODE.
|           data source: TINITIATIVE,      TPROGRAM,          TCMCTN_PROGRAM,
|                        TPROGRAM_TASK,    TPHASE_RVR_FILE,   TCMCTN_ENGINE_CD,
|                        ADM_LKP.ANALYTICS_USERS
|
| OUTPUT:   define HERCULES global macro parameters and setup the environment.
|
| USAGE:    The program will be called at the begining of the program level
|           parameter file using %include. The SYSPARM must be available either
|           through the nightly scheduling program or by specifying with OPTIONS:
|           e.g. OPTIONS SYSPARM='408 1', where 408 is the initiative_id and
|           1 is the phase_seq_nb.
|           The initiative_id specified must be a valid initiative_id and available
|           TINITIATIVE table.
|
| RS - 11/2007 - User's autoexec.sas must be contain the following
| statement for each SAS environment.  This will cause SAS to look for MACROS in
| Hercules macro library first.
|%ADD_TO_MACROS_PATH(NEW_MACRO_PATH=/PRG/sasXXXX1/hercules/macros,New_path_position=FRONT);
| where XXXX is the directory containing the code for that environment.
+--------------------------------------------------------------------------------
| HISTORY:  SEP, 2003 - J. Hou & Y. Vilk ORIGINAL
|           19MAR2004 - J.Chen - Commented out hard-coded %LET statement for 
|                       sysmode
|           AUG 2004 - resolving DOCUMENT_LOC_CD from table TPROGRAM_TASK instead of
|                       TCMCTN_PROGRAM
|           Hercules Version  2.0.1
|           09NOV2007 - Ron Smith / Greg Dudley 
|                       Modified to support ADT and QAT environments
|           07MAR2008 - N.WILLIAMS   - Hercules Version  2.0.01
|                                      1. Initial code migration into Dimensions
|                                         source safe control tool. 
|                                      2. Added references new program path.
|Hercules Version  2.1.01
| 22AUG2008 - G. Dudley 
|  1. Added the assignment of the macro variable DFL_CLT_INC_EXU_IN for new Client Setup
|  2. Added the assignment of the macro variable DSPLY_CLT_SETUP_CD for new Client Setup
|  3. Added assignment of Oracle Schema DSS_CLIN
| 21OCT2008 - SR
| 			-	Changed the assignment of macro variable ora_tmp from &user to dss_herc
|           - Hercules Version  2.1.2.01
|Hercules Version  2.1.3
| 15MAY2012 - P. Landis
|           - Modified to reference new hercdev2 server for testing procedures
+------------------------------------------------------------------------HEADER*/

*%include "/herc&sysmode./prg/hercules/macros/set_sysmode.sas" / nosource2;
/*options mprint mprintnest mlogic mlogicnest symbolgen source2;*/


%MACRO HERCULES_IN;
  
  %*SASDOC----------------------------------------------------------------------
  | Added GLOBAL variables for datasources.  Production variables will be set 
  | based on environment program is running in.
  | 09NOV2007 - RS.
  +---------------------------------------------------------------------SASDOC*;
   *CCW4 - CC_RE_MIGR_IND ADDED;
  *Q2X - CC_QL_MIGR_IND ADDED;

  %GLOBAL PROGRAM_ID        TASK_ID            	EXT_DRUG_LIST_IN
        DFLT_INCLSN_IN      DOCUMENT_LOC_CD    	PRT_CPNT_PARM_IN
        PRESCRIBER_PARM_IN  TRGT_RECIPIENT_CD  	DSPLY_CLT_SETUP_CD
        DRG_DEFINITION_CD   EMAIL_USR          	EMAIL_IT
        PRG_DIR             DATA_DIR           	RPT_DIR   LOG_DIR
        TITLE_TX            HERCULES           	INITIATIVE_ID
        DESTINATION_CD      FTP_HOST           	FTP_USER
        FTP_PASS            SYSMODE            	CLAIM_HIS_TBL
        TABLE_PREFIX        DB2_TMP            	LETTER_TYPE_QY_CD
        ADHOC_DIR           CLAIMSA            	OVRD_CLT_SETUP_IN
        DATA_CLEANSING_CD   CC_RE_MIGR_IND		CC_QL_MIGR_IND
	    UDBSPRP				UDBDWP				SUMMARY
		UDBSPRP_DB          USER_UDBSPRP	   	PASSWORD_UDBSPRP
		UDBDWP_DB			USER_UDBDWP		   	PASSWORD_UDBDWP
		QL_ADJ				RX_ADJ				RE_ADJ
		ORA_TMP				USER_EDW			PASSWORD_EDW
		GOLD				DFL_CLT_INC_EXU_IN  DSS_CLIN
		DSPLY_CLT_SETUP_CD  EDW_FTP_HOST EDW_FTP_USER EDW_FTP_PASS 
		DWHM DSS_HM GOLD_HA;

  *** Assign Claim History Table name ***;
  %LET CLAIM_HIS_TBL=TRXCLM_BASE;

  %*SASDOC----------------------------------------------------------------------
  | Determine the system mode based on the environment variable - $pwd
  | 09NOV2007 - RS - Note: set_sysmode now running from hercules lib in order
  | to support QAT environment
  +---------------------------------------------------------------------SASDOC*;
/*  %set_sysmode(mode=dev2);*/

  /*--------------------------------------------------------------------------------------------------*/
  /* PRODUCTION ENVIRONMENT                                                                           */
  /*--------------------------------------------------------------------------------------------------*/
  %IF &SYSMODE=prod %THEN %DO; /* 07MAR2008 - N.WILLIAMS */
  	/*---------------- setup schemas ----------------*/
	%LET HERCULES=HERCULES;
	%LET QCPAP020=QCPAP020; 
	%LET CLAIMSA=CLAIMSA;
	%LET CLAIMSP=CLAIMSP;
	%LET HERCULEP=HERCULEP;
 	%LET SUMMARY=SUMMARY;
  	
  	/*---------------- setup parametes for database LIBNAMES - Based on DATASOURCES */
 	/*---------------- ZEUS ----------------*/
	%LET UDBSPRP=&UDBSPRP;
	%LET UDBSPRP_DB=UDBSPRP;
	%LET USER_UDBSPRP=&USER_UDBSPRP;
	%LET PASSWORD_UDBSPRP=&PASSWORD_UDBSPRP;
	
  	/*---------------- CDW ----------------*/
	%LET UDBDWP=&UDBDWP;
	%LET UDBDWP_DB=UDBDWP;
	%LET USER_UDBDWP=&USER_UDBDWP;
	%LET PASSWORD_UDBDWP=&PASSWORD_UDBDWP;
	
  	/*---------------- EDW ----------------*/
	%LET DSS_CLIN=DSS_CLIN;
	%LET USER_EDW=&USER_GOLD;
	%LET PASSWORD_EDW=&PASSWORD_GOLD;
	%LET GOLD=GOLD user=&USER_EDW pw=&PASSWORD_EDW;
	%LET DSS_HM = DSS_HM;
	%LET DWHM = DWHM;
	
  	/*---------------- LIBNAME Definitions ----------------*/
	LIBNAME CLAIMSP  DB2 DSN=&UDBDWP  SCHEMA=&CLAIMSP  DEFER=YES;
	LIBNAME HERCULEP DB2 DSN=&UDBDWP  SCHEMA=&HERCULEP DEFER=YES;
	LIBNAME HERCULES DB2 DSN=&UDBSPRP SCHEMA=&HERCULES DEFER=YES;
	LIBNAME QCPAP020 DB2 DSN=&UDBSPRP SCHEMA=&QCPAP020 DEFER=YES;
	LIBNAME CLAIMSA  DB2 DSN=&UDBSPRP SCHEMA=&CLAIMSA  DEFER=YES;
	LIBNAME SUMMARY  DB2 DSN=&UDBSPRP SCHEMA=&SUMMARY  DEFER=YES;
	LIBNAME DSS_CLIN ORACLE SCHEMA=&DSS_CLIN PATH=&GOLD;
	
  	/*---------------- Health Alert Credentials ----------------*/	
	%LET GOLD_HA=GOLD %substr(&GOLD02., %index(&GOLD02., USER));	
	LIBNAME DSS_HM   ORACLE SCHEMA=&DSS_HM   PATH=&GOLD_HA DEFER=YES ;
	LIBNAME DWHM     ORACLE SCHEMA=&DWHM     PATH=&GOLD_HA DEFER=YES ;

  %END;
  /*--------------------------------------------------------------------------------------------------*/
  /* QAT ENVIRONMENT                                                                                  */
  /*--------------------------------------------------------------------------------------------------*/
  %IF &SYSMODE=sit3 %THEN %DO;
  	/*---------------- setup schemas ----------------*/
	%LET HERCULES=HERCULES;
	%LET QCPAP020=QCPAP020; 
	%LET CLAIMSA=CLAIMSA;
	%LET CLAIMSP=CLAIMSP;
	%LET HERCULEP=HERCULET; /* Test CDW */
	%LET SUMMARY=SUMMARY;
	
  	/*---------------- setup parametes for database LIBNAMES - Based on DATASOURCES */
  	/*---------------- ZEUS ----------------*/
	%LET UDBSPRP=&ANARPTQA;
	%LET UDBSPRP_DB=ANARPTQA;
	%LET USER_UDBSPRP=&USER_ANARPTQA;
	%LET PASSWORD_UDBSPRP=&PASSWORD_ANARPTQA;
	
  	/*---------------- CDW ----------------*/
	%LET UDBDWP=&UDBDWT;
	%LET UDBDWP_DB=UDBDWT;
	%LET USER_UDBDWP=&USER_UDBDWT;
	%LET PASSWORD_UDBDWP=&PASSWORD_UDBDWT;
	
  	/*---------------- EDW ----------------*/
	%LET DSS_CLIN=DSS_CLIN;
	%LET USER_EDW=&USER_GOLD;
	%LET PASSWORD_EDW=&PASSWORD_GOLD;
	%LET GOLD=GOLD user=&USER_EDW pw=&PASSWORD_EDW;
	%LET DSS_HM = DSS_HM;
	%LET DWHM = DWHM;
	
  	/*---------------- LIBNAME Definitions ----------------*/
	LIBNAME CLAIMSP  DB2 DSN=&UDBDWP  SCHEMA=&CLAIMSP  DEFER=YES;
	LIBNAME HERCULEP DB2 DSN=&UDBDWP  SCHEMA=&HERCULEP DEFER=YES;
	LIBNAME HERCULES DB2 DSN=&UDBSPRP SCHEMA=&HERCULES DEFER=YES;
	LIBNAME QCPAP020 DB2 DSN=&UDBSPRP SCHEMA=&QCPAP020 DEFER=YES;
	LIBNAME CLAIMSA  DB2 DSN=&UDBSPRP SCHEMA=&CLAIMSA  DEFER=YES;
	LIBNAME SUMMARY  DB2 DSN=&UDBSPRP SCHEMA=&SUMMARY  DEFER=YES;
	LIBNAME DSS_CLIN ORACLE SCHEMA=&DSS_CLIN PATH=&GOLD;
	
  	/*---------------- Health Alert Credentials ----------------*/	
	%let GOLD_HA=&OAK.;
	LIBNAME DSS_HM   ORACLE SCHEMA=&DSS_HM   PATH=&GOLD_HA DEFER=YES ;
	LIBNAME DWHM     ORACLE SCHEMA=&DWHM     PATH=&GOLD_HA DEFER=YES ;
  %END;
  /*--------------------------------------------------------------------------------------------------*/
  /* TEST ENVIRONMENT                                                                                 */
  /*--------------------------------------------------------------------------------------------------*/
  %IF &SYSMODE=dev2 or &SYSMODE=sit2  %THEN %DO;
  	/*---------------- setup schemas ----------------*/
	%LET HERCULES=HERCULES;
	%LET QCPAP020=QCPAP020; 
	%LET CLAIMSA=CLAIMSA;
	%LET CLAIMSP=CLAIMSP;
	%LET HERCULEP=HERCULEP;
 	%LET SUMMARY=SUMMARY;
  	
  	/*---------------- setup parametes for database LIBNAMES - Based on DATASOURCES */
 	/*---------------- ZEUS ----------------*/
/*	%LET UDBSPRP=&UDBSPRP;*/
/*	%LET UDBSPRP_DB=UDBSPRP;*/
	%LET UDBSPRP=&ANARPTAD;
	%LET UDBSPRP_DB=ANARPTAD;
	%LET USER_UDBSPRP=&USER_UDBSPRP;
	%LET PASSWORD_UDBSPRP=&PASSWORD_UDBSPRP;
	
  	/*---------------- CDW ----------------*/
	%LET UDBDWP=&UDBDWP;
	%LET UDBDWP_DB=UDBDWP;
	%LET USER_UDBDWP=&USER_UDBDWP;
	%LET PASSWORD_UDBDWP=&PASSWORD_UDBDWP;
	
  	/*---------------- EDW ----------------*/
	%LET DSS_CLIN=DSS_CLIN;
	%LET USER_EDW=&USER_GOLD;
	%LET PASSWORD_EDW=&PASSWORD_GOLD;
	/*	use GOLD=OAK to point to OAK test database*/
	/*	use GOLD=GRANITE to point to GRANITE test database*/
	%LET GOLD=GOLD user=&USER_EDW pw=&PASSWORD_EDW;
	%LET DSS_HM = DSS_HM;
	%LET DWHM = DWHM;
	
  	/*---------------- LIBNAME Definitions ----------------*/
	LIBNAME CLAIMSP  DB2 DSN=&UDBDWP  SCHEMA=&CLAIMSP  DEFER=YES;
	LIBNAME HERCULEP DB2 DSN=&UDBDWP  SCHEMA=&HERCULEP DEFER=YES;
	LIBNAME HERCULES DB2 DSN=&UDBSPRP SCHEMA=&HERCULES DEFER=YES;
	LIBNAME QCPAP020 DB2 DSN=&UDBSPRP SCHEMA=&QCPAP020 DEFER=YES;
	LIBNAME CLAIMSA  DB2 DSN=&UDBSPRP SCHEMA=&CLAIMSA  DEFER=YES;
	LIBNAME SUMMARY  DB2 DSN=&UDBSPRP SCHEMA=&SUMMARY  DEFER=YES;
	LIBNAME DSS_CLIN ORACLE SCHEMA=&DSS_CLIN PATH=&GOLD;
	
  	/*---------------- Health Alert Credentials ----------------*/	
	%LET GOLD_HA=GOLD %substr(&GOLD02., %index(&GOLD02., USER));	
	LIBNAME DSS_HM   ORACLE SCHEMA=&DSS_HM   PATH=&GOLD_HA DEFER=YES ;
	LIBNAME DWHM     ORACLE SCHEMA=&DWHM     PATH=&GOLD_HA DEFER=YES ;
  %END;

  
  %PUT NOTE: USER_EDW = &USER_EDW;
  %PUT NOTE: PASSWORD_EDW = &PASSWORD_EDW;
  %PUT NOTE: GOLD = &GOLD;
  %PUT NOTE: GOLD_HA = &GOLD_HA;

  LIBNAME AUX_TAB "/herc&sysmode/data/hercules/auxtables";
  LIBNAME ADM_LKP "/herc&sysmode/data/Admin/auxtable";


  %GETPARMS;

  %IF %LENGTH(&INITIATIVE_ID)=0 %THEN %DO;
    %PUT WARNING: INITIATIVE_ID IS NOT SUPPLIED.;
    %GOTO EXIT;
  %END;

  %*SASDOC----------------------------------------------------------------------
  | To start an initiative, an INITIATIVE_id will be given, the code needs to
  | resolve the associated PROGRAM_ID, TASK_ID, PHASE_SEQ_NB based on the setup
  | of TINITIATIVE and TINITIATIVE_PHASE tables.
  +---------------------------------------------------------------------SASDOC*;
  PROC SQL NOPRINT;
    CREATE   TABLE HERC_PARMS  AS
    SELECT   A.PROGRAM_ID,
             A.TASK_ID,
             '%nrbquote('||trim(left(A.TITLE_TX))||")" as title_tx,
             A.TRGT_RECIPIENT_CD,
             A.EXT_DRUG_LIST_IN,
             A.OVRD_CLT_SETUP_IN,
             B.DFLT_INCLSN_IN,
             C.DATA_CLEANSING_CD,
             C.DESTINATION_CD,
             D.DOCUMENT_LOC_CD,
             D.PRTCPNT_PARM_IN,
             D.PRESCRIBER_PARM_IN,
             D.DSPLY_CLT_SETUP_CD,
             D.DRG_DEFINITION_CD, 
             D.LETTER_TYPE_QY_CD,
			 D.DFL_CLT_INC_EXU_IN,
			 D.DSPLY_CLT_SETUP_CD

    FROM     &HERCULES..TINITIATIVE A,
             &CLAIMSA..TPROGRAM B,
             &HERCULES..TCMCTN_PROGRAM C,
             &HERCULES..TPROGRAM_TASK D

    WHERE    A.INITIATIVE_ID = &INITIATIVE_ID  AND
             A.PROGRAM_ID = B.PROGRAM_ID       AND
             A.PROGRAM_ID = C.PROGRAM_ID       AND
             A.PROGRAM_ID = D.PROGRAM_ID       AND
             A.TASK_ID = D.TASK_ID;

    SELECT COUNT(*) INTO :INIT_CNT
    FROM HERC_PARMS;
  QUIT;

  %IF &INIT_CNT=0 %THEN %DO;
    %put;
	%put;
    %PUT WARNING: INITIATIVE_ID &initiative_id CAN NOT BE RESOLVED FROM RELEVENT TABLES.;
    %PUT WARNING: Please correct the initiative_id or specify your own global setup.;
	%put;
	%put;
  %end;

  %IF &INIT_CNT=0 %THEN %GOTO EXIT;

  %LET TABLE_PREFIX=T_%CMPRES(&INITIATIVE_ID)_%CMPRES(&PHASE_SEQ_NB);

  DATA _NULL_;
    SET HERC_PARMS;
    CALL SYMPUT('PROGRAM_ID', COMPRESS(PUT(PROGRAM_ID, 4.)));
    CALL SYMPUT('TASK_ID', COMPRESS(PUT(TASK_ID, 4.)));
    CALL SYMPUT('TITLE_TX', TRIM(LEFT(TITLE_TX)));
    CALL SYMPUT('TRGT_RECIPIENT_CD', PUT(TRGT_RECIPIENT_CD,1.));
    CALL SYMPUT('EXT_DRUG_LIST_IN', PUT(EXT_DRUG_LIST_IN,1.));
    CALL SYMPUT('OVRD_CLT_SETUP_IN', PUT(OVRD_CLT_SETUP_IN,1.));
    CALL SYMPUT('DFLT_INCLSN_IN', PUT(DFLT_INCLSN_IN,1.));
    CALL SYMPUT('DESTINATION_CD', PUT(DESTINATION_CD,1.));
    CALL SYMPUT('DATA_CLEANSING_CD', PUT(DATA_CLEANSING_CD,1.));
    CALL SYMPUT('DOCUMENT_LOC_CD', COMPRESS(PUT(DOCUMENT_LOC_CD,4.)));
    CALL SYMPUT('PRTCPNT_PARM_IN', PUT(PRTCPNT_PARM_IN,1.));
    CALL SYMPUT('PRESCRIBER_PARM_IN', PUT(PRESCRIBER_PARM_IN,1.));
    CALL SYMPUT('DSPLY_CLT_SETUP_CD', PUT(DSPLY_CLT_SETUP_CD,1.));
    CALL SYMPUT('DRG_DEFINITION_CD', PUT(DRG_DEFINITION_CD,1.));
    CALL SYMPUT('LETTER_TYPE_QY_CD', PUT(LETTER_TYPE_QY_CD,1.));
  	CALL SYMPUT('DFL_CLT_INC_EXU_IN', PUT(DFL_CLT_INC_EXU_IN,1.));
  	CALL SYMPUT('DSPLY_CLT_SETUP_CD', PUT(DSPLY_CLT_SETUP_CD,1.));
  RUN;

  PROC TRANSPOSE DATA=HERC_PARMS(DROP=PROGRAM_ID TASK_ID)
                  OUT=TRNS_PARMS(DROP=_LABEL_)
                 NAME=CODE_NAME
               PREFIX=CODE;
  RUN;

  PROC SQL NOPRINT;
    CREATE TABLE CMCTN_CD_DECODE AS
    SELECT C.CODE_NAME, C.CODE1, LONG_TX AS ENGIN_DECODE
    FROM   (SELECT A.*, B.*
            FROM   &HERCULES..TCMCTN_ENGINE_CD A,
                   &HERCULES..TCODE_COLUMN_XREF B
            WHERE  A.CMCTN_ENGN_TYPE_CD=B.CMCTN_ENGN_TYPE_CD) AS AB
    RIGHT JOIN TRNS_PARMS C
    ON    AB.COLUMN_NM=C.CODE_NAME AND
          AB.CMCTN_ENGINE_CD=C.CODE1;
  QUIT;

  DATA _NULL_;
    SET CMCTN_CD_DECODE END=ENDFILE;
    IF ENGIN_DECODE= '' THEN DO;
      IF CODE1=1 THEN ENGIN_DECODE='APPLICABLE';
      ELSE IF CODE1=0 THEN ENGIN_DECODE='n/a';
    END;
    IF _N_=1 THEN DO;
      PUT "NOTE:";
      PUT @7 "PARAMETER SUMMARY FOR INITIATIVE &INITIATIVE_ID - &TITLE_TX (PROGRAM %cmpres(&PROGRAM_ID))";
      PUT @7 55*'_';
      PUT ' ';
      PUT @7 'CODE_NAME' @28 'CODE' @35 'ENGIN_DECODE';
      PUT @7 10*'-' @28 5*'-' @35 14*'-';
    END;
    PUT @7 CODE_NAME $20. @28 CODE1 3. @35 ENGIN_DECODE $35.;
    IF ENDFILE THEN DO;
      PUT @7 55*'_';
      PUT 'NOTE:';
      PUT ' ';
    END;
  RUN;

  proc sql;
      drop table CMCTN_CD_DECODE;
      drop table herc_parms;
      drop table trns_parms;
  quit;


  %*SASDOC----------------------------------------------------------------------
  | Define program level libname and fileref for data and file input/output.
  +----------------------------------------------------------------------SASDOC*;
  %IF %lowcase(&SYSMODE)=prod %THEN %DO;
  %LET DB2_TMP=TMP&PROGRAM_ID; /* 07MAR2008 - N.WILLIAMS */
/*	%LET ORA_TMP=&USER;*/
    %LET ORA_TMP=DSS_HERC; /** SR 21OCT2008 **/
  %END;
  %ELSE %DO;
	%LET DB2_TMP=TMP&PROGRAM_ID;
/*	%LET ORA_TMP=&USER;*/
    %LET ORA_TMP=DSS_HERC; /** SR 21OCT2008 **/
  %END;


  LIBNAME &DB2_TMP DB2 DSN=&UDBSPRP SCHEMA=&DB2_TMP DEFER=YES;
  LIBNAME &ORA_TMP ORACLE SCHEMA=&ORA_TMP PATH=&GOLD;
  %put *** folder assignments ***;
  %put *** folder assignments ***;
  %put *** folder assignments ***;
  %LET ADHOC_DIR=/herc&sysmode/adhoc/hercules;
  %LET PRG_DIR=/herc&sysmode/prg/hercules/%CMPRES(&PROGRAM_ID);  
  %LET DATA_DIR=/herc&sysmode/data/hercules/%CMPRES(&PROGRAM_ID);
  %LET RPT_DIR=/herc&sysmode/report_doc/hercules/%CMPRES(&PROGRAM_ID);
  %LET LOG_DIR=/herc&sysmode/data/hercules/%CMPRES(&PROGRAM_ID)/logs;

 %chk_dir(&ADHOC_DIR.);
 %chk_dir(&RPT_DIR.); 
 %chk_dir(&PRG_DIR.); 
 %chk_dir(&LOG_DIR.); 
 %chk_dir(&DATA_DIR./pending);
 %chk_dir(&DATA_DIR./results);
 %chk_dir(&DATA_DIR./archive);

  FILENAME PROG "&PRG_DIR.";
  FILENAME RPT "&RPT_DIR.";
  LIBNAME DATA_PND "&DATA_DIR/pending";
  LIBNAME DATA_RES "&DATA_DIR/results";
  LIBNAME DATA_ARC "&DATA_DIR/archive";
  %*SASDOC----------------------------------------------------------------------
  | Create general email receipient list.
  +----------------------------------------------------------------------SASDOC*;
  PROC SQL NOPRINT;
    %IF %LENGTH(&INITIATIVE_ID)>0 %THEN %DO;
      SELECT HSU_USR_ID INTO: HSU_USR_ID
        FROM &HERCULES..TINITIATIVE_PHASE
       WHERE INITIATIVE_ID=(&INITIATIVE_ID);

      SELECT QUOTE(TRIM(EMAIL)) INTO :EMAIL_USR SEPARATED BY ' '
        FROM ADM_LKP.ANALYTICS_USERS
       WHERE UPCASE(QCP_ID) IN ("%UPCASE(&HSU_USR_ID)");
    %END;
    %ELSE %PUT %NRSTR(WARNING: &HSU_USR_ID and &EMAIL_USR cannot be resolved without an INITIATIVE_ID.);

    SELECT QUOTE(TRIM(EMAIL)) INTO :EMAIL_IT SEPARATED BY ' '
      FROM ADM_LKP.ANALYTICS_USERS
     WHERE UPCASE(QCP_ID) = "&USER";
    QUIT;


  %*SASDOC----------------------------------------------------------------------
  | define file output FTP destinations
  +----------------------------------------------------------------------SASDOC*;
  DATA _NULL_;
    SET AUX_TAB.SET_FTP(WHERE=(DESTINATION_CD=&DESTINATION_CD));
    CALL SYMPUT('FTP_HOST', TRIM(LEFT(FTP_HOST)) );
    CALL SYMPUT('FTP_USER', TRIM(LEFT(FTP_USER)) );
    CALL SYMPUT('FTP_PASS', TRIM(LEFT(FTP_PASS)) );
  RUN;
  
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

  %*SASDOC----------------------------------------------------------------------
  | definition of Health Alert credentials
  +----------------------------------------------------------------------SASDOC*;
  %put NOTE: GOLD_HA = &GOLD_HA. ;    
  
PROC SQL NOPRINT;
  CREATE TABLE PLATFORMS AS 
  SELECT ADJ_ENGINE_CD
    FROM &HERCULES..TINIT_ADJUD_ENGINE
   WHERE INITIATIVE_ID=&INITIATIVE_ID;
QUIT;

PROC SORT DATA = PLATFORMS;BY ADJ_ENGINE_CD;
RUN;

%LET ADJ_ENGINE_CD1 = 0;
%LET ADJ_ENGINE_CD2 = 0;
%LET ADJ_ENGINE_CD3 = 0;

DATA _NULL_;
 SET PLATFORMS END = EOF;
  BY ADJ_ENGINE_CD;
  IF FIRST.ADJ_ENGINE_CD THEN DO;
  FLAG+1;
  CALL SYMPUT('ADJ_ENGINE_CD'||PUT(ADJ_ENGINE_CD,8. -L),ADJ_ENGINE_CD);
  END;
  IF EOF THEN CALL SYMPUT('TOT',PUT(ADJ_ENGINE_CD,8. -L));
RUN;

  %IF &ADJ_ENGINE_CD1 EQ 1 %THEN %LET QL_ADJ = 1; %ELSE %LET QL_ADJ = 0;
    %IF &ADJ_ENGINE_CD2 EQ 2 %THEN %LET RX_ADJ = 1 ; %ELSE %LET RX_ADJ = 0;
		%IF &ADJ_ENGINE_CD3 EQ 3 %THEN %LET RE_ADJ = 1 ; %ELSE %LET RE_ADJ = 0;

%PUT NOTE:	QL_ADJ = &QL_ADJ;
%PUT NOTE:	RX_ADJ = &RX_ADJ;
%PUT NOTE:	RE_ADJ = &RE_ADJ;

%PUT NOTE:	ADJ_ENGINE_CD1 = &ADJ_ENGINE_CD1;
%PUT NOTE:	ADJ_ENGINE_CD2 = &ADJ_ENGINE_CD2;
%PUT NOTE:	ADJ_ENGINE_CD3 = &ADJ_ENGINE_CD3;

  %EXIT:;

%MEND HERCULES_IN;

%HERCULES_IN;

