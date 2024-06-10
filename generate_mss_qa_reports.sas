/*%include '/user1/qcpap020/autoexec_new.sas';*/
/*%include '/home/user/qcpap020/autoexec_new.sas'; */

/*HEADER--------------------------------------------------------------------------------------------
|
| MACRO:  GENERATE_MSS_QA_REPORTS.sas
|
| LOCATION: /herc&sysmode/prg/hercules/macros/
|
| DESCRIPTION: This program generates QA reports for the Initiatives that are processed during Mailing file process.
|				
| PROCESS: 
|		1)  Query EDW tables to fetch data for the QA reports.
| 						      
|		2) 	Use PROC REPORT and ODS PDF to create reports in PDF format.
|
|	  	3)	FTP the PDF files to Patient List drive.
|
| INPUT:    Parameters: 	INITIATIVE_ID.
|           Data source: 	DWCORP.T_IBEN_OPP_SRC
|							DWCORP.T_IBEN_ECOE_STACK_MOCK
|							DWCORP.T_IBEN_ECOE_RSPNS
|							DWCORP.T_IBEN_SAV_EXTR
|
| OUTPUT:   Store the QA Reports in Patientlist drive in PDF format.
|			
|
| USAGE:    The program will be called by IBENEFIT3_EDW_PARMIN.SAS program.
|           
+---------------------------------------------------------------------------------------------------
| HISTORY:  
|
| 19JUL2011 - Sathishkumar Veeraswamy (SKV) - Initial Version  1.0
|             Created for PSG Carryover project Requirements (July 2011 Release).
| 08AUG2013 - Sergey Biletsy - Continous Processing changes
|			  Created macro version of the program
|
+--------------------------------------------------------------------------------------------HEADER*/
/*%set_sysmode(mode=prod);*/
/*options orientation=landscape nodate nonumber MISSING=' ' cleanup fullstimer SPOOL;	/* AK added spool option */*/

/*%Global INIT_ID;*/
/*%LET DS = BSLN_COPAY_SUMMARY;*/
/*%INCLUDE "/PRG/sas&sysmode.1/hercules/hercules_in.sas";*/
/*%INCLUDE "/herc&sysmode/prg/hercules/hercules_in.sas";*/
/**/
/*DATA EDW_DATA_INITIATIVES;*/
/*INFILE DATALINES;*/
/*INPUT INITIATIVE_ID 8.;*/
/*DATALINES;*/
/*14955*/
/*;*/
/*RUN;*/

/*%LET QAWORK = WORK;*/

*SASDOC----------------------------------------------------------------------------
| Fetch the list of initiatives to be processed from EDW_DATA_INITIATIVES dataset.
|This dataset is created during PARMIN process
+---------------------------------------------------------------------------SASDOC*;


/*PROC SQL NOPRINT;*/
/*             SELECT DISTINCT INITIATIVE_ID INTO : INIT_ID SEPARATED BY ','*/
/*             FROM EDW_DATA_INITIATIVES;*/
/*QUIT;*/
 

/*DATA _NULL_;*/
/*  SET EDW_DATA_INITIATIVES END=EOF;*/
/*    I+1;*/
/*    II=LEFT(PUT(I,4.));*/
/*    CALL SYMPUT('edw_initiative_id'||II,TRIM(INITIATIVE_ID));*/
/*    IF EOF THEN CALL SYMPUT('edw_initiative_id_total',II);*/
/*RUN;*/

%MACRO GENERATE_MSS_QA_REPORTS(INIT);

options orientation=landscape nodate nonumber MISSING=' ' cleanup fullstimer SPOOL;	/* AK added spool option */

%global QA_FTPDIR QA_FTP_HOST QA_FTP_USER QA_FTP_PASS;

%LET QAWORK = WORK;
%LET DS = BSLN_COPAY_SUMMARY;

/*%IF &edw_initiative_id_total. = 0 %THEN %GOTO EXIT_PROCESS;*/
/**/
/*%do z = 1 %to &edw_initiative_id_total.;  ** begin loop for the initiatives of the EdwInitiativeLoop macro; */
/**/
/*%LET INIT=&&edw_initiative_id&z.;*/

%put NOTE: Generating Reports for Initiative %trim(&INIT.);


* Fetch FTP server details from SET_FTP dataset;

proc sql noprint;
		 select      ftp_host,
                     ftp_user,
                  ftp_pass
            into     :ftp_host,
                     :ftp_user,
                     :ftp_pass
            from     aux_tab.set_ftp
            where    destination_cd = 1
			;
         QUIT;

%let QA_FTPDIR=/users/patientlist/iBenefit/Reports;
%LET QA_FTP_HOST = %TRIM(&FTP_HOST);
%LET QA_FTP_USER = %TRIM(&FTP_USER);
%LET QA_FTP_PASS = %TRIM(&FTP_PASS);


/* Get Data For Reports */

%MACRO GET_QC_DATA (QAWORK=WORK);
/* Run SQL to fetch data for Drug - No alternatives recommended Report*/

PROC SQL NOPRINT;
	CONNECT TO ORACLE (PATH =&GOLD);
	CREATE TABLE &QAWORK..DRUG_NO_ALT AS
	SELECT * FROM CONNECTION TO ORACLE
	( SELECT DISTINCT 
				A.INIT_ID, 
				B.BST_FLGHT_DRUG_IND, 
				B.BST_FLGHT_DRUG_CAT, 
				A.BSLNE_GNRC_IND, 
				B.PRFD_STUS_IND, 
				A.BSLNE_NDC_DESC 
    FROM DWCORP.T_IBEN_SAV_EXTR  A
    LEFT JOIN DWCORP.T_IBEN_OPP_SRC B
    ON A.CLAIM_GID=B.CLAIM_GID
    
    WHERE
 	A.IBEN3_REP_FLG = 'Y' AND        
	A.ALTRV_NDC_CODE=A.BSLNE_NDC_CODE AND
	A.INIT_ID IN (&INIT.)
    ORDER BY A.INIT_ID, B.BST_FLGHT_DRUG_IND, 
			A.BSLNE_GNRC_IND,B.PRFD_STUS_IND, A.BSLNE_NDC_DESC
	);
	DISCONNECT FROM ORACLE;
QUIT;


/* Fetch data for Drug - No alternatives recommended - No Generics Report */

DATA &QAWORK..DRUG_NO_GENERIC;
	SET &QAWORK..DRUG_NO_ALT;
	WHERE BSLNE_GNRC_IND NE 'Y';
RUN;

PROC SORT DATA=&QAWORK..DRUG_NO_GENERIC NODUPKEY;
	BY INIT_ID BST_FLGHT_DRUG_IND BSLNE_GNRC_IND PRFD_STUS_IND BSLNE_NDC_DESC;
RUN;

/* Run SQL to fetch data for Drug - Alternatives recommended Report */;

PROC SQL NOPRINT;
	CONNECT TO ORACLE (PATH =&GOLD);
	CREATE TABLE &QAWORK..DRUG_ALT_RCMND AS
	SELECT * FROM CONNECTION TO ORACLE
	(
	SELECT DISTINCT 
	A.INIT_ID, 
	B.BST_FLGHT_DRUG_IND, 
	B.BST_FLGHT_DRUG_CAT, 
	A.BSLNE_GNRC_IND, 
	B.PRFD_STUS_IND, 
	A.BSLNE_NDC_DESC,
	A.ALTRV_NDC_DESC,
	A.ALTRV_SRC_IND
	    FROM DWCORP.T_IBEN_SAV_EXTR A
	    LEFT JOIN DWCORP.T_IBEN_OPP_SRC B
	    ON A.CLAIM_GID=B.CLAIM_GID	    
	    WHERE
	 A.IBEN3_REP_FLG = 'Y' AND        
	A.ALTRV_NDC_CODE <> A.BSLNE_NDC_CODE AND A.INIT_ID IN (&INIT.)
	    ORDER BY A.INIT_ID, B.BST_FLGHT_DRUG_IND, 
	A.BSLNE_GNRC_IND,B.PRFD_STUS_IND, A.BSLNE_NDC_DESC
	);
	DISCONNECT FROM ORACLE;
QUIT;

/* Fetch data for Drug - Alternatives recommended - No MSBs Report*/

DATA &QAWORK..DRUG_ALT_NOMSB (DROP = ALTRV_SRC_IND);
	SET &QAWORK..DRUG_ALT_RCMND;
	WHERE ALTRV_SRC_IND = 'T';
RUN;

PROC SORT DATA=&QAWORK..DRUG_ALT_NOMSB NODUPKEY;
	BY INIT_ID BST_FLGHT_DRUG_IND BSLNE_GNRC_IND PRFD_STUS_IND BSLNE_NDC_DESC;
RUN;

/* Run SQL to fetch data for Channel Summary Report */

