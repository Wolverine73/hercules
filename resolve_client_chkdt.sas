
/**HEADER------------------------------------------------------------------------------------
|
| PROGRAM NAME: resolve_client.sas
|
| PURPOSE:
|       Determining the Clients and and their CPGs to be included OR excluded
|       in a mailing.
|
| INPUT:  INITIATIVE_ID, claimsa.tprogram a, &hercules..tinitiative b,
|            &hercules..tprogram_task
|
| CSS client setup tables:
|          CLAIMSP.TCLT_PROGRAM_CPGRT,
|          CLAIMSP.TCLIENT_PGM_DLY
|
| HERCULES client setup tables:
|          &claimsa..tprogram,
|          &hercules..tinitiative,
|          &hercules..tprogram_task,
|          &HERCULES..TINIT_CLIENT_RULE,
|          &HERCULES..TINIT_CLT_RULE_DEF
|
| CLIENT CPG-PB TABLES:
|          &CLAIMSA..TCPGRP_CLT_PLN_GR1
|          &CLAIMSA..TRPTGR_RPT_GROUP,
|          &CLAIMSA..TRPTDT_RPT_GRP_DTL,
|          &CLAIMSA..tcpg_pb_trl_hist,
|          &CLAIMSA..tpresc_benefit
|
|
| OUTPUT: &TBL_NAME_OUT with client_id and clt_plan_group_id,
|         RESOLVE_CLIENT_EXCLUDE_FLAG: 0=INCLUDE CPGS IN THE &TBL_NAME_OUT IN THE MAILING,
|                                      1=EXCLUDE CPGS IN THE &TBL_NAME_OUT FROM THE MAILING.
|         &resolve_client_tbl_exist_flag:
|                     0 = Table &tbl_name_out does not exist, due to that the conditions
|                          for creating the table are not meet.
|                     1 = Table &tbl_name_out has been created.
|
| REFERENCE: SAS DESIGN, HERCULES COMMUNICATION ENGINE, BY PEGGY WONDERS
|
| CALL EXAMPLE:
|         options sysparm='INITIATIVE_ID=20, PHASE_SEQ_NB=1';
|         %include '/PRG/sastest1/hercules/hercules_in.sas';
|
|          %resolve_client(TBL_NAME_OUT=&DB2_TMP..SELECTED_CLT_CPG);
|---------------------------------------------------------------------------------------      |
| HISTORY: SEPT, 2003, JOHN HOU
|          added chk_dt to allow checking client setup other than the default 'CURRENT DATE'
|          
+------------------------------------------------------------------------------------*HEADER*/


%macro resolve_client(tbl_name_in=,
					  tbl_name_out=,
					  tbl_name_out2=,
                                          chk_dt= %str(CURRENT DATE),
					  NO_OUTPUT_TABLES_IN=0,
					  Execute_condition=%STR(1=1));

%LOCAL MAC_NAME PROGRAM_TYPE program_type
              DFLT_INCLSN_IN
              ovrd_clt_setup_in
              dsply_clt_setup_cd
              record_cnt
              select_str;
%GLOBAL RESOLVE_CLIENT_EXCLUDE_FLAG RESOLVE_CLIENT_TBL_EXIST_FLAG RESOLVE_CLIENT_IDS
		CLIENT_ID_CONDITION PRIMARY_PROGRAMMER_EMAIL;

proc sql noprint;
select quote(trim(left(email)))
into   :PRIMARY_PROGRAMMER_EMAIL separated by ' '
from   ADM_LKP.ANALYTICS_USERS
where  upcase(QCP_ID) in ("&USER");
quit;


%let mac_name=RESOLVE_CLIENT;
%LET RESOLVE_CLIENT_IDS=;

%LET Execute_condition_flag=%SYSFUNC(SIGN((&Execute_condition)));
%PUT Execute_condition_flag=&Execute_condition_flag;

%IF &Execute_condition_flag.=0 %THEN 
								  %DO;
			%PUT NOTE: Macro will not execute because Execute_condition is false;
			%PUT Execute_condition=&Execute_condition; 
								 %END;
