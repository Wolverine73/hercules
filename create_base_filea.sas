/*HEADER------------------------------------------------------------------------
MACRO: create_base_file

PURPOSE:
                        Create SAS datasets (one for each receiver) in both the pending and
                        results directories beneath the appropriate HERCULES Program.

LOGIC:                          The macro first finds how many receivers are defined
                        for the initiative and then generate datasets in the pending
                        and results directories for each of the receivers. The data for
                        the output datasets comes from the input table and beneficiary
                        and/or prescriber demographics tables. The type of the demographics
                        table/tables is determined by CMCTN_ROLE_CD and look up
                        dataset AUX_TAB.CMCTN_ROLE_RVR_TABLE. Using DB2 tables:
                        HERCULES.TFILE_BASE_FIELD, HERCULES.TFIELD_DESCRIPTION
                        and HERCULES.TFILE_FIELD the macro finds names of the fields that
                        are required for the output dataset. To find the corresponding
                        names of input fields the mapping dataset AUX_TAB.CMCTN_ROLE_RVR_FIELD
                        is used. The dataset also contains expressions for new fields:
                        PROGRAM_ID, APN_CMCTTN_ID,MINOR_IN. Using this information
                        the SQL string for the join between &tbl_name_in and the demographics
                        table/tables is build dynamically and then executed. Before join
                        is performed the lists of required and available fields are compared
                        and the error message is generated if some of the required fields
                        are missing.
PARAMETERS:                     Global macro variables: Program_ID, Task_ID,Initiative_ID, Phase_Seq_Nb.
                        The name of input DB2 table &tbl_name_in. The table must contain
                        one or more fields based on receiver(s) of the file.
                                CMCTN_ROLE_CD                   FIELD REQUIRED
                                1 (Participant)                 PT_BENEFICIARY_ID
                                2 (Prescriber)                  PRESCRIBER_ID
                                5 (Cardholder)                  CDH_BENEFICIARY_ID
                        The table must also have all fields (except demographics) defined
                        in the layout(s) tables TFILE_BASE_FIELD and TFILE_FIELD.

FIRST RELEASE: Yury Vilk, OCTOBER 2003

      CHANGES: Greg Comerford - May 05 2005 - Added include statement for add_rocc_cd macro.
               Greg Comerford - May 10 2005 - Removed Drop of table WORK.TFILE_FIELDS.
SECOND RELEASE: Kuladeep M, DEC 2006

      CHANGES: Kuladeep M - Dec 2006 - Added include statement for Additional_fields macro.





USAGE EXAMPLE: %create_base_file(tbl_name_in=QCPI514.CLAIMS);

|	    Mar  2007    - Greg Dudley Hercules Version  1.0  
| Hercules Version  2.1.01
| June, 2008 Suresh - Hercules Version  2.1.2.01
ADDED LOGIC SO THAT THIS MACRO CAN ACCEPT ALIAS ALSO IN ADDITION TO
|                     TABLE AS INPUT
+-----------------------------------------------------------------------HEADER*/
%MACRO CREATE_BASE_FILEA(TBL_NAME_IN = ,
                        TBL_NAME_IN_LIST = );

%LOCAL  N_FILES TBL_NAME_IN_LIST;
%let DEBUG_FLAG=Y;

/** DEMOGRAPHICS TABLE TO REFERENCE ADDRESS INFO IS OBTAINED FROM AUX_TAB.CMCTN_ROLE_RVR_TABLE
BASED ON CMCTN_ROLE_CD. FOR CMCTN_ROLE_CD 1 & 5, THIS TABLE REFERENCES CLAIMSA.TBENEF_BENEFICIAR1,
BUT INSTEAD OF THIS TABLE CLAIMSA.VBENEF_BENEFICIARY IS TO BE USED **/

%LET BRENEF_TBL_NAME=CLAIMSA.VBENEF_BENEFICIARY;
%LET BRENEF_TBL_NAME2=&DB2_TMP..CLAIMS_PULL_&INITIATIVE_ID.; /** SR: ADDED TO BRING IN ADDRESS FOR MISSING BENEFICIARYs IN EDW **/
%LET T_DEMOGRAPHICS2=&DB2_TMP..CLAIMS_PULL_&INITIATIVE_ID.;
%PUT BRENEF_TBL_NAME=&BRENEF_TBL_NAME;
%PUT BRENEF_TBL_NAME2=&BRENEF_TBL_NAME2;

%IF &DEBUG_FLAG=Y %THEN %DO;
     OPTIONS NOTES;
     OPTIONS MLOGIC MPRINT SYMBOLGEN SOURCE2;
%END;
%ELSE %DO;
  OPTIONS NONOTES ;
  OPTIONS NOMLOGIC NOMPRINT NOSYMBOLGEN NOSOURCE2;
%END;

%MVAREXIST(CLAIMSA);

%IF ^&MVAREXIST %THEN 
	%LET CLAIMSA=CLAIMSA;

OPTIONS COMPRESS=NO;

%LET N_FILES=0;
%IF %LENGTH(&TBL_NAME_IN_LIST)=0 %THEN 
	%LET TBL_NAME_IN_LIST=&TBL_NAME_IN;

/* GET CMCTN_ROLE_CD AND FILE_ID */
DATA WORK.TPHASE_RVR_FILE;
	SET &HERCULES..TPHASE_RVR_FILE(WHERE=( INITIATIVE_ID=&INITIATIVE_ID
	                                    AND PHASE_SEQ_NB=&PHASE_SEQ_NB))
	                                    END=LAST;
	IF LAST THEN CALL SYMPUT('N_FILES',TRIM(LEFT(PUT(_N_,2.))));
	KEEP CMCTN_ROLE_CD FILE_ID;
RUN;

/* INITIALIZE CMCTN_ROLE_CD AND FILE_ID MACRO VARIABLES BASED ON NUMBER OF FILES  */
%DO  I=1 %TO &N_FILES;
	%LOCAL CMCTN_ROLE_CD&I ;
	%LOCAL FILE_ID&I;
	%PUT CMCTN_ROLE_CD&I ;
	%PUT FILE_ID&I;