PROC SQL NOPRINT;
	CONNECT TO ORACLE (PATH =&GOLD);
	CREATE TABLE &QAWORK..CHNL_SUMMARY AS
	SELECT * FROM CONNECTION TO ORACLE
	(
	SELECT DISTINCT A.INIT_ID,
	A.BSLNE_CHNL,
	A.BSLNE_MAINT_DRUG_IND,
	A.BSLNE_CNTRLD_SBSTNCS_IND,
	A.BSLNE_SPCLTY_DRUG_IND,
	A.BSLNE_ACUT_DRUG_IND,
	A.BST_FLGHT_CHNL_IND,

	CASE WHEN B.DAYS_SPLY_CNT < 21 THEN '1 - 20'
	    WHEN B.DAYS_SPLY_CNT BETWEEN 21 AND 30 THEN '21 - 30'
	    WHEN B.DAYS_SPLY_CNT BETWEEN 31 AND 83 THEN '31 - 83'
	    ELSE '84+'
	END AS Days_Supply 

	 FROM DWCORP.T_IBEN_SAV_EXTR A JOIN
	DWCORP.T_IBEN_ECOE_STACK_MOCK B ON 
	A.INIT_ID = B.INIT_ID AND
	A.MBR_ID = B.MBR_ID AND 
	B.NDC_CODE = A.BSLNE_NDC_CODE AND
	A.INIT_ID IN (&INIT.)

	WHERE
	A.IBEN3_REP_FLG <> 'N' AND
	A.BSLNE_RJCT_STUS_IND = 'A'
	ORDER BY 
	    A.INIT_ID,
	    A.BSLNE_CHNL,
	    A.BSLNE_MAINT_DRUG_IND,
	    A.BSLNE_CNTRLD_SBSTNCS_IND,
	    A.BSLNE_SPCLTY_DRUG_IND,
	    A.BSLNE_ACUT_DRUG_IND,
	    A.BST_FLGHT_CHNL_IND ,
	    Days_Supply
			);
	DISCONNECT FROM ORACLE;
QUIT;


/******************************************/
/* Extract ECOE Claim Data for initiative */
/******************************************/

PROC SQL NOPRINT;
	CONNECT TO ORACLE (PATH =&GOLD);
	CREATE TABLE &QAWORK..MOCK_CLAIM_&INIT. AS
	SELECT * FROM CONNECTION TO ORACLE
	(
	SELECT 
	   IBEN_ECOE_STACK_MOCK_GID,
	   CLAIM_KEY,
	   INIT_ID,	  
	   CLNT_CD,
	   MBR_ID,
	   BSLNE_IND,
	   NDC_CODE,
	   DAYS_SPLY_CNT,
       DELY_SYS_CD	  
	 FROM DWCORP.T_IBEN_ECOE_STACK_MOCK 
	 WHERE INIT_ID IN (&INIT.)
	);
	DISCONNECT FROM ORACLE;
QUIT;

/******************************************/
/* Find Min and Max GID                   */
/******************************************/

PROC SQL NOPRINT;
	SELECT DISTINCT("'"||COMPRESS(CLNT_CD)||"'"),
		min(IBEN_ECOE_STACK_MOCK_GID), 
		max(IBEN_ECOE_STACK_MOCK_GID)	
		INTO :CLNT_CD, :min_gid, :max_gid		
	FROM &QAWORK..MOCK_CLAIM_&INIT.;	
QUIT;

%PUT INIT: INIT = &INIT;
%PUT NOTE: CLNT_CD = &CLNT_CD;
%PUT NOTE: min_gid = &min_gid;
%PUT NOTE: max_gid = &max_gid;

/******************************************/
/* Extract ECOE Response Info for Init    */
/******************************************/

PROC SQL NOPRINT;
	CONNECT TO ORACLE (PATH =&GOLD);
	CREATE TABLE &QAWORK..MOCK_RESP_&INIT. AS
	SELECT * FROM CONNECTION TO ORACLE
	(
	SELECT 
	   TO_NUMBER (SUBSTR (CLAIM_KEY, 1, 10), '999999999999')
       					AS IBEN_ECOE_STACK_MOCK_GID,
	   RJCT_CD1,
	   MSG_1,
       CLAIM_STUS,
	   BYPS_PRIOR_ATHZN,
	   BYPS_REFIL_LMTS,
	   BYPS_STEP_THRPY,  

	   CASE WHEN (PNT_PAY_AMT - Floor(PNT_PAY_AMT)) <> 0 
			  AND (PNT_PAY_AMT - Floor(PNT_PAY_AMT)) <> 0.50 
			 THEN 'Coinsurance'
	         ELSE 'COPAY' 
	   END as COPCOINS,

	   CASE WHEN (PNT_PAY_AMT-Floor(PNT_PAY_AMT)) <> 0 
			  AND (PNT_PAY_AMT-Floor(PNT_PAY_AMT)) <> 0.50  
			 THEN ROUND((PNT_PAY_AMT/(PNT_PAY_AMT+TOT_AMT))*100, 0) /* Made the change in round function from 0.2 to 2 and multiplication by 100 was added */
	         ELSE Null
	   END as Coinsurance,

	   CASE WHEN(PNT_PAY_AMT - Floor(PNT_PAY_AMT)) IN (0,0.50) 
			 THEN PNT_PAY_AMT
	         ELSE Null
	   END as Copay,
	   PNT_PAY_AMT,	   
	   TOT_AMT, 
	   APD_DED_AMT,
	   PRD_SEL_AMT	  
	 FROM DWCORP.T_IBEN_ECOE_RSPNS 
	 WHERE TO_NUMBER (SUBSTR (CLAIM_KEY, 1, 10), '999999999999')
	 			BETWEEN	&min_gid. AND &max_gid.
 	 AND TRIM(CLNT_CD) = &CLNT_CD.
	);
	DISCONNECT FROM ORACLE;
QUIT;

/******************************************/
/* Extract Savings Extract Info for Init  */
/******************************************/

PROC SQL NOPRINT;
	CONNECT TO ORACLE (PATH =&GOLD);
	CREATE TABLE &QAWORK..SAV_EXT_&INIT. AS
	SELECT * FROM CONNECTION TO ORACLE
	(
		SELECT 
			INIT_ID,	
			MBR_ID, 
		    BSLNE_NDC_CODE, 
		    BSLNE_NDC_DESC,
		    ALTRV_NDC_CODE,
		    ALTRV_NDC_DESC,
			BSLNE_GNRC_IND, 
			CASE WHEN BSLNE_GNRC_IND = 'Y' 
				 THEN 'Generic'
			     ELSE 'Brand' 
		    END AS BG_status, 

			BSLNE_PRFRD_IND,
		    CASE WHEN BSLNE_PRFRD_IND = 'Y' 
                 THEN 'Preferred'
			     ELSE 'Not Preferred'
		    END AS Pref_Status,
			IBEN3_REP_FLG,
			MBR_SAV,
			BSLNE_COPAY_AMT,
			BSLNE_TOT_AMT,
			BST_FLGHT_DRUG_IND,
		    MDULE_200,
		    MDULE_201,
		    MDULE_202,
		    MDULE_203,
		    MDULE_204,
		    MDULE_205
		FROM DWCORP.T_IBEN_SAV_EXTR
		WHERE INIT_ID IN (&INIT.)
	);
	DISCONNECT FROM ORACLE;
QUIT;


/* Run SQL to fetch data for Reject Summary Report */

PROC SQL;	
	CREATE TABLE &QAWORK..REJECT_SUMMARY AS	
	SELECT DISTINCT 
		A.INIT_ID,
	    A.BSLNE_IND, 
	    B.RJCT_CD1, 
	    Count(B.RJCT_CD1) AS RJCT_CD_CNT, 
	    B.MSG_1
	    FROM 
	    &QAWORK..MOCK_CLAIM_&INIT. A
	    INNER JOIN 
	    &QAWORK..MOCK_RESP_&INIT. B
	    
		ON A.IBEN_ECOE_STACK_MOCK_GID = B.IBEN_ECOE_STACK_MOCK_GID

	    WHERE B.CLAIM_STUS IN ('DENIED','REJECT') AND A.INIT_ID IN (&INIT.)
	    GROUP BY A.INIT_ID,
	        B.RJCT_CD1, 
	        B.MSG_1,
	        A.BSLNE_IND
	    ORDER BY A.INIT_ID,
	        B.RJCT_CD1, 
	        B.MSG_1,
	        A.BSLNE_IND;
QUIT;

/*%BYPASS_FLAG_SUMMARY; */ /* Added this macro at the end as it takes a long time */
/* Run SQL to fetch data for Outlier Report*/

/*Query for fetching members having highest/lowest savings, highest/lowest out of pocket cost, highest/lowest plan paid cost, 
highest/lowest # of baseline drugs (best flight and not at best flight)*/

PROC SQL NOPRINT;	
	CREATE TABLE &QAWORK..COST_OUTLIER AS	
	SELECT 
		INIT_ID, 
		MBR_ID,
		SUM(MBR_SAV) AS MBR_SAV,
		SUM(BSLNE_COPAY_AMT) AS COPAY_AMT,
		SUM(BSLNE_TOT_AMT) AS BSLNE_TOT_AMT,
		COUNT(CASE WHEN BST_FLGHT_DRUG_IND = 'C' THEN BSLNE_NDC_CODE
			ELSE  ' '
		END) AS NDC_CNT_BF,
		COUNT(CASE WHEN BST_FLGHT_DRUG_IND <> 'C' THEN BSLNE_NDC_CODE
			ELSE ' '
		END) AS NDC_CNT_NTBF

		FROM &QAWORK..SAV_EXT_&INIT. WHERE INIT_ID IN (&INIT.)
		GROUP BY INIT_ID, MBR_ID
		ORDER BY INIT_ID, MBR_ID;	
QUIT;

/*Query for fetching member having highest/lowest # of Baseline drugs.*/

PROC SQL NOPRINT;
	CONNECT TO ORACLE (PATH =&GOLD);
	CREATE TABLE &QAWORK..NDC_OUTLIER AS
	SELECT * FROM CONNECTION TO ORACLE
	(	
	SELECT 
		INIT_ID, 
		mbr_id, 
		count(ndc_code) as ndc_cnt 

		from DWCORP.T_IBEN_OPP_SRC
		WHERE init_id IN (&INIT.) 
		GROUP BY INIT_ID, MBR_ID
		ORDER BY INIT_ID, MBR_ID
	);
	DISCONNECT FROM ORACLE;
