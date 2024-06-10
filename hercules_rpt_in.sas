*SASDOC------------------------------------------------------------------------
| PROGRAM:  hercules_rpt_in.sas
|
| LOCATION: /PRG/sas%lowcase(&SYSMODE)1/hercules/reports
|
| PURPOSE:  To define a standard environment and common parameters for Hercules
|           report programs.
|
|           Including:
|           1) setup SYSMODE and resolve SYSPARMS
|
|           2) Global Macro variables:
|            claimsa
|            CLAIM_HIS_TBL
|            db2_tmp
|            request_id
|            program_id
|            REPORT_ID
|            REQUIRED_PARMTR_ID
|            SEC_REQD_PARMTR_ID
|            REQUIRED_PARMTR_NM
|            SEC_REQD_PARMTR_NM
|            DELIVERY_METHOD -
|            SAS_PROGRAM_TX - exact SAS program name that produce the report
|            RPT_DISPLAY_NM - name, usually in title, to be displayed on the report
|            rpt_file_nm    - name of the report file. For easy tracking it uses the same name
|                             as the name of the SAS program plus report_id and request_id.
|            ops_subdir     - subfolder name for clinical OPS, derived from SHORT_TX, TPROGRAM
|            HSC_USR_ID
|            EMAIL_USR_rpt
|            java_call
|
|            _PROGRAM_ID      <===
|            _INITIATIVE_ID      ||
|            phase_seq_nb       ||
|            FORMULARY_ID       || Available only when applicable
|            CLIENT_ID          ||
|            BEGIN_DT           ||
|            END_DT          <===
|
|           3) Fileref associated with report output.
|              RPTFL  the RPTFL will be predefined
|                   - in the hercules_rpt_in when the report is to be generated batch.
|                   - or by Java when report is to be sent to screen.
|              ftp_pdf - fileref for creating PDF file on the Clinical OPS directory
|              ftp_txt -  ------------------- TXT ----------------------------------
|
| INPUT:    sysparm: request_id
|           &HERCULES..TREPORT
|           &HERCULES..TREPORT_REQUEST
|           &HERCULES..TCMCTN_ENGINE_CD
|           &HERCULES..TREPORT_RQST_PARM
|           &HERCULES..TPARAMETER
|
| OUTPUT:   HERCULES report global macro parameters and setup the environment.
+------------------------------------------------------------------------------
| HISTORY:  May-2004  J.Hou  - Original
|           27JUL2010 P. Landis - updated libnames for hercdev2 testing
+-----------------------------------------------------------------------SASDOC*;

*OPTIONS SYSPARM='request_id=1';

DATA REQUIRED_PARMS;
     FORMAT  REPORT_LEVEL_CD 2. REQUIRED_PARMTR_NM SEC_REQD_PARMTR_NM $15.;
     INPUT @1 REPORT_LEVEL_CD @3 REQUIRED_PARMTR_NM $ @17 SEC_REQD_PARMTR_NM  $ ;
     CARDS;
1 CLIENT_ID    NA 
2 PROGRAM_ID   NA 
3 INITIATIVE_ID PHASE_SEQ_NB
5 PROGRAM_ID    TASK_ID
;
RUN;


%macro hercules_rpt_in;

 %global    claimsa
            CLAIM_HIS_TBL
            db2_tmp
            request_id
            program_id
            _program_id
            REPORT_ID
            HCE_RPT
            REQUIRED_PARMTR_ID
            SEC_REQD_PARMTR_ID
            REQUIRED_PARMTR_NM
            SEC_REQD_PARMTR_NM
            DELIVERY_METHOD
            SAS_PROGRAM_TX
            RPT_DISPLAY_NM
            HSC_USR_ID
            EMAIL_USR_rpt
            ops_subdir
            rpt_file_nm
            java_call
            _INITIATIVE_ID
            phase_seq_nb
            FORMULARY_ID
            CLIENT_ID
            BEGIN_DT
            END_DT;

