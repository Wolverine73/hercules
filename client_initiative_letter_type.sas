
/* HEADER ------------------------------------------------------------------------------
 |
 | PROGRAM:    client_initiative_letter_type.SAS
 |
 | LOCATION:   /&PRG_dir.
 |
 | PURPOSE:    Provides a count of comunications/subjects by client and by type of letter
 |
 | INPUT:      pending file or HERCULES.TCMCTN_RECEIVR_HIS depending on the ARCHIVE_STS_CD
 |
 | OUTPUT      Count of communications by client and type of letters sent for a initiative.
 |             The result will be delivered to the WEB
 |
 | CREATED:    June. 2004, John Hou
 |
 + -------------------------------------------------------------------------------HEADER*/
/* options sysparm='initiative_id=180';*/


 %set_sysmode(mode=prod);
 %include "/herc&sysmode./prg/hercules/hercules_in.sas";
 %let _initiative_id=&initiative_id;

/** %include "/PRG/sas&sysmode.1/hercules/reports/hercules_rpt_in.sas";
 %let _&REQUIRED_PARMTR_NM = &REQUIRED_PARMTR_ID;
 %put &SEC_REQD_PARMTR_nm.=&SEC_REQD_PARMTR_id; **/



 ** SASDOC -------------------------------------------------------------------------------
  |
  | The letter_seq_nb for a processed initiative is available in the mailing file located
  | either data_pnd or data_res. Call hercules_in.sas to get the name  and location of
  | the mailing file - &table_prefix.
  |
  + -------------------------------------------------------------------------------SASDOC*;

%MACRO RPT;

%if &initiative_id >0 %then %do;
    %let initiative_where=%str(and a.initiative_id=&initiative_id);
    %let initiative_grp=%str(a.initiative_id,);
    %let initiative_rpt=initiative_id;
   %end;


 PROC SQL NOPRINT;
    SELECT   A.PROGRAM_ID INTO: PROGRAM_ID

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
             E.FILE_USAGE_CD=1;
  QUIT;

LIBNAME DATA_PND "/herc&sysmode./data/hercules/%cmpres(&program_id)/pending";
%let table_prefix=t_%cmpres(&_initiative_id)_1;

   proc sql noprint;

           select count(*) into: c_role_cnt
           from &hercules..tphase_rvr_file
           where initiative_id=&_initiative_id;

         create table c_role as
           select cmctn_role_cd, archive_sts_cd
           from &hercules..tphase_rvr_file
           where initiative_id=&_initiative_id;
     quit;

   data _null;
       set c_role;
       call symput('cmctn_role_cd'||put(_n_,1.),put(cmctn_role_cd,1.));
       call symput('archive_sts_cd'||put(_n_,1.), put(archive_sts_cd,1.));
     run;

 %do i=1 %to &c_role_cnt;

 %if &&archive_sts_cd&i=0 %then %do;
 PROC SQL;
      CREATE TABLE ltr_type_cnt&i AS
      SELECT CLIENT_ID, CLIENT_NM, LTR_RULE_SEQ_NB,
             count(RECIPIENT_ID) AS LETTER_COUNT
      FROM data_pnd.&table_prefix._&&cmctn_role_cd&i
      GROUP BY CLIENT_ID, CLIENT_NM, LTR_RULE_SEQ_NB ;
      QUIT;

  %end;
%else %if &&archive_sts_cd&i=1 %then %do;
%let file_str=%lowcase(&table_prefix._&&cmctn_role_cd&i..);


    PROC SQL;
         CONNECT TO DB2 (DSN=&UDBSPRP);
         CREATE TABLE ltr_type_cnt&i AS
         SELECT * FROM CONNECTION TO DB2
      (SELECT B.CLIENT_ID, C.CLIENT_NM, APN_CMCTN_iD AS LTR_RULE_SEQ_NB,
             count(RECIPIENT_ID) AS LETTER_COUNT
      FROM &HERCULES..TCMCTN_RECEIVR_HIS A, &HERCULES..TCMCTN_SUBJECT_HIS B,
           &CLAIMSA..TCLIENT1 C
      WHERE A.CMCTN_ID=B.CMCTN_ID
       AND  B.CLIENT_ID=C.CLIENT_ID
       AND  A.INITIATIVE_ID=&_INITIATIVE_ID
      GROUP BY b.CLIENT_ID, CLIENT_NM, APN_CMCTN_iD) ;
      DISCONNECT FROM DB2;
      QUIT;

 %end;
%ELSE %GOTO EXIT;

proc datasets memtype=data;
      contents data=work._all_
      out=cat_out(keep=memname) noprint short nodetails;
   run;    quit;
%let file_list=;

      PROC SQL NOPRINT;
      SELECT DISTINCT MEMNAME INTO: FILE_LIST SEPARATED BY ' '
      FROM CAT_OUT
      WHERE SUBSTR(upcase(MEMNAME),1,12)='LTR_TYPE_CNT'; QUIT;



 %if &FILE_LIST= %then %goto exit;
 %else %IF &FILE_LIST ne %THEN %DO;

  data ltr_type_cnt;
     set &FILE_LIST;
     client=trim(left(client_nm))||'('||trim(left(put(CLIENT_ID, 6.)))||')';
     RUN;
 %END;


DATA _NULL_;
     SET &HERCULES..TREPORT(WHERE=(REPORT_ID=12));
     CALL SYMPUT('RPT_DISPLAY_NM', trim(left(RPT_DISPLAY_NM)));
     RUN;

 OPTIONS  TOPMARGIN=.5   BOTTOMMARGIN=.5        RIGHTMARGIN=.5
          LEFTMARGIN=1.5 PAPERSIZE =letter   orientation=portrait
         nodate;
  footnote;
  * STARTPAGE=NO style=my_pdf;
   ods listing close;
   ods pdf file=rptfl style=my_pdf notoc;

   title1 font=bookmanoldstyle h=16pt j=c 'HERCULES Operation Reports';

   title3 font=bookmanoldstyle h=12pt j=c "&rpt_display_nm";
   footnote1 font=bookmanoldstyle c=blue h=8pt  j=l "Report ID = 12" j=r "&sysdate9";
    Proc report data=ltr_type_cnt  split='^' nowd nocenter contents='';

         column CLIENT ltr_rule_seq_nb letter_count;
         define client     / order format=$40.  'Client' style={cellwidth=480};
         define ltr_rule_seq_nb  / order format=$8.  'Letter Rule SEQ/APN_CMCTN_ID' style={cellwidth=180};
         define letter_count     / order format=8.  'Number of^Letters' style={cellwidth=80};
      quit;

    ods pdf close;

%end;

%EXIT:;

%if &file_list=0 %then %do;
data no_value;
     length message $ 80;
     message= 'No records were found for the selected client.'; run;

  ods listing close;
   ods pdf file=rptfl style=my_pdf notoc;

   title1 font=bookmanoldstyle h=14pt j=c 'HERCULES Operation Reports';
   title3 font=bookmanoldstyle h=12pt j=c "&rpt_display_nm";
   footnote1 font=bookmanoldstyle c=blue h=8pt  j=l "Report ID = 12" j=r "&sysdate9";
    Proc report data=no_value  split='^' nowd nocenter contents='';

         column message;
         define message    / order format=$80.  ' ' style={cellwidth=480};
      quit;

    ods pdf close;

  %end;

 %mend rpt;

    %RPT;