%END;

%PUT NOTE=GENERATING LIST OF CMCTN_ROLE_CDS ;
%PUT  N_FILES=&N_FILES;

%IF &N_FILES=0 %THEN 
	%PUT ERROR=NO FILES TO PROCESS FOR INITIATIVE_ID=&INITIATIVE_ID ;

/** OBTAIN THE LIST OF CMCTN_ROLE_CD AND FILE_ID **/
DATA _NULL_;
	SET WORK.TPHASE_RVR_FILE;
	CALL SYMPUT('CMCTN_ROLE_CD' || TRIM(LEFT(_N_)), TRIM(LEFT(CMCTN_ROLE_CD)));
	CALL SYMPUT('FILE_ID' || TRIM(LEFT(_N_)), TRIM(LEFT(FILE_ID)));
RUN;
%SET_ERROR_FL;

%MACRO CREATE_BASE_FILE0( TBL_NAME_IN=,
							CMCTN_ROLE_CD=,
							FILE_ID=,
							FILE_SEQ_NB=1);


		%LOCAL 	POS 
				SCHEMA 
				TBL_NAME_IN_SH 
				TBL_NAME_OUT_SH
				T_DEMOGRAPHICS 
				FIELDS_REQ_BUT_NOT_IN_INPUT
				FIELDS_IN_INPUT_BUT_NOT_REQ 
				FIELDS_IN_INPUT_BUT_NOT_REQ_CSV
				STR_SELECT 
				STR_FROM 
				STR_WHERE 
				STR_FROM2 
				STR_WHERE2;
/* FIND WHICH DEMOGRPHICS TABLE SHOULD BE USED (BENEFICIARY OR PRESCRIBER) */

%PUT BEGINNING PROCESSING FOR:
								TBL_NAME_IN=&TBL_NAME_IN.
								CMCTN_ROLE_CD=&CMCTN_ROLE_CD.
								FILE_ID=&FILE_ID.
								FILE_SEQ_NB=&FILE_SEQ_NB.;

%LET POS=%INDEX(&TBL_NAME_IN,.);
%LET SCHEMA=%SUBSTR(&TBL_NAME_IN,1,%EVAL(&POS-1));
%LET TBL_NAME_IN_SH=%SUBSTR(&TBL_NAME_IN,%EVAL(&POS+1));
%LET TBL_NAME_OUT_SH_MAIN=T_&INITIATIVE_ID._&PHASE_SEQ_NB._&CMCTN_ROLE_CD;

%IF  &FILE_SEQ_NB=1 %THEN 
	%LET TBL_NAME_OUT_SH=&TBL_NAME_OUT_SH_MAIN.;
%ELSE 
	%LET TBL_NAME_OUT_SH=&&TBL_NAME_OUT_SH_MAIN._&FILE_SEQ_NB.;

PROC SQL NOPRINT;
	SELECT COMPRESS(PUT(LTR_RULE_SEQ_NB,3.)) 
	INTO  : LTR_RULE_SEQ_NB_LIST SEPARATED BY ','
	FROM    &HERCULES..TPGM_TASK_LTR_RULE
	WHERE PROGRAM_ID=&PROGRAM_ID.
	AND TASK_ID=&TASK_ID.
	AND CMCTN_ROLE_CD=&CMCTN_ROLE_CD.
	AND PHASE_SEQ_NB=&PHASE_SEQ_NB.
	;
QUIT;
%PUT LTR_RULE_SEQ_NB_LIST=&LTR_RULE_SEQ_NB_LIST.;

/** CLAIMSA TABLE TO ACCESS BASED ON CMCTN_ROLE_CD FROM AUX_TAB.CMCTN_ROLE_RVR_TABLE **/
DATA _NULL_ ;
	SET AUX_TAB.CMCTN_ROLE_RVR_TABLE;
	WHERE CMCTN_ROLE_CD=&CMCTN_ROLE_CD;
	CALL SYMPUT("T_DEMOGRAPHICS","&CLAIMSA.." || TRIM(TBL_NAME));
RUN;
%PUT BRENEF_TBL_NAME=&BRENEF_TBL_NAME;

%IF &T_DEMOGRAPHICS.=CLAIMSA.TBENEF_BENEFICIAR1 %THEN 
	%LET T_DEMOGRAPHICS =&BRENEF_TBL_NAME.;
%PUT T_DEMOGRAPHICS=&T_DEMOGRAPHICS;