QUIT;

/*Query for fetching members having highest # of claim rejects*/

PROC SQL NOPRINT;	
	CREATE TABLE &QAWORK..BYPASSNDC AS	
	SELECT 
		B.INIT_ID,
		B.MBR_ID,
		COUNT(NDC_CODE) AS NDC_CNT

		FROM &QAWORK..MOCK_RESP_&INIT. A 
		INNER JOIN &QAWORK..MOCK_CLAIM_&INIT. B  		
		ON B.IBEN_ECOE_STACK_MOCK_GID = A.IBEN_ECOE_STACK_MOCK_GID

		WHERE A.CLAIM_STUS IN ('REJECT','DENIED') AND B.INIT_ID IN (&INIT.)
		GROUP BY B.INIT_ID, B.MBR_ID
		ORDER BY B.INIT_ID, B.MBR_ID;	
QUIT;

/*Query for fetching members having highest # of bypass flags.*/

PROC SQL;	
	CREATE TABLE &QAWORK..BYPASSFLGCNT AS	
	SELECT 
		B.INIT_ID,
		B.MBR_ID,
		(SUM( CASE WHEN A.BYPS_PRIOR_ATHZN = 'R' THEN 1
	        ELSE 0
	     END) +

		SUM(CASE WHEN A.BYPS_REFIL_LMTS = 'R' THEN 1
	        ELSE 0
	    END) +

		SUM( CASE WHEN A.BYPS_STEP_THRPY = 'R' THEN 1
	        ELSE 0
	    END)) AS SUM_BYP_FLG
	          
		FROM (&QAWORK..MOCK_CLAIM_&INIT. B 
			  INNER JOIN 
			  &QAWORK..MOCK_RESP_&INIT. A	           
		      ON B.IBEN_ECOE_STACK_MOCK_GID = A.IBEN_ECOE_STACK_MOCK_GID	      
	         )
		WHERE A.CLAIM_STUS IN ('ACCEPT') AND B.INIT_ID IN (&INIT.) AND
		(A.BYPS_PRIOR_ATHZN = 'R' OR
		A.BYPS_REFIL_LMTS = 'R' OR
		A.BYPS_STEP_THRPY = 'R')
		GROUP BY B.INIT_ID, B.MBR_ID
		ORDER BY B.INIT_ID, B.MBR_ID;	
QUIT;

/* Run SQL to fetch data for Baseline Copay Detail Report*/

PROC SQL;	
	CREATE TABLE &QAWORK..BSLN_COPAY_DETAIL AS	
	SELECT DISTINCT 
	    B.INIT_ID,
	    B.MBR_ID,
	    
	    CASE WHEN B.DELY_SYS_CD = '2' THEN 'Mail'
			ELSE 'Retail'
		END AS CHANNEL,	

	    CASE WHEN B.DAYS_SPLY_CNT < 31 THEN '1 - 30'
	         WHEN B.DAYS_SPLY_CNT BETWEEN 30 AND 84 THEN '31 - 83'
	         ELSE '> 83'
	    END AS Days_Supply, 

		A.COPCOINS,
		A.Coinsurance,
		A.Copay,
	    
		/*
	    CASE WHEN (A.PNT_PAY_AMT - Floor(A.PNT_PAY_AMT)) <> 0 
			  AND (A.PNT_PAY_AMT - Floor(A.PNT_PAY_AMT)) <> 0.50 
			 THEN 'Coinsurance'
	         ELSE 'COPAY' 
	    END as COPCOINS,

	    CASE WHEN (A.PNT_PAY_AMT-Floor(A.PNT_PAY_AMT)) <> 0 
			  AND (A.PNT_PAY_AMT-Floor(A.PNT_PAY_AMT)) <> 0.50  
			 THEN ROUND((A.PNT_PAY_AMT/(A.PNT_PAY_AMT+A.TOT_AMT))*100, 0) 		
	         ELSE .
	    END as Coinsurance,

	    CASE WHEN(A.PNT_PAY_AMT - Floor(A.PNT_PAY_AMT)) IN (0,0.50) 
			 THEN A.PNT_PAY_AMT
	         ELSE .
	    END as Copay,
		*/

		C.BSLNE_NDC_CODE, 
	    C.BSLNE_NDC_DESC,
		CASE WHEN C.BSLNE_GNRC_IND = 'Y' 
			 THEN 'Generic'
			 ELSE 'Brand'
		END AS BG_status, 

		CASE WHEN C.BSLNE_PRFRD_IND = 'Y' 
             THEN 'Preferred'
			 ELSE 'Not Preferred'
		END AS Pref_Status

	FROM ( &QAWORK..MOCK_CLAIM_&INIT. B
	INNER JOIN &QAWORK..MOCK_RESP_&INIT. A	    
	    ON B.IBEN_ECOE_STACK_MOCK_GID = A.IBEN_ECOE_STACK_MOCK_GID
	     )
	  INNER JOIN &QAWORK..SAV_EXT_&INIT. C ON 
	    B.INIT_ID = C.INIT_ID AND B.MBR_ID = C.MBR_ID AND B.NDC_CODE = C.BSLNE_NDC_CODE
	WHERE B.INIT_ID IN (&INIT.)
	    AND B.BSLNE_IND = 'Y'
	    AND A.TOT_AMT  > 0 
	    AND A.CLAIM_STUS = 'ACCEPT'
	    AND A.APD_DED_AMT  = 0
	    AND A.PRD_SEL_AMT = 0
	ORDER BY    
	    B.INIT_ID, CHANNEL,
	    BG_STATUS,
	    PREF_STATUS,
	    DAYS_SUPPLY,
	    COPCOINS,
	    COINSURANCE,
	    COPAY;    
QUIT;

/* Create dataset for Baseline COpay Summary for Baseline Copay Detail*/

PROC SQL NOPRINT;
	CREATE TABLE &QAWORK..BSLN_COPAY_SUMMARY AS
	SELECT DISTINCT 
		INIT_ID,
		CHANNEL,
	    BG_STATUS,
	    PREF_STATUS,
	    DAYS_SUPPLY,
	    COPCOINS,
	    COINSURANCE,
	    COPAY
	FROM &QAWORK..BSLN_COPAY_DETAIL;
QUIT;

/* Fetch 10 detail rows for Channel, Brand/Generic, /Preferred Status/DAYS Supply combination, Copay/Coinsurance Type, Coinsurance, and Copay combination*/

data &QAWORK..BSLN_COPAY_DETAIL_FINAL (DROP=OBS);
 	set &QAWORK..BSLN_COPAY_DETAIL;
 	by INIT_ID
		CHANNEL
    	BG_STATUS
    	PREF_STATUS
    	DAYS_SUPPLY
    	COPCOINS
    	COINSURANCE
    	COPAY;
 	if first.copay then obs=1;
 	else obs+1;
 	if obs le 10 then output;
run;

PROC SORT DATA=&QAWORK..BSLN_COPAY_DETAIL_FINAL;
	by INIT_ID
		CHANNEL
    	BG_STATUS
    	PREF_STATUS
    	DAYS_SUPPLY
    	COPCOINS
    	COINSURANCE
    	COPAY;
RUN;

* Run SQL to fetch data for Bypass Flag Summary Report;

PROC SQL;	
	CREATE TABLE &QAWORK..BYPASS_FLAG_SUMMARY AS	
	SELECT DISTINCT B.INIT_ID,    
		CASE
		    WHEN B.BSLNE_IND = 'Y' THEN A.BYPS_PRIOR_ATHZN
		    ELSE ' '
		END AS BSLN_PA_BP,

		CASE
		    WHEN B.BSLNE_IND = 'Y' THEN A.BYPS_REFIL_LMTS
		    ELSE ' '
		END AS BSLN_FILL_BP,

		CASE
		    WHEN B.BSLNE_IND = 'Y' THEN A.BYPS_STEP_THRPY
		    ELSE ' '
		END AS BSLN_STEP_BP,

		CASE
		    WHEN B.BSLNE_IND = 'N' THEN A.BYPS_PRIOR_ATHZN
		    ELSE ' '
		END AS ALT_PA_BP,

		CASE
		    WHEN B.BSLNE_IND = 'N' THEN A.BYPS_REFIL_LMTS
		    ELSE ' '
		END AS ALT_FILL_BP,

		CASE
		    WHEN B.BSLNE_IND = 'N' THEN A.BYPS_STEP_THRPY
		    ELSE ' '
		END AS ALT_STEP_BP,

			C.MBR_ID, 
		    C.BSLNE_NDC_CODE, 
		    C.BSLNE_NDC_DESC,
		    C.ALTRV_NDC_CODE,
		    C.ALTRV_NDC_DESC,
		    C.MDULE_200,
		    C.MDULE_201,
		    C.MDULE_202,
		    C.MDULE_203,
		    C.MDULE_204,
		    C.MDULE_205
		    
		FROM (&QAWORK..MOCK_RESP_&INIT. A INNER JOIN &QAWORK..MOCK_CLAIM_&INIT. B 		    
			 ON B.IBEN_ECOE_STACK_MOCK_GID = A.IBEN_ECOE_STACK_MOCK_GID   
		     ) 
		   INNER JOIN &QAWORK..SAV_EXT_&INIT. C
		   ON     B.INIT_ID=C.INIT_ID AND (B.MBR_ID=C.MBR_ID) AND (B.NDC_CODE=C.BSLNE_NDC_CODE)    
		    
		WHERE
		A.CLAIM_STUS = 'ACCEPT' AND  B.INIT_ID IN (&INIT.) AND C.IBEN3_REP_FLG='Y' AND
		(A.BYPS_PRIOR_ATHZN = 'R' OR
		A.BYPS_REFIL_LMTS = 'R' OR
		A.BYPS_STEP_THRPY = 'R')
		ORDER BY
		    B.INIT_ID,
		    C.MBR_ID, 
		    C.BSLNE_NDC_DESC;	
