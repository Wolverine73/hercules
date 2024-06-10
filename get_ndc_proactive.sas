%*HEADER-----------------------------------------------------------------------
| MACRO:    get_ndc_proactive
|
| LOCATION: /PRG/sas%lowcase(&SYSMODE)1/hercules/macros
|
| USAGE:    get_ndc(DRUG_NDC_TBL=,CLAIM_DATE_TBL=)
|
| Eg. options %get_ndc(DRUG_NDC_TBL=TMP55.MY_NDC)
|             %get_ndc(DRUG_NDC_TBL=TMP55.MY_NDC,CLAIM_DATE_TBL=TMP55.MY_DATE)
|
| PURPOSE:  1) If type of setup is "initiative" (DRG_DEFINITION_CD eq 1 or 5)
|              or "program" (DRG_DEFINITION_CD eq 2) 
|              then determines the drugs (NDCs) for targeting claims.
|           2) If type of setup is "initiative" (DRG_DEFINITION_CD eq 1)
|              then also determines claim review dates.
|
| LOGIC:    If Drug Definition Code eq 1 or 5 (Initiative) then
|              If External Drug List Indicator (EXT_DRG_LST_IN) is true (1)
|              (the user is supplying a list of drugs) then
|                 Select Initiative Drug Groups, Subgroups,
|                    Claim Review Begin and End dates by matching external list
|                    with HERCULES tables by Group & Subgroup.
|                 Validate the Groups and Subgroups in the external list exist
|                    in HERCULES TINIT_DRUG_GROUP and TINIT_DRUG_SUB_GRP.
|              Else
|              IF an external list was not used then
|                 Select Initiative Drug Groups, Subgroups, Drug IDs
|                    Claim Review Begin and End dates by matching external list
|                    with HERCULES tables by Initiative ID.
|                 Join HERCULES Drug IDs with CLAIMS Drug IDs by GPI, NDC-9 or
|                    NDC-11 keys.
|           Create output tables.
|           Load output tables.
|
| INPUT:    &DRUG_NDC_TBL (Drug NDC Table Name)
|           &CLAIM_DATE_TBL (Claim Date Table Name)
|           &INITIATIVE_ID, &PHASE_SEQ_NB, &DRG_DEFINITION_CD, &EXT_DRG_LST_IN
|           &CLAIMSA..TDRUG1
|           &HERCULES..TDRUG_SUB_GRP_DTL
|           &HERCULES..TINIT_DRUG_GROUP
|           &HERCULES..TINIT_DRUG_SUB_GRP
|           &HERCULES..TPHASE_DRG_GRP_DT
|           &NDC_SCHEMA..&EXT_LST_TBL_NM (external drug list)
|
| OUTPUT:   &DRUG_NDC_TBL (Drug NDC Table)
|           &CLAIM_DATE_TBL (Claim Date Table)
+------------------------------------------------------------------------------
| HISTORY:  12Oct2003 - L.Kummen  - Original (after J.Hou)
|           Sept. 2004 - John Hou
|
|                  added init_id and phase_nb to facilitate the need of the
|                        macro being called from the Hercules Reports modules and
|                        avoid initiative_id conflict with the hercules_job_masters
|  
|             When called by the task programs there is no changes needed. The macro
|                  has default:
|                              init_id=&initiative_id,
|                              phase_nb=&phase_seq_nb
|                                  
|              when called from reports:
|                  it can be:  init_id=&_initiative_id,
|                              phase_nb=&_phase_seq_nb
|              The get_ndc macro is also expecting &EXT_DRUG_LIST_IN and
|              &DRG_DEFINITION_CD which can be created by either call hercules_in.sas
|              or have them resolved in the calling program before the %get_ndc
|              is called. Please refer quality_phone_lst.sas for a sample usage.
|
|        Yury Vilk, 12/08/2004 
|				    Added code that enables setting restriction on 
|					EXCLUDE_OTC_IN and BRD_GNRC_OPT_CD. When at least one of the fields 
|					is not NULL the ALL_DRUG_IN is reset to zero and the NDC table 
|					is always created. 
|
|           30MAR2007 - N.Williams - Hercules Version  1.5 
|                                    Added logic to handle new Drug Definition Code 5.
|                                    - 2 queries (get incl/excl counts)
|                                    - When incl turned on only pull incls only.
|                                    - If both incl/excl both on pull only incls.
|                                    - Select all drugs minus excl drugs when excl turned
|                                      on with incl off. 
|
|			31MAR2008 - S.Yaramada - Hercules Version  2.1.01
|									 Added logic to handle all three adjudication engines.  
|
|     04DEC2008 - RS - Hercules Version 2.2.02
|                  add program id 106 and task 34 to condition
|     10JUN2009 - GD - Hercules Version 2.2.03
|                  Removed the use of the table HERCULES.TPROGRAM_GPI_HIS
|                  used for the exclusion on Thyroid products and 
|                  hormone treatments 
|								   	
+----------------------------------------------------------------------HEADER*;

%put SASDOC-----------------------------------------------------------------------;
%put | Macro is modifed to handle RX and RE claims along with QL claims.;
%put | S.Yaramada 31MAR2008;
%put |----------------------------------------------------------------------SASDOC;

%macro get_ndc_proactive(DRUG_NDC_TBL=,
        			 DRUG_NDC_TBL_RX=,
        			 DRUG_NDC_TBL_RE=, 			
               CLAIM_DATE_TBL=,	   			
         			 init_id=&initiative_id,
               phase_nb=&phase_seq_nb);


%local PRIMARY_PROGRAMMER_EMAIL init_id phase_nb;
%local DB2_TMP_TBL COUNT_DB2_TMP_TBL;
%global err_fl DEBUG_FLAG COUNT_DRUG_NDC_ID_DB2_TMP_TBL PROG_NAME;
%let err_fl      =0;
%let PROG_NAME = GET_NDC;

%put *SASDOC-----------------------------------------------------------------------;
%put | Default names to the output tables.;
%put | S.Yaramada 30JUL2008;
%put ----------------------------------------------------------------------SASDOC*;

%IF &DRUG_NDC_TBL = 	%THEN 
	%LET DRUG_NDC_TBL = &DB2_TMP..&TABLE_PREFIX._NDC_QL;
%IF &DRUG_NDC_TBL_RX = 	%THEN 
	%LET DRUG_NDC_TBL_RX = &ORA_TMP..&TABLE_PREFIX._NDC_RX;
%IF &DRUG_NDC_TBL_RE = 	%THEN 
	%LET DRUG_NDC_TBL_RE = &ORA_TMP..&TABLE_PREFIX._NDC_RE;
%IF &CLAIM_DATE_TBL = 	%THEN 
	%LET CLAIM_DATE_TBL = &DB2_TMP..&TABLE_PREFIX._RVW_DATES;

%PUT NOTE: &DRUG_NDC_TBL;
%PUT NOTE: &DRUG_NDC_TBL_RX;
%PUT NOTE: &DRUG_NDC_TBL_RE;
%PUT NOTE: &CLAIM_DATE_TBL;


%put *SASDOC-----------------------------------------------------------------------;
%put | In order to minimize the changes to the code, DRUG_NDC_TBL_QL is initialized; 
%put | to the macro variable DRUG_NDC_TBL so that the table naming remains in sync ;
%put | with the existing code for QL adjudication engine.;
%put | S.Yaramada 28JUN2008;
%put ----------------------------------------------------------------------SASDOC*;
%LET DRUG_NDC_TBL_QL=&DRUG_NDC_TBL;

%put NOTE: DRUG_NDC_TBL = &DRUG_NDC_TBL;
%put NOTE: DRUG_NDC_TBL_RX = &DRUG_NDC_TBL_RX;
%put NOTE: DRUG_NDC_TBL_RE = &DRUG_NDC_TBL_RE;

%LET DRUG_NDC_TBL= &DB2_TMP..&TABLE_PREFIX._NDC_TEMP;
%LET DRUG_NDC_TBL_EDW= &ORA_TMP..&TABLE_PREFIX._NDC_EDW;

%LET COUNT_NON_MATCH_DRG_GRP_SUB_GRP=0;
%LET COUNT_DRUG_NDC_ID_DB2_TMP_TBL=0;
%LET COUNT_EXT_LST_TBL=0;
%LET COUNT_DB2_TMP_TBL=0;
%LET COUNT_CLAIM_DATE_TBL=0;

/**** ADDED BY G. DUDLEY 6/24/2008 ***/
%LET INITIATIVE_ID=&INIT_ID;
%LET PHASE_SEQ_NB=&PHASE_NB;
/**** ADDED BY G. DUDLEY 6/24/2008 ***/

%put *SASDOC-----------------------------------------------------------------------;
%put | List adjudication executing;
%put ----------------------------------------------------------------------SASDOC*;

%put NOTE: QL_ADJ= &QL_ADJ.;
%put NOTE: RX_ADJ= &RX_ADJ.;
%put NOTE: RE_ADJ= &RE_ADJ.;
%put NOTE: EXT_DRUG_LIST_IN= &EXT_DRUG_LIST_IN;
%put NOTE: DRG_DEFINITION_CD= &DRG_DEFINITION_CD;

%put *SASDOC-----------------------------------------------------------------------;
%put | Set the parameters for error checking.;
%put ----------------------------------------------------------------------SASDOC*;
proc sql noprint;
select quote(trim(left(email)))
into   :PRIMARY_PROGRAMMER_EMAIL separated by ' '
from   ADM_LKP.ANALYTICS_USERS
where  upcase(QCP_ID) in ("&USER");
quit;

%PUT NOTE: PRIMARY_PROGRAMMER_EMAIL = &PRIMARY_PROGRAMMER_EMAIL;

%LET DRUG_FIELDS_FLAG=1;

%*SASDOC-----------------------------------------------------------------------
| DRUG COLUMN NAMES
+----------------------------------------------------------------------SASDOC*;
PROC SQL NOPRINT;
  SELECT (COUNT(*)>0) INTO : DRUG_FIELDS_FLAG
  FROM 		&HERCULES..TFILE_FIELD          AS A,
          	&HERCULES..TFIELD_DESCRIPTION AS B,
          	&HERCULES..TPHASE_RVR_FILE   	AS C
                WHERE INITIATIVE_ID=&INITIATIVE_ID
                  AND PHASE_SEQ_NB=&PHASE_SEQ_NB
                  AND A.FILE_ID = C.FILE_ID
              	  AND A.FIELD_ID = B.FIELD_ID
      			      AND  FIELD_NM IN ('DRUG_ABBR_PROD_NM','DRUG_ABBR_STRG_NM',
									'DRUG_ABBR_DSG_NM','DRUG_NDC_ID','NHU_TYPE_CD')
;
QUIT;

%PUT NOTE: DRUG_FIELDS_FLAG=&DRUG_FIELDS_FLAG.;

*SASDOC-----------------------------------------------------------------------
| N. Williams 30MAR2007 - add query to check if user specified drugs as inclusion.
+----------------------------------------------------------------------SASDOC*;
PROC SQL NOPRINT NOERRORSTOP;
connect to DB2 as DB2(dsn=&UDBSPRP);

select INCL_DRUGS
into   :INCL_DRUGS
from   connection to DB2
(
      SELECT  COUNT(*) as INCL_DRUGS

      FROM    &HERCULES..TINIT_DRUG_GROUP   A
             ,&HERCULES..TINIT_DRUG_SUB_GRP B
			       ,&HERCULES..TDRUG_SUB_GRP_DTL  C

      WHERE   A.INITIATIVE_ID      = &INITIATIVE_ID
        AND   A.INITIATIVE_ID      = B.INITIATIVE_ID
  	    AND   B.INITIATIVE_ID      = C.INITIATIVE_ID
        AND   A.DRG_GROUP_SEQ_NB   = B.DRG_GROUP_SEQ_NB
        AND   B.DRG_SUB_GRP_SEQ_NB = C.DRG_SUB_GRP_SEQ_NB
        AND   C.INCLUDE_IN         = 1 
);
DISCONNECT FROM DB2;
QUIT;

%PUT NOTE: INCL_DRUGS=&INCL_DRUGS.;

