%include '/user1/qcpap020/autoexec_new.sas'; 

/***HEADER -------------------------------------------------------------------------
 |  PROGRAM NAME:     ACT_MAILING.SAS
 |
 |  PURPOSE:    TARGETS A CLIENT WHO WOULD LIKE A AUTOMATIC CONTINUALTION OF THERAPY MAILING.
 |              THE INTENT OF THIS MAILING IS THAT IT IS A ONE TIME MAILING PER CLIENT, BUT 
 |              IT CAN BE RUN MULTIPLE TIMES AS IT WILL ONLY SEND A MAILING ONCE PER HOUSEHOLD.
 |              -- select client and CPGs
 |              -- select NDCs (maintenance and expanded maintenance) excluding controlled substances
 |              -- get 120 day mail claims - default - can be overrided in HCE setup 
 |              -- Apply participant parameters
 |              -- Do not send mailing to cardholders who have previously received this mailing
 |
 |  INPUT:      UDB Tables accessed by macros are not listed                      
 |                 &hercules..TCMCTN_RECEIVR_HIS,
 |                 &hercules..TINITIATIVE,
 |                 &claimsa..TCLIENT1,
 |                 &claimsa.trxclm_base,
 |                 &hercules..TREPORT_REQUEST
 |
 |  OUTPUT:     Standard datasets in /results and /pending directories 
 |
 |  HISTORY:    December 04, 2008 - Ron Smith - Hercules Version 2.1.01
 |                            New mailing - Initial implementation
 |              February 05, 2009 - Ron Smith - Hercules Version 2.1.02
 |                            Added index to temporary NDC table when initiative
 |                            is run for QL to correct performance issue.
 |              5/30/12 - Paul Landis - Hercules Version 2.1.03
 |                        Converted to reference new hercdev2 library
 +-------------------------------------------------------------------------------HEADER*/

%LET ERR_FL=0;
%set_sysmode;
OPTIONS SYSPARM='initiative_id=  phase_seq_nb=1';
options mprint mprintnest mlogic mlogicnest symbolgen source2;
%GLOBAL CLAIM_REVIEW_DAYS ACT_ADJ; 
%LET PROGRAM_NAME=act_mailing;

%include "/herc&sysmode/prg/hercules/hercules_in.sas" /;

*SASDOC-------------------------------------------------------------------------
| Update the job complete timestamp.
+-----------------------------------------------------------------------SASDOC*;
%update_task_ts(START, INIT_ID=&INITIATIVE_ID);

*SASDOC-------------------------------------------------------------------------
| Assign Email address for the initiative
+-----------------------------------------------------------------------SASDOC*;
proc sql;
  select QUOTE(TRIM(email)) into :primary_programmer_email
  from ADM_LKP.ANALYTICS_USERS 
  where UPCASE(QCP_ID) in ("&USER"); 
quit;

%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
    EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
    EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");

%put NOTE: primary_programmer_email = &primary_programmer_email;

*SASDOC--------------------------------------------------------------------------
| SET macro variable ACT_ADJ for depending on engine running
+------------------------------------------------------------------------SASDOC*;
%macro set_adj_engine;
  %IF &QL_ADJ = 1 %THEN %DO;
    %LET ACT_ADJ = QL;
  %END;
  %ELSE %IF &RX_ADJ = 1 %THEN %DO;
          %LET ACT_ADJ = RX;
        %END;
        %ELSE %IF &RE_ADJ = 1 %THEN %DO;
                %LET ACT_ADJ = RE;
              %END;
%mend set_adj_engine;
%set_adj_engine;

%PUT NOTE: ACT_ADJ = &ACT_ADJ;

*SASDOC --------------------------------------------------------------------
|  Assign the communication role code and CLAIM_REVIEW_DAYS for the initiative. 
|  Note: ACT_NBR_OF_DAYS defaults to 120 and can be overriden in HCE 
+-------------------------------------------------------------------SASDOC*;
data _null;
    set &hercules..tphase_rvr_file(where=(initiative_id=&initiative_id));
    call symput('cmctn_role_cd',put(cmctn_role_cd,1.));
    call symput('CLAIM_REVIEW_DAYS',put(ACT_NBR_OF_DAYS,11.));
run;
%put cmctn_role_cd = &cmctn_role_cd;
%PUT CLAIM_REVIEW_DAYS = &CLAIM_REVIEW_DAYS;

%set_error_fl;