QUIT;

%MEND GET_QC_DATA;

%GET_QC_DATA (QAWORK=&QAWORK.); 


/***************************************************************/
/* Produce Reports                                             */
/***************************************************************/

%MACRO NO_DATA_MSG(DS);

PROC SQL NOPRINT;
	SELECT COUNT(*) 
		INTO :OBS_COUNT 
	FROM &DS;	/* OBS_COUNT MACRO VARIABLE STORES NUMBER OF OBSERVATIONS */				
QUIT;

%IF &OBS_COUNT = 0 %THEN %DO;
	DATA EMPTY;
    	TEXT='NO DATA WAS FOUND FOR THIS REPORT FOR THIS INITIATIVE';			
	RUN;
	%PUT NOTE: DS = &DS.;
	%PUT NOTE: OBS_COUNT = &OBS_COUNT;	/* ONLY IF OBS_COUNT = 0 THEN THIS WILL PRINT THE ABOVE MESSAGE */

	PROC REPORT DATA=EMPTY HEADSKIP MISSING
		STYLE(HEADER)=[FONT_SIZE   =11PT
                  FONT_FACE   =ARIAL BACKGROUND=NONE FOREGROUND=LIGHT BLUE]
		STYLE(REPORT)=[FONT_SIZE   =9PT
                  FONT_FACE   =ARIAL BACKGROUND=NONE RULES=ROWS FRAME=VOID BORDERCOLOR=LIGHT BLUE];
		COLUMNS TEXT;
    	DEFINE TEXT / ' '; 		
	RUN;
%END;

%MEND NO_DATA_MSG;


/* Baseline Copay Summary Report */

%MACRO BSLN_SUMMARY(QAWORK=WORK);

DATA &QAWORK..BSLN_COPAY_SUMMARY;
	SET &QAWORK..BSLN_COPAY_SUMMARY;
   	BY CHANNEL BG_STATUS PREF_STATUS;
   	IF FIRST.PREF_STATUS = 1 THEN FLAG = 0;
		ELSE FLAG+1;
	IF FLAG >= 23 THEN DO;
      PAGEIT+1; 
      FLAG=0;
    END;
RUN;


FILENAME report1 FTP "&QA_FTPDIR./&INIT._Baseline_Copay_Summary_Report.pdf" USER ="&QA_FTP_USER" PASS ="&QA_FTP_PASS"
		 HOST = "&QA_FTP_HOST"  RCMD = 'SITE UMASK 022' RECFM = F;

ods listing close;
ods pdf file=report1 startpage=on notoc;

ods escapechar "^";
title1 j=l "^S={font_face=Arial
                font_size=14pt
                font_weight=bold FONT_STYLE=ROMAN CELLHEIGHT=30PT}Prescription Savings Guide Audit Report^S={}";

title2 j=l  "^S={font_face=Arial
                font_size=14pt
                font_weight=bold FONT_STYLE=ROMAN  CELLHEIGHT=24PT}Baseline Copay Summary^S={}"
		j=r "^S={font_face=Arial
                font_size=10pt
                font_weight=bold FONT_STYLE=ROMAN CELLHEIGHT=24PT}%sysfunc(date(),WEEKDATE30.)^S={}";



title3 j=l "^S={font_face=Arial
                font_size=12pt
                font_weight=bold FONT_STYLE=ROMAN}Initiative Id: &init.^S={}"

		j=r "^S={font_face=Arial
                font_size=10pt
                font_weight=bold FONT_STYLE=ROMAN}%sysfunc(TIME(),timeampm11.)^S={}";


footnote1 j=c "^S={font_face=Arial
                font_size=9pt
                font_weight=bold FONT_STYLE=ROMAN}Page ^{thispage} of ^{lastpage}^S={}";

%NO_DATA_MSG(&QAWORK..BSLN_COPAY_SUMMARY);						/* AK added 6th September 2011 for report 1 */

%IF OBS_COUNT > 0 %THEN %DO;

	proc report data=&QAWORK..BSLN_COPAY_SUMMARY headskip missing
		style(header)=[font_size   =11pt
                  font_face   =Arial background=none]
		style(report)=[font_size   =10pt
                  font_face   =Arial background=none rules=none frame=void];

	COLUMN CHANNEL PAGEIT BG_STATUS PREF_STATUS DAYS_SUPPLY COPCOINS COINSURANCE COPAY;	
	define CHANNEL / GROUP NOPRINT;
	define PAGEIT / GROUP NOPRINT;
	define BG_STATUS/ GROUP 'BG' '------';
	define PREF_STATUS /GROUP 'Pref Status' '--------------';
	define DAYS_SUPPLY /GROUP 'Days' '-------';
	define COPCOINS/ display 'COPINS:' '--------------';
	define COINSURANCE/ display 'COINSURANCE:' '-----------------------';
	define COPAY/ display 'COPAY:' '-----------';

	break after PAGEIT /page;
	break after BG_STATUS /page;
	break after PREF_STATUS /page;	

	compute before _page_/LEFT style=[background=very light moderate blue font_weight=bold];
		line CHANNEL $6.;
	endcomp;
	RUN;
%END;

quit;
ods pdf close;
ods listing;

%MEND BSLN_SUMMARY;

%BSLN_SUMMARY (QAWORK=&QAWORK.);


/* Baseline CoPay Detail Report */

%MACRO BSLN_DETAIL(QAWORK=WORK);

DATA &QAWORK..BSLN_COPAY_DETAIL_FINAL;
	SET &QAWORK..BSLN_COPAY_DETAIL_FINAL;
   	BY CHANNEL;
	IF _N_ = 1 THEN FLAG = 0;
		ELSE FLAG+1;
	IF FLAG >= 18 THEN DO;
      PAGEIT+1; 
      FLAG=0;
    END;
RUN;


FILENAME report2 FTP "&QA_FTPDIR./&INIT._Baseline_Copay_Detail_Report.pdf" USER ="&QA_FTP_USER" PASS ="&QA_FTP_PASS"
		 HOST = "&QA_FTP_HOST"  RCMD = 'SITE UMASK 022' RECFM = F;


ods listing close;
ods pdf file=report2 startpage=on notoc;

ods escapechar "^";
title1 j=l "^S={font_face=Arial
                font_size=14pt
                font_weight=bold FONT_STYLE=ROMAN CELLHEIGHT=30PT}Prescription Savings Guide Audit Report^S={}";

title2 j=l  "^S={font_face=Arial
                font_size=14pt
                font_weight=bold FONT_STYLE=ROMAN  CELLHEIGHT=12PT}Baseline Copay Detail^S={}"
		j=r "^S={font_face=Arial
                font_size=10pt
                font_weight=bold FONT_STYLE=ROMAN CELLHEIGHT=12PT}%sysfunc(date(),WEEKDATE30.)^S={}";



title3 j=l "^S={font_face=Arial
                font_size=10pt
                font_weight=bold FONT_STYLE=Italic CELLHEIGHT=24PT}Up to 10 Example Records from Each Copay Level^S={}"
		j=r "^S={font_face=Arial
                font_size=10pt
                font_weight=bold FONT_STYLE=ROMAN}%sysfunc(TIME(),timeampm11.)^S={}";

title4 j=l "^S={font_face=Arial
                font_size=12pt
                font_weight=bold FONT_STYLE=ROMAN}Initiative Id: &init.^S={}";

footnote1 j=c "^S={font_face=Arial
                font_size=9pt
                font_weight=bold FONT_STYLE=ROMAN}Page ^{thispage} of ^{lastpage}^S={}";

%NO_DATA_MSG(&QAWORK..BSLN_COPAY_DETAIL_FINAL);						/* AK added 6th September 2011 for report 2*/

%IF OBS_COUNT > 0 %THEN %DO;

	proc report data=&QAWORK..BSLN_COPAY_DETAIL_FINAL headskip missing
		style(header)=[font_size   =11pt
                  font_face   =Arial background=none]
		style(report)=[font_size   =10pt
                  font_face   =Arial background=none rules=NONE frame=void] MISSING;

	COLUMN CHANNEL PAGEIT BG_STATUS PREF_STATUS MBR_ID DAYS_SUPPLY BSLNE_NDC_CODE BSLNE_NDC_DESC COPCOINS COINSURANCE COPAY;
	
	define CHANNEL / group NOPRINT;
	define PAGEIT / group NOPRINT;
	define BG_STATUS/ GROUP 'BG' '------' Center;
	define PREF_STATUS /GROUP 'Pref Status' '--------------';
	define MBR_ID /display 'Member Id' '---------------';
	define DAYS_SUPPLY /GROUP 'DS' '------' Center;
	define BSLNE_NDC_CODE / display 'NDC' '---------';
	define BSLNE_NDC_DESC / display 'Drug Name' '-----------------';
	define COPCOINS/ group 'Copay Type' '----------------' ;
	define COINSURANCE/ GROUP 'COINS:' '---------------';
	define COPAY/ GROUP 'COPAY:' '------------' Center;
	break after PAGEIT /page;
	compute before _page_/LEFT
	style=[background=very light moderate blue font_weight=bold];
		line channel $6.;
	endcomp;
	COMPUTE AFTER COPAY/style=[background=NONE font_weight=bold JUST=R];
	LINE '-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------';
	ENDCOMP;
	
	RUN;
