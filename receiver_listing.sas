/* HEADER ------------------------------------------------------------------------------
 |
 | PROGRAM:    RCVR_LISTing.SAS
 |
 | LOCATION:   /&PRG_dir.
 |
 | PURPOSE:    Generate a listing file that provides the nems/addresses of receivers with
 |             given initiative_id|program_id|client_id|date_range.
 |
 |             Note: if the receiver is a participant the cardholder external id is included
 |                   if the receiver is a prescriber the DEA is provided
 |
 | INPUT:     request_id, date range
 |            when report_id:
 |                    15  requires initiative_id
 |                     3           program_id and/or client_id, date range
 |                     2           client_id, date range and/or initiative_id
 |
 | OUTPUT      List of receiver file will be delivered by Email/Network
 |
 | CREATED:    June. 2004, John Hou
 |
 |           07MAR2008 - N.WILLIAMS   - Hercules Version  2.0.01
 |                                      1. Initial code migration into Dimensions
 |                                         source safe control tool. 
 |                                      2. Added references new program path.
 |Hercules Version 2.1.01
 |22AUG2008 - Sudha Y. - Modified report to run for all three adjudications
 |					   - Hercules Version  2.1.2.01
 |03JLY2012 - P.Landis - added nosource2 options to %include macros
+ -------------------------------------------------------------------------------HEADER*/
%LET err_fl=0;

/*options sysparm='request_id=101145' MPRINT MLOGIC SYMBOLGEN;*/

/*%set_sysmode(mode=sit2);*/
/*OPTIONS SYSPARM='initiative_id=8442 phase_seq_nb=1';*/
 %include "/herc&sysmode/prg/hercules/hercules_in.sas" / nosource2;

%MACRO MAXIM_ID;
%global max_id;
  PROC SQL;
  	 SELECT MAX(REQUEST_ID) INTO :MAX_ID
  	 FROM HERCULES.TREPORT_REQUEST;
  QUIT;
  %PUT NOTE: &MAX_ID;
%MEND MAXIM_ID;

%MAXIM_ID;
%let request_id=&MAX_ID;

*SASDOC -----------------------------------------------------------------------------
| Generate client_initiative_summary report
+ ----------------------------------------------------------------------------SASDOC*;
%let JAVA_CALL=0;
%PUT NOTE: JAVA_CALL = &JAVA_CALL;


PROC SQL;
	INSERT INTO HERCULES.TREPORT_REQUEST
	(REQUEST_ID, REPORT_ID, REQUIRED_PARMTR_ID, SEC_REQD_PARMTR_ID, JOB_REQUESTED_TS,
	 JOB_START_TS, JOB_COMPLETE_TS, HSC_USR_ID , HSC_TS , HSU_USR_ID , HSU_TS )

	VALUES
	(%EVAL(&MAX_ID+1), 11, &INITIATIVE_ID., &PHASE_SEQ_NB., %SYSFUNC(DATETIME()), %SYSFUNC(DATETIME()), 
	 NULL, 'QCPAP020' , %SYSFUNC(DATETIME()), 'QCPAP020', %SYSFUNC(DATETIME()));
QUIT;

%include "/herc&sysmode/prg/hercules/reports/hercules_rpt_in.sas" / nosource2;
%let rpt_nm=receiver_listing;
%LET rpt_file_nm=&rpt_nm._&request_id._&report_id;

OPTIONS MPRINT MPRINTNEST MLOGIC MLOGICNEST SYMBOLGEN SOURCE2;
PROC SQL NOPRINT;
  SELECT QUOTE(TRIM(email)) INTO :Primary_programmer_email
  FROM ADM_LKP.ANALYTICS_USERS
  WHERE UPCASE(QCP_ID) IN ("&USER");
QUIT;

 %let _&REQUIRED_PARMTR_nm.=&REQUIRED_PARMTR_id;
 %let _&SEC_REQD_PARMTR_NM.=&SEC_REQD_PARMTR_id;

** SASDOC ----------------------------------------------------------------------------
 | DOCUMENTATION PURPOSES: DISPLAYS THE PARAMETERS REQUIRED FOR THE REPORT BASED ON 
 | THE REQUEST_ID.
 + --------------------------------------------------------------------------SASDOC*;

 %put _&REQUIRED_PARMTR_nm.=&REQUIRED_PARMTR_id;
 %put _&SEC_REQD_PARMTR_NM.=&SEC_REQD_PARMTR_id;
 %put &ops_subdir;

 %update_request_ts(start);

%macro rcvr_listing;

	%local initiative_where client_where program_where cmctn_role_cnt;
 	%global program_id _client_id;

** SASDOC ----------------------------------------------------------------------------
 | CLEARS THE WORK DATASET.
 + --------------------------------------------------------------------------SASDOC*;

	/*PROC DATASETS LIB = WORK NOLIST KILL; RUN;*/
  

** SASDOC -------------------------------------------------------------------------
 | setup conditional strings based on the availability of initiative_id, client_id, 
 | program_id.
 + --------------------------------------------------------------------------SASDOC*;
 %put &_INITIATIVE_ID;

 %IF &_INITIATIVE_ID>0  %then %do;
   %let PROGRAM_dir=;

 	PROC SQL NOPRINT;
    SELECT   A.PROGRAM_ID INTO: PROGRAM_dir

    FROM     &HERCULES..TINITIATIVE A,
             &CLAIMSA..TPROGRAM B,
             &HERCULES..TCMCTN_PROGRAM C,
             &HERCULES..TPROGRAM_TASK D,
             &HERCULES..TPHASE_RVR_FILE E

    WHERE    A.INITIATIVE_ID = &_INITIATIVE_ID  AND
             A.PROGRAM_ID = B.PROGRAM_ID       AND
             A.PROGRAM_ID = C.PROGRAM_ID       AND
             A.PROGRAM_ID = D.PROGRAM_ID       AND
             A.TASK_ID = D.TASK_ID             AND
             A.INITIATIVE_ID=E.INITIATIVE_ID   AND

             E.ARCHIVE_STS_CD =0               AND
             E.FILE_USAGE_CD=1                 AND
             E.RELEASE_STATUS_CD=2;
  	QUIT;

	%PUT INITIATIVE_ID: &_INITIATIVE_ID;
 
	%if &program_dir ne %then %do;