*SASDOC--------------------------------------------------------------------------
| Call %resolve_client
| Retrieve all client ids that are included in the mailing.  If a client is
| partial, this will be handled after determining current eligibility.
+------------------------------------------------------------------------SASDOC*;
%resolve_client(TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CLT_CPG_QL,
                TBL_NAME_OUT_RX=&ORA_TMP..&TABLE_PREFIX._CLT_CPG_RX,
                TBL_NAME_OUT_re=&ORA_TMP..&TABLE_PREFIX._CLT_CPG_RE
               );

*SASDOC--------------------------------------------------------------------------
| Call %get_ndc to determine the maintenance NDCs
| This mailing program uses all maintenance drugs
+------------------------------------------------------------------------SASDOC*;
%get_ndc(DRUG_NDC_TBL=&DB2_TMP..&TABLE_PREFIX._NDC_QL,
         DRUG_NDC_TBL_rx=&ora_TMP..&TABLE_PREFIX._NDC_RX,
         DRUG_NDC_TBL_re=&ora_TMP..&TABLE_PREFIX._NDC_RE
        );

*SASDOC--------------------------------------------------------------------------
| Create Begin and End claim review dates
+------------------------------------------------------------------------SASDOC*;
data _NULL_;  
  CALL SYMPUT('CLAIMS_BGN_DT',PUT((TODAY()-&CLAIM_REVIEW_DAYS), YYMMDD10.));  	  
  CALL SYMPUT('CLAIMS_END_DT',PUT(TODAY(),YYMMDD10.)); 
RUN;

%PUT NOTE: CLAIMS_BGN_DT     = &CLAIMS_BGN_DT;
%PUT NOTE: CLAIMS_END_DT     = &CLAIMS_END_DT;

*SASDOC --------------------------------------------------------------------
| Identify the maintenance ql claims during the last &claim_review_days
+--------------------------------------------------------------------SASDOC*;
%macro pull_claims_ql(cpg_tbl_name_in=,
                   ndc_tbl_name_in=,
                   tbl_name_out=
                  );

%if &ql_adj = 1 %then %do;

  data _NULL_;
    %IF &RESOLVE_CLIENT_EXCLUDE_FLAG = 1 %THEN %DO;  
        CALL SYMPUT('CLIENT_COND',TRIM(LEFT("NOT EXISTS")));
      %END;
    %ELSE 
      %IF &RESOLVE_CLIENT_EXCLUDE_FLAG = 0 %THEN  %DO;
          CALL SYMPUT('CLIENT_COND',TRIM(LEFT("EXISTS")));
        %END;
  RUN;

  %LET WHERECONS = %STR( 	AND &CLIENT_COND. (select 1 from &CPG_TBL_NAME_in. CLT 
                          where A.CLT_PLAN_GROUP_ID = CLT.CLT_PLAN_GROUP_ID ));

  %PUT NOTE: WHERECONS = &WHERECONS;

*SASDOC --------------------------------------------------------------------
| Create index on temporary NDC table for performance for QL initiatives
| 05FEB2009 RS
+--------------------------------------------------------------------SASDOC*;
  proc sql;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
    EXECUTE(CREATE INDEX &ndc_tbl_name_in.X1
                on &ndc_tbl_name_in.
                   (NHU_TYPE_CD,
                    DRUG_NDC_ID)
           ) 
         BY DB2;
    DISCONNECT from DB2;
  quit;

  %grant(tbl_name=&ndc_tbl_name_in.); 
  %runstats(TBL_NAME=&ndc_tbl_name_in.);  

