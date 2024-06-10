/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  benef_to_address.SAS
|
| PURPOSE:  CREATE A MAILING LIST BASED ON GIVEN LIST OF BENEFICIARY_IDs
|
|           A tipical case is appology letter where the beenficiary_ids are provided
|           the program will join it with beneficiary table and get the addresses.
|
| LOCATION: /PRG/sas&sysmode.1/hercules/gen_utilities/sas
|
| INPUT:    tables referenced by macros are not listed here
|           &CLAIMSA..&CLAIM_HIS_TBL
|           &CLAIMSA..TCLIENT1
|           &CLAIMSA..TDRUG1
|
|
| OUTPUT:   STANDARD OUTPUT FILES IN /pending and /results directories
|
+--------------------------------------------------------------------------------
| HISTORY:  AUG 2004 - JOHN HOU
+------------------------------------------------------------------------HEADER*/
%LET err_fl=0;
%set_sysmode;
* %LET DEBUG_FLAG=Y;
* OPTIONS MLOGIC MPRINT SYMBOLGEN;

libname QCPU603 DB2 DSN=&UDBSPRP SCHEMA=QCPU603 DEFER=YES;


 OPTIONS SYSPARM='INITIATIVE_ID=274 PHASE_SEQ_NB=1';
%INCLUDE "/PRG/sas&sysmode.1/hercules/hercules_in.sas";

%LET PROGRAM_NAME=benef_to_address.sas;

%drop_db2_table(tbl_name=QCPAP020.APPLIGY_07_04B);

%drop_db2_table(tbl_name=QCPAP020.APPLIGY_07_04);

PROC SQL;
CONNECT TO DB2 AS DB2 (DSN=&UDBSPRP);
CREATE TABLE QCPAP020.APPLIGY_W_REFIL(BULKLOAD=YES) AS
SELECT * FROM CONNECTION TO DB2

(SELECT CDH_BENEFICIARY_ID,
        PT_BENEFICIARY_ID,
        A.CLT_PLAN_GROUP_ID, max(ANNUAL_FILL_QY) as max_fil,
        max(REFILL_FILL_QY) as max_refil

   FROM QCPU603.PETE_CPG A,
        CLAIMSA.TCPG_PB_TRL_HIST B,
        SUMMARY.TDRUG_COV_LMT_SUMM C


   WHERE A.CLT_PLAN_GROUP_ID = B.CLT_PLAN_GROUP_ID
   AND   B.DELIVERY_SYSTEM_CD = 3
   AND   EFF_DT < CURRENT DATE
   AND   EXP_DT > CURRENT DATE
   AND BILLING_END_MONTH = 200407
                 AND c.DRUG_CATEGORY_ID IN (60, 61, 62)
   AND B.PB_ID=C.PB_ID
   AND B.PB_ID IN
                (SELECT DISTINCT PB_ID
                 FROM SUMMARY.TDRUG_COV_LMT_SUMM
                 WHERE BILLING_END_MONTH = 200407
                 AND DRUG_CATEGORY_ID IN (60, 61, 62)
         AND (ANNUAL_FILL_QY BETWEEN 0 AND 999
              OR REFILL_FILL_QY BETWEEN 0 AND 999 )
             )
  group by  CDH_BENEFICIARY_ID,
        PT_BENEFICIARY_ID,
        A.CLT_PLAN_GROUP_ID
      );
DISCONNECT FROM DB2;
QUIT;

 %get_moc_csphone(tbl_name_in=QCPU603.PETE_CPG, tbl_name_out=QCPAP020.APPLIGY_07_04);



/******


PROC SQL;
CONNECT TO DB2 AS DB2 (DSN=&UDBSPRP);
CREATE TABLE checkAPPLIGY_07_04 AS
SELECT * FROM CONNECTION TO DB2

(SELECT CDH_BENEFICIARY_ID,
        PT_BENEFICIARY_ID, C.*
   FROM QCPU603.PETE_CPG A,
        CLAIMSA.TCPG_PB_TRL_HIST B,
        SUMMARY.TDRUG_COV_LMT_SUMM c

   WHERE A.CLT_PLAN_GROUP_ID = B.CLT_PLAN_GROUP_ID
   AND  B.PB_ID=C.PB_ID
   AND   BILLING_END_MONTH = 200407
   AND   DRUG_CATEGORY_ID IN (60, 61, 62)
   AND   B.DELIVERY_SYSTEM_CD = 3
   AND   EFF_DT < CURRENT DATE
   AND   EXP_DT > CURRENT DATE
   AND B.PB_ID NOT IN
                (SELECT DISTINCT PB_ID
                 FROM SUMMARY.TDRUG_COV_LMT_SUMM
                 WHERE BILLING_END_MONTH = 200407
                 AND DRUG_CATEGORY_ID IN (60, 61, 62)
         AND (ANNUAL_FILL_QY BETWEEN 0 AND 999
              OR REFILL_FILL_QY BETWEEN 0 AND 999 )
             )
      );
DISCONNECT FROM DB2;
QUIT;

*************/

