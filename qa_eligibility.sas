
proc sql;
      connect to db2 (dsn=&udbsprp);
  create table elig_chk as
  select * from connection to db2
    (select a.*
      from claimsa.telig_detail_his a,
           qcpap020.t_130_1cpg_elig b
      where a.pt_beneficiary_id =b.pt_beneficiary_id
         and a.cdh_beneficiary_id =b.cdh_beneficiary_id
         and a.clt_plan_group_id=b.clt_plan_group_id
         and effective_dt >= '01-01-2005'
         and expiration_dt >=  '01-01-2005' );
  disconnect from db2;
   quit;

proc sort data=qcpap020.t_130_1cpg_elig  out=da;
      by cdh_beneficiary_id pt_beneficiary_id clt_plan_group_id;
      run;

proc sort data=elig_chk;
      by cdh_beneficiary_id pt_beneficiary_id clt_plan_group_id;
      run;



 data qcpap020.out_pt;
      merge da(in=a)
            elig_chk (in=b);
      by cdh_beneficiary_id pt_beneficiary_id clt_plan_group_id;
      if a and not b;
       run;

  proc sql;
      connect to db2 (dsn=&udbsprp);
  create table elig_chk as
  select * from connection to db2
    (select a.*
      from claimsa.telig_detail_his a,
           qcpap020.out_pt b
      where a.pt_beneficiary_id =b.pt_beneficiary_id
         and a.cdh_beneficiary_id =b.cdh_beneficiary_id
         and a.clt_plan_group_id=b.clt_plan_group_id );
  disconnect from db2;
   quit;

  proc sql;
       create table tst as
       select a.*, b.* from data_pnd.t_130_1_1 a left join elig_chk b
       on a.recipient_id=b.pt_beneficiary_id; quit;


   %MACRO eligibility_check(tbl_name_in=qcpap020.t_130_1pt_drug_group_e,
             tbl_name_out=,chk_dt='01JAN2005'd,CLAIMSA=CLAIMSA,
                                                Execute_condition=%STR(1=1),
                                                tbl_name_out2=);
   %GLOBAL SQLRC SQLXRC;


   %IF &tbl_name_out= %THEN %LET TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX.CPG_ELIG;

   %IF &chk_dt= %THEN %DO;
    %table_properties(tbl_name=&CLAIMSA..TELIG_DETAIL_HIS,PRINT=NOPRINT);
    %LET chk_dt=%STR(DATEPART(INPUT(TRIM(LEFT("&_STATS_TIME")),DATETIME21.)));
                                        %END;
   /* %IF &chk_dt= %THEN %LET chk_dt=%STR(TODAY()); */
   DATA _NULL_;
    LENGTH date 8 ;
    date=&chk_dt;
    IF date=. THEN date=TODAY();
    CALL SYMPUT('chk_dt_db2',"'" || PUT(date, MMDDYY10.) || "'");
   RUN;
   /*
   DATA _NULL_;
    LENGTH date 8 date_time_c $ 50 chk_dt_c $ 20;
    chk_dt_c="&chk_dt";
    IF chk_dt_c='' THEN
                                        DO;
    date_time_c=LEFT("&_STATS_TIME");
    date=DATEPART(INPUT(TRIM(LEFT(date_time_c)),DATETIME21.));
                                    END;
     ELSE date=chk_dt_c;
    IF date=. THEN date=TODAY();
    CALL SYMPUT('chk_dt_db2',"'" || PUT(date, MMDDYY10.) || "'");
    CALL SYMPUT('chk_dt',date);
   RUN;
   */

    %set_error_fl;
   %PUT chk_dt_db2=&chk_dt_db2;

    %LET pos=%INDEX(&Tbl_name_in,.);
    %LET Schema=%SUBSTR(&Tbl_name_in,1,%EVAL(&pos-1));
    %LET Tbl_name_in_sh=%SUBSTR(&Tbl_name_in,%EVAL(&pos+1));

    %LET pos=%INDEX(&Tbl_name_out,.);
    %LET Schema=%SUBSTR(&Tbl_name_out,1,%EVAL(&pos-1));
    %LET Tbl_name_out_sh=%SUBSTR(&Tbl_name_out,%EVAL(&pos+1));

   PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
     CREATE TABLE WORK.&Tbl_name_out_sh AS
                 SELECT DISTINCT * FROM CONNECTION TO DB2
      (

                WITH PTS  AS
                ( SELECT CDH_BENEFICIARY_ID,
                                 PT_BENEFICIARY_ID,COUNT(*) AS COUNT
               FROM &Tbl_name_in
                                 GROUP BY CDH_BENEFICIARY_ID,
                                              PT_BENEFICIARY_ID
                )
                SELECT          A.CDH_BENEFICIARY_ID                                     AS CDH_BENEFICIARY_ID,
                       A.PT_BENEFICIARY_ID,
       COALESCE(D.CLT_PLAN_GROUP_ID,B.CLT_PLAN_GROUP_ID)                 AS CLT_PLAN_GROUP_ID,
                                        MIN(D.EFFECTIVE_DT)      AS EFFECTIVE_DT ,
                                        MAX(D.EXPIRATION_DT)     AS EXPIRATION_DT,
                                        MIN(B.EFFECTIVE_DT)      AS CDH_EFFECTIVE_DT ,
                                        MAX(B.EXPIRATION_DT)     AS CDH_EXPIRATION_DT
                   FROM  (PTS                                             A             INNER JOIN
                          &CLAIMSA..TELIG_DETAIL_HIS B
                            ON A.CDH_BENEFICIARY_ID = B.CDH_BENEFICIARY_ID
                           AND B.EFFECTIVE_DT <= &chk_dt_db2
                           AND B.EXPIRATION_DT > &chk_dt_db2
                                                AND B.PT_BENEFICIARY_ID=B.pt_BENEFICIARY_ID
                                          )                                                                     LEFT JOIN
                                                        &CLAIMSA..TELIG_DETAIL_HIS D
                               ON A.PT_BENEFICIARY_ID = D.PT_BENEFICIARY_ID
                GROUP BY A.CDH_BENEFICIARY_ID,A.PT_BENEFICIARY_ID, COALESCE(D.CLT_PLAN_GROUP_ID,B.CLT_PLAN_GROUP_ID)
                )
         ORDER BY  CDH_BENEFICIARY_ID,PT_BENEFICIARY_ID,EFFECTIVE_DT,EXPIRATION_DT,CLT_PLAN_GROUP_ID
        ;
    DISCONNECT FROM DB2;
    QUIT;
     %set_error_fl;
    DATA WORK.&Tbl_name_out_sh.1;
     SET WORK.&Tbl_name_out_sh;
      BY CDH_BENEFICIARY_ID PT_BENEFICIARY_ID EFFECTIVE_DT EXPIRATION_DT;
       IF last.PT_BENEFICIARY_ID;
     IF EXPIRATION_DT=. OR EXPIRATION_DT > &chk_dt;
     IF EFFECTIVE_DT >=&CHK_DT;
   RUN;
   %mend;
   %eligibility_check;
