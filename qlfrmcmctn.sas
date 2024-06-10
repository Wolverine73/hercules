/*HEADER------------------------------------------------------------------------
|
| PROGRAM:     QLFRMCMCTN.sas (macro)
|
| LOCATION:    /PRG/sastest1/hercules/87/macros/QLFRMCMCTN
|
| PURPOSE:     Compares two DB2 Tables for matching NDCs and PODs to determine
|              drugs that mailing should run with those that had a change in formulary status. 
|              Records are then inserted into the DB2 temp table. 
|
| INPUT:       &TBLIN, 
|              &NDCTBL
|
| OUTPUT:      &TBLIN (uses &db2tmptbl to temporary hold results containing target drugs
|                      then drops &TBLIN and renames &db2tmptbl to &tblin )
|
| sample calls
| %QLFRMCMCTN(TBLIN=&DB2_TMP..&TABLE_PREFIX._NDC_X,NDCTBL=&DB2_TMP..&TABLE_PREFIX._NDC);
+--------------------------------------------------------------------------------
| HISTORY:  30MAR2007 - N.Williams - Hercules Version  1.5
|                       Original
|           26JAN2009 - N.Williams - Hercules Version  2.1.1
|                       Removed logic for including ptv code for only fyid# 61,
|                       as PTV code will now be included on every fyid.
|
+------------------------------------------------------------------------HEADER*/


*SASDOC-----------------------------------------------------------------------
| Need to make this code common bc it will be called by multiple mailings so need to know which one 
|  is calling it and do alittle something different for each */
+-----------------------------------------------------------------------SASDOC*;
%MACRO QLFRMCMCTN(TBLIN=,NDCTBL=);

*SASDOC-----------------------------------------------------------------------
|THIS WILL TEMP TABLE CREATED IN ALL OF NDC MERGES
+-----------------------------------------------------------------------SASDOC*;
%let DB2TMPTBL=&DB2_TMP..&TABLE_PREFIX._NDC_MRG; /*SO ONLY HAVE TO DEFINE ONCE */
%global PROGRAM_NAME;
%let PROGRAM_NAME=QLFRMCMCTN;

*SASDOC-----------------------------------------------------------------------
|THIS RENAME A TABLE FOR US.
+-----------------------------------------------------------------------SASDOC*;
%MACRO RENAMETBL;
%drop_db2_table(tbl_name=&TBLIN);
%local RTBL;
%let RTBL=%scan(%str(&TBLIN),2,%str(.));
PROC SQL NOPRINT;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
    EXECUTE(RENAME TABLE &DB2TMPTBL TO &RTBL) BY DB2;
DISCONNECT FROM DB2;
QUIT;
%MEND RENAMETBL;

%if %sysfunc(exist(&NDCTBL)) %then %do;
*SASDOC-----------------------------------------------------------------------
| CHECK NUMBER OF ROWS 
+-----------------------------------------------------------------------SASDOC*;
proc sql noprint;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
      select COUNT_NDC_DB2_TMP_TBL
      into   :COUNT_NDC_DB2_TMP_TBL
      from   connection to DB2
      (
      SELECT COUNT(*) as COUNT_NDC_DB2_TMP_TBL
      FROM   &NDCTBL 
      );
disconnect from DB2;
quit;
%end;

%MVAREXIST(COUNT_NDC_DB2_TMP_TBL) ;

%IF &MVAREXIST %THEN %DO ;

  %PUT &COUNT_NDC_DB2_TMP_TBL ;
  %PUT NOTE: &NDCTBL contains &COUNT_NDC_DB2_TMP_TBL observations.;

  *SASDOC-----------------------------------------------------------------------
  | run code for formulary_purge mailing
  +-----------------------------------------------------------------------SASDOC*;
  %IF (&PROGRAM_ID EQ 87 AND &TASK_ID EQ 3 AND &COUNT_NDC_DB2_TMP_TBL NE 0) %THEN %DO; 

    %drop_db2_table(tbl_name=&DB2TMPTBL);

