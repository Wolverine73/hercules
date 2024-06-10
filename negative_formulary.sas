%include '/user1/qcpap020/autoexec_new.sas';
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  NEGATIVE_FORMULARY.SAS
|
| LOCATION: /hercprod/prg/hercules/5246
|
| PURPOSE:  Notifies Med D participants about changes in there formulary plan.
|
| LOGIC:	(1) Determine current environment.
|		    (2) Define a standard environment and common parameters for Hercules
|               Communication Engine programs.
|		    (3) Set email parameters for error checking. 
|		    (4) Update the job start timestamp.
|		    (5) Client Setup - Retrieve all the targeted client hierarchy structure 
|               applicable by adjudication engine (QL/Recap/Rxclaim) that are to be 
|               included in the mailing.
|		    (6) Drug Setup(Adhoc) - Retrieve the target drugs that where identified for the
|               mailing. Run adhoc drug setup code see negfrmdrugsetup.sas and adhoc
|               drug list to be supplied by Client Ops and/or business user.
|		    (7) Claims Dates Range - Set GLOBAL Macro Variables for Claims date range.
|		    (8) Pull Claims EDW - Pull claims for Recap/Rxclaim based on client setup & drug
|               setup. This is a customed claims pull edw defined here for negative formulary
|               mailing program it pull a few additional fields (formulary_number, language code). 
|		    (9) Process Step Macro - Performs the Post Processing after claim pull. This includes
|               summarize of claims data,  remove duplicate benes/mbrs, adding mail order pharmacy
|               code. 
|		    (10) Eligibility - Perform standard eligibility check and omit these participants.
|		    (11) Process1 Step Macro - Downloads QL and EDW Data to Unix in the format of a SAS Dataset
|                for each adjudiction engine. 
|		    (12) Combine Adjudication - The logic in the macro combines the claims that were pulled for
|                all three adjudications. 
|		    (13) Create Base File - This macro creates the standard SAS datasets in both the pending and
|                results directories beneath the appropriate HERCULES Program.
|		    (14) Check Document - This macro updates apn_cmctn_ids to the standard SAS datasets waiting 
|                in the results and pending directories
|		    (15) Autorelease File - This macro checks for default conditions that will cause for standard  
|                SAS dataset in pending directory to be file release
|		    (16) Drop the temporary UDB & EDW tables created during the running of this mailing program. 
|		    (17) Insert Communication Pendign - This macro inserts data records for distinct recipients into 
|                hercules.tcmctn_pending to be used later to update communication history once the mailing 
|                request initiative has been released as final.
|           (18) Update Task Timestamp - Update Job completion timestamp.
|           (19) Email Job Completion and counts of data.
|
| 10.27.2009 - check this use the identify_drug_therpy code so that that its structured with claim_call 
|              and then process call etc.
|
| INPUT:    UDB TABLES FOR QL Data.
|           EDW TABLES FOR Recap/RxClaim Data.
|
| OUTPUT:   STANDARD SAS DATASETS IN /RESULTS AND /PENDING DIRECTORIES
|
| USAGE:    sasprogram(DEV);
|
+--------------------------------------------------------------------------------
| HISTORY:  07MAR2008 - N.WILLIAMS   - HERCULES VERSION  2.1.2.01 
|                                    - Original.
|           29JAN2010 -  N.WILLIAMS  - HERCULES VERSION  2.1.2.02
|                                    - New Requirement Add fields CMS Plan Id, CMS Contract ID.
|           18FEB2010 -  N.WILLIAMS  - HERCULES VERSION  2.1.2.03
|                                    - Added in EOB removal logic. Note EOB client
|                                      may need to be updated for each run of this 
|                                      mailing based on business requestors implementation
|                                      form.
|           07JUL2010 -  N.WILLIAMS  - HERCULES VERSION  2.1.2.04
|                                    - Two New Business Requirements
|                                      1. Provide a list of all Ppts records removed by the EOB filter. 
|                                      2. Provide a list of all Data quality 3 records. 
|
|           17JUN2013 -  S.BILETSKY  - As part of hercules stabilization
|                                    	logic was re-written since Negative Formulary was never 
|                                      	promoted to production correctly before. 
|                                       
+------------------------------------------------------------------------HEADER*/


%set_sysmode;

/*options sysparm='initiative_id=8367 phase_seq_nb=1 HSC_USR_ID=QCPI208';*/
%INCLUDE "/herc&sysmode/prg/hercules/hercules_in.sas";

/*options fullstimer mprint mlogic symbolgen source2 mprintnest mlogicnest;*/
options mprint mlogic;

%LET DEBUG_FLAG = Y;
%LET ERR_FL=0;
%LET PROGRAM_NAME=negative_formulary;

*SASDOC----------------------------------------------------------------------
| SET THE PARAMETERS FOR ERROR CHECKING
+---------------------------------------------------------------------SASDOC*;
PROC SQL NOPRINT;
  SELECT QUOTE(TRIM(EMAIL)) INTO :PRIMARY_PROGRAMMER_EMAIL SEPARATED BY ' '
  FROM ADM_LKP.ANALYTICS_USERS
  WHERE UPCASE(QCP_ID) IN ("&HSC_USR_ID");
QUIT;

%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative ID &Initiative_ID");

*SASDOC-------------------------------------------------------------------------
| UPDATE_TASK_TS - Update the job start timestamp.
+-----------------------------------------------------------------------SASDOC*;
%UPDATE_TASK_TS(JOB_START_TS);


*SASDOC--------------------------------------------------------------------------
| RESOLVE_CLIENT - RETRIEVE ALL CLIENT IDS THAT ARE INCLUDED IN THE MAILING.  IF 
| A CLIENT IS PARTIAL, THIS WILL BE HANDLED AFTER DETERMINING CURRENT ELIGIBILITY.
+------------------------------------------------------------------------SASDOC*;
/*%let DSPLY_CLT_SETUP_CD=1; ** NCW 10.16.2009 - Setting this here to get client setup how I want;*/
%RESOLVE_CLIENT(TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CLT_CPG_QL,
                TBL_NAME_OUT_RX=&ORA_TMP..&TABLE_PREFIX._CLT_CPG_RX,
                TBL_NAME_OUT_RE=&ORA_TMP..&TABLE_PREFIX._CLT_CPG_RE) ;


