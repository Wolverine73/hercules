/**HEADER------------------------------------------------------------------------------------
|
| PROGRAM NAME: RESOLVE_CLIENT_GSTP.SAS
|
| CALL REFERENCE: RESOLVE_CLIENT_GSTP IS CALLED BY GSTP.SAS
|
| PURPOSE:
|       DETERMINING THE CLIENTS AND THEIR ALGN_LVL_GIDS TO BE INCLUDED OR EXCLUDED
|       IN A MAILING.
|
| INPUT:  
|       MACRO VARIABLES FROM HERCULES_IN.SAS :
|       	INITIATIVE_ID, PROGRAM_ID, TASK_ID, QL_ADJ, RX_ADJ, RE_ADJ,
|			DFL_CLT_INC_EXU_IN, OVRD_CLT_SETUP_IN, DSPLY_CLT_SETUP_CD,
|			TABLE_PREFIX
|		TABLES :
|			CLIENT SPECIFIC SET-UP
|
| OUTPUT: 
|		TABLE:
|			&TBL_NAME_OUT WITH ALL CLIENT HIERARCHY
|
|------------------------------------------------------------------------------------------
| HISTORY: E.Sliounkova 11/04/2010 Original Version
|
|  10-29-2013  Ray Pileckis 
|  GSTP Batch changes to create dummy QL_MIGR_CLIENTS when there are no QL migr
|
|------------------------------------------------------------------------------------------
+---------------------------------------------------------------------------------*HEADER*/

%MACRO resolve_client_gstp(TBL_NAME_OUT=,STD_IND=);

%LET CC_QL_MIGR_IND=0;
%PUT STD_IND = &STD_IND;

/*%LET PROGRAM_ID = 5295;*/
/*%LET TASK_ID = 57;*/

*SASDOC-------------------------------------------------------------------------
| Macro for fields compare: character fields
+-----------------------------------------------------------------------SASDOC*;
%MACRO BLANK_OR_EQ_DB2(VAR=);
AND ((A.&VAR. IS NULL AND C.&VAR. IS NULL) 
OR (A.&VAR. ='' AND C.&VAR. IS NULL)
OR (A.&VAR. IS NULL AND C.&VAR. ='')
OR (UPPER(TRIM(A.&VAR.)) = UPPER(TRIM(C.&VAR.))))
%MEND;

*SASDOC-------------------------------------------------------------------------
| Macro for fields compare: numeric fields
+-----------------------------------------------------------------------SASDOC*;
%MACRO BLANK_OR_EQ_DB2_NUM(VAR=);
AND ((A.&VAR. IS NULL AND C.&VAR. IS NULL) 
OR (A.&VAR. =0 AND C.&VAR. IS NULL)
OR (A.&VAR. IS NULL AND C.&VAR. =0)
OR (A.&VAR. = C.&VAR.))
%MEND;


*SASDOC-------------------------------------------------------------------------
| Get GSTP Clients QL
+-----------------------------------------------------------------------SASDOC*;


		PROC SQL NOPRINT;
	        CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
			CREATE TABLE QL_CLIENTS AS
	        SELECT * FROM CONNECTION TO DB2
	   		(  SELECT A.CLIENT_ID
                    , CHAR(A.CLIENT_ID) AS CLIENT_ID_CHAR
			        , A.GROUP_CLASS_CD
					, A.GROUP_CLASS_SEQ_NB
					, A.BLG_REPORTING_CD
					, A.PLAN_NM
					, A.PLAN_CD_TX
					, A.PLAN_EXT_CD_TX
					, A.GROUP_CD_TX
					, A.GROUP_EXT_CD_TX
					, 'Q' || TRIM(COALESCE(CHAR(A.CLIENT_ID),''))|| TRIM(COALESCE(CHAR(A.GROUP_CLASS_CD),'')) 
                    || TRIM(COALESCE(CHAR(A.GROUP_CLASS_SEQ_NB),''))
					|| TRIM(COALESCE(A.BLG_REPORTING_CD,'')) || TRIM(COALESCE(A.PLAN_NM,'')) || TRIM(COALESCE(A.PLAN_CD_TX,'')) 
					|| TRIM(COALESCE(A.PLAN_EXT_CD_TX,'')) || TRIM(COALESCE(A.GROUP_CD_TX,'')) || TRIM(COALESCE(A.GROUP_EXT_CD_TX,''))
					AS TARGET_CLIENT_KEY
					, A.CLT_SETUP_DEF_CD
					, A.OVR_CLIENT_NM
					, 'Q' AS SYS_CD
					, A.GSTP_GSA_PGMTYP_CD
				

					FROM &HERCULES..TPGMTASK_QL_RUL A
			  %IF %UPCASE(&STD_IND.) = N %THEN %DO;
			           , &DB2_TMP..&TABLE_PREFIX._GSTP_CSTM_IN C
			  %END;

			WHERE A.PROGRAM_ID = &PROGRAM_ID.
			  AND A.TASK_ID = &TASK_ID.
	
			  %IF %UPCASE(&STD_IND.) = N %THEN %DO;
		  	  AND A.GSTP_GSA_PGMTYP_CD IN (4)
			  AND C.SRC_SYS_CD = 'Q'
			  AND C.CLIENT_ID = A.CLIENT_ID
			  AND C.EFFECTIVE_DT = A.EFFECTIVE_DT
			  %BLANK_OR_EQ_DB2_NUM(VAR=GROUP_CLASS_CD)
			  %BLANK_OR_EQ_DB2_NUM(VAR=GROUP_CLASS_SEQ_NB)
			  %BLANK_OR_EQ_DB2    (VAR=BLG_REPORTING_CD)
			  %BLANK_OR_EQ_DB2    (VAR=PLAN_NM)
			  %BLANK_OR_EQ_DB2    (VAR=PLAN_CD_TX)
			  %BLANK_OR_EQ_DB2    (VAR=PLAN_EXT_CD_TX)
			  %BLANK_OR_EQ_DB2    (VAR=GROUP_CD_TX)
			  %BLANK_OR_EQ_DB2    (VAR=GROUP_EXT_CD_TX)
			  %END;
			  %ELSE %DO;
			  AND A.EFFECTIVE_DT = &IMPL_DT. /*UPDATE LATER*/
			  AND A.GSTP_GSA_PGMTYP_CD IN (1,2,3)
			  %END;
		    WITH UR
			  		);
*SASDOC-------------------------------------------------------------------------
| Get GSTP Clients RECAP
+-----------------------------------------------------------------------SASDOC*;


			CREATE TABLE RE_CLIENTS AS
	        SELECT * FROM CONNECTION TO DB2
	   		(  SELECT A.INSURANCE_CD AS OPT1
			        , SUBSTR(A.CARRIER_ID,2,19)   AS LVL1 
					, A.GROUP_CD     AS LVL3
					, 'R'|| TRIM(COALESCE(A.INSURANCE_CD,'')) ||TRIM(COALESCE(A.CARRIER_ID,''))
                       || TRIM(COALESCE(A.GROUP_CD,''))
					AS TARGET_CLIENT_KEY
					, A.CLT_SETUP_DEF_CD
					, A.OVR_CLIENT_NM
					, 'R' AS SYS_CD
					, A.GSTP_GSA_PGMTYP_CD
					
				

					FROM &HERCULES..TPGMTASK_RECAP_RUL A
			  %IF %UPCASE(&STD_IND.) = N %THEN %DO;
			           , &DB2_TMP..&TABLE_PREFIX._GSTP_CSTM_IN C
			  %END;
			WHERE A.PROGRAM_ID = &PROGRAM_ID.
			  AND A.TASK_ID = &TASK_ID.
			  %IF %UPCASE(&STD_IND.) = N %THEN %DO;
		  	  AND A.GSTP_GSA_PGMTYP_CD IN (4)
			  AND C.SRC_SYS_CD = 'R'
			  AND C.INSURANCE_CD = A.INSURANCE_CD
			  AND C.EFFECTIVE_DT = A.EFFECTIVE_DT
			  %BLANK_OR_EQ_DB2    (VAR=CARRIER_ID)
			  %BLANK_OR_EQ_DB2    (VAR=GROUP_CD)
			  %END;
			  %ELSE %DO;
			  AND A.EFFECTIVE_DT = &IMPL_DT. /*UPDATE LATER*/
			  AND A.GSTP_GSA_PGMTYP_CD IN (1,2,3)
			  %END;
		    WITH UR
			  		);