/** SR -  10OCT2008 ADDED LOGIC TO ALTER THE INPUT TABLE TO ADD BASE COLUMNS
                    ADJ_ENGINE, CLIENT_LEVEL_1, CLIENT_LEVEL_2, CLIENT_LEVEL_3
                    TO THE INPUT DATASET IF IT DOES NOT CONTAIN THESE COLUMNS 
    NOTE: AN ALIAS TABLE COULD HAVE ALSO BEEN CREATED FROM ANOTHER ALIAS
          SO A RECURSIVE LOOP WILL BE GENERATED TO FIND THE BASE TABLE
          FROM WHICH THE ALIAS TABLE IS CREATED **/
 %CHK_TBL_TYPE:;
 PROC SQL NOPRINT;
  SELECT  TYPE INTO :TYPE
   FROM &Schema..TABLES(SCHEMA=SYSCAT)
    WHERE TABSCHEMA IN ("&Schema.")
	 AND TABNAME   IN ("&Tbl_name_in_sh.")
	 ;
 QUIT;

 %IF &TYPE = A %THEN %DO;
 	PROC SQL NOPRINT;
  		SELECT  BASE_TABSCHEMA, BASE_TABNAME
        INTO 	:Schema, :Tbl_name_in_sh
   		FROM &Schema..TABLES(SCHEMA=SYSCAT)
    	WHERE TABSCHEMA IN ("&Schema.")
	 	  AND TABNAME   IN ("&Tbl_name_in_sh.")
	 	;
 	QUIT;
 %END;
 %ELSE %GOTO EXIT_CHK_TBL_TYPE;

 %GOTO CHK_TBL_TYPE;

 %EXIT_CHK_TBL_TYPE:;

 %symdel BASE_COL;

 DATA BASE_COL_CHECK;
  FORMAT BASE_COL $14.;
  BASE_COL = 'ADJ_ENGINE'; OUTPUT;
  BASE_COL = 'CLIENT_LEVEL_1'; OUTPUT;
  BASE_COL = 'CLIENT_LEVEL_2'; OUTPUT; 
  BASE_COL = 'CLIENT_LEVEL_3'; OUTPUT;
  RUN;
  
 %let BASE_COL = ;
 
 PROC SQL;
  SELECT CASE WHEN A.BASE_COL = 'ADJ_ENGINE' 
              THEN ' ADD COLUMN ' || TRIM(LEFT(A.BASE_COL)) || ' CHAR(2) '
			  ELSE ' ADD COLUMN ' || TRIM(LEFT(A.BASE_COL)) || ' CHAR(22) '
		 END
 INTO: BASE_COL SEPARATED BY ' '
  FROM BASE_COL_CHECK A
  LEFT JOIN
  (SELECT COLNAME as BASE_COL
  FROM &HERCULES..COLUMNS(SCHEMA=SYSCAT)
   WHERE TABSCHEMA="&SCHEMA."
     AND  TABNAME="&TBL_NAME_IN_SH."
     AND   trim(left(COLNAME)) IN (	'ADJ_ENGINE', 
						'CLIENT_LEVEL_1',
						'CLIENT_LEVEL_2',
						'CLIENT_LEVEL_3'	)) B
  ON trim(left(A.BASE_COL)) = trim(left(B.BASE_COL))
  WHERE b.BASE_COL IS NULL;
 QUIT;

/* %IF %symexist(BASE_COL) %THEN %DO;*/
 %IF %bquote(&BASE_COL) NE %THEN %DO;


			PROC SQL NOPRINT;
        		CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
				EXECUTE
   				(
				   ALTER TABLE &SCHEMA..&TBL_NAME_IN_SH.
                   &BASE_COL.
				)BY DB2;
				DISCONNECT FROM DB2;
			QUIT;

 %END;
/** SR - 10OCT2008 - END OF CHANGES FOR ADDITION OF BASE COLUMNS IN INPUT TABLES **/

/** SR - 26JUN2008 ADDED LOGIC SO THAT THIS MACRO CAN ACCEPT TABLE ALIAS
                   ALSO IN ADDITION TO TABLE AS INPUT **/
 PROC SQL;
 CREATE TABLE WORK.FIELDS_THAT_ARE_IN_INTABLE AS
 SELECT COLNAME
  FROM &HERCULES..COLUMNS(SCHEMA=SYSCAT)
   WHERE TABSCHEMA="&Schema."
         AND  TABNAME="&Tbl_name_in_sh."
        ;
 RUN; 
/** SR - 26JUN2008 - END OF CHANGES FOR TABLE ALIAS **/


%LET RESET_CLIENT_ID_FL=0;
%LET PT_COUNT_QY_ON_INPUT_TBL_IN=0;

DATA _NULL_;
 LENGTH TASK_ID 8;
 SET WORK.FIELDS_THAT_ARE_IN_INTABLE;
 TASK_ID=&TASK_ID.;
 IF UPCASE(TRIM(COLNAME))='CLIENT_ID' AND TASK_ID=27 THEN CALL SYMPUT('RESET_CLIENT_ID_FL',1);
 IF UPCASE(TRIM(COLNAME))='PT_COUNT_QY' THEN CALL SYMPUT('PT_COUNT_QY_ON_INPUT_TBL_IN',1);
RUN;

/* CREATE TABLE THAT PROVIDES MAPPING BETWEEN BASE FIELDS ON THE INPUT
   AND OUTPUT TABLES */
%PUT NOTE=CREATING TEMP. MAPPING TABLES FOR BASE FIELDS;
PROC SQL;
	CREATE TABLE WORK.BASE_FIELDS_MAPPING AS
	SELECT TD.FIELD_NM, B.FIELD_NM_I
	FROM  (	&HERCULES..TFILE_BASE_FIELD AS A 
			INNER JOIN
			&HERCULES..TFIELD_DESCRIPTION AS TD
			ON A.FIELD_ID=TD.FIELD_ID
		   )                          
	LEFT JOIN
		   AUX_TAB.CMCTN_ROLE_RVR_FIELD  AS B
	ON  	TD.FIELD_NM=B.FIELD_NM
		AND B.CMCTN_ROLE_CD=&CMCTN_ROLE_CD
	WHERE (&FILE_SEQ_NB.=1)
	ORDER BY  SEQ_NB;
QUIT;
%SET_ERROR_FL;

/* CREATE TABLE THAT PROVIDES MAPPING BETWEEN NON-BASE FIELDS ON THE INPUT
    AND OUTPUT TABLES */
%PUT NOTE=CREATING TEMP. MAPPING TABLES FOR NON BASE FIELDS;
PROC SQL;
	CREATE TABLE WORK.TFILE_FIELDS AS
	SELECT TD.FIELD_NM, B.FIELD_NM_I,SUBJECT_FLAG
	FROM  (	&HERCULES..TFILE_FIELD AS A  
			INNER JOIN
			&HERCULES..TFIELD_DESCRIPTION AS TD
			ON A.FILE_ID=&FILE_ID
			AND A.FILE_SEQ_NB=&FILE_SEQ_NB
			AND A.FIELD_ID=TD.FIELD_ID
		  ) 
	LEFT JOIN
		AUX_TAB.CMCTN_ROLE_RVR_FIELD   AS B
	ON 		TD.FIELD_NM=B.FIELD_NM
		AND B.CMCTN_ROLE_CD=&CMCTN_ROLE_CD
	WHERE (	&FILE_ID.=1 AND 
			&PT_COUNT_QY_ON_INPUT_TBL_IN. = 0
			AND TD.FIELD_NM  IN ('PT_COUNT_QY') ) = 0
	ORDER BY  SEQ_NB
	;