*SASDOC--------------------------------------------------------------------------
| CALL %GET_NDC TO DETERMINE THE MAINTENANCE NDCS
+------------------------------------------------------------------------SASDOC*;
/* Run adhoc drug setup code. see negfrmdrugsetup.sas or drugsetup.sas in project*/
/*%include "/PRG/sas&sysmode.1/hercules/5246/negfrmdrugsetup.sas";*/
%GET_NDC(DRUG_NDC_TBL=&DB2_TMP..&TABLE_PREFIX._NDC_QL,
         DRUG_NDC_TBL_RX=&ORA_TMP..&TABLE_PREFIX._NDC_RX,
         DRUG_NDC_TBL_RE=&ORA_TMP..&TABLE_PREFIX._NDC_RE );

%MACRO CLAIMS_DATES_RANGE;

	%IF &RX_ADJ EQ 1 or &RE_ADJ EQ 1 %THEN %DO;
		%GLOBAL CLM_BEGIN_DT CLM_END_DT;
		PROC SQL noprint;
			SELECT  "'" || put(datepart(CLAIM_BEGIN_DT),yymmddd10.) || "'",
					"'" || put(datepart(CLAIM_END_DT),yymmddd10.) || "'"
			INTO    :CLM_BEGIN_DT,
					:CLM_END_DT
			FROM    &ORA_TMP..&TABLE_PREFIX._RVW_DATES;          
		QUIT;
		%PUT NOTE: CLM_BEGIN_DT = &CLM_BEGIN_DT. ;
		%PUT NOTE: CLM_END_DT   = &CLM_END_DT. ;   
	%END;
%MEND CLAIMS_DATES_RANGE;
%CLAIMS_DATES_RANGE;


*SASDOC--------------------------------------------------------------------------
| RETRIEVE THE CLAIM DATA - RXCLM OR RECAP 
+------------------------------------------------------------------------SASDOC*;
%MACRO CLAIM_CALL;
	%IF &RX_ADJ =1 OR &RE_ADJ =1 %THEN %DO;
		*SASDOC--------------------------------------------------------------------------
		| CALL CLAIMS_PULL_EDW MACRO IN ORDER TO PULL CLAIMS INFORMATION FROM EDW.
		+------------------------------------------------------------------------SASDOC*;
		%CLAIMS_PULL_EDW_NEGFRM (DRUG_NDC_TABLE_RX =&ORA_TMP..&TABLE_PREFIX._NDC_RX, 
								 DRUG_NDC_TABLE_RE = &ORA_TMP..&TABLE_PREFIX._NDC_RE, 
								 RESOLVE_CLIENT_TABLE_RX = &ORA_TMP..&TABLE_PREFIX._CLT_CPG_RX,				 
								 RESOLVE_CLIENT_TABLE_RE = &ORA_TMP..&TABLE_PREFIX._CLT_CPG_RE  );

	%END; 
%MEND CLAIM_CALL ;
%CLAIM_CALL;



%MACRO EOB_PROCESS (ADJ_ENGINE=);

		data _null_;
			begin_date = input("&EOB_BEGIN_DT", date9.);
			end_date = input("&EOB_END_DT", date9.);
  			CALL SYMPUT('EOB_BEGIN_DT_ORCL',"'" || PUT(begin_date, yymmdd10.) || "'"); 
    		CALL SYMPUT('EOB_END_DT_ORCL',"'" || PUT(end_date, yymmdd10.) || "'"); 
		run;

		%PUT &EOB_BEGIN_DT_ORCL;
		%PUT &EOB_END_DT_ORCL;

		%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..EOB_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.);


		PROC SQL;
				CONNECT TO ORACLE(PATH=&GOLD. PRESERVE_COMMENTS);
				EXECUTE
		(CREATE TABLE &ORA_TMP..EOB_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. AS

   			SELECT	%BQUOTE(/)%BQUOTE(*)+ ORDERED full(clt) use_hash(claim) full(claim)  use_nl(mbr) index(mbr x_mbr_n17) 
                    pq_distribute(claim hash hash) %BQUOTE(*)%BQUOTE(/)

           	%BQUOTE(')&ADJ_ENGINE.%BQUOTE(')	        AS ADJ_ENGINE,
            MBR.MBR_ID      	    AS MBR_ID,
            CLT.ALGN_LVL_GID_KEY,
            CLT.EXTNL_LVL_ID1       AS CLIENT_LEVEL_1,
            CLT.EXTNL_LVL_ID2       AS CLIENT_LEVEL_2,
            CLT.EXTNL_LVL_ID3       AS CLIENT_LEVEL_3,
            MAX (CLAIM.DSPND_DATE)  AS MAX_DSPND_DT,
            MAX (CLAIM.CLAIM_GID)   AS MAX_CLAIM_GID
            
      	 	FROM DSS_CLIN.V_ALGN_LVL_DENORM CLT,
				DSS_CLIN.V_CLAIM_CORE_PAID CLAIM,
				DSS_CLIN.V_MBR MBR
			
      		WHERE CLAIM.DSPND_DATE BETWEEN &EOB_BEGIN_DT_ORCL AND &EOB_END_DT_ORCL
/*			AND CLAIM.BATCH_DATE BETWEEN &EOB_BEGIN_DT_ORCL AND &EOB_END_DT_ORCL            */
            AND CLAIM.SRC_SYS_CD = 'X'
            AND MBR.PAYER_ID < 100000
            AND CLAIM.CLAIM_WSHD_CD IN ('P', 'W')
            AND CLAIM.BATCH_DATE IS NOT NULL
            AND (CLAIM.MBR_SUFFX_FLG = 'Y' OR CLAIM.MBR_SUFFX_FLG IS NULL)
            AND CLAIM.QL_VOID_IND <= 0
            AND (CLT.EXTNL_LVL_ID1 IN
                    ('8561',
                     '8700',
                     '8750',
                     '4234',
                     '4236',
                     '4237',
                     '1005',
                     '8572',
                     '8710',
                     '8576',
                     '1307',
                     '1310',
                     '1201',
                     '8725',
                     '8735',
                     '8561',
                     '8562',
                     '8563',
                     '8564',
                     '8565',
                     '8566',
                     '8567',
                     '8577',
                     '9094',
                     '9095',
                     '9096',
                     '9097',
                     '9098',
                     '9099',
                     '5015',
                     '5027')
                 OR (CLT.EXTNL_LVL_ID1 BETWEEN '9100' AND '9199')
                 OR (CLT.EXTNL_LVL_ID1 BETWEEN '9400' AND '9420')
                 OR (CLT.EXTNL_LVL_ID1 = '8578'
                     AND CLT.EXTNL_LVL_ID3 IN
                            ('PHCVNS 01', 'PHCVNS 02', 'PHCVNS 03', 'PHCVNS 04')))
            AND CLAIM.ALGN_LVL_GID = CLT.ALGN_LVL_GID_KEY
            AND CLAIM.MBR_GID = MBR.MBR_GID
			AND CLAIM.PAYER_ID = MBR.PAYER_ID
            
   			GROUP BY MBR.MBR_ID,
            CLT.ALGN_LVL_GID_KEY,
            CLT.EXTNL_LVL_ID1,
            CLT.EXTNL_LVL_ID2,
            CLT.EXTNL_LVL_ID3
            
/*   ORDER BY MBR.MBR_ID*/
			) BY ORACLE;
				DISCONNECT FROM ORACLE;
		QUIT;


		%IF %SYSFUNC(EXIST(&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.))  %THEN %DO;
		
