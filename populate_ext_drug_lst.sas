** HEADER -----------------------------------------------------------------
 |  PROGRAM NAME: POPULATE EXT_DRUG_LST.SAS
 |
 |  PURPOSE: populate external drug list table that is created by the hercules
 |           screen when a user selected the option
 |           The name of the table to be populated is always in the pattern of
 |           &TABLE_PREFIX._ADHOC
 |
 |   Due to adhoc nature of the request the program has to be modified/verified
 |   each time. Please use it with cautions
 |
 | History:   J. Hou, Dec 2004
 + ------------------------------------------------------------------HEADER *;

 %set_sysmode;

         options sysparm='INITIATIVE_ID=509 PHASE_SEQ_NB=1';
         %INCLUDE "/PRG/sasprod1/hercules/hercules_in.sas";
%PUT &DB2_TMP..&TABLE_PREFIX._ADHOC;

libname SYSCAT db2 DSN=&UDBSPRP SCHEMA=SYSCAT DEFER=YES;

PROC SQL;
     CONNECT TO DB2 (DSN=&UDBSPRP);
     EXECUTE (
     INSERT INTO &DB2_TMP..&TABLE_PREFIX._ADHOC
     SELECT 1 AS DRUG_GROUP_SEQ_NB,
            1 AS DRUG_SUB_GRP_SEQ_NB,
            DRUG_NDC_ID,
            NHU_TYPE_CD
       FROM CLAIMSA.TDRUG1
       WHERE GENERIC_AVAIL_IN=1
       AND DRUG_BRAND_CD='B') BY DB2;
     DISCONNECT FROM DB2; QUIT;


   PROC SQL;
     CONNECT TO DB2 (DSN=&UDBSPRP);
     CREATE TABLE YOUNG_NDCS_CNT AS
     SELECT *  FROM CONNECTION TO DB2
     (SELECT COUNT (*) AS CNT
       FROM CLAIMSA.TDRUG1);
     DISCONNECT FROM DB2; QUIT;


 PROC SQL;
     CREATE TABLE TMP106.T_456_1_RVW_DATES AS
      select * from TMP106.T_424_1_RVW_DATES; QUIT;
