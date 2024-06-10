
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  load_extfeeds_cmctn_history.sas
|
| LOCATION: /PRG/sas&sysmode.1/hercules/gen_utilities/sas
|
| PURPOSE:  To check for external feeds for faststart recap and rxclaim and load
|           the data into tcmctn_receiver_his
|
| SCHEDULE: Monday-Friday at 1 am 
|
|           note:  1.  needs to be scheduled before or after update cmctn history 
|                      at 4:00 am
|                  2.  before any faststart / retail to mail initatives at 8:00 pm
|                  3.  external feeds at Sunday-Thursday at 10:00 pm
|
| NOTES:    The external feeds are hosted in the following location:
|
|		dalcdcp:/PRG/sastest1/hercules/bss >ftp dwhprod1
|		Connected to dwhprod1.
|		220 dwhprod1 FTP server (Version 4.2 Sat Sep 8 09:49:58 CDT 2007) ready.
|		Name (dwhprod1:qcpap020): qcpap020
|		331 Password required for qcpap020.
|		Password:
|		ftp> cd /hercftp/FASTSTART/Archive
|
|
+--------------------------------------------------------------------------------
| HISTORY:  
|           
| NOV 20 2008  -  Brian Stropich - Hercules Version  2.1.2.01
|                 Original   
|
+------------------------------------------------------------------------HEADER*/

%let sysmode=prod;
%set_sysmode;

LIBNAME SYS_CAT   DB2 DSN=UDBDWP   USER=qcpap020   PASSWORD=anlt2web SCHEMA=SYSCAT   DEFER=YES;
LIBNAME TEMP      DB2 DSN=UDBDWP   USER=qcpap020   PASSWORD=anlt2web SCHEMA=QCPAP020 DEFER=YES;
LIBNAME TMP73     DB2 DSN=&UDBSPRP SCHEMA=TMP73    DEFER=YES;
LIBNAME HERCULES  DB2 DSN=&UDBSPRP SCHEMA=HERCULES DEFER=YES;
LIBNAME ADM_LKP   "/DATA/sas%lowcase(&SYSMODE)1/Admin/auxtable";

%LET PROGRAM_NAME=load_fs_extfeeds_cmctn_history;

 * ---> Set the email address for I.T. error reporting;
PROC SQL NOPRINT;
  SELECT QUOTE(TRIM(email)) INTO :Primary_programmer_email SEPARATED BY ' '
  FROM ADM_LKP.ANALYTICS_USERS
  WHERE UPCASE(QCP_ID) IN ("&USER")
    AND INDEX(UPCASE(EMAIL),'HERCULES') > 0 
    AND FIRST_NAME='ADM';
QUIT;

**%let Primary_programmer_email='Brian.Stropich@caremark.com '; ** for testing;

%put Primary_programmer_email = &Primary_programmer_email. ;

data _null_;
  date=put(today(),weekdate29.);
  call symput('date',date);
run;

%put date = &date. ;