*SASDOC --------------------------------------------------------------------
| Identify the maintenance Rx claims filled between claim begin and claim end
| dates for client requested 
+--------------------------------------------------------------------SASDOC*;
  %drop_db2_table(tbl_name=&tbl_name_out.);

  proc sql;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
    EXECUTE(CREATE TABLE &tbl_name_out.
           (PT_BENEFICIARY_ID  INTEGER NOT NULL,
            CDH_BENEFICIARY_ID INTEGER NOT NULL,
            CLIENT_ID          INTEGER NOT NULL, 
            CLIENT_NM          CHAR(30) NOT NULL, 
            CLT_PLAN_GROUP_ID2 INTEGER NOT NULL,
            RX_COUNT_QY        INTEGER NOT NULL,
            DRG_GROUP_SEQ_NB   INTEGER NOT NULL 
            ) NOT LOGGED INITIALLY) BY DB2;
    DISCONNECT from DB2;
  quit;

  /* extract maintenance claims */
  proc sql;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
    EXECUTE(ALTER TABLE &tbl_name_out.
            ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;

    EXECUTE(INSERT into &tbl_name_out.
            select DISTINCT
              A.PT_BENEFICIARY_ID,
              A.CDH_BENEFICIARY_ID,
              A.CLIENT_ID, 
              D.CLIENT_NM,
              A.CLT_PLAN_GROUP_ID AS CLT_PLAN_GROUP_ID2,
              COUNT(*) as RX_COUNT_QY,
              1 AS DRG_GROUP_SEQ_NB
            from &claimsa..&claim_his_tbl A, /* claims */
                 &ndc_tbl_name_in. B, /* all maintenance drugs */              
                 &claimsa..TCLIENT1 D
            where A.FILL_DT BETWEEN %BQUOTE('&CLAIMS_BGN_DT') 
                                AND %BQUOTE('&CLAIMS_END_DT') 
             AND A.BILLING_END_DT IS NOT NULL
             AND A.DELIVERY_SYSTEM_CD = 2  /*mail order only*/
			&whereCONS.
             AND A.CLIENT_ID   = D.CLIENT_ID
             AND A.DRUG_NDC_ID = B.DRUG_NDC_ID
             AND A.NHU_TYPE_CD = B.NHU_TYPE_CD          
           GROUP BY A.PT_BENEFICIARY_ID,
              A.CDH_BENEFICIARY_ID,
              A.CLIENT_ID, 
              D.CLIENT_NM,
              CLT_PLAN_GROUP_ID                           
      )BY DB2;

    %let _CLAIM_TBL_SYSDBRC=&SYSDBRC;

    EXECUTE
      (
      COMMIT
      ) by DB2;

    select CLAIM_ROW_COUNT
    into :CLAIM_ROW_COUNT
    from CONNECTION TO DB2
      (
       select COUNT(*) AS CLAIM_ROW_COUNT
       from   &tbl_name_out.
      );
    DISCONNECT from DB2;
  quit;
  
  %if (&_CLAIM_TBL_SYSDBRC eq 0) %then
    %do;
      %put NOTE: %cmpres(&CLAIM_ROW_COUNT) rows inserted into &tbl_name_out; 
      %grant(tbl_name=&tbl_name_out); 
      %RUNSTATS(TBL_NAME=&tbl_name_out.);      
    %end;
  %else
    %do;
      %if (&_CLAIM_TBL_SYSDBRC eq 100 ) %then
        %do;
          %put NOTE: empty &tbl_name_out table;
          %let err_fl=1;
          %drop_db2_table(tbl_name=&tbl_name_out);
          %set_error_fl;
          %on_error(ACTION=ABORT, EM_TO=&primary_programmer_email.,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend Pull Claims Macro",
          EM_MSG="No Claims were found.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");
        %end;
      %else
        %do;
          %let err_fl=1;
          %drop_db2_table(tbl_name=&tbl_name_out);
        %end;
    %end;   %*if (&_CLAIM_TBL_SYSDBRC eq 0);
  
  %set_error_fl;
  %on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
      EM_SUBJECT="HCE SUPPORT:  Notification of Abend Pull Claims Macro",
      EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");

%end; /* QL ADJ = 1 */
%mend pull_claims_ql;

%pull_claims_ql(cpg_tbl_name_in=&DB2_TMP..&TABLE_PREFIX._CLT_CPG_QL,
                ndc_tbl_name_in=&DB2_TMP..&TABLE_PREFIX._NDC_QL, 
                tbl_name_out=&DB2_TMP..CLAIMS_PULL_&INITIATIVE_ID._QL
               );

*SASDOC--------------------------------------------------------------------------
| Insert row into HERCULES.TDELIVERY_SYS_EXCL to exclude retail claims
| Note: EDW does not have paper claims
+------------------------------------------------------------------------SASDOC*;
%macro load_edw_exclude;

%IF &RX_ADJ. = 1 OR &RE_ADJ. = 1 %THEN %DO;
  /* This check for reruns - Only add row if no row exists */
  proc sql;
    select COUNT(*) into :DELIVERY_EXCLUDES
    from &hercules..TDELIVERY_SYS_EXCL
    where DELIVERY_SYSTEM_CD = 3
      AND INITIATIVE_ID = &INITIATIVE_ID.;
  quit;
  
  %IF &DELIVERY_EXCLUDES = 0 %THEN %DO;
    proc sql;    
      INSERT into &hercules..TDELIVERY_SYS_EXCL
        (DELIVERY_SYSTEM_CD,INITIATIVE_ID, HSC_USR_ID, HSC_TS, HSU_USR_ID, HSU_TS )
      VALUES
        (3, &INITIATIVE_ID.,"&USER"  , %SYSFUNC(DATETIME()), "&USER", %SYSFUNC(DATETIME()));
    quit;
  %END;
%END;

%mend load_edw_exclude;
%load_edw_exclude;

*SASDOC--------------------------------------------------------------------------
| CALL CLAIMS_PULL_EDW MACRO in ORDER TO PULL CLAIMS INFORMATION from EDW.	
+------------------------------------------------------------------------SASDOC*;
%CLAIMS_PULL_EDW(DRUG_NDC_TABLE_RX = &ORA_TMP..&TABLE_PREFIX._NDC_RX, 
                 DRUG_NDC_TABLE_RE = &ORA_TMP..&TABLE_PREFIX._NDC_RE, 
                 RESOLVE_CLIENT_TABLE_RX = &ORA_TMP..&TABLE_PREFIX._CLT_CPG_RX,
                 RESOLVE_CLIENT_TABLE_RE = &ORA_TMP..&TABLE_PREFIX._CLT_CPG_RE,
                 CLM_BEGIN_DT = %STR(&CLAIMS_BGN_DT), 
                 CLM_END_DT   = %STR(&CLAIMS_END_DT)
                 );
*SASDOC-------------------------------------------------------------------------
| Determine eligibility for the cardholdler as well as participant (if
| available).
| Pass new input and output names for Recap and Rxclaim
+-----------------------------------------------------------------------SASDOC*;
%eligibility_check(TBL_NAME_in=&DB2_TMP..CLAIMS_PULL_&INITIATIVE_ID._QL,
                   TBL_NAME_in_RX=&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX, 
                   TBL_NAME_in_RE=&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RE, 
                   tbl_name_out=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG_QL_H,
                   tbl_name_out2=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG_QL,
                   tbl_name_rx_out2=&ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RX,
                   tbl_name_re_out2=&ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RE,
                    CLAIMSA=&CLAIMSA);

*SASDOC--------------------------------------------------------------------------
| CALL %get_moc_phone
| Add the Mail Order pharmacy and customer service phone to the cpg elig file
+------------------------------------------------------------------------SASDOC*;
%macro process_moc;

%IF &QL_ADJ = 1 %THEN %DO;
  %get_moc_csphone(MODULE=&ACT_ADJ.,
                 TBL_NAME_in=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG_&ACT_ADJ.,
                 TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CLAIMS_MOC_&ACT_ADJ.);
%END;
%IF &RX_ADJ = 1 OR &RE_ADJ = 1 %THEN %DO;
    %get_moc_csphone(MODULE=&ACT_ADJ.,
                 TBL_NAME_in=&ORA_TMP..&TABLE_PREFIX._CPG_ELIG_&ACT_ADJ.,
                 TBL_NAME_OUT=&ORA_TMP..&TABLE_PREFIX._CLAIMS_MOC_&ACT_ADJ.);
%END;

%mend process_moc;
%process_moc;

*SASDOC--------------------------------------------------------------------------
| process participant parms for all adjudications.
| Note: Participant parms only handles DB2 data
| This needs to be done before combining claims files - Still at patient level
+------------------------------------------------------------------------SASDOC*;
%macro process_part_parms;

%IF &QL_ADJ = 1 %THEN %DO;
  %participant_parms(tbl_name_in=&DB2_TMP..&TABLE_PREFIX._CLAIMS_MOC_&ACT_ADJ.,
                     tbl_name_out2=&DB2_TMP..&TABLE_PREFIX._CLAIMS_PT);
%END;

/* For RX and RECAP create DB2 table for Participant Parms Macro */
/* CREATE SAS dataSET FIRST */
%IF &RX_ADJ. = 1 OR &RE_ADJ. = 1 %THEN %DO;

  /* copy Oracle table to SAS dataset */
  data PARTICIPANT_in (KEEP = PT_BENEFICIARY_ID RX_COUNT_QY 
                              DRG_GROUP_SEQ_NB EDW_PT_BENEFICIARY_ID);
    FORMAT PT_BENEFICIARY_ID2 12. DRG_GROUP_SEQ_NB 4.;
    SET &ORA_TMP..&TABLE_PREFIX._CLAIMS_MOC_&ACT_ADJ.;
    EDW_PT_BENEFICIARY_ID = PT_BENEFICIARY_ID;
    PT_BENEFICIARY_ID2 = INPUT(PT_BENEFICIARY_ID,12.);
    DRG_GROUP_SEQ_NB = 1;  
 
    DROP PT_BENEFICIARY_ID;
    RENAME 	PT_BENEFICIARY_ID2 = PT_BENEFICIARY_ID;     
  RUN;

  /* Load DB2 TABLE */
  %drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS_MOC_&ACT_ADJ.);  
  data &DB2_TMP..&TABLE_PREFIX._CLAIMS_MOC_&ACT_ADJ.;
    SET PARTICIPANT_in;
  RUN;

  /* Call participant parms - requires DB2 table */
  %participant_parms(tbl_name_in=&DB2_TMP..&TABLE_PREFIX._CLAIMS_MOC_&ACT_ADJ.,
                     tbl_name_out2=&DB2_TMP..&TABLE_PREFIX._CLAIMS_PT);

  /* Create output SAS dataset with participants to keep */
  proc sql NOPRINT;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
      CREATE TABLE PARTICIPANT_OUT AS
      select * from CONNECTION TO DB2
      (select DISTINCT EDW_PT_BENEFICIARY_ID AS PT_BENEFICIARY_ID
       from &DB2_TMP..&TABLE_PREFIX._CLAIMS_PT);
    DISCONNECT from DB2;
  quit;
   
  /* CREATE Oracle TABLE with participants to keep */ 
  %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._CLAIMS_PT);  
  data &ORA_TMP..&TABLE_PREFIX._CLAIMS_PT;
    SET PARTICIPANT_OUT;
  RUN;

  /* Create final Oracle table with participants that match participant parms */
  %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._CLAIMS_PT_&ACT_ADJ.);  
  proc sql;
    CREATE TABLE &ORA_TMP..&TABLE_PREFIX._CLAIMS_PT_&ACT_ADJ.
            LIKE &ORA_TMP..&TABLE_PREFIX._CLAIMS_MOC_&ACT_ADJ.;
  quit; 
  proc sql;
    CONNECT TO ORACLE(PATH=&GOLD ); 
    EXECUTE(INSERT into &ORA_TMP..&TABLE_PREFIX._CLAIMS_PT_&ACT_ADJ.
            select A.* 
            from &ORA_TMP..&TABLE_PREFIX._CLAIMS_MOC_&ACT_ADJ. A,
                 &ORA_TMP..&TABLE_PREFIX._CLAIMS_PT B
            where A.PT_BENEFICIARY_ID = B.PT_BENEFICIARY_ID            
           ) BY ORACLE;
    DISCONNECT from ORACLE;    
  quit;

  %set_error_fl;
  %on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
      EM_SUBJECT="HCE SUPPORT:  Notification of Abend - process Part Parms Macro",
      EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");