%IF &Execute_condition_flag.=0 %THEN %GOTO EXIT;
								  

  %IF &DB2_TMP = %THEN %LET DB2_TMP=&USER;
  LIBNAME CLAIMSP DB2 DSN=&UDBDWP SCHEMA=CLAIMSP DEFER=YES ;

  %IF &tbl_name_out= %THEN %LET TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX.CPG;
  proc sql noprint;
       select compress("'"||A.program_type_cd||"'"),
              put(A.DFLT_INCLSN_IN,3.),
              put(b.ovrd_clt_setup_in,3.),
              put(C.dsply_clt_setup_cd,8.),
              count(*)

         into :program_type,
              :DFLT_INCLSN_IN,
              :ovrd_clt_setup_in,
              :dsply_clt_setup_cd,
              :record_cnt
       from &claimsa..tprogram a, &hercules..tinitiative b,
            &hercules..tprogram_task c
       where a.program_id=&program_id
         and a.program_id=b.program_id
         and a.program_id=c.program_id
         and b.task_id = c.task_id
         and B.initiative_id = &initiative_id;
        quit;

   %if &record_cnt=0 %then %PUT WARNING: NO matching initiative_id was found.;

   %PUT NOTE: Program_type=&program_type.;
   %PUT NOTE: Default_Inclusion Indicator=%cmpres(&dflt_inclsn_in).;
   %PUT NOTE: Client-Override-Id=%cmpres(&ovrd_clt_setup_in).;

   %IF &dflt_inclsn_in=1 AND &ovrd_clt_setup_in=0 %THEN %LET RESOLVE_CLIENT_EXCLUDE_FLAG=1;
      %ELSE %LET RESOLVE_CLIENT_EXCLUDE_FLAG=0;

%IF &RESOLVE_CLIENT_EXCLUDE_FLAG=1 %THEN 
								  %DO;
				%LET CPG_CONDITION=%STR(IS NULL);
				%LET CLIENT_CONDITION=NOT;
								  %END;
%ELSE							  %DO;
				%LET CPG_CONDITION=%STR(IS NOT NULL);
				%LET CLIENT_CONDITION=;
								  %END; 
%PUT CPG_CONDITION=&CPG_CONDITION;

   %IF &dsply_clt_setup_cd=2 %THEN
       %PUT NOTE: Client-Display-Setup-Code=%cmpres(&dsply_clt_setup_cd), USE CSS CLIENT SETUP. ;

   %ELSE %IF &dsply_clt_setup_cd=1 %THEN %PUT
        NOTE: Client-Display-Setup-Code=%cmpres(&dsply_clt_setup_cd), USE HERCULES SETUP. ;
   %ELSE %DO;
         %PUT NOTE: Client-Display-Setup-Code=%cmpres(&dsply_clt_setup_cd).;
         %PUT NOTE: The &MAC_NAME macro is not applicable to INITIATIVE &initiative_id..;
         %END;

%if &dsply_clt_setup_cd > 2 %then %let resolve_client_tbl_exist_flag=0;
%if &dsply_clt_setup_cd > 2 %then %goto exit;

%*SASDOC -------------------------------------------------------------------------
 | RESET DSPLY_CLT_SETUP_CD =1, TO USE HERCULES SETUP WHEN ovrd_clt_setup_in IS 1.
 +---------------------------------------------------------------------------SASDOC;

%if &dsply_clt_setup_cd = 2 %then %do;
    %if &ovrd_clt_setup_in=1 %then %let dsply_clt_setup_cd=1;
    %end;


%if (&record_cnt=0 or &record_cnt>1) %then %let resolve_client_tbl_exist_flag=0;

%if &record_cnt=0 %then %goto exit;

%if &record_cnt>1 %then %put WARNING: DUPLICATE INITIATIVE_IDs WERE FOUND.;
%if &record_cnt>1 %then %goto exit;


%else %if &record_cnt=1 %then %do;
%drop_db2_table(tbl_name=&TBL_NAME_OUT); quit;

%*SASDOC -----------------------------------------------------------------------
 | WHEN TPROGRAM_TASK.DSPLY_CLT_SETUP_CD=2, USE CSS CLIENT SETUP.
 +-------------------------------------------------------------------------SASDOC;

      %if &dsply_clt_setup_cd=2 %then %do;

