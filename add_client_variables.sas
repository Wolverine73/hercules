%macro add_client_variables(INIT_ID=);

	%LOCAL TEMP_CLIENT_TABLE SAS_DATASET CPG_VARIABLE TEMP_COUNT TEMP_COUNT2 ;

	%LET TEMP_CLIENT_TABLE=%STR(QCPAP020.ADD_CLIENT_VARIABLES_&INIT_ID.); 
	%LET SAS_DATASET=%STR(DATA_PND.T_&INIT_ID._&PHASE_SEQ_NB._1);

	%IF %SYSFUNC(EXIST(DATA_PND.T_&INIT_ID._&PHASE_SEQ_NB._1)) %THEN %DO;
	%PUT NOTE: &SAS_DATASET. EXISTS. ;

	PROC SQL NOPRINT;
	  DROP TABLE &TEMP_CLIENT_TABLE.;   
	QUIT;

	PROC CONTENTS DATA = &SAS_DATASET. OUT = TEMP_CONTENTS (KEEP = NAME) NOPRINT;
	RUN;

	%LET CPG_VARIABLE=;

	DATA _NULL_;
	 SET TEMP_CONTENTS (WHERE=(UPCASE(NAME)='CLT_PLAN_GROUP_ID'));
	 CALL SYMPUT('CPG_VARIABLE',NAME);
	RUN;

	%PUT NOTE: CPG_VARIABLE = &CPG_VARIABLE. ;

	%IF &CPG_VARIABLE. NE %THEN %DO;
	%END;
	%ELSE %DO;  /** missing cpg variable - retrieve from temp db2 table **/

		%IF &PROGRAM_ID = 5259 %THEN %DO;
		  %IF %SYSFUNC(EXIST(&DB2_TMP..&TABLE_PREFIX._CPG_ELIG)) %THEN %DO;  /** QL initiatives **/
		    %PUT NOTE: &DB2_TMP..&TABLE_PREFIX._DETAIL EXISTS. ;
			DATA DB2_DETAIL ;
			 SET &DB2_TMP..&TABLE_PREFIX._DETAIL (KEEP=PT_BENEFICIARY_ID CLT_PLAN_GROUP_ID);
			 RECIPIENT_ID=PT_BENEFICIARY_ID;
			 DROP PT_BENEFICIARY_ID;
			RUN;

			PROC SORT DATA = DB2_DETAIL NODUPKEY;
			  BY RECIPIENT_ID;
			RUN;

			PROC SQL NOPRINT;
			  CREATE TABLE &SAS_DATASET. AS
			  SELECT A.*, B.CLT_PLAN_GROUP_ID AS TEMP_CPG
			  FROM &SAS_DATASET. A LEFT JOIN
			       DB2_DETAIL    B
			  ON A.RECIPIENT_ID=B.RECIPIENT_ID;
			QUIT;
		  %END;
		  %ELSE %DO;
		    %PUT NOTE: &DB2_TMP..&TABLE_PREFIX._DETAIL DOES NOT EXISTS. ;
			DATA &SAS_DATASET. ;
			 SET &SAS_DATASET. ;
			 TEMP_CPG=.;
			RUN; 
		  %END;
		%END;
		%ELSE %IF &PROGRAM_ID = 87 or &PROGRAM_ID = 106 or &PROGRAM_ID = 83 %THEN %DO; 
		  %IF %SYSFUNC(EXIST(&DB2_TMP..&TABLE_PREFIX._CPG_ELIG)) %THEN %DO;  /** QL initiatives **/
		    %PUT NOTE: &DB2_TMP..&TABLE_PREFIX._CPG_ELIG EXISTS.;
			DATA DB2_DETAIL ;
			  SET &DB2_TMP..&TABLE_PREFIX._CPG_ELIG (KEEP=PT_BENEFICIARY_ID CLT_PLAN_GROUP_ID);
			  RECIPIENT_ID=PT_BENEFICIARY_ID;
			  DROP PT_BENEFICIARY_ID;
			RUN;

			PROC SORT DATA = DB2_DETAIL NODUPKEY;
			  BY RECIPIENT_ID;
			RUN;

			PROC SQL NOPRINT;
			  CREATE TABLE &SAS_DATASET. AS
			  SELECT A.*, B.CLT_PLAN_GROUP_ID AS TEMP_CPG
			  FROM &SAS_DATASET. A LEFT JOIN
			       DB2_DETAIL    B
			  ON A.RECIPIENT_ID=B.RECIPIENT_ID;
			QUIT;
		  %END;
		  %ELSE %DO; /** RE RX initiatives **/
		    %PUT NOTE: &DB2_TMP..&TABLE_PREFIX._CPG_ELIG DOES NOT EXIST.;
			DATA &SAS_DATASET. ;
			 SET &SAS_DATASET. ;
			 TEMP_CPG=.;
			RUN; 
		  %END;
		%END;

		/** add CPG to the hercules SAS dataset **/
		DATA &SAS_DATASET. ;
		 SET &SAS_DATASET. ;
		 CLT_PLAN_GROUP_ID=TEMP_CPG*1;
		 DROP TEMP_CPG;
		RUN; 
	%END;

	PROC SQL;
	  CREATE TABLE &TEMP_CLIENT_TABLE. AS
	  SELECT DISTINCT CLIENT_ID, CLT_PLAN_GROUP_ID
	  FROM &SAS_DATASET. 
	  WHERE CLT_PLAN_GROUP_ID NOT IN (.,0);
	QUIT;

	PROC SQL NOPRINT;
	  SELECT COUNT(*) INTO : TEMP_COUNT
	  FROM &TEMP_CLIENT_TABLE.  ;
	QUIT;

	%PUT NOTE: TEMP_COUNT = &TEMP_COUNT. ;

	%IF &TEMP_COUNT. NE 0 %THEN %DO;

		PROC SQL NOPRINT;
		  CREATE TABLE ADD_CLIENT_VARIABLES AS  
		  SELECT CLT_PLAN_GROUP_ID, 
			 CLIENT_ID, 
			 PLAN_CD AS PLAN_CD2, 
			 PLAN_EXTENSION_CD AS PLAN_EXT_CD_TX2, 
			 GROUP_CD AS GROUP_CD2, 
			 GROUP_EXTENSION_CD AS GROUP_EXT_CD_TX2,
			 BLG_REPORTING_CD AS BLG_REPORTING_CD2
		  FROM CLAIMSA.TCPGRP_CLT_PLN_GR1
		  WHERE CLT_PLAN_GROUP_ID IN (
				SELECT CLT_PLAN_GROUP_ID
				FROM &TEMP_CLIENT_TABLE.)
		  AND CLIENT_ID IN (
				SELECT CLIENT_ID
				FROM &TEMP_CLIENT_TABLE.);
		QUIT;
		
		PROC SQL NOPRINT;
		  SELECT COUNT(*) INTO: TEMP_COUNT2
		  FROM ADD_CLIENT_VARIABLES
		  WHERE CLT_PLAN_GROUP_ID NOT IN (.,0);
		QUIT;

		%PUT NOTE: TEMP_COUNT2 = &TEMP_COUNT2. ;

		%IF &TEMP_COUNT2 NE 0 %THEN %DO;

			PROC SORT DATA = ADD_CLIENT_VARIABLES;
			  BY CLIENT_ID CLT_PLAN_GROUP_ID;
			RUN;

			PROC SORT DATA = &SAS_DATASET. ;
			  BY CLIENT_ID CLT_PLAN_GROUP_ID;
			RUN;

			DATA &SAS_DATASET. ;
			  MERGE &SAS_DATASET.        (IN=A)
				    ADD_CLIENT_VARIABLES (IN=B);
			  BY CLIENT_ID CLT_PLAN_GROUP_ID;
			  IF A;
			  IF A AND B THEN DO;
				 PLAN_CD = PLAN_CD2;
				 PLAN_EXT_CD_TX = PLAN_EXT_CD_TX2; 
				 GROUP_CD = GROUP_CD2;
				 GROUP_EXT_CD_TX = GROUP_EXT_CD_TX2;
				 BLG_REPORTING_CD = BLG_REPORTING_CD2;			  
			  END;
			  DROP PLAN_CD2 PLAN_EXT_CD_TX2 GROUP_CD2 GROUP_EXT_CD_TX2 BLG_REPORTING_CD2;
			RUN;
	
		%END;

		PROC SQL NOPRINT;
		  DROP TABLE &TEMP_CLIENT_TABLE.;   
		QUIT;

	%END;

	%END;
	%ELSE %DO;
	  %PUT NOTE: &SAS_DATASET. DOES NOT EXISTS. ;
	%END;

%mend add_client_variables;