%END; /* IF RX or RE Adj */

%mend process_part_parms;
%process_part_parms;

*SASDOC-------------------------------------------------------------------------
| Condense mailing tables to CDH_BENEFICIARY level
+-----------------------------------------------------------------------SASDOC*;
%macro summarize_to_household;

%IF &QL_ADJ = 1 %THEN %DO;

  %drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS_ACT_&ACT_ADJ.);
  
  proc sql;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
    EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS_ACT_&ACT_ADJ.
      (CDH_BENEFICIARY_ID	INTEGER NOT NULL,
       CLIENT_ID         	INTEGER NOT NULL, 
       CLIENT_NM         	CHARACTER(30) NOT NULL,           
       CLT_PLAN_GROUP_ID 	INTEGER,
       MOC_PHM_CD        	CHARACTER(3),
       CS_AREA_PHONE     	CHARACTER(13) NOT NULL,
       LTR_RULE_SEQ_NB    SMALLINT, /* added for create base file */
       PT_BENEFICIARY_ID  INTEGER,
       ADJ_ENGINE         CHARACTER(2),
       CLIENT_LEVEL_1     CHARACTER(22),
       CLIENT_LEVEL_2     CHARACTER(22),
       CLIENT_LEVEL_3     CHARACTER(22))
       NOT LOGGED INITIALLY) BY DB2;
    DISCONNECT from DB2;
  quit;

  proc sql;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
    EXECUTE(ALTER TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS_ACT_&ACT_ADJ.
            ACTIVATE NOT LOGGED INITIALLY ) BY DB2;
          
    EXECUTE(INSERT into &DB2_TMP..&TABLE_PREFIX._CLAIMS_ACT_&ACT_ADJ.
            select DISTINCT
              CDH_BENEFICIARY_ID,
              CLIENT_ID, 
              CLIENT_NM,              
              CLT_PLAN_GROUP_ID,
              MOC_PHM_CD,
              CS_AREA_PHONE,
              0,
              CDH_BENEFICIARY_ID, /* for RX and RE - NA for QL but still need field */
              %BQUOTE('&ACT_ADJ'),
              CHAR(CLT_PLAN_GROUP_ID),
              ' ',
              ' '
            from &DB2_TMP..&TABLE_PREFIX._CLAIMS_PT          
           ) BY DB2;
    DISCONNECT from DB2;
  quit;

  %set_error_fl;
  %on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,   
      EM_SUBJECT="HCE SUPPORT:  Notification of Abend - act_elig_households Macro",
      EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");