/*			MAKE BKUP OF CLAIMS TABLE BEFORE REMOVING MEMBERS*/
			DATA &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE._B4_EOB ;
				SET &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.;
			RUN; 

			%PUT:  NOTE: EOB_ELIMQRYS - Table &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. exists ;

			%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..EOB_MBRS_REMOVED_&INITIATIVE_ID._&ADJ_ENGINE.);


			PROC SQL;
				CONNECT TO ORACLE(PATH=&GOLD. PRESERVE_COMMENTS);
				EXECUTE
				(
					CREATE TABLE &ORA_TMP..EOB_MBRS_REMOVED_&INITIATIVE_ID._&ADJ_ENGINE. AS
					SELECT DISTINCT A.MBR_ID, A.DRUG_NDC_ID 
					FROM &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. A
					WHERE A.MBR_ID IN (SELECT B.MBR_ID 
						FROM &ORA_TMP..EOB_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. B)
				 ) 	
			 BY ORACLE;
			 DISCONNECT FROM ORACLE;
			QUIT;

/*			PROC SQL;*/
/*				CONNECT TO ORACLE(PATH=&GOLD. PRESERVE_COMMENTS);*/
/*				EXECUTE*/
/*				(*/
/*					CREATE TABLE &ORA_TMP..EOB_MBRS_REMOVED_&INITIATIVE_ID._&ADJ_ENGINE. AS*/
/*					SELECT MBR_ID FROM &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.*/
/*					INTERSECT */
/*					SELECT MBR_ID FROM &ORA_TMP..EOB_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.*/
/*				 ) 	*/
/*			 BY ORACLE;*/
/*			 DISCONNECT FROM ORACLE;*/
/*			QUIT;*/

		%END;
		%ELSE %DO;
			%PUT:  NOTE: EOB_ELIMQRYS - Table &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE. does not exists ;
		%END;


		PROC SQL;
			CONNECT TO ORACLE (PATH=&GOLD.);
			 EXECUTE (delete from DSS_HERC.CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.
					  where MBR_ID in 
					( SELECT  MBR_ID  FROM &ORA_TMP..EOB_CLAIMS_PULL_&INITIATIVE_ID._&ADJ_ENGINE.  ) )	
			 BY ORACLE;
			 DISCONNECT FROM ORACLE;
		QUIT;

%MEND EOB_PROCESS;


%MACRO RUN_EOB_PROCESS;

	PROC SQL;
		SELECT EOB_INDICATOR, EOB_BEGIN_DT, EOB_END_DT 
		INTO :EOB_INDICATOR, :EOB_BEGIN_DT, :EOB_END_DT
		FROM QCPAP020.TEOB_FILTER_DTL
		WHERE INITIATIVE_ID = &INITIATIVE_ID;

	QUIT;

		%put note: EOB_INDICATOR = &EOB_INDICATOR;
		%put note: EOB_BEGIN_DT = &EOB_BEGIN_DT;
		%put note: EOB_END_DT = &EOB_END_DT;

	%IF &EOB_INDICATOR. = 1 %THEN %DO; *if EOB indicator enabled;
		%IF &RX_ADJ EQ 1 %THEN %DO;
			%EOB_PROCESS(ADJ_ENGINE=RX);
		%END;
		%IF &RE_ADJ EQ 1 %THEN %DO;
			%EOB_PROCESS(ADJ_ENGINE=RE);
    	%END; 
	%END;
%MEND RUN_EOB_PROCESS;

%RUN_EOB_PROCESS;

