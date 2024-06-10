%include '/user1/qcpap020/autoexec_new.sas';
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  formulary_purge.sas
|
| LOCATION: /PRG/sas&sysmode.1/hercules/87
|
| PURPOSE:  Used to produce task #3 (FORMULARY PURGE) for CMA program.
|
| LOGIC:    (1) Determine the target claim dates, formulary change dates
|               and formulary id.  Determine the incentive code(s) for
|               plans being targeted (open, closed, incentivized).
|
|           (2) Determine if any delivery systems should be omitted from claim
|               review.
|
|           (3) Drug Setup (optional) if turned on it will allow for the mailing
|               to run for the drugs that where identified provided they had a 
|               associated formulary status change. 
|
|           (4) Identify target drugs by finding the Y/Z drugs (formulary
|               indicator 3 or 4) that are moving to X/N status (formulary
|               indicator 5,6). Although rare, the mailing will also target
|               drugs moving from N to X status.
|               OR 
|               For Formulary_id=61 in addition we will identify target drugs 
|               whose ptv_cd of 5/6/9/0 for formulary status code (3,4,5) went 
|               to a ptv_cd  of 7 for formulary status code (3,4,5).
|               AND
|               Identify target drugs by running the %addfrmcmctn macro this will
|               check the drug history based on claims begin date and it will search
|               within the history if the Y/Z drugs (formulary
|               indicator 3 or 4) that are moving to X/N status (formulary
|               indicator 5,6). Although rare, the mailing will also target
|               drugs moving from N to X status. And if running for formulary 61
|               it will process that ptv logic.
|
|               Run qlfrmcmctn macro if drug table is defined from drug setup then
|               match up whats there to formulary changes and those will be the drugs
|               targeted for this mailing.
|
|           (5) Find participants within the CPGs found who have filled a
|               target NDC within the claim date range. DAW5 claims are always
|               excluded along with voids. It is not required that the claim be
|               billed.
|
|           (6) Get the Mail Order Pharmacy and Customer Care phone number.
|
|           (7) Perform standard eligibility check and omit these participants.
|
|           (8) Omit participants who have already switched to the new Y drug
|               in the same POD during the claim review period.
|
|           (9) Omit participants who have filled the generic equivalent
|               subsequent to filling the target drug. Use GPI attached to POD.
|
|           (10) Replace Cell and Pod messages (see macro).
|
|           (11) 3 Custom CMA reports are called and the client initiative summary
|               report
|
|           (12) Run standard macros - %create_base_file, %check_document,
|                %autorelease_file, %update_task_ts, %insert_cmctn_pending.
|
|
| INPUT:    TABLES ACCESSED BY CALLED MACROS ARE NOT LISTED BELOW
|           HERCULES.TINIT_FORMULARY
|           HERCULES.TINITIATIVE_DATE
|           HERCULES.TINIT_FRML_INCNTV
|           HERCULES.TDELIVERY_SYS_EXCL
|           &CLAIMSA..TDRUG1,
|           &CLAIMSA..TBENEF_XREF_DN
|           &CLAIMSA..TCLIENT1
|           &CLAIMSA..&CLAIM_HIS_TBL
|           &CLAIMSA..TCPG_PB_TRL_HIST
|           &CLAIMSA..TPB_FORMULARY_HIST
|           &CLAIMSA..TPRESC_BENEFIT
|
| OUTPUT:   standard files in /pending and /results directories
|
+-------------------------------------------------------------------------------
| HISTORY:  October 2003 - P.Wonders - Original.
|           January 2003 - 2 macros pod to ndc for 5/6 drugs and 6 to 5 to accept
|           >&Y_Z_DT and POD_DRUG_HIS.EFFECTIVE_DT <= &chg_dt rather than
|           >= &CHG_DT as criteria for EFF_DT parameter
|           November 2006 - N.Williams - Added code to process additional criteria
|                           when processing formulary_id=61 by creating 2 macros
|                           to go after PTV_CD on tables to enhance data capture 
|                           for formulary_id 61.
|			Jan, 2007	- Kuladeep M	  Added Claim end date is not null when
|										  fill_dt between claim begin date and claim end
|										  date.
|           21MAR2007     - Changed %eligibility_check_adhoc to %eligibility_check
|
|	        Mar  2007     - Greg Dudley Hercules Version  1.0                                      
|           30MAR2007     - N.Williams - Hercules Version  1.5
|                          Add call to %get_ndc macro for drug setup enablement in HCE
|                          for program_id 87 for selective tasks.
|
|           09Jan2009     - Ron Smith Hercules 2.1.1
|                           Add check to prevent participants from being removed 
|                           from mailing if the filled a rx for the same drug NDC
|                           as the targeted drug (can occur if only a PTV code change
|                           occurred).
|
|           26JAN2009     - N.Williams - Hercules Version  2.1.2
|                           1. Productionalize FYID# 78 custom code
|                           2. Include PTV Code (aka P_T_Perferred Code as output field
|                           for all formulary ids).
|                           3. Add Logic to populate CLT_LVL_1 with clt_plan_group_id
|                           this is needed so %check_document updates document id across the client 
|                           hierarchy levels.
|
|
+-----------------------------------------------------------------------HEADER*/
%set_sysmode;

options mlogic mlogicnest mprint mprintnest symbolgen source2;
/* options sysparm='INITIATIVE_ID= PHASE_SEQ_NB=1';  */
%INCLUDE "/herc&sysmode/prg/hercules/hercules_in.sas";
%INCLUDE "/herc&sysmode/prg/hercules/87/cma_tasks_in.sas";

%LET ERR_FL=0;
%LET PROGRAM_NAME=FORMULARY_PURGE;

* ---> Set the parameters for error checking;
 PROC SQL NOPRINT;
    SELECT QUOTE(TRIM(email)) INTO :Primary_programmer_email SEPARATED BY ' '
    FROM ADM_LKP.ANALYTICS_USERS
	WHERE UPCASE(QCP_ID) IN ("&USER"); 
 QUIT;

%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &INITIATIVE_ID");


*SASDOC-------------------------------------------------------------------------
| Update the job start timestamp.
+-----------------------------------------------------------------------SASDOC*;
%update_task_ts(job_start_ts);

*SASDOC-------------------------------------------------------------------------
| Find the formulary id and the begin/end dates that the mailing will target.
| This is determined by querying the TINITIATIVE_DATE table for records
| containing formularies/initiatives with dates for each of the following:
|
|   BEGIN CLAIM DATE               (DATE_TYPE_CD = 5) --> BEGIN_DT
|   END CLAIM DATE                 (DATE_TYPE_CD = 6) --> END_DT
|   NON-FORMULARY DRUG DATE        (DATE_TYPE_CD = 4) --> X_N_DT
|   IN-FORMULARY BEGIN CHECK DATE  (DATE_TYPE_CD = 7) --> Y_Z_DT
|
| This is a mailing initiative, so the PB Formulary ID must be checked as well
| (i.e., TINIT_FORMULARY.FRML_USAGE_CD = 1).
+-----------------------------------------------------------------------SASDOC*;

PROC SQL NOPRINT;
  SELECT A.FORMULARY_ID,
         "'"||PUT(B.INITIATIVE_DT, MMDDYY10.)||"'",
         "'"||PUT(C.INITIATIVE_DT, MMDDYY10.)||"'",
         "'"||PUT(D.INITIATIVE_DT, MMDDYY10.)||"'",
         "'"||PUT(E.INITIATIVE_DT, MMDDYY10.)||"'"
  INTO   :FRM_ID, :BEGIN_DT, :END_DT, :Y_Z_DT, :CHG_DT
  FROM   &HERCULES..TINIT_FORMULARY A,
         &HERCULES..TINITIATIVE_DATE B,
         &HERCULES..TINITIATIVE_DATE C,
         &HERCULES..TINITIATIVE_DATE D,
         &HERCULES..TINITIATIVE_DATE E
  WHERE  A.INITIATIVE_ID = &INITIATIVE_ID
    AND  A.INITIATIVE_ID = B.INITIATIVE_ID
    AND  A.INITIATIVE_ID = C.INITIATIVE_ID
    AND  A.INITIATIVE_ID = D.INITIATIVE_ID
    AND  A.INITIATIVE_ID = E.INITIATIVE_ID
    AND  B.DATE_TYPE_CD = 5      /* claim begin */
    AND  C.DATE_TYPE_CD = 6      /* claim end   */
    AND  D.DATE_TYPE_CD = 4      /* y_z_dt - last formulary review */
    AND  E.DATE_TYPE_CD = 7      /* x_n_dt - change effective date */
    AND  A.FRML_USAGE_CD = 1;