/*	LIBNAME DATA_PND "/data/sas&sysmode.1/hercules/%cmpres(&program_dir)/pending"; */
/*	commented for testing purpose - Sandeep*/
	LIBNAME DATA_PND "/herc&sysmode/data/hercules/%cmpres(&program_dir)/pending"; 


	%end;
	%let table_prefix=t_%cmpres(&_initiative_id)_1;

    %let initiative_where=%str(and a.initiative_id=&_initiative_id);

 %end;

 %else %let _initiative_id=;

	%if &_client_id>0  %then %do;
	    %let client_where =%str(and client_id=&_client_id);
    	%let client_id=&_client_id;
		%put CLIENT_ID: &_client_id;
 	%end;

	%if &_program_id>0  %then %do;
       %let program_where =%str(and program_id=&_program_id);
	   %put PROGRAM_ID: &_program_id;	
 	%end;


/** when initiative_id is not supplied bypass the initiative based report codes **/

%if &_initiative_id = %then %goto report_23;

 ** SASDOC -----------------------------------------------------------------
  |
  |  PART I: &INITIATIVE_ID is known
  |
  + ------------------------------------------------------------------SASDOC*;

** SASDOC ------------------------------------------------------------------
  | Two types of receivers, PRESCRIBER or BENEFICIARY are to be recognized,
  | The type of receiver will determine the route of queries that the list
  | to be constructed.
  |
  | when the receipient is not a prescriber (cmctn_role_cd ne 2), get address
  | and ss#(CDH external id) at the beneficiary level.
  |
  +--------------------------------------------------------------------SASDOC*;

  	proc sql noprint;
          select count(*) into: c_role_cnt
          from &hercules..tphase_rvr_file
          where initiative_id=&_initiative_id; 
	quit;

  	data _null;
      set &hercules..tphase_rvr_file(where=( initiative_id=&_initiative_id));
      call symput('cmctn_role_cd'||put(_n_,1.),put(cmctn_role_cd,1.));
      call symput('ARCHIVE_STS_CD'||put(_n_,1.),put(ARCHIVE_STS_CD,1.));
    run;


%do i=1 %to &c_role_cnt;

%put &table_prefix._&&cmctn_role_cd&i;

%let _PROGRAM_ID = %TRIM(&_PROGRAM_ID);
%put NOTE: PROGRAM_ID= &_PROGRAM_ID;

%if &&ARCHIVE_STS_CD&i = 0 %then %do;

/*LIBNAME DATA_PND "/DATA/sas&sysmode.1/hercules/%cmpres(&_program_id)/pending";*/
LIBNAME DATA_PND "/herc&sysmode/data/hercules/%cmpres(&_program_id)/pending";


  ** SASDOC -----------------------------------------------------------------
   | when the receipient is not a prescriber (cmctn_role_cd ne 2), get address
   | and ss#(CDH external id) at the beneficiary level.
   | 07MAR2008 - N.WILLIAMS - Adjust bulkload.
   +--------------------------------------------------------------------SASDOC*;

%if %sysfunc(exist(DATA_PND.&table_prefix._&&cmctn_role_cd&i)) >0 %then %do;
    %if &&cmctn_role_cd&i ne 2 %then %do;

 		PROC SORT DATA=DATA_PND.&table_prefix._&&cmctn_role_cd&i (KEEP=RECIPIENT_ID)
          OUT=&table_prefix._&&cmctn_role_cd&i NODUPKEY;
          by recipient_id; QUIT;

      %DROP_DB2_TABLE(TBL_NAME=&db2_tmp..&table_prefix.PT_LIST_&_program_id);

      data &db2_tmp..&table_prefix.PT_LIST_&_program_id (BULKLOAD=YES);
          SET &table_prefix._&&cmctn_role_cd&i;
      RUN;
/*YM:NOV19,2012: ADDED MBR_ID AS PER PROACTIVE REFILL ITPR003487*/
     PROC SQL noprint;
         CONNECT TO DB2 (DSN=&UDBSPRP);
        CREATE TABLE _RCVR_LIST AS
        SELECT * FROM CONNECTION TO DB2
            (SELECT    A.RECIPIENT_ID,
                               B.PT_EXTERNAL_ID,
                               B.CDH_EXTERNAL_ID,
							   B.BENEFICIARY_ID AS MBR_ID

                FROM             &db2_tmp..&table_prefix.PT_LIST_&_program_id A,
                                 &CLAIMSA..TBENEF_BENEFICIAR1 B
                WHERE           A.RECIPIENT_ID = B.BENEFICIARY_ID
                            	&client_where  );
                DISCONNECT FROM DB2;
          QUIT;