*SASDOC-----------------------------------------------------------------------
| N. Williams 30MAR2007 - add query to check if user specified drugs as exclusion.
+----------------------------------------------------------------------SASDOC*;
PROC SQL NOPRINT NOERRORSTOP;
connect to DB2 as DB2(dsn=&UDBSPRP);

select EXCL_DRUGS
into  :EXCL_DRUGS
from   connection to DB2
(
      SELECT  COUNT(*) as EXCL_DRUGS

      FROM    &HERCULES..TINIT_DRUG_GROUP   A
             ,&HERCULES..TINIT_DRUG_SUB_GRP B
      			 ,&HERCULES..TDRUG_SUB_GRP_DTL  C

      WHERE   A.INITIATIVE_ID      = &INITIATIVE_ID
        AND   A.INITIATIVE_ID      = B.INITIATIVE_ID
  	    AND   B.INITIATIVE_ID      = C.INITIATIVE_ID
        AND   A.DRG_GROUP_SEQ_NB   = B.DRG_GROUP_SEQ_NB
        AND   B.DRG_SUB_GRP_SEQ_NB = C.DRG_SUB_GRP_SEQ_NB
        AND   C.INCLUDE_IN         = 0 
);
DISCONNECT FROM DB2;
QUIT;

%PUT NOTE: EXCL_DRUGS=&EXCL_DRUGS.;

%*SASDOC-----------------------------------------------------------------------
| Drop tables.
+----------------------------------------------------------------------SASDOC*;
%if (%cmpres(&DRUG_NDC_TBL) ne) %then
   %drop_db2_table(tbl_name=&DRUG_NDC_TBL);
%if (%cmpres(&CLAIM_DATE_TBL) ne) %then
   %drop_db2_table(tbl_name=&CLAIM_DATE_TBL);

%*SASDOC-----------------------------------------------------------------------
| If Drug Definition Code eq 1 (Initiative).
| March 2007 - N.Williams Add logic for Drug Definition Code eq 5 (Initiative)
+----------------------------------------------------------------------SASDOC*;
%if (&DRG_DEFINITION_CD eq 1 OR &DRG_DEFINITION_CD eq 5) %then
%do;
   %let DB2_TMP_TBL=&DB2_TMP..&TABLE_PREFIX._&PROG_NAME;
   %drop_db2_table(tbl_name=&DB2_TMP_TBL);

%*SASDOC-----------------------------------------------------------------------
| Create a temporary table.
+----------------------------------------------------------------------SASDOC*;
   proc sql noprint;
   connect to DB2 as DB2(dsn=&UDBSPRP AUTOCOMMIT=NO);
   execute
   (
   CREATE TABLE &DB2_TMP_TBL
          ( DRG_GROUP_SEQ_NB   SMALLINT NOT NULL
           ,DRG_SUB_GRP_SEQ_NB SMALLINT NOT NULL
           ,CLAIM_BEGIN_DT     DATE
           ,CLAIM_END_DT       DATE
           ,ALL_DRUG_IN        SMALLINT
           ,CTS_DRUG_IN        SMALLINT
    		   ,INCLUDE_IN         SMALLINT
           ,DRUG_NDC_ID        DECIMAL(11)
           ,NHU_TYPE_CD        SMALLINT
    			,DRUG_ABBR_DSG_NM    CHAR(3)
    			,DRUG_ABBR_PROD_NM   CHAR(12)
    			,DRUG_ABBR_STRG_NM   CHAR(8)
    			,DRUG_BRAND_CD       CHAR(1) )
   NOT LOGGED INITIALLY
   )
   by DB2;
   execute
   (
   ALTER TABLE &DB2_TMP_TBL ACTIVATE NOT LOGGED INITIALLY
   )
   by DB2;
   execute
   (
   COMMIT
   )
   by DB2;
   disconnect from DB2;
   quit;

%*SASDOC-----------------------------------------------------------------------
| If External Drug List Indicator (EXT_DRG_LST_IN) is true (1).
| March 2007 - N.Williams Add logic to not execute If Drug Definition Code eq 5
+----------------------------------------------------------------------SASDOC*;
   %if (&EXT_DRUG_LIST_IN eq 1 and &DRG_DEFINITION_CD ne 5) %then
   %do;

%*SASDOC-----------------------------------------------------------------------
| Assign name of external drug list table to macro variable.
+----------------------------------------------------------------------SASDOC*;
      %local EXT_LST_TBL;
      %let EXT_LST_TBL=&DB2_TMP..&TABLE_PREFIX._ADHOC;

%*SASDOC-----------------------------------------------------------------------
| Insert matching Groups, Sub-Groups, and Initiative Claim Begin & End Dates
| into temporary table.  These were created dirung the initiative setup 
| within the HCE
+----------------------------------------------------------------------SASDOC*;
      proc sql noprint NOERRORSTOP;
      connect to DB2 as DB2(dsn=&UDBSPRP AUTOCOMMIT=NO);
      execute
      (
      INSERT INTO &DB2_TMP_TBL
            ( DRG_GROUP_SEQ_NB
             ,DRG_SUB_GRP_SEQ_NB
             ,CLAIM_BEGIN_DT
             ,CLAIM_END_DT
             ,ALL_DRUG_IN
             ,CTS_DRUG_IN
      			 ,INCLUDE_IN
             ,DRUG_NDC_ID
             ,NHU_TYPE_CD
             	,DRUG_ABBR_DSG_NM
    					,DRUG_ABBR_PROD_NM
    					,DRUG_ABBR_STRG_NM
    					,DRUG_BRAND_CD)

      SELECT  A.DRG_GROUP_SEQ_NB
             ,C.DRG_SUB_GRP_SEQ_NB
             ,B.CLAIM_BEGIN_DT
             ,B.CLAIM_END_DT
             ,C.ALL_DRUG_IN
      			 ,1 as INCLUDE_IN
             ,D.DRUG_NDC_ID
             ,D.NHU_TYPE_CD
    					,DRUG_ABBR_DSG_NM
    					,DRUG_ABBR_PROD_NM
    					,DRUG_ABBR_STRG_NM
    					,DRUG_BRAND_CD
      FROM    &HERCULES..TINIT_DRUG_GROUP   A
             ,&HERCULES..TPHASE_DRG_GRP_DT  B
             ,&HERCULES..TINIT_DRUG_SUB_GRP C
             ,&EXT_LST_TBL                  D
      WHERE   A.INITIATIVE_ID      = &init_id
        AND   A.INITIATIVE_ID      = B.INITIATIVE_ID
        AND   B.PHASE_SEQ_NB       = &phase_nb
        AND   A.DRG_GROUP_SEQ_NB   = B.DRG_GROUP_SEQ_NB
        AND   A.INITIATIVE_ID      = C.INITIATIVE_ID
        AND   A.DRG_GROUP_SEQ_NB   = C.DRG_GROUP_SEQ_NB
        AND   C.DRG_GROUP_SEQ_NB   = D.DRUG_GROUP_SEQ_NB
        AND   C.DRG_SUB_GRP_SEQ_NB = D.DRUG_SUB_GRP_SEQ_NB
      ORDER BY DRUG_NDC_ID, NHU_TYPE_CD, DRG_GROUP_SEQ_NB, DRG_SUB_GRP_SEQ_NB
      )
      by DB2;
      %let _GETNDC_DB2_TMP_TBL_SYSDBRC=&SYSDBRC;

	  select COUNT_EXT_LST_TBL
      into   :COUNT_EXT_LST_TBL
      from   connection to DB2
      (
      SELECT COUNT(*) as COUNT_EXT_LST_TBL
      FROM   &EXT_LST_TBL.
      );

      select COUNT_DB2_TMP_TBL
      into   :COUNT_DB2_TMP_TBL
      from   connection to DB2
      (
      SELECT COUNT(*) as COUNT_DB2_TMP_TBL
      FROM   &DB2_TMP_TBL
      );

      select count(*)
      into   :COUNT_NON_MATCH_DRG_GRP_SUB_GRP
      from   connection to DB2
      (
      SELECT DISTINCT DRUG_GROUP_SEQ_NB   AS DRG_GROUP_SEQ_NB, 
					  DRUG_SUB_GRP_SEQ_NB AS DRG_SUB_GRP_SEQ_NB
      FROM   &EXT_LST_TBL
      EXCEPT ALL
      SELECT DISTINCT DRG_GROUP_SEQ_NB, 
					  DRG_SUB_GRP_SEQ_NB
      FROM   &DB2_TMP_TBL
      );

	  select COUNT_DRUG_NDC_ID_DB2_TMP_TBL
      into   :COUNT_DRUG_NDC_ID_DB2_TMP_TBL
      from   connection to DB2
      (
      SELECT COUNT(DRUG_NDC_ID) as COUNT_DRUG_NDC_ID_DB2_TMP_TBL
      FROM   &DB2_TMP_TBL
      );

      %PUT SQLXRC=&SQLXRC SYSERR=&SYSERR;
  	  %reset_sql_err_cd;
      quit;

      %if (&COUNT_NON_MATCH_DRG_GRP_SUB_GRP ne 0 OR &COUNT_EXT_LST_TBL.=0) %then
      %do;
         %let err_fl=1;
         %put ERROR: External list Groups/Sub-Groups do not match Initiative Groups/Sub-Groups;
         %put ERROR: INITIATIVE:&init_id  EXTERNAL LIST:&EXT_LST_TBL;
	  %if (&COUNT_EXT_LST_TBL.=0) 
          %then %PUT ERROR: EXTERNAL DRUG TABLE &EXT_LST_TBL IS EMPTY;
      %end;   %*if (&COUNT_NON_MATCH_DRG_GRP_SUB_GRP ne 0);

   %end;   %*if (&EXT_DRUG_LIST_IN eq 1);
   %else