%END;

quit;
ods pdf close;
ods listing;

%MEND BSLN_DETAIL;

%BSLN_DETAIL (QAWORK=&QAWORK.);


/* DRUG No Alternative Report */

%MACRO DRUG_NOALT (QAWORK=WORK);


FILENAME report3 FTP "&QA_FTPDIR./&INIT._Drug_No_Alternatives_Report.pdf" USER ="&QA_FTP_USER" PASS ="&QA_FTP_PASS"
		 HOST = "&QA_FTP_HOST"  RCMD = 'SITE UMASK 022' RECFM = F;


ods listing close;
ods pdf file=report3 startpage=on notoc;

ods escapechar "^";
title1 j=l "^S={font_face=Arial
                font_size=14pt
                font_weight=bold foreground=light blue FONT_STYLE=ROMAN CELLHEIGHT=30PT}Prescription Savings Guide Audit Report^S={}";

title2 j=l  "^S={font_face=Arial
                font_size=14pt
                font_weight=bold foreground=light blue FONT_STYLE=ROMAN  CELLHEIGHT=24PT}Drug Alternatives Details - No Alternatives Recommended^S={}";
	

title3 j=l "^S={font_face=Arial
                font_size=12pt
                font_weight=bold foreground=light blue FONT_STYLE=ROMAN}Initiative Id: &init.^S={}";


footnote1 j=r "^S={font_face=Arial
                font_size=10pt
                font_weight=bold}%sysfunc(date(),WEEKDATE30.)^S={}"
		j=c "^S={font_face=Arial
                font_size=9pt
                font_weight=bold FONT_STYLE=ROMAN}Page ^{thispage} of ^{lastpage}^S={}";

footnote2 j=r "^S={font_face=Arial
                font_size=10pt
                font_weight=bold}%sysfunc(TIME(),timeampm11.)^S={}";

%NO_DATA_MSG(&QAWORK..DRUG_NO_ALT);						/*  AK added 6th September 2011 for report 3 */

%IF OBS_COUNT > 0 %THEN %DO;

	proc report data=&QAWORK..DRUG_NO_ALT headskip missing
		style(header)=[font_size   =11pt
                  font_face   =Arial background=none foreground=light blue]
		style(report)=[font_size   =9pt
                  font_face   =Arial background=none rules=NONE frame=void];

	COLUMN BST_FLGHT_DRUG_IND BST_FLGHT_DRUG_CAT BSLNE_GNRC_IND PRFD_STUS_IND BSLNE_NDC_DESC;	
	define BST_FLGHT_DRUG_IND / Group 'Best Flight' '-----------' ;
	define BST_FLGHT_DRUG_CAT / display 'Best Flight Description' '--------------------';
	define BSLNE_GNRC_IND /display 'Gen Ind' '-------------';
	define PRFD_STUS_IND /display 'Pref Ind' '-------------';
	define BSLNE_NDC_DESC / display 'Baseline Drug Description' '--------------------------------------';

	break after BST_FLGHT_DRUG_IND /page;
	RUN;
%END;

quit;
ods pdf close;
ods listing;

%MEND DRUG_NOALT;

%DRUG_NOALT (QAWORK=&QAWORK.);


/* Drug No Altenatives Without Generices */

%MACRO DRUG_NOALT_GNRC (QAWORK=WORK);


FILENAME report4 FTP "&QA_FTPDIR./&INIT._Drug_No_Alternatives_Report_NO_Generics.pdf" USER ="&QA_FTP_USER" PASS ="&QA_FTP_PASS"
HOST = "&QA_FTP_HOST"  RCMD = 'SITE UMASK 022' RECFM = F;


ods listing close;
ods pdf file=report4 startpage=on notoc;

ods escapechar "^";
title1 j=l "^S={font_face=Arial
                font_size=14pt
                font_weight=bold foreground=light blue FONT_STYLE=ROMAN CELLHEIGHT=30PT}Prescription Savings Guide Audit Report^S={}";

title2 j=l  "^S={font_face=Arial
                font_size=14pt
                font_weight=bold foreground=light blue FONT_STYLE=ROMAN  CELLHEIGHT=24PT}Drug Alternatives Details - No Alternatives Recommended^S={}";
	

title3 j=l "^S={font_face=Arial
                font_size=12pt
                font_weight=bold foreground=light blue FONT_STYLE=ROMAN}Initiative Id: &init.^S={}"
		j=R "^S={font_face=Arial
                font_size=9pt
                font_weight=bold foreground=brown FONT_STYLE=ITALIC}No Generics^S={}";

footnote1 j=r "^S={font_face=Arial
                font_size=10pt
                font_weight=bold}%sysfunc(date(),WEEKDATE30.)^S={}"
		j=c "^S={font_face=Arial
                font_size=9pt
                font_weight=bold FONT_STYLE=ROMAN}Page ^{thispage} of ^{lastpage}^S={}";

footnote2 j=r "^S={font_face=Arial
                font_size=10pt
                font_weight=bold}%sysfunc(TIME(),timeampm11.)^S={}";

%NO_DATA_MSG(&QAWORK..DRUG_NO_GENERIC);						/*  AK added 6th September 2011 for report 4 */

%IF OBS_COUNT > 0 %THEN %DO;

	proc report data=&QAWORK..DRUG_NO_GENERIC headskip missing
		style(header)=[font_size   =11pt
                  font_face   =Arial background=none foreground=light blue]
		style(report)=[font_size   =9pt
                  font_face   =Arial background=none rules=NONE frame=void];

	COLUMN BST_FLGHT_DRUG_IND BST_FLGHT_DRUG_CAT BSLNE_GNRC_IND PRFD_STUS_IND BSLNE_NDC_DESC;	
	define BST_FLGHT_DRUG_IND / Group 'Best Flight' '-----------' ;
	define BST_FLGHT_DRUG_CAT / display 'Best Flight Description' '--------------------';
	define BSLNE_GNRC_IND /display 'Gen Ind' '-------------';
	define PRFD_STUS_IND /display 'Pref Ind' '-------------';
	define BSLNE_NDC_DESC / display 'Baseline Drug Description' '--------------------------------------';

	break after BST_FLGHT_DRUG_IND /page;
	RUN;
%END;

quit;
ods pdf close;
ods listing;

%MEND DRUG_NOALT_GNRC;

%DRUG_NOALT_GNRC (QAWORK=&QAWORK.);


/* Drug Alternatives Report */

%MACRO DRUG_ALT (QAWORK=WORK);


FILENAME report5 FTP "&QA_FTPDIR./&INIT._Drug_Alternatives_Report.pdf" USER ="&QA_FTP_USER" PASS ="&QA_FTP_PASS"
		 HOST = "&QA_FTP_HOST"  RCMD = 'SITE UMASK 022' RECFM = F;


ods listing close;
ods pdf file=report5 startpage=on notoc;

ods escapechar "^";
title1 j=l "^S={font_face=Arial
                font_size=14pt
                font_weight=bold foreground=light blue FONT_STYLE=ROMAN CELLHEIGHT=30PT}Prescription Savings Guide Audit Report^S={}";

title2 j=l  "^S={font_face=Arial
                font_size=14pt
                font_weight=bold foreground=light blue FONT_STYLE=ROMAN  CELLHEIGHT=24PT}Drug Alternatives Details - Alternatives Recommended^S={}";
	

title3 j=l "^S={font_face=Arial
                font_size=12pt
                font_weight=bold foreground=light blue FONT_STYLE=ROMAN}Initiative Id: &init.^S={}";


footnote1 j=r "^S={font_face=Arial
                font_size=10pt
                font_weight=bold}%sysfunc(date(),WEEKDATE30.)^S={}"
		j=c "^S={font_face=Arial
                font_size=9pt
                font_weight=bold FONT_STYLE=ROMAN}Page ^{thispage} of ^{lastpage}^S={}";

footnote2 j=r "^S={font_face=Arial
                font_size=10pt
                font_weight=bold}%sysfunc(TIME(),timeampm11.)^S={}";

%NO_DATA_MSG(&QAWORK..DRUG_ALT_RCMND);						/* AK added 6th September 2011 for report 5*/

%IF OBS_COUNT > 0 %THEN %DO;

	proc report data=&QAWORK..DRUG_ALT_RCMND headskip missing
		style(header)=[font_size   =11pt
                  font_face   =Arial background=none foreground=light blue]
		style(report)=[font_size   =9pt
                  font_face   =Arial background=none rules=ROWS frame=void BORDERCOLOR=light blue];
	COLUMN BSLNE_GNRC_IND PRFD_STUS_IND BSLNE_NDC_DESC BST_FLGHT_DRUG_IND BST_FLGHT_DRUG_CAT ALTRV_NDC_DESC;	
	define BST_FLGHT_DRUG_IND / Group 'Best Flight';
	define BST_FLGHT_DRUG_CAT / display 'Best Flight Description';
	define BSLNE_GNRC_IND /display 'Gen Ind' ;
	define PRFD_STUS_IND /display 'Pref Ind' ;
	define BSLNE_NDC_DESC / display 'Baseline Drug Name' ;
	define ALTRV_NDC_DESC / display 'Alternative Drug Name';

	break after BST_FLGHT_DRUG_IND /page;
	RUN;