%IF RESOLVE_CLIENT_EXCLUDE_FLAG=1 %THEN %LET STR_ENTIRE_CLIENT_IN=%STR(HAVING MIN(B.ENTIRE_CLIENT_IN)=1);
%ELSE									%LET STR_ENTIRE_CLIENT_IN=;
	
PROC SQL NOPRINT;
 CONNECT TO DB2 AS DB2(DSN=&UDBDWP);
  SELECT  CLIENT_ID	INTO :RESOLVE_CLIENT_IDS SEPARATED BY ','
   FROM CONNECTION TO DB2 
   (SELECT  A.CLIENT_ID
     FROM	CLAIMSP.TCLIENT_PGM_DLY A,
			CLAIMSP.TCLIENT_PGM_RULE B
		WHERE A.CLIENT_PROGRAM_ID = B.CLIENT_PROGRAM_ID
		  AND	A.PROGRAM_TYPE_CD = &program_type.  
		  AND	A.CLT_PGM_EFF_DT <= &chk_dt
		  AND	(A.CLT_PGM_EXP_DT > &chk_dt OR A.CLT_PGM_EXP_DT IS NULL)
		GROUP BY A.CLIENT_ID
		 &STR_ENTIRE_CLIENT_IN.
	);
   DISCONNECT FROM DB2;
 QUIT;

%set_error_fl;

 %PUT RESOLVE_CLIENT_IDS=&RESOLVE_CLIENT_IDS;

%IF &RESOLVE_CLIENT_IDS. NE  
%THEN  %LET CLIENT_ID_CONDITION=%STR(AND CLIENT_ID &CLIENT_CONDITION IN (&RESOLVE_CLIENT_IDS.));
%ELSE  %LET CLIENT_ID_CONDITION=;
%PUT CLIENT_ID_CONDITION = &CLIENT_ID_CONDITION;
 
 %IF &NO_OUTPUT_TABLES_IN=1 %THEN %GOTO EXIT;

   PROC SQL;
        CONNECT TO DB2 AS DB2(DSN=&UDBDWP);
        CREATE TABLE &TBL_NAME_OUT AS
        SELECT * FROM CONNECTION TO DB2
         (SELECT DISTINCT B.CLIENT_ID, A.CLT_PLAN_GROUP_ID
            FROM   CLAIMSP.TCLT_PROGRAM_CPGRT A, CLAIMSP.TCLIENT_PGM_DLY B
            WHERE A.CLIENT_PROGRAM_ID = B.CLIENT_PROGRAM_ID
             AND  B.CLT_PGM_EFF_DT <= &chk_dt
             AND (B.CLT_PGM_EXP_DT > &chk_dt OR B.CLT_PGM_EXP_DT IS NULL)
             AND  B.PROGRAM_TYPE_CD =&program_type
             );
        DISCONNECT FROM DB2;
    QUIT;



%runstats(tbl_name=&TBL_NAME_OUT);

 %let resolve_client_tbl_exist_flag=1;

 %end;

%set_error_fl;

   %on_error( ACTION=ABORT
             ,EM_TO=&PRIMARY_PROGRAMMER_EMAIL
             ,EM_SUBJECT=HCE SUPPORT: Notification of Abend Initiative_id &initiative_id
             ,EM_MSG=%str(A problem was encountered at the RESOLVE_CLIENT macro. Please check the log associated with Initiative_id &initiative_id..));

%*SASDOC -----------------------------------------------------------------------
 | WHEN TPROGRAM_TASK.DSPLY_CLT_SETUP_CD=1 OR TINITIATIVE.OVRD_CLT_SETUP_ID=1, USE
 | HERCULES TABLES FOR CLIENT SETUP.
 +-------------------------------------------------------------------------SASDOC;

%if &dsply_clt_setup_cd=1 %then %do;

%IF RESOLVE_CLIENT_EXCLUDE_FLAG=1 %THEN %LET STR_CLT_SETUP_DEF_CD=%STR(AND CLT_SETUP_DEF_CD = 1);
%ELSE									%LET STR_CLT_SETUP_DEF_CD=;