QUIT;
%SET_ERROR_FL;

/* COCATENATE MAPPING TABLES WITH BASE AND NON-BASE FIELDS.
BUILED MACRO VARIABLES FOR THE SQL STRING. */
%PUT NOTE=BUILDING MACRO VARIABLES FOR THE SQL STRING.;
DATA WORK.ALL_FIELDS;
	SET WORK.BASE_FIELDS_MAPPING(IN=INBASE)
		WORK.TFILE_FIELDS(IN=INTFILE_FIELDS) END=LAST;
	LENGTH STR_FIELD $ 500 STR_SELECT $ 5000 STR_SELECT2 $ 5000 
		   STR_SELECT3 $ 5000 STR_FROM $ 200 STR_FROM2 $ 200 
		   STR_WHERE $ 500 STR_WHERE2 $ 500 TBL_QUALIFIER $ 4 
           STR_TMP $ 500 COMMA $ 1 ;
	RETAIN STR_SELECT '' STR_SELECT2 '' STR_SELECT3 '' 
		   STR_WHERE '' STR_FROM '' STR_WHERE2 '' STR_FROM2 ''
		   IS_RECIPIENT_BENEFICIARY_IN 0 ;
	KEEP FIELD_NM FIELD_NM_I IN_TFILE_BASE_FIELDS IN_TFILE_FIELDS;
	IN_TFILE_BASE_FIELDS=INBASE;
	IN_TFILE_FIELDS=INTFILE_FIELDS;
	
	IF LAST THEN COMMA=' ';
			ELSE COMMA=',';

    /* START BUILDING SELECT, FROM AND WHERE STRINGS FOR A JOIN BETWEEN INPUT TABLE
       AND RECEIVER'S DEMOGRAPHICS TABLE. 'IN' IS THE TABLE QUALIFIER (ALIAS) FOR
       INPUT TABLE AND 'TD' IS THE ONE FOR THE RECEIPIENT'S DEMOGRAPHICS TABLE.
      */

	IF FIELD_NM='RECIPIENT_ID' THEN DO;
		STR_TMP=TRIM(SUBSTR(FIELD_NM_I,INDEX(FIELD_NM_I,'_')+1)) ;
		STR_FROM="FROM &TBL_NAME_IN  AS IN";
		STR_FROM2="FROM &TBL_NAME_IN  AS IN";

		IF &FILE_SEQ_NB.=1   THEN DO;
			STR_FROM=TRIM(STR_FROM) || ", &T_DEMOGRAPHICS  AS TD";
			STR_FROM2=TRIM(STR_FROM2) || ", &T_DEMOGRAPHICS2  AS TD";
			STR_WHERE='WHERE IN.' || TRIM(FIELD_NM_I) || '=' || 'TD.' || TRIM(STR_TMP);
			STR_SELECT2 = TRIM(FIELD_NM);
			STR_SELECT3 = TRIM(FIELD_NM_I);
		END;
        /* Check if RECIPIENT_ID is a participant */
		IF TRIM(FIELD_NM_I)='PT_BENEFICIARY_ID' THEN 
			IS_RECIPIENT_BENEFICIARY_IN=1;
	END;

    /*  IF THE FIELD SUBJECT_ID IS REQIERED AND IT IS NOT THE SAME AS RECIPIENT_ID
        THEN WE NEED TO BRING DEMOGRAPHICS TABLE FOR A SUBJECT. THE SUBJECT
        CAN BE ONLY BENEFICIARY. THUS WE ONLY NEED TO BRING TBENEF_BENEFICIAR1 TABLE
        AND WE ONLY NEED IT IF RECIPIENT_ID IS NOT A BENEFICIARY.
        THE TABLE TBENEF_BENEFICIAR1 IS ALIASED AS 'TB'.
    */
	ELSE IF FIELD_NM='SUBJECT_ID' AND IS_RECIPIENT_BENEFICIARY_IN=0 AND &FILE_SEQ_NB.=1 THEN DO;
		STR_FROM=TRIM(STR_FROM) || ",&BRENEF_TBL_NAME. AS TB" ;
		STR_FROM2=TRIM(STR_FROM2) || ",&BRENEF_TBL_NAME2. AS TB" ;
		STR_TMP=TRIM(SUBSTR(FIELD_NM_I,INDEX(FIELD_NM_I,'_')+1)) ;
		STR_WHERE=TRIM(STR_WHERE) || ' AND IN.'    || TRIM(FIELD_NM_I)
		              || '=' || 'TB.' || TRIM(STR_TMP);
	END;
	IF FIELD_NM='LTR_RULE_SEQ_NB' THEN 
		STR_WHERE=TRIM(STR_WHERE) || " AND LTR_RULE_SEQ_NB IN (&LTR_RULE_SEQ_NB_LIST.)";

    /* THIS FIELDS DO NOT NEED TABLE QUALIFIER IN THE JOIN */
	IF FIELD_NM IN ('PROGRAM_ID','APN_CMCTN_ID','MINOR_IN','CDH_EXTERNAL_ID','DEA_NB','PT_COUNT_QY')
		THEN  TBL_QUALIFIER='';

	/* IF THE SUBJECT'S FIELDS ARE REQUIERED THEN THEY WILL BE PULLED FROM
	A DEMOGRAFICS TABLE FOR THE SUBJECT. IF SUBJECT IS RECIPIENT
	THEN THIS TABLE IS RECIPIENT'S DEMOGRAFICS TABLE TD. OTHERWISE,
	IT IS THE BENEFICIARY TABLE. THE CODE BELOW SETS THE TABLE QUALIFIER
	FOR THE SUBJECT'S FIELD.
	*/

	ELSE IF SUBJECT_FLAG=1 AND &FILE_SEQ_NB.=1 THEN DO;
		IF IS_RECIPIENT_BENEFICIARY_IN=1 THEN TBL_QUALIFIER='TD.';
		ELSE TBL_QUALIFIER='TB.';
	END;

	/* THE RECIPIENT'S DEMOGRAPHICS FIELDS ARE LISTED IN THE BASE TABLE
	AND WILL BE PULLED FROM THE 'TD' TABLE. ALL OTHER FIELDS ARE LISTED IN
	THE TFILE_FIELDS TABLE AND WILL BE PULLED FROM THE INPUT TABLE.
	FROM THE INPUT TABLE.
	*/

	ELSE IF (INBASE AND  FIELD_NM NOT IN ('RECIPIENT_ID','LTR_RULE_SEQ_NB', 'ADJ_ENGINE', 'CLIENT_LEVEL_1', 'CLIENT_LEVEL_2', 'CLIENT_LEVEL_3' )  AND &FILE_SEQ_NB.=1)
		THEN TBL_QUALIFIER='TD.';
		ELSE TBL_QUALIFIER='IN.';
	/*  IF AN ALIAS HAS BEEN DEFINED FOR A FIELD THEN THE ' AS ' CLAUSE IS BUILD.*/
	IF FIELD_NM_I='' 
		THEN STR_FIELD=TRIMN(TBL_QUALIFIER) || TRIM(FIELD_NM) || COMMA;
		ELSE STR_FIELD=TRIMN(TBL_QUALIFIER) || TRIM(FIELD_NM_I) || ' AS ' || TRIM(FIELD_NM) || COMMA;

    /* START BUILDING THE SELECT STRING */
	IF _N_=1 THEN STR_SELECT='SELECT DISTINCT ';

	STR_SELECT=COMPBL(STR_SELECT) || TRIM(STR_FIELD);

	IF LAST THEN DO;
	        CALL SYMPUT('STR_SELECT',TRIM(STR_SELECT));
	        CALL SYMPUT('STR_FROM',TRIM(STR_FROM));
	        CALL SYMPUT('STR_FROM2',TRIM(STR_FROM2));
			CALL SYMPUT('STR_SELECT2',TRIM(STR_SELECT2));
			CALL SYMPUT('STR_SELECT3',TRIM(STR_SELECT3));
	        CALL SYMPUT('STR_WHERE',TRIM(STR_WHERE));
	END;