/*YM:NOV19,2012: ADDED MBR_ID AS PER PROACTIVE REFILL ITPR003487*/
   	  PROC SQL noprint;
        CREATE TABLE RCVR_LIST_QL AS
            SELECT             A.ADJ_ENGINE AS ADJUDICATION,
							   A.RECIPIENT_ID,
							   A.APN_CMCTN_ID,
                 B.PT_EXTERNAL_ID,
                 'Beneficiary' as RECIPIENT_TYPE,
                 A.RVR_LAST_NM AS LAST_NAME,
                 A.RVR_FIRST_NM AS FIRST_NAME,
                 A.ADDRESS1_TX,
                 A.ADDRESS2_TX,
                 A.STATE AS STATE_CD,
                 A.CITY_TX,
                 A.ZIP_CD,
							   &_initiative_id AS INITIATIVE_ID,
                 B.CDH_EXTERNAL_ID,
                 CLIENT_ID,
                 BLG_REPORTING_CD AS CLIENT_LEVEL_1,
		             PLAN_CD AS CLIENT_LEVEL_2,
		             GROUP_CD AS CLIENT_LEVEL_3,
                 B.MBR_ID

                FROM            DATA_PND.&table_prefix._&&cmctn_role_cd&i A,
                                 _RCVR_LIST B
                WHERE           A.RECIPIENT_ID = B.RECIPIENT_ID
                	AND A.DATA_QUALITY_CD in (1,2)
                  AND ADJ_ENGINE='QL'
                             ;
       QUIT;
   	  PROC SQL noprint;
        CREATE TABLE RCVR_LIST_EDW AS
            SELECT             A.ADJ_ENGINE AS ADJUDICATION,
							   A.RECIPIENT_ID,
							   A.APN_CMCTN_ID,
                 B.PT_EXTERNAL_ID,
                 'Beneficiary' as RECIPIENT_TYPE,
                 A.RVR_LAST_NM AS LAST_NAME,
                 A.RVR_FIRST_NM AS FIRST_NAME,
                 A.ADDRESS1_TX,
                 A.ADDRESS2_TX,
                 A.STATE AS STATE_CD,
                 A.CITY_TX,
                 A.ZIP_CD,
							   &_initiative_id AS INITIATIVE_ID,
                 B.CDH_EXTERNAL_ID,
                 CLIENT_ID,
                 CLIENT_LEVEL_1,
		             CLIENT_LEVEL_2,
		             CLIENT_LEVEL_3,
                 B.MBR_ID

                FROM            DATA_PND.&table_prefix._&&cmctn_role_cd&i A,
                                 _RCVR_LIST B
                WHERE           A.RECIPIENT_ID = B.RECIPIENT_ID
                	AND A.DATA_QUALITY_CD in (1,2)
                  AND ADJ_ENGINE IN ('RX','RE')
                             ;
       QUIT;

       data RCVR_LIST;
         set RCVR_LIST_QL RCVR_LIST_EDW;
       run;

	   %DROP_DB2_TABLE(TBL_NAME = &db2_tmp..&table_prefix.PT_LIST_&_program_id); 

    %END;

    %ELSE %DO;
/*YM:NOV19,2012: ADDED MBR_ID AS PER PROACTIVE REFILL ITPR003487*/
       PROC SQL noprint;
        CREATE TABLE RCVR_LIST2 AS
            SELECT   distinct           A.ADJ_ENGINE AS ADJUDICATION,
										A.RECIPIENT_ID,
										A.APN_CMCTN_ID,
                                        'Prescriber' as RECIPIENT_TYPE,
										B.PRCBR_LAST_NAME AS LAST_NAME,
                                        B.PRCBR_FIRST_NM AS FIRST_NAME,
                                        B.ADDRESS1_TX,
                                        B.ADDRESS2_TX,
                                        B.CITY_TX,
                                        B.ZIP_CD,
										&_initiative_id AS INITIATIVE_ID,
                                        CLIENT_ID,
										CLIENT_LEVEL_1,
							   			CLIENT_LEVEL_2,
							   			CLIENT_LEVEL_3,
										B.PRESCRIBER_DEA_NB,
										B.STATE,
										B.ZIP_SUFFIX_CD,
										B.PRESCRIBER_ID AS MBR_ID

                FROM         DATA_PND.&table_prefix._&&cmctn_role_cd&i A,
                             &CLAIMSA..TPRSCBR_PRESCRIBE1 B
                WHERE           A.RECIPIENT_ID = B.PRESCRIBER_ID
                				&client_where ;
          QUIT;

      %end;

%end;  /** end of checking existance of pending file **/ 
%end; /** end of archive_sts_cd=0 **/


%else %if &&ARCHIVE_STS_CD&i = 1 %then %do;

%let table_prefix = t_%cmpres(&_initiative_id)_1;
%let cmctn_role_cd = &&cmctn_role_cd&i.;

/*LIBNAME DATA_ARC "/DATA/sas&sysmode.1/hercules/&_program_id/archive";*/
/*filename file_arc "/DATA/sas&sysmode.1/hercules/&_program_id/archive/&table_prefix._&cmctn_role_cd._pending.sas7bdat.Z";*/
/*commented for testing purpose - Sandeep*/
LIBNAME DATA_ARC "/herc&sysmode/data/hercules/&_program_id/archive";
filename file_arc "/herc&sysmode/data/hercules/&_program_id/archive/&table_prefix._&cmctn_role_cd._pending.sas7bdat.Z"

 %let dsn = %lowcase(&table_prefix._&cmctn_role_cd._pending);
 %put &dsn.;

 %if %sysfunc(fexist(file_arc))>0 or %sysfunc(exist(DATA_ARC.&dsn.))>0 %then %do;

 %if (not %sysfunc(exist(DATA_ARC.&dsn.))) %then %do;
 /* unzip in UNIX using X / %sysexec */
/* systask command "uncompress /DATA/sas&sysmode.1/hercules/&_program_id/archive/&dsn..sas7bdat" taskname=sas1;*/
 systask command "uncompress /herc&sysmode/data/hercules/&_program_id/archive/&dsn..sas7bdat" taskname=sas1;
 waitfor _all_ sas1;
 %end;

 %if &cmctn_role_cd. ne 2 %then %do;

 	PROC SORT DATA = DATA_ARC.&dsn.(KEEP=RECIPIENT_ID)
           OUT=&table_prefix._&cmctn_role_cd._pending  NODUPKEY; 
	BY RECIPIENT_ID; 
	QUIT;

       %DROP_DB2_TABLE(TBL_NAME=&db2_tmp..&table_prefix.PT_LIST_&_program_id);

		   data &db2_tmp..&table_prefix.PT_LIST_&_program_id (BULKLOAD=YES);
           SET &table_prefix._&cmctn_role_cd._pending;
           RUN;