*SASDOC-------------------------------------------------------------------------
| Get GSTP Clients RxClaim
+-----------------------------------------------------------------------SASDOC*;


			CREATE TABLE RX_CLIENTS AS
	        SELECT * FROM CONNECTION TO DB2
	   		(  SELECT SUBSTR(A.CARRIER_ID,2,19) AS LVL1
			        , A.ACCOUNT_ID AS LVL2
					, A.GROUP_CD   AS LVL3
					, 'X' || TRIM(COALESCE(A.CARRIER_ID,'')) || TRIM(COALESCE(A.ACCOUNT_ID,''))
					|| TRIM(COALESCE(A.GROUP_CD,'')) AS TARGET_CLIENT_KEY
					, A.CLT_SETUP_DEF_CD
					, A.OVR_CLIENT_NM
					,'X' AS SYS_CD
					, A.GSTP_GSA_PGMTYP_CD
								

					FROM &HERCULES..TPGMTASK_RXCLM_RUL A
			  %IF %UPCASE(&STD_IND.) = N %THEN %DO;
			           , &DB2_TMP..&TABLE_PREFIX._GSTP_CSTM_IN C
			  %END;
			WHERE A.PROGRAM_ID = &PROGRAM_ID.
			  AND A.TASK_ID = &TASK_ID.
			  %IF %UPCASE(&STD_IND.) = N %THEN %DO;
		  	  AND A.GSTP_GSA_PGMTYP_CD IN (4)
			  AND C.SRC_SYS_CD = 'X'
			  AND C.CARRIER_ID = A.CARRIER_ID
			  AND C.EFFECTIVE_DT = A.EFFECTIVE_DT
			  %BLANK_OR_EQ_DB2    (VAR=ACCOUNT_ID)
			  %BLANK_OR_EQ_DB2    (VAR=GROUP_CD)
			  %END;
			  %ELSE %DO;
			  AND A.EFFECTIVE_DT = &IMPL_DT. /*UPDATE LATER*/
			  AND A.GSTP_GSA_PGMTYP_CD IN (1,2,3)
			  %END;
		    WITH UR
			  		);

	    	DISCONNECT FROM DB2;

		QUIT;

		%SET_ERROR_FL;

*SASDOC-------------------------------------------------------------------------
| Q2X: TPGMTASK - WE CHECK IF CLIENT MIGRATED FROM QL TO RX 
	AND PREPARE INPUT TABLES TO CALL RESOLVE QL MACRO
+-----------------------------------------------------------------------SASDOC*;

	PROC SQL NOPRINT;
		CREATE TABLE QL_MIGR_CLIENTS_A AS
		SELECT DISTINCT 
				&PROGRAM_ID. AS PROGRAM_ID,
				&TASK_ID. AS TASK_ID, 
				B.SRC_HIER_ALGN_0_ID AS QL_CLIENT_CD,
				INPUT(B.SRC_HIER_ALGN_1_ID, 12.) AS QL_CLIENT_ID,
				INPUT(B.SRC_HIER_ALGN_2_ID, 12.) AS QL_CPG_ID,
				A.CLT_SETUP_DEF_CD,
				A.OVR_CLIENT_NM,
				A.GSTP_GSA_PGMTYP_CD,
				B.SRC_ADJD_CD AS SYS_CD
			FROM RX_CLIENTS A,
				 DSS_CLIN.V_CLNT_CAG_MGRTN B
			WHERE 	   A.LVL1 = B.TRGT_HIER_ALGN_1_ID
/*				  AND (A.LVL2 IS NULL OR TRIM(LEFT(A.LVL2))= TRIM(LEFT(B.TRGT_HIER_ALGN_2_ID) ))*/
/*				  AND (A.LVL3 IS NULL OR TRIM(A.LVL3)= TRIM(B.TRGT_HIER_ALGN_3_ID) )*/
			      AND B.SRC_ADJD_CD ='Q'
				  AND DATEPART(B.MGRTN_EFF_DT) LE TODAY() 
				  AND B.SRC_HIER_ALGN_2_ID IS NOT NULL;

			SELECT COUNT(*) INTO :QL_MGRTN_ROW_CNT 
			FROM QL_MIGR_CLIENTS_A;
	QUIT;


	%IF &QL_MGRTN_ROW_CNT NE 0 %THEN %DO;
	%LET CC_QL_MIGR_IND = 1;

		PROC SQL;
		CREATE TABLE QL_MIGR_CLIENTS AS
		SELECT DISTINCT A.PROGRAM_ID
					,A.TASK_ID
					,A.QL_CLIENT_ID AS CLIENT_ID
					,INPUT(PUT(A.QL_CLIENT_ID, 20.), $20.) AS CLIENT_ID_CHAR
					,A.QL_CPG_ID AS CPG_ID
					,B.BLNG_RPTG_CD AS BLG_REPORTING_CD
	                ,B.PLAN_CD AS PLAN_CD_TX
					,B.PLAN_EXT_CD AS PLAN_EXT_CD_TX
					,B.GRP_CD AS GROUP_CD_TX
					,B.GRP_EXT_CD AS GROUP_EXT_CD_TX
					,A.CLT_SETUP_DEF_CD
					,A.GSTP_GSA_PGMTYP_CD
					,A.OVR_CLIENT_NM
					,A.SYS_CD
				FROM QL_MIGR_CLIENTS_A A, 
				     DSS_CLIN.V_CLNT_CPG_QL_DENORM B
	        	WHERE A.QL_CPG_ID = B.QL_CPG_ID;
		QUIT;

	%END;
/*  GSTP Batch changes to create dummy QL_MIGR_CLIENTS when there are no QL migr start */
	%ELSE %DO ;

		DATA QL_MIGR_CLIENTS ;
			SET	QL_CLIENTS ;
				IF	CLIENT_ID =	0	THEN
					DO	;
						OUTPUT ;
					END ;
		RUN ;
	
	%END;
/*  GSTP Batch changes to create dummy QL_MIGR_CLIENTS when there are no QL migr end */	


*SASDOC-------------------------------------------------------------------------
| Drop and Create Temp DB2 and Oracle Tables that will house client info 
+-----------------------------------------------------------------------SASDOC*;

	%DROP_DB2_TABLE(TBL_NAME=&DB2_TMP..&TABLE_PREFIX._GSTP_LVL1); 
	%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..&TABLE_PREFIX._GSTP_LVL1); 

	PROC SQL;
	 CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	    EXECUTE(CREATE TABLE &DB2_TMP..&TABLE_PREFIX._GSTP_LVL1
		(CLIENT_ID 		INTEGER,
		RPT_OPT1_CD     VARCHAR(3),
		EXTNL_LVL_ID1  			VARCHAR(20),
		SYS_CD           CHAR(1)
		) NOT LOGGED INITIALLY) BY DB2;
	 DISCONNECT FROM DB2;
	QUIT;
	%SET_ERROR_FL;


	DATA RE_CLIENTS_U (RENAME=(OPT1=RPT_OPT1_CD LVL1=EXTNL_LVL_ID1));
	SET RE_CLIENTS;
	RUN;

 	PROC SORT DATA = RE_CLIENTS_U NODUPKEY; BY RPT_OPT1_CD;
    RUN;
	%SET_ERROR_FL;



	DATA ALL_CLNT (KEEP = CLIENT_ID RPT_OPT1_CD EXTNL_LVL_ID1 SYS_CD);
	LENGTH CLIENT_ID 5;
	LENGTH RPT_OPT1_CD $3;
	LENGTH EXTNL_LVL_ID1 $20;
	LENGTH SYS_CD $1;

    SET QL_CLIENTS (RENAME=(CLIENT_ID_CHAR=EXTNL_LVL_ID1))
	    RE_CLIENTS_U 
		RX_CLIENTS (RENAME=(LVL1=EXTNL_LVL_ID1))
		QL_MIGR_CLIENTS (RENAME=(CLIENT_ID_CHAR=EXTNL_LVL_ID1))
		;
	RUN;
	%SET_ERROR_FL;

   PROC SORT DATA = ALL_CLNT NODUPKEY; BY CLIENT_ID RPT_OPT1_CD EXTNL_LVL_ID1 SYS_CD;
   RUN;
	%SET_ERROR_FL;

	PROC SQL;
			INSERT INTO &DB2_TMP..&TABLE_PREFIX._GSTP_LVL1
				SELECT  CLIENT_ID
					   ,RPT_OPT1_CD   
					   ,EXTNL_LVL_ID1  
					   ,SYS_CD

				FROM ALL_CLNT;
				QUIT;
				RUN;

		%SET_ERROR_FL;

	   		PROC SQL NOPRINT;
					CONNECT TO ORACLE(PATH=&GOLD );
		  			EXECUTE 
					(
					CREATE TABLE &ORA_TMP..&TABLE_PREFIX._GSTP_LVL1
					(CLIENT_ID 		NUMBER,
					RPT_OPT1_CD     VARCHAR2(3),
					EXTNL_LVL_ID1  	VARCHAR2(20),
					SYS_CD          VARCHAR2(1)
			
					 )
		  			) BY ORACLE;
		    		DISCONNECT FROM ORACLE;
				QUIT;
				RUN;
		%SET_ERROR_FL;


				PROC SQL;

				INSERT INTO &ORA_TMP..&TABLE_PREFIX._GSTP_LVL1
				SELECT  CLIENT_ID
					   ,RPT_OPT1_CD   
					   ,EXTNL_LVL_ID1  
					   ,SYS_CD  
				     

				FROM ALL_CLNT;
				QUIT;
				RUN; 
		%SET_ERROR_FL; 