%END;

quit;
ods pdf close;
ods listing;

%MEND DRUG_ALT;
%DRUG_ALT (QAWORK=&QAWORK.);
/* Drug Alternative Not Including Multi-Source Brands */

%MACRO DRUG_ALT_NOMSB (QAWORK=WORK);
FILENAME report6 FTP "&QA_FTPDIR./&INIT._Drug_Alternatives_No_MSBs_Report.pdf" USER ="&QA_FTP_USER" PASS ="&QA_FTP_PASS"
		 HOST = "&QA_FTP_HOST"  RCMD = 'SITE UMASK 022' RECFM = F;

ods listing close;
ods pdf file=report6 startpage=on notoc;

ods escapechar "^";
title1 j=l "^S={font_face=Arial
                font_size=14pt
                font_weight=bold foreground=light blue FONT_STYLE=ROMAN CELLHEIGHT=30PT}Prescription Savings Guide Audit Report^S={}";

title2 j=l  "^S={font_face=Arial
                font_size=14pt
                font_weight=bold foreground=light blue FONT_STYLE=ROMAN  CELLHEIGHT=24PT}Drug Alternatives Details - Alternatives Recommended^S={}";
	

title3 j=l "^S={font_face=Arial
                font_size=12pt
                font_weight=bold foreground=light blue FONT_STYLE=ROMAN}Initiative Id: &init.^S={}"
		j=r "^S={font_face=Arial
                font_size=9pt
                font_weight=bold foreground=brown FONT_STYLE=ITALIC}No MSBs^S={}";


footnote1 j=r "^S={font_face=Arial
                font_size=10pt
                font_weight=bold}%sysfunc(date(),WEEKDATE30.)^S={}"
		j=c "^S={font_face=Arial
                font_size=9pt
                font_weight=bold FONT_STYLE=ROMAN}Page ^{thispage} of ^{lastpage}^S={}";

footnote2 j=r "^S={font_face=Arial
                font_size=10pt
                font_weight=bold}%sysfunc(TIME(),timeampm11.)^S={}";

%NO_DATA_MSG(&QAWORK..DRUG_ALT_NOMSB);						/* AK added 6th September 2011 for report 6 */

%IF OBS_COUNT > 0 %THEN %DO;

	proc report data=&QAWORK..DRUG_ALT_NOMSB headskip missing
		style(header)=[font_size   =11pt
                  font_face   =Arial background=none foreground=light blue]
		style(report)=[font_size   =9pt
                  font_face   =Arial background=none rules=ROWS frame=void BORDERCOLOR=light blue];
	COLUMN BSLNE_GNRC_IND PRFD_STUS_IND BSLNE_NDC_DESC BST_FLGHT_DRUG_IND BST_FLGHT_DRUG_CAT ALTRV_NDC_DESC;	
	define BST_FLGHT_DRUG_IND / Group 'Best Flight';
	define BST_FLGHT_DRUG_CAT / display 'Best Flight Description';
	define BSLNE_GNRC_IND /display 'Gen Ind' ;
	define PRFD_STUS_IND /display 'Pref Ind' ;
	define BSLNE_NDC_DESC / display 'Baseline Drug Name' ;
	define ALTRV_NDC_DESC / display 'Alternative Drug Name';
	break after BST_FLGHT_DRUG_IND /page;
	RUN;
%END;

quit;
ods pdf close;
ods listing;
%MEND DRUG_ALT_NOMSB;

%DRUG_ALT_NOMSB (QAWORK=&QAWORK.);


/* Channel Summary Report */

%MACRO CHANNEL_SUMMARY (QAWORK=WORK);

DATA &QAWORK..CHNL_SUMMARY;
	SET &QAWORK..CHNL_SUMMARY;
    BY BSLNE_CHNL;
    IF FIRST.BSLNE_CHNL = 1 THEN FLAG = 0;
		ELSE FLAG+1;
	IF FLAG >= 23 THEN DO;
       PAGEIT+1; 
       FLAG=0;
    END;
RUN;

proc format;
value $chnfmt  'M'='Mail'
				'R'='Retail';
Run;

FILENAME report7 FTP "&QA_FTPDIR./&INIT._Channel_Summary_Report.pdf" USER ="&QA_FTP_USER" PASS ="&QA_FTP_PASS"
		 HOST = "&QA_FTP_HOST"  RCMD = 'SITE UMASK 022' RECFM = F;


ods listing close;
ods pdf file=report7 startpage=on notoc;

ods escapechar "^";
title1 j=l "^S={font_face=Arial
                font_size=14pt
                font_weight=bold FONT_STYLE=ROMAN CELLHEIGHT=30PT}Prescription Savings Guide Audit Report^S={}";

title2 j=l  "^S={font_face=Arial
                font_size=14pt
                font_weight=bold FONT_STYLE=ROMAN  CELLHEIGHT=24PT}Channel Alternatives Summary^S={}"
		j=r "^S={font_face=Arial
                font_size=10pt
                font_weight=bold FONT_STYLE=ROMAN CELLHEIGHT=12PT}%sysfunc(date(),WEEKDATE30.)^S={}";
	

title3 j=l "^S={font_face=Arial
                font_size=12pt
                font_weight=bold FONT_STYLE=ROMAN}Initiative Id: &init.^S={}"
		j=r "^S={font_face=Arial
                font_size=10pt
                font_weight=bold FONT_STYLE=ROMAN}%sysfunc(TIME(),timeampm11.)^S={}";

footnote1 j=c "^S={font_face=Arial
                font_size=9pt
                font_weight=bold FONT_STYLE=ROMAN}Page ^{thispage} of ^{lastpage}^S={}";

%NO_DATA_MSG(&QAWORK..CHNL_SUMMARY);						/* AK added 6th September 2011 for report 7 */

%IF OBS_COUNT > 0 %THEN %DO;

	proc report data=&QAWORK..CHNL_SUMMARY headskip missing
		style(header)=[font_size   =11pt
                  font_face   =Arial background=none]
		style(report)=[font_size   =8pt
                  font_face   =Arial background=none rules=rows frame=void linethickness=0];

	COLUMN BSLNE_CHNL PAGEIT BSLNE_MAINT_DRUG_IND BSLNE_CNTRLD_SBSTNCS_IND BSLNE_SPCLTY_DRUG_IND BSLNE_ACUT_DRUG_IND BST_FLGHT_CHNL_IND DAYS_SUPPLY;	
	define BSLNE_CHNL / group format=$CHNFMT. 'Channel'
							style(column)=[background=very light moderate blue rules=none];
	define PAGEIT / GROUP NOPRINT;
	define BSLNE_MAINT_DRUG_IND / display 'Maint';
	define BSLNE_CNTRLD_SBSTNCS_IND / display 'Cntrld';
	define BSLNE_SPCLTY_DRUG_IND /display 'Spec';
	define BSLNE_ACUT_DRUG_IND /display 'Acute';
	define BST_FLGHT_CHNL_IND /display 'Best Flight';
	define DAYS_SUPPLY /display 'Days Supply';
	break after PAGEIT /page;
	break after BSLNE_CHNL /page;
	RUN;
%END;

quit;
ods pdf close;
ods listing;

%MEND CHANNEL_SUMMARY;

%CHANNEL_SUMMARY (QAWORK=&QAWORK.);


/* Reject Summary Report */

%MACRO REJECT_SUMMARY (QAWORK=WORK);


FILENAME report8 FTP "&QA_FTPDIR./&INIT._Reject_Summary_Report.pdf" USER ="&QA_FTP_USER" PASS ="&QA_FTP_PASS"
		 HOST = "&QA_FTP_HOST"  RCMD = 'SITE UMASK 022' RECFM = F;


ods listing close;
ods pdf file=report8 startpage=on notoc;

ods escapechar "^";
title1 j=l "^S={font_face=Arial
                font_size=14pt
                font_weight=bold FONT_STYLE=ROMAN CELLHEIGHT=30PT}Prescription Savings Guide Audit Report^S={}";
title2 j=l  "^S={font_face=Arial
                font_size=14pt
                font_weight=bold FONT_STYLE=ROMAN  CELLHEIGHT=24PT}Reject Summary^S={}"
		j=r "^S={font_face=Arial
                font_size=10pt
                font_weight=bold FONT_STYLE=ROMAN CELLHEIGHT=24PT}%sysfunc(date(),WEEKDATE30.)^S={}";



title3 j=l "^S={font_face=Arial
                font_size=12pt
                font_weight=bold FONT_STYLE=ROMAN}Initiative Id: &init.^S={}"

		j=r "^S={font_face=Arial
                font_size=10pt
                font_weight=bold FONT_STYLE=ROMAN}%sysfunc(TIME(),timeampm11.)^S={}";


footnote1 j=c "^S={font_face=Arial
                font_size=9pt
                font_weight=bold FONT_STYLE=ROMAN}Page ^{thispage} of ^{lastpage}^S={}";

%NO_DATA_MSG(&QAWORK..REJECT_SUMMARY);					/* AK added 6th September 2011 for report 8 */