*SASDOC --------------------------------------------------------------------
| CALL %RX_RE_PROCESS
| IDENTIFY THE RETAIL MAINTENANCE RX/RE CLAIMS DURING THE LAST &POS_REVIEW_DAYS
| WHO HAVE NOT FILLED ANY SCRIPTS AT MAIL DURING THE LAST 90 DAYS.
+--------------------------------------------------------------------SASDOC*;
%MACRO RX_RE_PROCESS(TBL_NM_RX_RE, INPT_TBL_RX_RE, EDW_ADJ,CLAIMS_TBL, TBL_NM_RX_RE2,MODULE2);

	%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..CLAIMS3_PULL_&INITIATIVE_ID._&MODULE2.);

	PROC SQL;
	CONNECT TO ORACLE(PATH=&GOLD);             
	EXECUTE	(
	CREATE TABLE &ORA_TMP..CLAIMS3_PULL_&INITIATIVE_ID._&MODULE2. AS
	SELECT 
	 %BQUOTE(/)%BQUOTE(*)+ ordered  use_nl(v) use_nl(b) %BQUOTE(*)%BQUOTE(/)
		DISTINCT
	   CLAIM.MBR_GID		,
	   CLAIM.PAYER_ID		,
	   CLAIM.ALGN_LVL_GID_KEY	,
	   CLAIM.PT_BENEFICIARY_ID 	,
	   CLAIM.MBR_ID			,
	   CLAIM.CDH_BENEFICIARY_ID 	,
	   CLAIM.CLIENT_ID		,
	   CLAIM.CLIENT_LEVEL_1         ,
	   CLAIM.CLIENT_LEVEL_2         ,
	   CLAIM.CLIENT_LEVEL_3         ,
	   CLAIM.CLIENT_NM         	,
	   MAX(CLAIM.ADJ_ENGINE)	AS ADJ_ENGINE,
	   MAX(CLAIM.BIRTH_DT)      AS BIRTH_DT,
	   MAX(CLAIM.LAST_FILL_DT)  AS LAST_FILL_DT,   
	   MAX(CLAIM.DRUG_NDC_ID) 	AS DRUG_NDC_ID,
	   MAX(CLAIM.NHU_TYPE_CD) 	AS NHU_TYPE_CD,
	   CLAIM.DRUG_ABBR_DSG_NM  	 ,
	   CLAIM.DRUG_ABBR_PROD_NM 	 ,
	   CLAIM.DRUG_ABBR_STRG_NM 	 ,
	   CLAIM.DRUG_BRAND_CD     	 ,
	   MAX(CLAIM.REFILL_FILL_QY) 	AS REFILL_FILL_QY,
	   MAX(LTR_RULE_SEQ_NB)   	 as LTR_RULE_SEQ_NB,
	   CLAIM.MBR_FIRST_NM      	 ,
	   CLAIM.MBR_LAST_NM       	 ,
	   CLAIM.ADDR_LINE1_TXT    	 ,
	   CLAIM.ADDR_LINE2_TXT    	 ,
	   CLAIM.ADDR_CITY_NM      	 ,
	   CLAIM.ADDR_ST_CD        	 ,
	   CLAIM.ADDR_ZIP_CD       	 ,
	   CLAIM.SRC_SUFFX_PRSN_CD ,
	   CLAIM.LANGUAGE_INDICATOR     ,
	   CLAIM.FORMULARY_ID,
	   V.CMS_PLAN_ID, 
	   V.CMS_CNTRC_ID AS CMS_CNTRCT_ID
	 %IF &MODULE2. = RX %THEN %DO;  
	   ,MAX(B.PRTC_EFF_DT) as LAST_PRTC_EFF_DT
	   ,MAX(B.PRTC_END_DT) AS LAST_PRTC_END_DT
	   ,MAX(B.PRTC_REC_STUS_CD ) AS LAST_PRTC_REC_STUS_CD
	 %END; 
	 %IF &MODULE2. = RE %THEN %DO; 
		 ,MAX(B.REC_ADD_TS) as LAST_PRTC_EFF_DT   
	 %END;

	FROM &CLAIMS_TBL. CLAIM
	LEFT JOIN &DSS_CLIN..V_CLAIM V
/*		   ON     CLAIM.PAYER_ID       = V.PAYER_ID*/
/*		   AND    CLAIM.MBR_GID      = V.MBR_GID*/
          ON CLAIM.PAYER_ID = V.PAYER_ID 
			AND CLAIM.ALGN_LVL_GID_KEY = V.ALGN_LVL_GID
          	AND    CLAIM.MBR_GID      = V.MBR_GID
          	AND CLAIM.BATCH_DATE = V.BATCH_DATE

		%IF &MODULE2. = RX %THEN %DO; 
			LEFT JOIN &DSS_CLIN..V_MBR_PRTC_ELIG B
			ON     CLAIM.MBR_ID       = B.MBR_ID
			AND    CLAIM.MBR_GID      = B.MBR_GID
			AND    CLAIM.ALGN_LVL_GID_KEY = B.ALGN_LVL_GID
			AND    CLAIM.PAYER_ID     = B.PAYER_ID
			AND    B.PRTC_REC_STUS_CD = 'A'
		%END;

		%IF &MODULE2. = RE %THEN %DO; 
			LEFT JOIN &DSS_CLIN..V_MBR_MEDD_EXT  B
			ON     CLAIM.MBR_ID       = B.MBR_ID
		%END;

	GROUP BY 
	   CLAIM.MBR_GID,
	   CLAIM.PAYER_ID,
	   CLAIM.ALGN_LVL_GID_KEY	,
	   CLAIM.PT_BENEFICIARY_ID 	,
	   CLAIM.MBR_ID			,
	   CLAIM.CDH_BENEFICIARY_ID 	,
	   CLAIM.CLIENT_ID		,
	   CLAIM.CLIENT_LEVEL_1         ,
	   CLAIM.CLIENT_LEVEL_2         ,
	   CLAIM.CLIENT_LEVEL_3         ,
	   CLAIM.CLIENT_NM         	,
	   CLAIM.BIRTH_DT          	,
	   CLAIM.DRUG_ABBR_DSG_NM  	,
	   CLAIM.DRUG_ABBR_PROD_NM 	,
	   CLAIM.DRUG_ABBR_STRG_NM 	,
	   CLAIM.DRUG_BRAND_CD     	,
	   CLAIM.MBR_FIRST_NM      	 ,
	   CLAIM.MBR_LAST_NM       	 ,
	   CLAIM.ADDR_LINE1_TXT    	 ,
	   CLAIM.ADDR_LINE2_TXT    	 ,
	   CLAIM.ADDR_CITY_NM      	 ,
	   CLAIM.ADDR_ST_CD        	 ,
	   CLAIM.ADDR_ZIP_CD       	 ,
	   CLAIM.SRC_SUFFX_PRSN_CD 	,
	   CLAIM.LANGUAGE_INDICATOR     ,
	   CLAIM.FORMULARY_ID,
	   V.CMS_PLAN_ID, 
	   V.CMS_CNTRC_ID   
	HAVING SUM(CLAIM.RX_COUNT_QY) > 0 ) BY ORACLE ;
	DISCONNECT FROM ORACLE;
	QUIT;

		%put NOTE: *************************************************************************;
		%put NOTE: SQL COMPLETE ************************************************************;
		%put NOTE: *************************************************************************;

	*SASDOC--------------------------------------------------------------------------
	| CALL %GET_MOC_PHONE
	| ADD THE MAIL ORDER PHARMACY AND CUSTOMER SERVICE PHONE TO THE CPG FILE
	+------------------------------------------------------------------------SASDOC*;
    %GET_MOC_CSPHONE(MODULE=&MODULE2.,
					 TBL_NAME_IN =&ORA_TMP..CLAIMS3_PULL_&INITIATIVE_ID._&MODULE2., 
                     TBL_NAME_OUT=&TBL_NM_RX_RE2.);