*SASDOC-------------------------------------------------------------------------
| Get QL Plan Name Information 
+-----------------------------------------------------------------------SASDOC*;	
		PROC SQL NOPRINT;
	        CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
			CREATE TABLE QL_PLAN_NM AS
	        SELECT * FROM CONNECTION TO DB2
   		(  SELECT A.BENEFACTOR_CLT_ID AS CLIENT_ID
			    , A.PB_LISTING_NM  AS PLAN_NM
				, B.CLT_PLAN_GROUP_ID AS QL_CPG_ID

		   FROM &CLAIMSA..TPBW_TEMP_CNVRT A 
		       ,&CLAIMSA..TCPG_PB_TRL_HIST  B
			   ,&CLAIMSA..TCPGRP_CLT_PLN_GR1 C
			   ,&DB2_TMP..&TABLE_PREFIX._GSTP_LVL1  D

			WHERE A.BENEFACTOR_CLT_ID = D.CLIENT_ID
			  AND D.SYS_CD = 'Q'
			  AND A.BENEFACTOR_CLT_ID = C.CLIENT_ID
			  AND B.CLT_PLAN_GROUP_ID = C.CLT_PLAN_GROUP_ID
			  AND A.POS_PBT_ID = B.PB_ID
			  AND B.DELIVERY_SYSTEM_CD = 3
			  AND B.EFF_DT <= CURRENT DATE
			  AND B.EXP_DT >= CURRENT DATE					
		    WITH UR
			  		);

	    	DISCONNECT FROM DB2;

		QUIT;


/*%let gold=%str(oak user=dss_herc pw=anlt2web);*/

*SASDOC-------------------------------------------------------------------------
| Get QL Information from  DSS_CLIN.V_ALGN_LVL_DENORM
+-----------------------------------------------------------------------SASDOC*;	
			PROC SQL NOPRINT;
		CONNECT TO ORACLE(PATH=&GOLD );
		CREATE TABLE QL_ALGN AS
	        SELECT * FROM CONNECTION TO ORACLE
		(
      	SELECT   ALGN.ALGN_LVL_GID_KEY               AS ALGN_GID, 
  				 ALGN.RPT_OPT1_CD                    AS OPT1,
  				 ALGN.EXTNL_LVL_ID1                  AS LVL1,
  				 ALGN.EXTNL_LVL_ID2                  AS LVL2,
  				 ALGN.EXTNL_LVL_ID3                  AS LVL3,
  				 ALGN.PAYER_ID,
  				 ALGN.CUST_NM,
  				 ALGN.SRC_SYS_CD                    AS SYS_CD
		FROM &DSS_CLIN..V_ALGN_LVL_DENORM ALGN 
		  , &ORA_TMP..&TABLE_PREFIX._GSTP_LVL1 CLNT
		WHERE ALGN.SRC_SYS_CD = 'Q'
		 AND CLNT.SYS_CD = 'Q'
		AND ALGN.EXTNL_LVL_ID1 = CLNT.EXTNL_LVL_ID1
  		);

*SASDOC-------------------------------------------------------------------------
| Get QL CPG ID Information: Billing Reporting Code, Plan Code, Plan Extension
| Code, Group Code, Group Extension Code
+-----------------------------------------------------------------------SASDOC*;		
		CREATE TABLE QL_CPG_ID AS
	      SELECT * FROM CONNECTION TO ORACLE
		(
      	SELECT  QL.QL_CLNT_ID AS CLIENT_ID
		        ,QL.ALGN_LVL_GID AS ALGN_GID
                ,QL.QL_CPG_ID AS QL_CPG_ID
			    ,QL.BLNG_RPTG_CD AS BLG_REPORTING_CD
                ,QL.PLAN_CD AS PLAN_CD_TX
				,QL.PLAN_EXT_CD AS PLAN_EXT_CD_TX
				,QL.GRP_CD AS GROUP_CD_TX
				,QL.GRP_EXT_CD AS GROUP_EXT_CD_TX

		FROM &DSS_CLIN..V_CLNT_CPG_QL_DENORM QL 
   				,&ORA_TMP..&TABLE_PREFIX._GSTP_LVL1 CLNT
		WHERE QL.QL_CLNT_ID    = CLNT.CLIENT_ID
 			 AND QL.SRC_SYS_CD = 'Q'
 			 AND CLNT.SYS_CD   = 'Q'
  		);

*SASDOC-------------------------------------------------------------------------
| Get QL Group Class Code and Seq Number Information
+-----------------------------------------------------------------------SASDOC*;	
		CREATE TABLE QL_GROUP_CLASS AS
	      SELECT * FROM CONNECTION TO ORACLE
		(
      	SELECT  QL.CLNT_ID AS CLIENT_ID
   				,QL.CLNT_PLN_GRP_ID AS QL_CPG_ID
   				,QL.GRP_CLS_CD      AS GROUP_CLASS_CD
   				,QL.SEQ_NB          AS GROUP_CLASS_SEQ_NB
				,QL.UPD_BATCH_GID

		FROM DWCORP.V_QL_RPTDT_RPT_GRP_DTL QL
/*		FROM UB01B2K.T_QL_RPTDT_RPT_GRP_DTL QL*/
		,&ORA_TMP..&TABLE_PREFIX._GSTP_LVL1 CLNT
		
		WHERE QL.CLNT_ID = CLNT.CLIENT_ID
         AND CLNT.SYS_CD = 'Q'
);

*SASDOC-------------------------------------------------------------------------
| Get RECAP Information from  DSS_CLIN.V_ALGN_LVL_DENORM
+-----------------------------------------------------------------------SASDOC*;	 
		CREATE TABLE RECAP_ALGN AS
	        SELECT * FROM CONNECTION TO ORACLE
		(
      	SELECT   ALGN.ALGN_LVL_GID_KEY               AS ALGN_GID, 
  				 ALGN.RPT_OPT1_CD                    AS OPT1,
  				 ALGN.EXTNL_LVL_ID1                  AS LVL1,
  				 ALGN.EXTNL_LVL_ID2                  AS LVL2,
  				 ALGN.EXTNL_LVL_ID3                  AS LVL3,
  				 ALGN.PAYER_ID,
  				 ALGN.CUST_NM,
  				 ALGN.SRC_SYS_CD                    AS SYS_CD,
				 ALGN.QL_CLNT_ID
		FROM &DSS_CLIN..V_ALGN_LVL_DENORM ALGN
		,&ORA_TMP..&TABLE_PREFIX._GSTP_LVL1 CLNT
		WHERE ALGN.SRC_SYS_CD = 'R'
		AND CLNT.SYS_CD = 'R'
		AND ALGN.RPT_OPT1_CD = CLNT.RPT_OPT1_CD
  		);