QUIT;

%PUT BEGIN_DT=&BEGIN_DT END_DT=&END_DT CHG_DT=&CHG_DT Y_Z_DT=&Y_Z_DT frm_id=&frm_id ;
%LET FTR_FRM_ID=&FRM_ID;
*SASDOC-------------------------------------------------------------------------
| Get the incentive type code(s) (INITIATIVE_ID) that will be targeted for the
| current plan design (i.e., PERIOD_CD=1) from the TINIT_FRML_INCNTV table.
| The resulting macrovar, ICT_CD, will be used to filter rows later in this
| program.
+-----------------------------------------------------------------------SASDOC*;

PROC SQL NOPRINT;
  SELECT INCENTIVE_TYPE_CD INTO :ICT_CD SEPARATED BY ','
  FROM &HERCULES..TINIT_FRML_INCNTV
  WHERE INITIATIVE_ID = &INITIATIVE_ID
    AND PERIOD_CD = 1;
QUIT;
%PUT ICT_CD=&ICT_CD;

*SASDOC-------------------------------------------------------------------------
| Determine if any of the delivery systems should be excluded from the
| initiative.  If so, form a string that will be inserted into the SQL that
| queries claims.
+-----------------------------------------------------------------------SASDOC*;
PROC SQL NOPRINT;
  SELECT COUNT(DELIVERY_SYSTEM_CD) INTO :OMIT_DS
  FROM &HERCULES..TDELIVERY_SYS_EXCL
  WHERE INITIATIVE_ID = &INITIATIVE_ID;
QUIT;
%LET OMIT_DS=&OMIT_DS;
%PUT OMIT_DS=&OMIT_DS;


%MACRO GET_DS_STRING;
%GLOBAL DS_STRING;

%IF &OMIT_DS > 0 %then %DO;

   PROC SQL NOPRINT;
        SELECT DELIVERY_SYSTEM_CD INTO :OMIT_DS_STR SEPARATED BY ','
        FROM &HERCULES..TDELIVERY_SYS_EXCL
        WHERE INITIATIVE_ID = &INITIATIVE_ID;
    QUIT;

   %LET DS_STRING=%STR( AND DELIVERY_SYSTEM_CD NOT IN (&OMIT_DS_STR));
 %END;
%ELSE %DO;
   %LET  DS_STRING=%STR();

  %END;
%MEND GET_DS_STRING;

%GET_DS_STRING;

%PUT &DS_STRING;

*SASDOC--------------------------------------------------------------------------
| Set CALL %get_ndc - 30MAR2007 - N.Williams
+------------------------------------------------------------------------SASDOC*;
%macro set_adj_engine;
%GLOBAL FRM_ADJ;
  %IF &QL_ADJ = 1 %THEN %DO;
    %LET FRM_ADJ = QL;
  %END;
  %ELSE %IF &RX_ADJ = 1 %THEN %DO;
          %LET FRM_ADJ = RX;
        %END;
        %ELSE %IF &RE_ADJ = 1 %THEN %DO;
                %LET FRM_ADJ = RE;
              %END;
%mend set_adj_engine;
%set_adj_engine;

%PUT &FRM_ADJ;



*SASDOC--------------------------------------------------------------------------
| CALL %get_ndc - 30MAR2007 - N.Williams
+------------------------------------------------------------------------SASDOC*;
%get_ndc(DRUG_NDC_TBL=&DB2_TMP..&TABLE_PREFIX._NDC);

*SASDOC-------------------------------------------------------------------------
| Identify the target drugs by finding Y/Z drugs (i.e., "in-formulary" drugs --
| formulary indicator 3 and 4) that are moving to X/N status (i.e.,
| "non-formulary" drugs -- indicator 5 or 6).
+-----------------------------------------------------------------------SASDOC*;
%POD_TO_NDC(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._NDC_Y_Z, FRM_STS=%STR(3,4), EFF_DT=%str(< &CHG_DT),
            EXP_DT=%STR(BETWEEN &Y_Z_DT AND &CHG_DT));

%POD_TO_NDC(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._NDC_X_N, FRM_STS=%STR(5,6),
            EFF_DT=%str(>&Y_Z_DT and POD_DRUG_HIS.EFFECTIVE_DT <= &chg_dt),
            EXP_DT=%STR(> CURRENT DATE), EXTRA_CRITERIA=AND FORM_POD.EXPIRATION_DT %STR(> &CHG_DT));

*SASDOC-------------------------------------------------------------------------
| Look for a match on NDC/POD.  Convert the formulary status codes into "user
| codes" i.e. 3, 4, 5, 6 becomes y, z, x, n (respectively).  Do not target
| generic drugs.
|
| 26JAN2009 - N.Williams - Hercules Version  2.1.2
|             Added PTV Code(aka P_T_PREFERRED_CD) as part of table definition
|			  and table insert selection. 
+-----------------------------------------------------------------------SASDOC*;

%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._NDC_CHG);

PROC SQL NOPRINT;
  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);

    EXECUTE(
      CREATE TABLE &DB2_TMP..&TABLE_PREFIX._NDC_CHG
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
  DISCONNECT FROM DB2;
QUIT;

%POD_CHANGES(TBL1_IN=&DB2_TMP..&TABLE_PREFIX._NDC_X_N, TBL2_IN=&DB2_TMP..&TABLE_PREFIX._NDC_Y_Z,
             TBL_OUT=&DB2_TMP..&TABLE_PREFIX._NDC_CHG);
%SET_ERROR_FL;

*SASDOC-------------------------------------------------------------------------
| Find the N drugs that are moving to X status.  There may not be drugs in this
| category - so do not use the %set_error_fl/error flag.
+-----------------------------------------------------------------------SASDOC*;
%POD_TO_NDC(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._NDC_N, FRM_STS=%str(6), EFF_DT=%STR(< &CHG_DT),
                                                 EXP_DT=%str(BETWEEN &Y_Z_DT AND &CHG_DT));
%POD_TO_NDC(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._NDC_X, FRM_STS=%str(5),
           EFF_DT=%STR(>&Y_Z_DT and POD_DRUG_HIS.EFFECTIVE_DT <= &chg_dt),
           EXP_DT=%str(> CURRENT DATE), EXTRA_CRITERIA=AND FORM_POD.EXPIRATION_DT %STR(> &CHG_DT));


%POD_CHANGES(TBL1_in=&DB2_TMP..&TABLE_PREFIX._NDC_X, TBL2_in=&DB2_TMP..&TABLE_PREFIX._NDC_N,
             TBL_OUT=&DB2_TMP..&TABLE_PREFIX._NDC_CHG);
%put _all_;
*SASDOC-------------------------------------------------------------------------
| MACRO: %POD_EXECUTE61 - November 2006 - N.Williams 
|------------------------------------------------------------------------------
| This macro was created to run for formulary_id 61 it will execute only when
| running for formulary 61 and it gets target drugs who's ptv code changed 
| from with 0/5/6/9 to 7. It creates 3 tables related for comparasion of PTV
| changes and modified NDC_CHG table to incorporate PTV change results with 
| regular formulary status change results.
|------------------------------------------------------------------------------
| MACRO: %POD_EXECUTE - January 2009 - N.Williams 
|------------------------------------------------------------------------------
| 1. Macro was renamed to POD_EXECUTE.
| 2. Customization was add for fyid# 78 
| 3. Formulary Changes Business Rules where modified for fyid# 61 & 78 to both 
|    be the same change logic.
+-----------------------------------------------------------------------SASDOC*;
%MACRO POD_EXECUTE;

%IF &FRM_ID=61 OR &FRM_ID=78 %THEN %DO ;

*SASDOC-------------------------------------------------------------------------
| Identify the target drugs by finding drugs with 0/5/6/9 P_T_PREFERRED_CD aka
| PTV_CD (i.e. "Preferred") that are moving to 7 code (i.e. "Non-Preferred")
+-----------------------------------------------------------------------SASDOC*;
/*OLD STATUS*/
%POD_TO_NDC61(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._NDC_PTV_OTHER, 
              FRM_STS=%STR(3,4), 
              PTVCODE=%STR(5,6),
              EFF_DT=%str(< &CHG_DT),
              EXP_DT=%STR(BETWEEN &Y_Z_DT AND &CHG_DT), 
              EXTRA_CRITERIA=AND POD_DRUG_HIS.EXPIRATION_DT <> '12/31/9999');

/*NEW STATUS */
%POD_TO_NDC61(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._NDC_PTV_TIER3,
              FRM_STS=%STR(5,6),
              PTVCODE=%STR(5,6,7),
              EFF_DT=%str(>&Y_Z_DT and POD_DRUG_HIS.EFFECTIVE_DT <= &CHG_DT),
              EXP_DT=%STR(> CURRENT DATE), 
              EXTRA_CRITERIA=AND FORM_POD.EXPIRATION_DT %STR(> &CHG_DT));

/*NEW STATUS sevens only*/
%POD_TO_NDC61(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._NDC_PTV_SEVEN,
              FRM_STS=%STR(3,4),
              PTVCODE=%STR(7),
              EFF_DT=%str(>&Y_Z_DT and POD_DRUG_HIS.EFFECTIVE_DT <= &CHG_DT),
              EXP_DT=%STR(> CURRENT DATE), 
              EXTRA_CRITERIA=AND FORM_POD.EXPIRATION_DT %STR(> &CHG_DT));


%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._NDC_PTV_CHG);

   PROC SQL NOPRINT;
     CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	      EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._NDC_PTV_CHG
          (DRUG_NDC_ID DECIMAL(11) not null,
           NHU_TYPE_CD SMALLINT not null,
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
           PRIMARY KEY(DRUG_NDC_ID, NHU_TYPE_CD))) BY DB2;
  DISCONNECT FROM DB2;