%MEND RX_RE_PROCESS;

*SASDOC--------------------------------------------------------------------------
| POST PROCESSING AFTER CLAIM PULL 
+------------------------------------------------------------------------SASDOC*;
%MACRO RUN_PROCESS;
	%IF &RX_ADJ EQ 1 %THEN %do;
		%RX_RE_PROCESS(&ORA_TMP..&TABLE_PREFIX.PT_CLAIMS_GROUP_RX
				  ,&ORA_TMP..&TABLE_PREFIX._CLT_CPG_RX
				  ,2
				  ,&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX
				  ,&ORA_TMP..&TABLE_PREFIX.PT_CLAIM_MOC_RX
				  ,RX);
	%END;
	%IF &RE_ADJ EQ 1 %THEN %do;
		%RX_RE_PROCESS(&ORA_TMP..&TABLE_PREFIX.PT_CLAIMS_GROUP_RE
					  ,&ORA_TMP..&TABLE_PREFIX._CLT_CPG_RE
					  ,3
					  ,&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RE
					  ,&ORA_TMP..&TABLE_PREFIX.PT_CLAIM_MOC_RE
					  ,RE); 
	%END;
%MEND RUN_PROCESS;
%RUN_PROCESS;

*SASDOC-------------------------------------------------------------------------
| ELIGIBILITY_CHECK_NEGFRM2 - New Solution BSS
+-----------------------------------------------------------------------SASDOC*;
%ELIGIBILITY_CHECK_NEGFRM2(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX._CLAIMS_QL,
                   TBL_NAME_IN_RX=&ORA_TMP..&TABLE_PREFIX.PT_CLAIM_MOC_RX, 
                   TBL_NAME_IN_RE=&ORA_TMP..&TABLE_PREFIX.PT_CLAIM_MOC_RE, 
                   TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG_QL,
                   TBL_NAME_RX_OUT2=&ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RX,
                   TBL_NAME_RE_OUT2=&ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RE,
                   CLAIMSA=&CLAIMSA);

*SASDOC--------------------------------------------------------------------------
| THIS PROCESS WILL DOWNLOAD EDW DATA TO UNIX FOR EACH ADJUDICATION.
+------------------------------------------------------------------------SASDOC*;
%MACRO EDW2UNIX_CALL;
	%IF &RX_ADJ EQ 1 %THEN %DO;
		%EDW2UNIXNF(TBL_NM_IN=&ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RX
				 ,TBL_NM_OUT=DATA.&TABLE_PREFIX._CPG_ELIG_RX
				 ,ADJ_ENGINE=2   );
				 
		PROC SORT DATA = DATA.&TABLE_PREFIX._CPG_ELIG_RX NODUPKEY;
		  BY MBR_ID DRUG_NDC_ID ;
		RUN;
	%END;
	%IF &RE_ADJ EQ 1 %THEN %DO;
		%EDW2UNIXNF(TBL_NM_IN=&ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RE
				 ,TBL_NM_OUT=DATA.&TABLE_PREFIX._CPG_ELIG_RE
				 ,ADJ_ENGINE=3  );

		PROC SORT DATA = DATA.&TABLE_PREFIX._CPG_ELIG_RE NODUPKEY;
		  BY MBR_ID DRUG_NDC_ID ;
		RUN;
	%END;
%MEND EDW2UNIX_CALL;
%EDW2UNIX_CALL;


*SASDOC--------------------------------------------------------------------------
| CALL THE MACRO %COMBINE_ADJUDICATIONS. THE LOGIC IN THE MACRO COMBINES THE CLAIMS
| THAT WERE PULLED FOR ALL THREE ADJUDICATIONS.
+------------------------------------------------------------------------SASDOC*;
%COMBINE_ADJ(TBL_NM_RX=DATA.&TABLE_PREFIX._CPG_ELIG_RX,
             TBL_NM_RE=DATA.&TABLE_PREFIX._CPG_ELIG_RE,
             TBL_NM_OUT=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB1   ); 

*SASDOC --------------------------------------------------------------------
| MAY2008 N. WILLIAMS 
| REQUIREMENT**** Drop DB2 Columns and add them with proper data after.
+--------------------------------------------------------------------SASDOC*;
%MACRO DROP_ADD_DATA(VARIABLE=);
	DATA TEMP01;
	  SET &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB1 (OBS=1);
	RUN;

	PROC CONTENTS DATA = TEMP01 OUT = TEMP02 NOPRINT;
	RUN;
	
	%LET CONTENTS_CNT=0;

	PROC SQL NOPRINT;
	  SELECT COUNT(*) INTO: CONTENTS_CNT
	  FROM TEMP02
	  WHERE UPCASE(NAME)="&VARIABLE.";
	QUIT;

	%PUT NOTE: &CONTENTS_CNT. ;

	%IF &CONTENTS_CNT. NE 0 %THEN %DO;
		PROC SQL NOPRINT;
		    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
		    EXECUTE(ALTER TABLE &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB1 DROP COLUMN &VARIABLE.) BY DB2; 
		DISCONNECT FROM DB2;
		QUIT;
	%END;
%MEND DROP_ADD_DATA;
%DROP_ADD_DATA(VARIABLE=CDH_BENEFICIARY_ID);
%DROP_ADD_DATA(VARIABLE=CDH_EXTERNAL_ID);

%DROP_DB2_TABLE(tbl_name=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB2);

