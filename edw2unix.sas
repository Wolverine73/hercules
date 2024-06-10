/*HEADER---------------------------------------------------------------------------------------------------------
|MACRO: EDW2UNIX.SAS
|
|PURPOSE:
|                        BRING (QL/RX/RE) DATA INTO UNIX BOX.
|
|INPUT					 TBL_NM_IN(QL/RX/RE TABLE),ADJ_ENGINE(IF ADJ_ENGINE = 2,3 THEN DATA FROM EDW TABLES
|															  ELSE QL TABLE)
|
|LOGIC:                  BRING (QL/RX/RE) DATA INTO UNIX BOX ,FORMAT THE DATA AND CREATE OUTPUT DATA SET(TBL_NM_OUT).
|						
|						
|PARAMETERS:            GLOBAL MACRO VARIABLES: INITIATIVE_ID, PHASE_SEQ_NB.
|						ADJ_ENGINE.
|
|OUTPUT			 		PERMANENT DATA SET (TBL_NM_OUT) IS CREATED .
|+-----------------------------------------------------------------------------------------------------------------
| HISTORY: 
|FIRST RELEASE: 		10MAY2008 - K.MITTAPALLI   - Hercules Version  2.1.01
|                       19NOV2008 - S.Y. - Hercules Version  2.1.2.01
|                       18FEB2010 - N. WILLIAMS - Hercules Version  2.1.2.02
|                                   Add logic to lookup cdh_beneficiary_id when value from edw contains alphanumeric
|                                   data instead of numeric data.
|                       JUNE 2012 - E BUKOWSKI(SLIOUNKOVA) -  TARGET BY DRUG/DSA AUTOMATION
|                                   FIXED LOGIC FOR CDH_BENEFICIARY_ID TO BE CARRIED TO THE OUTPUT FILE
|                                   REMOVED LOGIC FOR PRESCRIBER_ID VERIFICATION FOR PROGRAMS 105 AND 106
+-----------------------------------------------------------------------------------------------------------HEADER*/
%MACRO EDW2UNIX(TBL_NM_IN=,
			    TBL_NM_OUT=,
				ADJ_ENGINE=);
LIBNAME DATA "/&DATA_DIR";

*SASDOC----------------------------------------------------------------------------------------------------------
|   IF ADJ_ENGINE = 2,3(RX/RE) THEN CREATE DATA SET ON UNIX BOX LOCATED AT /DATA/SASTEST(PROD)1/HERCULES2.1/.
|	VALIDATE CARD HOLDER BENEFICIARY_ID ,IF ANY CHARACTER EXISTS ON DATA, TRUNCATE THOSE RECORDS.
|	FORMAT DATA FOR THE FOLLOWING FIELDS :
|	BIRTH_DT
|   PT_BENEFICIARY_ID
|	LAST_FILL_DT 
|	CLIENT_ID
|   CDH_BENEFICIARY_ID
|	CLT_PLAN_GROUP_ID
|   DRUG_NDC_ID FOR ALL THE PROGRAMS EXCEPT GENERIC_LAUNCH.
|	FORMAT DATA FOR THE FOLLOWING FIELDS :
|	BIRTH_DT
|	PT_BENEFICIARY_ID
|	CLIENT_ID
|	CLT_PLAN_GROUP_ID FOR GENERIC_LAUNCH.
|	FORMAT DATA FOR THE FOLLOWING FIELDS :
|	VALIDATE PRESCRIBER ID ,IF ANY CHARACTER EXISTS ON DATA, TRUNCATE THOSE RECORDS.
|   FORMAT DATA FOR THE FOLLOWING FIELDS :
|	PRESCRIBER_ID FOR PROGRAM ID 105 AS WELL AS 106.
|
|	10MAY2008 - K.MITTAPALLI   - HERCULES VERSION  2.1.0.1
+-----------------------------------------------------------------------------------------------------------SASDOC*;