%GETPARMS;

 LIBNAME &HERCULES DB2 DSN=&UDBSPRP SCHEMA=&HERCULES DEFER=YES;
 %LET CLAIMSA=CLAIMSA;
 %LET CLAIM_HIS_TBL=TRXCLM_BASE;

 %ADD_TO_MACROS_PATH(NEW_MACRO_PATH=/herc&sysmode/prg/hercules/macros);

 LIBNAME &CLAIMSA DB2 DSN=&UDBSPRP SCHEMA=&CLAIMSA DEFER=YES;
  LIBNAME AUX_TAB "/herc&sysmode/data/hercules/auxtables";
  LIBNAME ADM_LKP "/herc&sysmode/data/Admin/auxtable";

 %IF %lowcase(&SYSMODE)=prod %THEN %DO;
      %LET HCE_RPT=HCERPTP;
      %LET DB2_TMP=&user;
     %end;
  %ELSE %if %lowcase(&SYSMODE)=sit2 %then %DO;
       %LET HCE_RPT=HCERPTT;
       %LET DB2_TMP=&USER; %END;
   %ELSE %DO;
        %LET HCE_RPT=&USER;
        %LET DB2_TMP=&USER; %END;

    LIBNAME &DB2_TMP DB2 DSN=&UDBSPRP SCHEMA=&DB2_TMP DEFER=YES;

    LIBNAME &HCE_RPT DB2 DSN=&UDBSPRP SCHEMA=&HCE_RPT DEFER=YES;


*SASDOC------------------------------------------------------------------------
| RESOLVE REPORTING PARAMETERS BASED ON REQUEST: REQUEST_ID, REPORT_ID
+----------------------------------------------------------------------SASDOC*;

PROC SQL NOPRINT;
    CREATE TABLE PARMS1 AS
     SELECT A.REPORT_ID,
            A.REPORT_LEVEL_CD,
            REQUIRED_PARMTR_ID,
            SEC_REQD_PARMTR_ID,
            REQUIRED_PARMTR_NM,
            SEC_REQD_PARMTR_NM,
            D.SHORT_TX AS DELIVERY_METHOD,
            A.SAS_PROGRAM_TX,
            A.RPT_DISPLAY_NM,
            C.HSC_USR_ID
    FROM &HERCULES..TREPORT A, REQUIRED_PARMS B,
         &HERCULES..TREPORT_REQUEST C,
         &HERCULES..TCMCTN_ENGINE_CD D
   WHERE A.REPORT_LEVEL_CD=B.REPORT_LEVEL_CD
     AND A.REPORT_LEVEL_CD=D.CMCTN_ENGINE_CD
     AND D.CMCTN_ENGN_TYPE_CD=28 /* DELIVERY METHOD */
     AND A.REPORT_ID=C.REPORT_ID
     and C.REQUEST_ID=&REQUEST_ID;
   QUIT;


      DATA _NULL;
           SET  PARMS1;
           ID=INDEXC(REVERSE(TRIM(LEFT(SAS_PROGRAM_TX))), '/');
           CALL SYMPUT('REPORT_ID', trim(left(PUT(REPORT_ID,3.))));
           CALL SYMPUT('REPORT_LEVEL_CD', PUT(REPORT_LEVEL_CD,1.));
           CALL SYMPUT('REQUIRED_PARMTR_ID', trim(left(PUT(REQUIRED_PARMTR_ID,8.))));
           CALL SYMPUT('SEC_REQD_PARMTR_ID', trim(left(PUT(SEC_REQD_PARMTR_ID,8.))));
           CALL SYMPUT('REQUIRED_PARMTR_NM', trim(left(REQUIRED_PARMTR_NM)));
           CALL SYMPUT('SEC_REQD_PARMTR_NM', trim(left(SEC_REQD_PARMTR_NM)));
           CALL SYMPUT('DELIVERY_METHOD',  trim(left(DELIVERY_METHOD)));
           CALL SYMPUT('SAS_PROGRAM_TX',  trim(left(SAS_PROGRAM_TX)));

          if id>0 then CALL SYMPUT('RPT_NM', REVERSE(SUBSTR(REVERSE(TRIM(LEFT(SAS_PROGRAM_TX))),5,
                                 (INDEXC(REVERSE(TRIM(LEFT(SAS_PROGRAM_TX))), '/')-5))));
            else CALL SYMPUT('RPT_NM', trim(left(tranwrd(SAS_PROGRAM_TX,'.sas', ''))));
           CALL SYMPUT('RPT_DISPLAY_NM',  trim(left(RPT_DISPLAY_NM)));
           CALL SYMPUT('HSC_USR_ID',  trim(left(HSC_USR_ID)));
          RUN;


