/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  update_cmctn_his_adhoc.sas
|
| LOCATION: /PRG/sas&sysmode.1/hercules/gen_utilities/sas
|
| PURPOSE:  This program insert ad hoc (mailing corrections) into communication
|           tables.
|
| INPUT:    Adhoc file that has the list of letters sent as an adhoc/revised
|           mailing. The records of these adhoc mailing can not be performed
|           using the regular archive process update_cmctn_history.sas
|
| OUTPUT:   &HERCULES..TCMCTN_RECEIVR_HIS - updates table for completed mailings
|           &HERCULES..TCMCTN_SUBJECT_HIS - updates table for completed mailings
|           &HERCULES..TCMCTN_ADDRESS     - updates table for completed mailings
|           &HERCULES..TCMCTN_SBJ_NDC_HIS - updates table for completed mailings
|           &HERCULES..TCMCTN_TRANSACTION - updates table for completed mailings
|
|           Datasets from DATA_PND/DATA_RES are compressed & moved to "archive".
|
|           Temp tables are identified and dropped for completed initiatives.
|
| MACROS:   %assign_cmctn_id
|           %LOAD_INIT_HIS
|           %drop_initiative_temp_tables
|           %archive_results
|
+-------------------------------------------------------------------------------
| HISTORY:  FEB 2004 - JOHN HOU
|
+-----------------------------------------------------------------------HEADER*/
libname SYSCAT DB2 DSN=&UDBSPRP SCHEMA=SYSCAT DEFER=YES;


OPTIONS SYSPARM='INITIATIVE_ID=212, PHASE_SEQ_NB=1';

%set_sysmode;
%include "/PRG/sas&sysmode.1/hercules/hercules_in.sas";

%MACRO r2m_his_update
           (TBL_NAME_IN=
           , initiative_id=
           , cmctn_role_cd= );

%PUT %cmpres(&initiative_id), %cmpres(&task_id), %cmpres(&PHASE_SEQ_NB), %cmpres(&cmctn_role_cd);
%LOCAL MAX_CMCTN_ID MAX_INIT_ID;

PROC SQL NOPRINT;
     SELECT MAX(CMCTN_ID), MAX(INITIATIVE_ID) INTO: MAX_CMCTN_ID, :MAX_INIT_ID
     FROM &HERCULES..TCMCTN_RECEIVR_HIS; QUIT;

%let hercules=QCPAP020;
%LET DB2_TMP=QCPAP020;

%put &MAX_CMCTN_ID;

*** add communication_id start from the max of historical max_cmctn_id;

%drop_db2_table(tbl_name= &DB2_TMP..&TABLE_PREFIX.INSERT_HIS); quit;


DATA &DB2_TMP..&TABLE_PREFIX.INSERT_HIS ;
     SET &TBL_NAME_IN.;
     apn_cmctn_ids=put(apn_cmctn_id,8.);
     zip_cd=substr(zip_4,1,5);
     zip_suffix=substr(zip_4,7,4);
     format HSC_TS HSU_TS datetime25.6 com_sas_dt mmddyy10.;
     informat HSC_TS HSU_TS datetime25.6 com_sas_dt mmddyy10.;
     COM_SAS_DT=TODAY();
     HSC_TS=DATETIME();
     HSU_TS=DATETIME();
     CMCTN_ID=_N_+&MAX_CMCTN_ID;
  RUN;


/* NOTE:

  %CREATE_BASE_FILE DOES NOT CREATE CORRECT FILE WHEN RECIPIENT IS THE CARDHOLDER
   AND THE PT_BENEFICIARY_ID IS INCLUDED IN THE INPUT TABLE &TBL_NAME_IN. THE PT_BENEFICIARY_ID
   IS TO BE USED FOR UPDATING THE SUBJECT HISTORY TABLES. THE FOLLOWING QUERY ADD
   PT_BENEFICIARY_ID TO THE MAILING LIST SO THAT THE SUBJECT_ID CAN BE CORRECTLY UPDATED
 */


%runstats(tbl_name=&DB2_TMP..&TABLE_PREFIX.INSERT_HIS);

PROC SQL;
     CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);

     EXECUTE (
     INSERT INTO &HERCULES..TCMCTN_RECEIVR_HIS
     SELECT DISTINCT &INITIATIVE_ID,
            %cmpres(&PHASE_SEQ_NB),
            %cmpres(&CMCTN_ROLE_CD),
            A.CMCTN_ID,
            A.RECIPIENT_ID,
            A.APN_CMCTN_IDs,
            A.PROGRAM_ID,
            A.COM_SAS_DT,
            'QCPAP020',
            HSC_TS,
            'QCPAP020',
            HSU_TS
       FROM &DB2_TMP..&TABLE_PREFIX.INSERT_HIS A
        WHERE A.CMCTN_ID>&MAX_CMCTN_ID
        ) BY DB2;
     DISCONNECT FROM DB2;
  QUIT;

PROC SQL;

     INSERT INTO &HERCULES..TCMCTN_ADDRESS
     SELECT DISTINCT &INITIATIVE_ID,
            %cmpres(&PHASE_SEQ_NB),
            %cmpres(&CMCTN_ROLE_CD),
            CMCTN_ID,
            ADDRESS1_TX,
            alternate2_TX,
            ADDRESS3_TX,
            ' ',
            CITY_TX,
            STATE,
            'N/A',
            ZIP_SUFFIX_CD,
            ' ',
            .,
            'QCPAP020',
            HSC_TS,
            'QCPAP020',
            HSU_TS
     FROM &DB2_TMP..&TABLE_PREFIX.INSERT_HIS
    WHERE CMCTN_ID>&MAX_CMCTN_ID;
  QUIT;

PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);

     EXECUTE (
     INSERT INTO &HERCULES..TCMCTN_SUBJECT_HIS
     SELECT DISTINCT &INITIATIVE_ID,
            %cmpres(&PHASE_SEQ_NB),
            &CMCTN_ROLE_CD,
            CMCTN_ID,
            recipient_id,
            0,
            CLIENT_ID,
            'QCPAP020',
            HSC_TS,
            'QCPAP020',
            HSU_TS
     FROM &DB2_TMP..&TABLE_PREFIX.INSERT_HIS
     WHERE CMCTN_ID>&MAX_CMCTN_ID) BY DB2;
     DISCONNECT FROM DB2;
  QUIT;

%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX.INSERT_HIS);



%MEND r2m_his_update;
%r2m_his_update(tbl_name_IN=data_pnd.init_212_extra
               , initiative_id=212
               , cmctn_role_cd=1);