PROC SQL NOPRINT;
 SELECT DISTINCT CLIENT_ID  INTO :RESOLVE_CLIENT_IDS SEPARATED BY ','
  FROM &HERCULES..TINIT_CLT_RULE_DEF
   WHERE INITIATIVE_ID=&INITIATIVE_ID
     &STR_CLT_SETUP_DEF_CD. 
	 ;
QUIT;

%PUT  RESOLVE_CLIENT_IDS=&RESOLVE_CLIENT_IDS;


%IF &RESOLVE_CLIENT_IDS. NE  
%THEN  %LET CLIENT_ID_CONDITION=%STR(AND CLIENT_ID &CLIENT_CONDITION IN (&RESOLVE_CLIENT_IDS.));
%ELSE  %LET CLIENT_ID_CONDITION=;
%PUT CLIENT_ID_CONDITION = &CLIENT_ID_CONDITION;

 %IF &NO_OUTPUT_TABLES_IN=1 %THEN %GOTO EXIT;

%drop_db2_table(tbl_name=&DB2_TMP..&table_prefix.&MAC_NAME);

PROC SQL;
 CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
  EXECUTE (CREATE TABLE &DB2_TMP..&table_prefix.&MAC_NAME AS
    (SELECT RL.CLIENT_ID, CPG.CLT_PLAN_GROUP_ID
              FROM &HERCULES..TINIT_CLIENT_RULE RL,
                  &CLAIMSA..TCPGRP_CLT_PLN_GR1 CPG)
    DEFINITION ONLY NOT LOGGED INITIALLY)
    BY DB2;
EXECUTE
  (ALTER TABLE &DB2_TMP..&table_prefix.&MAC_NAME ACTIVATE NOT LOGGED INITIALLY 
  ) BY DB2;
    DISCONNECT FROM DB2;
QUIT;

%*SASDOC ----------------------------------------------------------------------------
 | To avoid repeating conncections to DB2 tables, create SAS datasets for only involved
 | clients.
 +----------------------------------------------------------------------------SASDOC*;

/** consolidate the cpg and reporting group info for involved the clients
    and send them to temp dataset **/

proc sql;
     connect to db2 (dsn=&udbsprp);
     create table TCPG_COMBO as
     select * from connection to db2
     (SELECT distinct PLN.*, GRP.GROUP_CLASS_CD, GRP.SEQUENCE_NB
        FROM  &CLAIMSA..TCPGRP_CLT_PLN_GR1 PLN, &CLAIMSA..TRPTGR_RPT_GROUP GRP,
                      &CLAIMSA..TRPTDT_RPT_GRP_DTL DTL
       WHERE PLN.CLIENT_ID=GRP.CLIENT_ID
         AND PLN.CLIENT_ID=DTL.CLIENT_ID
         AND PLN.CLT_PLAN_GROUP_ID=DTL.CLT_PLAN_GROUP_ID
         AND GRP.GROUP_CLASS_CD = DTL.GROUP_CLASS_CD
         AND GRP.SEQUENCE_NB = DTL.SEQUENCE_NB
         AND PLN.CLIENT_ID IN
              (SELECT DISTINCT CLIENT_ID
                 FROM &HERCULES..TINIT_CLIENT_RULE
                WHERE INITIATIVE_ID=&INITIATIVE_ID)
      );
          DISCONNECT FROM DB2;
    quit;


/** consolidate the client initiative setup info for involved the clients
    and send them to temp dataset **/

proc sql;
     connect to db2 (dsn=&udbsprp);
     create table TRULE_COMBO as
     select * from connection to db2
     (SELECT DISTINCT RL.*, SETUP.CLT_SETUP_DEF_CD
          FROM &HERCULES..TINIT_CLIENT_RULE RL,
               &HERCULES..TINIT_CLT_RULE_DEF setup
          WHERE RL.INITIATIVE_ID=SETUP.INITIATIVE_ID
            AND RL.INITIATIVE_ID=&INITIATIVE_ID
            AND RL.client_id = SETUP.client_id);
    DISCONNECT FROM DB2;
   QUIT;