*SASDOC-------------------------------------------------------------------------
| Get RxClaim Information from  DSS_CLIN.V_ALGN_LVL_DENORM
+-----------------------------------------------------------------------SASDOC*;	    
		CREATE TABLE RXCLM_ALGN AS
	        SELECT * FROM CONNECTION TO ORACLE
		(
      	SELECT   ALGN.ALGN_LVL_GID_KEY               AS ALGN_GID, 
  				 ALGN.RPT_OPT1_CD                    AS OPT1,
  				 ALGN.EXTNL_LVL_ID1                  AS LVL1,
  				 ALGN.EXTNL_LVL_ID2                  AS LVL2,
  				 ALGN.EXTNL_LVL_ID3                  AS LVL3,
  				 ALGN.PAYER_ID,
  				 ALGN.CUST_NM,
  				 ALGN.SRC_SYS_CD                    AS SYS_CD,
				 ALGN.QL_CLNT_ID
		FROM &DSS_CLIN..V_ALGN_LVL_DENORM ALGN
			,&ORA_TMP..&TABLE_PREFIX._GSTP_LVL1 CLNT
		WHERE ALGN.SRC_SYS_CD = 'X'
		AND CLNT.SYS_CD = 'X'
		AND ALGN.EXTNL_LVL_ID1 = CLNT.EXTNL_LVL_ID1
  		);


    	DISCONNECT FROM ORACLE;
	QUIT;
	%SET_ERROR_FL; 

*SASDOC-------------------------------------------------------------------------
| Sort and Combine QL hierarchy datasets
+-----------------------------------------------------------------------SASDOC*;	 
	PROC SORT DATA = QL_GROUP_CLASS; BY QL_CPG_ID CLIENT_ID GROUP_CLASS_CD 
                     GROUP_CLASS_SEQ_NB UPD_BATCH_GID;
	RUN;
	%SET_ERROR_FL; 

	DATA QL_GROUP_CLASS(DROP=UPD_BATCH_GID);
	SET QL_GROUP_CLASS;
	BY QL_CPG_ID CLIENT_ID GROUP_CLASS_CD 
                     GROUP_CLASS_SEQ_NB;
	IF LAST.GROUP_CLASS_SEQ_NB THEN OUTPUT;
	RUN;
	%SET_ERROR_FL; 


	PROC SORT DATA = QL_CPG_ID NODUPKEY; BY QL_CPG_ID;
	RUN;
	%SET_ERROR_FL; 

    PROC SORT DATA = QL_PLAN_NM NODUPKEY; BY QL_CPG_ID;
	RUN;
	%SET_ERROR_FL; 

	DATA QL_CPG_ALL;
	MERGE QL_CPG_ID 
	      QL_GROUP_CLASS
          QL_PLAN_NM
		  ;
		  BY QL_CPG_ID;
		  LVL1=LEFT(PUT(CLIENT_ID,5.));
	RUN;
	%SET_ERROR_FL; 

	PROC SORT DATA = QL_CPG_ALL; BY LVL1;
	RUN;

	PROC SORT DATA = QL_ALGN NODUPKEY; BY LVL1;
	RUN;

	DATA ALL_QL_PLAN_INFO;
	MERGE QL_ALGN (IN=A)
	      QL_CPG_ALL;
		  BY LVL1;
		  IF A=1 THEN OUTPUT;
	RUN;
	%SET_ERROR_FL; 

data out.ALL_QL_PLAN_INFO;
set ALL_QL_PLAN_INFO;
run;

%MACRO BLANK_OR_EQ(VAR=);
AND ((B.&VAR.='' OR B.&VAR. IS NULL) OR (TRIM(UPCASE(A.&VAR.)) = TRIM(UPCASE(B.&VAR.))))
%MEND;

*SASDOC-------------------------------------------------------------------------
| Get QL Targeted Clients: full include and partial include
+-----------------------------------------------------------------------SASDOC*;	 
	PROC SQL;
     CREATE TABLE QL_TARGET_1 AS

	 SELECT DISTINCT A.ALGN_GID
	       ,A.OPT1
		   ,A.LVL1
		   ,A.LVL2
		   ,A.LVL3
		   ,A.PAYER_ID
		   ,A.CUST_NM
		   ,A.SYS_CD
		   ,'' AS INSURANCE_CD
		   ,'' AS CARRIER_ID
		   ,'' AS ACCOUNT_ID
		   ,'' AS GROUP_CD
		   ,A.QL_CPG_ID
		   ,A.CLIENT_ID AS QL_CLIENT_ID
		   ,A.GROUP_CLASS_CD
		   ,A.GROUP_CLASS_SEQ_NB
		   ,A.BLG_REPORTING_CD
		   ,A.PLAN_NM
		   ,A.PLAN_CD_TX
		   ,A.PLAN_EXT_CD_TX
		   ,A.GROUP_CD_TX
		   ,A.GROUP_EXT_CD_TX
		   ,B.TARGET_CLIENT_KEY
		   ,B.OVR_CLIENT_NM
		   ,B.GSTP_GSA_PGMTYP_CD

		   
FROM ALL_QL_PLAN_INFO   A
, QL_CLIENTS            B

WHERE A.CLIENT_ID = B.CLIENT_ID
AND B.CLT_SETUP_DEF_CD IN (1,3)
AND (B.GROUP_CLASS_CD IS NULL OR B.GROUP_CLASS_CD=0 OR (A.GROUP_CLASS_CD = B.GROUP_CLASS_CD))
AND (B.GROUP_CLASS_SEQ_NB IS NULL OR B.GROUP_CLASS_SEQ_NB=0 OR (A.GROUP_CLASS_SEQ_NB = B.GROUP_CLASS_SEQ_NB))
%BLANK_OR_EQ(VAR=BLG_REPORTING_CD)
%BLANK_OR_EQ(VAR=PLAN_NM)
%BLANK_OR_EQ(VAR=PLAN_CD_TX)
%BLANK_OR_EQ(VAR=PLAN_EXT_CD_TX)
%BLANK_OR_EQ(VAR=GROUP_CD_TX)
%BLANK_OR_EQ(VAR=GROUP_EXT_CD_TX)
 
;
QUIT;
%SET_ERROR_FL; 


PROC SORT DATA =QL_TARGET_1 NODUPKEY; BY ALGN_GID QL_CPG_ID;
RUN;

*SASDOC-------------------------------------------------------------------------
| Get QL Targeted Clients: excludes
+-----------------------------------------------------------------------SASDOC*;	 
	PROC SQL;
     CREATE TABLE QL_TARGET_2 AS

	 SELECT DISTINCT A.ALGN_GID
		   ,A.QL_CPG_ID

		   
	 FROM ALL_QL_PLAN_INFO   A
		, QL_CLIENTS            B

	 WHERE A.CLIENT_ID = B.CLIENT_ID
		AND B.CLT_SETUP_DEF_CD IN (2)
		AND (B.GROUP_CLASS_CD IS NULL OR B.GROUP_CLASS_CD=0 OR (A.GROUP_CLASS_CD = B.GROUP_CLASS_CD))
		AND (B.GROUP_CLASS_SEQ_NB IS NULL OR B.GROUP_CLASS_SEQ_NB=0 OR (A.GROUP_CLASS_SEQ_NB = B.GROUP_CLASS_SEQ_NB))
		%BLANK_OR_EQ(VAR=BLG_REPORTING_CD)
		%BLANK_OR_EQ(VAR=PLAN_NM)
		%BLANK_OR_EQ(VAR=PLAN_CD_TX)
		%BLANK_OR_EQ(VAR=PLAN_EXT_CD_TX)
		%BLANK_OR_EQ(VAR=GROUP_CD_TX)
		%BLANK_OR_EQ(VAR=GROUP_EXT_CD_TX)
 
;
QUIT;
%SET_ERROR_FL; 

PROC SORT DATA =QL_TARGET_2 NODUPKEY; BY ALGN_GID QL_CPG_ID;
RUN;