/*YM:NOV19,2012: ADDED MBR_ID AS PER PROACTIVE REFILL ITPR003487*/
 	PROC SQL noprint;
         CONNECT TO DB2 (DSN=&UDBSPRP);
        CREATE TABLE _RCVR_LIST AS
        SELECT * FROM CONNECTION TO DB2
            (SELECT    A.RECIPIENT_ID,
                               B.PT_EXTERNAL_ID,
                               B.CDH_EXTERNAL_ID,
							   B.BENEFICIARY_ID AS MBR_ID

                FROM             &db2_tmp..&table_prefix.PT_LIST_&_program_id A,
                                 &CLAIMSA..TBENEF_BENEFICIAR1 B
                WHERE           A.RECIPIENT_ID = B.BENEFICIARY_ID
                            &client_where  );
                DISCONNECT FROM DB2;
          QUIT;

/*YM:NOV19,2012: ADDED MBR_ID AS PER PROACTIVE REFILL ITPR003487*/
    PROC SQL noprint;
        CREATE TABLE RCVR_LIST AS
            SELECT  		   A.ADJ_ENGINE AS ADJUDICATION,
							   A.RECIPIENT_ID,
							   A.APN_CMCTN_ID,
                               B.PT_EXTERNAL_ID,
                               'Beneficiary' as RECIPIENT_TYPE,
                               A.RVR_LAST_NM AS LAST_NAME,
                               A.RVR_FIRST_NM AS FIRST_NAME,
                               A.ADDRESS1_TX,
                               A.ADDRESS2_TX,
                               A.STATE AS STATE_CD,
                               A.CITY_TX,
                               A.ZIP_CD,
							   &_initiative_id AS INITIATIVE_ID,
                               B.CDH_EXTERNAL_ID,
                               CLIENT_ID,
							   CLIENT_LEVEL_1,
							   CLIENT_LEVEL_2,
							   CLIENT_LEVEL_3,
							   B.MBR_ID

                FROM             DATA_arc.&dsn. A,
                                 _RCVR_LIST B
                WHERE           A.RECIPIENT_ID = B.RECIPIENT_ID  ;
          QUIT;

    %END;

    %ELSE %DO;
/*YM:NOV19,2012: ADDED MBR_ID AS PER PROACTIVE REFILL ITPR003487*/
       PROC SQL noprint;
        CREATE TABLE RCVR_LIST2 AS
            SELECT   distinct           A.ADJ_ENGINE AS ADJUDICATION,
										A.RECIPIENT_ID,
										A.APN_CMCTN_ID,
                                        'Prescriber' as RECIPIENT_TYPE,
										B.PRCBR_LAST_NAME AS LAST_NAME,
                                        B.PRCBR_FIRST_NM AS FIRST_NAME,
                                        B.ADDRESS1_TX,
                                        B.ADDRESS2_TX,
                                        B.CITY_TX,
                                        B.ZIP_CD,
										&_initiative_id AS INITIATIVE_ID,
                                        CLIENT_ID,
										CLIENT_LEVEL_1,
							   			CLIENT_LEVEL_2,
							   			CLIENT_LEVEL_3,
										B.PRESCRIBER_DEA_NB,
										B.STATE,
										B.ZIP_SUFFIX_CD,
										B.PRESCRIBER_ID AS MBR_ID

                FROM         DATA_arc.&dsn. A,
                             &CLAIMSA..TPRSCBR_PRESCRIBE1 B
                WHERE           A.RECIPIENT_ID = B.PRESCRIBER_ID
                &client_where;
          QUIT;

      %end;

/*   systask command "compress /DATA/sas&sysmode.1/hercules/&_program_id/archive/&dsn..sas7bdat" taskname=sas2;*/
	  systask command "compress /herc&sysmode/data/hercules/&_program_id/archive/&dsn..sas7bdat" taskname=sas2;
   waitfor _all_ sas2;

%end;/* end of sysfunc */

%end;  /** end of archive_sts_cd =1 **/


	%else %if &&ARCHIVE_STS_CD&i = 2 %then
    %put  NOTE: THIS MAILING WAS CANCELLED;


%end; /** end of looping cmctn_roles for a given &initiative_id --- PART I **/

%GOTO RPT_OUT;


%if &_initiative_id= %then %do;
%put NOTE: (RCVR_LISTing) No initiative_id has been resolved.;

 %report_23:;

  %let init_record_cnt=0; /** pre-set count of initiatives to 0 **/

 ** SASDOC -------------------------------------------------------------------------------------
  |  PART II: &initiative_id is not available
  |
  | when no initiative_id is specified, receiver listing reports can be generated for a client
  | at a given date range and/or program_id. The program choose the source of data based on the
  | locations of the data - HERCULES history tables Vs /pending
  |
  | -------------------------------------------------------------------------------------------
  |  The report also needs to differentiate the type of receipient based on the cmctn_role_cd and
  |  go to different paths, /pending Vs CMCTN_HIS, to get their addresses.
  + -------------------------------------------------------------------------------------SASDOC*;

%put &BEGIN_DT. AND &END_DT.;

 PROC SQL noprint;
           CONNECT TO DB2 (DSN=&UDBSPRP);
           CREATE TABLE clt_init_his AS
           SELECT * FROM CONNECTION TO DB2
            (SELECT  A.INITIATIVE_ID,  A.PROGRAM_ID
                FROM   &HERCULES..TCMCTN_RECEIVR_HIS A,
                       &HERCULES..TCMCTN_SUBJECT_HIS b
                WHERE  A.COMMUNICATION_DT BETWEEN &BEGIN_DT. AND &END_DT.
                  AND A.CMCTN_ID=B.CMCTN_ID
                  AND A.INITIATIVE_ID=B.INITIATIVE_ID
                  &PROGRAM_WHERE
                  &client_where
                GROUP BY B.CLIENT_ID, A.INITIATIVE_ID, A.PROGRAM_ID
             );
           DISCONNECT FROM DB2;
          QUIT;

	   PROC SQL noprint;
         CREATE TABLE clt_init_pend AS
         SELECT distinct A.INITIATIVE_ID, B.PROGRAM_ID
         FROM   &HERCULES..TPHASE_RVR_FILE a, &hercules..tinitiative b
         WHERE  a.initiative_id=b.initiative_id
