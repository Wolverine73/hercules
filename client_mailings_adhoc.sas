%include '/user1/qcpap020/autoexec_new.sas';

/* HEADER ------------------------------------------------------------------------------
 |
 | PROGRAM:    client_mailings.SAS
 |
 | LOCATION:   /&PRG_dir.
 |
 | PURPOSE:    Generate the number od communications by initiative/receiver that clienth
 |             as participated in a give date range.
 |
 | INPUT:      CLIENT_ID, initiative_id, date range
 |
 | OUTPUT      Count of communications by client for a initiative
 |             The result will be delivered to the WEB only
 |
 | CREATED:    June. 2004, John Hou
 |
 | MODIFICATIONS: S.YARAMADA 06MAY2008 - Hercules Version 2.1.01
 |				Added logic to the code so that the report shows the adjudication 
 |              of the client that has been selected.
 |
 + -------------------------------------------------------------------------------HEADER*/
%LET err_fl=0;

%set_sysmode(mode=prod);

options sysparm='request_id=108122';
/*%set_sysmode(mode=sit2);*/
/*OPTIONS MPRINT SOURCE2 MPRINTNEST MLOGIC MLOGICNEST symbolgen   ;*/

%INCLUDE "/herc&sysmode/prg/hercules/hercules_in.sas";
%include "/herc&sysmode/prg/hercules/reports/hercules_rpt_in.sas";

 %let _&REQUIRED_PARMTR_nm.=&REQUIRED_PARMTR_id;
 %let _&SEC_REQD_PARMTR_NM.=&SEC_REQD_PARMTR_id;

 %put _&REQUIRED_PARMTR_nm.=&REQUIRED_PARMTR_id;
 %put _&SEC_REQD_PARMTR_NM.=&SEC_REQD_PARMTR_id;
 %let ops_subdir=GENERAL_REPORTS;

%update_request_ts(start);

%macro asign_str;
%global initiative_where client_where program_where initiative_grp client_grp program_grp
        initiative_rpt client_rpt program_rpt initiative_id program_id client_id rpt_adj_engine_cd;

%if &_initiative_id >0 %then %do;
    %let initiative_where=%str(and a.initiative_id=&_initiative_id);
    %let initiative_grp=%str(a.initiative_id,);
    %let initiative_rpt=initiative_id;
   %end;

%if &_client_id>0  %then %do;
    %let client_where =%str(and b.client_id=&_client_id);
    %let client_grp=%str(b.client_id, b.client_nm,);
    %let client_rpt=client;
 %end;

%mend asign_str;
%asign_str;

PROC SQL NOPRINT;
	SELECT adj_engine_cd INTO :rpt_adj_engine_cd
	FROM CLAIMSA.TCLIENT1
	WHERE client_id=&_client_id;
QUIT;

%put rpt_adj_engine_cd = &rpt_adj_engine_cd for client_id = &client_id ;