QUIT;

*SASDOC-------------------------------------------------------------------------
| Identify formulary changes formulary status code + ptv code.
| This was spilit up to accurately track formulary business changes.
| (i.e. 35, 45, 36, 46 -> 37 47 and 35, 45, 36, 46 -> 55,56,57,65,66,67)
+-----------------------------------------------------------------------SASDOC*;
%POD_CHANGES61(TBL1_IN=&DB2_TMP..&TABLE_PREFIX._NDC_PTV_SEVEN, /** NEW STATUS**/
               TBL2_IN=&DB2_TMP..&TABLE_PREFIX._NDC_PTV_OTHER, /** OLD STATUS**/
               TBL_OUT=&DB2_TMP..&TABLE_PREFIX._NDC_PTV_CHG);

%POD_CHANGES61(TBL1_IN=&DB2_TMP..&TABLE_PREFIX._NDC_PTV_TIER3, /** NEW STATUS**/
               TBL2_IN=&DB2_TMP..&TABLE_PREFIX._NDC_PTV_OTHER, /** OLD STATUS**/
               TBL_OUT=&DB2_TMP..&TABLE_PREFIX._NDC_PTV_CHG);

%SET_ERROR_FL;


*SASDOC-------------------------------------------------------------------------
| Remove duplicate rows: Delete ptv_chg when a drug_ndc_id has already been created 
+-----------------------------------------------------------------------SASDOC*;

PROC SQL NOPRINT;
  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
    EXECUTE(DELETE FROM &DB2_TMP..&TABLE_PREFIX._NDC_PTV_CHG A
            WHERE EXISTS
             (SELECT 1
              FROM &DB2_TMP..&TABLE_PREFIX._NDC_CHG B
              WHERE A.DRUG_NDC_ID = B.DRUG_NDC_ID
              AND   A.POD_ID      = B.POD_ID)) BY DB2;
  %reset_sql_err_cd;

QUIT;
%set_error_fl;
%RUNSTATS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._NDC_CHG);

*SASDOC-----------------------------------------------------------------------
| CHECK NUMBER OF ROWS IN PTV_CHG TABLE BEFORE INSERTING into NDC_CHG
+-----------------------------------------------------------------------SASDOC*;
%NOBS(&DB2_TMP..&TABLE_PREFIX._NDC_PTV_CHG);
%PUT NOTE: &DB2_TMP..&TABLE_PREFIX._NDC_PTV_CHG contains &NOBS observations.;

	%IF &NOBS NE 0 %THEN %DO;
		PROC SQL;
        CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
        EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX._NDC_CHG
               (SELECT A.DRUG_NDC_ID,                       
                       A.NHU_TYPE_CD,
                       A.POD_ID,
		               A.POD_NM,
                       A.CELL_NM,
                       A.DRUG_ABBR_PROD_NM,
                       A.DRUG_ABBR_DSG_NM,
                       A.DRUG_ABBR_STRG_NM,
                       A.GENERIC_AVAIL_IN,
                       A.GPI_GROUP,
                       A.GPI_CLASS,
                       A.GPI_SUBCLASS,
                       A.GPI_NAME,
                       A.GPI_NAME_EXTENSION,
                       A.GPI_FORM,
                       A.GPI_STRENGTH,
                       A.ORG_FRM_STS,
                       A.NEW_FRM_STS,
		               A.ORG_PTV_CD,
		               A.NEW_PTV_CD
                FROM   &DB2_TMP..&TABLE_PREFIX._NDC_PTV_CHG A)) BY DB2;
          %reset_sql_err_cd;
    %END;
QUIT;
%set_error_fl;

%RUNSTATS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._NDC_CHG);

%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._NDC_PTV_CHG);    /* N.Williams */
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._NDC_PTV_SEVEN);  /* N.Williams */
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._NDC_PTV_OTHER);  /* N.Williams */  
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._NDC_PTV_TIER3);   /* N.Williams */  

%END;
%MEND POD_EXECUTE;

*SASDOC------------------------------------------------------------------------
| November 2006 - N.Williams 
| Make call to %POD_execute61 macro for selective execution by formulary id 61.
| 26JAN2009 - N.Williams - Renamed %pod_execute61 to %pod_execute
+-----------------------------------------------------------------------SASDOC*;
%POD_EXECUTE; 

*SASDOC--------------------------------------------------------------------------
| 30MAR2007 - N.Williams - call %addfrmchgs CODE This will catch additional formulary
| changes that where not picked up in normal formulary changes logic. 
| This is done by look at current row and looking back in history based on date
| range for mailing to see if there was a formulary status change or ptv change
| is running for formulary id=61. 
+------------------------------------------------------------------------SASDOC*;
%addfrmcmctn  (TBLIN=&DB2_TMP..&TABLE_PREFIX._NDC_CHG,
               PRGNM=FORMULARY_PURGE,
     		   HIST_EXP_DT=%str(>= &Y_Z_DT ),
               FORMULARY_ID=&FRM_ID);

*SASDOC--------------------------------------------------------------------------
| 30MAR2007 - N.Williams - call %QLFRMCMCTN CODE This will enable the inclusion
| of drugs for initiative to run on as well. 
+------------------------------------------------------------------------SASDOC*;
%QLFRMCMCTN(TBLIN=&DB2_TMP..&TABLE_PREFIX._NDC_CHG,NDCTBL=&DB2_TMP..&TABLE_PREFIX._NDC);

*SASDOC-------------------------------------------------------------------------
| Get the target claims for the given formulary.
+-----------------------------------------------------------------------SASDOC*;
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS);

PROC SQL;
  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);

    EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS
                (PT_BENEFICIARY_ID INTEGER NOT NULL,
                 DRUG_NDC_ID DECIMAL(11) NOT NULL,
                 NHU_TYPE_CD SMALLINT NOT NULL,
                 CDH_BENEFICIARY_ID INTEGER NOT NULL,
                 POD_ID INTEGER NOT NULL,
                 LAST_FILL_DT DATE,
                 RXS INTEGER) NOT LOGGED INITIALLY) BY DB2;
  DISCONNECT FROM DB2;
QUIT;

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
    EXECUTE(ALTER TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS
            ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;

    EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX._CLAIMS
           (SELECT B.PT_BENEFICIARY_ID,
                   A.DRUG_NDC_ID, 
                   A.NHU_TYPE_CD, 
                   B.CDH_BENEFICIARY_ID,
                   A.POD_ID,
                   MAX(B.FILL_DT) AS LAST_FILL,
                   SUM(RX_COUNT_QY)
            FROM   &DB2_TMP..&TABLE_PREFIX._NDC_CHG A,
                   &CLAIMSA..&CLAIM_HIS_TBL B
            WHERE A.DRUG_NDC_ID = B.DRUG_NDC_ID
            AND   A.NHU_TYPE_CD = B.NHU_TYPE_CD
            AND   FORMULARY_ID IN (&FRM_ID)
            AND   DAW_TYPE_CD NOT IN (5)
            AND   FILL_DT BETWEEN &BEGIN_DT AND &END_DT
			AND   B.BILLING_END_DT IS NOT NULL
            &DS_STRING
            GROUP BY B.PT_BENEFICIARY_ID,
                     A.DRUG_NDC_ID, 
                     A.NHU_TYPE_CD, 
                     B.CDH_BENEFICIARY_ID,
                     A.POD_ID

            HAVING SUM(RX_COUNT_QY) > 0)) BY DB2;
  %reset_sql_err_cd;