%*SASDOC-----------------------------------------------------------------------
| If an external list was not used, select the drug definition from Hercules
| schema.
+----------------------------------------------------------------------SASDOC*;
   %if (&EXT_DRUG_LIST_IN eq 0) %then
   %do;
      proc sql noprint;
      connect to DB2 as DB2(dsn=&UDBSPRP AUTOCOMMIT=NO);
      execute
      (
      INSERT INTO &DB2_TMP_TBL
            ( DRG_GROUP_SEQ_NB
             ,DRG_SUB_GRP_SEQ_NB
             ,CLAIM_BEGIN_DT
             ,CLAIM_END_DT
             ,ALL_DRUG_IN
             ,CTS_DRUG_IN
      			 ,INCLUDE_IN
             ,DRUG_NDC_ID
             ,NHU_TYPE_CD)
      SELECT  A.DRG_GROUP_SEQ_NB
             ,A.DRG_SUB_GRP_SEQ_NB
             ,A.CLAIM_BEGIN_DT
             ,A.CLAIM_END_DT
             ,CASE
			  WHEN   COALESCE(A.RX_IN,A.GENERIC_AVAIL_IN) IS NOT NULL 
			  	OR A.DRUG_BRAND_CD IS NOT NULL
			    OR &DRUG_FIELDS_FLAG.=1
               THEN 						0
			   ELSE 						A.ALL_DRUG_IN
			  END AS ALL_DRUG_IN
			 ,A.INCLUDE_IN
             ,B.DRUG_NDC_ID
             ,B.NHU_TYPE_CD
      FROM
         (
         SELECT  A.DRG_GROUP_SEQ_NB
                ,A.DRG_SUB_GRP_SEQ_NB
                ,A.CLAIM_BEGIN_DT
                ,A.CLAIM_END_DT
                ,A.ALL_DRUG_IN
                ,A.CTS_DRUG_IN
        				,B.INCLUDE_IN
                ,B.DRUG_ID_TYPE_CD
                ,DECIMAL(B.DRUG_ID,14)               AS DRUG_PRODUCT_NDC_ID
                ,NULLIF(SUBSTR(B.DRUG_ID,01,2),'  ') AS GPI_GROUP
                ,NULLIF(SUBSTR(B.DRUG_ID,03,2),'  ') AS GPI_CLASS
                ,NULLIF(SUBSTR(B.DRUG_ID,05,2),'  ') AS GPI_SUBCLASS
                ,NULLIF(SUBSTR(B.DRUG_ID,07,2),'  ') AS GPI_NAME
                ,NULLIF(SUBSTR(B.DRUG_ID,09,2),'  ') AS GPI_NAME_EXTENSION
                ,NULLIF(SUBSTR(B.DRUG_ID,11,2),'  ') AS GPI_FORM
                ,NULLIF(SUBSTR(B.DRUG_ID,13,2),'  ') AS GPI_STRENGTH
                ,B.NHU_TYPE_CD
				,CASE A.EXCLUDE_OTC_IN 
                   WHEN 1			     THEN 1
				   WHEN 0				 THEN NULL
				   ELSE						  NULL
                 END								  AS RX_IN
				,CASE A.BRD_GNRC_OPT_CD
				   WHEN 1  				 THEN NULL
				   WHEN 2				 THEN 'G'
				   ELSE				 		  'B'
				END 								 AS DRUG_BRAND_CD
				, CASE A.BRD_GNRC_OPT_CD
				     WHEN 4				THEN 1
					 ELSE					 NULL 
				  END								 AS GENERIC_AVAIL_IN
         FROM
            (
            SELECT  A.INITIATIVE_ID
                   ,A.DRG_GROUP_SEQ_NB
                   ,B.CLAIM_BEGIN_DT
                   ,B.CLAIM_END_DT
                   ,C.DRG_SUB_GRP_SEQ_NB
                   ,C.ALL_DRUG_IN
				   ,A.EXCLUDE_OTC_IN
				   ,C.BRD_GNRC_OPT_CD
            FROM    &HERCULES..TINIT_DRUG_GROUP   A
                   ,&HERCULES..TPHASE_DRG_GRP_DT  B
                   ,&HERCULES..TINIT_DRUG_SUB_GRP C
            WHERE  A.INITIATIVE_ID      = &init_id
              AND  A.INITIATIVE_ID      = B.INITIATIVE_ID
              AND  B.PHASE_SEQ_NB       = &phase_nb
              AND  A.DRG_GROUP_SEQ_NB   = B.DRG_GROUP_SEQ_NB
              AND  A.INITIATIVE_ID      = C.INITIATIVE_ID
              AND  A.DRG_GROUP_SEQ_NB   = C.DRG_GROUP_SEQ_NB
            )
                AS A
                LEFT JOIN
                &HERCULES..TDRUG_SUB_GRP_DTL AS B
          ON A.INITIATIVE_ID      = B.INITIATIVE_ID
         AND A.DRG_GROUP_SEQ_NB   = B.DRG_GROUP_SEQ_NB
         AND A.DRG_SUB_GRP_SEQ_NB = B.DRG_SUB_GRP_SEQ_NB
         )
          AS A
          LEFT JOIN
          &CLAIMSA..TDRUG1 AS B
      ON
         ( 	

/*	if all drug indicator with restrictions. */

			 (     A.ALL_DRUG_IN = 1 
/*	EXCLUDE SPECIALTY DRUGS */
         AND CTS_DRUG_IN = 0
			   AND (   COALESCE(A.RX_IN,A.GENERIC_AVAIL_IN) IS NOT NULL 
			   		OR A.DRUG_BRAND_CD IS NOT NULL OR &DRUG_FIELDS_FLAG.=1)
			   AND (     A.RX_IN 			IS NULL OR 
			             A.RX_IN			=B.RX_IN)
			   AND (   A.DRUG_BRAND_CD	 IS NULL 
     				OR A.DRUG_BRAND_CD	=B.DRUG_BRAND_CD)
			  AND (   A.GENERIC_AVAIL_IN	 IS NULL 
     				OR A.GENERIC_AVAIL_IN	=B.GENERIC_AVAIL_IN) 
			 )

/* if target drug type is GPI. */

          OR (  (A.DRUG_ID_TYPE_CD        = 1)
             AND(  (   A.GPI_GROUP          = B.GPI_GROUP)
                AND(   A.GPI_CLASS          IS NULL
                    OR A.GPI_CLASS          = B.GPI_CLASS)
                AND(   A.GPI_SUBCLASS       IS NULL
                    OR A.GPI_SUBCLASS       = B.GPI_SUBCLASS)
                AND(   A.GPI_NAME           IS NULL
                    OR A.GPI_NAME           = B.GPI_NAME)
                AND(   A.GPI_NAME_EXTENSION IS NULL
                    OR A.GPI_NAME_EXTENSION = B.GPI_NAME_EXTENSION)
                AND(   A.GPI_FORM           IS NULL
                    OR A.GPI_FORM           = B.GPI_FORM)
                AND(   A.GPI_STRENGTH       IS NULL
                    OR A.GPI_STRENGTH       = B.GPI_STRENGTH)
				AND (   A.RX_IN 			IS NULL 
     				 OR A.RX_IN			=B.RX_IN)
				AND (   A.DRUG_BRAND_CD	 IS NULL 
     				 OR A.DRUG_BRAND_CD	=B.DRUG_BRAND_CD)
				AND (   A.GENERIC_AVAIL_IN	 IS NULL 
     				 OR A.GENERIC_AVAIL_IN	=B.GENERIC_AVAIL_IN)  
				) 
              )

/* if target drug type is NDC-9. */

         OR (    (A.DRUG_ID_TYPE_CD     = 2)
             AND (A.DRUG_PRODUCT_NDC_ID = B.DRUG_PRODUCT_ID)
			 AND (   A.RX_IN 			IS NULL 
			      OR A.RX_IN			=B.RX_IN)
		 	 AND (   A.DRUG_BRAND_CD	 IS NULL 
			      OR A.DRUG_BRAND_CD	=B.DRUG_BRAND_CD)
	     	 AND (   A.GENERIC_AVAIL_IN	 IS NULL 
			      OR A.GENERIC_AVAIL_IN	=B.GENERIC_AVAIL_IN) 
			)

/* if target drug type is NDC-11. */

         OR (   (    A.DRUG_ID_TYPE_CD     = 3)
             AND(    A.DRUG_PRODUCT_NDC_ID =B.DRUG_NDC_ID)
             AND(    A.NHU_TYPE_CD IS NULL
                 OR  A.NHU_TYPE_CD =  	B.NHU_TYPE_CD  )
			 )

/* if target drug type is GCN. */

		OR (   (    A.DRUG_ID_TYPE_CD     = 4)
             AND(    A.DRUG_PRODUCT_NDC_ID =B.DGH_GCN_CD)
             AND (   A.RX_IN 			IS NULL 
			      OR A.RX_IN			=B.RX_IN)
		 	 AND (   A.DRUG_BRAND_CD	 IS NULL 
			      OR A.DRUG_BRAND_CD	=B.DRUG_BRAND_CD)
	     	 AND (   A.GENERIC_AVAIL_IN	 IS NULL 
			      OR A.GENERIC_AVAIL_IN	=B.GENERIC_AVAIL_IN) 
			 )
         )
         AND(   (TIMESTAMPDIFF(256,CHAR(TIMESTAMP_ISO(A.CLAIM_BEGIN_DT) - TIMESTAMP_ISO(B.DISCONTINUANCE_DT))) < 3)
             OR (B.DISCONTINUANCE_DT IS NULL))
      )
      BY DB2;

      %let _GETNDC_DB2_TMP_TBL_SYSDBRC =&SYSDBRC;

      disconnect from DB2;
      quit;

	%*SASDOC-----------------------------------------------------------------------
	| Inclusion/exclusion of drugs. 
	+----------------------------------------------------------------------SASDOC*;
   %if ( &INCL_DRUGS gt 0 and &EXCL_DRUGS gt 0 ) %then
   %do;
  *SASDOC-----------------------------------------------------------------------
   | Logic to include drugs only in output table. - if specified include n exclude
   | remove exclusions keep inclusion.
   +----------------------------------------------------------------------SASDOC*;

PROC SQL NOPRINT;
SELECT DRUG_NDC_ID into: DRUG_NDC_ID separated by ',' FROM &DB2_TMP_TBL
WHERE INCLUDE_IN = 0
AND DRUG_NDC_ID IS NOT NULL;
QUIT;

%PUT NOTE: NDCS_EXCLUDED = &DRUG_NDC_ID;

PROC SQL NOPRINT;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
EXECUTE(DELETE FROM &DB2_TMP_TBL 
WHERE DRUG_NDC_ID IN (&DRUG_NDC_ID)
OR INCLUDE_IN = 0) BY DB2;
QUIT;

   %end;
   %else %if ( &EXCL_DRUGS gt 0 and &INCL_DRUGS le 0 ) %then
   %do;
		%*SASDOC-----------------------------------------------------------------------
		|  Pull All Drugs then Check what has been setup inclusion/exculsion based 
		|  to decide what to place in the output table.  N. Williams 30MAR2007
		+----------------------------------------------------------------------SASDOC*;
		   %let DB2_TMP_TBL2=&DB2_TMP..&TABLE_PREFIX._ALL_NDC;
		   %drop_db2_table(tbl_name=&DB2_TMP_TBL2);

		%*SASDOC-----------------------------------------------------------------------
		| Create a temporary table. - N. Williams
		+----------------------------------------------------------------------SASDOC*;
		   proc sql noprint;
		   connect to DB2 as DB2(dsn=&UDBSPRP AUTOCOMMIT=NO);
		   execute
		   (
		   CREATE TABLE &DB2_TMP_TBL2
		          ( DRG_GROUP_SEQ_NB   SMALLINT NOT NULL
		           ,DRG_SUB_GRP_SEQ_NB SMALLINT NOT NULL
		           ,CLAIM_BEGIN_DT     DATE
		           ,CLAIM_END_DT       DATE
		           ,ALL_DRUG_IN        SMALLINT 
               ,CTS_DRUG_IN        SMALLINT
    				   ,INCLUDE_IN         SMALLINT
		           ,DRUG_NDC_ID        DECIMAL(11)
		           ,NHU_TYPE_CD        SMALLINT
    					,DRUG_ABBR_DSG_NM    CHAR(3)
    					,DRUG_ABBR_PROD_NM   CHAR(12)
    					,DRUG_ABBR_STRG_NM   CHAR(8)
    					,DRUG_BRAND_CD       CHAR(1) )
		   NOT LOGGED INITIALLY
		   )
		   by DB2;
		   execute
		   (
		   ALTER TABLE &DB2_TMP_TBL2 ACTIVATE NOT LOGGED INITIALLY
		   )
		   by DB2;
		   execute
		   (
		   COMMIT
		   )
		   by DB2;
		   disconnect from DB2;
		   quit;

		%*SASDOC-----------------------------------------------------------------------
		| Pull all drugs ndc that our active on claims begin date from drug setup. 
		+----------------------------------------------------------------------SASDOC*;
      proc sql noprint;
      connect to DB2 as DB2(dsn=&UDBSPRP AUTOCOMMIT=NO);
      execute
      ( 
         INSERT INTO &DB2_TMP_TBL2
            ( DRUG_NDC_ID
             ,NHU_TYPE_CD
    				 ,DRUG_ABBR_DSG_NM
    				 ,DRUG_ABBR_PROD_NM
    				 ,DRUG_ABBR_STRG_NM
    				 ,DRUG_BRAND_CD
             ,DRG_GROUP_SEQ_NB   
             ,DRG_SUB_GRP_SEQ_NB
             ,CLAIM_BEGIN_DT     
             ,CLAIM_END_DT       
             ,ALL_DRUG_IN       
             ,CTS_DRUG_IN
             ,INCLUDE_IN
            )
         SELECT  DISTINCT
                 A.DRUG_NDC_ID
                ,A.NHU_TYPE_CD
    						,DRUG_ABBR_DSG_NM
    						,DRUG_ABBR_PROD_NM
    						,DRUG_ABBR_STRG_NM
    						,DRUG_BRAND_CD
        				,1 as DRG_GROUP_SEQ_NB   
        				,1 as DRG_SUB_GRP_SEQ_NB 
                ,B.CLAIM_BEGIN_DT     
                ,B.CLAIM_END_DT       
        				,0 AS ALL_DRUG_IN
                ,A.CTS_DRUG_IN
        				,1 AS INCLUDE_IN
         FROM   &CLAIMSA..TDRUG1              A 
               ,&HERCULES..TPHASE_DRG_GRP_DT  B 
         WHERE  A.DRUG_NDC_ID IS NOT NULL
           AND  A.NHU_TYPE_CD IS NOT NULL
    		   AND  B.INITIATIVE_ID = &init_id
           AND(   (TIMESTAMPDIFF(256,CHAR(TIMESTAMP_ISO(B.CLAIM_BEGIN_DT) - TIMESTAMP_ISO(A.DISCONTINUANCE_DT))) < 3)
             OR (A.DISCONTINUANCE_DT IS NULL))

         ORDER BY A.DRUG_NDC_ID, A.NHU_TYPE_CD
         )
         by DB2;

         execute
         (
         COMMIT
         )
         by DB2;	
      disconnect from DB2;
      quit;

  *SASDOC-----------------------------------------------------------------------
   | Logic to exclude drugs from all drugs output table. 
   +----------------------------------------------------------------------SASDOC*;
         PROC SQL NOPRINT;
         CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
         EXECUTE(DELETE FROM &DB2_TMP_TBL2 A
                 WHERE EXISTS
                (SELECT 1
                 FROM &DB2_TMP_TBL Z
                 WHERE Z.DRUG_NDC_ID = A.DRUG_NDC_ID                 
				 and   Z.NHU_TYPE_CD = A.NHU_TYPE_CD
                )) BY DB2;
         %reset_sql_err_cd;

         disconnect from DB2;
         quit;

	  /* rename output table */
	  %drop_db2_table(tbl_name=&DB2_TMP_TBL);
	  %let RTBL=%scan(%str(&DB2_TMP_TBL),2,%str(.));

      PROC SQL NOPRINT;
      CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
      EXECUTE(RENAME TABLE &DB2_TMP_TBL2 TO &RTBL ) BY DB2;
      DISCONNECT FROM DB2;
      QUIT;

    %end;

      PROC SQL NOPRINT;
      CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
      
      select COUNT_DB2_TMP_TBL
      into   :COUNT_DB2_TMP_TBL
      from   connection to DB2
      (
      SELECT COUNT(*) as COUNT_DB2_TMP_TBL
      FROM   &DB2_TMP_TBL
      );

      select COUNT_DRUG_NDC_ID_DB2_TMP_TBL
      into   :COUNT_DRUG_NDC_ID_DB2_TMP_TBL
      from   connection to DB2
      (
      SELECT COUNT(DRUG_NDC_ID) as COUNT_DRUG_NDC_ID_DB2_TMP_TBL
      FROM   &DB2_TMP_TBL
      );

      disconnect from DB2;
      quit;

   %end;   %*if (&EXT_DRUG_LIST_IN eq 0);