/*          	&program_where*/
          	and FILE_USAGE_CD=1
          	AND RELEASE_STATUS_CD=2
          	AND ARCHIVE_STS_CD=0;
       QUIT;

       DATA  clt_initiatives;
       set clt_init_his(in=his) clt_init_pend(in=pend);
       if his then init_sts='HIST';
       if pend then init_sts='PEND'; 
	   run;


	data _null_;
      set clt_initiatives END=END_init;
      call symput('initiative_id'||left(put(_n_,5.)),put(initiative_id,5.));
      call symput('program_id'||left(put(_n_,5.)),put(program_id,5.));
      call symput('init_sts'||left(put(_n_,5.)),init_sts);
      IF END_INIT THEN call symput('init_record_CNT',put(_n_,5.));
    run;


%do k=1 %to &init_record_cnt;

	%LET _INIT_ID=&&INITIATIVE_ID&K;
	%LET _program_id = &&program_ID&K;

	%put NOTE: INITIATIVE_ID = &_INIT_ID;
	%put NOTE: PROGRAM_ID = &_program_id;

		PROC SQL noprint;
           CONNECT TO DB2 (DSN=&UDBSPRP);
           CREATE TABLE CMCTN_ROLE&k AS
           SELECT * FROM CONNECTION TO DB2

            (SELECT A.CMCTN_ROLE_CD, C.ARCHIVE_STS_CD, COUNT(*) AS CNT_PER_ROLE
                FROM   &HERCULES..TCMCTN_RECEIVR_HIS A,
                       &HERCULES..TCMCTN_SUBJECT_HIS B,
                       &HERCULES..TPHASE_RVR_FILE C
                WHERE  A.COMMUNICATION_DT BETWEEN &BEGIN_DT. AND &END_DT.
                  AND A.CMCTN_ID=B.CMCTN_ID
                  AND A.INITIATIVE_ID=B.INITIATIVE_ID
                 AND A.INITIATIVE_ID=C.INITIATIVE_ID
                  AND A.CMCTN_ROLE_CD=C.CMCTN_ROLE_CD
                  &client_where
                  and A.initiative_id=&_INIT_ID
                GROUP BY A.CMCTN_ROLE_CD, C.ARCHIVE_STS_CD
             );
           DISCONNECT FROM DB2;
		QUIT;

  		data _null_;
      	set CMCTN_ROLE&k END=END_RL;
      	call symput('cmctn_role_cd'||put(_n_,1.),put(cmctn_role_cd,1.));
      	call symput('ARCHIVE_STS_CD'||put(_n_,1.),put(ARCHIVE_STS_CD,1.));
      	IF END_RL THEN call symput('cmctn_role_CNT',put(_n_,1.));
     	run;

 %if &&init_sts&k=HIST %then %do;

	%PUT NOTE: "HISTORY";

	%if &cmctn_role_CNT = %then %GOTO OUT_OF_JLOOP_HIST;
	 %do j=1 %to &cmctn_role_CNT;

 ** SASDOC ------------------------------------------------------------------------
  | when file is not archived (archive_sts_cd =0), the records are only available
  | in the /pending. hercules_in.sas is called to identify the file to be processed.
  |
  |--------------------------------------------------------------------------------
  | when the recipient is not a prescriber (cmctn_role_cd ne 2), get address
  | and ss#(CDH external id) at the beneficiary level
  +------------------------------------------------------------------------- SASDOC*;


 ** SASDOC--------------------------------------------------------------------------
  | when the recipient is not a prescriber (cmctn_role_cd ne 2), get address
  | and ss#(CDH external id) at the beneficiary level
  | 07MAR2008 - N.WILLIAMS - Adjust bulkload.
  +------------------------------------------------------------------------- SASDOC*;
%let table_prefix = t_%cmpres(&_init_id)_1;
%let cmctn_role_cd = &&cmctn_role_cd&j.;

/*LIBNAME DATA_ARC "/DATA/sas&sysmode.1/hercules/&_program_id/archive";*/
/*filename file_arc "/DATA/sas&sysmode.1/hercules/&_program_id/archive/&table_prefix._&cmctn_role_cd._pending.sas7bdat.Z";*/
/*commented for testing purpose - Sandeep*/
LIBNAME DATA_ARC "/herc&sysmode/data/hercules/&_program_id/archive";
filename file_arc "/herc&sysmode/data/hercules/&_program_id/archive/&table_prefix._&cmctn_role_cd._pending.sas7bdat.Z";

 %let dsn = %lowcase(&table_prefix._&cmctn_role_cd._pending);
 %put &dsn.;

 %if %sysfunc(fexist(file_arc))>0 or %sysfunc(exist(DATA_ARC.&dsn.)) %then %do;

 /* unzip in UNIX using X / %sysexec */

 %if (not %sysfunc(exist(DATA_ARC.&dsn.))) %then %do;
/* systask command "uncompress /DATA/sas&sysmode.1/hercules/&_program_id/archive/&dsn..sas7bdat" taskname=sas1;*/
 systask command "uncompress /herc&sysmode/data/hercules/&_program_id/archive/&dsn..sas7bdat" taskname=sas1;
 waitfor _all_ sas1;
 %end;


 %if &cmctn_role_cd. ne 2 %then %do;

 	PROC SORT DATA = DATA_ARC.&dsn.(KEEP=RECIPIENT_ID)
           OUT=&table_prefix._&cmctn_role_cd._pending  NODUPKEY; 
	BY RECIPIENT_ID; 
	QUIT;

       %DROP_DB2_TABLE(TBL_NAME=&db2_tmp..&table_prefix.PT_LIST_&_program_id);

		   data &db2_tmp..&table_prefix.PT_LIST_&_program_id (BULKLOAD=YES);
           SET &table_prefix._&cmctn_role_cd._pending;
           RUN;

