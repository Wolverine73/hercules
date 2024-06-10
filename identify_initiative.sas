/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Wednesday, November 30, 2005      TIME: 03:03:32 PM
   PROJECT: retail_to_mail_macros
   PROJECT PATH: G:\Documentation\Projects\Hercules\retail_to_mail_macros.seg
---------------------------------------- */
%LET INITIATIVE_ID=1167;
%LET PHASE_SEQ_NB=1;
%LET CLAIM_BEGIN_DT = '2005-01-01';
%LET CLAIM_END_DT = '2005-12-20';
%LET CLAIM_BEGIN_DT1 = '2005-01-01';
%LET CLAIM_END_DT1 = '2005-12-20';

%LET HERCULES = HERCULES;
%LET CLAIMSA=CLAIMSA;
LIBNAME &HERCULES DB2 DSN=&UDBSPRP SCHEMA=&HERCULES DEFER=YES;
LIBNAME &CLAIMSA  DB2 DSN=&UDBSPRP SCHEMA=&CLAIMSA  DEFER=YES;

PROC SQL;
  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
  CREATE TABLE NDC AS
  SELECT * from connection to db2
  (SELECT *
     FROM &CLAIMSA..TRXCLM_BASE AS A
     WHERE &CLAIM_BEGIN_DT1. <= A.FILL_DT 
       AND &CLAIM_END_DT1. >= A.FILL_DT
       AND A.CLIENT_ID=256
   )
;
quit;

%PUT SQLXMSG;

%macro skip;
DATA WORK.INITIATIVE_DATA;
/*     SET &HERCULES..TTASK;*/
     SET &HERCULES..TPHASE_RVR_FILE(WHERE=(INITIATIVE_ID=&INITIATIVE_ID
                                AND PHASE_SEQ_NB=&PHASE_SEQ_NB));
/*     KEEP INITIATIVE_ID CMCTN_ROLE_CD DATA_CLEANSING_CD DESTINATION_CD*/
/*          RELEASE_STATUS_CD RELEASE_TS ARCHIVE_STS_CD FILE_ID;*/
RUN;

/*PROC CONTENTS DATA=WORK.TPHASE_RVR_FILE VARNUM;*/
/*RUN;*/

%mend skip;