*SASDOC-------------------------------------------------------------------------
| Get QL Targeted Clients: opposites of excludes
+-----------------------------------------------------------------------SASDOC*;	
	PROC SQL;
     CREATE TABLE QL_TARGET_3 AS

	 SELECT DISTINCT A.ALGN_GID
	       ,A.OPT1
		   ,A.LVL1
		   ,A.LVL2
		   ,A.LVL3
		   ,A.PAYER_ID
		   ,A.CUST_NM
		   ,A.SYS_CD
		   ,'' AS INSURANCE_CD
		   ,'' AS CARRIER_ID
		   ,'' AS ACCOUNT_ID
		   ,'' AS GROUP_CD
		   ,A.QL_CPG_ID
		   ,A.CLIENT_ID AS QL_CLIENT_ID
		   ,A.GROUP_CLASS_CD
		   ,A.GROUP_CLASS_SEQ_NB
		   ,A.BLG_REPORTING_CD
		   ,A.PLAN_NM
		   ,A.PLAN_CD_TX
		   ,A.PLAN_EXT_CD_TX
		   ,A.GROUP_CD_TX
		   ,A.GROUP_EXT_CD_TX
		   ,B.TARGET_CLIENT_KEY
		   ,B.OVR_CLIENT_NM
		   ,B.GSTP_GSA_PGMTYP_CD

		   
FROM ALL_QL_PLAN_INFO   A
, QL_CLIENTS            B
WHERE A.CLIENT_ID = B.CLIENT_ID
AND B.CLT_SETUP_DEF_CD IN (2)
/*AND (A.ALGN_GID, A.QL_CPG_ID) NOT IN*/

AND NOT EXISTS
( SELECT 1 /*C.ALGN_GID, C.QL_CPG_ID*/
FROM QL_TARGET_2           C
WHERE A.ALGN_GID = C.ALGN_GID
  AND A.QL_CPG_ID = C.QL_CPG_ID)

;
QUIT;
%SET_ERROR_FL; 

*SASDOC-------------------------------------------------------------------------
| Combine all QL Targeted clients
+-----------------------------------------------------------------------SASDOC*;	
DATA QL_TARGET;
LENGTH QL_CPG_ID GROUP_CLASS_CD 8;
LENGTH QL_CLIENT_ID GROUP_CLASS_SEQ_NB 5;
LENGTH INSURANCE_CD $3;
LENGTH CARRIER_ID ACCOUNT_ID $20;
LENGTH GROUP_CD BLG_REPORTING_CD GROUP_CD_TX $15;
LENGTH PLAN_NM $40;
LENGTH PLAN_CD_TX PLAN_EXT_CD_TX $8;
LENGTH GROUP_EXT_CD_TX $5;
LENGTH TARGET_CLIENT_KEY $200;
LENGTH OVR_CLIENT_NM $100;

SET QL_TARGET_1
    QL_TARGET_3
	;
	RUN;
%SET_ERROR_FL; 

*SASDOC-------------------------------------------------------------------------
| Get RECAP Targeted Clients: full include and partial include
+-----------------------------------------------------------------------SASDOC*;	 

	PROC SQL;
     CREATE TABLE RE_TARGET_1 AS

	 SELECT DISTINCT A.ALGN_GID
	       ,A.OPT1
		   ,A.LVL1
		   ,A.LVL2
		   ,A.LVL3
		   ,A.PAYER_ID
		   ,A.CUST_NM
		   ,A.SYS_CD
		   ,A.OPT1 AS INSURANCE_CD
		   ,A.LVL1 AS CARRIER_ID
		   ,'' AS ACCOUNT_ID
		   ,A.LVL3 AS GROUP_CD
		   ,0 AS QL_CPG_ID
		   ,A.QL_CLNT_ID AS QL_CLIENT_ID
		   ,0 AS GROUP_CLASS_CD
		   ,0 AS GROUP_CLASS_SEQ_NB
		   ,'' AS BLG_REPORTING_CD
		   ,'' AS PLAN_NM
		   ,'' AS PLAN_CD_TX
		   ,'' AS PLAN_EXT_CD_TX
		   ,'' AS GROUP_CD_TX
		   ,'' AS GROUP_EXT_CD_TX
		   ,B.TARGET_CLIENT_KEY
		   ,B.OVR_CLIENT_NM
		   ,B.GSTP_GSA_PGMTYP_CD
		   
FROM RECAP_ALGN   A
, RE_CLIENTS            B

WHERE A.OPT1 = B.OPT1
AND B.CLT_SETUP_DEF_CD IN (1,3)
%BLANK_OR_EQ(VAR=LVL1)
%BLANK_OR_EQ(VAR=LVL3)

 
;
QUIT;
%SET_ERROR_FL; 

*SASDOC-------------------------------------------------------------------------
| Get RECAP Targeted Clients: excludes
+-----------------------------------------------------------------------SASDOC*;

	PROC SQL;
     CREATE TABLE RE_TARGET_2 AS
	 SELECT DISTINCT A.ALGN_GID
	 
	FROM  RECAP_ALGN   A
		, RE_CLIENTS   B

	WHERE A.OPT1 = B.OPT1
	AND B.CLT_SETUP_DEF_CD IN (2)
	%BLANK_OR_EQ(VAR=LVL1)
	%BLANK_OR_EQ(VAR=LVL3)

;
QUIT;
%SET_ERROR_FL; 

*SASDOC-------------------------------------------------------------------------
| Get RECAP Targeted Clients: opposites of excludes
+-----------------------------------------------------------------------SASDOC*;	
	PROC SQL;
     CREATE TABLE RE_TARGET_3 AS

	 SELECT DISTINCT A.ALGN_GID
	       ,A.OPT1
		   ,A.LVL1
		   ,A.LVL2
		   ,A.LVL3
		   ,A.PAYER_ID
		   ,A.CUST_NM
		   ,A.SYS_CD
		   ,A.OPT1 AS INSURANCE_CD
		   ,A.LVL1 AS CARRIER_ID
		   ,'' AS ACCOUNT_ID
		   ,A.LVL3 AS GROUP_CD
		   ,0 AS QL_CPG_ID
		   ,A.QL_CLNT_ID AS QL_CLIENT_ID
		   ,0 AS GROUP_CLASS_CD
		   ,0 AS GROUP_CLASS_SEQ_NB
		   ,'' AS BLG_REPORTING_CD
		   ,'' AS PLAN_NM
		   ,'' AS PLAN_CD_TX
		   ,'' AS PLAN_EXT_CD_TX
		   ,'' AS GROUP_CD_TX
		   ,'' AS GROUP_EXT_CD_TX
		   ,B.TARGET_CLIENT_KEY
		   ,B.OVR_CLIENT_NM
		   ,B.GSTP_GSA_PGMTYP_CD
		   
FROM RECAP_ALGN   A
, RE_CLIENTS            B

WHERE A.OPT1 = B.OPT1
AND B.CLT_SETUP_DEF_CD IN (2)
AND A.ALGN_GID NOT IN

( SELECT C.ALGN_GID
FROM RE_TARGET_2           C)
 
;
QUIT;
%SET_ERROR_FL; 

*SASDOC-------------------------------------------------------------------------
| Combine all RECAP Targeted clients
+-----------------------------------------------------------------------SASDOC*;	

DATA RE_TARGET;
LENGTH QL_CPG_ID GROUP_CLASS_CD 8;
LENGTH QL_CLIENT_ID GROUP_CLASS_SEQ_NB 5;
LENGTH INSURANCE_CD $3;
LENGTH CARRIER_ID ACCOUNT_ID $20;
LENGTH GROUP_CD BLG_REPORTING_CD GROUP_CD_TX $15;
LENGTH PLAN_NM $40;
LENGTH PLAN_CD_TX PLAN_EXT_CD_TX $8;
LENGTH GROUP_EXT_CD_TX $5;
LENGTH TARGET_CLIENT_KEY $200;
LENGTH OVR_CLIENT_NM $100;

SET RE_TARGET_1
    RE_TARGET_3
	;
	RUN;
%SET_ERROR_FL; 

*SASDOC-------------------------------------------------------------------------
| Get RxClaim Targeted Clients: full include and partial include
+-----------------------------------------------------------------------SASDOC*;	 

	PROC SQL;
     CREATE TABLE RX_TARGET_1 AS

	 SELECT DISTINCT A.ALGN_GID
	       ,A.OPT1
		   ,A.LVL1
		   ,A.LVL2
		   ,A.LVL3
		   ,A.PAYER_ID
		   ,A.CUST_NM
		   ,A.SYS_CD
		   ,'' AS INSURANCE_CD
		   ,A.LVL1 AS CARRIER_ID
		   ,A.LVL2 AS ACCOUNT_ID
		   ,A.LVL3 AS GROUP_CD
		   ,0 AS QL_CPG_ID
		   ,A.QL_CLNT_ID AS QL_CLIENT_ID
		   ,0 AS GROUP_CLASS_CD
		   ,0 AS GROUP_CLASS_SEQ_NB
		   ,'' AS BLG_REPORTING_CD
		   ,'' AS PLAN_NM
		   ,'' AS PLAN_CD_TX
		   ,'' AS PLAN_EXT_CD_TX
		   ,'' AS GROUP_CD_TX
		   ,'' AS GROUP_EXT_CD_TX
		   ,B.TARGET_CLIENT_KEY
		   ,B.OVR_CLIENT_NM
		   ,B.GSTP_GSA_PGMTYP_CD
		  