RUN;
%set_error_fl;

DATA WORK.FIELDS_THAT_MUST_BE_IN_INTABLE;
	SET WORK.ALL_FIELDS;
	IF FIELD_NM IN ('RECIPIENT_ID','LTR_RULE_SEQ_NB' )
		OR 
	(IN_TFILE_FIELDS=1 AND FIELD_NM NOT IN ('SBJ_FIRST_NM','SBJ_LAST_NM','CDH_EXTERNAL_ID','DEA_NB'));
	IF FIELD_NM NOT IN ('MINOR_IN');
	IF FIELD_NM_I='' THEN FIELD_NM_I=FIELD_NM;
RUN;

%IF &RESET_CLIENT_ID_FL.=1 %THEN %DO;
	PROC SQL;
	CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	EXECUTE
	(
		UPDATE &tbl_name_in.
		SET CLIENT_ID=-1
	) 
	BY DB2; /* Book of business */
	DISCONNECT FROM DB2;
	QUIT;
%END;

/* CREATE MACRO VARIABLES THAT CONTAINES THE LIST OF VARIABLES
THAT ARE ONLY ON THE INPUT OR OUTPUT TABLES */
PROC SQL NOPRINT;
	SELECT 	TRIMN(A.FIELD_NM_I),
			TRIMN(B.COLNAME),
			'IN.' || TRIMN(B.COLNAME)
	INTO
			: FIELDS_REQ_BUT_NOT_IN_INPUT SEPARATED BY ' ' ,
			: FIELDS_IN_INPUT_BUT_NOT_REQ SEPARATED BY ' ',
			: FIELDS_IN_INPUT_BUT_NOT_REQ_CSV SEPARATED BY ','
	FROM    WORK.FIELDS_THAT_MUST_BE_IN_INTABLE AS A  
	FULL JOIN
			WORK.FIELDS_THAT_ARE_IN_INTABLE     AS B
	ON  TRIM(A.FIELD_NM_I)=TRIM(B.COLNAME)
	WHERE 	(A.FIELD_NM_I IS NULL OR B.COLNAME IS  NULL)
		AND B.COLNAME NOT IN ('BIRTH_DT')
	;
QUIT;

%PUT FIELDS_REQ_BUT_NOT_IN_INPUT =&FIELDS_REQ_BUT_NOT_IN_INPUT;
%PUT FIELDS_IN_INPUT_BUT_NOT_REQ =&FIELDS_IN_INPUT_BUT_NOT_REQ;
%PUT FIELDS_IN_INPUT_BUT_NOT_REQ =&FIELDS_IN_INPUT_BUT_NOT_REQ;

PROC SQL NOPRINT;
	SELECT DISTINCT TRIMN(FIELD_NM) 
	INTO : ID_FIELDS_REQ_ON_OUTPUT_TBL SEPARATED BY ' '
	FROM WORK.ALL_FIELDS
	WHERE TRIMN(FIELD_NM) NOT IN ('RECIPIENT_ID','CLIENT_ID','RX_COUNT_QY','PT_COUNT_QY')
	;
QUIT;

%LET FIELDS_REQ_BUT_NOT_IN_INPUT=%CMPRES(&FIELDS_REQ_BUT_NOT_IN_INPUT.);
%LET FIELDS_IN_INPUT_BUT_NOT_REQ=%CMPRES(&FIELDS_IN_INPUT_BUT_NOT_REQ.);

