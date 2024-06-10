/**HEADER------------------------------------------------------------------------------------------------
|
| PROGRAM NAME: get_moc_csphone.SAS
|
| PURPOSE:
|       This macro adds customer service area code and phone number of the mail order
|       pharmacy for all adjudications.
|
| INPUT: 
|		FOR QL 
|             The tbl_name_in is a name of input DB2 table. It must have the column
|             CLT_PLAN_GROUP_ID that does not need to be unique. There may be other
|             columns in the table.
|
|             The tbl_name_out is a name of output DB2 table. It has the same structure
|             as an input table plus two additional columns: MOC_PHM_CD and CS_AREA_PHONE. 
|
|			  The chk_dt is a SAS date on which one wants to check eligibility.
|             If chk_dt is not specified (second example below) then the default value
|             for chk_dt is the current date.
|
|		FOR RX / RE
|
|			  MACRO PARAMETER MODULE SHOULD BE PASSED BY THE USER BASED ON THE ADJ
|             FOR RXCLM IW SHOULD BE SET TO MODULE = RX AND FOR RECAP IT SHOULD BE SET TO MODULE=RE
|
|			  The tbl_name_in is a name of input ORACLE table.
|
|			  The tbl_name_out is a name of output ORACLE table. It has the same structure
|             as an input table plus two additional columns: MOC_PHM_CD and CS_AREA_PHONE. 
|			  BOTH THESE COLUMNS WILL BE POPULATED WITH NULL VALUES
|
|
|---------------------------------------------------------------------------------------------------------
|HISTORY:  SEPTEMBER 2003 - YURY VILK 
|Revision: Hercules Version  2.1.01             
|June, 2008 - Suresh  - Changes have been made to accomodate all 3 adjudications.
|                     - For QL adjudication NO change in Logic has been made
|                     - For Rx/Re the output table created based on the input table
|                       without any constraints is altered to add columns MOC_PHM_CD 
|                       and CS_AREA_PHONE with NULL values
|                     - Added Module as a macro parameter which is passed by the user.
|                       Default value is QL, but when executing this macro in Rx/Re 
|                       the user will pass values for Module (Module=Rx)
|----------------------------------------------------------------------------------------------------------
|26JUL2012 - P. Landis - Modified to reference new hercdev2 environment
+--------------------------------------------------------------------------------------------------*HEADER*/


%MACRO GET_MOC_CSPHONE(MODULE = QL, TBL_NAME_IN=, TBL_NAME_OUT=,CHK_DT=,CLAIMSA=CLAIMSA,DEFAULT_PHONE='(800)841-5550');