PROC SQL;
	CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	CREATE TABLE &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB2 AS
    SELECT * FROM CONNECTION TO DB2
	(
		SELECT A.*,                
			   B.CDH_BENEFICIARY_ID,
			   B.CDH_EXTERNAL_ID   as CDH_EXT_ID,
			   ' ' as ACCOUNT_ID, 
			' ' as ALTERNATE_DRUG_NM1,
			' ' as ALTERNATE_DRUG_NM2,
			' ' as ALTERNATE_DRUG_NM3,
			' ' as ALTERNATE_DRUG_NM4,
			' ' as ALTERNATE_DRUG_NM5,
			' ' as CARRIER_ID,
			1 as DATA_QUALITY_CD,
			' ' as EXPIRATION_DATE,
			' ' as INSURANCE_CD,
			' ' AS PHY_TOLL_FREE_NUM,
			' ' as SRC_INSRD_MBR_ID,
			' ' as TARGET_DRUG_NM

		FROM   &DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB1 A
		LEFT JOIN  &CLAIMSA..TBENEF_XREF_DN B			   
		ON  A.PT_BENEFICIARY_ID  = B.BENEFICIARY_ID
     ) ;
     DISCONNECT FROM DB2;
QUIT;
%RUNSTATS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB2);

*SASDOC-------------------------------------------------------------------------
| CREATE_BASE_FILE - GET BENEFICIARY ADDRESS AND CREATE SAS FILE LAYOUT.
+-----------------------------------------------------------------------SASDOC*;
%CREATE_BASE_FILE(TBL_NAME_IN=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB2);

*SASDOC-------------------------------------------------------------------------
| CHECK FOR DUPLICATS AGAINS FIRST RUN INITIATIVE AND DELETE IF ANY BY MBR_ID AND NDC.
| EOB_RUN_SEQ: 1 -first run, 2 - catch up run, 3 - periodic run.
+-----------------------------------------------------------------------SASDOC*;
%MACRO CHECK_DUP_MAILING;
	PROC SQL;
		SELECT EOB_RUN_SEQ, TRIM(LEFT(PUT(FIRST_RUN_INIT,4.))) INTO :EOB_RUN_SEQ, :FIRST_RUN_INIT
		FROM QCPAP020.TEOB_FILTER_DTL
		WHERE INITIATIVE_ID = &INITIATIVE_ID;

	QUIT;

	%put note: EOB_RUN_SEQ = &EOB_RUN_SEQ;
	%put note: FIRST_RUN_INIT =&FIRST_RUN_INIT;

	%IF &EOB_RUN_SEQ. = 2 OR &EOB_RUN_SEQ. = 3 %THEN %DO;
		%PUT NOTE: EOB_RUN_SEQ = &EOB_RUN_SEQ;
		%PUT NOTE: DATA_PND.T_&INITIATIVE_ID._DUPS_&FIRST_RUN_INIT.;
		%PUT NOTE: DATA_PND.DUPS_FOR_&INITIATIVE_ID._AND_&FIRST_RUN_INIT.;

		PROC SQL;
			CREATE TABLE DATA_PND.DUPS_FOR_&INITIATIVE_ID._AND_&FIRST_RUN_INIT. AS
			SELECT DISTINCT A.MBR_ID, A.DRUG_NDC_ID 
			FROM DATA_PND.T_&INITIATIVE_ID._1_1 AS A, 
				 DATA_PND.T_&FIRST_RUN_INIT._1_1 AS B
			WHERE A.MBR_ID = B.MBR_ID
			AND A.DRUG_NDC_ID = B.DRUG_NDC_ID;
		QUIT;
		%NOBS(DATA_PND.DUPS_FOR_&INITIATIVE_ID._AND_&FIRST_RUN_INIT.);
		%IF &NOBS %THEN %DO;
			/* FOR TESTING BKUP BEFORE REMOVAL*/
/*			DATA DATA_PND.T_&INITIATIVE_ID._1_1_B4_REMOVAL ;*/
/*				SET DATA_PND.T_&INITIATIVE_ID._1_1;*/
/*			RUN; */

			%PUT NOTE: DELETING DUPLICATS FROM FIRST RUN NOBS = &NOBS;
			PROC SQL;
				DELETE FROM DATA_PND.T_&INITIATIVE_ID._1_1 AS A
				WHERE EXISTS 
				(SELECT * 
				FROM DATA_PND.DUPS_FOR_&INITIATIVE_ID._AND_&FIRST_RUN_INIT. AS B
				WHERE A.MBR_ID = B.MBR_ID
				AND A.DRUG_NDC_ID = B.DRUG_NDC_ID);
			QUIT;
		%END;
		%ELSE %DO;
			%PUT NOTE: DELETING DATASET NOBS = &NOBS DATASET=T_&INITIATIVE_ID._&FIRST_RUN_INIT._DUPS LIB=&DATA_PND;
			PROC DATASETS LIB=DATA_PND NOLIST;
				DELETE DUPS_FOR_&INITIATIVE_ID._AND_&FIRST_RUN_INIT.;
			QUIT;
			RUN;
		%END;
	%END;
%MEND CHECK_DUP_MAILING;
%CHECK_DUP_MAILING;

*SASDOC-------------------------------------------------------------------------
| CHECK_DOCUMENT - TO SEE IF THE STELLENT ID(S) HAVE BEEN ATTACHED.
+-----------------------------------------------------------------------SASDOC*;
%CHECK_DOCUMENT_PROD;

*SASDOC-------------------------------------------------------------------------
| AUTORELEASE_FILE - CHECK FOR AUTO RELEASE OF FILE.
+-----------------------------------------------------------------------SASDOC*;
%AUTORELEASE_FILE(INIT_ID=&INITIATIVE_ID, PHASE_ID=&PHASE_SEQ_NB);

*SASDOC-------------------------------------------------------------------------
| Custom logic - Business request for additional fields for QA purposes
+-----------------------------------------------------------------------SASDOC*;
DATA DATA_PND.T_&initiative_id._1_1;
   format PREFERRED_MEMBER 15.;
   set DATA_PND.T_&initiative_id._1_1 ;
   FORMULARY_TX=FORMULARY_ID;
   ORG_FRM_STS=LANGUAGE_INDICATOR;
   SENIOR_IN=PAYER_ID;      
   PREFERRED_MEMBER = MBR_GID; 
   PRFR_DRUG_NM1 = MBR_ID;
   CDH_EXTERNAL_ID=CDH_EXT_ID;
   PRFR_DRUG_NM2=CMS_CNTRCT_ID; 
   PRFR_DRUG_NM3=CMS_PLAN_ID;
   SUBJECT_ID=RECIPIENT_ID; 
   AGE=floor((today()-birth_dt)/365.25);
   if AGE < 18 then MINOR_IN=1;
   else MINOR_IN=0;