FROM RXCLM_ALGN   A
, RX_CLIENTS            B

WHERE A.LVL1 = B.LVL1
AND B.CLT_SETUP_DEF_CD IN (1,3)
%BLANK_OR_EQ(VAR=LVL2)
%BLANK_OR_EQ(VAR=LVL3)

 
;
QUIT;
%SET_ERROR_FL; 

*SASDOC-------------------------------------------------------------------------
| Get RECAP Targeted Clients: excludes
+-----------------------------------------------------------------------SASDOC*;

	PROC SQL;
     CREATE TABLE RX_TARGET_2 AS

	 SELECT DISTINCT A.ALGN_GID
	 
		  
FROM RXCLM_ALGN   A
, RX_CLIENTS            B

WHERE A.LVL1 = B.LVL1
AND B.CLT_SETUP_DEF_CD IN (2)
%BLANK_OR_EQ(VAR=LVL2)
%BLANK_OR_EQ(VAR=LVL3)
;
QUIT;
%SET_ERROR_FL; 

*SASDOC-------------------------------------------------------------------------
| Get RxClaim Targeted Clients: opposites of excludes
+-----------------------------------------------------------------------SASDOC*;	
	PROC SQL;
     CREATE TABLE RX_TARGET_3 AS

	 SELECT DISTINCT A.ALGN_GID
	       ,A.OPT1
		   ,A.LVL1
		   ,A.LVL2
		   ,A.LVL3
		   ,A.PAYER_ID
		   ,A.CUST_NM
		   ,A.SYS_CD
		   ,'' AS INSURANCE_CD
		   ,A.LVL1 AS CARRIER_ID
		   ,A.LVL2 AS ACCOUNT_ID
		   ,A.LVL3 AS GROUP_CD
		   ,0 AS QL_CPG_ID
		   ,A.QL_CLNT_ID AS QL_CLIENT_ID
		   ,0 AS GROUP_CLASS_CD
		   ,0 AS GROUP_CLASS_SEQ_NB
		   ,'' AS BLG_REPORTING_CD
		   ,'' AS PLAN_NM
		   ,'' AS PLAN_CD_TX
		   ,'' AS PLAN_EXT_CD_TX
		   ,'' AS GROUP_CD_TX
		   ,'' AS GROUP_EXT_CD_TX
		   ,B.TARGET_CLIENT_KEY
		   ,B.OVR_CLIENT_NM
		   ,B.GSTP_GSA_PGMTYP_CD
		  
FROM RXCLM_ALGN   A
,RX_CLIENTS            B

WHERE A.LVL1 = B.LVL1
AND B.CLT_SETUP_DEF_CD IN (2)
AND A.ALGN_GID NOT IN

( SELECT C.ALGN_GID
FROM RX_TARGET_2           C)
 
;
QUIT;
%SET_ERROR_FL; 

*SASDOC-------------------------------------------------------------------------
| Combine all RxClaim Targeted clients
+-----------------------------------------------------------------------SASDOC*;	

DATA RX_TARGET;
LENGTH QL_CPG_ID GROUP_CLASS_CD 8;
LENGTH QL_CLIENT_ID GROUP_CLASS_SEQ_NB 5;
LENGTH INSURANCE_CD $3;
LENGTH CARRIER_ID ACCOUNT_ID $20;
LENGTH GROUP_CD BLG_REPORTING_CD GROUP_CD_TX $15;
LENGTH PLAN_NM $40;
LENGTH PLAN_CD_TX PLAN_EXT_CD_TX $8;
LENGTH GROUP_EXT_CD_TX $5;
LENGTH TARGET_CLIENT_KEY $200;
LENGTH OVR_CLIENT_NM $100;

SET RX_TARGET_1
    RX_TARGET_3
	;
	RUN;
%SET_ERROR_FL; 
*SASDOC-------------------------------------------------------------------------
| Sort all Targeted clients
+-----------------------------------------------------------------------SASDOC*;
DATA QL_TARGET_ONE_TYPE (KEEP= TARGET_CLIENT_KEY GSTP_GSA_PGMTYP_CD);
SET QL_TARGET;
RUN;
%SET_ERROR_FL; 

DATA RE_TARGET_ONE_TYPE (KEEP= TARGET_CLIENT_KEY GSTP_GSA_PGMTYP_CD);
SET RE_TARGET;
RUN;
%SET_ERROR_FL; 

DATA RX_TARGET_ONE_TYPE (KEEP= TARGET_CLIENT_KEY GSTP_GSA_PGMTYP_CD);
SET RX_TARGET;
RUN;
%SET_ERROR_FL; 


PROC SORT DATA = QL_TARGET_ONE_TYPE NODUPKEY; BY TARGET_CLIENT_KEY GSTP_GSA_PGMTYP_CD;
RUN;

PROC SORT DATA = RE_TARGET_ONE_TYPE NODUPKEY; BY TARGET_CLIENT_KEY GSTP_GSA_PGMTYP_CD;
RUN;

PROC SORT DATA = RX_TARGET_ONE_TYPE NODUPKEY; BY TARGET_CLIENT_KEY GSTP_GSA_PGMTYP_CD;
RUN;
%SET_ERROR_FL; 
*SASDOC-------------------------------------------------------------------------
| Get All clients with just one GSTP type. This info will be used later 
| for APN_CMCTN_ID field override
+-----------------------------------------------------------------------SASDOC*;


	PROC SQL NOPRINT;
	        CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
			CREATE TABLE QL_OVR AS
	        SELECT * FROM CONNECTION TO DB2
	   		(  SELECT  'Q' || TRIM(COALESCE(CHAR(A.CLIENT_ID),''))|| TRIM(COALESCE(CHAR(A.GROUP_CLASS_CD),'')) 
                    || TRIM(COALESCE(CHAR(A.GROUP_CLASS_SEQ_NB),''))
					|| TRIM(COALESCE(A.BLG_REPORTING_CD,'')) || TRIM(COALESCE(A.PLAN_NM,'')) || TRIM(COALESCE(A.PLAN_CD_TX,'')) 
					|| TRIM(COALESCE(A.PLAN_EXT_CD_TX,'')) || TRIM(COALESCE(A.GROUP_CD_TX,'')) || TRIM(COALESCE(A.GROUP_EXT_CD_TX,''))
					AS TARGET_CLIENT_KEY
					,A.CMCTN_ROLE_CD AS LTR_TYPE
					,A.APN_CMCTN_ID  AS OVR_APN_CMCTN_ID
			   
			  FROM &HERCULES..TPGMTASK_QL_OVR  A

			  WHERE A.PROGRAM_ID = &PROGRAM_ID.
			    AND A.TASK_ID    = &TASK_ID.
			    AND A.EFFECTIVE_DT <= CURRENT DATE
				AND A.EXPIRATION_DT >= CURRENT DATE

				    WITH UR
			  		);

			CREATE TABLE RE_OVR AS
	        SELECT * FROM CONNECTION TO DB2
	   		(  SELECT 'R'|| TRIM(COALESCE(A.INSURANCE_CD,'')) ||TRIM(COALESCE(A.CARRIER_ID,''))
                       || TRIM(COALESCE(A.GROUP_CD,''))
					AS TARGET_CLIENT_KEY
					,A.CMCTN_ROLE_CD AS LTR_TYPE
					,A.APN_CMCTN_ID  AS OVR_APN_CMCTN_ID
			   
			  FROM &HERCULES..TPGMTASK_RECAP_OVR  A
			  WHERE A.PROGRAM_ID = &PROGRAM_ID.
			  	AND A.TASK_ID    = &TASK_ID.
			    AND A.EFFECTIVE_DT  <= CURRENT DATE
				AND A.EXPIRATION_DT >= CURRENT DATE
				    WITH UR
			  		);


			CREATE TABLE RX_OVR AS
	        SELECT * FROM CONNECTION TO DB2
	   		(  SELECT 'X' || TRIM(COALESCE(A.CARRIER_ID,'')) || TRIM(COALESCE(A.ACCOUNT_ID,''))
					|| TRIM(COALESCE(A.GROUP_CD,'')) AS TARGET_CLIENT_KEY
					,A.CMCTN_ROLE_CD AS LTR_TYPE
					,A.APN_CMCTN_ID  AS OVR_APN_CMCTN_ID
			   
			  FROM &HERCULES..TPGMTASK_RXCLM_OVR  A

			  WHERE A.PROGRAM_ID = &PROGRAM_ID.
			  	AND A.TASK_ID    = &TASK_ID.
			    AND A.EFFECTIVE_DT  <= CURRENT DATE
				AND A.EXPIRATION_DT >= CURRENT DATE

				    WITH UR
			  		);
	    	DISCONNECT FROM DB2;

		QUIT;