%PUT &RPT_NM;

proc sql noprint;
     select count(*) into: adtnl_cnt
     from &HERCULES..TREPORT_RQST_PARM A, &HERCULES..TPARAMETER B
      WHERE A.PARAMETER_ID=B.PARAMETER_ID
        AND A.REQUEST_ID=&REQUEST_ID;
    QUIT;

*SASDOC----------------------------------------------------------------------------
| assign values for additional macro variables applicable only to a specific request
+-------------------------------------------------------------------------- SASDOC*;

%if &adtnl_cnt>0 %then %do;

PROC SQL NOPRINT;
     CREATE TABLE PARM_ADDNL AS
     SELECT A.PARAMETER_ID, B.SAS_MACRO_VAR_NM, A.VALUE_REF_TX
       FROM &HERCULES..TREPORT_RQST_PARM A, &HERCULES..TPARAMETER B
      WHERE A.PARAMETER_ID=B.PARAMETER_ID
        AND A.REQUEST_ID=&REQUEST_ID;
    QUIT;

DATA _NULL2;
     SET PARM_ADDNL;
     IF indexc(SAS_MACRO_VAR_NM, '_DT') >0 THEN 
         CALL SYMPUT(SAS_MACRO_VAR_NM, "'"||TRIM(LEFT(VALUE_REF_TX))||"'" );
     ELSE CALL SYMPUT(SAS_MACRO_VAR_NM, TRIM(LEFT(VALUE_REF_TX)));
     RUN;
%end;

*SASDOC----------------------------------------------------------------------------
| combine program name, request_id and report_id as the file name rpt_file_nm for
| the report to be generated.
+-------------------------------------------------------------------------- SASDOC*;

%LET rpt_file_nm=&rpt_nm._&request_id._&report_id;

%LET ops_subdir=GENERAL_REPORTS;

%IF &REPORT_LEVEL_CD=2 OR &REPORT_LEVEL_CD=5  %THEN
    %STR(DATA _NULL_;
         SET &HERCULES..TREPORT_PROGRAM(WHERE=(REPORT_ID=&REPORT_ID and PROGRAM_ID=&REQUIRED_PARMTR_ID.));
         CALL SYMPUT('_PROGRAM_ID', trim(left(PUT(PROGRAM_ID,4.))));
         RUN;

	data _null_;
  	   set &claimsa..tprogram(where=(program_id=&_program_id));
  	   call symput('ops_subdir',  translate(trim(left(short_tx)),'_',' /&'));

	RUN;
	);

%IF &REPORT_LEVEL_CD=3 %THEN
    %STR(DATA _NULL_;
         SET &HERCULES..TINITIATIVE(WHERE=(&REQUIRED_PARMTR_NM = &REQUIRED_PARMTR_ID.));
         CALL SYMPUT('_PROGRAM_ID', trim(left(PUT(PROGRAM_ID,4.))));
         RUN;

	data _null_;
  	   set &claimsa..tprogram(where=(program_id=&_program_id));
   	  call symput('ops_subdir',  translate(trim(left(short_tx)),'_',' /&'));

	RUN;
	);

    

 DATA _NULL_;
      SET REQUIRED_PARMS(WHERE=(REPORT_LEVEL_CD=&REPORT_LEVEL_CD));
      IF REPORT_LEVEL_CD IN (1,4) then do;
          CALL SYMPUT('RPTFL', "/herc&sysmode/hercules/general/&RPT_FILE_NM..pdf");
             CALL SYMPUT('RPT_txt', "/herc&sysmode/hercules/general/&RPT_FILE_NM..txt");
        END;

      IF REPORT_LEVEL_CD IN (2,3,5) THEN DO;
         CALL SYMPUT('RPTFL', "/herc&sysmode/hercules/&_PROGRAM_ID./&RPT_FILE_NM..pdf");
         CALL SYMPUT('RPT_txt', "/herc&sysmode/hercules/&_PROGRAM_ID./&RPT_FILE_NM..txt");
         END;
     RUN;