%IF &DEBUG_FLAG. NE Y %THEN %DO;
	PROC SQL;
	DROP TABLE WORK.BASE_FIELDS_MAPPING,
	WORK.ALL_FIELDS, WORK.FIELDS_THAT_MUST_BE_IN_INTABLE,
	WORK.FIELDS_THAT_ARE_IN_INTABLE;
	QUIT;
%END;

OPTIONS NOTES;
%IF &FIELDS_IN_INPUT_BUT_NOT_REQ NE %STR() %THEN %DO;
	%PUT NOTE: THE FOLLOWING FIELDS WERE FOUND IN THE INPUT TABLE BUT ARE NOT REQUERED.
				FIELDS_IN_INPUT_BUT_NOT_REQ=&FIELDS_IN_INPUT_BUT_NOT_REQ;
	%IF &FILE_SEQ_NB=1 
		%THEN %LET STR_SELECT=&STR_SELECT. , &FIELDS_IN_INPUT_BUT_NOT_REQ_CSV;
		%ELSE %LET FIELDS_IN_INPUT_BUT_NOT_REQ=%STR();
	%PUT  ;
%END;

%PUT STR_SELECT = &STR_SELECT;
%PUT FIELDS_IN_INPUT_BUT_NOT_REQ_CSV = &FIELDS_IN_INPUT_BUT_NOT_REQ_CSV;
OPTIONS COMPRESS=YES;

%IF &FIELDS_REQ_BUT_NOT_IN_INPUT NE %THEN %DO;
	%LET ERR_FL=1;
	%PUT ERROR: THE FOLLOWING REQUIERED FIELDS WERE NOT FOUND IN THE INPUT TABLE.
				NO DATASETS WILL BE CREATED.
				FIELDS_REQ_BUT_NOT_IN_INPUT=&FIELDS_REQ_BUT_NOT_IN_INPUT;
%END;
%ELSE %DO;

/** PATCH TO GO AGAINST PRODUCTION DATA
    REMOVE THE PATCH BEFORE MOVING TO PRODUCTION **/
    
/** UNCOMMENT THIS QUERY BEFORE MOVING TO PRODUCTION **/
PROC SQL;
	CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	CREATE TABLE WORK.&TBL_NAME_OUT_SH. AS
	SELECT * FROM CONNECTION TO DB2
	(&STR_SELECT.
	&STR_FROM.
	&STR_WHERE.)
	;
QUIT;

/**	START TO COMMENT THIS QUERY BEFORE MOVING TO PRODUCTION **/		
/*
%LET POS=%INDEX(&TBL_NAME_IN,.);
%LET SCHEMA=%SUBSTR(&TBL_NAME_IN,1,%EVAL(&POS-1));
%LET TBL_NAME_IN_SH=%SUBSTR(&TBL_NAME_IN,%EVAL(&POS+1));

LIBNAME &SCHEMA.P  DB2 DSN=ANARPT SCHEMA=&SCHEMA. DEFER=YES USER = qcpap020 PW = anlt2web;

DATA &SCHEMA.P.&TBL_NAME_IN_SH.;
 SET &SCHEMA..&TBL_NAME_IN_SH.;
RUN;

PROC SQL;
CONNECT TO DB2 AS DB2(DSN=ANARPT USER = qcpap020 PW = anlt2web);
 CREATE TABLE WORK.&TBL_NAME_OUT_SH. AS
  SELECT * FROM CONNECTION TO DB2
    (&STR_SELECT.
         &STR_FROM.
         &STR_WHERE.)
        ;
QUIT;

PROC SQL;
 DROP TABLE &SCHEMA.P.&TBL_NAME_IN_SH.;
QUIT;
*/
/**	END OF COMMENT THIS QUERY BEFORE MOVING TO PRODUCTION **/	