PROC SQL;
     CREATE TABLE FILE_FIELDS AS
     SELECT SEQ_NB,FIELD_NM
     FROM HERCULES.TFIELD_DESCRIPTION A, HERCULES.TFILE_BASE_FIELD B
     WHERE A.FIELD_ID=B.FIELD_ID

      UNION
     SELECT SEQ_NB, FIELD_NM
     FROM HERCULES.TFIELD_DESCRIPTION A, HERCULES.TFILE_FIELD B
     WHERE A.FIELD_ID=B.FIELD_ID
       AND B.FILE_ID=18
     ORDER BY SEQ_NB
     ;
     QUIT;

 PROC SQL NOPRINT;
      SELECT FIELD_NM INTO: FIELD_NMS SEPARATED BY ","
      FROM FILE_FIELDS
      ORDER BY SEQ_NB; QUIT;

 %%PUT &FIELD_NMS;

data _null_;
     set hercules.tphase_rvr_file(where=(initiative_id=&initiative_id));
     call symput('cmctn_role_cd', trim(left(cmctn_role_cd))); run;
 %let cmctn_role_cd=&cmctn_role_cd;

PROC SQL;
           CONNECT TO DB2 (DSN=&UDBSPRP);
           CREATE TABLE org&table_prefix._&cmctn_role_cd AS
           SELECT * FROM CONNECTION TO DB2
            (SELECT      CLIENT_ID,
                           106 AS PROGRAM_ID,
                           '005129' AS APN_CMCTN_ID,
                             A.CDH_BENEFICIARY_ID AS RECIPIENT_ID,
                             A.PT_BENEFICIARY_ID AS SUBJECT_ID,
                               BNF.BNF_LAST_NM as RVR_LAST_NM,
                               BNF.BNF_FIRST_NM AS RVR_FIRST_NM,
                               ADDRESS1_TX,
                               ADDRESS2_TX,
                               ADDRESS3_TX,
                               STATE,
                               CITY_TX,
                               ZIP_CD,
                               ZIP_SUFFIX_CD,
                               CS_AREA_PHONE,
                               1 AS DATA_QUALITY_CD

                FROM        QCPAP020.APPLIGY_07_04 A,
                             &CLAIMSA..VBENEF_BENEFICIARY BNF
                WHERE    A.PT_BENEFICIARY_ID = BNF.BENEFICIARY_ID
                 AND CLIENT_ID=142
                );
          DISCONNECT FROM DB2;
          QUIT;


PROC SORT DATA=org&table_prefix._&cmctn_role_cd out=&table_prefix._&cmctn_role_cd  nodupkey ;
      BY client_id recipient_id subject_id; RUN;

PROC SQL;
     CREATE TABLE data_pnd.&table_prefix._&cmctn_role_cd AS
     SELECT A.SUBJECT_ID, B.*, A.CS_AREA_PHONE, A.DATA_QUALITY_CD
   FROM
   &table_prefix._&cmctn_role_cd a, DATAPND.SBC_apology_8_18_04 B
   WHERE SUBJECT_ID=INPUT(B.RECIPIENT_ID,10.); QUIT;

/*** REMOVE CLIENTS THAT HAVE BEEN SETUP IN THE HERCULES.TCLT_BSRL_OVRD **/

proc sql noprint;
     select client_id into:client_exlude separated by ","
     from  HERCULES.TCLT_BSRL_OVRD_his
     where bus_rule_type_cd=1
       AND PROGRAM_ID=72
       AND EXPIRATION_TS>DATETIME();
    quit;
 %put &client_exlude;


Proc sql;
     create table data_pnd.&table_prefix._&cmctn_role_cd AS
     select *
     from &table_prefix._&cmctn_role_cd; quit;


      proc sql;
           create table stats_al as
           select count(distinct recipient_id) as letters
            from data_pnd.&table_prefix._&cmctn_role_cd ; quit;

data data_res.&table_prefix._&cmctn_role_cd;
     set  data_pnd.&table_prefix._&cmctn_role_cd; run;