%*SASDOC-----------------------------------------------------------------------
| Just a check here. If this macro var is in the SAS dictonary tables. It only
| get created in the above code and to use the %mvarexist the name neeeded to 
| be smaller. N. Williams this allows for a soft abort from the code.
+----------------------------------------------------------------------SASDOC*;
   PROC SQL NOPRINT;
    SELECT COUNT(*)
	INTO   :MVARCNTS
    FROM DICTIONARY.MACROS
    WHERE name = "_GETNDC_DB2_TMP_TBL_SYSDBRC"
    ;
   QUIT ;
   %PUT MVARCNTS=&MVARCNTS;

   %if (&MVARCNTS le 0) %then  %let _GETNDC_DB2_TMP_TBL_SYSDBRC = 100;


   %if (&_GETNDC_DB2_TMP_TBL_SYSDBRC eq 0) %then
   %do;
      %put NOTE: %cmpres(&COUNT_DB2_TMP_TBL) rows inserted into &DB2_TMP_TBL;
      %put NOTE: %cmpres(&COUNT_DRUG_NDC_ID_DB2_TMP_TBL) NDC rows inserted into &DB2_TMP_TBL;
      %grant(tbl_name=&DB2_TMP_TBL);
   

      %if (%cmpres(&DRUG_NDC_TBL) ne) and (&COUNT_DRUG_NDC_ID_DB2_TMP_TBL ne 0) %then
      %do;
         proc sql noprint;
         connect to DB2 as DB2(dsn=&UDBSPRP AUTOCOMMIT=NO);
         execute
         (
         CREATE TABLE &DRUG_NDC_TBL
                ( DRUG_NDC_ID        DECIMAL(11) NOT NULL
                 ,NHU_TYPE_CD        SMALLINT NOT NULL
                 ,DRG_GROUP_SEQ_NB   SMALLINT NOT NULL
                 ,DRG_SUB_GRP_SEQ_NB SMALLINT NOT NULL
        					,DRUG_ABBR_DSG_NM    CHAR(3)
        					,DRUG_ABBR_PROD_NM   CHAR(12)
        					,DRUG_ABBR_STRG_NM   CHAR(8)
        					,DRUG_BRAND_CD       CHAR(1)
                 ,PRIMARY KEY(DRUG_NDC_ID,NHU_TYPE_CD,DRG_GROUP_SEQ_NB,DRG_SUB_GRP_SEQ_NB))
         NOT LOGGED INITIALLY
         )
         by DB2;
         execute
         (
         ALTER TABLE &DRUG_NDC_TBL ACTIVATE NOT LOGGED INITIALLY
         )
         by DB2;
         execute
         (
         INSERT INTO &DRUG_NDC_TBL
            ( DRUG_NDC_ID
             ,NHU_TYPE_CD
             ,DRG_GROUP_SEQ_NB
             ,DRG_SUB_GRP_SEQ_NB
    					,DRUG_ABBR_DSG_NM 
    					,DRUG_ABBR_PROD_NM
    					,DRUG_ABBR_STRG_NM
    					,DRUG_BRAND_CD)
         SELECT  DISTINCT
                 DRUG_NDC_ID
                ,NHU_TYPE_CD
                ,DRG_GROUP_SEQ_NB
                ,DRG_SUB_GRP_SEQ_NB
      					,DRUG_ABBR_DSG_NM 
      					,DRUG_ABBR_PROD_NM
      					,DRUG_ABBR_STRG_NM
      					,DRUG_BRAND_CD
         FROM   &DB2_TMP_TBL
         WHERE  ALL_DRUG_IN <> 1
           AND  DRUG_NDC_ID IS NOT NULL
           AND  NHU_TYPE_CD IS NOT NULL
         ORDER BY DRUG_NDC_ID, NHU_TYPE_CD, DRG_GROUP_SEQ_NB, DRG_SUB_GRP_SEQ_NB
         )
         by DB2;

         %let _GETNDC_DRUG_NDC_TBL_SYSDBRC=&SYSDBRC;

         execute
         (
         COMMIT
         )
         by DB2;

         select COUNT_DRUG_NDC_TBL
         into   :COUNT_DRUG_NDC_TBL
         from   connection to DB2
         (
         SELECT COUNT(*) AS COUNT_DRUG_NDC_TBL
         FROM   &DRUG_NDC_TBL
         );

         disconnect from DB2;
         quit;

         %if (&_GETNDC_DRUG_NDC_TBL_SYSDBRC eq 0) %then
         %do;
            %put NOTE: %cmpres(&COUNT_DRUG_NDC_TBL) rows inserted into &DRUG_NDC_TBL;
            %grant(tbl_name=&DRUG_NDC_TBL);
            %runstats(tbl_name=&DRUG_NDC_TBL);
         %end;
         %else
         %do;
            %if (&_GETNDC_DRUG_NDC_TBL_SYSDBRC eq 100 ) %then
            %do;
               %put NOTE: empty &DRUG_NDC_TBL table;
               %drop_db2_table(tbl_name=&DRUG_NDC_TBL);
            %end;
            %else
            %do;
               %let err_fl=1;
               %drop_db2_table(tbl_name=&DRUG_NDC_TBL);
            %end;
         %end;   %*if (&_GETNDC_DRUG_NDC_TBL_SYSDBRC eq 0);
      %end;   %*%if (%cmpres(&DRUG_NDC_TBL) ne) and (&COUNT_DRUG_NDC_ID_DB2_TMP_TBL ne 0);

%*SASDOC-----------------------------------------------------------------------
| Generate CLAIM_DATE_TBL.
+----------------------------------------------------------------------SASDOC*;

%IF &QL_ADJ=1 OR &RX_ADJ=1 OR &RE_ADJ=1 %THEN %DO;

      %if (%cmpres(&CLAIM_DATE_TBL) ne) and (&COUNT_DB2_TMP_TBL ne 0) %then
      %do;
	   proc sql noprint;
         connect to DB2 as DB2(dsn=&UDBSPRP AUTOCOMMIT=NO);
		 CREATE TABLE &CLAIM_DATE_TBL AS
         SELECT * FROM CONNECTION TO DB2
         (
         SELECT  DISTINCT
                 DRG_GROUP_SEQ_NB
                ,DRG_SUB_GRP_SEQ_NB
                ,CLAIM_BEGIN_DT
                ,CLAIM_END_DT
                ,ALL_DRUG_IN
         FROM   &DB2_TMP_TBL
         ORDER BY DRG_GROUP_SEQ_NB, DRG_SUB_GRP_SEQ_NB
        );
         disconnect from DB2;
         quit;
    %IF &RX_ADJ=1 OR &RE_ADJ=1 %THEN %DO;
		  %drop_oracle_table(tbl_name=&ORA_TMP..&TABLE_PREFIX._RVW_DATES);
  		PROC SQL NOPRINT;
  		CREATE TABLE &ORA_TMP..&TABLE_PREFIX._RVW_DATES AS 
  		SELECT * FROM &CLAIM_DATE_TBL;
  		QUIT;
    %END;

		 proc sql noprint;
         connect to DB2 as DB2(dsn=&UDBSPRP AUTOCOMMIT=NO);
		 select count(*)
         into   :COUNT_CLAIM_DATE_TBL
         from   connection to DB2
         (
         SELECT COUNT(*)
         FROM   &CLAIM_DATE_TBL
         );
         disconnect from DB2;
         quit;
		%let _GETNDC_CLAIM_DATE_TBL_SYSDBRC=&SYSDBRC.;

         %if (&_GETNDC_CLAIM_DATE_TBL_SYSDBRC eq 0) %then
         %do;
            %put NOTE: %cmpres(&COUNT_CLAIM_DATE_TBL) rows inserted into &CLAIM_DATE_TBL;
            %grant(tbl_name=&CLAIM_DATE_TBL);
            %runstats(tbl_name=&CLAIM_DATE_TBL);
         %end;
         %else
         %do;
            %if (&_GETNDC_CLAIM_DATE_TBL_SYSDBRC eq 100) %then
            %do;
               %put NOTE: empty &CLAIM_DATE_TBL table;
               %drop_db2_table(tbl_name=&CLAIM_DATE_TBL);
            %end;
            %else
            %do;
               %let err_fl=1;
               %drop_db2_table(tbl_name=&CLAIM_DATE_TBL);
            %end;   %*if (&_GETNDC_CLAIM_DATE_TBL_SYSDBRC eq 100);
         %end;   %*if (&_GETNDC_CLAIM_DATE_TBL_SYSDBRC eq 0);
      %end;    %*if (%cmpres(&CLAIM_DATE_TBL) ne);
   %end;   %*if (&_GETNDC_DB2_TMP_TBL_SYSDBRC eq 0);
   %end;
   %else
   %do;
      %if (&_GETNDC_DB2_TMP_TBL_SYSDBRC eq 100) %then
      %do;
        %put NOTE: empty &DB2_TMP_TBL table;
      %end;
      %else
      %do;
         %let err_fl=1;
      %end;   %*if (&_GETNDC_DB2_TMP_TBL_SYSDBRC eq 100);
   %end;   %*if (&_GETNDC_DB2_TMP_TBL_SYSDBRC eq 0);
   %drop_db2_table(tbl_name=&DB2_TMP_TBL);
   %set_error_fl;