%IF OBS_COUNT > 0 %THEN %DO;

	proc report data=&QAWORK..REJECT_SUMMARY headskip missing
		style(header)=[font_size   =11pt
                  font_face   =Arial background=none]
		style(report)=[font_size   =8pt
                  font_face   =Arial background=none rules=none frame=void linethickness=1] MISSING;

	COLUMN RJCT_CD1 MSG_1 BSLNE_IND RJCT_CD_CNT ;	
	define RJCT_CD1 / group 'Reject Code' CENTER;
	define MSG_1 /group 'Message';
	define BSLNE_IND / group 'Baseline' CENTER;
	define RJCT_CD_CNT / display 'Count' CENTER;
	COMPUTE AFTER MSG_1/style=[background=NONE font_weight=bold JUST=C];
	LINE '---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------';
	ENDCOMP;
	RUN;
%END;

quit;

ods pdf close;
ods listing;

%MEND REJECT_SUMMARY;

%REJECT_SUMMARY (QAWORK=&QAWORK.);


/* Bypasss Flag Summary Report */

%MACRO BYPASS_FLAG_SUMMARY (QAWORK=WORK);

DATA BYPASS_SUMMARY_TMP(KEEP = MBR BASE MSG BSLN_PA_BP BSLN_FILL_BP BSLN_STEP_BP ALT_PA_BP ALT_FILL_BP ALT_STEP_BP);
	SET &QAWORK..BYPASS_FLAG_SUMMARY;
	LENGTH MBR $35 BASE $200 MSGS $50;
	MBR='MBR ID: '||MBR_ID;
	BASE='Base: '||TRIM(BSLNE_NDC_CODE)||'    '||TRIM(BSLNE_NDC_DESC)||'^n'||'Alt:   '||TRIM(ALTRV_NDC_CODE)||'    '||TRIM(ALTRV_NDC_DESC);
	MSG='MSGS: '||MDULE_200||'  '||MDULE_201||'  '||MDULE_202||'  '||MDULE_203||'  '||MDULE_204||'  '||MDULE_205;
RUN;

PROC SORT DATA=BYPASS_SUMMARY_TMP;
	BY BSLN_PA_BP BSLN_FILL_BP BSLN_STEP_BP ALT_PA_BP ALT_FILL_BP ALT_STEP_BP MBR;
RUN;

data BYPASS_SUMMARY_FINAL (DROP=OBS);
 	set BYPASS_SUMMARY_TMP;
	BY BSLN_PA_BP BSLN_FILL_BP BSLN_STEP_BP ALT_PA_BP ALT_FILL_BP ALT_STEP_BP;
 	if first.ALT_STEP_BP then obs=1;
 	else obs+1;
 	if obs le 10 then output;
run;


FILENAME report9 FTP "&QA_FTPDIR./&INIT._Bypass_Flags_Summary_Report.pdf" USER ="&QA_FTP_USER" PASS ="&QA_FTP_PASS"
		 HOST = "&QA_FTP_HOST"  RCMD = 'SITE UMASK 022' RECFM = F;


ods listing close;
ods pdf file=report9 style=sasdocprinter startpage=on notoc;

ods escapechar "^";
title1 j=l "^S={font_face=Arial
                font_size=14pt
                font_weight=bold FONT_STYLE=ROMAN CELLHEIGHT=30PT}Prescription Savings Guide Audit Report^S={}";

title2 j=l  "^S={font_face=Arial
                font_size=14pt
                font_weight=bold FONT_STYLE=ROMAN  CELLHEIGHT=24PT}Bypass Flag Messaging Report^S={}"
		j=r "^S={font_face=Arial
                font_size=10pt
                font_weight=bold FONT_STYLE=ROMAN CELLHEIGHT=24PT}%sysfunc(date(),WEEKDATE30.)^S={}";


title3 j=l "^S={font_face=Arial
                font_size=10pt
                font_weight=bold FONT_STYLE=Italic CELLHEIGHT=24PT}Up to 10 Examples^S={}"
		j=r "^S={font_face=Arial
                font_size=10pt
                font_weight=bold FONT_STYLE=ROMAN}%sysfunc(TIME(),timeampm11.)^S={}";

title4 j=l "^S={font_face=Arial
                font_size=12pt
                font_weight=bold FONT_STYLE=ROMAN}Initiative Id: &init.^S={}";

footnote1 j=c "^S={font_face=Arial
                font_size=9pt
                font_weight=bold FONT_STYLE=ROMAN}Page ^{thispage} of ^{lastpage}^S={}";

%NO_DATA_MSG(BYPASS_SUMMARY_FINAL);						/* AK added 6th September 2011 for report 9 */

%IF OBS_COUNT > 0 %THEN %DO;

	proc report data=BYPASS_SUMMARY_FINAL headskip
		style(header)=[font_size   =11pt
                  font_face   =Arial background=none]
		style(report)=[font_size   =10pt
                  font_face   =Arial background=none rules=rows frame=void] missing;

	COLUMN MBR BASE MSG BSLN_PA_BP BSLN_FILL_BP BSLN_STEP_BP ALT_PA_BP ALT_FILL_BP ALT_STEP_BP;	
	DEFINE BSLN_PA_BP/GROUP NOPRINT;
	DEFINE BSLN_FILL_BP/GROUP NOPRINT;
	DEFINE BSLN_STEP_BP/GROUP NOPRINT;
	DEFINE ALT_PA_BP/GROUP NOPRINT;
	DEFINE ALT_FILL_BP/GROUP NOPRINT;
	DEFINE ALT_STEP_BP/GROUP NOPRINT;
	DEFINE MBR /DISPLAY '';
	DEFINE BASE /DISPLAY '' flow;
	DEFINE MSG /DISPLAY '' width=16;

	break after ALT_STEP_BP /page;
	compute before _page_/LEFT style=[background=very light moderate blue font_weight=bold];
		LINE 'Baseline PA BP  Baseline Fill BP  Baseline Step BP  ALT PA BP  ALT Fill BP  ALT Step BP';
		line "^S={just=l}              " 
			BSLN_PA_BP $1. "                    " 
			BSLN_FILL_BP $1. "                        " 
			BSLN_STEP_BP $1. "                            " 
			ALT_PA_BP $1. "               " 
			ALT_FILL_BP $1. "                     " 
			ALT_STEP_BP $1. " ";
	endcomp;
	RUN;
%END;

quit;
ods pdf close;
ods listing;

%MEND BYPASS_FLAG_SUMMARY;

%BYPASS_FLAG_SUMMARY (QAWORK=&QAWORK.);


/* Outlier Report */

%MACRO OUTLIER (QAWORK=WORK);

%GLOBAL MBR_MAX_SAV
MAX_MBR_SAV
MBR_MIN_SAV
MIN_MBR_SAV
MBR_MAX_BSLN_DRG
MAX_BSLN_DRG
MBR_Min_BSLN_DRG
Min_BSLN_DRG
MBR_MAX_CLAIM_REJ
MAX_CLAIM_REJ
MBR_MAX_BYPASS_FLAG
MAX_BYPASS_FLAG
MBR_MAX_COPAY_AMT
MAX_COPAY_AMT
MBR_MAX_TOT_AMT
MAX_TOT_AMT
MBR_MAX_BSLN_DRG_BF
MAX_BSLN_DRG_BF
MBR_MAX_BSLN_DRG_NOTBF
MAX_BSLN_DRG_NOTBF;


* Identify Member having maximum savings;
proc sql outobs=1 noprint;
	select mbr_id, 
		mbr_Sav FORMAT 10.2
		into : MBR_MAX_SAV, :MAX_MBR_SAV
	from &QAWORK..COST_OUTLIER
	having mbr_Sav=(select max(mbr_sav) from &QAWORK..COST_OUTLIER);
quit;

* Identify Member having minimum savings;
proc sql outobs=1 noprint;
	select mbr_id, 
		mbr_Sav FORMAT 10.2
		into :MBR_MIN_SAV, :MIN_MBR_SAV
	from &QAWORK..COST_OUTLIER
	having mbr_Sav=(select MIN(mbr_sav) from &QAWORK..COST_OUTLIER);
quit;

* Identify Member having maximum Copay Amount;
proc sql outobs=1 noprint;
	select mbr_id, 
		COPAY_AMT FORMAT 10.2
	into : MBR_MAX_COPAY_AMT, :MAX_COPAY_AMT
	from &QAWORK..COST_OUTLIER 
	having COPAY_AMT=(select MAX(COPAY_AMT) from &QAWORK..COST_OUTLIER);
quit;

* Identify Member having maximum Plan Paid Amount;
proc sql outobs=1 noprint;
	select mbr_id, 
		BSLNE_TOT_AMT FORMAT 10.2 
		into : MBR_MAX_TOT_AMT, :MAX_TOT_AMT
	from &QAWORK..COST_OUTLIER 
	having BSLNE_TOT_AMT=(select MAX(BSLNE_TOT_AMT) from &QAWORK..COST_OUTLIER);
quit;


*Identify member having highest # of Baseline drugs (At Best Flight);
proc sql outobs=1 noprint;
	select mbr_id, 
		NDC_CNT_BF FORMAT 10.0
		into : MBR_MAX_BSLN_DRG_BF, :MAX_BSLN_DRG_BF
	from &QAWORK..COST_OUTLIER 
	having NDC_CNT_BF=(select Max(NDC_CNT_BF) from &QAWORK..COST_OUTLIER);
quit;

*Identify member having highest # of Baseline drugs (Not At Best Flight);
proc sql outobs=1 noprint;
	select mbr_id, 
		NDC_CNT_NTBF FORMAT 10.0
		into : MBR_MAX_BSLN_DRG_NOTBF, :MAX_BSLN_DRG_NOTBF
	from &QAWORK..COST_OUTLIER 
	having NDC_CNT_NTBF=(select Max(NDC_CNT_NTBF) from &QAWORK..COST_OUTLIER);