%macro load_fs_extfeeds_cmctn_history(load=);


	*-------------------------------------------------------------;
	* check if new transaction tables exist on UDBDWP;
	*-------------------------------------------------------------;
	proc sql;
	  create table tcm_fs_tables as
	  select tabname, 
	         create_time,
		 datetime() as load_time
	  from sys_cat.tables
	  where upcase(tabschema)   = 'QCPAP020'
	    and substr(tabname,1,6) = 'TCM_FS';
	quit;

	proc sort data = tmp73.external_feeds_tables (keep = tabname)
	          out  = external_feeds_tables;
	  by tabname;
	run;

	proc sort data = tcm_fs_tables ;
	  by tabname;
	run;

	data tcm_fs_tables;
	  merge tcm_fs_tables        (in=a)
	        external_feeds_tables(in=b);
	  by tabname;
	  if a and not b;
	run;
	
	%let table_total = 0;

	data _null_;
	  set tcm_fs_tables end=eof;
	    i+1;
	    ii=left(put(i,4.));
	    call symput('table'||ii,left(trim(tabname)));
	    if eof then call symput('table_total',ii);
	run;

	%put NOTE: table_total = &table_total. ;
	
	
	*-------------------------------------------------------------;
	* process data if new transaction tables exist on UDBDWP;
	*-------------------------------------------------------------;
	%if &table_total > 0 %then %do;  **table total loop - begin ;

		data tcm_fs_transaction;
		  set %do i= 1 %to &table_total. ;
		         temp.&&table&i (keep = receiver_id program_id apn_cmctn_id cmctn_generated_ts)
		      %end;;
		run;

		data tcm_fs_transaction ;
		  set tcm_fs_transaction ;
		  date1=datepart(cmctn_generated_ts);
		run;
		
		data tcm_fs_transaction ;
		  set tcm_fs_transaction ;
		  where program_id=73;
		run;

		proc sort data = hercules.tdocument_version 
		          out  = tdocument_version (keep = apn_cmctn_id template_id)
	              nodupkey;
		  by apn_cmctn_id;
		run;
		
		
		/** tcmctn_receivr_his has to be unique by INITIATIVE_ID PHASE_SEQ_NB CMCTN_ROLE_CD CMCTN_ID **/
		
		%let counter=0;
		proc sql noprint;
		 select max(cmctn_id) into: counter
		 from hercules.tcmctn_receivr_his
		 where initiative_id=0;
		quit;

		%put NOTE: counter = &counter. ;		

		proc sql noprint;
		  create table tcmctn_receivr_his as
		  select 0 as initiative_id,
			 1 as phase_seq_nb,
			 1 as cmctn_role_cd,
			 1 as cmctn_id,
			 receiver_id as recipient_id,
			 a.apn_cmctn_id,
			 program_id,
			 date1 as communication_dt format=date9.,
			 "EXTFEEDS"  as hsc_usr_id,
			 datetime() as hsc_ts,
			 "EXTFEEDS"  as hsu_usr_id,
			 datetime() as hsu_ts
		  from   tcm_fs_transaction as a left join
			 tdocument_version  as b
		  on a.apn_cmctn_id=b.apn_cmctn_id;
		QUIT;

		data tcmctn_receivr_his;
		  set tcmctn_receivr_his;
		  if apn_cmctn_id = '' then do;
            		apn_cmctn_id='0';
		  end;
		run;

		data tcmctn_receivr_his;
		  set tcmctn_receivr_his;
		  cmctn_id = &counter + _n_;
		run;
		
		
		*-------------------------------------------------------------;
		* load data into TCMCTN_RECEIVR_HIS;
		*-------------------------------------------------------------;
		%if %upcase(&load) = YES %then %do;  **load loop - begin ; 
		
			proc sql; 
			  drop table tmp73.tcmctn_receivr_his ; 
			quit;

			proc sql;
			  connect to db2 (dsn=&udbsprp);
			  execute(
			    create table tmp73.tcmctn_receivr_his as
			    (select * 
			     from hercules.tcmctn_receivr_his)
			     definition only not logged initially) by db2;
			  disconnect from db2; 
			quit;

			proc sql noprint;
			  insert into tmp73.tcmctn_receivr_his (bulkload=yes)
			  select * 
			  from tcmctn_receivr_his;
			quit;
			
			%let obs_total = 0;

			proc sql noprint;
			 select count(*) into:  obs_total
			 from tmp73.tcmctn_receivr_his;
			quit;

			%put NOTE: obs_total = &obs_total. ;	
			
			%if &obs_total > 0 %then %do;  **obs total loop - begin ;

				proc sql;
				  connect to db2 (dsn=&udbsprp);	    
				  execute ( rollback) by db2;
				  execute ( insert into hercules.tcmctn_receivr_his
					    select a.*
					    from tmp73.tcmctn_receivr_his a
				      ) by db2;	    
				  disconnect from db2;
				quit;
				
				%set_error_fl;


				%on_error(ACTION=ABORT, EM_TO=&Primary_programmer_email,
					  EM_SUBJECT="HCE SUPPORT:  Failure on Load FastStart External Feeds",
					  EM_MSG="A problem was encountered. See LOG file - load_fs_extfeeds_cmctn_history.log in gen_utilities - sas directory");				
			
			%end;  **obs total loop - end ;

			proc append data = tcm_fs_tables
			            base = tmp73.external_feeds_tables
			            force;
			run; 
			
			%create_faststart_report;
			%email_faststart_report;
                
		%end;  **load loop - end ;

	%end;  **table total loop  - end ;

%mend load_fs_extfeeds_cmctn_history;

%macro create_faststart_report;

	%*SASDOC--------------------------------------------------------------------------
	| Create load faststart external feeds report 
	+------------------------------------------------------------------------SASDOC;
	options  TOPMARGIN=.5 BOTTOMMARGIN=.5 RIGHTMARGIN=.5 LEFTMARGIN=.5
		 ORIENTATION =PORTRAIT  PAPERSIZE=LETTER;

	ods listing close;
	ods pdf file="/PRG/sas&sysmode.1/hercules/gen_utilities/sas/report_load_fs_extfeeds_cmctn_history.pdf" NOTOC startpage=no;
	ods proclabel ' ';

	  options nodate;

	  proc print data= tmp73.external_feeds_tables;
	    title1 font=arial color=black  h=12pt j=c  'Hercules Communication Engine';
	    title2 font=arial color=black  h=16pt j=c  'FastStart External Feeds into HERCULES.TCMCTN_RECEIVR_HIS';
	    title3 font=arial color=black  h=16pt j=c  'Load FastStart External Feeds Report';
	    title4 " ";
	    title5 " ";
	    title6 " ";  
	    title7 " "; 
	    footnote1 h=8pt j=r  "Hercules Communication Engine" ;
	    footnote2 h=8pt j=r  "&date." ;    
	  run;

	ods pdf close;
	ods listing;

	run;
	quit;
	
%mend create_faststart_report;

%macro email_faststart_report;

	%*SASDOC--------------------------------------------------------------------------
	| Send email to Hercules Support of the load faststart external feeds
	+------------------------------------------------------------------------SASDOC;
	filename mymail email 'qcpap020@dalcdcp';

	data _null_;
	    file mymail

		to =(&primary_programmer_email)
		subject='Load FastStart External Feeds Report - Summary'
		attach=("/PRG/sas&sysmode.1/hercules/gen_utilities/sas/report_load_fs_extfeeds_cmctn_history.pdf" 
			 ct="application/pdf");;

	    put 'Hello:' ;
	    put / "This is an automatically generated message to inform Hercules Support of the load of the FastStart external files into HERCULES.TCMCTN_RECEIVR_HIS.";
	    put / "The report will contain a list of new tables that became available from the external cmctn process. ";
	    put / "Attached is the report that summarizes the load information.";
	    put / 'Thanks,';
	    put   'Hercules Support';
	run;
	quit;

%mend email_faststart_report;

%load_fs_extfeeds_cmctn_history(load=YES);