/*YM:NOV19,2012: ADDED MBR_ID AS PER PROACTIVE REFILL ITPR003487*/
 PROC SQL noprint;
         CONNECT TO DB2 (DSN=&UDBSPRP);
        CREATE TABLE _RCVR_LIST AS
        SELECT * FROM CONNECTION TO DB2
            (SELECT    A.RECIPIENT_ID,
                               B.PT_EXTERNAL_ID,
                               B.CDH_EXTERNAL_ID,
							   B.BENEFICIARY_ID AS MBR_ID


                FROM             &db2_tmp..&table_prefix.PT_LIST_&_program_id A,
                                 &CLAIMSA..TBENEF_BENEFICIAR1 B
                WHERE           A.RECIPIENT_ID = B.BENEFICIARY_ID
                            &client_where  );
                DISCONNECT FROM DB2;
          QUIT;
/*YM:NOV19,2012: ADDED MBR_ID AS PER PROACTIVE REFILL ITPR003487*/
    PROC SQL noprint;
        CREATE TABLE RCVR_LIST&k.&j AS
            SELECT  		   A.ADJ_ENGINE AS ADJUDICATION,
							   A.RECIPIENT_ID,  
							   A.APN_CMCTN_ID, 
                               B.PT_EXTERNAL_ID,
                                'Beneficiary' as RECIPIENT_TYPE,
                               A.RVR_LAST_NM AS LAST_NAME,
                               A.RVR_FIRST_NM AS FIRST_NAME,
                               A.ADDRESS1_TX,
                               A.ADDRESS2_TX,
                               A.STATE AS STATE_CD,
                               A.CITY_TX,
                               A.ZIP_CD,
							   &_INIT_ID as INITIATIVE_ID,
                               B.CDH_EXTERNAL_ID,
                               CLIENT_ID,
							   CLIENT_LEVEL_1,
							   CLIENT_LEVEL_2,
							   CLIENT_LEVEL_3,
							   B.MBR_ID
                               
                FROM             DATA_arc.&table_prefix._&cmctn_role_cd._pending A,
                                 _RCVR_LIST B
                WHERE           A.RECIPIENT_ID = B.RECIPIENT_ID  ;
          QUIT;

    %END;

    %ELSE %DO;
/*YM:NOV19,2012: ADDED MBR_ID AS PER PROACTIVE REFILL ITPR003487*/
       PROC SQL noprint;
        CREATE TABLE RCVR_LIST2&k.&j AS
            SELECT   distinct           A.ADJ_ENGINE AS ADJUDICATION,
									    A.RECIPIENT_ID,  
									    A.APN_CMCTN_ID, 
                                        'Prescriber' as RECIPIENT_TYPE,
                                        B.PRCBR_LAST_NAME AS LAST_NAME,
                                        B.PRCBR_FIRST_NM AS FIRST_NAME,
                                        B.ADDRESS1_TX,
                                        B.ADDRESS2_TX,
                                        B.CITY_TX,
                                        B.ZIP_CD,
										&_INIT_ID as INITIATIVE_ID,
										CLIENT_ID,
										CLIENT_LEVEL_1,
							   			CLIENT_LEVEL_2,
							   			CLIENT_LEVEL_3,
										B.PRESCRIBER_DEA_NB,
										B.STATE,
										B.ZIP_SUFFIX_CD,
 										B.PRESCRIBER_ID AS MBR_ID 
                                        
                FROM         DATA_arc.&table_prefix._&cmctn_role_cd._pending A,
                             &CLAIMSA..TPRSCBR_PRESCRIBE1 B
                WHERE           A.RECIPIENT_ID = B.PRESCRIBER_ID
                &client_where;
          QUIT;

      %end;

/*   systask command "compress /DATA/sas&sysmode.1/hercules/&_program_id/archive/&dsn..sas7bdat" taskname=sas2;*/
	   systask command "compress /herc&sysmode/data/hercules/&_program_id/archive/&dsn..sas7bdat" taskname=sas2;
   waitfor _all_ sas2;

%end;/* end of sysfunc */

%end; /* end of j=1 count */

%OUT_OF_JLOOP_HIST:;

   %end; /** end of init_sts='HIST' **/

%PUT &CLIENT_WHERE.;


%if &&init_sts&k=PEND %then %do; /*** start of not-archived initiatives **/

%PUT NOTE: "PENDING";

 ** SASDOC ------------------------------------------------------------------------
  | when file is not archived (archive_sts_cd =0), the records are only available
  | in the /pending. hercules_in.sas is called to identify the file to be processed.
  |
  |--------------------------------------------------------------------------------
  | when the recipient is not a prescriber (cmctn_role_cd ne 2), get address
  | and ss#(CDH external id) at the beneficiary level
  +------------------------------------------------------------------------- SASDOC*;


 ** SASDOC--------------------------------------------------------------------------
  | when the recipient is not a prescriber (cmctn_role_cd ne 2), get address
  | and ss#(CDH external id) at the beneficiary level
  | 07MAR2008 - N.WILLIAMS - Adjust bulkload.
  +------------------------------------------------------------------------- SASDOC*;

%if &cmctn_role_CNT = %then %GOTO OUT_OF_JLOOP_PEND;
%do j=1 %to &cmctn_role_CNT;

/*LIBNAME DATA_PND "/DATA/sas&sysmode.1/hercules/&_program_id/pending"; */
LIBNAME DATA_PND "/herc&sysmode/data/hercules/&_program_id/pending";