quit;

* Identify Member having highest # NDCs;
proc sql outobs=1 noprint;
	select mbr_id, 
		ndc_cnt FORMAT 10.0
	into : MBR_MAX_BSLN_DRG, :MAX_BSLN_DRG
	from &QAWORK..NDC_OUTLIER 
	having ndc_cnt=(select max(ndc_cnt) from &QAWORK..NDC_OUTLIER);
quit;

* Identify Member having lowest # NDCs;
proc sql outobs=1 noprint;
	select mbr_id, 
		ndc_cnt FORMAT 10.0
		into : MBR_MIN_BSLN_DRG, :MIN_BSLN_DRG
	from &QAWORK..NDC_OUTLIER 
	having ndc_cnt=(select min(ndc_cnt) from &QAWORK..NDC_OUTLIER);
quit;

* Identify Member having highest # of Claim Rejects;
proc sql outobs=1 noprint;
	select mbr_id, 
		ndc_cnt FORMAT 10.0
		into : MBR_MAX_CLAIM_REJ, :MAX_CLAIM_REJ
	from &QAWORK..BYPASSNDC 
	having ndc_cnt=(select max(ndc_cnt) from &QAWORK..BYPASSNDC);
quit;

* Identify Member having highest # of Bypass Flags;

proc sql outobs=1 noprint;
	select mbr_id, 
		SUM_BYP_FLG FORMAT 10.0
		into : MBR_MAX_BYPASS_FLAG, :MAX_BYPASS_FLAG
	from &QAWORK..BYPASSFLGCNT 
	having SUM_BYP_FLG=(select max(SUM_BYP_FLG) from &QAWORK..BYPASSFLGCNT);
quit;


DATA OUTLIER1;
LENGTH MBRCOL $80 MBRNUM $30 TAGCOL $15 VALCOL $20;
MBRCOL			='MBR ID for Highest Savings:';
MBRNUM          =SYMGET('MBR_MAX_SAV');
TAGCOL          ='Savings:';
VALCOL			=SYMGET('MAX_MBR_SAV');
RUN;

DATA OUTLIER2;
LENGTH MBRCOL $80 MBRNUM $30 TAGCOL $15 VALCOL $20;
MBRCOL			='MBR ID for Lowest Savings:';
MBRNUM          =SYMGET('MBR_MIN_SAV');
TAGCOL          ='Savings:';
VALCOL			=SYMGET('MIN_MBR_SAV');
RUN;

DATA OUTLIER3;
LENGTH MBRCOL $80 MBRNUM $30 TAGCOL $15 VALCOL $20;
MBRCOL			='MBR ID for Highest # of Baseline Drugs:';
MBRNUM          =SYMGET('MBR_MAX_BSLN_DRG');
TAGCOL          ='Count:';
VALCOL			=SYMGET('MAX_BSLN_DRG');
RUN;

DATA OUTLIER4;
LENGTH MBRCOL $80 MBRNUM $30 TAGCOL $15 VALCOL $20;
MBRCOL			='MBR ID for Lowest # of Baseline Drugs :';
MBRNUM          =SYMGET('MBR_MIN_BSLN_DRG');
TAGCOL          ='Count:';
VALCOL			=SYMGET('MIN_BSLN_DRG');
RUN;


DATA OUTLIER5;
LENGTH MBRCOL $80 MBRNUM $30 TAGCOL $15 VALCOL $20;
MBRCOL			='MBR ID for Highest # of Claim Rejects:';
MBRNUM          =SYMGET('MBR_MAX_CLAIM_REJ');
TAGCOL          ='Count:';
VALCOL			=SYMGET('MAX_CLAIM_REJ');
RUN;

DATA OUTLIER6;
LENGTH MBRCOL $80 MBRNUM $30 TAGCOL $15 VALCOL $20;
MBRCOL			='MBR ID for Highest # of Bypass Flags:';
MBRNUM          =SYMGET('MBR_MAX_BYPASS_FLAG');
TAGCOL          ='Count:';
VALCOL			=SYMGET('MAX_BYPASS_FLAG');
RUN;

DATA OUTLIER7;
LENGTH MBRCOL $80 MBRNUM $30 TAGCOL $15 VALCOL $20;
MBRCOL			='MBR ID for Highest Out of Pocket Cost:';
MBRNUM          =SYMGET('MBR_MAX_COPAY_AMT');
TAGCOL          ='Cost:';
VALCOL			=SYMGET('MAX_COPAY_AMT');
RUN;

DATA OUTLIER8;
LENGTH MBRCOL $80 MBRNUM $30 TAGCOL $15 VALCOL $20;
MBRCOL			='MBR ID for Highest Plan Paid Cost:';
MBRNUM          =SYMGET('MBR_MAX_TOT_AMT');
TAGCOL          ='Cost:';
VALCOL			=SYMGET('MAX_TOT_AMT');
RUN;

DATA OUTLIER9;
LENGTH MBRCOL $80 MBRNUM $30 TAGCOL $15 VALCOL $20;
MBRCOL			='MBR ID for Highest # of Baseline Drugs Designated as Best Flight:';
MBRNUM          =SYMGET('MBR_MAX_BSLN_DRG_BF');
TAGCOL          ='Count:';
VALCOL			=SYMGET('MAX_BSLN_DRG_BF');
RUN;

DATA OUTLIER10;
LENGTH MBRCOL $80 MBRNUM $30 TAGCOL $15 VALCOL $20;
MBRCOL			='MBR ID for Highest # of Baseline Drugs Designated as Not Best Flight:';
MBRNUM          =SYMGET('MBR_MAX_BSLN_DRG_NOTBF');
TAGCOL          ='Count:';
VALCOL			=SYMGET('MAX_BSLN_DRG_NOTBF');
RUN;

DATA OUTLIER;
SET OUTLIER1 OUTLIER2
	OUTLIER3 OUTLIER4
	OUTLIER5 OUTLIER6
	OUTLIER7 OUTLIER8
	OUTLIER9 OUTLIER10;
RUN;


FILENAME report10 FTP "&QA_FTPDIR./&INIT._Outlier_Report.pdf" USER ="&QA_FTP_USER" PASS ="&QA_FTP_PASS"
		 HOST = "&QA_FTP_HOST"  RCMD = 'SITE UMASK 022' RECFM = F;


ods listing close;
ods pdf file=report10 startpage=on notoc;

ods escapechar "^";
title1 j=l "^S={font_face=Arial
                font_size=14pt
                font_weight=bold FONT_STYLE=ROMAN CELLHEIGHT=30PT}Prescription Savings Guide Audit Report^S={}";

title2 j=l  "^S={font_face=Arial
                font_size=14pt
                font_weight=bold FONT_STYLE=ROMAN  CELLHEIGHT=24PT}Outlier Report^S={}"
		j=r "^S={font_face=Arial
                font_size=10pt
                font_weight=bold FONT_STYLE=ROMAN CELLHEIGHT=24PT}%sysfunc(date(),WEEKDATE30.)^S={}";


title3 j=l "^S={font_face=Arial
                font_size=12pt
                font_weight=bold FONT_STYLE=ROMAN}Initiative Id: &init.^S={}"
		j=r "^S={font_face=Arial
                font_size=10pt
                font_weight=bold FONT_STYLE=ROMAN}%sysfunc(TIME(),timeampm11.)^S={}";

footnote1 j=c "^S={font_face=Arial
                font_size=9pt
                font_weight=bold FONT_STYLE=ROMAN}Page ^{thispage} of ^{lastpage}^S={}";

%NO_DATA_MSG(OUTLIER);					/* AK added 6th September 2011 for report 10 */

%IF OBS_COUNT > 0 %THEN %DO;

	PROC REPORT DATA=outlier headskip noheader missing
		style(report)=[font_size   =14pt  CELLHEIGHT=30PT 
					font_weight=bold
                  font_face   =Arial background=none rules=none frame=void];
	COLUMN MBRCOL MBRNUM TAGCOL VALCOL;	
	DEFINE	MBRCOL/DISPLAY WIDTH=80 LEFT;
	DEFINE  MBRNUM/DISPLAY WIDTH=30 LEFT;
	DEFINE  TAGCOL/DISPLAY WIDTH=15 LEFT;
	DEFINE	VALCOL/DISPLAY WIDTH=20 RIGHT;
	RUN;
%END;

QUIT;
ODS PDF CLOSE;
ods listing;

%MEND OUTLIER;

%OUTLIER (QAWORK=&QAWORK.);


/*%END; End initiatives loop;*/

* Notify Business Users;

FILENAME MYMAIL EMAIL 'qcpap020@prdsas1';		

	 DATA _NULL_;
	    FILE MYMAIL
		TO =(&IBEN3_email_all.)
		SUBJECT	='MSS QA REPORTS: Request for Prescription Savings Guide 3.0 Audit Report.'; 								
	   
		PUT / 'Hello:' ;
	    PUT / "This is an automatically generated message to inform you that PSG Audit reports are generated. Reports are available in Patient List drive.";
	    PUT / "Initiative IDs = &INIT. ";
	    PUT / "Feel free to contact Hercules.Support@Caremark.com with any questions or concerns.";
	    PUT / 'Thanks,';
	    PUT / 'Hercules Support';
	 RUN;
	 QUIT;

/*%EXIT_PROCESS:;*/
ODS PDF CLOSE;
ODS LISTING;

%MEND GENERATE_MSS_QA_REPORTS;