%IF (&ADJ_ENGINE EQ 2 OR &ADJ_ENGINE EQ 3) %THEN %DO;
								PROC SQL;
								  CONNECT TO ORACLE(PATH=&GOLD);
								  CREATE TABLE &TBL_NM_OUT. AS
								  SELECT * FROM CONNECTION TO ORACLE
								    (
								    SELECT *
								    FROM &TBL_NM_IN);
								  DISCONNECT FROM ORACLE;
								QUIT;

  	%IF &PROGRAM_ID NE 83 %THEN %DO;

		DATA &TBL_NM_OUT.
		     PT_CDH_LKUP (DROP=CDH_BENEFICIARY_ID)
        ;
		 SET &TBL_NM_OUT.;		 
		 	IF  VERIFY(CDH_BENEFICIARY_ID,' 0123456789. ') EQ 0 THEN OUTPUT &TBL_NM_OUT. ;
			IF  VERIFY(CDH_BENEFICIARY_ID,' 0123456789. ') NE 0 THEN OUTPUT PT_CDH_LKUP  ;
		RUN;

		/* Get Count of Observations in passed-in SAS dataset */
       %NOBS(PT_CDH_LKUP) ;

       /* Informational message  in saslog  */
       %PUT NOTE: Number of Observations for PT_CDH_LKUP our &NOBS . ;

       /*check count of obs before executing, on for big datasets splits*/       
      %IF &NOBS GT 0 %THEN %DO;
       /*n. williams - logic to lookup cdh_beneficiary_id when edw data contains alphanumeric data value*/       
		%DROP_DB2_TABLE(TBL_NAME=&DB2_TMP..&TABLE_PREFIX.PT_CDH_LOOKUP);

        PROC SQL ;
	    CREATE TABLE &DB2_TMP..&TABLE_PREFIX.PT_CDH_LOOKUP (BULKLOAD=YES) AS
	    SELECT *
	    FROM PT_CDH_LKUP;
	    QUIT;

        %DROP_DB2_TABLE(TBL_NAME=&DB2_TMP..&TABLE_PREFIX.PT_CDH_LKUP_FINAL);

        PROC SQL;
	    CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	    CREATE TABLE &DB2_TMP..&TABLE_PREFIX.PT_CDH_LKUP_FINAL AS
        SELECT * FROM CONNECTION TO DB2
	    (
		  SELECT A.*,                
		    	 CHAR(B.CDH_BENEFICIARY_ID) AS CDH_BENEFICIARY_ID
			   
		  FROM   &DB2_TMP..&TABLE_PREFIX.PT_CDH_LOOKUP A
		  LEFT JOIN
		         &CLAIMSA..TBENEF_XREF_DN B			   
		  ON  A.PT_BENEFICIARY_ID  = B.BENEFICIARY_ID
        ) ;
        DISCONNECT FROM DB2;
        QUIT;

	    PROC SQL;
		CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
		CREATE TABLE PT_CDH_LKUP_FINAL2 AS
		SELECT * FROM CONNECTION TO DB2
		(
		   SELECT *
		   FROM &DB2_TMP..&TABLE_PREFIX.PT_CDH_LKUP_FINAL
        );
		DISCONNECT FROM DB2;
		QUIT;

	   PROC APPEND
	   BASE=&TBL_NM_OUT.
	   DATA=PT_CDH_LKUP_FINAL2
	   FORCE
	   ;
	   RUN;

    %END;



 			  	%IF (&PROGRAM_ID EQ 105 OR &PROGRAM_ID EQ 106) %THEN %DO;
*SASDOC--------------------------------------------------------------------------
|JUNE 2012 - TARGET BY DRUG/ DSA AUTOMATION
|EB - THE BELOW LOGIC IS COMMENTED OUT PER BUSINESS REQUIREMENTS 
+------------------------------------------------------------------------SASDOC*;
/*											DATA &TBL_NM_OUT.;*/
/*						 						SET &TBL_NM_OUT.;*/
/*						 							IF  VERIFY(PRESCRIBER_ID,' 0123456789. ') EQ 0 THEN OUTPUT;*/
/*						 					RUN;*/
														DATA &TBL_NM_OUT.;
							 			 				 SET &TBL_NM_OUT.;
														IF PRESCRIBER_ID NOT IN(' ','.') THEN 
							 								PRESCRIBER_ID2 = INPUT(PRESCRIBER_ID,12.);
														ELSE
							 								PRESCRIBER_ID2 = 000000;
															DROP PRESCRIBER_ID;
															NTW_PRESCRIBER_ID = PRESCRIBER_ID2;
															RENAME PRESCRIBER_ID2 = PRESCRIBER_ID; 
															FORMAT PRESCRIBER_ID 8.;
										 				RUN;
				%END;

DATA &TBL_NM_OUT.;
		 SET &TBL_NM_OUT.;
			IF BIRTH_DT NOT IN(' ','.') AND LENGTH(BIRTH_DT) EQ 10 THEN 
			   BIRTH_DT2 =INPUT(BIRTH_DT,YYMMDD10.);
			   FORMAT BIRTH_DT2 DATE9.;
			ELSE
			   BIRTH_DT2 = .;

			IF LAST_FILL_DT NOT IN(' ','.') AND LENGTH(LAST_FILL_DT) EQ 10 THEN 
			   LAST_FILL_DT2 =INPUT(LAST_FILL_DT,YYMMDD10.);
			   FORMAT LAST_FILL_DT2 DATE9.;
			ELSE
			   LAST_FILL_DT2 = .;

			   PT_BENEFICIARY_ID2 = INPUT(PT_BENEFICIARY_ID,12.);

			IF CDH_BENEFICIARY_ID NOT IN(' ','.') THEN 
		 	   CDH_BENEFICIARY_ID2 = INPUT(CDH_BENEFICIARY_ID,12.);
			ELSE
			   CDH_BENEFICIARY_ID2 = 000000;

			IF CLT_PLAN_GROUP_ID NOT IN(' ','.') THEN 
		       CLT_PLAN_GROUP_ID2 = INPUT(CLT_PLAN_GROUP_ID,8.);
			ELSE
		 	   CLT_PLAN_GROUP_ID2 = .; 

			IF DRUG_NDC_ID NOT IN(' ','.') THEN 
			   DRUG_NDC_ID2 = INPUT(DRUG_NDC_ID,20.);
			ELSE
			   DRUG_NDC_ID2 = .; 

		 	   CLIENT_ID2 = INPUT(CLIENT_ID,20.);

		DROP BIRTH_DT LAST_FILL_DT PT_BENEFICIARY_ID CLIENT_ID CDH_BENEFICIARY_ID CLT_PLAN_GROUP_ID DRUG_NDC_ID;
		RENAME 	BIRTH_DT2 				= 	BIRTH_DT 
				PT_BENEFICIARY_ID2 		= 	PT_BENEFICIARY_ID
				LAST_FILL_DT2 			= 	LAST_FILL_DT 
				CLIENT_ID2 				= 	CLIENT_ID 
				CDH_BENEFICIARY_ID2 	= 	CDH_BENEFICIARY_ID
				CLT_PLAN_GROUP_ID2		=	CLT_PLAN_GROUP_ID 
				DRUG_NDC_ID2			=	DRUG_NDC_ID;
		FORMAT PT_BENEFICIARY_ID 8. CDH_BENEFICIARY_ID 8. CLIENT_ID 4. CLT_PLAN_GROUP_ID 4.;