proc sql noprint;
     select count(*) into: rcrds_cnt
     from data_pnd.&table_prefix._&cmctn_role_cd; quit;


      proc sql;
           create table stats as
           select client_id, count(distinct recipient_id) as letters
            from &table_prefix._&cmctn_role_cd
           group by client_id; quit;

   filename test ftp "/users/patientlist/CUSTOM_MAILINGS/mailing/&table_prefix._&cmctn_role_cd.apology1_by_client.txt"
            mach='sfb006.psd.caremark.int' RECFM=v ;


   %export_sas_to_txt(tbl_name_in=stats,
                       tbl_name_out=test,
                       l_file="layout_out",
                       File_type_out='DEL|',
                       Col_in_fst_row=Y);



      filename ftp_txt ftp "/users/patientlist/CUSTOM_MAILINGS/mailing/&table_prefix._&cmctn_role_cd.SBCapology_07_04.txt"
            mach='sfb006.psd.caremark.int' RECFM=v ;


    %export_sas_to_txt(tbl_name_in=data_pnd.&table_prefix._&cmctn_role_cd ,
                       tbl_name_out=ftp_txt,
                       l_file="layout_out",
                       File_type_out='DEL|',
                       Col_in_fst_row=Y);

   filename mymail email 'qcpap020@dalcdcp';
     data _null_;
        file mymail
            to=('Sherri.Duncan@caremark.com')
            subject="ADHOC Mailing: Apology Letter 005128" ;

        put 'Hi, All:' ;
        put / "This is an automatically generated message to inform you that the adhoc mailing file for 005128 has been processed.";
        put "There are %cmpres(&rcrds_cnt) records in the file and can be accessed by clicking the link: ";
        put / "\\sfb006\PatientList\CUSTOM_MAILINGS\mailing\&table_prefix._&cmctn_role_cd.apology_07_04.txt";
        put / "\\sfb006\PatientList\CUSTOM_MAILINGS\mailing\&table_prefix._&cmctn_role_cd.apology_byclient.txt";

        put / 'Please review the listing and let us know of any questions.';
        put / 'Thanks,';
        put / 'HERCULES Production Supports';
      run;
      quit;

   libname archive '/DATA/sasprod1/hercules/106/archive';

 data SBC_apology_8_18_04;
      set data_pnd.SBC_apology_8_18_04;
      SUBJECT_ID=input(RECIPIENT_id, 10.); run;



  proc sql;
       create table  temp as
       select a.*
       from  data_pnd.SBC_apology_8_18_04 a
           where not exists
            (select 1 from  data_pnd.&table_prefix._&cmctn_role_cd b

            where b.subject_id=a.recipient_id
                )
           ; quit;

PROC SORT DATA= SBC_apology_8_18_04(keep=SUBJECT_ID);
     BY SUBJECT_ID; RUN;
PROC SORT DATA= data_pnd.&table_prefix._&cmctn_role_cd;
     BY SUBJECT_ID; RUN;

 data temp;
      merge  SBC_apology_8_18_04 (in=a )
              data_pnd.&table_prefix._&cmctn_role_cd(in=b);
       by SUBJECT_id;
      if a and not b; run;

   data temp;
      merge  SBC_apology_8_18_04 (in=a )
              data_pnd.&table_prefix._&cmctn_role_cd(in=b);
       by SUBJECT_id;
      if a and not b; run;


PROC SQL;
     CREATE TABLE TEMP AS
     SELECT * FROM
  QCPAP020.APPLIGY_07_04B A, SBC_apology_8_18_04 B
   WHERE PT_BENEFICIARY_ID=SUBJECT_ID; QUIT;

   PROC SQL;
CONNECT TO DB2 AS DB2 (DSN=&UDBSPRP);
CREATE TABLE APPLIGY_sbc_w_lmt AS
SELECT * FROM CONNECTION TO DB2

(SELECT CDH_BENEFICIARY_ID,
        PT_BENEFICIARY_ID,
        A.CLT_PLAN_GROUP_ID

   FROM QCPU603.PETE_CPG A,
        CLAIMSA.TCPG_PB_TRL_HIST B

   WHERE A.CLT_PLAN_GROUP_ID = B.CLT_PLAN_GROUP_ID
   AND   B.DELIVERY_SYSTEM_CD = 3
   AND   EFF_DT < CURRENT DATE
   AND   EXP_DT > CURRENT DATE
   AND B.PB_ID IN
                (SELECT DISTINCT PB_ID
                 FROM SUMMARY.TDRUG_COV_LMT_SUMM
                 WHERE BILLING_END_MONTH = 200407
                 AND DRUG_CATEGORY_ID IN (60, 61, 62)
         AND (ANNUAL_FILL_QY BETWEEN 0 AND 999
              OR REFILL_FILL_QY BETWEEN 0 AND 999 )
             )
      );
DISCONNECT FROM DB2;
QUIT;

 PROC SQL;
     CREATE TABLE TEMP AS
     SELECT * FROM
   QCPAP020.APPLIGY_W_REFIL A, DATAPND.SBC_apology_8_18_04 B
   WHERE PT_BENEFICIARY_ID=INPUT(RECIPIENT_ID,10.); QUIT;



      filename ftp_txt ftp "/users/patientlist/CUSTOM_MAILINGS/mailing/&table_prefix._&cmctn_role_cd.SBCapology_07_04.txt"
            mach='sfb006.psd.caremark.int' RECFM=v ;


    %export_sas_to_txt(tbl_name_in=TEMP,
                       tbl_name_out=ftp_txt,
                       l_file="layout_out",
                       File_type_out='DEL|',
                       Col_in_fst_row=Y);