%END;

*SASDOC--------------------------------------------------------------------------
| IF EDW THEN CALL HEAD_OF_HOUSEHOLD MACRO in ORDER CREATE ONE MAILING PER HOUSEHOLD	
+------------------------------------------------------------------------SASDOC*;
%IF &RX_ADJ. = 1 OR &RE_ADJ. = 1 %THEN %DO;
  %HEAD_OF_HOUSEHOLD(TBL_NM_in = &ORA_TMP..&TABLE_PREFIX._CLAIMS_PT_&ACT_ADJ.,
                     TBL_NM_OUT = &ORA_TMP..&TABLE_PREFIX._CLAIMS_ACT_&ACT_ADJ.);
%END;

%mend summarize_to_household;
%summarize_to_household;

*SASDOC--------------------------------------------------------------------------
| Load all adjudication platform files
+------------------------------------------------------------------------SASDOC*;
%macro load_adj;

%IF &ql_adj eq 1 %THEN %DO;
  %EDW2UNIX(TBL_NM_in=&DB2_TMP..&TABLE_PREFIX._CLAIMS_ACT_&ACT_ADJ.
    ,TBL_NM_OUT=data.&TABLE_PREFIX._CLAIMS_ACT_&ACT_ADJ.
    ,ADJ_ENGINE=1  );