%macro query_by_adj;
	%if &rpt_adj_engine_cd. =1 %then %do;
 		PROC SQL;
      		CONNECT TO DB2 (DSN=&UDBSPRP);
     		CREATE TABLE CLT_MAILINGS AS
      		SELECT * FROM CONNECTION TO DB2 (
      		WITH CLIENT_MAILINGS AS 
			(SELECT &client_grp d.initiative_id, d.TITLE_TX, d.program_id, b.client_cd,
             	count(RECIPIENT_ID) AS LETTER_COUNT, A.COMMUNICATION_DT
      		FROM &HERCULES..TCMCTN_RECEIVR_HIS A, CLAIMSA.TCLIENT1 B,
            	&HERCULES..TCMCTN_SUBJECT_HIS C, &HERCULES..TINITIATIVE D
      		WHERE C.CLIENT_ID=B.CLIENT_ID
            	&client_where
            	&initiative_where
       			AND  A.CMCTN_ID=C.CMCTN_ID
       			AND  A.INITIATIVE_ID=D.INITIATIVE_ID
       			and  a.INITIATIVE_ID=c.INITIATIVE_ID
       			AND  A.COMMUNICATION_DT BETWEEN &BEGIN_DT. AND &END_DT.
      		GROUP BY &CLIENT_grp b.client_cd, d.initiative_id, 
			D.title_TX, d.PROGRAM_ID, A.COMMUNICATION_DT)
			SELECT A.*, B.BLG_REPORTING_CD, B.PLAN_CD_TX, B.GROUP_CD_TX
			 FROM CLIENT_MAILINGS A LEFT JOIN &HERCULES..TINIT_CLIENT_RULE B
			 ON A.INITIATIVE_ID = B.INITIATIVE_ID
			);
      		DISCONNECT FROM DB2;
		QUIT;
	%end;
	%if &rpt_adj_engine_cd. =2 %then %do;
 		PROC SQL;
      		CONNECT TO DB2 (DSN=&UDBSPRP);
     		CREATE TABLE CLT_MAILINGS AS
      		SELECT * FROM CONNECTION TO DB2 (
			WITH CLIENT_MAILINGS AS 
			(SELECT &client_grp d.initiative_id, d.TITLE_TX, d.program_id, b.client_cd,
             	count(RECIPIENT_ID) AS LETTER_COUNT, A.COMMUNICATION_DT
      		FROM &HERCULES..TCMCTN_RECEIVR_HIS A, CLAIMSA.TCLIENT1 B,
            	&HERCULES..TCMCTN_SUBJECT_HIS C, &HERCULES..TINITIATIVE D
      		WHERE C.CLIENT_ID=B.CLIENT_ID
            	&client_where
            	&initiative_where
       			AND  A.CMCTN_ID=C.CMCTN_ID
       			AND  A.INITIATIVE_ID=D.INITIATIVE_ID
       			and  a.INITIATIVE_ID=c.INITIATIVE_ID
       			AND  A.COMMUNICATION_DT BETWEEN &BEGIN_DT. AND &END_DT.
      		GROUP BY &CLIENT_grp b.client_cd, d.initiative_id, 
			D.title_TX, d.PROGRAM_ID, A.COMMUNICATION_DT)
			SELECT A.*, B.CARRIER_ID, B.ACCOUNT_ID, B.GROUP_CD
			 FROM CLIENT_MAILINGS A LEFT JOIN &HERCULES..TINIT_RXCLM_CLT_RL B
			 ON A.INITIATIVE_ID = B.INITIATIVE_ID
			);
      		DISCONNECT FROM DB2;
		QUIT;
	%end;
	%if &rpt_adj_engine_cd. =3 %then %do;
 		PROC SQL;
      		CONNECT TO DB2 (DSN=&UDBSPRP);
     		CREATE TABLE CLT_MAILINGS AS
      		SELECT * FROM CONNECTION TO DB2 (
			WITH CLIENT_MAILINGS AS 
			(SELECT &client_grp d.initiative_id, d.TITLE_TX, d.program_id, b.client_cd,
             	count(RECIPIENT_ID) AS LETTER_COUNT, A.COMMUNICATION_DT
      		FROM &HERCULES..TCMCTN_RECEIVR_HIS A, CLAIMSA.TCLIENT1 B,
            	&HERCULES..TCMCTN_SUBJECT_HIS C, &HERCULES..TINITIATIVE D
      		WHERE C.CLIENT_ID=B.CLIENT_ID
            	&client_where
            	&initiative_where
       			AND  A.CMCTN_ID=C.CMCTN_ID
       			AND  A.INITIATIVE_ID=D.INITIATIVE_ID
       			and  a.INITIATIVE_ID=c.INITIATIVE_ID
       			AND  A.COMMUNICATION_DT BETWEEN &BEGIN_DT. AND &END_DT.
      		GROUP BY &CLIENT_grp b.client_cd, d.initiative_id, 
			D.title_TX, d.PROGRAM_ID, A.COMMUNICATION_DT)
			SELECT A.*, B.INSURANCE_CD, B.CARRIER_ID, B.GROUP_CD
			 FROM CLIENT_MAILINGS A LEFT JOIN &HERCULES..TINIT_RECAP_CLT_RL B
			 ON A.INITIATIVE_ID = B.INITIATIVE_ID
			);
      		DISCONNECT FROM DB2;
		QUIT;
	%end;