RUN;

	%END;  /* END DO LOOP FOR PROGRAM ID NE 83 */

		%IF &PROGRAM_ID EQ 83 %THEN %DO;

DATA &TBL_NM_OUT.;
 SET &TBL_NM_OUT.;
/*	AK ADDED CODE FOR LAST_FILL_DT PROCESSING - JAN2013*/

								IF BIRTH_DT NOT IN(' ','.') AND LENGTH(BIRTH_DT) EQ 10 THEN 
									BIRTH_DT2 =INPUT(BIRTH_DT,YYMMDD10.);
									FORMAT BIRTH_DT2 DATE9.;
								ELSE
									BIRTH_DT2 = .;

								IF LAST_FILL_DT NOT IN(' ','.') AND LENGTH(LAST_FILL_DT) EQ 10 THEN 
									LAST_FILL_DT2 =INPUT(LAST_FILL_DT,YYMMDD10.);
			   						FORMAT LAST_FILL_DT2 DATE9.;
									ELSE
							   LAST_FILL_DT2 = .;


								IF CLT_PLAN_GROUP_ID NOT IN(' ','.') THEN 
						 		   CLT_PLAN_GROUP_ID2 = INPUT(CLT_PLAN_GROUP_ID,8.);
								ELSE
						 		   CLT_PLAN_GROUP_ID2 = .;

						 		   PT_BENEFICIARY_ID2 = INPUT(PT_BENEFICIARY_ID,12.);
						 		   CLIENT_ID2 = INPUT(CLIENT_ID,20.);

								   DROP BIRTH_DT PT_BENEFICIARY_ID CLIENT_ID CLT_PLAN_GROUP_ID LAST_FILL_DT;

								   RENAME BIRTH_DT2 			= 	BIRTH_DT 
										  PT_BENEFICIARY_ID2 	= 	PT_BENEFICIARY_ID 
										  CLIENT_ID2 			= 	CLIENT_ID 
										  CLT_PLAN_GROUP_ID2	=	CLT_PLAN_GROUP_ID
										  LAST_FILL_DT2 		= 	LAST_FILL_DT ;

									FORMAT PT_BENEFICIARY_ID 8. CLIENT_ID 4. CLT_PLAN_GROUP_ID 4.;
RUN;

		%END; /* END DO LOOP FOR PROGRAM ID EQ 83 */

%END;	/* END ADJ_ENGIN 2 AND 3 */

		%ELSE %IF &ADJ_ENGINE EQ 1 %THEN %DO;

		*SASDOC----------------------------------------------------------------------------------------------------------
		|   IF ADJ_ENGINE = 1(QL) THEN CREATE DATA SET ON UNIX BOX LOCATED AT /DATA/SASTEST(PROD)1/HERCULES2.1/.
		|	FORMAT DATA FOR THE FOLLOWING FIELDS :
		|	CLIENT_LEVEL_1
		|
		|	10MAY2008 - K.MITTAPALLI   - HERCULES VERSION  2.1.0.1
		+-----------------------------------------------------------------------------------------------------------SASDOC*;

						PROC SQL;
						  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
						  CREATE TABLE &TBL_NM_OUT. AS
						  SELECT * FROM CONNECTION TO DB2
						    (
						    SELECT *
						    FROM &TBL_NM_IN);
						  DISCONNECT FROM DB2;
						QUIT;

						DATA &TBL_NM_OUT.;
						 SET &TBL_NM_OUT.;
						 CLIENT_LEVEL_11 = LEFT(PUT(CLIENT_LEVEL_1,20.)) ; 
						 DROP CLIENT_LEVEL_1; 
						 RENAME CLIENT_LEVEL_11=CLIENT_LEVEL_1; 
						 RUN;

		%END;
		%MEND EDW2UNIX;