%END;
%IF &rx_adj eq 1 %THEN %DO;
  %EDW2UNIX(TBL_NM_in=&ORA_TMP..&TABLE_PREFIX._CLAIMS_ACT_&ACT_ADJ.
	  ,TBL_NM_OUT=data.&TABLE_PREFIX._CLAIMS_ACT_&ACT_ADJ.
    ,ADJ_ENGINE=2   );
%END;
%IF &re_adj eq 1 %THEN %DO;
  %EDW2UNIX(TBL_NM_in=&ORA_TMP..&TABLE_PREFIX._CLAIMS_ACT_&ACT_ADJ.
 	  ,TBL_NM_OUT=data.&TABLE_PREFIX._CLAIMS_ACT_&ACT_ADJ.
    ,ADJ_ENGINE=3  );
%END;

%mend load_adj;
%load_adj;

*SASDOC--------------------------------------------------------------------------
| Call the macro %COMBINE_ADJUDICATIONS. The logic in the macro COMBINES THE CLAIMS
| that were pulled for all three adjudications.
| Note: for this mailing only one adjudication is available per run
+------------------------------------------------------------------------SASDOC*;
%combine_adj(TBL_NM_QL=data.&TABLE_PREFIX._CLAIMS_ACT_QL,
             TBL_NM_RX=data.&TABLE_PREFIX._CLAIMS_ACT_RX,
             TBL_NM_RE=data.&TABLE_PREFIX._CLAIMS_ACT_RE,
             TBL_NM_OUT=&DB2_TMP..&TABLE_PREFIX._CLAIMS_COMBA
            ); 