QUIT;
%set_error_fl;

%RUNSTATS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CLAIMS);


*SASDOC--------------------------------------------------------------------------
|  Additional Columns - Drugs
+------------------------------------------------------------------------SASDOC*;
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._QL_DRUG);

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._QL_DRUG AS
      (  SELECT                  A.NTW_PRESCRIBER_ID AS PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID,
                                 A.PT_BENEFICIARY_ID,
                                 A.PT_BIRTH_DT          AS BIRTH_DT,  
 				 A.CLIENT_ID,
 				 A.CLT_PLAN_GROUP_ID as CLT_PLAN_GROUP_ID2,
                                 A.RX_NB,
                                 A.CALC_BRAND_CD,
                                 A.DRUG_NDC_ID, 
                                 A.FILL_DT  AS LAST_FILL_DT,
                                 A.DAY_SUPPLY_QY,
                                 A.DELIVERY_SYSTEM_CD,
                                 A.DISPENSED_QY 
                          FROM  &CLAIMSA..&CLAIM_HIS_TBL A 
      ) DEFINITION ONLY NOT LOGGED INITIALLY
               ) BY DB2;
   DISCONNECT FROM DB2;
QUIT;


*SASDOC--------------------------------------------------------------------------
|  Additional Columns - Drugs
+------------------------------------------------------------------------SASDOC*;
PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
EXECUTE
  (ALTER TABLE &DB2_TMP..&TABLE_PREFIX._QL_DRUG ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;
   EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX._QL_DRUG
	         SELECT          B.NTW_PRESCRIBER_ID    AS PRESCRIBER_ID,
				 B.CDH_BENEFICIARY_ID,
				 B.PT_BENEFICIARY_ID,
				 MAX(B.PT_BIRTH_DT)     AS BIRTH_DT,  
				 B.CLIENT_ID,
				 B.CLT_PLAN_GROUP_ID    AS CLT_PLAN_GROUP_ID2,
				 B.RX_NB                AS RX_NB,
				 B.CALC_BRAND_CD,
				 B.DRUG_NDC_ID          AS DRUG_NDC_ID, 
				 B.FILL_DT              AS LAST_FILL_DT,
				 B.DAY_SUPPLY_QY,
				 B.DELIVERY_SYSTEM_CD,
				 B.DISPENSED_QY 
                       
             FROM   &DB2_TMP..&TABLE_PREFIX._NDC_CHG A,
                    &CLAIMSA..&CLAIM_HIS_TBL B
             WHERE A.DRUG_NDC_ID = B.DRUG_NDC_ID
             AND   A.NHU_TYPE_CD = B.NHU_TYPE_CD
             AND   FORMULARY_ID IN (&FRM_ID)
             AND   DAW_TYPE_CD NOT IN (5)
             AND   FILL_DT BETWEEN &BEGIN_DT AND &END_DT
 			AND   B.BILLING_END_DT IS NOT NULL
            &DS_STRING
			GROUP BY B.NTW_PRESCRIBER_ID,
				 B.CDH_BENEFICIARY_ID,
				 B.PT_BENEFICIARY_ID,
				 B.CLIENT_ID,
				 B.CLT_PLAN_GROUP_ID,
				 B.RX_NB,
				 B.CALC_BRAND_CD,
				 B.DRUG_NDC_ID,
				 B.FILL_DT,
				 B.DAY_SUPPLY_QY,
				 B.DELIVERY_SYSTEM_CD,
				 B.DISPENSED_QY

      ) BY DB2; 
QUIT;


*SASDOC-------------------------------------------------------------------------
| Determine the active CPGs for PBs attached to the target formulary and
| applicable incentive codes.
+-----------------------------------------------------------------------SASDOC*;

%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CPG);

PROC SQL;
  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);

    EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._CPG
          (CLT_PLAN_GROUP_ID INTEGER NOT NULL,
           GRACE_DAYS SMALLINT,
           INCENTIVE_TYPE_CD INTEGER)) BY DB2;

    EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX._CPG
         SELECT DISTINCT A.CLT_PLAN_GROUP_ID,
                         B.GRACE_DAYS_CNT_QY,
                         B.INCENTIVE_TYPE_CD
         FROM &CLAIMSA..TCPG_PB_TRL_HIST A,
              &CLAIMSA..TPB_FORMULARY_HIST B,
              &CLAIMSA..TPRESC_BENEFIT C
         WHERE A.PB_ID = C.PB_ID
         AND  ((B.PB_ID = C.PB_ID AND PB_CLASS_CD = 3)
               OR
              (B.PB_ID = C.MASTER_PB_ID AND PB_CLASS_CD = 2))
         AND C.END_FILL_DT > CURRENT DATE
         AND C.END_ENTRY_DT > CURRENT DATE
         AND B.PB_STATUS_CD =1
         AND C.INACTIVE_DT > CURRENT DATE
         AND C.END_ENTRY_DT > CURRENT DATE
         AND A.EFF_DT <= CURRENT DATE
         AND A.EXP_DT >  CURRENT DATE
         AND B.EFF_DT <= CURRENT DATE
         AND B.EXP_DT >  CURRENT DATE
         AND B.INCENTIVE_TYPE_CD IN (&ICT_CD)
         AND B.FORMULARY_ID = &FRM_ID) BY DB2;
  %reset_sql_err_cd;

QUIT;
%set_error_fl;

%RUNSTATS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CPG);
*SASDOC--------------------------------------------------------------------------
| CALL %get_moc_phone
| Add the Mail Order pharmacy and customer service phone to the cpg file
+------------------------------------------------------------------------SASDOC*;
 %get_moc_csphone(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._CPG,
                  TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CPG_MOC);

*SASDOC-------------------------------------------------------------------------
| Determine eligibility for the cardholdler as well as participant (if
| available).
+-----------------------------------------------------------------------SASDOC*;

%eligibility_check(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._CLAIMS,
                     TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG,
                     CLAIMSA=&CLAIMSA);

*SASDOC-------------------------------------------------------------------------
| Eliminate claims that should not be includes because of eligibility.  This
| extra step was added to improve performance before deleting alternate therapy.
| 26JAN2009 - N.Williams - Add CLT_LVL_1(will contain clt_plan_group_id) 
|			               column to claims2 table
+-----------------------------------------------------------------------SASDOC*;

%reset_sql_err_cd;
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS2);
PROC SQL;
  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);


    EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS2
                (PT_BENEFICIARY_ID INTEGER NOT NULL,
                 DRUG_NDC_ID DECIMAL(11) NOT NULL,
                 NHU_TYPE_CD SMALLINT NOT NULL,
                 POD_ID INTEGER NOT NULL,
                 GRACE_DAYS SMALLINT,
                 INCENTIVE_TYPE_CD SMALLINT,
                 LAST_FILL_DT DATE,
                 CS_AREA_PHONE CHAR(13),
                 MOC_PHM_CD CHAR(4),
                 BLG_REPORTING_CD CHAR(15),
                 PLAN_CD CHAR(8),
                 PLAN_EXTENSION_CD CHAR(8),
                 GROUP_CD CHAR(15),
                 GROUP_EXTENSION_CD CHAR(5),
        				 CLIENT_LEVEL_1   CHAR(22),	
                 ADJ_ENGINE       CHAR(2),
                 PRIMARY KEY(PT_BENEFICIARY_ID, DRUG_NDC_ID, NHU_TYPE_CD))
                 NOT LOGGED INITIALLY) BY DB2;
  DISCONNECT FROM DB2;
QUIT;
%set_error_fl;


PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
    EXECUTE(ALTER TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS2
            ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;

    EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX._CLAIMS2
           (SELECT A.PT_BENEFICIARY_ID,
                   B.DRUG_NDC_ID,
                   B.NHU_TYPE_CD,
                   B.POD_ID,
                   MIN(C.GRACE_DAYS),
                   MAX(C.INCENTIVE_TYPE_CD),
                   MAX(B.LAST_FILL_DT),
                   MAX(C.CS_AREA_PHONE),
                   C.MOC_PHM_CD,
                   MAX(D.BLG_REPORTING_CD),
                   D.PLAN_CD,
                   PLAN_EXTENSION_CD,
                   GROUP_CD,
                   GROUP_EXTENSION_CD,				   
				   CHAR(COALESCE(A.CLT_PLAN_GROUP_ID,C.CLT_PLAN_GROUP_ID)), /** 26JAN2009 N. Williams**/
				   %BQUOTE('QL') /** 26JAN2009 N. Williams**/
            FROM   &DB2_TMP..&TABLE_PREFIX._CPG_ELIG A,
                   &DB2_TMP..&TABLE_PREFIX._CLAIMS   B,
                   &DB2_TMP..&TABLE_PREFIX._CPG_MOC C,
                   &CLAIMSA..TCPGRP_CLT_PLN_GR1 D
            WHERE A.PT_BENEFICIARY_ID = B.PT_BENEFICIARY_ID
            AND   C.CLT_PLAN_GROUP_ID = A.CLT_PLAN_GROUP_ID
            AND   C.CLT_PLAN_GROUP_ID = D.CLT_PLAN_GROUP_ID
 
            GROUP BY A.PT_BENEFICIARY_ID,
                     B.DRUG_NDC_ID,
                     B.NHU_TYPE_CD,
                     B.POD_ID,
                     C.MOC_PHM_CD,
                     PLAN_CD,
                     PLAN_EXTENSION_CD,
                     GROUP_CD,
                     GROUP_EXTENSION_CD,
					 COALESCE(A.CLT_PLAN_GROUP_ID,C.CLT_PLAN_GROUP_ID),  /** 26JAN2009 N. Williams**/
					 %BQUOTE('QL')
            )) BY DB2;
  %reset_sql_err_cd;

QUIT;
%set_error_fl;

%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &INITIATIVE_ID");


%RUNSTATS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CLAIMS2);

*SASDOC-------------------------------------------------------------------------
| Find the formulary alternates for each pod.
+-----------------------------------------------------------------------SASDOC*;

%POD_TO_NDC(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._NDC_ALT,
            FRM_STS =%str(3,4),
            EFF_DT  =%str(>= '01/01/1999' and POD.POD_ID IN
                          (SELECT DISTINCT POD_ID
                           FROM &DB2_TMP..&TABLE_PREFIX._NDC_CHG)),
            EXP_DT  =%str(> CURRENT DATE));

*SASDOC-------------------------------------------------------------------------
| Find NDCs for pods with a generic available.
+-----------------------------------------------------------------------SASDOC*;

PROC SQL NOPRINT;
 CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX._NDC_ALT(DRUG_NDC_ID, NHU_TYPE_CD, POD_ID)
            SELECT DISTINCT
                   A.DRUG_NDC_ID,
                   A.NHU_TYPE_CD,
                   B.POD_ID
            FROM   &CLAIMSA..TDRUG1 A,
                   &DB2_TMP..&TABLE_PREFIX._NDC_CHG B
            WHERE  A.GPI_GROUP = B.GPI_GROUP
            AND   (A.GPI_CLASS = B.GPI_CLASS OR B.GPI_CLASS IS NULL)
            AND   (A.GPI_SUBCLASS = B.GPI_SUBCLASS OR B.GPI_SUBCLASS IS NULL)
            AND   (A.GPI_NAME = B.GPI_NAME OR B.GPI_NAME IS NULL)
            AND   (A.GPI_NAME_EXTENSION = B.GPI_NAME_EXTENSION OR B.GPI_NAME_EXTENSION IS NULL)
            AND   (A.GPI_FORM = B.GPI_FORM OR B.GPI_FORM IS NULL)
            AND   (A.GPI_STRENGTH = B.GPI_STRENGTH OR B.GPI_STRENGTH IS NULL)
            AND   A.DRUG_BRAND_CD = 'G'
            AND   B.GENERIC_AVAIL_IN = 1
            AND   (DISCONTINUANCE_DT IS NULL OR (DISCONTINUANCE_DT < CURRENT DATE - 3 YEARS))
            AND NOT EXISTS
                  (SELECT 1
                   FROM &DB2_TMP..&TABLE_PREFIX._NDC_ALT Z
                   WHERE B.DRUG_NDC_ID = DRUG_NDC_ID
                   AND   B.NHU_TYPE_CD = NHU_TYPE_CD
                   AND   B.POD_ID = POD_ID)) by DB2;
        %reset_sql_err_cd;

QUIT;
%set_error_fl;

%RUNSTATS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._NDC_ALT);

*SASDOC-------------------------------------------------------------------------
| Delete claims when the participant has filled the generic or formulary
| alternate for the pod after the non-formulary fill.
| 09Jan2009 - RS added check to prevent removal of rows where the NDC filled 
|             is the same as the NDC being targeted
+-----------------------------------------------------------------------SASDOC*;

PROC SQL NOPRINT;
  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
    EXECUTE(DELETE FROM &DB2_TMP..&TABLE_PREFIX._CLAIMS2 A
            WHERE EXISTS
             (SELECT 1
              FROM &CLAIMSA..&CLAIM_HIS_TBL X,
                   &DB2_TMP..&TABLE_PREFIX._NDC_ALT Y
              WHERE A.PT_BENEFICIARY_ID = X.PT_BENEFICIARY_ID
              AND Y.DRUG_NDC_ID = X.DRUG_NDC_ID
              AND Y.NHU_TYPE_CD = X.NHU_TYPE_CD
              AND A.POD_ID = Y.POD_ID
              /* NDC cannot be the same as the targeted drug */
              AND Y.DRUG_NDC_ID <> A.DRUG_NDC_ID
              AND X.FILL_DT > A.LAST_FILL_DT
              AND X.BILLING_END_DT > &BEGIN_DT
              AND X.BRLI_VOID_IN = 0)) BY DB2;
  %reset_sql_err_cd;

QUIT;
%set_error_fl;

*SASDOC------------------------------------------------------------------------
| Message Processing: The Cell and Pod names contain message text as does the
| custom message table.  The determination of where to pull and how to parse
| the message text is handled by the %GET_MESSAGE CMA macro.
+----------------------------------------------------------------------SASDOC*;

%GET_MESSAGE(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._NDC_CHG,
             TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._NDC_CHG2);

***** _NDC_CHG2 now contains the parsed messages *****;
*SASDOC-------------------------------------------------------------------------
| Omit ineligible CPGs. When plan is closed and drug is moving to an N status,
| remove from the mailing.
+-----------------------------------------------------------------------SASDOC*;
%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS3);