%*SASDOC ----------------------------------------------------------------------------
 | 1 PICK UP WHOLE CLIENT INCLUSION WHEN clt_setup_def_cd=1.
 |    When CLT_SETUP_DEF_CD is 2, include WHOLE clients first then exclusion
 |         (REMOVE THOSE CPGs can be identified based on plan/group OR reporting groups).
 +----------------------------------------------------------------------------SASDOC*;

 %LET SELECT_STR=
      %STR( AND ( rule1.group_class_cd is null or
              cpg.group_class_cd = rule1.group_class_cd)
            AND ( rule1.group_class_SEQ_NB is null or
              cpg.SEQUENCE_NB = rule1.group_class_SEQ_NB)
          AND ( rule1.blg_reporting_cd is null or
              cpg.blg_reporting_cd LIKE COMPRESS(rule1.blg_reporting_cd))
          AND ( cpg.plan_cd LIKE COMPRESS(rule1.plan_cd_TX)
              OR rule1.plan_cd_TX IS NULL)
           AND (cpg.plan_extension_cd LIKE COMPRESS(rule1.plan_ext_cd_TX)
            OR rule1.plan_ext_cd_TX IS NULL)
           AND (cpg.group_cd LIKE COMPRESS(rule1.group_cd_TX)
            OR rule1.group_cd_TX IS NULL)
           AND (cpg.group_extension_cd LIKE COMPRESS(rule1.group_ext_cd_TX)
           OR rule1.group_ext_cd_TX IS NULL)
             );

 PROC SQL;
       CREATE TABLE TCPG_COMBO_RULE AS
       SELECT cpg.*
       FROM TCPG_COMBO CPG, TRULE_COMBO RULE
  WHERE rule.client_id = cpg.client_id
    AND CLT_SETUP_DEF_CD IN (1,2);

PROC SQL;
     DELETE FROM TCPG_COMBO_RULE CPG
     WHERE CPG.clt_plan_group_id IN
     (SELECT distinct CPG.clt_plan_group_id
        FROM    TRULE_COMBO RULE1, TCPG_COMBO_RULE CPG
        WHERE   rule1.client_id = cpg.client_id
        AND   rule1.clt_setup_def_cd in (2)
        AND   rule1.include_in = 0
        &SELECT_STR
            )
     ;
   QUIT;

PROC SQL;
       INSERT INTO &DB2_TMP..&table_prefix.&MAC_NAME(BULKLOAD=YES)
         SELECT DISTINCT CLIENT_ID, clt_plan_group_id
       FROM TCPG_COMBO_RULE;
   QUIT;

 %*SASDOC ----------------------------------------------------------------------------
  | 2: WHEN clt_setup_def_cd=3, PICK UP partial INCLUSION FIRST, THEN EXCLUSION.
  +--------------------------------------------------------------------------- SASDOC*;

  PROC SQL;
       CREATE TABLE TCPG_COMBO_RULE2 AS
       SELECT distinct cpg.*
  FROM TRULE_COMBO RULE1, TCPG_COMBO CPG
  WHERE rule1.client_id = cpg.client_id
        AND RULE1.clt_setup_def_cd=3
        AND INCLUDE_IN = 1
        &select_str;
      QUIT;

  PROC SQL;
       DELETE FROM TCPG_COMBO_RULE2 CPG
     WHERE CPG.clt_plan_group_id IN
     (SELECT distinct CPG.clt_plan_group_id
        FROM    TRULE_COMBO RULE1, TCPG_COMBO_RULE2 CPG
         WHERE   rule1.client_id = cpg.client_id
             AND   rule1.clt_setup_def_cd in (3)
             AND   INCLUDE_IN = 0
             &select_str  );
   QUIT;

PROC SQL;
       INSERT INTO &DB2_TMP..&table_prefix.&MAC_NAME
       SELECT DISTINCT CLIENT_ID, clt_plan_group_id
       FROM TCPG_COMBO_RULE2;
   QUIT;

   %runstats(tbl_name=&DB2_TMP..&table_prefix.&MAC_NAME);

%*SASDOC -----------------------------------------------------------------------------
 |
 | MERGE WITH CPG HISTORY TABLES TO GET CURRENT CPGs. NEED TO AWARE THAT WHEN USING
 | THE CURRENT CPGs TO SELECT CLAIMS SOME CLAIMS WILL BE LEFT WHEN CLAIMS WERE COVERED
 | UNDER OLDER CPGS.
 |
 +------------------------------------------------------------------------------SASDOC*;