%IF &CMCTN_ROLE_CD. NE 2 %THEN %DO;

	PROC SQL;
		SELECT COUNT(*) 
		INTO :MISSING_CNT
		FROM &TBL_NAME_IN
		WHERE PT_BENEFICIARY_ID IS NULL AND
		   	  ADJ_ENGINE IN ('RX', 'RE');
	QUIT;

	%IF &MISSING_CNT. > 0 AND &PROGRAM_ID. ^= 5250 %THEN %DO;

		%PUT NOTE: COUNT  OF MISSING QL_BENEFICIARY_ID FOR EDW DATA &MISSING_CNT.;
		%PUT NOTE: THESE MISSING BENEFICIARYs WILL HAVE PT_BENEFICIARY_ID AS 99999999;
		%PUT NOTE: THEIR ADDRESS INFORMATION WILL BE OBTAINED FROM EDW TABLES;

		%IF %SYSFUNC(EXIST(&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX)) %THEN %DO;
		PROC SQL;
			CONNECT TO ORACLE (PATH = &GOLD.);
			CREATE TABLE DATA_RES.CLAIMS_PULL_&INITIATIVE_ID._RX AS
			SELECT * FROM CONNECTION TO ORACLE
			( SELECT DISTINCT	 MBR.MBR_ID 
			                    ,MBR.MBR_GID
								,MBR.MBR_FIRST_NM AS BNF_FIRST_NM
								,MBR.MBR_LAST_NM AS BNF_LAST_NM	 			
								,MBR.ADDR_LINE1_TXT	AS ADDRESS1_TX 		
								,MBR.ADDR_LINE2_TXT	AS ADDRESS2_TX	
								,' '  AS ADDRESS3_TX	
								,MBR.ADDR_CITY_NM AS CITY_TX				
								,MBR.ADDR_ST_CD	AS STATE			
								,MBR.ADDR_ZIP_CD AS ZIP_CD
								,' ' AS ZIP_SUFFIX_CD
                               ,' ' as CDH_EXTERNAL_ID	
			 FROM &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RX MBR
			);
			DISCONNECT FROM ORACLE;
		QUIT;
		%END;

		%IF %SYSFUNC(EXIST(&ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RE)) %THEN %DO;
		PROC SQL;
			CONNECT TO ORACLE (PATH = &GOLD.);
			CREATE TABLE DATA_RES.CLAIMS_PULL_&INITIATIVE_ID._RE AS
			SELECT * FROM CONNECTION TO ORACLE
			( SELECT DISTINCT	 MBR.MBR_ID 
			                    ,MBR.MBR_GID
								,MBR.MBR_FIRST_NM AS BNF_FIRST_NM
								,MBR.MBR_LAST_NM AS BNF_LAST_NM	 			
								,MBR.ADDR_LINE1_TXT	AS ADDRESS1_TX 		
								,MBR.ADDR_LINE2_TXT	AS ADDRESS2_TX	
								,' '  AS ADDRESS3_TX	
								,MBR.ADDR_CITY_NM AS CITY_TX				
								,MBR.ADDR_ST_CD	AS STATE			
								,MBR.ADDR_ZIP_CD AS ZIP_CD
								,' ' AS ZIP_SUFFIX_CD
                                ,' ' as CDH_EXTERNAL_ID	
			 FROM &ORA_TMP..CLAIMS_PULL_&INITIATIVE_ID._RE MBR
			);
			DISCONNECT FROM ORACLE;
		QUIT;
		%END;

		%IF %SYSFUNC(EXIST(DATA_RES.CLAIMS_PULL_&INITIATIVE_ID._RX)) OR
		    %SYSFUNC(EXIST(DATA_RES.CLAIMS_PULL_&INITIATIVE_ID._RE)) %THEN %DO;

				%IF %SYSFUNC(EXIST(DATA_RES.CLAIMS_PULL_&INITIATIVE_ID._RX)) %THEN 
				 	%LET RX_TABLE = DATA_RES.CLAIMS_PULL_&INITIATIVE_ID._RX;
				%ELSE %LET RX_TABLE = ;

				%IF %SYSFUNC(EXIST(DATA_RES.CLAIMS_PULL_&INITIATIVE_ID._RE)) %THEN 
				 	%LET RE_TABLE = DATA_RES.CLAIMS_PULL_&INITIATIVE_ID._RE;
				%ELSE %LET RE_TABLE = ;

			DATA DATA_RES.CLAIMS_PULL_&INITIATIVE_ID.;
				SET &RX_TABLE.
                    &RE_TABLE.
				 ;
			RUN;
		%END;

		%IF %SYSFUNC(EXIST(DATA_RES.CLAIMS_PULL_&INITIATIVE_ID._RX)) %THEN %DO;
			PROC SQL;
				DROP TABLE DATA_RES.CLAIMS_PULL_&INITIATIVE_ID._RX;
			QUIT;
		%END;
		%IF %SYSFUNC(EXIST(DATA_RES.CLAIMS_PULL_&INITIATIVE_ID._RE)) %THEN %DO;
			PROC SQL;
				DROP TABLE DATA_RES.CLAIMS_PULL_&INITIATIVE_ID._RE;
			QUIT;
		%END;

		PROC SORT DATA = DATA_RES.CLAIMS_PULL_&INITIATIVE_ID.;
			BY MBR_ID MBR_GID;
		RUN;

		DATA DATA_RES.CLAIMS_PULL_&INITIATIVE_ID.;
			SET DATA_RES.CLAIMS_PULL_&INITIATIVE_ID.;
			BY  MBR_ID MBR_GID;
			IF LAST.MBR_GID;
		RUN;

        %DROP_DB2_TABLE(tbl_name=&DB2_TMP..CLAIMS_PULL_&INITIATIVE_ID.);
		PROC SQL;
			CREATE TABLE &DB2_TMP..CLAIMS_PULL_&INITIATIVE_ID. AS
			SELECT *
			FROM DATA_RES.CLAIMS_PULL_&INITIATIVE_ID.;
		QUIT;

		PROC SQL;
			CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
			CREATE TABLE WORK.&TBL_NAME_OUT_SH.2 AS
			SELECT * FROM CONNECTION TO DB2
			(&STR_SELECT.
			 &STR_FROM2.
			 WHERE IN.MBR_ID = TD.MBR_ID and
               PT_BENEFICIARY_ID IS NULL AND
		   	  ADJ_ENGINE IN ('RX', 'RE'))
			;DISCONNECT FROM DB2;
		QUIT;
        %DROP_DB2_TABLE(tbl_name=&DB2_TMP..CLAIMS_PULL_&INITIATIVE_ID.);

		PROC SQL;
			UPDATE WORK.&TBL_NAME_OUT_SH.2
			SET RECIPIENT_ID = 9999999999,
                SUBJECT_ID = 9999999999;
		QUIT;

		PROC APPEND BASE = WORK.&TBL_NAME_OUT_SH
		            DATA = WORK.&TBL_NAME_OUT_SH.2 FORCE;
		RUN;quit;

	%END;

%END;


/** PRESCRIBER EXCLUSIONS FOR QUALITY **/
/*%IF &CMCTN_ROLE_CD. EQ 2 %THEN %DO;*/
  OPTIONS NONOTES ;
  OPTIONS NOMLOGIC NOMPRINT NOSYMBOLGEN NOSOURCE2;

	%PRESCRIBER_OPT_OUTA(TBL_NAME_IN=WORK.&TBL_NAME_OUT_SH.,
						TBL_NAME_OUT=WORK.&TBL_NAME_OUT_SH.);
/*%END;*/

%PUT STR_SELECT = &STR_SELECT;
%PUT STR_FROM = &STR_FROM;
%PUT STR_FROM2 = &STR_FROM2;
%PUT STR_SELECT2 = &STR_SELECT2;
%PUT STR_SELECT3 = &STR_SELECT3;
%PUT STR_WHERE = &STR_WHERE;

%include "/PRG/sas%lowcase(&SYSMODE)1/hercules/macros/add_rocc_cd.sas";