%IF (&RX_ADJ=1 OR &RE_ADJ=1 )and %SYSFUNC(EXIST(&DRUG_NDC_TBL.)) %THEN %DO;

	%if (%cmpres(&DRUG_NDC_TBL_EDW.) ne) %then
	%drop_oracle_table(tbl_name=&DRUG_NDC_TBL_EDW.);
   	%PUT NOTE: DROPPING TABLE &DRUG_NDC_TBL_EDW. BECAUSE IT EXISTS;
   	
	PROC SQL NOPRINT;
 	CREATE TABLE &DRUG_NDC_TBL_EDW. AS
 		SELECT DISTINCT A.DRUG_NDC_ID         
                 ,B.DRUG_GID
                 ,A.DRG_GROUP_SEQ_NB   
                 ,A.DRG_SUB_GRP_SEQ_NB
        				 ,A.NHU_TYPE_CD 
        				 ,DRUG_ABBR_DSG_NM
        				 ,DRUG_ABBR_PROD_NM
        				 ,DRUG_ABBR_STRG_NM
        				 ,DRUG_BRAND_CD
 		FROM &DRUG_NDC_TBL. A
 		LEFT JOIN
			(SELECT DRUG_GID, NDC_CODE AS DRUG_NDC_ID, DRUG_VLD_FLG
	  		FROM &DSS_CLIN..V_DRUG_DENORM) B
				ON A.DRUG_NDC_ID = input(B.DRUG_NDC_ID,20.)
				AND B.DRUG_VLD_FLG = 'Y'
				ORDER BY A.DRUG_NDC_ID, B.DRUG_GID;
	QUIT;

			%LET pos1=%INDEX(&DRUG_NDC_TBL_EDW,.);
			%LET pos2=%INDEX(&DRUG_NDC_TBL_RX,.);
 			%LET pos3=%INDEX(&DRUG_NDC_TBL_RE,.);
			%LET EDW_table = %SUBSTR(&DRUG_NDC_TBL_EDW.,%EVAL(&pos1+1));
			%LET RX_table = %SUBSTR(&DRUG_NDC_TBL_RX.,%EVAL(&pos2+1));
			%LET RE_table = %SUBSTR(&DRUG_NDC_TBL_RE.,%EVAL(&pos3+1));

%*SASDOC-----------------------------------------------------------------------
| Generate DRUG_NDC_TBL_RX if RX engine is ON
+----------------------------------------------------------------------SASDOC*;
		%if &RX_ADJ=1 %then %do;

			%if (%cmpres(&DRUG_NDC_TBL_RX.) ne) %then
			%drop_oracle_table(tbl_name=&DRUG_NDC_TBL_RX.);
			%PUT NOTE: DROPPING TABLE &DRUG_NDC_TBL_RX. BECAUSE IT EXISTS;

			proc sql noprint;
			connect to oracle(PATH=&GOLD);
			execute
			(
			rename &EDW_table. to &RX_table.
			)
			by oracle;
			disconnect from oracle;
			quit;
			
			%if NOT %SYSFUNC(EXIST(&DRUG_NDC_TBL_EDW.)) AND %SYSFUNC(EXIST(&DRUG_NDC_TBL_RX.)) AND &RE_ADJ=1 %THEN %do;

				%if (%cmpres(&DRUG_NDC_TBL_RE.) ne) %then
				%drop_oracle_table(tbl_name=&DRUG_NDC_TBL_RE.);
				%PUT NOTE: DROPPING TABLE &DRUG_NDC_TBL_RE. BECAUSE IT EXISTS;

				proc sql noprint; 
				connect to oracle(PATH=&GOLD);
				execute
				(
         		create table &DRUG_NDC_TBL_RE as 
     			select * from &DRUG_NDC_TBL_RX
				)
				by oracle; 
				disconnect from oracle;
				quit; 
 
			%end;

		%end;

%*SASDOC-----------------------------------------------------------------------
| Generate DRUG_NDC_TBL_RE if RE is ON
+----------------------------------------------------------------------SASDOC*;

		%else %do;

			%if (%cmpres(&DRUG_NDC_TBL_RE.) ne) %then
			%drop_oracle_table(tbl_name=&DRUG_NDC_TBL_RE.);
			%PUT NOTE: DROPPING TABLE &DRUG_NDC_TBL_RE. BECAUSE IT EXISTS;

			proc sql;
			connect to oracle(PATH=&GOLD);
			execute
			(
			rename &EDW_table. to &RE_table.
			)
			by oracle;
			disconnect from oracle;
			quit;

		%end;

%END;

%*SASDOC-----------------------------------------------------------------------
| Generate DRUG_NDC_TBL_QL.
+----------------------------------------------------------------------SASDOC*;

		%IF &QL_ADJ=1 and %SYSFUNC(EXIST(&DRUG_NDC_TBL.)) %THEN %DO;

			%if (%cmpres(&DRUG_NDC_TBL_QL.) ne) %then 
			%drop_db2_table(tbl_name=&DRUG_NDC_TBL_QL.);
   			%PUT NOTE: DROPPING TABLE &DRUG_NDC_TBL_QL. BECAUSE IT EXISTS;

			proc sql noprint;
			connect to db2 as db2(dsn=&udbsprp.);
			execute
			(
				CREATE TABLE &DRUG_NDC_TBL_QL. AS
				(SELECT * FROM &DRUG_NDC_TBL.)
				DEFINITION ONLY NOT LOGGED INITIALLY
			)
			BY DB2;
			execute
			(	ALTER TABLE &DRUG_NDC_TBL_QL. ACTIVATE NOT LOGGED INITIALLY 
			) 
			BY DB2;
			execute
			(
				insert into &DRUG_NDC_TBL_QL. 
				SELECT * FROM &DRUG_NDC_TBL.
            )
			BY DB2;
			disconnect from db2;
			QUIT; 

		%END;

		%drop_db2_table(tbl_name=&DRUG_NDC_TBL.);

%end;   %*if (DRG_DEFINITION_CD eq 1);

%else
%*SASDOC-----------------------------------------------------------------------
| If Drug Definition Code eq 2 (Program)
| 04DEC2008 - RS - add program id 106 and task 34 to condition
+----------------------------------------------------------------------SASDOC*;
%if (&DRG_DEFINITION_CD eq 2) %then %do;

%if (&program_id eq 72 and &RE_ADJ = 1 and &QL_ADJ = 0 and &RX_ADJ = 0) %then %GOTO RE_72;

/*-----------------------------------------------------------------------
|01JUN2009 G.O.D. - Removed following code to include Thyroid products and 
|hormone treatments ***
+----------------------------------------------------------------------*/
%else;

%macro to_be_removed_01jun2009;
%let GPI_NDC_HIS = &DB2_TMP..&table_prefix._GPI_NDC_HIS;
%put NOTE: GPI_NDC_HIS = &GPI_NDC_HIS; 

   		%if (%cmpres(&GPI_NDC_HIS) ne) %then
		%drop_db2_table(tbl_name=&GPI_NDC_HIS);
		%PUT NOTE: DROPPING TABLE &GPI_NDC_HIS BECAUSE IT EXISTS;

   proc sql noprint;
   connect to DB2 as DB2(dsn=&UDBSPRP AUTOCOMMIT=NO);
   execute
   (
   CREATE TABLE &GPI_NDC_HIS
          ( DRUG_NDC_ID         DECIMAL(11) NOT NULL
		   ,NHU_TYPE_CD         SMALLINT NOT NULL
		   ,GPI_GROUP			CHAR(2)
		   ,GPI_CLASS			CHAR(2)
		   ,PRIMARY KEY(DRUG_NDC_ID,NHU_TYPE_CD))
                 
   NOT LOGGED INITIALLY
   )
   by DB2;
   execute
   (
   ALTER TABLE &GPI_NDC_HIS ACTIVATE NOT LOGGED INITIALLY
   )
   by DB2;
   execute
   (
      INSERT INTO &GPI_NDC_HIS
           (DRUG_NDC_ID         
		   ,NHU_TYPE_CD         
		   ,GPI_GROUP			
		   ,GPI_CLASS)
	  SELECT DISTINCT B.DRUG_NDC_ID
                     ,B.NHU_TYPE_CD
                     ,B.GPI_GROUP
                     ,B.GPI_CLASS
            FROM 
				(
				 SELECT DISTINCT GPI_CD
	   				  			,NULLIF(SUBSTR(GPI_CD,01,2),'  ') AS GPI_GROUP
                    ,NULLIF(SUBSTR(GPI_CD,03,2),'  ') AS GPI_CLASS
                    ,NULLIF(SUBSTR(GPI_CD,05,2),'  ') AS GPI_SUBCLASS
                    ,NULLIF(SUBSTR(GPI_CD,07,2),'  ') AS GPI_NAME
                    ,NULLIF(SUBSTR(GPI_CD,09,2),'  ') AS GPI_NAME_EXTENSION
                    ,NULLIF(SUBSTR(GPI_CD,11,2),'  ') AS GPI_FORM
                    ,NULLIF(SUBSTR(GPI_CD,13,2),'  ') AS GPI_STRENGTH
            				,DRUG_CATEGORY_ID
	   				  			 
	   			 FROM &HERCULES..TPROGRAM_GPI_HIS

				 WHERE 	 PROGRAM_ID     = &PROGRAM_ID
        				AND  EFFECTIVE_DT  <= (CURRENT DATE)
        				AND  EXPIRATION_DT  > (CURRENT DATE)
						AND  INCLUDE_IN = 0
				) AS A,
				&CLAIMSA..TDRUG1 AS B

			WHERE  
			(
				(	  	(A.DRUG_CATEGORY_ID       = 1)
			  		AND (    A.GPI_GROUP          = B.GPI_GROUP)
              		AND (    A.GPI_CLASS          IS NULL
                    	OR A.GPI_CLASS          = B.GPI_CLASS)
              		AND (    A.GPI_SUBCLASS       IS NULL
                    	OR A.GPI_SUBCLASS       = B.GPI_SUBCLASS)
              		AND (    A.GPI_NAME           IS NULL
                    	OR A.GPI_NAME           = B.GPI_NAME)
              		AND (    A.GPI_NAME_EXTENSION IS NULL
                    	OR A.GPI_NAME_EXTENSION = B.GPI_NAME_EXTENSION)
              		AND (    A.GPI_FORM           IS NULL
                    	OR A.GPI_FORM           = B.GPI_FORM)
              		AND (    A.GPI_STRENGTH       IS NULL
                    	OR A.GPI_STRENGTH       = B.GPI_STRENGTH)
				)

			  OR(       (A.DRUG_CATEGORY_ID     = 2)
             		AND (	DECIMAL(A.GPI_CD) = B.DRUG_PRODUCT_ID)
			 	)

			  OR(       (A.DRUG_CATEGORY_ID     = 3)
                     AND(   DECIMAL(A.GPI_CD) = B.DRUG_NDC_ID)
                 )

			  OR(       (A.DRUG_CATEGORY_ID     = 4)
             		AND (	DECIMAL(A.GPI_CD) = B.DGH_GCN_CD)
			 	)
            )
            AND (    (TIMESTAMPDIFF(256,CHAR(CURRENT TIMESTAMP - TIMESTAMP_ISO(B.DISCONTINUANCE_DT))) < 3)
                    OR (B.DISCONTINUANCE_DT IS NULL))
		
			GROUP BY DRUG_NDC_ID, NHU_TYPE_CD, B.GPI_GROUP, B.GPI_CLASS
            ORDER BY DRUG_NDC_ID, NHU_TYPE_CD
   )
   by DB2;
   execute
   (
   COMMIT
   )
   by DB2;
   disconnect from DB2;
   quit;
%mend to_be_removed_01jun2009;


%if &program_id ne 72 %then %do;