%let table_prefix=t_%cmpres(&_init_id)_1;
         
 %if %sysfunc(exist(DATA_PND.&table_prefix._&&cmctn_role_cd&j))>0 %then %do;
    %if &&cmctn_role_cd&j ne 2 %then %do;

 	PROC SORT DATA=DATA_PND.&table_prefix._&&cmctn_role_cd&j(KEEP=RECIPIENT_ID)
           OUT=&table_prefix._&&cmctn_role_cd&j NODUPKEY; 
	BY RECIPIENT_ID; 
	QUIT;

       %DROP_DB2_TABLE(TBL_NAME=&db2_tmp..&table_prefix.PT_LIST_&_program_id);

      data &db2_tmp..&table_prefix.PT_LIST_&_program_id (BULKLOAD=YES);
           SET &table_prefix._&&cmctn_role_cd&j;
           RUN;
/*YM:NOV19,2012: ADDED MBR_ID AS PER PROACTIVE REFILL ITPR003487*/
 PROC SQL noprint;
         CONNECT TO DB2 (DSN=&UDBSPRP);
        CREATE TABLE _RCVR_LIST AS
        SELECT * FROM CONNECTION TO DB2
            (SELECT            A.RECIPIENT_ID, 
                               B.PT_EXTERNAL_ID,
                               B.CDH_EXTERNAL_ID,
							   B.BENEFICIARY_ID AS MBR_ID

                FROM             &db2_tmp..&table_prefix.PT_LIST_&_program_id A,
                                 &CLAIMSA..TBENEF_BENEFICIAR1 B
                WHERE           A.RECIPIENT_ID = B.BENEFICIARY_ID
                            &client_where  );
                DISCONNECT FROM DB2;
          QUIT;
/*YM:NOV19,2012: ADDED MBR_ID AS PER PROACTIVE REFILL ITPR003487*/
    PROC SQL noprint;
        CREATE TABLE RCVR_LIST&k.&j AS
            SELECT  		   A.ADJ_ENGINE AS ADJUDICATION,
							   A.RECIPIENT_ID,  
							   A.APN_CMCTN_ID, 
                               B.PT_EXTERNAL_ID,
                                'Beneficiary' as RECIPIENT_TYPE,
                               A.RVR_LAST_NM AS LAST_NAME,
                               A.RVR_FIRST_NM AS FIRST_NAME,
                               A.ADDRESS1_TX,
                               A.ADDRESS2_TX,
                               A.STATE AS STATE_CD,
                               A.CITY_TX,
                               A.ZIP_CD,
							   &_INIT_ID as INITIATIVE_ID,
                               B.CDH_EXTERNAL_ID,
                               CLIENT_ID,
							   CLIENT_LEVEL_1,
							   CLIENT_LEVEL_2,
							   CLIENT_LEVEL_3,
							   B.MBR_ID

                FROM             DATA_PND.&table_prefix._&&cmctn_role_cd&j A,
                                 _RCVR_LIST B
                WHERE           A.RECIPIENT_ID = B.RECIPIENT_ID  ;
          QUIT;

    %END;

    %ELSE %DO;
/*YM:NOV19,2012: ADDED MBR_ID AS PER PROACTIVE REFILL ITPR003487*/
       PROC SQL noprint;
        CREATE TABLE RCVR_LIST2&k.&j AS
            SELECT  distinct         A.ADJ_ENGINE AS ADJUDICATION,
								    A.RECIPIENT_ID,  
								    A.APN_CMCTN_ID, 
                    'Prescriber' as RECIPIENT_TYPE,
                    B.PRCBR_LAST_NAME AS LAST_NAME,
                    B.PRCBR_FIRST_NM AS FIRST_NAME,
                    B.ADDRESS1_TX,
                    B.ADDRESS2_TX,
                    B.CITY_TX,
                    B.ZIP_CD,
										&_INIT_ID as INITIATIVE_ID,
										CLIENT_ID,
										CLIENT_LEVEL_1,
						   			CLIENT_LEVEL_2,
						   			CLIENT_LEVEL_3,
										B.PRESCRIBER_DEA_NB,
										B.STATE,
										B.ZIP_SUFFIX_CD, 
										B.PRESCRIBER_ID AS MBR_ID
                FROM         DATA_PND.&table_prefix._&&cmctn_role_cd&j A,
                             &CLAIMSA..TPRSCBR_PRESCRIBE1 B
                WHERE           A.RECIPIENT_ID = B.PRESCRIBER_ID
                				&client_where;
          QUIT;

      %end; /* end of cmctn_role_cd */
%end; /* end of sysfunc */
%end; /*end of j=1 count */

%OUT_OF_JLOOP_PEND:;

   %end;  /** end of init_sts='PEND' **/
%end; /** end of one initiative **/

%end; /** end of looping for the client_id on a give date range when &_initiative_id is not given **/

  ** SASDOC -------------------------------------------------------------------------------------
  |
  | Union files by beneficiaries or proscribers.
  |
  | For report_id =3, the report is to be generated at the program level. The following code
  | subset the listing based on the &program_id when it is available.
  |
  + -------------------------------------------------------------------------------------SASDOC*;

%RPT_OUT:;

  proc datasets memtype=data;
     contents data=work._all_
     out=cat_out(keep=memname) noprint short nodetails;
  run;    
  quit;

%let file_list=;
	 PROC SQL NOPRINT;
     SELECT DISTINCT MEMNAME INTO: FILE_LIST SEPARATED BY ' '
     FROM CAT_OUT
     WHERE SUBSTR(MEMNAME,1,9)='RCVR_LIST'; 
	 QUIT;

%let rcrds_cnt=0;

%IF &FILE_LIST ne %THEN %DO;

     DATA FINAL_LIST;
     SET &file_list;
     RUN;