%mend query_by_adj;
%query_by_adj;

%macro dataset_by_adj;
	%if &rpt_adj_engine_cd. =1 %then %do;
		data CLT_MAILINGS;
     		set clt_mailings;
	 		length adjvar $7 ;
     		client=trim(left(client_nm))||'('||trim(left(put(CLIENT_ID, 6.)))||')';
			adjvar='QL';
		RUN;
	%end;
	%if &rpt_adj_engine_cd. =2 %then %do;
		data CLT_MAILINGS;
     		set clt_mailings;
	 		length adjvar $7 ;
     		client=trim(left(client_nm))||'('||trim(left(put(CARRIER_ID, $6.)))||')';
			adjvar='RX';
		RUN;
	%end;
	%if &rpt_adj_engine_cd. =3 %then %do;
		data CLT_MAILINGS;
     		set clt_mailings;
	 		length adjvar $7 ;
     		client=trim(left(client_nm))||'('||trim(left(put(INSURANCE_CD, $6.)))||')';
			adjvar='RE';
		RUN;
	%end;
%mend dataset_by_adj;
%dataset_by_adj;

Proc sql noprint;
     select count(*) into: rcrds_cnt
     from clt_mailings; quit;

       filename ftp_pdf ftp "/users/patientlist/GENERAL_REPORTS/&RPT_FILE_NM..pdf"
            mach='sfb006.psd.caremark.int' RECFM=s ;

 OPTIONS  TOPMARGIN=.5   BOTTOMMARGIN=.5        RIGHTMARGIN=.5
          LEFTMARGIN=.5 PAPERSIZE =letter   orientation=portrait
         nodate;
  footnote;
  * STARTPAGE=NO style=my_pdf;
   ods listing close;
   ods pdf file=ftp_pdf style=my_pdf notoc;

   title1 font=bookmanoldstyle h=16pt j=c 'HERCULES Operation Reports';
   title3 font=bookmanoldstyle h=12pt j=c "Client Mailings";
   title5 h=10pt j=l "Date Range: Communication Date between &BEGIN_DT and &END_DT";
   footnote1 font=bookmanoldstyle j=l "Report ID = 1" c=blue h=8pt j=r "&sysdate9";