%SET_ERROR_FL; 

DATA ALL_OVR;
LENGTH TARGET_CLIENT_KEY $200;
SET QL_OVR
    RX_OVR
	RE_OVR
	;
RUN;
%SET_ERROR_FL; 

		PROC SORT DATA = ALL_OVR NODUPKEY; BY TARGET_CLIENT_KEY LTR_TYPE;
		RUN;
%SET_ERROR_FL; 



DATA QL_TARGET_ONE_TYPE;
SET QL_TARGET_ONE_TYPE;
BY TARGET_CLIENT_KEY;
IF FIRST.TARGET_CLIENT_KEY =1 AND LAST.TARGET_CLIENT_KEY=1 THEN OUTPUT;
RUN;
%SET_ERROR_FL; 

DATA RE_TARGET_ONE_TYPE;
SET RE_TARGET_ONE_TYPE;
BY TARGET_CLIENT_KEY;
IF FIRST.TARGET_CLIENT_KEY =1 AND LAST.TARGET_CLIENT_KEY=1 THEN OUTPUT;
RUN;
%SET_ERROR_FL; 

DATA RX_TARGET_ONE_TYPE;
SET RX_TARGET_ONE_TYPE;
BY TARGET_CLIENT_KEY;
IF FIRST.TARGET_CLIENT_KEY =1 AND LAST.TARGET_CLIENT_KEY=1 THEN OUTPUT;
RUN;
%SET_ERROR_FL; 

DATA ALL_ONE_TYPE;
LENGTH TARGET_CLIENT_KEY $200;
SET QL_TARGET_ONE_TYPE
    RE_TARGET_ONE_TYPE
	RX_TARGET_ONE_TYPE
	;
IF GSTP_GSA_PGMTYP_CD IN (2,3) THEN OUTPUT;
RUN;
%SET_ERROR_FL; 


*SASDOC-------------------------------------------------------------------------
| Read in parm file with APN_CMCTN_IDs 
+-----------------------------------------------------------------------SASDOC*;

DATA APN_IDS 
;

INFILE APN 
DLM=',' 
DSD 
MISSOVER
FIRSTOBS=2;

INPUT 

FILE_ID           :3.
TGST_ID           :$10.
PGST_ID           :$10.
HPGST_ID          :$10.
;

RUN;
%SET_ERROR_FL; 

DATA APN_IDS (KEEP=LTR_TYPE GSTP_GSA_PGMTYP_CD APN_CMCTN_ID);
SET APN_IDS;
IF FILE_ID = 32 THEN LTR_TYPE =1;
ELSE LTR_TYPE = 2;
GSTP_GSA_PGMTYP_CD = 1;
APN_CMCTN_ID = TGST_ID;
OUTPUT;
GSTP_GSA_PGMTYP_CD = 2;
APN_CMCTN_ID = PGST_ID;
OUTPUT;
GSTP_GSA_PGMTYP_CD = 3;
APN_CMCTN_ID = HPGST_ID;
OUTPUT;
RUN;
%SET_ERROR_FL; 


PROC SORT DATA = APN_IDS; BY GSTP_GSA_PGMTYP_CD LTR_TYPE;
RUN;
%SET_ERROR_FL; 

*SASDOC-------------------------------------------------------------------------
| Create dataset for APN_CMCTN_ID field override
+-----------------------------------------------------------------------SASDOC*;

	PROC SQL;
     CREATE TABLE ONE_TYPE_APN AS
	 SELECT A.TARGET_CLIENT_KEY
	      , B.LTR_TYPE
		  , B.APN_CMCTN_ID

	 FROM ALL_ONE_TYPE  A
	 , APN_IDS          B

	 WHERE A.GSTP_GSA_PGMTYP_CD = B.GSTP_GSA_PGMTYP_CD
			 ;
QUIT;
%SET_ERROR_FL; 

PROC SORT DATA = ONE_TYPE_APN; BY TARGET_CLIENT_KEY LTR_TYPE;
RUN;
%SET_ERROR_FL; 

DATA ONE_TYPE_APN;
MERGE ONE_TYPE_APN (IN=A)
      ALL_OVR (IN=B)
	  ;
BY TARGET_CLIENT_KEY LTR_TYPE;
IF A=1 AND B=0 THEN OUTPUT ONE_TYPE_APN;
RUN;


DATA OUT.ONE_TYPE_APN;
SET ONE_TYPE_APN;
RUN;

*SASDOC-------------------------------------------------------------------------
| Combine all targeted clients into one dataset
+-----------------------------------------------------------------------SASDOC*;


PROC SORT DATA = QL_TARGET NODUPKEY; BY ALGN_GID QL_CPG_ID;
RUN;

PROC SORT DATA = RE_TARGET NODUPKEY; BY ALGN_GID;
RUN;

PROC SORT DATA = RX_TARGET NODUPKEY; BY ALGN_GID;
RUN;
%SET_ERROR_FL; 



DATA ALL_TARGET;
LENGTH QL_CPG_ID GROUP_CLASS_CD 8;
LENGTH QL_CLIENT_ID GROUP_CLASS_SEQ_NB 5;
LENGTH INSURANCE_CD $3;
LENGTH CARRIER_ID ACCOUNT_ID $20;
LENGTH GROUP_CD BLG_REPORTING_CD GROUP_CD_TX $15;
LENGTH PLAN_NM $40;
LENGTH PLAN_CD_TX PLAN_EXT_CD_TX $8;
LENGTH GROUP_EXT_CD_TX $5;
LENGTH TARGET_CLIENT_KEY $200;
LENGTH OVR_CLIENT_NM $100;

SET QL_TARGET
    RE_TARGET
	RX_TARGET
	;
IF SYS_CD in ('X','R') THEN QL_CPG_ID = 0;
RUN;

%SET_ERROR_FL; 

PROC SORT DATA =ALL_TARGET NODUPKEY; BY ALGN_GID QL_CPG_ID;
RUN;
%SET_ERROR_FL; 


DATA ALGN_DATA (KEEP=ALGN_GID OPT1 LVL1 LVL2 LVL3 
PAYER_ID CUST_NM SYS_CD INSURANCE_CD CARRIER_ID ACCOUNT_ID 
GROUP_CD QL_CLIENT_ID);
SET ALL_TARGET;
RUN;
%SET_ERROR_FL; 

DATA CPG_DATA (KEEP=ALGN_LVL_GID_KEY QL_CPG_ID QL_GROUP_CLASS_CD
QL_GROUP_CLASS_SEQ_NB QL_BLG_REPORTING_CD QL_PLAN_NM QL_PLAN_CD QL_PLAN_EXT_CD
QL_GROUP_CD QL_GROUP_EXT_CD TARGET_CLIENT_KEY OVR_CLIENT_NM);
SET ALL_TARGET;
IF QL_CPG_ID          = . THEN QL_CPG_ID=0;
ALGN_LVL_GID_KEY      = ALGN_GID;
QL_GROUP_CLASS_CD     = GROUP_CLASS_CD;
QL_GROUP_CLASS_SEQ_NB = GROUP_CLASS_SEQ_NB;
QL_BLG_REPORTING_CD   = BLG_REPORTING_CD;
QL_PLAN_NM            = PLAN_NM;
QL_PLAN_CD            = PLAN_CD_TX;
QL_PLAN_EXT_CD        = PLAN_EXT_CD_TX;
QL_GROUP_CD           = GROUP_CD_TX;
QL_GROUP_EXT_CD       = GROUP_EXT_CD_TX;