RUN;

*SASDOC-------------------------------------------------------------------------
| INSERT DISTINCT RECIPIENTS INTO TCMCTN_PENDING IF THE FILE IS NOT AUTORELEASE.
| THE USER WILL RECEIVE AN EMAIL WITH THE INITIATIVE SUMMARY REPORT.  IF THE
| FILE IS AUTORELEASED, %RELEASE_DATA IS CALLED AND NO EMAIL IS GENERATED FROM
| %INSERT_TCMCTN_PENDING.
+-----------------------------------------------------------------------SASDOC*;
PROC SQL NOPRINT;
 DELETE *
 FROM HERCULES.TCMCTN_PENDING 
 WHERE INITIATIVE_ID = &INITIATIVE_ID. ;
QUIT;

%INSERT_TCMCTN_PENDING(INIT_ID=&INITIATIVE_ID, PHASE_ID=&PHASE_SEQ_NB);

%ON_ERROR(ACTION=ABORT, EM_TO=&PRIMARY_PROGRAMMER_EMAIL,
          EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
          EM_MSG="A problem was encountered.  See LOG file - &PROGRAM_NAME..log for Initiative Id &INITIATIVE_ID");

*SASDOC-------------------------------------------------------------------------
| UPDATE THE JOB COMPLETE TIMESTAMP.
+-----------------------------------------------------------------------SASDOC*;
%UPDATE_TASK_TS(JOB_COMPLETE_TS);

*SASDOC-------------------------------------------------------------------------
| get counts and email it.
+-----------------------------------------------------------------------SASDOC*;
%MACRO GET_COUNTS(TBL_NAME=,SASMACVAR=);
  %IF %SYSFUNC(EXIST(&TBL_NAME.))  %THEN %DO;
	 %NOBS(&TBL_NAME.);
	 %GLOBAL &SASMACVAR;
	 %IF &nobs NE %THEN %LET &SASMACVAR = %EVAL(&nobs);
	 %ELSE %LET &SASMACVAR = 0;
	 %PUT &SASMACVAR ;
  %END;
  %ELSE %DO;
     %GLOBAL &SASMACVAR;
     %LET &SASMACVAR = NA;
	 %PUT NOTE: &SASMACVAR ;
  %END;
%MEND GET_COUNTS;


/*client setup counts*/
%GET_COUNTS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CLT_CPG_QL,SASMACVAR=QLCLTCNT);
%GET_COUNTS(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._CLT_CPG_RX,SASMACVAR=RXCLTCNT);
%GET_COUNTS(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._CLT_CPG_RE,SASMACVAR=RECLTCNT);

/*drug setup counts*/
%GET_COUNTS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._NDC_QL,SASMACVAR=QLDRGCNT);
%GET_COUNTS(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._NDC_RX,SASMACVAR=RXDRGCNT);
%GET_COUNTS(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._NDC_RE,SASMACVAR=REDRGCNT);

/*initial claims pull counts*/
%GET_COUNTS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CLAIMS_QL,SASMACVAR=QLICLMCNT);
%GET_COUNTS(TBL_NAME=&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX,SASMACVAR=RXICLMCNT);
%GET_COUNTS(TBL_NAME=&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RE,SASMACVAR=REICLMCNT);

/*claims counts(summarization) after process step */
%GET_COUNTS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CLAIMS2_QL,SASMACVAR=QLPCLMCNT);
%GET_COUNTS(TBL_NAME=&ORA_TMP..&TABLE_PREFIX.PT_CLAIM_MOC_RX,SASMACVAR=RXPCLMCNT);
%GET_COUNTS(TBL_NAME=&ORA_TMP..&TABLE_PREFIX.PT_CLAIM_MOC_RE,SASMACVAR=REPCLMCNT);

/*eligibility check counts*/
%GET_COUNTS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._CPG_ELIG_QL,SASMACVAR=QLELGCNT);
%GET_COUNTS(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RX,SASMACVAR=RXELGCNT);
%GET_COUNTS(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RE,SASMACVAR=REELGCNT);

/*edw2 unix counts */ 
%GET_COUNTS(TBL_NAME=DATA.&TABLE_PREFIX._CLAIMS2_QL,SASMACVAR=QLE2UCNT); 
%GET_COUNTS(TBL_NAME=DATA.&TABLE_PREFIX._CPG_ELIG_RX,SASMACVAR=RXE2UCNT);
%GET_COUNTS(TBL_NAME=DATA.&TABLE_PREFIX._CPG_ELIG_RE,SASMACVAR=REE2UCNT);

/*combine_adj unix counts */
%GET_COUNTS(TBL_NAME=&DB2_TMP..&TABLE_PREFIX.PT_DRUG_GROUP_COMB2,SASMACVAR=COMBADJCNT);

/*create base file counts */
%GET_COUNTS(TBL_NAME=DATA_PND.T_&INITIATIVE_ID._&PHASE_SEQ_NB._1,SASMACVAR=FNLCNT);

DATA _NULL_ ;
  CALL SYMPUT('TODAY',TRANSLATE (PUT(TODAY(),WORDDATE18.),' -',','));
RUN;
%PUT NOTE:  &TODAY ;

filename TEMAIL email 
           to=(&PRIMARY_PROGRAMMER_EMAIL)
			cc=('Hercules.Support@caremark.com')
           subject="HCE SUPPORT: Negative Formulary Mailing - Initiative# &initiative_id has completed successfully" 
           type="text/plain"   ;
   