*SASDOC-------------------------------------------------------------------------
| Macro: Get_Claims3 - November 2006 - N.Williams 
+-------------------------------------------------------------------------------
| Macro to get claims data and for formulary 61 to include ptv_cd in results
+-------------------------------------------------------------------------------
| Macro: Get_Claims3 - 26JAN2009 - N.Williams REMOVED 61 logic for ptv code.
|                                  Also added CLT_LVL_1 column.         
+-----------------------------------------------------------------------SASDOC*;
%MACRO GET_CLAIMS3 ;
PROC SQL;
    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
      EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS3 as
         (select
             INCENTIVE_TYPE_CD as LTR_RULE_SEQ_NB,
             PT_BENEFICIARY_ID ,
             MOC_PHM_CD ,
             CS_AREA_PHONE ,
             INCENTIVE_TYPE_CD ,
             date(&CHG_DT) as  GRACE_DT,
             CHG.POD_ID,
             CHG.DRG_POD_NM,
             CHG.DRG_CELL_NM,
             CHG.DRUG_ABBR_PROD_NM,
             CHG.DRUG_ABBR_DSG_NM,
             CHG.DRUG_ABBR_STRG_NM,
             CHG.ORG_FRM_STS,
             CHG.NEW_FRM_STS,			 
		     CHG.ORG_PTV_CD,                    /* N.Williams */
			 CHG.NEW_PTV_CD,                    /* N.Williams */
             clt.CLIENT_ID ,
             clt.CLIENT_NM ,
             BIRTH_DT ,
             chg.DRUG_NDC_ID ,
             CLMS.LAST_FILL_DT,
             chg.NHU_TYPE_CD ,
             BLG_REPORTING_CD ,
             PLAN_CD ,
             PLAN_EXTENSION_CD ,
             GROUP_CD ,
             GROUP_EXTENSION_CD,			 
			 CLIENT_LEVEL_1, /** 26JAN2009 N. Williams**/
			 ADJ_ENGINE      /** 26JAN2009 N. Williams**/
             FROM   &DB2_TMP..&TABLE_PREFIX._CLAIMS2   CLMS,
                    &DB2_TMP..&TABLE_PREFIX._NDC_CHG2  CHG,
                    &CLAIMSA..TBENEF_XREF_DN BNF,
                    &CLAIMSA..TCLIENT1 CLT )
  definition only not logged initially ) BY DB2;
  DISCONNECT FROM DB2;
  %reset_sql_err_cd;
  QUIT;

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
    EXECUTE(ALTER TABLE &DB2_TMP..&TABLE_PREFIX._CLAIMS3
            ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;

    EXECUTE(INSERT INTO &DB2_TMP..&TABLE_PREFIX._CLAIMS3
            SELECT
              MIN(CASE
                   WHEN INCENTIVE_TYPE_CD = 2 THEN 2
                    ELSE 1
                  END) as LTR_RULE_SEQ_NB,
              CLMS.PT_BENEFICIARY_ID,
              CLMS.MOC_PHM_CD,
              MIN(CLMS.CS_AREA_PHONE),
              MIN(INCENTIVE_TYPE_CD),
              min(date(&CHG_DT) + GRACE_DAYS DAYS),
              CHG.POD_ID,
              CHG.DRG_POD_NM,
              CHG.DRG_CELL_NM,
              CHG.DRUG_ABBR_PROD_NM,
              CHG.DRUG_ABBR_DSG_NM,
              CHG.DRUG_ABBR_STRG_NM,
              CHG.ORG_FRM_STS,
              CHG.NEW_FRM_STS,
  			  CHG.ORG_PTV_CD,                    /* N.Williams */
			  CHG.NEW_PTV_CD,                    /* N.Williams */			 
              min(CLT.CLIENT_ID),
              min(CLT.CLIENT_NM),
              min(BNF.BIRTH_DT),
              min(CLMS.DRUG_NDC_ID),
              MAX(LAST_FILL_DT),
              min(CLMS.NHU_TYPE_CD),
              min(BLG_REPORTING_CD),
              PLAN_CD,
              PLAN_EXTENSION_CD,
              GROUP_CD,
              GROUP_EXTENSION_CD,			  
			  CLIENT_LEVEL_1,                     /** 26JAN2009 N. Williams**/
			  ADJ_ENGINE
           FROM   &DB2_TMP..&TABLE_PREFIX._CLAIMS2   CLMS,
                  &DB2_TMP..&TABLE_PREFIX._NDC_CHG2  CHG,
                  &CLAIMSA..TBENEF_XREF_DN BNF,
                  &CLAIMSA..TCLIENT1 CLT
           WHERE  BNF.BENEFICIARY_ID = CLMS.PT_BENEFICIARY_ID
           AND    BNF.CLIENT_ID = CLT.CLIENT_ID
           AND    CLMS.DRUG_NDC_ID = CHG.DRUG_NDC_ID
           AND  NOT (CLMS.INCENTIVE_TYPE_CD=2 AND CHG.NEW_FRM_STS='N')
           GROUP BY
              CLMS.MOC_PHM_CD,
              CLMS.PT_BENEFICIARY_ID,
              CHG.POD_ID,
              CHG.DRG_POD_NM,
              CHG.DRG_CELL_NM,
              CHG.DRUG_ABBR_PROD_NM,
              CHG.DRUG_ABBR_DSG_NM,
              CHG.DRUG_ABBR_STRG_NM,
              CHG.ORG_FRM_STS,
              CHG.NEW_FRM_STS,
 			  CHG.ORG_PTV_CD,                     /* N.Williams */
			  CHG.NEW_PTV_CD,                     /* N.Williams */
              PLAN_CD,
              PLAN_EXTENSION_CD,
              GROUP_CD,
              GROUP_EXTENSION_CD,
              CLIENT_LEVEL_1,
              ADJ_ENGINE )
BY DB2;
%reset_sql_err_cd;

QUIT;
%set_error_fl;
%RUNSTATS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CLAIMS3);

%MEND GET_CLAIMS3 ;

*SASDOC-------------------------------------------------------------------------
| Macro call to Get_claims3 macro code. - November 2006 - N.Williams 
+-----------------------------------------------------------------------SASDOC*;
%GET_CLAIMS3;

*SASDOC-------------------------------------------------------------------------
| get counts if 0 then flag error if not then reset err_fl
+-----------------------------------------------------------------------SASDOC*;
%MACRO GET_COUNTS(TBL_NAME=,SASMACVAR=);
 %NOBS(&TBL_NAME.);
 %GLOBAL &SASMACVAR;
 %IF &nobs ne %then %do; 
    %LET ERR_FL = 0;
	%LET &SASMACVAR = %eval(&nobs);
	DATA _NULL_;
     PUT 'Resetting &ERR_FL to 0 because PROC SQL returned not an error but a warning.';
	RUN;
	%PUT &SASMACVAR ;
	%PUT &ERR_FL ;
 %end;
%MEND GET_COUNTS;
%GET_COUNTS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CLAIMS3,SASMACVAR=FRMCLMCNT);

*SASDOC-------------------------------------------------------------------------
| Get beneficiary address and create SAS file layout.
+-----------------------------------------------------------------------SASDOC*;
%CREATE_BASE_FILE(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._CLAIMS3);

*SASDOC-------------------------------------------------------------------------
| Call %check_document to see if the Stellent id(s) have been attached.
+-----------------------------------------------------------------------SASDOC*;
%check_document;

%add_client_variables(INIT_ID=&INITIATIVE_ID);


/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  add_drug_variables.sas 
|
| PROCESS:  The macro joins drug level information to SAS pending dataset.
|           Merge variables -  CLIENT_ID BENE_ID FILL_DT DRUG_NDC_ID
|           Adjudication - QL RE RX
|
+--------------------------------------------------------------------------------
|
+-----------------------------------------------------------------------HEADER*/