*SASDOC-------------------------------------------------------------------------
| select eligible households whom have claims and have not been sent a 
| ACT mailing before.
+-----------------------------------------------------------------------SASDOC*;
%macro act_elig_households(tbl_name_in=,
                           tbl_name_out=);

  %drop_db2_table(tbl_name=&tbl_name_out.);
  
  proc sql;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
    EXECUTE(CREATE TABLE &tbl_name_out.
       (CDH_BENEFICIARY_ID	INTEGER NOT NULL,
       CLIENT_ID         	INTEGER NOT NULL, 
       CLIENT_NM         	CHARACTER(30) NOT NULL,           
       CLT_PLAN_GROUP_ID 	INTEGER,
       MOC_PHM_CD        	CHARACTER(3),
       CS_AREA_PHONE     	CHARACTER(13),
       LTR_RULE_SEQ_NB    SMALLINT, /* added for create base file */
       PT_BENEFICIARY_ID  INTEGER,
       ADJ_ENGINE         CHARACTER(2),
       CLIENT_LEVEL_1     CHARACTER(22),
       CLIENT_LEVEL_2     CHARACTER(22),
       CLIENT_LEVEL_3     CHARACTER(22))
       NOT LOGGED INITIALLY) BY DB2;      
    DISCONNECT from DB2;
  quit;

  proc sql;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
    EXECUTE(ALTER TABLE &tbl_name_out.
            ACTIVATE NOT LOGGED INITIALLY ) BY DB2;
          
    EXECUTE(INSERT into &tbl_name_out.         
          select DISTINCT A.CDH_BENEFICIARY_ID,
              A.CLIENT_ID, 
              A.CLIENT_NM,              
              A.CLT_PLAN_GROUP_ID,
              A.MOC_PHM_CD,
              A.CS_AREA_PHONE, 
              A.LTR_RULE_SEQ_NB,
              A.CDH_BENEFICIARY_ID, /* for RX and RE if Cardholder not found on ql */
              A.ADJ_ENGINE,
              A.CLIENT_LEVEL_1,
              A.CLIENT_LEVEL_2,
              A.CLIENT_LEVEL_3  
          from &tbl_name_in A
          where CDH_BENEFICIARY_ID NOT in
              (select distinct B.RECIPIENT_ID
               from &hercules..TCMCTN_RECEIVR_HIS B,
                    &hercules..TINITIATIVE C
               where B.INITIATIVE_ID = C.INITIATIVE_ID
               AND C.PROGRAM_ID = 106 
               AND C.TASK_ID = 34)
           ) BY DB2;
          select MAILING_COUNT
          into :MAILING_COUNT
          from CONNECTION TO DB2
            (select COUNT(*) AS MAILING_COUNT
             from   &tbl_name_out.
            );
    DISCONNECT from DB2;
  quit;

  %PUT NOTE: ELIGIBLE HOUSEHOLD MAILING COUNT = &MAILING_COUNT;

  %set_error_fl;
  %on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
      EM_SUBJECT="HCE SUPPORT:  Notification of Abend - act_elig_households Macro",
      EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");

%mend act_elig_households;

%act_elig_households(tbl_name_in=&DB2_TMP..&TABLE_PREFIX._CLAIMS_COMBA,
                     tbl_name_out=&DB2_TMP..&TABLE_PREFIX._CLAIMS_COMB);

*SASDOC-------------------------------------------------------------------------
| Create the Pending SAS dataset for the initiative. 
+-----------------------------------------------------------------------SASDOC*;
*%let debug_flag=Y; /* for testing only */

%CREATE_BASE_FILE(TBL_NAME_in=&DB2_TMP..&TABLE_PREFIX._CLAIMS_COMB);
%set_error_fl;

*SASDOC-------------------------------------------------------------------------
| Call %check_document to see if the Stellent id(s) have been attached.
+-----------------------------------------------------------------------SASDOC*;
%CHECK_DOCUMENT;

*SASDOC-------------------------------------------------------------------------
| Check if the initiative is setup to auto release the vendor file.
+-----------------------------------------------------------------------SASDOC*;
%AUTORELEASE_FILE(INIT_ID=&INITIATIVE_ID, PHASE_ID=&PHASE_SEQ_NB);

*SASDOC-------------------------------------------------------------------------
| DROP THE TEMPORARY UDB TABLES
| Dependent on engine running
+-----------------------------------------------------------------------SASDOC*;
%macro clean_up_tables;

/* act eligible households */
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS_COMBA);
/* patient parms */
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS_PT);
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._NDC_TBL_106_34);
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX.PT_PARMS);
/* get moc csphone */
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS_MOC_&ACT_ADJ.);