DATA _NULL_ ;
  FILE TEMAIL ;

  PUT @1 80*'-' ;

  PUT @1 "The Negative Formulary Initiative# &INITIATIVE_ID. job has just finished running";
  PUT @1 "on &TODAY..";
  PUT @1 80*'-' ;
  PUT @1 "The job has used the following file as input : " ;
  PUT @1 80*'-' ;
  PUT @1 "Claims Pull Date Range   : &CLM_BEGIN_DT to &CLM_END_DT"  ;
  PUT @1 90*' ';
  PUT @1 90*' ';
  PUT @1 "The job has produced the following files as output : " ;
  PUT @1 80*'-';
  PUT @1 90*' ';
  PUT @1 "Client Setup Process Step   : " ;
  PUT @1 80*'-' ;
  PUT @1 "QL Client Setup produced : &QLCLTCNT "  ;
  PUT @1 "RX Client Setup produced : &RXCLTCNT "  ;
  PUT @1 "RE Client Setup produced : &RECLTCNT "  ;
  PUT @1 90*' ';
  PUT @1 "Drug Setup Process Step   : " ;
  PUT @1 80*'-' ;
  PUT @1 "QL Drug Setup produced   : &QLDRGCNT "  ;
  PUT @1 "RX Drug Setup produced   : &RXDRGCNT "  ;
  PUT @1 "RE Drug Setup produced   : &REDRGCNT "  ;
  PUT @1 90*' ';
  PUT @1 "Initial Claims Pull Process Step   : " ;
  PUT @1 80*'-' ;
  PUT @1 "QL Initial Claims produced : &QLICLMCNT "  ;
  PUT @1 "RX Initial Claims produced : &RXICLMCNT "  ;
  PUT @1 "RE Initial Claims produced : &REICLMCNT "  ;
  PUT @1 90*' ';
  PUT @1 "After PROCESS Macro Step   : " ;
  PUT @1 80*'-' ;
  PUT @1 "QL Claims now has : &QLPCLMCNT "  ;
  PUT @1 "RX Claims now has : &RXPCLMCNT "  ;
  PUT @1 "RE Claims now has : &REPCLMCNT "  ;
  PUT @1 90*' ';
  PUT @1 "After Eligibility Check Macro Step   : " ;
  PUT @1 80*'-' ;
  PUT @1 "QL Eligibility Check Data now has : &QLELGCNT "  ;
  PUT @1 "RX Eligibility Check Data now has : &RXELGCNT "  ;
  PUT @1 "RE Eligibility Check Data now has : &REELGCNT "  ;
  PUT @1 90*' ';
  PUT @1 "After EDW2UNIX Macro Step   : " ;
  PUT @1 80*'-' ;
  PUT @1 "QL Data now has : &QLE2UCNT "  ;
  PUT @1 "RX Data now has : &RXE2UCNT "  ;
  PUT @1 "RE Data now has : &REE2UCNT "  ;
  PUT @1 90*' ';
  PUT @1 "After COMBINE_ADJ Macro Step   : " ;
  PUT @1 80*'-' ;
  PUT @1 "Total Claims Data now is : &COMBADJCNT "  ;
  PUT @1 90*' ';
  PUT @1 "Final Output Create_Base_File Macro Step   : " ;
  PUT @1 80*'-' ;
  PUT @1 "Final Data Count is : &FNLCNT "  ;
  PUT @1 90*' ';
  PUT @1 "Verify SAS Log File for any problems or data issues.";

RUN ;

*SASDOC-------------------------------------------------------------------------
| DROP THE TEMPORARY UDB TABLES
+-----------------------------------------------------------------------SASDOC*;
%MACRO FINAL_DROP_TABLE;
	%IF &DEBUG_FLAG NE Y %THEN %DO ;	 
		 /* DROP ORACLE TEMPORARY TABLES **************************************/  
		 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._NDC_RX); 
		 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._NDC_RE); 
		 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._RVW_DATES); 
		 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..ALGN_LVL_LIST_&INITIATIVE_ID._RE);
		 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..ALGN_LVL_LIST_&INITIATIVE_ID._RX);
		 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._CLT_CPG_RX);
		 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._CLT_CPG_RE);
		 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX);
		 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RE);
		 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..CLAIMS3_PULL_&INITIATIVE_ID._RX);
		 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..CLAIMS3_PULL_&INITIATIVE_ID._RE);
		 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX.PT_CLAIM_MOC_RX);
		 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX.PT_CLAIM_MOC_RE);
		 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RX);
		 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._CPG_ELIG_RE);

		 /* DROP SAS TEMP DATASETS ********************************************/
		 %DROP_SAS_DSN(DSN=DATA.&TABLE_PREFIX._CPG_ELIG_RX);
		 %DROP_SAS_DSN(DSN=DATA.&TABLE_PREFIX._CPG_ELIG_RE);
	%END;
%MEND FINAL_DROP_TABLE;
/*%FINAL_DROP_TABLE;*/

%MACRO SENT_CMCTN_ERR;
	  %*SASDOC-----------------------------------------------------------------------
	  | Produce report of undeleted files.
	  +----------------------------------------------------------------------SASDOC*;
	  /*SASDOC-----------------------------------------------------------------------
	  | Modify ODS template.
	  +----------------------------------------------------------------------SASDOC*/
	  ods path sasuser.templat(read) sashelp.tmplmst(read) work.templat(update);
	  proc template;
	  define style MAIN_DIR / store=WORK.TEMPLAT;
		 parent=styles.minimal;
		   style TABLE /
			 rules = NONE
			 frame = VOID
			 cellpadding = 0
			 cellspacing = 0
			 borderwidth = 1pt;
		 end;
	  run;


     filename RPTDEL "/herc&sysmode/data/hercules/reports/data_quality_3_&Initiative_id._report.xls";
     ods listing close;
     ods html
        file =RPTDEL
        style=MAIN_DIR;
     title1 j=l "data_quality_cd 3 MBRS  ";

        proc print data = DATA_PND.T_&INITIATIVE_ID._&PHASE_SEQ_NB._1 noobs; 
		WHERE DATA_QUALITY_CD=3; 
		run;

     quit;
     ods html close;
     ods listing;
     run;
     quit;

     %let RPTDEL=%sysfunc(PATHNAME(RPTDEL));
     %let RPT   =%sysfunc(PATHNAME(RPT));

	 filename mymail email 'qcpap020@prdsas1';

	  data _null_;
		file mymail
			to =(&PRIMARY_PROGRAMMER_EMAIL)
			cc =('Hercules.Support@caremark.com')
			subject="HCE SUPPORT: List of data quality 3 Members on pending sas dataset &Initiative_id."
			attach=( "&RPTDEL" ct='application/xls' ext='xls' );;

		put 'Hello:' ;
		put / "Attached is a list of member(s) that were eliminated during EOB Filtering Process.";
		put / 'Please check the members(s) and ensure accuracy.';
	 run;
 quit; 
%MEND SENT_CMCTN_ERR;
/*%SENT_CMCTN_ERR;*/