*SASDOC-----------------------------------------------------------------------
| GET ALL DATA NEED FOR MERGE LATER.
+-----------------------------------------------------------------------SASDOC*;
   PROC SQL NOPRINT;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);

    EXECUTE(
      CREATE TABLE &DB2TMPTBL
                (DRUG_NDC_ID DECIMAL(11) NOT NULL,
                 NHU_TYPE_CD SMALLINT NOT NULL,
                 POD_ID INTEGER,
                 POD_NM CHAR(60),
                 CELL_NM CHAR (60),
                 DRUG_ABBR_PROD_NM CHAR(12),
                 DRUG_ABBR_DSG_NM CHAR(3),
                 DRUG_ABBR_STRG_NM CHAR(8),
                 GENERIC_AVAIL_IN SMALLINT,
                 GPI_GROUP CHAR(2),
                 GPI_CLASS CHAR(2),
                 GPI_SUBCLASS CHAR(2),
                 GPI_NAME CHAR(2),
                 GPI_NAME_EXTENSION CHAR(2),
                 GPI_FORM CHAR(2),
                 GPI_STRENGTH CHAR(2),
                 ORG_FRM_STS CHAR,
                 NEW_FRM_STS CHAR,             
		         ORG_PTV_CD SMALLINT,
		         NEW_PTV_CD SMALLINT,             
                 PRIMARY KEY(DRUG_NDC_ID, NHU_TYPE_CD))
    ) BY DB2;



     EXECUTE(INSERT INTO  &DB2TMPTBL
             SELECT   T2.DRUG_NDC_ID,
                      T2.NHU_TYPE_CD,
                      T1.POD_ID,
                      T1.POD_NM,
                      T1.CELL_NM,
                      T1.DRUG_ABBR_PROD_NM,
                      T1.DRUG_ABBR_DSG_NM,
                      T1.DRUG_ABBR_STRG_NM,
                      T1.GENERIC_AVAIL_IN,
                      T1.GPI_GROUP, 
                      T1.GPI_CLASS,
                      T1.GPI_SUBCLASS, 
                      T1.GPI_NAME,
                      T1.GPI_NAME_EXTENSION,
                      T1.GPI_FORM,
                      T1.GPI_STRENGTH,
                      T1.ORG_FRM_STS,                    
                      T1.NEW_FRM_STS,                   
		              T1.ORG_PTV_CD,
		              T1.NEW_PTV_CD
				   

             FROM     &TBLIN      T1,
                      &NDCTBL     T2

             WHERE T2.DRUG_NDC_ID = T1.DRUG_NDC_ID
             AND   T2.NHU_TYPE_CD = T1.NHU_TYPE_CD

             ) BY DB2;
  DISCONNECT FROM DB2;
  QUIT;


  %SET_ERROR_FL;

  %RUNSTATS(TBL_NAME=&DB2TMPTBL);

  *SASDOC-----------------------------------------------------------------------
  | rename the table created here to tblin name.
  +-----------------------------------------------------------------------SASDOC*;
  %RENAMETBL;

  %NOBS(&TBLIN);

   %IF &NOBS EQ 0 %THEN %DO;
      
       *SASDOC-----------------------------------------------------------------------
       | NO DRUGS TARGETED BC THEY WHERE NOT IN DRUG SETUP AND FORMULARY CHG.
       +-----------------------------------------------------------------------SASDOC*;
	   %on_error( ACTION=ABORT
	             ,EM_TO=&primary_programmer_email
	             ,EM_SUBJECT=HCE SUPPORT: Notification of Abend
	             ,EM_MSG=%str(The target drugs did not have a matching status change. See LOG file - &PROGRAM_NAME..log));       
   %END;
  %END;

  %ELSE 
  *SASDOC-----------------------------------------------------------------------
  | run code for incentivized_frm_no_N mailing
  +-----------------------------------------------------------------------SASDOC*;
  %IF (&PROGRAM_ID EQ 87 AND &TASK_ID EQ 2 AND &COUNT_NDC_DB2_TMP_TBL NE 0) %THEN %DO; 

  %drop_db2_table(tbl_name=&DB2TMPTBL);

  PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
      EXECUTE(
        CREATE TABLE &DB2TMPTBL
          (DRUG_NDC_ID DECIMAL(11) not null,
           NHU_TYPE_CD SMALLINT not null,
           POD_ID INTEGER,
           IN_FORMULARY_IN_CD SMALLINT,
           POD_NM CHAR(60),
           CELL_NM CHAR (60),
           GPI CHAR(14))
      )BY DB2;

     EXECUTE(INSERT INTO  &DB2TMPTBL
             SELECT   T2.DRUG_NDC_ID,
                      T2.NHU_TYPE_CD,
                      T1.POD_ID,
                      T1.IN_FORMULARY_IN_CD,
                      T1.POD_NM,
                      T1.CELL_NM,
                      T1.GPI

             FROM     &TBLIN      T1,
                      &NDCTBL     T2

             WHERE T2.DRUG_NDC_ID = T1.DRUG_NDC_ID
             AND   T2.NHU_TYPE_CD = T1.NHU_TYPE_CD

             ) BY DB2;
  DISCONNECT FROM DB2;
  QUIT;
  %SET_ERROR_FL;

  %RUNSTATS(TBL_NAME=&DB2TMPTBL);

  *SASDOC-----------------------------------------------------------------------
  | rename the table created here to tblin name.
  +-----------------------------------------------------------------------SASDOC*;
  %RENAMETBL;

  %NOBS(&TBLIN);

   %IF &NOBS EQ 0 %THEN %DO;
      
       *SASDOC-----------------------------------------------------------------------
       | NO DRUGS TARGETED BC THEY WHERE NOT IN DRUG SETUP AND FORMULARY CHG.
       +-----------------------------------------------------------------------SASDOC*;
	   %on_error( ACTION=ABORT
	             ,EM_TO=&primary_programmer_email
	             ,EM_SUBJECT=HCE SUPPORT: Notification of Abend
	             ,EM_MSG=%str(The target drugs did not have a matching status change. See LOG file - &PROGRAM_NAME..log));       
   %END;
  %END;
%END;
%MEND QLFRMCMCTN;