%let NDC_TMP_TBL = &DB2_TMP..&TABLE_PREFIX._NDC_TBL_&program_id._&task_id.;
%put NDC_TMP_TBL = &NDC_TMP_TBL.;

   		%if (%cmpres(&NDC_TMP_TBL.) ne) %then
		%drop_db2_table(tbl_name=&NDC_TMP_TBL.);
		%PUT NOTE: DROPPING TABLE &NDC_TMP_TBL. BECAUSE IT EXISTS;

   proc sql noprint;
   connect to DB2 as DB2(dsn=&UDBSPRP AUTOCOMMIT=NO);
   execute
   (
   CREATE TABLE &NDC_TMP_TBL.
          ( DRUG_NDC_ID      DECIMAL(11) NOT NULL
           ,NHU_TYPE_CD      SMALLINT NOT NULL
           ,DRUG_CATEGORY_ID INTEGER
           ,GPI_GROUP        CHAR(2)
           ,GPI_CLASS        CHAR(2)
           ,PRIMARY KEY(DRUG_NDC_ID,NHU_TYPE_CD))
   NOT LOGGED INITIALLY
   )
   by DB2;
   execute
   (
   ALTER TABLE &NDC_TMP_TBL. ACTIVATE NOT LOGGED INITIALLY
   )
   by DB2;
   execute
      (
      INSERT INTO &NDC_TMP_TBL.
         ( DRUG_NDC_ID
          ,NHU_TYPE_CD
          ,GPI_GROUP
          ,GPI_CLASS
          ,DRUG_CATEGORY_ID)
      SELECT  DISTINCT
                    DRUG_NDC_ID
                   ,NHU_TYPE_CD
                   ,GPI_GROUP
                   ,GPI_CLASS
        				   ,59 AS DRUG_CATEGORY_ID
            FROM    &CLAIMSA..TDRUG1
            WHERE   (    TIMESTAMPDIFF(256,CHAR(CURRENT TIMESTAMP - TIMESTAMP_ISO(DISCONTINUANCE_DT))) < 3
                      OR DISCONTINUANCE_DT IS NULL)
              AND   (DRUG_MAINT_IN = 1
            			   OR	DGH_EXT_MNT_IN = 1)
              AND CTS_DRUG_IN = 0
            GROUP BY DRUG_NDC_ID, NHU_TYPE_CD, GPI_GROUP, GPI_CLASS
            ORDER BY DRUG_NDC_ID, NHU_TYPE_CD
      )
   by DB2;

   execute
   (
   COMMIT
   )
   by DB2;

   disconnect from DB2;
   quit;

/* 04DEC2008 RS - add program 106 and task 34 to list */
%if ((&program_id eq 73) or (&program_id eq 123))
OR ((&program_id eq 106) and (&task_id eq 28))
OR ((&program_id eq 106) and (&task_id eq 34)) %then %do;

   		%if (%cmpres(&DRUG_NDC_TBL) ne) %then
		%drop_db2_table(tbl_name=&DRUG_NDC_TBL);
		%PUT NOTE: DROPPING TABLE &DRUG_NDC_TBL BECAUSE IT EXISTS;

   PROC SQL NOPRINT;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   		EXECUTE(CREATE TABLE &DRUG_NDC_TBL. AS
   			(SELECT * FROM &NDC_TMP_TBL.)
			DEFINITION ONLY NOT LOGGED INITIALLY
		   	)
		   	BY DB2;
		   	execute
			(	ALTER TABLE &DRUG_NDC_TBL. ACTIVATE NOT LOGGED INITIALLY 
			) 
			BY DB2;
			execute
			(
				insert into &DRUG_NDC_TBL. 
				SELECT * FROM &NDC_TMP_TBL. A
/*-----------------------------------------------------------------------
|01JUN2009 G.O.D. - Removed following code to include Thyroid products and 
|hormone treatments ***
+----------------------------------------------------------------------*/
/*		           WHERE NOT EXISTS*/
/*                (SELECT 1*/
/*                 FROM &GPI_NDC_HIS B*/
/*                 WHERE A.DRUG_NDC_ID = B.DRUG_NDC_ID                 */
/*				 and   A.NHU_TYPE_CD = B.NHU_TYPE_CD*/
/*                 )*/
			) BY DB2;

   	%let _GETNDC_DRUG_NDC_TBL_SYSDBRC=&SYSDBRC;
    %let _GETNDC_DRUG_NDC_TBL_SYSDBMSG=&SYSDBMSG;

   execute
   (
   COMMIT
   )
   by DB2;
   disconnect from DB2;
   quit;

%end;

   proc sql noprint;
      SELECT COUNT(*) AS COUNT_DRUG_NDC_TBL into :COUNT_DRUG_NDC_TBL
      FROM   &DRUG_NDC_TBL;
   	quit;

   %if (  (&_GETNDC_DRUG_NDC_TBL_SYSDBRC eq 0)
        or(%index(&_GETNDC_DRUG_NDC_TBL_SYSDBMSG,%str(SQLSTATE 01003)) ne 0)  )
   %then
   %do;
      %put NOTE: %cmpres(&COUNT_DRUG_NDC_TBL) rows inserted into &DRUG_NDC_TBL;
      %grant(tbl_name=&DRUG_NDC_TBL);
      %runstats(tbl_name=&DRUG_NDC_TBL);
   %end;
   %else
   %do;
      %if (&_GETNDC_DRUG_NDC_TBL_SYSDBRC eq 100) %then
      %do;
        %put NOTE: empty &DRUG_NDC_TBL table;
        %drop_db2_table(tbl_name=&DRUG_NDC_TBL);
      %end;
      %else
      %do;
         %put ERROR: SYSDBRC =&_GETNDC_DRUG_NDC_TBL_SYSDBRC;
         %put ERROR: SYSDBMSG=&_GETNDC_DRUG_NDC_TBL_SYSDBMSG;
         %let err_fl=1;
      %end;
   %end;

   %IF (&RX_ADJ=1 OR &RE_ADJ=1 )and %SYSFUNC(EXIST(&DRUG_NDC_TBL.)) %THEN %DO;

	%if (%cmpres(&DRUG_NDC_TBL_EDW.) ne) %then
	%drop_oracle_table(tbl_name=&DRUG_NDC_TBL_EDW.);
   	%PUT NOTE: DROPPING TABLE &DRUG_NDC_TBL_EDW. BECAUSE IT EXISTS;
   	
	PROC SQL NOPRINT;
 	CREATE TABLE &DRUG_NDC_TBL_EDW. AS
 		SELECT DISTINCT A.DRUG_NDC_ID
					   ,B.DRUG_GID
					   ,A.DRUG_CATEGORY_ID
             ,A.GPI_GROUP   
             ,A.GPI_CLASS
					   ,' ' AS NHU_TYPE_CD
 		FROM &DRUG_NDC_TBL. A
 		LEFT JOIN
			(SELECT DRUG_GID, NDC_CODE AS DRUG_NDC_ID, DRUG_VLD_FLG
	  		FROM &DSS_CLIN..V_DRUG_DENORM) B
				ON A.DRUG_NDC_ID = input(B.DRUG_NDC_ID,20.)
				AND B.DRUG_VLD_FLG = 'Y'
				ORDER BY A.DRUG_NDC_ID, B.DRUG_GID;
	QUIT;

			%LET pos1=%INDEX(&DRUG_NDC_TBL_EDW,.);
			%LET pos2=%INDEX(&DRUG_NDC_TBL_RX,.);
 			%LET pos3=%INDEX(&DRUG_NDC_TBL_RE,.);
			%LET EDW_table = %SUBSTR(&DRUG_NDC_TBL_EDW.,%EVAL(&pos1+1));
			%LET RX_table = %SUBSTR(&DRUG_NDC_TBL_RX.,%EVAL(&pos2+1));
			%LET RE_table = %SUBSTR(&DRUG_NDC_TBL_RE.,%EVAL(&pos3+1));

%*SASDOC-----------------------------------------------------------------------
| Generate DRUG_NDC_TBL_RX if RX engine is ON
+----------------------------------------------------------------------SASDOC*;
		%if &RX_ADJ=1 %then %do;

			%if (%cmpres(&DRUG_NDC_TBL_RX.) ne) %then
			%drop_oracle_table(tbl_name=&DRUG_NDC_TBL_RX.);
			%PUT NOTE: DROPPING TABLE &DRUG_NDC_TBL_RX. BECAUSE IT EXISTS;

			proc sql noprint;
			connect to oracle(PATH=&GOLD);
			execute
			(
			rename &EDW_table. to &RX_table.
			)
			by oracle;
			disconnect from oracle;
			quit;
			
			%if NOT %SYSFUNC(EXIST(&DRUG_NDC_TBL_EDW.)) AND %SYSFUNC(EXIST(&DRUG_NDC_TBL_RX.)) AND &RE_ADJ=1 %THEN %do;

				%if (%cmpres(&DRUG_NDC_TBL_RE.) ne) %then
				%drop_oracle_table(tbl_name=&DRUG_NDC_TBL_RE.);
				%PUT NOTE: DROPPING TABLE &DRUG_NDC_TBL_RE. BECAUSE IT EXISTS;

				proc sql noprint; 
				connect to oracle(PATH=&GOLD);
				execute
				(
         		create table &DRUG_NDC_TBL_RE as 
     			select * from &DRUG_NDC_TBL_RX
				)
				by oracle; 
				disconnect from oracle;
				quit; 
 
			%end;

		%end;

%*SASDOC-----------------------------------------------------------------------
| Generate DRUG_NDC_TBL_RE if RE is ON
+----------------------------------------------------------------------SASDOC*;

		%else %do;

			%if (%cmpres(&DRUG_NDC_TBL_RE.) ne) %then
			%drop_oracle_table(tbl_name=&DRUG_NDC_TBL_RE.);
			%PUT NOTE: DROPPING TABLE &DRUG_NDC_TBL_RE. BECAUSE IT EXISTS;

			proc sql;
			connect to oracle(PATH=&GOLD);
			execute
			(
			rename &EDW_table. to &RE_table.
			)
			by oracle;
			disconnect from oracle;
			quit;

		%end;

%END;

%*SASDOC-----------------------------------------------------------------------
| Generate DRUG_NDC_TBL_QL and DRUG_NDC_TBL_RX
+----------------------------------------------------------------------SASDOC*;

		%IF &QL_ADJ=1 and %SYSFUNC(EXIST(&DRUG_NDC_TBL.)) %THEN %DO;

			%if (%cmpres(&DRUG_NDC_TBL_QL.) ne) %then 
			%drop_db2_table(tbl_name=&DRUG_NDC_TBL_QL.);
   			%PUT NOTE: DROPPING TABLE &DRUG_NDC_TBL_QL. BECAUSE IT EXISTS;

			proc sql noprint;
			connect to db2 as db2(dsn=&udbsprp.);
			execute
			(
				CREATE TABLE &DRUG_NDC_TBL_QL. AS
				(SELECT * FROM &DRUG_NDC_TBL.)
				DEFINITION ONLY NOT LOGGED INITIALLY
			)
			BY DB2;
			execute
			(	ALTER TABLE &DRUG_NDC_TBL_QL. ACTIVATE NOT LOGGED INITIALLY 
			) 
			BY DB2;
			execute
			(
				insert into &DRUG_NDC_TBL_QL. 
				SELECT * FROM &DRUG_NDC_TBL.
            )
			BY DB2;
			disconnect from db2;
			QUIT; 

		%END;

		%drop_db2_table(tbl_name=&DRUG_NDC_TBL.);
/*		%drop_db2_table(tbl_name=&GPI_NDC_HIS.);*/