%IF &QL_ADJ EQ 1 %THEN %DO;
  /* get ndc */
  %drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._NDC_&ACT_ADJ.);
  /* resolve client */
  %drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLT_CPG_&ACT_ADJ.);
  /* claims pull */
  %drop_db2_table(tbl_name=&DB2_TMP..CLAIMS_PULL_&INITIATIVE_ID._&ACT_ADJ.);
  /* eligibility check */
  %drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG_&ACT_ADJ.);
  /* summarize to household */
  %drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS_ACT_&ACT_ADJ.);
  /* eligibility */
  %drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG_QL_H);
%END;

%IF &RX_ADJ EQ 1 or &RE_ADJ EQ 1 %THEN %DO;
  /* get ndc */
  %DROP_ORACLE_TABLE(tbl_name=&ORA_TMP..&TABLE_PREFIX._NDC_&ACT_ADJ.);
  /* resolve client */
  %DROP_ORACLE_TABLE(tbl_name=&ORA_TMP..&TABLE_PREFIX._CLT_CPG_&ACT_ADJ.);
  /* claims pull */
  %DROP_ORACLE_TABLE(tbl_name=&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._&ACT_ADJ.); 
  /* eligibility check */
  %DROP_ORACLE_TABLE(tbl_name=&ORA_TMP..&TABLE_PREFIX._CPG_ELIG_&ACT_ADJ.);
  /* get moc csphone */
  %DROP_ORACLE_TABLE(tbl_name=&ORA_TMP..&TABLE_PREFIX._CLAIMS_MOC_&ACT_ADJ.);
  /* patient parms */
  %DROP_ORACLE_TABLE(tbl_name=&ORA_TMP..&TABLE_PREFIX._CLAIMS_PT);
  /* patient parms */
  %DROP_ORACLE_TABLE(tbl_name=&ORA_TMP..&TABLE_PREFIX._CLAIMS_PT_&ACT_ADJ.);
  /* summarize to household */
  %DROP_ORACLE_TABLE(tbl_name=&ORA_TMP..&TABLE_PREFIX._CLAIMS_ACT_&ACT_ADJ.);
%END;

%mend clean_up_tables;
%clean_up_tables;

*SASDOC-------------------------------------------------------------------------
| Insert a row into HERCULES.TCMCTN_PENDING if the initiative is not setup to
| auto release the vendor file.  The row will consist of accumulators based
| upon the address edit check.  One for Accepted letters, Rejected letters, 
| and Suspended letters.
+-----------------------------------------------------------------------SASDOC;
OPTIONS MLOGIC MPRINT SYMBOLGEN SOURCE2;

%insert_tcmctn_pending(init_id=&initiative_id, phase_id=&phase_seq_nb);
%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend - insert_tcmctn_pending",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative Id &INITIATIVE_ID");

*SASDOC -----------------------------------------------------------------------------
| Generate client initiative summary report
+ ----------------------------------------------------------------------------SASDOC*;
%include "/herc&sysmode/prg/hercules/reports/client_initiative_summary.sas";

%client_initiative_summary; 

*SASDOC -----------------------------------------------------------------------------
| Generate receiver_listing report
+ ----------------------------------------------------------------------------SASDOC*;
proc sql;
  select MAX(REQUEST_ID) into :MAX_ID
  from &hercules..TREPORT_REQUEST;
quit;
%PUT Report request id = &MAX_ID;

proc sql;
  INSERT into &hercules..TREPORT_REQUEST
   (REQUEST_ID, REPORT_ID, REQUIRED_PARMTR_ID, SEC_REQD_PARMTR_ID, JOB_REQUESTED_TS,
    JOB_START_TS, JOB_COMPLETE_TS, HSC_USR_ID , HSC_TS , HSU_USR_ID , HSU_TS )
    VALUES
    (%EVAL(&MAX_ID.+1), 15, &INITIATIVE_ID., &PHASE_SEQ_NB., %SYSFUNC(DATETIME()), %SYSFUNC(DATETIME()), 
    NULL,"&USER"  , %SYSFUNC(DATETIME()), "&USER", %SYSFUNC(DATETIME()));
quit;

options sysparm="request_id=%EVAL(&MAX_ID.+1)" ;
%include "/herc&sysmode/prg/hercules/reports/receiver_listing.sas";

*SASDOC-------------------------------------------------------------------------
| Update the job complete timestamp
+-----------------------------------------------------------------------SASDOC*;
%update_task_ts(FINISH,init_id=&initiative_id);