PROC SQL;
     CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
     CREATE TABLE &TBL_NAME_OUT AS
     SELECT * FROM CONNECTION TO DB2
     (SELECT distinct cpg_in.*
      FROM &CLAIMSA..TCPGRP_CLT_PLN_GR1 clt, &DB2_TMP..&table_prefix.&MAC_NAME cpg_in
      WHERE cpg_in.client_id =clt.CLIENT_ID
         and cpg_in.clt_plan_group_id=clt.clt_plan_group_id
         and exists
            (SELECT 1
               FROM &CLAIMSA..tcpg_pb_trl_hist cpg,
                    &CLAIMSA..tpresc_benefit pb
               WHERE clt.clt_plan_group_id = cpg.clt_plan_group_id
                 AND CPG_IN.clt_plan_group_id = cpg.clt_plan_group_id
                 AND cpg.pb_id = pb.pb_id
                 AND cpg.eff_dt <= &chk_dt
                 AND cpg.exp_dt > &chk_dt
                 AND pb.begin_fill_dt <= &chk_dt
                 AND pb.end_fill_dt > &chk_dt
               )
      );
      DISCONNECT FROM DB2;
   QUIT;

%runstats(tbl_name=&TBL_NAME_OUT);

%drop_db2_table(tbl_name=&DB2_TMP..&table_prefix.&MAC_NAME);
   %NOBS(&TBL_NAME_OUT);

         %IF &NOBS %THEN %let resolve_client_tbl_exist_flag=1;
         %else %let resolve_client_tbl_exist_flag=0;

  %end;
%end;
%exit:;

%IF &tbl_name_in. NE  AND &tbl_name_out2. NE AND &err_fl=0 %THEN
 %DO;
 	 %drop_db2_table(tbl_name=&tbl_name_out2.);

 %LET pos=%INDEX(&tbl_name_out2,.);
 %LET Schema=%SUBSTR(&tbl_name_out2,1,%EVAL(&pos-1));
 %LET Tbl_name_out2_sh=%SUBSTR(&tbl_name_out2,%EVAL(&pos+1));

 %IF &Execute_condition_flag.=1 %THEN  
 							 %DO;	
  PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE TABLE &tbl_name_out2.	AS
      (  SELECT  A.*
			  FROM  &tbl_name_in. AS A
      ) DEFINITION ONLY NOT LOGGED INITIALLY
	       ) BY DB2;
   DISCONNECT FROM DB2;
  QUIT;

   %set_error_fl;

  PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
   EXECUTE
  (ALTER TABLE &tbl_name_out2. ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;    
	EXECUTE(INSERT INTO &tbl_name_out2. 
    	     SELECT A.*
		      FROM &tbl_name_in.				 	AS A LEFT JOIN
		 		   &tbl_name_out.			 		AS B
                ON A.CLT_PLAN_GROUP_ID = B.CLT_PLAN_GROUP_ID
				 WHERE B.CLT_PLAN_GROUP_ID &CPG_CONDITION.
			) BY DB2;
%reset_sql_err_cd;
QUIT;
%set_error_fl;
%runstats(TBL_NAME=&tbl_name_out2.);
			%END; /* End of &Execute_condition_flag.=1 */
%ELSE
 							%DO;
PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE ALIAS &tbl_name_out2.  FOR &tbl_name_in. ) BY DB2;
	DISCONNECT FROM DB2;
QUIT;
%set_error_fl;
							%END;

   %END;


   %on_error( ACTION=ABORT
             ,EM_TO=&PRIMARY_PROGRAMMER_EMAIL
             ,EM_SUBJECT=HCE SUPPORT: Notification of Abend Initiative_id &initiative_id
             ,EM_MSG=%str(A problem was encountered at the RESOLVE_CLIENT macro. Please check the log associated with Initiative_id &initiative_id..));


%mend resolve_client;

/** options sysparm='INITIATIVE_ID=192, PHASE_SEQ_NB=1';
         %include '/PRG/sastest1/hercules/hercules_in.sas';

          %resolve_client(TBL_NAME_OUT=&DB2_TMP..SELECTED_CLT_CPG); **/