%macro add_drug_variables(INIT_ID=);

	%LOCAL TEMP_CLIENT_TABLE SAS_DATASET CPG_VARIABLE TEMP_COUNT TEMP_COUNT2 ;
	
	%MACRO DO_MERGE;
	%IF %SYSFUNC(EXIST(&SAS_DATASET.)) %THEN %DO;  /** START - SAS_DATASET **/
	    %PUT NOTE: &SAS_DATASET. EXISTS. ;

		%let adj_count=0;

		proc sql noprint;
		  select count(*) into: adj_count
		  from &SAS_DATASET.
		  where adj_engine='QL';
		quit;
		
		%put NOTE: QL adj_count = &adj_count. ;

		%IF %SYSFUNC(EXIST(&QL_DRUG_TABLE.)) AND &ADJ_COUNT. NE 0 %THEN %DO; /** START - QL **/
			%PUT NOTE: &QL_DRUG_TABLE. EXISTS. ;

			PROC SQL NOPRINT;
			  CREATE TABLE &TEMP_SAS_DATASET. AS
			  SELECT 
					
					 A.PT_BENEFICIARY_ID    AS &VAR_MERGE.,  
					 A.CLIENT_ID		    AS CLIENT_ID, 
					 A.LAST_FILL_DT         AS LAST_FILL_DT,
					 A.LAST_FILL_DT         AS LAST_FILL_DT2,
					 A.DRUG_NDC_ID          AS DRUG_NDC_ID,
           			 B.DGH_GCN_CD           AS GCN_CODE,
					 A.RX_NB                AS RX_NB2,
					 A.CALC_BRAND_CD        AS CALC_BRAND_CD2,					  					 
					 A.DAY_SUPPLY_QY        AS DAY_SUPPLY_QY2,
					 A.DELIVERY_SYSTEM_CD   AS DELIVERY_SYSTEM_CD2,
					 A.DISPENSED_QY         AS DISPENSED_QY2,
			                 trim(gpi_group)||trim(gpi_class)||trim(gpi_subclass)||
                                           trim(gpi_name)||trim(gpi_name_extension)||trim(gpi_form)||
                                           trim(gpi_strength) as GPI142 format $20., 
					 B.GENERIC_AVAIL_IN  as GENERIC_AVAIL_IN2,
					 B.DRUG_BRAND_CD     as DRUG_BRAND_CD2	
			  FROM &QL_DRUG_TABLE. A LEFT JOIN
			       CLAIMSA.TDRUG1  B
			  ON A.DRUG_NDC_ID=B.DRUG_NDC_ID;
			QUIT; 

			data &TEMP_SAS_DATASET. ; 
			  set &TEMP_SAS_DATASET. ; 
			  delivery_system2=put(left(DELIVERY_SYSTEM_CD2),2.); 
			run;

			%LET TEMP_COUNT = 0;

			PROC SQL NOPRINT;
			  SELECT COUNT(*) INTO : TEMP_COUNT
			  FROM &TEMP_SAS_DATASET. ;
			QUIT;

			%PUT NOTE: TEMP_COUNT = &TEMP_COUNT. ;

			%IF &TEMP_COUNT. NE 0 %THEN %DO;

				PROC SORT DATA = &TEMP_SAS_DATASET.  ;   
				BY CLIENT_ID &VAR_MERGE. DRUG_NDC_ID descending LAST_FILL_DT2 ;
				RUN;

				PROC SORT DATA = &TEMP_SAS_DATASET. 
                OUT = LAST_DRUG (KEEP = CLIENT_ID &VAR_MERGE. DRUG_NDC_ID LAST_FILL_DT2 DELIVERY_SYSTEM_CD2)
                NODUPKEY ;  
				/** NEED NODUPKEY DUE TO SAME DRUGS FILLED ON MULTI DAY - KEEP ONE **/
				BY CLIENT_ID &VAR_MERGE. DRUG_NDC_ID ;
				RUN; 

				PROC SORT DATA = &TEMP_SAS_DATASET. NODUPKEY ;  
				  /** NEED NODUPKEY DUE TO MULTI DRUGS FILLED ON SAME DAY - KEEP ONE **/
				  BY CLIENT_ID &VAR_MERGE. LAST_FILL_DT DRUG_NDC_ID;
				RUN;

				PROC SORT DATA = &SAS_DATASET. ;
				  BY CLIENT_ID &VAR_MERGE. LAST_FILL_DT DRUG_NDC_ID;
				RUN;

				DATA  &SAS_DATASET. ;
				  MERGE &SAS_DATASET.        (IN=A)
					    &TEMP_SAS_DATASET.   (IN=B);
				  BY CLIENT_ID &VAR_MERGE. LAST_FILL_DT DRUG_NDC_ID;
				  IF A;
				  IF A AND B THEN DO; 
					 RX_NB              = RX_NB2;
					 DRUG_BRAND_CD      = DRUG_BRAND_CD2;
					 CALC_BRAND_CD      = CALC_BRAND_CD2;  
					 DAY_SUPPLY_QY      = DAY_SUPPLY_QY2;
					 DELIVERY_SYSTEM    = DELIVERY_SYSTEM2; 
					 DISPENSED_QY       = DISPENSED_QY2; 
			     GPI14              = GPI142 ; 
					 GENERIC_AVAIL_IN   = GENERIC_AVAIL_IN2; 
				  END;
				  DROP RX_NB2 DRUG_BRAND_CD2 CALC_BRAND_CD2  DAY_SUPPLY_QY2 DELIVERY_SYSTEM_CD2 DELIVERY_SYSTEM2
                       DISPENSED_QY2 GPI142 GENERIC_AVAIL_IN2 LAST_FILL_DT2;
				RUN;

				PROC SORT DATA = &SAS_DATASET. ;
				  BY CLIENT_ID &VAR_MERGE. DRUG_NDC_ID;
				RUN;

				DATA  &SAS_DATASET. ;
				  MERGE &SAS_DATASET.        (IN=A)
					    LAST_DRUG   (IN=B);
				  BY CLIENT_ID &VAR_MERGE. DRUG_NDC_ID ;
				  IF A;
				  IF A AND B THEN DO;   
					 IF LAST_DELIVERY_SYS=. THEN LAST_DELIVERY_SYS=DELIVERY_SYSTEM_CD2;
					 LAST_FILL_DT       = LAST_FILL_DT2;
				  END;
				  DROP DELIVERY_SYSTEM_CD2 LAST_FILL_DT2;
				RUN;
	
			%END;

		%END;  /** END - QL **/


		%let adj_count=0;

		proc sql noprint;
		  select count(*) into: adj_count
		  from &SAS_DATASET.
		  where adj_engine NE 'QL';
		quit;
		
		%put NOTE: RE RX adj_count = &adj_count. ;

		%IF (%SYSFUNC(EXIST(&RE_DRUG_TABLE.)) OR 
            %SYSFUNC(EXIST(&RX_DRUG_TABLE.))) AND &ADJ_COUNT. NE 0 %THEN %DO; /** START - RE RX **/
			%PUT NOTE: &RE_DRUG_TABLE. OR &RX_DRUG_TABLE. EXISTS. ;

			%IF %SYSFUNC(EXIST(&RE_DRUG_TABLE.)) %THEN %DO;
				PROC SQL NOPRINT;
				  CREATE TABLE TEMP_RE AS
				  SELECT 
						 A.PT_BENEFICIARY_ID    AS &VAR_MERGE.,  
						 A.CLIENT_ID		    AS CLIENT_ID, 
						 A.LAST_FILL_DT         AS LFD, 
						 A.DRUG_NDC_ID          AS DRUG_NDC_ID, 
             A.DGH_GCN_CD               AS GCN_CODE
						 A.RX_NB                AS RX_NB2,
						 A.MBR_ID               AS MBR_ID2,
						 A.DRUG_BRAND_CD        AS DRUG_BRAND_CD2,						 					 
						 A.DAY_SUPPLY_QY        AS DAY_SUPPLY_QY2,
						 A.DELIVERY_SYSTEM_CD   AS DELIVERY_SYSTEM_CD2, 
						 A.DISPENSED_QY         AS DISPENSED_QY2,
				                 trim(gpi_group)||trim(gpi_class)||trim(gpi_subclass)||
	                                           trim(gpi_name)||trim(gpi_name_extension)||trim(gpi_form)||
	                                           trim(gpi_strength) as GPI142 format $20., 
						 B.GENERIC_AVAIL_IN as GENERIC_AVAIL_IN2			
				  FROM &RE_DRUG_TABLE. A LEFT JOIN
				       CLAIMSA.TDRUG1  B
				  ON A.DRUG_NDC_ID=B.DRUG_NDC_ID;
				QUIT; 
			%END;
			%IF %SYSFUNC(EXIST(&RX_DRUG_TABLE.)) %THEN %DO;
				PROC SQL NOPRINT;
				  CREATE TABLE TEMP_RX AS
				  SELECT 
						  
						 A.PT_BENEFICIARY_ID    AS &VAR_MERGE.,  
						 A.CLIENT_ID		    AS CLIENT_ID, 
						 A.LAST_FILL_DT         AS LFD, 
						 A.DRUG_NDC_ID          AS DRUG_NDC_ID, 
             A.DGH_GCN_CD               AS GCN_CODE
						 A.RX_NB                AS RX_NB2,
						 A.MBR_ID               AS MBR_ID2,
						 A.DRUG_BRAND_CD        AS DRUG_BRAND_CD2,						 					 
						 A.DAY_SUPPLY_QY        AS DAY_SUPPLY_QY2,
						 A.DELIVERY_SYSTEM_CD   AS DELIVERY_SYSTEM_CD2,
						 A.RX_COUNT_QY          AS DISPENSED_QY2,
				                 trim(gpi_group)||trim(gpi_class)||trim(gpi_subclass)||
	                                           trim(gpi_name)||trim(gpi_name_extension)||trim(gpi_form)||
	                                           trim(gpi_strength) as GPI142 format $20., 
						 B.GENERIC_AVAIL_IN as GENERIC_AVAIL_IN2		
				  FROM &RX_DRUG_TABLE. A LEFT JOIN
				       CLAIMSA.TDRUG1  B
				  ON A.DRUG_NDC_ID=B.DRUG_NDC_ID;
				QUIT; 
			%END;

			DATA &TEMP_SAS_DATASET. ;
			  SET
			  %IF %SYSFUNC(EXIST(&RE_DRUG_TABLE.)) %THEN %DO;
			    TEMP_RE
			  %END;
			  %IF %SYSFUNC(EXIST(&RX_DRUG_TABLE.)) %THEN %DO;
			    TEMP_RX
			  %END;;
			RUN;

			data &TEMP_SAS_DATASET. ;
			  format last_fill_dt last_fill_dt2 mmddyy10. ;
			  set &TEMP_SAS_DATASET. ;
			  prescriber_id=prescriber_id2*1;
			  last_fill_dt=input(LFD,yymmdd10.);
			  last_fill_dt2=last_fill_dt;
			  delivery_system2=put(left(DELIVERY_SYSTEM_CD2),2.);
			  drop LFD prescriber_id2;
			run;

			%LET TEMP_COUNT = 0;

			PROC SQL NOPRINT;
			  SELECT COUNT(*) INTO : TEMP_COUNT
			  FROM &TEMP_SAS_DATASET. ;
			QUIT;

			%PUT NOTE: TEMP_COUNT = &TEMP_COUNT. ;

			%IF &TEMP_COUNT. NE 0 %THEN %DO;

				PROC SORT DATA = &TEMP_SAS_DATASET.  ;   
				BY CLIENT_ID &VAR_MERGE. DRUG_NDC_ID descending LAST_FILL_DT2 ;
				RUN;

				PROC SORT DATA = &TEMP_SAS_DATASET. 
                OUT = LAST_DRUG (KEEP = CLIENT_ID &VAR_MERGE. DRUG_NDC_ID LAST_FILL_DT2 DELIVERY_SYSTEM_CD2)
                NODUPKEY ;  
				/** NEED NODUPKEY DUE TO SAME DRUGS FILLED ON MULTI DAY - KEEP ONE **/
				BY CLIENT_ID &VAR_MERGE. DRUG_NDC_ID ;
				RUN; 

				PROC SORT DATA = &TEMP_SAS_DATASET. NODUPKEY ;  
				  /** NEED NODUPKEY DUE TO MULTI DRUGS FILLED ON SAME DAY - KEEP ONE **/
				  BY CLIENT_ID &VAR_MERGE. LAST_FILL_DT DRUG_NDC_ID;
				RUN;

				PROC SORT DATA = &SAS_DATASET. ;
				  BY CLIENT_ID &VAR_MERGE. LAST_FILL_DT DRUG_NDC_ID;
				RUN;

				DATA  &SAS_DATASET. ; 
				  MERGE &SAS_DATASET.        (IN=A)
					    &TEMP_SAS_DATASET.   (IN=B);
				  BY CLIENT_ID &VAR_MERGE. LAST_FILL_DT DRUG_NDC_ID;
				  IF A;
				  IF A AND B THEN DO; 
					 RX_NB              = RX_NB2;
					 DRUG_BRAND_CD      = DRUG_BRAND_CD2;
					 IF DRUG_BRAND_CD2  = 'G' THEN CALC_BRAND_CD =0;
					 ELSE IF DRUG_BRAND_CD2 = 'B' AND GENERIC_AVAIL_IN2=1 THEN CALC_BRAND_CD =2;
					 ELSE IF DRUG_BRAND_CD2 = 'B' THEN CALC_BRAND_CD =1; 
					 DAY_SUPPLY_QY      = DAY_SUPPLY_QY2;
					 DELIVERY_SYSTEM    = DELIVERY_SYSTEM2; 
					 DISPENSED_QY       = DISPENSED_QY2;
					 IF MBR_ID='' THEN  MBR_ID=MBR_ID2;
			         GPI14              = GPI142 ; 
                     GENERIC_AVAIL_IN   = GENERIC_AVAIL_IN2; 
				  END;
				  DROP RX_NB2 DRUG_BRAND_CD2 DAY_SUPPLY_QY2 DELIVERY_SYSTEM_CD2 DELIVERY_SYSTEM2 MBR_ID2
                       DISPENSED_QY2 GPI142 GENERIC_AVAIL_IN2 LAST_FILL_DT2;
				RUN;

				PROC SORT DATA = &SAS_DATASET. ;
				  BY CLIENT_ID &VAR_MERGE. DRUG_NDC_ID;
				RUN;

				DATA  &SAS_DATASET. ;
				  MERGE &SAS_DATASET.        (IN=A)
					    LAST_DRUG   (IN=B);
				  BY CLIENT_ID &VAR_MERGE. DRUG_NDC_ID ;
				  IF A;
				  IF A AND B THEN DO;   
					 IF LAST_DELIVERY_SYS=. THEN LAST_DELIVERY_SYS=DELIVERY_SYSTEM_CD2;
					 LAST_FILL_DT       = LAST_FILL_DT2;
				  END;
				  DROP DELIVERY_SYSTEM_CD2 LAST_FILL_DT2;
				RUN;
	
			%END;

		%END;  /** END - RE RX **/

	%END;  /** END SAS_DATASET **/
	%ELSE %DO;
	  %PUT NOTE: &SAS_DATASET. DOES NOT EXISTS. ;
	%END;

	%MEND DO_MERGE;

	/*** PARTICIPANT DATASET  ***********************************************/
	%LET TEMP_CLIENT_TABLE=%STR(QCPAP020.ADD_DRUG_VARIABLES_&INIT_ID.); 
	%LET SAS_DATASET=%STR(DATA_PND.T_&INIT_ID._&PHASE_SEQ_NB._1);
	%LET TEMP_SAS_DATASET=%STR(DRUG_VARIABLES);
	%LET VAR_MERGE=RECIPIENT_ID;

	%LET QL_DRUG_TABLE=%STR(&DB2_TMP..&TABLE_PREFIX._QL_DRUG); 
	%LET RE_DRUG_TABLE=%STR(DSS_HERC.CLAIMS_PULL_&INIT_ID._RE);
	%LET RX_DRUG_TABLE=%STR(DSS_HERC.CLAIMS_PULL_&INIT_ID._RX);
	%DO_MERGE;