%end;

   %else %if &program_id=72 %then %do;/* if program_id = 72*/

   %if &QL_ADJ=1 OR &RX_ADJ=1 %then %do;

  %let NDC_TMP_TBL_QLRX72 = &DB2_TMP..&TABLE_PREFIX._NDC_TBL_QLRX72;
  %put NDC_TMP_TBL_QLRX72 = &NDC_TMP_TBL_QLRX72.;

   		%if (%cmpres(&NDC_TMP_TBL_QLRX72.) ne) %then
		%drop_db2_table(tbl_name=&NDC_TMP_TBL_QLRX72.);
		%PUT NOTE: DROPPING TABLE &NDC_TMP_TBL_QLRX72. BECAUSE IT EXISTS;

   proc sql noprint;
   connect to DB2 as DB2(dsn=&UDBSPRP AUTOCOMMIT=NO);
   execute
   (
   CREATE TABLE &NDC_TMP_TBL_QLRX72.
          ( DRUG_NDC_ID      DECIMAL(11) NOT NULL
           ,NHU_TYPE_CD      SMALLINT NOT NULL
           ,DRUG_CATEGORY_ID INTEGER
           ,GPI_GROUP           CHAR(2)
           ,GPI_CLASS           CHAR(2)
           ,GPI_SUBCLASS        CHAR(2)
           ,GPI_NAME            CHAR(2)
           ,GPI_NAME_EXTENSION  CHAR(2)
           ,GPI_FORM            CHAR(2)
           ,GPI_STRENGTH        CHAR(2)
           ,PRIMARY KEY(DRUG_NDC_ID,NHU_TYPE_CD))
   NOT LOGGED INITIALLY
   )
   by DB2;
   execute
   (
   ALTER TABLE &NDC_TMP_TBL_QLRX72. ACTIVATE NOT LOGGED INITIALLY
   )
   by DB2;
   execute
      (
      INSERT INTO &NDC_TMP_TBL_QLRX72.
         ( DRUG_NDC_ID
          ,NHU_TYPE_CD
          ,GPI_GROUP
          ,GPI_CLASS
          ,GPI_SUBCLASS
          ,GPI_NAME    
          ,GPI_NAME_EXTENSION
          ,GPI_FORM          
          ,GPI_STRENGTH      
          ,DRUG_CATEGORY_ID)
      SELECT  DISTINCT
                    DRUG_NDC_ID
                   ,NHU_TYPE_CD
                   ,GPI_GROUP
                   ,GPI_CLASS
                   ,GPI_SUBCLASS
                   ,GPI_NAME    
                   ,GPI_NAME_EXTENSION
                   ,GPI_FORM          
                   ,GPI_STRENGTH      
                   ,59 AS DRUG_CATEGORY_ID
            FROM    &CLAIMSA..TDRUG1
            WHERE   (    TIMESTAMPDIFF(256,CHAR(CURRENT TIMESTAMP - TIMESTAMP_ISO(DISCONTINUANCE_DT))) < 3
                      OR DISCONTINUANCE_DT IS NULL)
              AND   (DRUG_MAINT_IN = 1
			   OR	DGH_EXT_MNT_IN = 1)
        AND CTS_DRUG_IN = 0
			  AND   DEA_CLASS_CD NOT IN (1,2,3,4,5)
      GROUP BY DRUG_NDC_ID, NHU_TYPE_CD, GPI_GROUP, GPI_CLASS ,GPI_SUBCLASS ,GPI_NAME    
                   ,GPI_NAME_EXTENSION ,GPI_FORM ,GPI_STRENGTH      
      ORDER BY DRUG_NDC_ID, NHU_TYPE_CD
      )
   by DB2;

   execute
   (
   COMMIT
   )
   by DB2;

   disconnect from DB2;
   quit;


   %if (%cmpres(&DRUG_NDC_TBL.) ne) %then
   %drop_db2_table(tbl_name=&DRUG_NDC_TBL.);
   %PUT NOTE: DROPPING TABLE &DRUG_NDC_TBL. BECAUSE IT EXISTS;

   PROC SQL NOPRINT;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   		EXECUTE(CREATE TABLE &DRUG_NDC_TBL. AS
   			(SELECT * FROM &NDC_TMP_TBL_QLRX72.)
			DEFINITION ONLY NOT LOGGED INITIALLY
		   	)
		   	BY DB2;
		   	execute
			(	ALTER TABLE &DRUG_NDC_TBL. ACTIVATE NOT LOGGED INITIALLY 
			) 
			BY DB2;
			execute
			(
				insert into &DRUG_NDC_TBL. 
				SELECT * FROM &NDC_TMP_TBL_QLRX72. A
/*-----------------------------------------------------------------------
|01JUN2009 G.O.D. - Removed following code to include Thyroid products and 
|hormone treatments ***
+----------------------------------------------------------------------*/
/*		           WHERE NOT EXISTS*/
/*                (SELECT 1*/
/*                 FROM &GPI_NDC_HIS B*/
/*                 WHERE A.DRUG_NDC_ID = B.DRUG_NDC_ID                 */
/*				 and   A.NHU_TYPE_CD = B.NHU_TYPE_CD*/
/*                 )*/
			) BY DB2;

   	%let _GETNDC_DRUG_NDC_TBL_SYSDBRC=&SYSDBRC;
    %let _GETNDC_DRUG_NDC_TBL_SYSDBMSG=&SYSDBMSG;

   execute
   (
   COMMIT
   )
   by DB2;
   disconnect from DB2;
   quit;


   proc sql noprint;
      SELECT COUNT(*) AS COUNT_DRUG_NDC_TBL into :COUNT_DRUG_NDC_TBL
      FROM   &DRUG_NDC_TBL;
   quit;


   %if (  (&_GETNDC_DRUG_NDC_TBL_SYSDBRC eq 0)
        or(%index(&_GETNDC_DRUG_NDC_TBL_SYSDBMSG,%str(SQLSTATE 01003)) ne 0)  )
   %then
   %do;
      %put NOTE: %cmpres(&COUNT_DRUG_NDC_TBL) rows inserted into &DRUG_NDC_TBL;
      %grant(tbl_name=&DRUG_NDC_TBL);
      %runstats(tbl_name=&DRUG_NDC_TBL);
   %end;
   %else
   %do;
      %if (&_GETNDC_DRUG_NDC_TBL_SYSDBRC eq 100) %then
      %do;
        %put NOTE: empty &DRUG_NDC_TBL table;
f        %drop_db2_table(tbl_name=&DRUG_NDC_TBL);
      %end;
      %else
      %do;
         %put ERROR: SYSDBRC =&_GETNDC_DRUG_NDC_TBL_SYSDBRC;
         %put ERROR: SYSDBMSG=&_GETNDC_DRUG_NDC_TBL_SYSDBMSG;
         %let err_fl=1;
      %end;
   %end;


%*SASDOC-----------------------------------------------------------------------
| Generate DRUG_NDC_TBL_RX.
+----------------------------------------------------------------------SASDOC*;
 	
   %IF &RX_ADJ=1 %THEN %DO;

   		%if (%cmpres(&DRUG_NDC_TBL_RX) ne) %then
		%drop_oracle_table(tbl_name=&DRUG_NDC_TBL_RX);
		%PUT NOTE: DROPPING TABLE &DRUG_NDC_TBL_RX BECAUSE IT EXISTS;
   		
		PROC SQL NOPRINT;
 		CREATE TABLE &DRUG_NDC_TBL_RX AS
 			SELECT DISTINCT A.DRUG_NDC_ID         
                 ,B.DRUG_GID
                 ,A.DRUG_CATEGORY_ID 
                 ,A.GPI_GROUP
        				 ,A.GPI_CLASS 
                 ,A.GPI_SUBCLASS
                 ,A.GPI_NAME    
                 ,A.GPI_NAME_EXTENSION
                 ,A.GPI_FORM          
                 ,A.GPI_STRENGTH      
        				 ,' ' AS NHU_TYPE_CD 
 			FROM &DRUG_NDC_TBL. A
 			LEFT JOIN
				(SELECT DRUG_GID
                ,NDC_CODE AS DRUG_NDC_ID
                ,SUBSTR(GPI_CODE,1,2) AS GPI_GROUP
                ,SUBSTR(GPI_CODE,3,2) AS GPI_CLASS 
                ,DRUG_VLD_FLG
                ,SUBSTR(GPI_CODE,5,2)AS GPI_SUBCLASS
                ,SUBSTR(GPI_CODE,7,2)AS GPI_NAME    
                ,SUBSTR(GPI_CODE,9,2)AS GPI_NAME_EXTENSION
                ,SUBSTR(GPI_CODE,11,2)AS GPI_FORM          
                ,SUBSTR(GPI_CODE,13,2)AS GPI_STRENGTH      
	  			FROM &DSS_CLIN..V_DRUG_DENORM) B
					ON  A.DRUG_NDC_ID = input(B.DRUG_NDC_ID,20.)
					AND B.DRUG_VLD_FLG = 'Y'
				    AND A.GPI_GROUP = B.GPI_GROUP
					AND A.GPI_CLASS = B.GPI_CLASS
				ORDER BY DRUG_NDC_ID, DRUG_GID;
		QUIT;

	%end;

%*SASDOC-----------------------------------------------------------------------
| Generate DRUG_NDC_TBL_QL.
+----------------------------------------------------------------------SASDOC*;

	%IF &QL_ADJ=1 %THEN %DO;
		
			%if (%cmpres(&DRUG_NDC_TBL_QL.) ne) %then 
				%drop_db2_table(tbl_name=&DRUG_NDC_TBL_QL.);
   				%PUT NOTE: DROPPING TABLE &DRUG_NDC_TBL_QL. BECAUSE IT EXISTS;

			proc sql noprint;
			connect to db2 as db2(dsn=&udbsprp.);
			execute
			(
				CREATE TABLE &DRUG_NDC_TBL_QL. AS
				(SELECT * FROM &DRUG_NDC_TBL.)
				DEFINITION ONLY NOT LOGGED INITIALLY
			)
			BY DB2;
			execute
			(	ALTER TABLE &DRUG_NDC_TBL_QL. ACTIVATE NOT LOGGED INITIALLY 
			) 
			BY DB2;
			execute
			(
				insert into &DRUG_NDC_TBL_QL. 
				SELECT * FROM &DRUG_NDC_TBL.
            )
			BY DB2;
			disconnect from db2;
			QUIT; 

	%END;

%drop_db2_table(tbl_name=&DRUG_NDC_TBL.);
/*%drop_db2_table(tbl_name=&GPI_NDC_HIS.);*/

%end;

%*SASDOC-----------------------------------------------------------------------
| Generate DRUG_NDC_TBL_RE.
+----------------------------------------------------------------------SASDOC*;

%RE_72:;

   %if &RE_ADJ=1 %then %do;

   %let NDC_TMP_TBL_RE72 = &ORA_TMP..&TABLE_PREFIX._NDC_TBL_RE72;
   %put NDC_TMP_TBL_RE72 = &NDC_TMP_TBL_RE72;

	%if (%cmpres(&NDC_TMP_TBL_RE72) ne) %then
	%drop_oracle_table(tbl_name=&NDC_TMP_TBL_RE72);
	%PUT NOTE: DROPPING TABLE &NDC_TMP_TBL_RE72 BECAUSE IT EXISTS;
   

	proc sql noprint;
	CREATE TABLE &NDC_TMP_TBL_RE72 AS
	 
	SELECT DISTINCT NDC_CODE AS DRUG_NDC_ID       
                 ,DRUG_GID
        				 ,59 AS DRUG_CATEGORY_ID
                 ,SUBSTR(GPI_CODE,1,2) AS GPI_GROUP        
             		 ,SUBSTR(GPI_CODE,3,2) AS GPI_CLASS
        				 ,' ' AS NHU_TYPE_CD
                 ,FDB_MAINT_IND
                 ,LEGAL_STATUS
    FROM &DSS_CLIN..V_DRUG_DENORM 
 	WHERE DRUG_VLD_FLG = 'Y'
	  AND FDB_MAINT_IND = 1
	  AND LEGAL_STATUS NOT LIKE 'C%'
	  AND ( (yrdif(datepart(RECAP_END_DATE), TODAY(),'ACT/ACT') < 3)
		   OR (RECAP_END_DATE IS NULL))
	ORDER BY DRUG_NDC_ID, DRUG_GID;
	QUIT;