*SASDOC----------------------------------------------------------------------------
|
| when applicable, resolve short_tx corresponding to the PROGRAM_ID as the
| changing portion of the folder name for the Clinical OPS Server (sfb006)
|
+-------------------------------------------------------------------------- SASDOC*;



 %IF &JAVA_CALL = %STR() %THEN %DO;
     %if &_program_id>0 %then %do;
     filename ftp_pdf ftp "/users/patientlist/&ops_subdir/Reports/&RPT_FILE_NM..pdf" 
           mach='sfb006.psd.caremark.int' RECFM=s ;
     filename ftp_txt ftp "/users/patientlist/&ops_subdir/Reports/&RPT_FILE_NM..txt" 
           mach='sfb006.psd.caremark.int' RECFM=v ;
     %end;
  %else %do;
      filename ftp_pdf ftp "/users/patientlist/GENERAL_REPORTS/&RPT_FILE_NM..pdf" 
           mach='sfb006.psd.caremark.int' RECFM=s ;
      filename ftp_txt ftp "/users/patientlist/GENERAL_REPORTS/&RPT_FILE_NM..txt" 
           mach='sfb006.psd.caremark.int' RECFM=v ;

     %end;
     
     filename RPTFL "&RPTFL"; /** create file in PDF format **/
     filename RPT_txt "&RPT_txt"; /** create file in Pipe dilimited TXT format **/
 %END;

PROC SQL NOPRINT;
     SELECT QUOTE(TRIM(EMAIL)) INTO :EMAIL_USR_rpt
       FROM   ADM_LKP.ANALYTICS_USERS
       WHERE  UPCASE(QCP_ID) IN ("%UPCASE(&HSC_USR_ID)");
     QUIT;

 %PUT --------------------------------------;
 %put LIST OF HERCULES REPORT GLOBOL MACROS:;
 %PUT --------------------------------------;
 %PUT -  REQUEST_ID=&REQUEST_ID..;
 %PUT -  REPORT_ID=&REPORT_ID..;
 %if &REQUIRED_PARMTR_nm. ne %then %PUT -  REQUIRED_PARMTR_NM = &REQUIRED_PARMTR_NM..;
 %if &SEC_REQD_PARMTR_nm. ne %then %PUT -  SEC_REQD_PARMTR_NM = &SEC_REQD_PARMTR_NM..;
 %if &REQUIRED_PARMTR_ID. ne %then %PUT -  REQUIRED_PARMTR_ID = &REQUIRED_PARMTR_ID..;
 %if &SEC_REQD_PARMTR_ID. ne %then %PUT -  SEC_REQD_PARMTR_ID = &SEC_REQD_PARMTR_ID..;
 %PUT -  DELIVERY_METHOD = &DELIVERY_METHOD..;
 %PUT -  SAS_PROGRAM_TX = &SAS_PROGRAM_TX..;
 %PUT -  RPT_DISPLAY_NM = &RPT_DISPLAY_NM..;
 %PUT -  REQUESTOR EMAIL = &EMAIL_USR_rpt..;
 %PUT -  RPT_FILE_NM = &RPT_FILE_NM..;
 %if &_program_id ne %then %PUT -  PROGRAM_ID = &_program_id..;
 %if &_initiative_id ne %then %PUT -  INITIATIVE_ID = &_initiative_id..;
 %if &formulary_id ne %then %PUT -  FORMULARY_ID = &formulary_id..;
 %if &client_id ne %then %PUT -  CLIENT_ID = &client_id..;
 %if &BEGIN_DT ne %then %PUT -  BEGIN_DT = &BEGIN_DT..;
 %if &END_DT ne %then %PUT -  END_DT   = &END_DT..;



%mend hercules_rpt_in;
%hercules_rpt_in;