%mend add_drug_variables;

%add_drug_variables(INIT_ID=&INITIATIVE_ID);


*SASDOC-------------------------------------------------------------------------
| Check for autorelease of file.
+-----------------------------------------------------------------------SASDOC*;
%AUTORELEASE_FILE(INIT_ID=&INITIATIVE_ID, PHASE_ID=&PHASE_SEQ_NB);

*SASDOC-------------------------------------------------------------------------
| Generate the Client Initiative Summary report.
+-----------------------------------------------------------------------SASDOC*;
%include "/herc&sysmode/prg/hercules/reports/client_initiative_summary.sas";
%client_initiative_summary;

*SASDOC-------------------------------------------------------------------------
| Drop the temporary UDB tables
+-----------------------------------------------------------------------SASDOC*;

/*%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._NDC_CHG);*/
/*%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._NDC_CHG2);*/
/*%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS);*/
/*%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS2);*/
/*%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CLAIMS3);*/
/*%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._CPG);*/
/*%drop_db2_table(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CPG_MOC);*/
/*%drop_db2_table(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._NDC_Y_Z);*/
/*%drop_db2_table(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._NDC_X_N);*/
/*%drop_db2_table(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._NDC_N);*/
/*%drop_db2_table(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._NDC_X);*/
/*%drop_db2_table(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._NDC_ALT);*/
/*%drop_db2_table(tbl_name=&DB2_TMP..&TABLE_PREFIX._NDC); */

%put _all_;

*SASDOC-------------------------------------------------------------------------
| Update the job complete timestamp.
+-----------------------------------------------------------------------SASDOC*;
%update_task_ts(job_complete_ts);


*SASDOC-------------------------------------------------------------------------
| Insert distinct recipients into TCMCTN_PENDING if the file is not autorelease.
| The user will receive an email with the initiative summary report.  If the
| file is autoreleased, %release_data is called and no email is generated from
| %insert_tcmctn_pending.
+-----------------------------------------------------------------------SASDOC*;
%insert_tcmctn_pending(init_id=&initiative_id, phase_id=&phase_seq_nb);

%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative Id &INITIATIVE_ID");

*SASDOC------------------------------------------------------------------------
| Generate the Cell/Pod/drug patient count report. Pass org_frm_sts to represent
| the current formulary status on the report.
+----------------------------------------------------------------------SASDOC*;
%cell_pod_drg_pt(IN_TBL=DATA_PND.&TABLE_PREFIX._1, CURR_FRM_STS=ORG_FRM_STS);

*SASDOC-------------------------------------------------------------------------
| Generate the Client/Cell-Pod/Drug/Patient count report.  Pass column new_frm_sts to
| populate the flag field on the report.
+-----------------------------------------------------------------------SASDOC*;
%clt_cellpod_drg_pt(IN_TBL=DATA_PND.&TABLE_PREFIX._1, FRM_STS=NEW_FRM_STS);

*SASDOC-------------------------------------------------------------------------
| Generate the Client/Plan-Group/Patient count report.  First summarize the
| data to pass in to the report.
+-----------------------------------------------------------------------SASDOC*;
%clt_brc_plngrp_pt(IN_TBL=DATA_PND.&TABLE_PREFIX._1);

*SASDOC-------------------------------------------------------------------------
| Generate the Client/Plan Design/Patient Count report
+-----------------------------------------------------------------------SASDOC*;
%clt_plndgn_pt(IN_TBL=DATA_PND.&TABLE_PREFIX._1);

%on_error(ACTION=ABORT, EM_TO=&primary_programmer_email,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered in Cell POD reports.  See LOG file - &PROGRAM_NAME..log for Initiative Id &INITIATIVE_ID");