/*-----------------------------------------------------------------------
|01JUN2009 G.O.D. - Removed following code to include Thyroid products and 
|hormone treatments ***
+----------------------------------------------------------------------*/
%macro to_be_removed_01jun2009;
%let GPI_NDC_HIS_EDW72 = &ORA_TMP..&TABLE_PREFIX._GPI_NDC_HIS_EDW72;
%put GPI_NDC_HIS_EDW72 = &GPI_NDC_HIS_EDW72;

	%if (%cmpres(&GPI_NDC_HIS_EDW72) ne) %then
	%drop_oracle_table(tbl_name=&GPI_NDC_HIS_EDW72);
	%PUT NOTE: DROPPING TABLE &GPI_NDC_HIS_EDW72 BECAUSE IT EXISTS;


	PROC SQL;
	CREATE TABLE &GPI_NDC_HIS_EDW72 AS
	SELECT DISTINCT   B.NDC_CODE AS DRUG_NDC_ID
					 ,B.DRUG_GID
           ,SUBSTR(GPI_CODE,1,2) AS GPI_GROUP
           ,SUBSTR(GPI_CODE,3,2) AS GPI_CLASS
            FROM 
				(
				 SELECT DISTINCT GPI_CD
				 				,SUBSTR(GPI_CD,1,2) AS GPI_GROUP
           			,SUBSTR(GPI_CD,3,2) AS GPI_CLASS
           			,SUBSTR(GPI_CD,5,2) AS GPI_SUBCLASS
           			,SUBSTR(GPI_CD,7,2) AS GPI_NAME
           			,SUBSTR(GPI_CD,9,2) AS GPI_NAME_EXTENSION
           			,SUBSTR(GPI_CD,11,2) AS GPI_FORM
           			,SUBSTR(GPI_CD,13,2) AS GPI_STRENGTH
								,DRUG_CATEGORY_ID
	   				  			 
	   			 FROM &HERCULES..TPROGRAM_GPI_HIS

				 WHERE 	 PROGRAM_ID     = &PROGRAM_ID
        				AND  EFFECTIVE_DT  <= TODAY()
        				AND  EXPIRATION_DT  > TODAY()
						AND  INCLUDE_IN = 0
				) A,
				&DSS_CLIN..V_DRUG_DENORM B

		WHERE  
			
				(	  	(A.DRUG_CATEGORY_ID       = 1)
			  		AND (    A.GPI_GROUP        = SUBSTR(B.GPI_CODE,1,2))
              		AND (    A.GPI_CLASS          IS NULL
                    	OR A.GPI_CLASS          = SUBSTR(B.GPI_CODE,3,2))
              		AND (    A.GPI_SUBCLASS       IS NULL
                    	OR A.GPI_SUBCLASS       = SUBSTR(B.GPI_CODE,5,2))
              		AND (    A.GPI_NAME           IS NULL
                    	OR A.GPI_NAME           = SUBSTR(B.GPI_CODE,7,2))
              		AND (    A.GPI_NAME_EXTENSION IS NULL
                    	OR A.GPI_NAME_EXTENSION = SUBSTR(B.GPI_CODE,9,2))
              		AND (    A.GPI_FORM           IS NULL
                    	OR A.GPI_FORM           = SUBSTR(B.GPI_CODE,11,2))
              		AND (    A.GPI_STRENGTH       IS NULL
                    	OR A.GPI_STRENGTH       = SUBSTR(B.GPI_CODE,13,2))
				)

		AND ( (yrdif(datepart(B.RECAP_END_DATE), TODAY(),'ACT/ACT') < 3)
		   OR (B.RECAP_END_DATE IS NULL))
		AND B.DRUG_VLD_FLG = 'Y'

            ORDER BY B.NDC_CODE, B.DRUG_GID;
	QUIT;
%mend to_be_removed_01jun2009;

	%if (%cmpres(&DRUG_NDC_TBL_RE) ne) %then
	%drop_oracle_table(tbl_name=&DRUG_NDC_TBL_RE);
	%PUT NOTE: DROPPING TABLE &DRUG_NDC_TBL_RE BECAUSE IT EXISTS;

/*-----------------------------------------------------------------------
|01JUN2009 G.O.D. - Removed following code to include Thyroid products and 
|hormone treatments ***
+----------------------------------------------------------------------*/
/*			   WHERE NOT EXISTS*/
/*                (SELECT 1*/
/*                 FROM &GPI_NDC_HIS_EDW72 B*/
/*                 WHERE A.DRUG_NDC_ID = B.DRUG_NDC_ID                 */
/*				 AND A.DRUG_GID = B.DRUG_GID*/
	PROC SQL NOPRINT;
	CREATE TABLE &DRUG_NDC_TBL_RE AS
	  SELECT * FROM &NDC_TMP_TBL_RE72;
    QUIT;
/*	%let _GETNDC_DRUG_NDC_TBL_SYSDBRC=&SYSDBRC;*/
/*  %let _GETNDC_DRUG_NDC_TBL_SYSDBMSG=&SYSDBMSG;*/
/*    %put NOTE: SYSDBRC =&SYSDBRC;*/
/*    %put NOTE: SYSDBMSG=&SYSDBMSG;*/
/*%if (  (&_GETNDC_DRUG_NDC_TBL_SYSDBRC eq 0)*/
/*        or(%index(&_GETNDC_DRUG_NDC_TBL_SYSDBMSG,%str(SQLSTATE 01003)) ne 0)  )*/
/*   %then*/
/*   %do;*/
/*      %put NOTE: %cmpres(&COUNT_DRUG_NDC_TBL) rows inserted into &DRUG_NDC_TBL_RE;*/
/*   %end;*/
/*   %else*/
/*   %do;*/
/*      %if (&_GETNDC_DRUG_NDC_TBL_SYSDBRC eq 100) %then*/
/*      %do;*/
/*        %put NOTE: empty &DRUG_NDC_TBL_RE table;*/
/*        %drop_oracle_table(tbl_name=&DRUG_NDC_TBL_RE);*/
/*      %end;*/
/*      %else*/
/*      %do;*/
/*         %put ERROR: SYSDBRC =&_GETNDC_DRUG_NDC_TBL_SYSDBRC;*/
/*         %put ERROR: SYSDBMSG=&_GETNDC_DRUG_NDC_TBL_SYSDBMSG;*/
/*         %let err_fl=1;*/
/*      %end;*/
/*   %end;*/
/*   %end;*/
/*   %end;*/
/*%end;   %*if (DRG_DEFINITION_CD eq 2) for program_id=72;*/


	proc sql noprint;
    SELECT COUNT(*) AS COUNT_DRUG_NDC_TBL into :COUNT_DRUG_NDC_TBL 
      FROM   &DRUG_NDC_TBL_RE;
    quit;

  %if (%cmpres(&COUNT_DRUG_NDC_TBL) gt 0)
   %then
   %do;
      %put NOTE: %cmpres(&COUNT_DRUG_NDC_TBL) rows inserted into &DRUG_NDC_TBL_RE;
   %end;
   %else
   %do;
     %put NOTE: empty &DRUG_NDC_TBL_RE table;
     %drop_oracle_table(tbl_name=&DRUG_NDC_TBL_RE);
     %let err_fl=1;
   %end;
   %end;
 %end; %* if &RE_ADJ=1 for program_id=72;
%end;   %*if (DRG_DEFINITION_CD eq 2) for program_id=72;

%MACRO TBL_XST(DB, TBL_NM, G_VARNAME);

 %LET POS=%INDEX(&TBL_NM,.); 
 %LET SCHEMA=%SUBSTR(&TBL_NM,1,%EVAL(&POS-1)); 
 %LET TBL_NAME_SH=%SUBSTR(&TBL_NM,%EVAL(&POS+1)); 

 %GLOBAL &G_VARNAME;

 %PUT &TBL_NAME_SH &SCHEMA;
%IF &DB eq %str('DB2') %THEN %DO;
	LIBNAME LBRF DB2 DSN=&UDBSPRP. SCHEMA=&SCHEMA. DEFER=YES;
%END;

%ELSE %IF &DB eq %str('ORACLE') %THEN %DO;
	LIBNAME LBRF ORACLE SCHEMA=&SCHEMA. PATH=&GOLD.;
%END;

%IF %SYSFUNC(EXIST(LBRF.&TBL_NAME_SH)) %THEN 
		%LET &G_VARNAME = 1;
%ELSE 	%LET &G_VARNAME = 0;
%MEND TBL_XST;

%if %sysfunc(exist(&DRUG_NDC_TBL_RX.)) or %sysfunc(exist(&DRUG_NDC_TBL_RE.)) %then %do;

%if (not %sysfunc(exist(&DRUG_NDC_TBL_RX.))) and &RE_ADJ = 1 %then %do;

proc sql print;
create table data_pnd.t_&initiative_id._missing_drug_gids_re as
select DRUG_GID, DRUG_NDC_ID
from &DRUG_NDC_TBL_RE.
where DRUG_GID IS NULL;
quit;

proc sql noprint;
select count(DRUG_NDC_ID), DRUG_NDC_ID into: COUNT_MISSING_GIDS, : NDCS_FOR_MISSING_GIDS separated by ','
from &DRUG_NDC_TBL_RE.
where DRUG_GID IS NULL;
quit;
%put NOTE: COUNT_MISSING_GIDS = &COUNT_MISSING_GIDS;
%put NOTE: NDCS_FOR_MISSING_GIDS = &NDCS_FOR_MISSING_GIDS;

	%if &COUNT_MISSING_GIDS > 0 %then %do;
		filename mymail email 'qcpap020@tstsas5';
   			data _null_;
     			file mymail
         		to=(&EMAIL_USR)
         		subject="&PROG_NAME" ;
				put 'Hi,' ;
     		put / "This is an automatically generated message to inform you that DRUG_GIDs for %left(%str(&COUNT_MISSING_GIDS.)) NDCs are not available for initiative &initiative_id.";
     		put / "This is the list of NDCs: (%str(&NDCS_FOR_MISSING_GIDS.) ";
				put / 'Please let us know of any questions.';
    		put / 'Thanks,';
     		put / 'HERCULES Production Supports';
   			run;
	%end;
%end;
%else %if %sysfunc(exist(&DRUG_NDC_TBL_RX.)) %then %do;

proc sql noprint;
select count(DRUG_NDC_ID), DRUG_NDC_ID into: COUNT_MISSING_GIDS, : NDCS_FOR_MISSING_GIDS separated by ','
from &DRUG_NDC_TBL_RX.
where DRUG_GID IS NULL;
quit;
proc sql print;
create table data_pnd.t_&initiative_id._missing_drug_gids_rx as
select DRUG_GID, DRUG_NDC_ID
from &DRUG_NDC_TBL_RX.
where DRUG_GID IS NULL;
quit;

	%if &COUNT_MISSING_GIDS > 0 %then %do;
		filename mymail email 'qcpap020@tstsas5';
   			data _null_;
     			file mymail
         		to=(&EMAIL_USR)
         		subject="&PROG_NAME" ;
				put 'Hi,' ;
     			put / "This is an automatically generated message to inform you that DRUG_GIDs for %left(%str(&COUNT_MISSING_GIDS.)) NDCs are not available for initiative &initiative_id.";
     			put / 'Please let us know of any questions.';
    			put / 'Thanks,';
     			put / 'HERCULES Production Supports';
   			run;

	%end;
%end;
%end;


%if &QL_ADJ = 1 %then %do;
%TBL_XST('DB2', &DRUG_NDC_TBL_QL, get_ndc_ndc_tbl_fl);
%PUT NOTE: NDC_TABLE_EXIST_FLAG_QL = &get_ndc_ndc_tbl_fl;
%end;

%if &RX_ADJ = 1 %then %do;
%TBL_XST('ORACLE', &DRUG_NDC_TBL_RX, get_ndc_ndc_tbl_rx_fl);
%PUT NOTE: NDC_TABLE_EXIST_FLAG_RX = &get_ndc_ndc_tbl_rx_fl;
%end;

%if &RE_ADJ = 1 %then %do;
%TBL_XST('ORACLE', &DRUG_NDC_TBL_RE, get_ndc_ndc_tbl_re_fl);
%PUT NOTE: NDC_TABLE_EXIST_FLAG_RE = &get_ndc_ndc_tbl_re_fl;
%end;
%if %SYSFUNC(EXIST(&DB2_TMP..&TABLE_PREFIX._RVW_DATES)) %THEN %DO;
%TBL_XST('DB2', &CLAIM_DATE_TBL, get_ndc_claims_tbl_fl);
%PUT NOTE: RVW_DATE_TABLE_EXIST_FLAG = &get_ndc_claims_tbl_fl;
%END;


%IF &DEBUG_FLAG=Y %THEN OPTIONS OPTIONS MPRINT MPRINTNEST MLOGIC MLOGICNEST SYMBOLGEN SOURCE2;;

%on_error( ACTION=ABORT
          ,EM_TO=&PRIMARY_PROGRAMMER_EMAIL
          ,EM_SUBJECT=HCE SUPPORT: Notification of Abend
          ,EM_MSG=%str(A problem was encountered. See LOG file -  GET_NDC log));
OPTIONS MPRINT MPRINTNEST MLOGIC MLOGICNEST SYMBOLGEN SOURCE2;

%mend get_ndc_proactive;
