
	/**HEADER------------------------------------------------------------------------------------
	|
	| PROGRAM NAME: RESOLVE_CLIENT_RE.SAS
	|
	| CALL REFERENCE: RESOLVE_CLIENT_RE.SAS IS CALLED BY RESOLVE_CLIENT.SAS
	|
	| PURPOSE:
	|       DETERMINING THE ALGN_LVL_GID_KEY, INSURANCE_CD AND THEIR HIERARCHIES
	|		TO BE INCLUDED OR EXCLUDED IN A MAILING.
	|
	| INPUT:  
	|       MACRO VARIABLES FROM HERCULES_IN.SAS :
	|       	INITIATIVE_ID, PROGRAM_ID, TASK_ID, QL_ADJ, RX_ADJ, RE_ADJ,
	|			DFL_CLT_INC_EXU_IN, OVRD_CLT_SETUP_IN, DSPLY_CLT_SETUP_CD,
	|			TABLE_PREFIX
	|		TABLES :
	|			PROGRAM-MAINTAINENCE SET-UP
	|				HERCULES.TPGMTASK_RECAP_RUL
	|				DSS_CLIN.V_ALGN_LVL_DENORM
	|			CLIENT SPECIFIC SET-UP
	|				HERCULES.TINIT_CLT_RULE_DEF 
	|			    HERCULES.TINIT_RECAP_CLT_RL 
	|				DSS_CLIN.V_ALGN_LVL_DENORM
	|
	| OUTPUT: 
	|       MACRO VARIABLES
	|       	RESOLVE_CLIENT_EXCLUDE_FLAG: 
	|				0=INCLUDE ALGN_LVL_GID_KEY IN THE &TBL_NAME_OUT IN THE MAILING,
	|           	1=EXCLUDE ALGN_LVL_GID_KEY IN THE &TBL_NAME_OUT FROM THE MAILING.
	|       	RESOLVE_CLIENT_TBL_EXIST_FLAG_RE:
	|           	0 = TABLE &TBL_NAME_OUT DOES NOT EXIST
	|           	1 = TABLE &TBL_NAME_OUT HAS BEEN CREATED.
	|		TABLE:
	|			&TBL_NAME_OUT_RE WITH ALGN_LVL_GID_KEY, INSURANCE_CD, CARRIER_ID, GROUP_CD
	|			&TBL_NAME_OUT_RE2 IF &TBL_NAME_IN IS PASSED AS AN INPUT TABLE
	|
	|------------------------------------------------------------------------------------------
	| HISTORY: 14APR2008 - SR	- Hercules Version  2.1.01
	|							- Hercules Version  2.1.2.01
	|
	|           JUNE 2012 - E BUKOWSKI(SLIOUNKOVA) -  TARGET BY DRUG/DSA AUTOMATION
	|           SUPRESSED ALGN_GRP_EFF_DT AND ALGN_GRP_END_DT CHECKS (TBD)
	|
	|30AUG2012 - S.BILETSKY - LOGIC CHANGES FOR CLIENT CONNECT RE TO RX PROJECT. (CCW4)
	|
	|------------------------------------------------------------------------------------------
	+---------------------------------------------------------------------------------*HEADER*/

	%MACRO RESOLVE_CLIENT_RE;

	%LET SAMPLE_REC = %STR( );

	%*SASDOC -------------------------------------------------------------------------
	 | SETTING UP EXECUTE_CONDITION_FLAG
	 | EXECUTES ONLY WHEN MACRO VARIABLE EXECUTE_CONDITION_FLAG = 1, OTHERWISE EXIT
	 +---------------------------------------------------------------------------SASDOC;

	%IF &EXECUTE_CONDITION_FLAG. = 0 %THEN %DO;
		%PUT NOTE: MACRO WILL NOT EXECUTE BECAUSE EXECUTE_CONDITION IS FALSE;
		%PUT NOTE: EXECUTE_CONDITION = &EXECUTE_CONDITION; 
	%END;
	%IF &EXECUTE_CONDITION_FLAG.= 0 %THEN 
		%GOTO EXIT;

	%*SASDOC ----------------------------------------------------------------------------------
	 | PROCESS SETUP BASED ON DSPLY_CLT_SETUP_CD
	 | NOTE: DSPLY_CLT_SETUP_CD = 1 - INITIATIVE SETUP (CLIENT SPECIFIC PROCESS)
	 |       DSPLY_CLT_SETUP_CD IN (2,3) - PROGRAM MAINTAINENCE SETUP (BOOK OF BUSINESS PROCESS / PROGRAM SET-UP)
	 |       IF (DSPLY_CLT_SETUP_CD > 3 OR DSPLY_CLT_SETUP_CD = 0), EXIT THE PROCESS
	 |       IF (DSPLY_CLT_SETUP_CD IN (2,3) AND OVRD_CLT_SETUP_IN = 1), RESET DSPLY_CLT_SETUP_CD =1
	 +-----------------------------------------------------------------------------------SASDOC;

	%IF &DSPLY_CLT_SETUP_CD=2 OR &DSPLY_CLT_SETUP_CD=3 %THEN
	    %PUT NOTE: CLIENT-DISPLAY-SETUP-CODE=%CMPRES(&DSPLY_CLT_SETUP_CD), USE PROGRAM MAINTAINENCE SETUP. ;
	%ELSE %IF &DSPLY_CLT_SETUP_CD=1 %THEN
		%PUT NOTE: CLIENT-DISPLAY-SETUP-CODE=%CMPRES(&DSPLY_CLT_SETUP_CD), USE CLIENT SETUP. ;
	%ELSE %DO;
		%PUT NOTE: CLIENT-DISPLAY-SETUP-CODE=%CMPRES(&DSPLY_CLT_SETUP_CD), EXIT THE PROCESS;
	%END;

	%IF (&DSPLY_CLT_SETUP_CD = 0 OR &DSPLY_CLT_SETUP_CD > 3) %THEN %DO;
	    %LET RESOLVE_CLIENT_TBL_EXIST_FLAG_RE = 0;
		%GOTO EXIT;
	%END;

	%*SASDOC ----------------------------------------------------------------------------------
	 | DROP &TBL_NAME_OUT_RE TABLE THAT ALREADY EXISTS IN THE DATABASE
	 | CCW4 - ADDED MIGR TABLE	
	 +-----------------------------------------------------------------------------------SASDOC;

	%IF &CC_RE_MIGR_IND = 1 %THEN %DO;
		%DROP_ORACLE_TABLE(TBL_NAME=&TBL_NAME_OUT_RE._MIGR);
	%END;
	%ELSE %DO;
		%DROP_ORACLE_TABLE(TBL_NAME=&TBL_NAME_OUT_RE);
	%END;
	 
	%*SASDOC ----------------------------------------------------------------------------------
	 | CREATE INITIATIVE AND PROGRAM-MAINTAINENCE DB2 TABLES IN ORACLE
	 +-----------------------------------------------------------------------------------SASDOC;

	 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..TINIT_CLT_RULE_DEF_&INITIATIVE_ID.);
	 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..TINIT_RE_CLT_RULE_DEF_&INITIATIVE_ID.); 
	 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..TINIT_RECAP_CLT_RL_&INITIATIVE_ID.); 
	 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..TPGMTASK_RECAP_RUL_&INITIATIVE_ID.);
	 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..RE_HIERARCHIES_&INITIATIVE_ID.); 
	 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..RE_LIST_&INITIATIVE_ID.); 
	 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..RULE_DEF_&INITIATIVE_ID.);
	 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..RE_RULE_DEF_&INITIATIVE_ID.);  
	 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..RE_INCEXC_&INITIATIVE_ID.); 
	 %DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..RE_LIST2_&INITIATIVE_ID.);

	 %*SASDOC ----------------------------------------------------------------------------------
	 | CCW4 : IF MIGRATION IND = 1, SET RUN FOR MIGRATED CLIENTS FROM RXCLAIM MACRO
	 | TBD: COMBINED CC_EFF_EXP_COND WITH CHANGES FOR TBD
	 +-----------------------------------------------------------------------------------SASDOC;

	  	PROC SQL;
			CREATE TABLE TINIT_RE_CLT_RULE_DEF AS
			SELECT * FROM &HERCULES..TINIT_CLT_RULE_DEF 
			WHERE INITIATIVE_ID = &INITIATIVE_ID;
		QUIT;

	%IF &CC_RE_MIGR_IND = 0 %THEN %DO;

		PROC SQL;
			CREATE TABLE TINIT_RECAP_CLT_RL AS
			SELECT * FROM &HERCULES..TINIT_RECAP_CLT_RL
			WHERE INITIATIVE_ID = &INITIATIVE_ID;

			CREATE TABLE TPGMTASK_RECAP_RUL AS
			SELECT * FROM &HERCULES..TPGMTASK_RECAP_RUL
			WHERE PROGRAM_ID = &PROGRAM_ID. 
			AND TASK_ID = &TASK_ID.
			AND TODAY() BETWEEN EFFECTIVE_DT AND EXPIRATION_DT;
		QUIT;

		/**** LL 10/26/2012 ****/

			%let dt    = TPGMTASK_RECAP_RUL;  

            %let nm1 = ^in('CLIENT_ID' 'HSC_USR_ID' 'OVR_CLIENT_NM'); 
			%let nm2 = ^in('CLIENT_ID' 'HSC_TS' 'EFFECTIVE_DT' 'EXPIRATION_DT' 'HSU_TS');

	        proc contents data = &dt out = t; run;

		    proc sql; 
		    select distinct(name) into: cvlist separated by ' '
			from t
			where upcase(name) &nm1   and type = 2;
			
			select distinct(count(*)) into: ccnt
			from t
			where upcase(name) &nm1   and type = 2;

			select distinct(name) into: nvlist separated by ' '
			from t
			where upcase(name) &nm2   and type = 1;
			
			select distinct(count(*)) into: ncnt
			from t
			where upcase(name) &nm2   and type = 1;
    	   quit;
		   
		   %put nvar_list = &nvlist;
		   %put cvar_list = &cvlist;
		   %put nmberc    = &ccnt;
		   %put numbern   = &ncnt;

		   %let cntc = %eval(&ccnt);
		   %put cntc = &cntc;

		   %let cntn = %eval(&ncnt);
		   %put cntn = &cntn;

		   %let cvlst = &cvlist;
		   %put cvlst = &cvlist;

		   %let nvlst = &nvlist;
		   %put nvlst = &nvlst;
			    	
	 	    data &dt; set &dt;
			length new_var1-new_var&cntc $3. frstc1-frstc&cntc $2.;

			 array wldc     {*} &cvlist;
			 array indxc    {*} indxc1-indxc&cntc;
			 array new_var  {*} new_var1-new_var&cntc; 
			 array lng      {*} lng1-lng&cntc;
			 array frtc     {*} frstc1-frstc&cntc;
			
			 /** Check for this variables in the data set the are defined as character **/

			    do i = 1 to dim(wldc);
				  indxc[i] = indexc (wldc[i], "*");
				  if substr(upcase(wldc[i]), 1, 1) = '*'  
			      then new_var[i] = substr(upcase(wldc[i]), 1, 3);
				end;
				
				/*** * at the end of the variable ***/
				 do i = 1 to dim(wldc);
				 lng[i] = length(wldc[i]);
				 if substr(upcase(wldc[i]), lng[i], 1) = '*' then new_var[i] = substr(wldc[i], 1, 2);
				end; 

				do i = 1 to dim(wldc);
				if compress(upcase(new_var[i]), '*') in ('CO' 'DC' 'ST') then
				 frtc[i] = compress(new_var[i], '*');

				 /**** Make the dataset variable clean ****/
				 if upcase(frtc[i]) in('CO' 'DC' 'ST') then wldc[i] = frtc[i];
				end; 

				drop indxc1-indxc&cntc new_var1-new_var&cntc lng1-lng&cntc frstc1-frstc&cntc i;
				run;

		%LET CC_EFF_EXP_COND = %STR(AND SYSDATE BETWEEN C.ALGN_GRP_EFF_DT AND C.ALGN_GRP_END_DT );
		%LET RL_CARRIER_ID = %STR(SUBSTR(RL.CARRIER_ID,2));
		%LET CC_CREATE_OUT_RE_COND = %STR(CREATE TABLE &TBL_NAME_OUT_RE. AS);
	%END;

	%IF &CC_RE_MIGR_IND = 1 %THEN %DO;

		%IF &DSPLY_CLT_SETUP_CD = 1 %THEN %DO;
			PROC SQL;
				CREATE TABLE TINIT_RECAP_CLT_RL AS
				SELECT * FROM &ORA_TMP..TINIT_CLT_MGRTN_RE_&INITIATIVE_ID.;

				CREATE TABLE TPGMTASK_RECAP_RUL AS
				SELECT * FROM &HERCULES..TPGMTASK_RECAP_RUL
				WHERE PROGRAM_ID = &PROGRAM_ID. 
				AND TASK_ID = &TASK_ID.
				AND TODAY() BETWEEN EFFECTIVE_DT AND EXPIRATION_DT;
	 		QUIT;
		%END;

		%IF &DSPLY_CLT_SETUP_CD=2 OR &DSPLY_CLT_SETUP_CD=3 %THEN %DO;
			PROC SQL;
				CREATE TABLE TINIT_RECAP_CLT_RL AS
				SELECT * FROM &HERCULES..TINIT_RECAP_CLT_RL
				WHERE INITIATIVE_ID = &INITIATIVE_ID;

				CREATE TABLE TPGMTASK_RECAP_RUL AS
				SELECT * FROM &ORA_TMP..TPGMTASK_CLT_MGRTN_RE_&INITIATIVE_ID.;
	 		QUIT;
		%END;

		%LET CC_EFF_EXP_COND = %STR( );
		%LET RL_CARRIER_ID = %STR(RL.CARRIER_ID);
		%LET CC_CREATE_OUT_RE_COND = %STR(CREATE TABLE &TBL_NAME_OUT_RE._MIGR AS);

	%END;
	%SET_ERROR_FL;

	PROC SQL;
		 CREATE TABLE &ORA_TMP..TINIT_RE_CLT_RULE_DEF_&INITIATIVE_ID. AS
		 SELECT * FROM TINIT_RE_CLT_RULE_DEF;

		 CREATE TABLE &ORA_TMP.. TINIT_RECAP_CLT_RL_&INITIATIVE_ID. AS
		 SELECT * FROM  TINIT_RECAP_CLT_RL;

		 CREATE TABLE &ORA_TMP..TPGMTASK_RECAP_RUL_&INITIATIVE_ID. AS
		 SELECT * FROM TPGMTASK_RECAP_RUL;
	QUIT;

	%SET_ERROR_FL;

	%*SASDOC -----------------------------------------------------------------------
	 | PROGRAM-MAINTAINENCE SETUP: TPROGRAM_TASK.DSPLY_CLT_SETUP_CD IN (2,3)
	 | NOTE: 1)DEFAULT INCLUDE / EXCLUDE IS PASSED AT PROGRAMTASK LEVEL, MEANING 
	 |       ALL CLIENTS ASSOCIATED WITH THAT PROGRAM_ID AND TASK_ID WILL HAVE THE 
	 |       SAME DEFAULT INCLUDE / EXCLUDE, UNLIKE HERCULES SETUP, IF NO ROWS EXIST
	 |       IN TPGMTASK_RECAP_RUL.
	 |       2) IF ROWS EXIST IN TPGMTASK_RECAP_RUL, THEN THE PROCESS RUNS AS PER
	 |       THE RULE SPECIFIED IN CLT_SETUP_DEF_CD IN TPGMTASK_RECAP_RUL,
	 |       AND THE DEFAULT INCLUDE / EXCLUDE SPECIFIED IN PROGRAMTASK IS IGNORED
	 |       3) THE OUPUT TABLE CREATED IS BASED ON THE DEFAULT INCLUDE / EXCLUDE 
	 |       SPECIFIED AT PROGRAMTASK LEVEL, BECAUSE THE PROCESS THAT CALLS 
	 |       RESOLVE_CLIENT HAS BEEN HARD-CODED BASED ON THE INCLUDE / EXCLUDE 
	 |       AT PROGRAMTASK LEVEL
	 |       4) THE PROCESS FOR PROGRAM MAINTAINENCE SETUP IS CODED TO RUN FOR 
	 |       DEFAULT EXCLUDE (MEANING THE FINAL TABLE CREATED HAS THE INCLUDE LIST),
	 |       BUT IF THE PROGRAM-TASK BEING RUN IS A DEFAULT INCUDE
	 |       THEN THE OUTPUT OF THE FINAL TABLE OBTAINED IS INVERSED
	 |       5)DEFAULT INCLUDE (DFL_CLT_INC_EXU_IN = 1), MEANS RUN EXCLUSION LOGIC
	 |       DEFAULT EXCLUDE (DFL_CLT_INC_EXU_IN = 0), MEANS RUN INCLUSION LOGIC
	 +-------------------------------------------------------------------------SASDOC;

	%IF &DSPLY_CLT_SETUP_CD=2 OR &DSPLY_CLT_SETUP_CD=3 %THEN %DO;

	%*SASDOC -----------------------------------------------------------------------------------------
	 | CHECK IF ATLEAST A ROW EXISTS FOR THE PROGRAM_ID-TASK_ID COMBINATION IN TPGMTASK_RECAP_RUL.
	 | 1)	IF NO ROW EXISTS, USE THE DEFAULT INCLUDE/EXCLUDE SPECIFIED IN TPROGRAMTASK TABLE
	 | 2)	IF EVEN A SINGLE ROW EXISTS, IGNORE THE DEFAULT INCLUDE/EXCLUDE SPECIFIED IN TPROGRAMTASK
	 | 		AND USE THE CLT_SETUP_DEF_CD SPECIFIED IN TPGMTASK_RECAP_RUL AT CLIENT LEVEL AND APPLY
	 | 		THE CLIENT SPECIFIC RULE ONLY FOR THOSE CLIENTS IN TPGMTASK_RECAP_RUL TABLE
	 |      PROCESS WILL RUN FOR DEFAULT EXCLUDE, BUT IF IT IS DEFAULT INCLUDE IT WILL INVERSE
	 |      THE OUTPUT
	 +------------------------------------------------------------------------------------------SASDOC;

		PROC SQL NOPRINT;
			CONNECT TO ORACLE(PATH=&GOLD );
			SELECT ROWS_EXIST_RE_RUL
			INTO :ROWS_EXIST_RE_RUL
			FROM CONNECTION TO ORACLE 
			(
			SELECT  COUNT(*) AS ROWS_EXIST_RE_RUL
			FROM &ORA_TMP..TPGMTASK_RECAP_RUL_&INITIATIVE_ID. A);
			DISCONNECT FROM ORACLE;
		QUIT;
		%PUT NOTE: NUMBER OF ROWS IN TPGMTASK_RECAP_RUL FOR PROGRAM_ID &PROGRAM_ID. - TASKID &TASK_ID. IS &ROWS_EXIST_RE_RUL;

		%SET_ERROR_FL;

	%*SASDOC -----------------------------------------------------------------------------------------
	 | IF NO ROW EXISTS IN TPGMTASK_RECAP_RUL
	 +------------------------------------------------------------------------------------------SASDOC;

		%IF &ROWS_EXIST_RE_RUL = 0 %THEN %DO;

			%PUT NOTE: TPGMTASK_RECAP_RUL IS EMPTY FOR THIS PROGRAM AND TASK;

	%*SASDOC -----------------------------------------------------------------------
	 | IF MACRO VARIABLE NO_OUTPUT_TABLES_IN = 1, EXIT THE PROCESS
	 +-------------------------------------------------------------------------SASDOC;
	 
			%IF &NO_OUTPUT_TABLES_IN_RE.= 1 %THEN %DO;
				%GOTO EXIT;
			%END;
	%*SASDOC -----------------------------------------------------------------------
	 | CREATE &TBL_NAME_OUT_RE WITH THE LIST OF ALGN_LVL_GID_KEY AND THEIR HIERARCHIES
	 | FROM DSS_CLIN.V_ALGN_LVL_DENORM TABLE IN ORACLE
	 +-------------------------------------------------------------------------SASDOC;

				%IF &DFL_CLT_INC_EXU_IN. = 1 %THEN %DO;

					PROC SQL NOPRINT;
						CONNECT TO ORACLE(PATH=&GOLD );
			  			EXECUTE 
						(
						&CC_CREATE_OUT_RE_COND.
						(SELECT DISTINCT ALGN_LVL_GID_KEY INT
					     ,INSURANCE_CD CHAR(20)
					     ,CARRIER_ID CHAR(20)
						,GROUP_CD CHAR(20)
						,QL_CLIENT_ID INT
						,PAYER_ID INT)
			  			) BY ORACLE;
			    		DISCONNECT FROM ORACLE;
					QUIT;

				%END;

				%ELSE %IF &DFL_CLT_INC_EXU_IN. = 0 %THEN %DO;

					PROC SQL NOPRINT;
						CONNECT TO ORACLE(PATH=&GOLD );
			  			EXECUTE 
						(
						&CC_CREATE_OUT_RE_COND.
						SELECT DISTINCT C.ALGN_LVL_GID_KEY
					               	   ,C.RPT_OPT1_CD AS INSURANCE_CD
								   	   ,C.EXTNL_LVL_ID1 AS CARRIER_ID
								   	   ,C.EXTNL_LVL_ID3 AS GROUP_CD
								   	   ,C.QL_CLNT_ID AS QL_CLIENT_ID
									   ,C.PAYER_ID
			        	FROM  DSS_CLIN.V_ALGN_LVL_DENORM C
						WHERE C.SRC_SYS_CD = 'R'
						%IF NOT (&PROGRAM_ID EQ 105 OR (&PROGRAM_ID EQ 106 AND &TASK_ID EQ 21)) %THEN %DO;
	           				&CC_EFF_EXP_COND.
						%END;
			  			) BY ORACLE;
			    		DISCONNECT FROM ORACLE;
					QUIT;

					%SET_ERROR_FL;

				%END;


	 		%LET RESOLVE_CLIENT_TBL_EXIST_FLAG_RE = 1;

		%END;

	%*SASDOC -----------------------------------------------------------------------------------------
	 | IF ROW EXISTS IN TPGMTASK_RE_RUL
	 +------------------------------------------------------------------------------------------SASDOC;

		%ELSE %IF &ROWS_EXIST_RE_RUL >= 1 %THEN %DO;

	%*SASDOC -----------------------------------------------------------------------
	 | IF MACRO VARIABLE NO_OUTPUT_TABLES_IN = 1, EXIT THE PROCESS
	 +-------------------------------------------------------------------------SASDOC;
	 
			%IF &NO_OUTPUT_TABLES_IN_RE.= 1 %THEN %DO;
				%GOTO EXIT;
			%END;

	%*SASDOC -----------------------------------------------------------------------
	 | CREATE A DATASET RE_HIERARCHIES WITH ALGN_LVL_GID_KEY ALONG WITH HIERARCHIES 
	 | AND CLT_SETUP_DEF_CD THAT IS SPECIFIED IN TPGMTASK_RECAP_RUL.
	 +-------------------------------------------------------------------------SASDOC;

			PROC SQL NOPRINT;
				CONNECT TO ORACLE(PATH=&GOLD );
	  			EXECUTE 
				(
				CREATE TABLE &ORA_TMP..RE_HIERARCHIES_&INITIATIVE_ID. AS
				SELECT DISTINCT A.ALGN_LVL_GID_KEY 
			               	   ,A.RPT_OPT1_CD AS INSURANCE_CD
						   	   ,A.EXTNL_LVL_ID1 AS CARRIER_ID
						   	   ,A.EXTNL_LVL_ID3 AS GROUP_CD
						   	   ,A.QL_CLNT_ID AS QL_CLIENT_ID
							   ,A.PAYER_ID
							   ,B.CLT_SETUP_DEF_CD
	        	FROM  (SELECT C.ALGN_LVL_GID_KEY, C.RPT_OPT1_CD, C.EXTNL_LVL_ID1,  
	                          C.EXTNL_LVL_ID3, C.QL_CLNT_ID, C.PAYER_ID
	                   FROM DSS_CLIN.V_ALGN_LVL_DENORM C
	                   WHERE C.SRC_SYS_CD = 'R'
						%IF NOT (&PROGRAM_ID EQ 105 OR (&PROGRAM_ID EQ 106 AND &TASK_ID EQ 21)) %THEN %DO;
	           				&CC_EFF_EXP_COND.
						%END;
	                   ) A
				RIGHT JOIN
	                  (SELECT INSURANCE_CD, CLT_SETUP_DEF_CD
					   FROM &ORA_TMP..TPGMTASK_RECAP_RUL_&INITIATIVE_ID.) B
				ON A.RPT_OPT1_CD = B.INSURANCE_CD
				ORDER BY INSURANCE_CD, CARRIER_ID, GROUP_CD
	  			)BY ORACLE;
	    		DISCONNECT FROM ORACLE;
			QUIT;

			%SET_ERROR_FL;

	%*SASDOC ----------------------------------------------------------------------------
	 | WHOLE CLIENT INCLUSION: CLT_SETUP_DEF_CD=1.
	 | CREATE DATASET RE_LIST WITH THE CONSTRAINT CLT_SETUP_DEF_CD=1.
	 +----------------------------------------------------------------------------SASDOC*;

			PROC SQL NOPRINT;
				CONNECT TO ORACLE(PATH=&GOLD );
	  			EXECUTE 
				(
				CREATE TABLE &ORA_TMP..RE_LIST_&INITIATIVE_ID. AS
	      		SELECT  A.ALGN_LVL_GID_KEY 
			           ,A.INSURANCE_CD
					   ,A.CARRIER_ID
					   ,A.GROUP_CD
					   ,A.QL_CLIENT_ID
					   ,A.PAYER_ID
			 	FROM  &ORA_TMP..RE_HIERARCHIES_&INITIATIVE_ID. A
			 	WHERE A.CLT_SETUP_DEF_CD = 1
	  			)BY ORACLE;
	    		DISCONNECT FROM ORACLE;
			QUIT;

			%SET_ERROR_FL;

	%*SASDOC -----------------------------------------------------------------------
	 | CREATE DATASET RULE_DEF FROM TPGMTASK_RECAP_RUL
	 +-------------------------------------------------------------------------SASDOC;

			PROC SQL NOPRINT;
				CONNECT TO ORACLE(PATH=&GOLD );
	  			EXECUTE 
				(
				CREATE TABLE &ORA_TMP..RE_RULE_DEF_&INITIATIVE_ID. AS
				SELECT DISTINCT RL.PROGRAM_ID, RL.TASK_ID, 
				RL.INSURANCE_CD, &RL_CARRIER_ID. AS CARRIER_ID, RL.GROUP_CD, RL.CLT_SETUP_DEF_CD
	        	FROM &ORA_TMP..TPGMTASK_RECAP_RUL_&INITIATIVE_ID. RL
	  			)BY ORACLE;
	    		DISCONNECT FROM ORACLE;
			QUIT;

			%SET_ERROR_FL;

	%*SASDOC -----------------------------------------------------------------------
	 | CREATE DATASET RE_INCEXC WITH THE REQUIRED TABLE STRUCTURE.
	 | ROWS WILL BE INSERTED INTO THIS TABLE FOR INCLUDES AND EXCLUDES BASED ON HIERARCHY_CONS
	 +-------------------------------------------------------------------------SASDOC;
			%LET HIERARCHY_CONS = %STR( 
	            					AND (RULE.CARRIER_ID = ' ' OR RULE.CARRIER_ID IS NULL OR
	                 					UPPER(LTRIM(RTRIM(RULE.CARRIER_ID))) = UPPER(LTRIM(RTRIM(RE.CARRIER_ID))))
	            					AND (RULE.GROUP_CD = ' ' OR RULE.GROUP_CD IS NULL OR
	                 					UPPER(LTRIM(RTRIM(RULE.GROUP_CD))) = UPPER(LTRIM(RTRIM(RE.GROUP_CD))))
	             			     	  );
			PROC SQL NOPRINT;
				CONNECT TO ORACLE(PATH=&GOLD );
	  			EXECUTE 
				(
				CREATE TABLE &ORA_TMP..RE_INCEXC_&INITIATIVE_ID.	AS
	      		SELECT  RE.ALGN_LVL_GID_KEY, RE.INSURANCE_CD, RE.CARRIER_ID, RE.GROUP_CD, RULE.CLT_SETUP_DEF_CD
				FROM  &ORA_TMP..RE_HIERARCHIES_&INITIATIVE_ID. RE
			     	 ,&ORA_TMP..RE_RULE_DEF_&INITIATIVE_ID. RULE
				WHERE RE.CLT_SETUP_DEF_CD IN (2,3)
	              AND UPPER(LTRIM(RTRIM(RULE.INSURANCE_CD))) = UPPER(LTRIM(RTRIM(RE.INSURANCE_CD)))
			  	&HIERARCHY_CONS. 
				ORDER BY RE.INSURANCE_CD, RE.CARRIER_ID, RE.GROUP_CD
	  			)BY ORACLE;
	    		DISCONNECT FROM ORACLE;
			QUIT;

			%SET_ERROR_FL;

	%*SASDOC ----------------------------------------------------------------------------
	 | PARTIAL INCLUSION: CLT_SETUP_DEF_CD = 3
	 | INSERT INTO DATASET RE_LIST WHERE ALGN_LVL_GID_KEYs ARE IN RE_INCEXC 
	 | WITH CLT_SETUP_DEF_CD = 3
	 +----------------------------------------------------------------------------SASDOC*;

			PROC SQL NOPRINT;
				CONNECT TO ORACLE(PATH=&GOLD );
	  			EXECUTE 
				(
				INSERT INTO &ORA_TMP..RE_LIST_&INITIATIVE_ID.
	      		SELECT  A.ALGN_LVL_GID_KEY 
			           ,A.INSURANCE_CD
					   ,A.CARRIER_ID
					   ,A.GROUP_CD
					   ,A.QL_CLIENT_ID
					   ,A.PAYER_ID
			 	FROM  &ORA_TMP..RE_HIERARCHIES_&INITIATIVE_ID.  A
			      	 ,&ORA_TMP..RE_INCEXC_&INITIATIVE_ID. B
			 	WHERE B.CLT_SETUP_DEF_CD = 3 
			      AND UPPER(LTRIM(RTRIM(A.INSURANCE_CD))) = UPPER(LTRIM(RTRIM(B.INSURANCE_CD)))
			   	  AND A.ALGN_LVL_GID_KEY  = B.ALGN_LVL_GID_KEY
	  			)BY ORACLE;
	    		DISCONNECT FROM ORACLE;
			QUIT;

			%SET_ERROR_FL;

	%*SASDOC ----------------------------------------------------------------------------
	 | CLIENT WITH EXCLUSIONS AND WHOLE CLIENT EXCLUDE LOGIC.
	 | IF FOR A PROGRAM TASK, THERE EXISTS BOTH CLT_SETUP_DEF_CD 2 AND 4, THEN
	 | ONLY THE LOGIC FOR CLT_SETUP_DEF_CD = 2 EXECUTES AS IT TAKES CARE OF THE OTHER
	 | SCENERIO ALSO.
	 | IF EITHER CLT_SETUP_DEF_CD = 2 OR CLT_SETUP_DEF_CD = 4 THEN THE CORRESPONDING
	 | LOGIC EXECUTES.
	 +----------------------------------------------------------------------------SASDOC*;

			PROC SQL NOPRINT;
				CONNECT TO ORACLE(PATH=&GOLD );
				SELECT EXCCOUNT, MAX_DEF_CD
				INTO :EXCCOUNT, :MAX_DEF_CD
	        	FROM CONNECTION TO ORACLE
	   			(
				SELECT COUNT(DISTINCT CLT_SETUP_DEF_CD) as EXCCOUNT
				      ,MAX(CLT_SETUP_DEF_CD) AS MAX_DEF_CD
				FROM &ORA_TMP..TPGMTASK_RECAP_RUL_&INITIATIVE_ID. 
				WHERE CLT_SETUP_DEF_CD IN (2,4)
	  			);
	    		DISCONNECT FROM ORACLE;
			QUIT;

			%SET_ERROR_FL;

	%*SASDOC ----------------------------------------------------------------------------
	 | CLIENT WITH EXCLUSIONS: CLT_SETUP_DEF_CD = 2
	 | INSERT INTO RE_LIST WHERE ALGN_LVL_GID_KEYs ARE NOT IN RE_INCEXC 
	 | WITH CLT_SETUP_DEF_CD = 2, BUT IN RE_HIERARCHIES WHERE CLT_SETUP_DEF_CD = 2 OR 
	 | CLT_SETUP_DEF_CD IS NULL
	 +----------------------------------------------------------------------------SASDOC*;

			%IF (&EXCCOUNT = 1 AND &MAX_DEF_CD = 2) OR 
				(&EXCCOUNT = 2 AND &MAX_DEF_CD = 4) 
			%THEN %DO;

				PROC SQL NOPRINT;
					CONNECT TO ORACLE(PATH=&GOLD );
	  				EXECUTE 
					(
					INSERT INTO &ORA_TMP..RE_LIST_&INITIATIVE_ID.
		      		SELECT  A.ALGN_LVL_GID_KEY 
			           		,A.INSURANCE_CD
					   		,A.CARRIER_ID
					   		,A.GROUP_CD
					   		,A.QL_CLIENT_ID
							,A.PAYER_ID
			 		FROM  &ORA_TMP..RE_HIERARCHIES_&INITIATIVE_ID. A
	         		WHERE (A.CLT_SETUP_DEF_CD = 2 OR A.CLT_SETUP_DEF_CD IS NULL)
			   	  	  AND NOT EXISTS (SELECT 1
			                   	  	  FROM &ORA_TMP..RE_INCEXC_&INITIATIVE_ID. B
	                           	      WHERE UPPER(LTRIM(RTRIM(A.INSURANCE_CD))) = UPPER(LTRIM(RTRIM(B.INSURANCE_CD)))
							     	    AND B.CLT_SETUP_DEF_CD = 2
							     	    AND A.ALGN_LVL_GID_KEY  = B.ALGN_LVL_GID_KEY )
	  				)BY ORACLE;
	    			DISCONNECT FROM ORACLE;
				QUIT;

				%SET_ERROR_FL;

			%END;

			%ELSE %IF (&EXCCOUNT = 1 AND &MAX_DEF_CD = 4) 
			%THEN %DO;

	%*SASDOC ----------------------------------------------------------------------------
	 | WHOLE CLIENT EXCLUDE: CLT_SETUP_DEF_CD = 4
	 | NOTE: THIS QUERY RUNS ONLY WHEN THERE ARE NO ROWS FOR CLT_SETUP_DEF_CD = 2
	 |       FOR THE PROGRAM-TASK THE PROCESS IS RUN FOR, BECAUSE IF THERE WERE ROWS
	 |       FOR CLT_SETUP_DEF_CD = 2, IT WOULD HAVE ALREADY TAKEN CARE OF ENTIRE CLIENT
	 |       EXCLUDE CRITERIA
	 | INSERT INTO DATASET RE_LIST ALGN_LVL_GID_KEYs ARE IN RE_INCEXC 
	 | WITH CLT_SETUP_DEF_CD = 4
	 +----------------------------------------------------------------------------SASDOC*;

				PROC SQL NOPRINT;
					CONNECT TO ORACLE(PATH=&GOLD );
	  				EXECUTE 
					(
					INSERT INTO &ORA_TMP..RE_LIST_&INITIATIVE_ID.
	      			SELECT  ALGN_LVL_GID_KEY 
			           		,INSURANCE_CD
					   		,CARRIER_ID
					   		,GROUP_CD
					   		,QL_CLIENT_ID
							,PAYER_ID
			 		FROM  &ORA_TMP..RE_HIERARCHIES_&INITIATIVE_ID. 
			 		WHERE CLT_SETUP_DEF_CD IS NULL
	  				)BY ORACLE;
	    			DISCONNECT FROM ORACLE;
				QUIT;

				%SET_ERROR_FL;

			%END;

			PROC SQL NOPRINT;
				CONNECT TO ORACLE(PATH=&GOLD );
	  			EXECUTE 
				(
				CREATE INDEX RE_LIST_&INITIATIVE_ID. ON &ORA_TMP..RE_LIST_&INITIATIVE_ID. ( ALGN_LVL_GID_KEY, INSURANCE_CD )
	  			)BY ORACLE;
	    		DISCONNECT FROM ORACLE;
			QUIT;

			%SET_ERROR_FL;

			PROC SQL NOPRINT;
				CONNECT TO ORACLE(PATH=&GOLD );
	  			EXECUTE 
				(
				CREATE INDEX RE_HIERARCHIES_&INITIATIVE_ID. ON &ORA_TMP..RE_HIERARCHIES_&INITIATIVE_ID. ( ALGN_LVL_GID_KEY, INSURANCE_CD )
	  			)BY ORACLE;
	    		DISCONNECT FROM ORACLE;
			QUIT;

			%SET_ERROR_FL;

			%IF &DFL_CLT_INC_EXU_IN. = 1 %THEN %DO;

				PROC SQL NOPRINT;
					CONNECT TO ORACLE(PATH=&GOLD );
			  		EXECUTE 
					(
					CREATE TABLE &ORA_TMP..RE_LIST2_&INITIATIVE_ID. AS
					SELECT *
					FROM &ORA_TMP..RE_HIERARCHIES_&INITIATIVE_ID. A
					WHERE NOT EXISTS (SELECT 1
									  FROM &ORA_TMP..RE_LIST_&INITIATIVE_ID. B
									  WHERE A.ALGN_LVL_GID_KEY = B.ALGN_LVL_GID_KEY AND
									        A.INSURANCE_CD = B.INSURANCE_CD)
			  		)BY ORACLE;
			    	DISCONNECT FROM ORACLE;
				QUIT;

				%SET_ERROR_FL;

	%*SASDOC ----------------------------------------------------------------------------
	 | CREATE TABLE &TBL_NAME_OUT_RE. WITH DATASET RE_LIST2
	 +----------------------------------------------------------------------------SASDOC*;

				PROC SQL NOPRINT;
					CONNECT TO ORACLE(PATH=&GOLD );
		  			EXECUTE 
					(
					&CC_CREATE_OUT_RE_COND.
					SELECT ALGN_LVL_GID_KEY 
							,INSURANCE_CD
			           		,CARRIER_ID
					   		,GROUP_CD
					   		,QL_CLIENT_ID
							,PAYER_ID
					FROM &ORA_TMP..RE_LIST2_&INITIATIVE_ID. 
		  			)BY ORACLE;
		    		DISCONNECT FROM ORACLE;
				QUIT;

				%SET_ERROR_FL;

			%END;

			%ELSE %DO;

	%*SASDOC ----------------------------------------------------------------------------
	 | CREATE TABLE &TBL_NAME_OUT_RE. WITH DATASET RE_LIST
	 | CCW4: FOR MIGRATED CLIENT CREATE SPECIFIC MIGR TABLE
	 +----------------------------------------------------------------------------SASDOC*;

				PROC SQL NOPRINT;
					CONNECT TO ORACLE(PATH=&GOLD );
		  			EXECUTE 
					(
					&CC_CREATE_OUT_RE_COND.
					SELECT ALGN_LVL_GID_KEY 
							,INSURANCE_CD
			           		,CARRIER_ID
					   		,GROUP_CD
					   		,QL_CLIENT_ID
							,PAYER_ID
					FROM &ORA_TMP..RE_LIST_&INITIATIVE_ID. 
		  			)BY ORACLE;
		    		DISCONNECT FROM ORACLE;
				QUIT;

				%SET_ERROR_FL;

			%END;

	 	%LET RESOLVE_CLIENT_TBL_EXIST_FLAG_RE = 1;

		%END;

	%END;

	%SET_ERROR_FL;
	%ON_ERROR( ACTION=ABORT
	          ,EM_TO=&PRIMARY_PROGRAMMER_EMAIL
	          ,EM_SUBJECT=HCE SUPPORT: NOTIFICATION OF ABEND INITIATIVE_ID &INITIATIVE_ID
	          ,EM_MSG=%STR(A PROBLEM WAS ENCOUNTERED IN THE &MAC_NAME. MACRO PLEASE CHECK THE LOG ASSOCIATED WITH INITIATIVE_ID &INITIATIVE_ID.));

	%*SASDOC -----------------------------------------------------------------------
	 | INITIATIVE SETUP: TPROGRAM_TASK.DSPLY_CLT_SETUP_CD=2 OR OVRD_CLT_SETUP_IN = 1
	 | NOTE: THE SETUP CAN BE SPLIT INTO THREE CATEGORIES
	 |       1) WHOLE CLIENT INCLUSION, DEFAULT EXCLUDE IN COMMUNICATION ENGINE 
	 |          (TINIT_CLT_RULE_DEF.CLT_SETUP_DEF_CD = 1)
	 |       2) CLIENT WITH EXCLUSIONS 
	 |          (TINIT_CLT_RULE_DEF.CLT_SETUP_DEF_CD = 2)
	 |       3) PARTIAL CLIENT -INCLUSIONS ONLY 
	 |          (TINIT_CLT_RULE_DEF.CLT_SETUP_DEF_CD = 3)
	 +-------------------------------------------------------------------------SASDOC;

	%IF &DSPLY_CLT_SETUP_CD=1 %THEN %DO;

	%*SASDOC -----------------------------------------------------------------------
	 | IF MACRO VARIABLE NO_OUTPUT_TABLES_IN = 1, EXIT THE PROCESS
	 +-------------------------------------------------------------------------SASDOC;
	 
		%IF &NO_OUTPUT_TABLES_IN_RE.= 1 %THEN 
			%GOTO EXIT;

	%*SASDOC -----------------------------------------------------------------------
	 | CREATE DATASET RE_HIERARCHIES WITH A LIST OF CLIENTID
	 | ALONG WITH THEIR HIERARCHIES FROM TABLES V_ALGN_LVL_DENORM
	 +-------------------------------------------------------------------------SASDOC;
		PROC SQL NOPRINT;
			CONNECT TO ORACLE(PATH=&GOLD );
	  		EXECUTE 
			(
			CREATE TABLE &ORA_TMP..RE_HIERARCHIES_&INITIATIVE_ID. AS
	 		SELECT  DISTINCT C.ALGN_LVL_GID_KEY 
			           		,C.RPT_OPT1_CD AS INSURANCE_CD
					   		,C.EXTNL_LVL_ID1 AS CARRIER_ID
					   		,C.EXTNL_LVL_ID3 AS GROUP_CD
					   		,C.QL_CLNT_ID AS QL_CLIENT_ID
							,C.PAYER_ID
							,A.CLT_SETUP_DEF_CD
	  		FROM &ORA_TMP..TINIT_RE_CLT_RULE_DEF_&INITIATIVE_ID. A
			    ,&ORA_TMP..TINIT_RECAP_CLT_RL_&INITIATIVE_ID. B
				,DSS_CLIN.V_ALGN_LVL_DENORM C
	   		WHERE A.INITIATIVE_ID=&INITIATIVE_ID
			  AND A.INITIATIVE_ID=B.INITIATIVE_ID
			  AND A.CLIENT_ID = B.CLIENT_ID
			  AND C.SRC_SYS_CD = 'R'
			  %IF NOT (&PROGRAM_ID EQ 105 OR (&PROGRAM_ID EQ 106 AND &TASK_ID EQ 21)) %THEN %DO;
	           			&CC_EFF_EXP_COND.
			  %END;
	          AND UPPER(RTRIM(LTRIM(B.INSURANCE_CD))) = UPPER(RTRIM(LTRIM(C.RPT_OPT1_CD)))
			  &SAMPLE_REC.
			ORDER BY C.RPT_OPT1_CD, C.EXTNL_LVL_ID1, C.EXTNL_LVL_ID3

	  		)BY ORACLE;
	    	DISCONNECT FROM ORACLE;
		QUIT;

		%SET_ERROR_FL;

	%*SASDOC -----------------------------------------------------------------------
	 | CREATE DATASET RULE_DEF WITH ALGN_LVL_GID_KEY ALONG WITH HIERARCHIES AND 
	 | SET-UP DEFINITIONS (WHOLE CLIENT, CLIENT WITH EXCLUSIONS,
	 | PARTIAL CLIENT INCLUSIONS, FROM TABLES TINIT_RECAP_CLT_RL & TINIT_CLT_RULE_DEF
	 +-------------------------------------------------------------------------SASDOC;

		PROC SQL NOPRINT;
			CONNECT TO ORACLE(PATH=&GOLD );
	  		EXECUTE 
			(
			CREATE TABLE &ORA_TMP..RE_RULE_DEF_&INITIATIVE_ID. AS
			SELECT DISTINCT RL.INSURANCE_CD, &RL_CARRIER_ID. AS CARRIER_ID,
	                        RL.GROUP_CD, SETUP.CLT_SETUP_DEF_CD
	        FROM  &ORA_TMP..TINIT_RECAP_CLT_RL_&INITIATIVE_ID. RL,
	              &ORA_TMP..TINIT_RE_CLT_RULE_DEF_&INITIATIVE_ID. SETUP
			WHERE RL.INITIATIVE_ID=&INITIATIVE_ID. 
	          AND RL.INITIATIVE_ID=SETUP.INITIATIVE_ID
	          AND RL.CLIENT_ID = SETUP.CLIENT_ID
			ORDER BY RL.INSURANCE_CD, &RL_CARRIER_ID., RL.GROUP_CD
	  		)BY ORACLE;
	    	DISCONNECT FROM ORACLE;
		QUIT;

		%SET_ERROR_FL;

	%*SASDOC ----------------------------------------------------------------------------
	 | WHOLE CLIENT INCLUSION: CLT_SETUP_DEF_CD=1.
	 | CREATE DATASET RE_LIST WITH THE CONSTRAINT CLT_SETUP_DEF_CD=1.
	 +----------------------------------------------------------------------------SASDOC*;

		PROC SQL NOPRINT;
			CONNECT TO ORACLE(PATH=&GOLD );
	  		EXECUTE 
			(
			CREATE TABLE &ORA_TMP..RE_LIST_&INITIATIVE_ID. AS
	      	SELECT  A.ALGN_LVL_GID_KEY 
			       ,A.INSURANCE_CD
				   ,A.CARRIER_ID
				   ,A.GROUP_CD
				   ,A.QL_CLIENT_ID
				   ,A.PAYER_ID
			 FROM  &ORA_TMP..RE_HIERARCHIES_&INITIATIVE_ID. A
			 WHERE A.CLT_SETUP_DEF_CD = 1
	  		)BY ORACLE;
	    	DISCONNECT FROM ORACLE;
		QUIT;

		%SET_ERROR_FL;

	%*SASDOC -----------------------------------------------------------------------
	 | CREATE DATASET RE_INCEXC WITH THE REQUIRED TABLE STRUCTURE.
	 | ROWS WILL BE INSERTED INTO THIS TABLE FOR INCLUDES AND EXCLUDES BASED ON HIERARCHY_CONS
	 +-------------------------------------------------------------------------SASDOC;

		%LET HIERARCHY_CONS = %STR( 
	            					AND (RULE.CARRIER_ID IS NULL OR RULE.CARRIER_ID = ' ' OR 
	                 					UPPER(LTRIM(RTRIM(RULE.CARRIER_ID))) = UPPER(LTRIM(RTRIM(RE.CARRIER_ID))))
	            					AND (RULE.GROUP_CD IS NULL OR RULE.GROUP_CD = ' ' OR 
	                 					UPPER(LTRIM(RTRIM(RULE.GROUP_CD))) = UPPER(LTRIM(RTRIM(RE.GROUP_CD))))
	             			      );

		PROC SQL NOPRINT;
			CONNECT TO ORACLE(PATH=&GOLD );
	  		EXECUTE 
			(
			CREATE TABLE &ORA_TMP..RE_INCEXC_&INITIATIVE_ID.	AS
	     	SELECT  RE.ALGN_LVL_GID_KEY, RE.INSURANCE_CD, RE.CARRIER_ID, RE.GROUP_CD, RULE.CLT_SETUP_DEF_CD
			FROM  &ORA_TMP..RE_HIERARCHIES_&INITIATIVE_ID. RE
		     	 ,&ORA_TMP..RE_RULE_DEF_&INITIATIVE_ID. RULE
			WHERE RE.CLT_SETUP_DEF_CD IN (2,3)
	          AND UPPER(LTRIM(RTRIM(RULE.INSURANCE_CD))) = UPPER(LTRIM(RTRIM(RE.INSURANCE_CD)))
		      &HIERARCHY_CONS. 
			ORDER BY RE.INSURANCE_CD, RE.CARRIER_ID, RE.GROUP_CD
	  		)BY ORACLE;
	    	DISCONNECT FROM ORACLE;
		QUIT;

		%SET_ERROR_FL;

	%*SASDOC ----------------------------------------------------------------------------
	 | CLIENT WITH EXCLUSIONS: CLT_SETUP_DEF_CD is 2
	 | INSERT INTO DATASET RE_LIST WHERE ALGN_LVL_GID_KEY ARE NOT IN RE_INCEXC 
	 | WITH CLT_SETUP_DEF_CD = 2
	 +----------------------------------------------------------------------------SASDOC*;

			PROC SQL NOPRINT;
				CONNECT TO ORACLE(PATH=&GOLD );
		  		EXECUTE 
				(
				INSERT INTO &ORA_TMP..RE_LIST_&INITIATIVE_ID.
	      		SELECT  A.ALGN_LVL_GID_KEY 
			           ,A.INSURANCE_CD
					   ,A.CARRIER_ID
					   ,A.GROUP_CD
					   ,A.QL_CLIENT_ID
					   ,A.PAYER_ID
			 	FROM  &ORA_TMP..RE_HIERARCHIES_&INITIATIVE_ID. A
	         	WHERE A.CLT_SETUP_DEF_CD = 2
			   	  AND NOT EXISTS (SELECT 1
			                   	  FROM &ORA_TMP..RE_INCEXC_&INITIATIVE_ID. B
	                           	  WHERE UPPER(LTRIM(RTRIM(A.INSURANCE_CD))) = UPPER(LTRIM(RTRIM(B.INSURANCE_CD)))
							     	AND B.CLT_SETUP_DEF_CD = 2
							     	AND A.ALGN_LVL_GID_KEY  = B.ALGN_LVL_GID_KEY )
		  		)BY ORACLE;
		    	DISCONNECT FROM ORACLE;
			QUIT;
			%SET_ERROR_FL;

	%*SASDOC ----------------------------------------------------------------------------
	 | CLIENT WITH EXCLUSIONS: CLT_SETUP_DEF_CD is 3
	 | INSERT INTO DATASET RE_LIST WHERE ALGN_LVL_GID_KEYs ARE IN RE_INCEXC 
	 | WITH CLT_SETUP_DEF_CD = 3
	 +----------------------------------------------------------------------------SASDOC*;

			PROC SQL NOPRINT;
				CONNECT TO ORACLE(PATH=&GOLD );
		  		EXECUTE 
				(
				INSERT INTO &ORA_TMP..RE_LIST_&INITIATIVE_ID.
	      		SELECT  A.ALGN_LVL_GID_KEY 
			           ,A.INSURANCE_CD
					   ,A.CARRIER_ID
					   ,A.GROUP_CD
					   ,A.QL_CLIENT_ID
					   ,A.PAYER_ID
			 	FROM  &ORA_TMP..RE_HIERARCHIES_&INITIATIVE_ID. A
			      	 ,&ORA_TMP..RE_INCEXC_&INITIATIVE_ID. B
			 	WHERE B.CLT_SETUP_DEF_CD = 3 
			      AND UPPER(LTRIM(RTRIM(A.INSURANCE_CD))) = UPPER(LTRIM(RTRIM(B.INSURANCE_CD)))
			   	  AND A.ALGN_LVL_GID_KEY  = B.ALGN_LVL_GID_KEY
		  		)BY ORACLE;
		    	DISCONNECT FROM ORACLE;
			QUIT;

			%SET_ERROR_FL;

	%*SASDOC ----------------------------------------------------------------------------
	 | CREATE TABLE &TBL_NAME_OUT_RE. WITH DATASET RE_LIST
	 +----------------------------------------------------------------------------SASDOC*;
			PROC SQL NOPRINT;
				CONNECT TO ORACLE(PATH=&GOLD );
	  			EXECUTE 
				(
				&CC_CREATE_OUT_RE_COND.
				SELECT ALGN_LVL_GID_KEY 
						,INSURANCE_CD
		           		,CARRIER_ID
				   		,GROUP_CD
				   		,QL_CLIENT_ID
						,PAYER_ID
				FROM &ORA_TMP..RE_LIST_&INITIATIVE_ID. 
	  			)BY ORACLE;
	    		DISCONNECT FROM ORACLE;
			QUIT;

			%SET_ERROR_FL;

		%IF &CC_RE_MIGR_IND = 0 %THEN %DO;

	   		%NOBS(&TBL_NAME_OUT_RE.);

	    	%IF &NOBS %THEN %DO;
				%LET RESOLVE_CLIENT_TBL_EXIST_FLAG_RE=1;
			%END;
			%ELSE %DO; 
				%LET RESOLVE_CLIENT_TBL_EXIST_FLAG_RE=0;
			%END;
		%END;
	%END;

	%EXIT:;

	%*SASDOC -----------------------------------------------------------------------------
	 | IF TBL_NAME_IN_RE AND TBL_NAME_OUT_RE2 ARE PASSED AS INPUT PARAMETERS, THEN
	 | IF &EXECUTE_CONDITION_FLAG.=1 THEN 
	 |       POPULATE &TBL_NAME_OUT_RE2. BASED ON &TBL_NAME_IN_RE. AND &TBL_NAME_OUT_RE.
	 | ELSE JUST CREATE &TBL_NAME_OUT_RE2. AS AN ALIAS OF &TBL_NAME_IN_RE. 
	 +------------------------------------------------------------------------------SASDOC*;

	%IF &TBL_NAME_IN_RE. NE AND &TBL_NAME_OUT_RE2. NE AND &ERR_FL=0 %THEN %DO;
		%DROP_ORACLE_TABLE(TBL_NAME=&TBL_NAME_OUT_RE2.);

	 	%IF &EXECUTE_CONDITION_FLAG.=1 %THEN %DO;	

			PROC SQL NOPRINT;
				CONNECT TO ORACLE(PATH=&GOLD );
				CREATE TABLE &TBL_NAME_OUT_RE2. AS
	        	SELECT * FROM CONNECTION TO ORACLE
	   			(
	    	    SELECT A.*
			    FROM &TBL_NAME_IN_RE. A
	            LEFT JOIN
			 		 (SELECT *
					  FROM &TBL_NAME_OUT_RE.
					  WHERE ALGN_LVL_GID_KEY  &HIERARCHY_CONDITION.) B
	            ON A.ALGN_LVL_GID_KEY  = B.ALGN_LVL_GID_KEY 
				);
	   			DISCONNECT FROM ORACLE;
	  		QUIT;

			%SET_ERROR_FL;

		%END; /* END OF &EXECUTE_CONDITION_FLAG.=1, TRUE */ 
		%ELSE %DO;
			PROC SQL;
				CONNECT TO ORACLE(PATH=&GOLD );
	   			EXECUTE
				(
				CREATE SYNONYM &TBL_NAME_OUT_RE2.  
				FOR &TBL_NAME_IN_RE. 
				) BY ORACLE;
				DISCONNECT FROM ORACLE;
			QUIT;

			%SET_ERROR_FL;

		%END; /* END OF &EXECUTE_CONDITION_FLAG.=1, FALSE */ 
	%END;

	%ON_ERROR( ACTION=ABORT
	          ,EM_TO=&PRIMARY_PROGRAMMER_EMAIL
	          ,EM_SUBJECT=HCE SUPPORT: NOTIFICATION OF ABEND INITIATIVE_ID &INITIATIVE_ID
	          ,EM_MSG=%STR(A PROBLEM WAS ENCOUNTERED IN THE &MAC_NAME. MACRO PLEASE CHECK THE LOG ASSOCIATED WITH INITIATIVE_ID &INITIATIVE_ID.));

	%MEND RESOLVE_CLIENT_RE;
