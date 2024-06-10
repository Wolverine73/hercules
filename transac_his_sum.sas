** HEADER ----------------------------------------------------------------------------
 |
 | PROGRAM NAME: TRANSAC_HIS_SUM.SAS
 |
 | PURPOSE: CREATE AND UPDATE SUMMARY STATUS OF HERCULES.TCMCTN_TRANSACTION TABLE
 | INPUT:   HERCULES.TCMCTN_TRANSACTION
 | OUTPUT:  QCPAP020.TTRANSAC_HIS_SUM
 |
 | CREATED BY: JOHN HOU, JUNE 2004
 |             N. WILLIAMS, DEC 2009 - 1. Modified first sas sql query to Sql pass-thru query.
 |                                     2. Modified second sql query logic to split sql query into 
 |                                     two seperate queries one for sql delete step query 
 |                                     and one for sql insert query. 
 |                                     3. Modified email setup so we get daily email when errors
 |                                        do exist. 
 + ---------------------------------------------------------------------------HEADER*;
   LIBNAME ADM_LKP "/herc&sysmode/data/Admin/auxtable";

*SASDOC--------------------------------------------------------------------------
| N. WILLIAMS DEC 2009 - Adjust SAS SQL Select query step to use SQL pass-thru
| query for optimization. 
+-------------------------------------------------------------------------SASDOC*;
%drop_db2_table(tbl_name=&USER..TTRANSAC_HIS_TEMP);

proc sql;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
execute(CREATE TABLE &USER..TTRANSAC_HIS_TEMP 
like &USER..TTRANSAC_HIS) by db2;
execute(Insert Into &USER..TTRANSAC_HIS_TEMP
SELECT  APN_CMCTN_ID, CMCTN_STS_CD, cmctn_generated_ts, PROGRAM_ID,
        COUNT(*) AS RECORD_COUNT, CURRENT DATE AS UPDATE_DATE
FROM HERCULES.TCMCTN_TRANSACTION
WHERE PROGRAM_ID NOT IN (40,90,91)
GROUP BY APN_CMCTN_ID,CMCTN_STS_CD, cmctn_generated_ts, PROGRAM_ID
order by APN_CMCTN_ID, CMCTN_STS_CD, cmctn_generated_ts, PROGRAM_ID
) by db2;
disconnect from db2;
quit;
*%GRANT(TBL_NAME=QCPAP020.TTRANSAC_HIS);

*SASDOC--------------------------------------------------------------------------
| N. WILLIAMS DEC 2009 - SQL Delete query step delete transactions that already
| exist on hercules id communication history transaction table archive.
+-------------------------------------------------------------------------SASDOC*;
   PROC SQL ;
     CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
       EXECUTE(DELETE FROM &USER..TTRANSAC_HIS_TEMP A
               WHERE EXISTS
              (SELECT 1 FROM &USER..TTRANSAC_HIS B
               WHERE B.CMCTN_STS_CD       = A.CMCTN_STS_CD
               AND   A.cmctn_generated_ts = B.cmctn_generated_ts
               AND   A.PROGRAM_ID         = B.PROGRAM_ID )) BY DB2;
     %reset_sql_err_cd;
     DISCONNECT FROM DB2;
   QUIT;

*SASDOC--------------------------------------------------------------------------
| N. WILLIAMS DEC 2009 - SQL Insert query step insert transactions that do not 
| already exist on hercules id communication history transaction table archive.
+-------------------------------------------------------------------------SASDOC*;
PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
    EXECUTE(ALTER TABLE &USER..TTRANSAC_HIS
            ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;

    EXECUTE(INSERT INTO &USER..TTRANSAC_HIS
           (SELECT *
            FROM  &USER..TTRANSAC_HIS_TEMP
           )) BY DB2;
  DISCONNECT FROM DB2;
QUIT;
%set_error_fl;

%RUNSTATS(TBL_NAME=&USER..TTRANSAC_HIS);


 PROC SQL NOPRINT;
      CREATE TABLE ERR_LST AS
      SELECT *, CASE WHEN CMCTN_STS_CD = 4 THEN 'Delete'
                     WHEN CMCTN_STS_CD = 5 THEN 'Delete Extracted'
                     WHEN CMCTN_STS_CD = 6 THEN 'Document Not Found'
                     ELSE 'Other Error' end
                as ERROR_STS

        FROM QCPAP020.TTRANSAC_HIS
      WHERE CMCTN_STS_CD >=4
       AND UPDATE_DATE=TODAY();
   quit;

 PROC SQL NOPRINT;
     select count(*) into: err_cnt
      from ERR_LST;
  QUIT;

   proc sql noprint;
     select quote(trim(left(email)))
     into   :PRIMARY_PROGRAMMER_EMAIL separated by ' '
     from   ADM_LKP.ANALYTICS_USERS
     where  upcase(QCP_ID) in ("&USER");
     quit;

%macro sent_cmctn_err;

  %*SASDOC-----------------------------------------------------------------------
  | Produce report of undeleted files.
  +----------------------------------------------------------------------SASDOC*;
 %if &err_cnt>0 %then %do;
  /*SASDOC-----------------------------------------------------------------------
  | Modify ODS template.
  +----------------------------------------------------------------------SASDOC*/
  ods path sasuser.templat(read) sashelp.tmplmst(read) work.templat(update);
  proc template;
  define style MAIN_DIR / store=WORK.TEMPLAT;
     parent=styles.minimal;
       style TABLE /
         rules = NONE
         frame = VOID
         cellpadding = 0
         cellspacing = 0
         borderwidth = 1pt;
     end;
  run;


     filename RPTDEL temp;
     ods listing close;
     ods html
        file =RPTDEL
        style=MAIN_DIR;
     title1 j=l "TCMCTN_TRANSACTION Error &sysdate9.";

     proc print
        data=err_lst
        noobs;
     run;
     quit;
     ods html close;
     ods listing;
     run;
     quit;

     %let RPTDEL=%sysfunc(PATHNAME(RPTDEL));
     %let RPT   =%sysfunc(PATHNAME(RPT));

 filename mymail email 'qcpap020@dalcdcp';

  data _null_;
    file mymail

        to =(&PRIMARY_PROGRAMMER_EMAIL)
        subject="HCE SUPPORT: List of Errors on TCMCTN_TRANSACTION Table &sysdate9 "
        attach=( "&RPTDEL" ct='application/xls' ext='xls' );;

    put 'Hello:' ;
    put / "Attached is a list of initiatives(s) that were errored while being updated to mainframe.";
    put / 'Please check the initiative(s) and make needed corrections';
 run;
 quit;
%end;
%mend sent_cmctn_err;

%sent_cmctn_err;