/* LOOP FOR QL ADJ */
%IF %UPCASE(&MODULE.) = QL %THEN %DO;
	%GLOBAL ERR_FL SYSERR SQLRC SQLXRC SYSDBMSG DEBUG_FLAG;
	%GLOBAL HERCULES;

	%DROP_DB2_TABLE(TBL_NAME=&TBL_NAME_OUT);
	%IF &DEBUG_FLAG=Y %THEN %DO;
			OPTIONS NOTES;
			OPTIONS MLOGIC MPRINT SYMBOLGEN SOURCE2;
 	%END;
	%ELSE %DO;
  			OPTIONS NONOTES ;
  			OPTIONS NOMLOGIC NOMPRINT NOSYMBOLGEN NOSOURCE2;
	%END;

	%IF &CHK_DT= %THEN 
		%LET CHK_DT=%STR(TODAY()	);

	PROC SQL;
	SELECT ELIGIBILITY_DT, ELIGIBILITY_CD
	INTO :ELIG_DT1, :ELIG_CD
	FROM &HERCULES..TPHASE_RVR_FILE
	WHERE INITIATIVE_ID in (&initiative_id);
	QUIT;
	%PUT ELIG_CD=&ELIG_CD;
	%PUT ELIG_DT1=&ELIG_DT1;

	DATA _NULL_;
 		LENGTH DATE 8 ;
 		DATE=&CHK_DT;
 		IF DATE=. THEN DATE=TODAY();
 		CALL SYMPUT('CHK_DT_DB2',"'" || PUT(DATE, MMDDYY10.) || "'");
			%IF &ELIG_CD = 2 %THEN %DO; /*FUTURE ELIGIBILITY ONLY WOULD HAVE DATE IN THE TABLE.*/
				CALL SYMPUT('ELIG_DT',"'" || PUT("&ELIG_DT1"d, MMDDYY10.) || "'");
				%PUT ELIG_DT=&ELIG_DT;
			%END;
	RUN;
	%PUT CHK_DT_DB2=&CHK_DT_DB2;

		


	%IF &elig_cd=1 %THEN %DO;
		%LET ELIG_VAR= %STR(AND &CHK_DT_DB2 BETWEEN B.EFF_DT AND B.EXP_DT);
	%END;

	%ELSE %IF &elig_cd=2 %THEN %DO;
		%LET ELIG_VAR= %str(AND &ELIG_DT BETWEEN B.EFF_DT AND B.EXP_DT);
	%END;

	%ELSE %IF &elig_cd=3 %THEN %DO;
		%LET ELIG_VAR= %STR(AND CURRENT DATE >= B.EFF_DT);
	%END;

	PROC SQL;
 		CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
  		EXECUTE 
		(CREATE TABLE &TBL_NAME_OUT AS
    	(SELECT * FROM &TBL_NAME_IN) DEFINITION ONLY
        ) BY DB2;

		EXECUTE
		(ALTER TABLE &TBL_NAME_OUT
         ADD MOC_PHM_CD CHAR(3)
         ADD CS_AREA_PHONE CHAR(13) NOT NULL WITH DEFAULT &DEFAULT_PHONE
        ) BY DB2;
 	DISCONNECT FROM DB2;
 	QUIT;

	PROC SQL;
 		CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
  		EXECUTE 
		(INSERT INTO &TBL_NAME_OUT
		 WITH OUT_TMP AS
		(SELECT DISTINCT IN.CLT_PLAN_GROUP_ID,
                         A.MOC_PHM_CD,
                         '(' || A.TALX_PHN_SAR_NB || ')' ||
                 		 SUBSTR(A.TALX_PHN_NB, 1,3)|| '-' ||
                 		 SUBSTR(A.TALX_PHN_NB, 4) AS CS_AREA_PHONE

         FROM  &TBL_NAME_IN AS IN,
               &CLAIMSA..TCPG_PB_TRL_HIST AS B,
               &CLAIMSA..TMAIL_ORD_PB_RLS AS A

         WHERE IN.CLT_PLAN_GROUP_ID=B.CLT_PLAN_GROUP_ID
           AND B.DELIVERY_SYSTEM_CD = 2
           AND B.PB_ID = A.PB_ID
/*           AND &CHK_DT_DB2 BETWEEN B.EFF_DT AND B.EXP_DT*/
		   &ELIG_VAR.	
			)

		SELECT  IN.*,
                C.MOC_PHM_CD,
                CASE WHEN C.CS_AREA_PHONE IS NULL THEN &DEFAULT_PHONE.
                     ELSE C.CS_AREA_PHONE
                END AS CS_AREA_PHONE
        FROM &TBL_NAME_IN AS IN  
		LEFT JOIN
             OUT_TMP      AS C
        ON IN.CLT_PLAN_GROUP_ID=C.CLT_PLAN_GROUP_ID
        )BY DB2;
	   DISCONNECT FROM DB2;
	 QUIT;

  	%IF &SQLXRC=0 %THEN %DO;
		%PUT THE TABLE &TBL_NAME_OUT WAS CREATED SUCCESFULY.;
	%END;
  	%ELSE %DO;
 		%PUT &SYSDBMSG;
		%LET ERR_FL=1;
	%END;

/*	%RUNSTATS(TBL_NAME=&TBL_NAME_OUT);*/

 	%IF &DEBUG_FLAG NE Y %THEN %DO;
 		OPTIONS NOMLOGIC NOMPRINT NOSYMBOLGEN;
	%END;

  	OPTIONS NOTES DATE;

%END; /* END OF LOOP FOR QL */

/* START OF LOOP FOR RX - RE */
%IF %UPCASE(&MODULE) = RX OR %UPCASE(&MODULE) = RE %THEN %DO;

  	%DROP_ORACLE_TABLE(TBL_NAME=&TBL_NAME_OUT);

	PROC SQL;
		 CONNECT TO ORACLE (PATH=&GOLD.);
		 EXECUTE
		 (CREATE TABLE &TBL_NAME_OUT AS
		  SELECT * FROM &TBL_NAME_IN)
		 BY ORACLE;
		 DISCONNECT FROM ORACLE;
	QUIT;

	PROC SQL;
		 CONNECT TO ORACLE (PATH=&GOLD.);
		 EXECUTE
		 (
		 ALTER TABLE &TBL_NAME_OUT
		 ADD 
	   		(
	         MOC_PHM_CD CHAR(3) NULL,
	         CS_AREA_PHONE  CHAR(13) NULL
	   		)
		 )
		 BY ORACLE;
		 DISCONNECT FROM ORACLE;
	QUIT;


%END; /* END OF LOOP FOR RX - RE */

%MEND;