%macro report_by_adj;
	%if &rpt_adj_engine_cd. =1 %then %do;
    	Proc report data=clt_mailings  split='^' nowd nocenter contents='';

         column adjvar &CLIENT_rpt initiative_id 
				blg_reporting_cd plan_cd_tx group_cd_tx 
				program_id TITLE_TX letter_count COMMUNICATION_DT;
         define adjvar       / order format=$7.  'ADJ' style={cellwidth=80};
         define client     / order format=$40.  'Client Name^(Client Level 1)' style={cellwidth=175};
         define initiative_id  / order format=5.  'INIT^ID' style={cellwidth=80};
		 define blg_reporting_cd  / format=$10.  'Client^Level^2' style={cellwidth=80};
		 define plan_cd_tx  / format=$10.  'Client^Level^3' style={cellwidth=80};
		 define group_cd_tx  / format=$10.  'Client^Level^4' style={cellwidth=80};
         define program_id  /  format=6.  'PGM^ID' style={cellwidth=80};
         define title_TX  / format=$100.  'Description' style={cellwidth=150};
         define letter_count   /  format=8.  'Number^of^Letters' style={cellwidth=100};
         define communication_dt /format=mmddyyd10. 'Mailing^Date' style={cellwidth=125};
		quit;
	%end;
	%if &rpt_adj_engine_cd. =2 %then %do;
    	Proc report data=clt_mailings  split='^' nowd nocenter contents='';

         column adjvar &CLIENT_rpt initiative_id 
				account_id group_cd 
				program_id TITLE_TX letter_count COMMUNICATION_DT;
         define adjvar       / order format=$7.  'ADJ' style={cellwidth=80};
         define client     / order format=$40.  'Client Name^(Client Level 1)' style={cellwidth=175};
         define initiative_id  / order format=5.  'INIT^ID' style={cellwidth=80};
		 define account_id  / format=$10.  'Client^Level^2' style={cellwidth=80};
		 define group_cd  / format=$10.  'Client^Level^3' style={cellwidth=80};
         define program_id  /  format=6.  'PGM^ID' style={cellwidth=80};
         define title_TX  / format=$100.  'Description' style={cellwidth=150};
         define letter_count   /  format=8.  'Number^of^Letters' style={cellwidth=100};
         define communication_dt /format=mmddyyd10. 'Mailing^Date' style={cellwidth=125};
		quit;
	%end;
	%if &rpt_adj_engine_cd. =3 %then %do;
    	Proc report data=clt_mailings  split='^' nowd nocenter contents='';

         column adjvar &CLIENT_rpt initiative_id 
				carrier_id group_cd 
				program_id TITLE_TX letter_count COMMUNICATION_DT;
         define adjvar       / order format=$7.  'ADJ' style={cellwidth=80};
         define client     / order format=$40.  'Client Name^(Client Level 1)' style={cellwidth=175};
         define initiative_id  / order format=5.  'INIT^ID' style={cellwidth=80};
		 define carrier_id  / format=$10.  'Client^Level^2' style={cellwidth=80};
		 define group_cd  / format=$10.  'Client^Level^3' style={cellwidth=80};
         define program_id  /  format=6.  'PGM^ID' style={cellwidth=80};
         define title_TX  / format=$100.  'Description' style={cellwidth=150};
         define letter_count   /  format=8.  'Number^of^Letters' style={cellwidth=100};
         define communication_dt /format=mmddyyd10. 'Mailing^Date' style={cellwidth=125};
		quit;
	%end;
%mend report_by_adj;
%report_by_adj;

	ods pdf close;



%macro send_mail;

 %if &err_fl=0 %then %do;

   filename mymail email 'qcpap020@prdsas1';
 %if &rcrds_cnt >0 %then %do;
   data _null_;
     file mymail
         to=(&EMAIL_USR_rpt)
         subject="&rpt_display_nm" ;

     put 'Hi, All:' ;
     put / "This is an automatically generated message to inform you that your request &request_id has been processed.";
     put "There are %cmpres(&rcrds_cnt) records in the file and can be accessed by clicking the link: ";
     put / "\\sfb006\PatientList\&ops_subdir\&rpt_file_nm..pdf";
     put / 'Please let us know of any questions.';
     put / 'Thanks,';
     put / 'HERCULES Production Supports';
   run;
   quit;
 %end; /** end of &rcrds_cnt>0 **/

   %if &rcrds_cnt =0 %then %do;
   data _null_;
     file mymail
         to=(&EMAIL_USR_rpt)
         subject="&rpt_display_nm" ;

     put 'Hi, All:' ;
     put / "This is an automatically generated message to inform you that your request &request_id has been processed.";
     put "The request resulted 0 record and no file was created. ";
     put / 'Please let us know of any questions.';
     put / 'Thanks,';
     put / 'HERCULES Production Supports';
   run;

  %end; /** end of &rcrds_cnt=0 **/

	%update_request_ts(complete);
 %end;

%mend send_mail;
 %send_mail;