%IF &FILE_SEQ_NB.> 1 %THEN %DO;
	PROC SQL;
		CREATE TABLE WORK.&TBL_NAME_OUT_SH._TEMP AS
		SELECT A.*
		FROM WORK.&TBL_NAME_OUT_SH. AS A,
		WORK.&TBL_NAME_OUT_SH_MAIN. AS B
		WHERE A.RECIPIENT_ID=B.RECIPIENT_ID
		;
	QUIT;

	Data WORK.&TBL_NAME_OUT_SH.;
		set WORK.&TBL_NAME_OUT_SH._TEMP;
	run;
%END;

%IF &file_id.=1 AND &PT_COUNT_QY_ON_INPUT_TBL_IN=0 %THEN %DO;

	PROC SORT DATA=WORK.&TBL_NAME_OUT_SH. FORCE;
		BY CLIENT_ID RECIPIENT_ID ;
	RUN;

	PROC MEANS DATA=WORK.&TBL_NAME_OUT_SH. NOPRINT NWAY;
		BY CLIENT_ID RECIPIENT_ID ;
		VAR RX_COUNT_QY;
		ID &ID_FIELDS_REQ_ON_OUTPUT_TBL. &FIELDS_IN_INPUT_BUT_NOT_REQ.;
		OUTPUT OUT=WORK.&TBL_NAME_OUT_SH.(DROP=_TYPE_ RENAME=(_FREQ_=PT_COUNT_QY))
		SUM(RX_COUNT_QY)=RX_COUNT_QY;
		RUN;
	QUIT;

%END;

%IF &FILE_SEQ_NB=1 %THEN %DO;
	%IF &FILE_ID. EQ 17 %THEN  %DO;                                                
		%GET_DATA_QUALITY(TBL_NAME_IN = WORK.&TBL_NAME_OUT_SH.,
				  TBL_NAME_OUT=DATA_PND.&TBL_NAME_OUT_SH.);
	%END;
	%ELSE %DO;
 		%include "/PRG/sas%lowcase(&sysmode)1/hercules/macros/additional_fields.sas";
		%GET_DATA_QUALITY(TBL_NAME_IN = WORK.&TBL_NAME_OUT_SH.,
				  TBL_NAME_OUT=DATA_PND.&TBL_NAME_OUT_SH.);
	%END;
%END;
%ELSE %DO;
	DATA DATA_PND.&TBL_NAME_OUT_SH.;
		SET WORK.&TBL_NAME_OUT_SH.;
	RUN;
%END;

%PUT NOTE: CREATED OUTPUT DATASET IN THE PENDING LIBRARY;
%set_error_fl;

DATA DATA_RES.&TBL_NAME_OUT_SH.;
 SET DATA_PND.&TBL_NAME_OUT_SH.;
RUN;

%PUT NOTE: CREATED OUTPUT DATASET IN THE RESULTS LIBRARY;
%set_error_fl;
OPTIONS NONOTES;
%END;
%PUT ENDING PROCESSING FOR:
							TBL_NAME_IN=&TBL_NAME_IN.
							CMCTN_ROLE_CD=,&CMCTN_ROLE_CD.
							FILE_ID=&FILE_ID.
							FILE_SEQ_NB=&FILE_SEQ_NB.;

%MEND CREATE_BASE_FILE0;

%MACRO LOOP_FILES;
  %LOCAL I J TBL_NAME_IN_TMP;
  %DO  I=1 %TO &N_FILES;
		OPTIONS COMPRESS=NO;
		%PUT  ;
		%PUT START PROCESSING DATA FOR CMCTN_ROLE_CD&I=&&CMCTN_ROLE_CD&I ;
		%PUT FILE_ID&I=&&FILE_ID&I;

		%LET MAX_FILE_SEQ_NB = 1;
		   
		PROC SQL NOPRINT;
			SELECT DISTINCT MAX(FILE_SEQ_NB) INTO : MAX_FILE_SEQ_NB
			FROM &HERCULES..TFILE_FIELD
			WHERE FILE_ID =&&FILE_ID&I;
		QUIT;

		/** SR - 14OCT2008 - ASSIGNED MACRO VARIABLE MAX_FILE_SEQ_NB TO 1,
		                     IF MACRO VARIABLE MAX_FILE_SEQ_NB RESOLVED FROM 
		                     THE SQL QUERY ABOVE IS MISSING.
		                     THIS HAPPENS WHEN TFILE_FIELD TABLE FOR THAT
		                     FILE_ID DOES NOT CONTAIN ANY ROWS (MEANING
		                     ONLY BASE COLUMNS ARE INCLUDED IN THE VENDOR FILE) **/

		%IF &MAX_FILE_SEQ_NB. EQ . %THEN %LET MAX_FILE_SEQ_NB = 1;

		%DO J=1 %TO &MAX_FILE_SEQ_NB.;
	        %LET TBL_NAME_IN_TMP=%SCAN(&TBL_NAME_IN_LIST,&J,%STR( ));
        	%IF %LENGTH(&TBL_NAME_IN_TMP) =0 %THEN %DO;
				%LET ERR_FL=1;
               	%PUT ERROR: NO INPUT TABLE WAS SUPPLIED FOR FILE_SEQ_NB=&J.;
			%END;
        	%IF &ERR_FL=0 %THEN %DO;
				%CREATE_BASE_FILE0(TBL_NAME_IN=&TBL_NAME_IN_TMP.,
				                   CMCTN_ROLE_CD=&&CMCTN_ROLE_CD&I,
				                   FILE_ID=&&FILE_ID&I,FILE_SEQ_NB=&J);
            %END; /*END OF ERR_FL=0 DO-GROUP */
       %END; /* END OF J-LOOP*/
  %END; /* END OF I-LOOP*/
%MEND LOOP_FILES;

%LOOP_FILES;

%IF &DEBUG_FLAG NE Y %THEN %DO;
 OPTIONS NOMLOGIC NOMPRINT NOSYMBOLGEN;
 PROC SQL;
  DROP TABLE WORK.TPHASE_RVR_FILE ;
 QUIT;
%END;
OPTIONS NOTES DATE;

%MEND CREATE_BASE_FILEA;