/*	 DATA FINAL_LIST (DROP = CLIENT_LEVEL_1 CLIENT_LEVEL_2 CLIENT_LEVEL_3);*/
/*	 SET FINAL_LIST;*/
/*	 FORMAT INSURANCE_CD CARRIER_ID ACCOUNT_ID GROUP_CD $25.;*/
/*	 	IF ADJUDICATION = 'QL' THEN DO;*/
/*	 		INSURANCE_CD = ' ';*/
/*			CARRIER_ID = ' ';*/
/*			ACCOUNT_ID = ' ';*/
/*			GROUP_CD = ' ';*/
/*	 	END;*/
/**/
/*		IF ADJUDICATION = 'RX' THEN DO;*/
/*	 		INSURANCE_CD = ' ';*/
/*			CARRIER_ID = CLIENT_LEVEL_1;*/
/*			ACCOUNT_ID = CLIENT_LEVEL_2;*/
/*			GROUP_CD = CLIENT_LEVEL_3;*/
/*	 	END;*/
/**/
/*		IF ADJUDICATION = 'RE' THEN DO;*/
/*	 		INSURANCE_CD = CLIENT_LEVEL_1;*/
/*			CARRIER_ID = CLIENT_LEVEL_2;*/
/*			ACCOUNT_ID = ' ';*/
/*			GROUP_CD = CLIENT_LEVEL_3;*/
/*	 	END;*/
/*	 RUN;*/

	
  proc sql noprint;
       select count(*) into:rcrds_cnt
       from final_list; quit;

 %END;
** SASDOC -------------------------------------------------------------------------------------
  | PART III:
  |
  | For report_id =3, the report is to be generated at the program level. The following code
  | subset the listing based on the &program_id when it is available.
  |
  + -------------------------------------------------------------------------------------SASDOC*;

   %IF &_PROGRAM_ID>0 and &_initiative_id = %THEN %DO;
    %if %sysfunc(exist(WORK.FINAL_LIST))>0 %THEN
       %STR(proc sql;
                 create table final_list as
                 select a.* from final_list a, &hercules..tinitiative b
                 where a.initiative_id=b.initiative_id
                  and b.program_id=&_program_id; quit;
         );

     %END;

** SASDOC -------------------------------------------------------------------------------------
  | When &client_id is known, potentially more than one PROGRAM is involved,
  | send the report to the GENERAL_REPORTS FOLDER.
  + -------------------------------------------------------------------------------------SASDOC*;
%IF &CLIENT_ID>0 %THEN %DO;
      filename ftp_pdf ftp "/users/patientlist/REFILL_NOTE_MLG/Reports/&RPT_FILE_NM..pdf"
           mach='sfb006.psd.caremark.int' RECFM=s ;
      filename ftp_txt ftp "/users/patientlist/REFILL_NOTE_MLG/Reports/&RPT_FILE_NM..txt"
           mach='sfb006.psd.caremark.int' RECFM=V ;
%END;
%ELSE %DO;
      filename ftp_pdf ftp "/users/patientlist/REFILL_NOTE_MLG/Reports/&RPT_FILE_NM..pdf"
           mach='sfb006.psd.caremark.int' RECFM=s ;
      filename ftp_txt ftp "/users/patientlist/REFILL_NOTE_MLG/Reports/&RPT_FILE_NM..txt"
           mach='sfb006.psd.caremark.int' RECFM=V ;
%END;

 %PUT "/users/patientlist/GENERAL_REPORTS/&RPT_FILE_NM..txt";


 %if %sysfunc(exist(WORK.FINAL_LIST))>0 %THEN %do;

	proc sort data=final_list out=final_list nodup;
     by recipient_id; quit;


	%export_sas_to_txt(tbl_name_in=final_list,
                   tbl_name_out=ftp_txt,
                   l_file="layout_out",
                   File_type_out='DEL|',
                   Col_in_fst_row=Y);

 %end;

%SET_ERROR_FL;

/*%FINAL:;*/

 %if &err_fl=0 %then %do;

   filename mymail email "qcpap020@dalcdcp";
   %if &rcrds_cnt >0 %then %do;
    data _null_;
     file mymail
         to=("Marianna.Sumoza@caremark.com" "Hercules.Support@caremark.com" "MEA_Data_Operations@caremark.com")
         subject="&rpt_display_nm" ;

     put 'Hi, All:' ;
     put / "This is an automatically generated message to inform you that your request &initiative_id has been processed.";
     put "There are %cmpres(&rcrds_cnt) records in the file and can be accessed by clicking the link: ";
     %if &ops_subdir =%str(GENERAL_REPORTS) %THEN %STR(put / "\\sfb006\PatientList\&ops_subdir.\&rpt_file_nm..txt";);
     %ELSE %STR(put / "\\sfb006\Patientlist\users\PatientList\&ops_subdir.\Reports\&rpt_file_nm..txt";);
     put / 'Please let us know of any questions.';
     put / 'Thanks,';
     put / 'HERCULES Production Supports';
   run;
   quit;
   %end; 
   %if &rcrds_cnt =0 %then %do;
    data _null_;
     file mymail
         to=("Hercules.Support@caremark.com" "MEA_Data_Operations@caremark.com")
         subject="&rpt_display_nm" ;

     put 'Hi, All:' ;
     put / "This is an automatically generated message to inform you that your request &initiative_id has been processed.";
     put "The request resulted 0 record and no file was created. ";
     put / 'Please let us know of any questions.';
     put / 'Thanks,';
     put / 'HERCULES Production Supports';
    run;

  %end; 

%end;

 %update_request_ts(complete);


%EXIT_END:;

  * ---> Set the parameters for error checking;
   PROC SQL NOPRINT;
      SELECT QUOTE(TRIM(email)) INTO :Primary_programmer_email
      FROM ADM_LKP.ANALYTICS_USERS
      WHERE UPCASE(QCP_ID) IN ("&USER");
   QUIT;

%SET_ERROR_FL;


/*%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,*/
/*           EM_SUBJECT="HCE SUPPORT:  Notification of Abend",*/
/*           EM_MSG="A problem was encountered.  See LOG file - RCVR_LISTing.log for REQUEST ID &initiative_id");*/

%mend rcvr_listing;
%rcvr_listing;