RUN;
%SET_ERROR_FL; 

PROC SORT DATA = ALGN_DATA NODUPKEY; BY ALGN_GID;
RUN;
%SET_ERROR_FL; 

PROC SORT DATA =CPG_DATA NODUPKEY; BY ALGN_LVL_GID_KEY QL_CPG_ID;
RUN;
%SET_ERROR_FL;


*SASDOC-------------------------------------------------------------------------
| Output all targeted clients into output Oracle table
+-----------------------------------------------------------------------SASDOC*;

%DROP_ORACLE_TABLE(TBL_NAME=&TBL_NAME_OUT.); 
%DROP_ORACLE_TABLE(TBL_NAME=&TBL_NAME_OUT.1); 

			PROC SQL NOPRINT;
					CONNECT TO ORACLE(PATH=&GOLD );
		  			EXECUTE 
					(
					CREATE TABLE &TBL_NAME_OUT.
					(ALGN_LVL_GID_KEY            NUMBER
					 ,RPT_OPT1_CD                VARCHAR2(22)
                     ,EXTNL_LVL_ID1              VARCHAR2(20)
					 ,EXTNL_LVL_ID2              VARCHAR2(20)
					 ,EXTNL_LVL_ID3              VARCHAR2(20)
					 ,PAYER_ID                   NUMBER
					 ,CUST_NM                    VARCHAR2(60)
					 ,SRC_SYS_CD                 CHAR(1)
				     ,INSURANCE_CD               VARCHAR2(20)
				     ,CARRIER_ID                 VARCHAR2(20)
					 ,ACCOUNT_ID                 VARCHAR2(20)
					 ,GROUP_CD                   VARCHAR2(20)
					 ,QL_CPG_ID                  NUMBER
					 ,QL_CLIENT_ID               NUMBER
					 ,QL_GROUP_CLASS_CD          NUMBER
					 ,QL_GROUP_CLASS_SEQ_NB      NUMBER
					 ,QL_BLG_REPORTING_CD        VARCHAR2(15)
					 ,QL_PLAN_NM                 VARCHAR2(40)
					 ,QL_PLAN_CD                 VARCHAR2(8)
					 ,QL_PLAN_EXT_CD             VARCHAR2(8)
					 ,QL_GROUP_CD                VARCHAR2(15)
					 ,QL_GROUP_EXT_CD            VARCHAR2(5)
					 ,TARGET_CLIENT_KEY          VARCHAR2(200)
					 ,OVR_CLIENT_NM             VARCHAR2(100)
					 )
		  			) BY ORACLE;
		    		DISCONNECT FROM ORACLE;
				QUIT;
				
			PROC SQL NOPRINT;
					CONNECT TO ORACLE(PATH=&GOLD );
		  			EXECUTE 
					(
					CREATE TABLE &TBL_NAME_OUT.1
					(ALGN_LVL_GID_KEY            NUMBER
					 ,RPT_OPT1_CD                VARCHAR2(22)
                     ,EXTNL_LVL_ID1              VARCHAR2(20)
					 ,EXTNL_LVL_ID2              VARCHAR2(20)
					 ,EXTNL_LVL_ID3              VARCHAR2(20)
					 ,PAYER_ID                   NUMBER
					 ,CUST_NM                    VARCHAR2(60)
					 ,SRC_SYS_CD                 CHAR(1)
				     ,INSURANCE_CD               VARCHAR2(20)
				     ,CARRIER_ID                 VARCHAR2(20)
					 ,ACCOUNT_ID                 VARCHAR2(20)
					 ,GROUP_CD                   VARCHAR2(20)
					 ,QL_CLIENT_ID               NUMBER
					 )
		  			) BY ORACLE;
		    		DISCONNECT FROM ORACLE;
				QUIT;
				RUN;



				PROC SQL;

				INSERT INTO &TBL_NAME_OUT.
				SELECT A.ALGN_GID
	       ,A.OPT1
		   ,A.LVL1
		   ,A.LVL2
		   ,A.LVL3
		   ,A.PAYER_ID
		   ,A.CUST_NM
		   ,A.SYS_CD
		   ,A.INSURANCE_CD
		   ,A.CARRIER_ID
		   ,A.ACCOUNT_ID
		   ,A.GROUP_CD
		   ,A.QL_CPG_ID
		   ,A.QL_CLIENT_ID
		   ,A.GROUP_CLASS_CD
		   ,A.GROUP_CLASS_SEQ_NB
		   ,A.BLG_REPORTING_CD
		   ,A.PLAN_NM
		   ,A.PLAN_CD_TX
		   ,A.PLAN_EXT_CD_TX
		   ,A.GROUP_CD_TX
		   ,A.GROUP_EXT_CD_TX
		   ,A.TARGET_CLIENT_KEY
		   ,A.OVR_CLIENT_NM 


				FROM ALL_TARGET  A;
				QUIT;
				RUN;
			PROC SQL;

				INSERT INTO &TBL_NAME_OUT.1
				SELECT A.ALGN_GID
	       ,A.OPT1
		   ,A.LVL1
		   ,A.LVL2
		   ,A.LVL3
		   ,A.PAYER_ID
		   ,A.CUST_NM
		   ,A.SYS_CD
		   ,A.INSURANCE_CD
		   ,A.CARRIER_ID
		   ,A.ACCOUNT_ID
		   ,A.GROUP_CD
		   ,A.QL_CLIENT_ID


				FROM ALGN_DATA  A;
				QUIT;
				RUN;
*SASDOC-------------------------------------------------------------------------
| Create Indexes and run runstats on output Oracle table
+-----------------------------------------------------------------------SASDOC*;


PROC SQL;
 CONNECT TO ORACLE(PATH=&GOLD );
  EXECUTE (
    CREATE INDEX &TBL_NAME_OUT._I1
    ON &TBL_NAME_OUT.(ALGN_LVL_GID_KEY))
  BY ORACLE;
  DISCONNECT FROM ORACLE;
QUIT;

PROC SQL;
 CONNECT TO ORACLE(PATH=&GOLD );
  EXECUTE (
    CREATE INDEX &TBL_NAME_OUT._I2
    ON &TBL_NAME_OUT.(QL_CPG_ID))
  BY ORACLE;
  DISCONNECT FROM ORACLE;
QUIT;

PROC SQL;
 CONNECT TO ORACLE(PATH=&GOLD );
  EXECUTE (
    CREATE UNIQUE INDEX &TBL_NAME_OUT.1_I1
    ON &TBL_NAME_OUT.1(ALGN_LVL_GID_KEY))
  BY ORACLE;
  DISCONNECT FROM ORACLE;
QUIT;


%LET POS=%INDEX(&TBL_NAME_OUT,.);
%LET SCHEMA_OUT=%SUBSTR(&TBL_NAME_OUT,1,%EVAL(&POS-1));
%LET NAME_OUT=%SUBSTR(&TBL_NAME_OUT,%EVAL(&POS+1));



DATA _NULL_;
TICK = "'";
COMMA=",";
DB_ID = TRIM(LEFT("&SCHEMA_OUT."));
TBL_NM = TRIM(LEFT("&NAME_OUT."));

CALL SYMPUT('ORA_STR1',TICK||LEFT(TRIM(DB_ID))||TICK||COMMA);
CALL SYMPUT('ORA_STR2',TICK||LEFT(TRIM(TBL_NM))||TICK);
CALL SYMPUT('ORA_STR2A',TICK||LEFT(TRIM(TBL_NM))||'1'||TICK);

RUN;


RUN;

DATA _NULL_;
CALL SYMPUT('ORA_STRB',TRIM(LEFT("&ORA_STR1"))||TRIM(LEFT("&ORA_STR2")));
CALL SYMPUT('ORA_STRBA',TRIM(LEFT("&ORA_STR1"))||TRIM(LEFT("&ORA_STR2A")));
RUN;


PROC SQL;
  CONNECT TO ORACLE(PATH=&GOLD );
EXECUTE(EXEC DBMS_STATS.GATHER_TABLE_STATS(&ORA_STRB.)) BY ORACLE;
EXECUTE(EXEC DBMS_STATS.GATHER_TABLE_STATS(&ORA_STRBA.)) BY ORACLE;
DISCONNECT FROM ORACLE;
 QUIT;
RUN;

%MEND resolve_client_gstp;


