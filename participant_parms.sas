
/**HEADER ---------------------------------------------------------------------
 | NAME:     PARTICIPANT_PARMS.SAS
 |
 | PURPOSE:  SCREEN PTBENEFICIARY BASED ON TINIT_PRTCPNT_RULE:
 |           minimum and maximum AGE (defaults to min 0,  max 999), RX_COUNT_QY
 |           (defaults to min 1 & max 999) and GENDER.
 |
 |
 | INPUT:    UDB TABLE WITH - PT_BENEFICIARY_ID, DRG_GROUP_SEQ_NB, RX_COUNT_QY
 |           PT_BENEFICIARY_ID DOES NOT NEED TO BE UNIQUE ON INPUT TABLE. MACRO
 |           WILL SUM PRESCRIPTION COUNT.
 |
 | OUTPUT:   A FLAG - PARTICIPANT_PARMS_TBL_EXIST_FLAG=0 IS CREATED WHEN SELECTION
 |           CRITERIA IS ONLY DEFAULT AND &tbl_name_out2 IS CREATED. OTHERWISE
 |           PARTICIPANT_PARMS_TBL_EXIST_FLAG IS SET TO 1 AND BOTH &TBL_NAME_OUT AND
 |           &TBL_NAME_OUT2 WILL BE CREATED.
 |
 |           &tbl_name_out: UDB TABLE WITH ONLY PARTICIPANT_ID FIELD FOR QUALIFIED PBR
 |           &tbl_name_out2: UDB TABLE RETAINING ALL THE FIELDS FROM &TBL_NAME_IN
 |
 | USAGE:    %participant_parms(
 |                tbl_name_in=&db2_tmp..claim_info,
 |                tbl_name_out=&db2_tmp..resolved_pts,
 |                tbl_name_out2=   )
 |
 | HISTORY:  SEPT. 2003, JOHN HOU
 |           AUG 2004, Add memeber_cost_at to the selection creteria
 |           JUNE 2012 - E BUKOWSKI(SLIOUNKOVA) -  TARGET BY DRUG/DSA AUTOMATION
 |           changed logic for pulling gender by eliminating join to beneficiary table
 |           on Zeus, which allows RE/RX members without valid QL beneficiary id to be passed
 |           to the output file (change is only done for program 105 and 106 (task 21))
 |           also changed the logic of the final join to the parameter file to use mbr_id
 |           or pt_beneficiary_id
 +-----------------------------------------------------------------------HEADER*/




%MACRO participant_parms
           (tbl_name_in=,
            tbl_name_out=,
                        tbl_name_out2=);

OPTIONS MPRINT MPRINTNEST MLOGIC MLOGICNEST SYMBOLGEN SOURCE2;

%LOCAL I J D_CHECK SLCTN_CNT INCLUDE_IN INC_CHAR AGE CRITERIA_CNT;
%GLOBAL PARTICIPANT_PARMS_TBL_EXIST_FLAG ;

%PUT NOTE: START OF (&sysmacroname) MACRO.;

%IF  &tbl_name_in= %THEN %DO;
                        %LET err_fl=1;
                        %PUT ERROR: Parameter tbl_name_in must be specified; %END;
%IF  &tbl_name_in= %THEN %GOTO EXIT;

%IF &tbl_name_out= %THEN %LET TBL_NAME_OUT=&DB2_TMP..&TABLE_PREFIX.PT_PARMS;
%*SASDOC -------------------------------------------------------------------------
 |  DETERMINE IF THERE REALLY ARE NO PARTICIPANT PARMS.  SOME PROGRAM-TASKS REQUIRE
 |  THAT THE USER MAKE A SELECTION (DEFAULT).
 +---------------------------------------------------------------------------SASDOC*;

PROC SQL NOPRINT;
     SELECT COUNT(*) INTO: DEFAULT_CNT
     FROM  &HERCULES..TINIT_PRTCPNT_RULE
     WHERE INITIATIVE_ID=&INITIATIVE_ID
       and GENDER_OPTION_CD=1
       and MINIMUM_AGE_AT=0
       and MAXIMUM_AGE_AT=999
       and PRTCPNT_MIN_RX_QY=1
       and PRTCPNT_MAX_RX_QY=999  ;

  create table default as
     SELECT *
     FROM  &HERCULES..TINIT_PRTCPNT_RULE
     WHERE INITIATIVE_ID=&INITIATIVE_ID
       and GENDER_OPTION_CD=1
       and MINIMUM_AGE_AT=0
       and MAXIMUM_AGE_AT=999

       and PRTCPNT_MIN_RX_QY=1
       and PRTCPNT_MAX_RX_QY=999  ;
     QUIT;

PROC SQL NOPRINT;
     SELECT COUNT(*)-&default_cnt, COUNT(*) INTO: VALID_CNT, :TOT_CNT
     FROM &HERCULES..TINIT_PRTCPNT_RULE
     WHERE INITIATIVE_ID=&INITIATIVE_ID;
     QUIT;

  %PUT NOTE: %cmpres(&TOT_CNT) ROW(S) OF SELECTIONS WERE FOUND FOR INITIATIVE &INITIATIVE_id IN &HERCULES..TINIT_PRTCPNT_RULE.;


%*SASDOC -------------------------------------------------------------------------
 |  ELIMINATE DEFAULT USER INPUTED ROWS, ASSUMING THE DEFAULT INPUTS WERE BY
 |  USER MISTAKE.
 +---------------------------------------------------------------------------SASDOC*;

PROC SQL  NOPRINT;
     CREATE TABLE TINIT_PRTCPNT_RULE AS
     SELECT *
     FROM &HERCULES..TINIT_PRTCPNT_RULE
     WHERE INITIATIVE_ID=&INITIATIVE_ID;
     QUIT;

    %IF &TOT_CNT=0 %THEN
      %LET PARTICIPANT_PARMS_TBL_EXIST_FLAG=0;
          %ELSE %LET PARTICIPANT_PARMS_TBL_EXIST_FLAG=1;

%IF &TOT_CNT=0 %THEN %GOTO EXIT;

%*SASDOC ------------------------------------------------------------------------
 | RX_COUNT_QY are always assumed exist in the input data, while the existance of
 | MEMEBER_COST_AT will be determined and strings will be created for handling
 | MEMBER_COST_AT.
 +-------------------------------------------------------------------------SASDOC*;
 proc contents data=&tbl_name_IN OUT=CNTNT(KEEP=NAME) NOPRINT; run;

  PROC SQL NOPRINT;
       SELECT COUNT(*) INTO: member_cost_exist
       FROM  CNTNT
       WHERE UPCASE(NAME) CONTAINS 'MEMBER_COST_AT';
       QUIT;
%IF &member_cost_exist=0 %THEN %do;
        %LET member_cost_STR=;
        %LET m_cst_where=;
      %END;
 %ELSE %DO;
       %LET member_cost_STR=%STR(, SUM(MEMBER_COST_AT) AS MEMBER_COST_AT);
       %LET M_CST_WHERE=
            %STR(|| OPERATOR_2_TX||' MEMBER_COST_AT BETWEEN '||
                 PUT(MIN_MEMBER_COST_AT,8.2)||' AND '|| PUT(MAX_MEMBER_COST_AT,8.2)
                );
       %END;

%*SASDOC ------------------------------------------------------------------------
 | SUMMARIZE INPUT DATA FOR RX_COUNT_QY AND MEMBER_COST_AT BY PT_BENEFICIARY_ID,
 | AGE AND GENDER.
 +-------------------------------------------------------------------------SASDOC*;
*SASDOC--------------------------------------------------------------------------
|JUNE 2012 - TARGET BY DRUG/ DSA AUTOMATION
|Changed for programs 105 and 106 (task 21) for pulling gender by eliminating join 
|beneficiary table on Zeus, which allows members without valid QL beneficiary id 
|to be passed to the output file
+------------------------------------------------------------------------SASDOC*;
   %IF &PROGRAM_ID EQ 105 
    OR (&PROGRAM_ID EQ 106 AND &TASK_ID EQ 21) %THEN %DO;
    PROC SQL;
     CONNECT TO DB2 (DSN=&UDBSPRP);

	 %IF (&RX_ADJ. EQ 1 OR &RE_ADJ. EQ 1) %THEN %DO;
     CREATE TABLE PT_TMP1 AS
     SELECT * FROM CONNECTION TO DB2
       ( SELECT PT_BENEFICIARY_ID, MBR_ID, CLIENT_LEVEL_1, YEAR(CURRENT DATE - BIRTH_DT) AS BNF_AGE, 


	            CASE WHEN MBR_GNDR_GID  = 1 THEN 'M'
					 WHEN MBR_GNDR_GID  = 2 THEN 'F'
	 				 ELSE ' '  END                         AS GENDER_CD,
                SUM(RX_COUNT_QY) AS RX_COUNT_QY &member_cost_STR
         FROM &TBL_NAME_IN 
         WHERE DRG_GROUP_SEQ_NB=1
		  AND ADJ_ENGINE IN ('RX','RE')
          GROUP BY PT_BENEFICIARY_ID, MBR_ID, CLIENT_LEVEL_1, YEAR(CURRENT DATE-BIRTH_DT), MBR_GNDR_GID);
     %END;

	 %IF &QL_ADJ. EQ 1 %THEN %DO;
	CREATE TABLE PT_TMP2 AS
     SELECT * FROM CONNECTION TO DB2
		(SELECT PT_BENEFICIARY_ID, CHAR(PT_BENEFICIARY_ID) AS MBR_ID, CLIENT_LEVEL_1, YEAR(CURRENT DATE -A.BIRTH_DT) AS BNF_AGE, GENDER_CD,
                SUM(RX_COUNT_QY) AS RX_COUNT_QY &member_cost_STR
         FROM &CLAIMSA..TBENEF_BENEFICIAR1 A, &TBL_NAME_IN B
         WHERE A.BENEFICIARY_ID=B.PT_BENEFICIARY_ID
          AND  B.DRG_GROUP_SEQ_NB=1
		   AND B.ADJ_ENGINE IN ('QL')
          GROUP BY PT_BENEFICIARY_ID, CHAR(PT_BENEFICIARY_ID), CLIENT_LEVEL_1, YEAR(CURRENT DATE-A.BIRTH_DT), GENDER_CD);
	  %END;
     DISCONNECT FROM DB2;
     QUIT;

	 DATA PT_TMP;
	 SET 
	 %IF (&RX_ADJ. EQ 1 OR &RE_ADJ. EQ 1) %THEN %DO;
		PT_TMP1 
	 %END;
	 %IF &QL_ADJ. EQ 1 %THEN %DO;
		PT_TMP2
	 %END;
		;
	 IF BNF_AGE = . THEN BNF_AGE = 999;
	 RUN;
	 %END;
	 %ELSE %DO;
	     PROC SQL;
     CONNECT TO DB2 (DSN=&UDBSPRP);
     CREATE TABLE PT_TMP AS
     SELECT * FROM CONNECTION TO DB2
       ( SELECT PT_BENEFICIARY_ID, YEAR(CURRENT DATE -A.BIRTH_DT) AS BNF_AGE, GENDER_CD,
                SUM(RX_COUNT_QY) AS RX_COUNT_QY &member_cost_STR
         FROM &CLAIMSA..TBENEF_BENEFICIAR1 A, &TBL_NAME_IN B
         WHERE A.BENEFICIARY_ID=B.PT_BENEFICIARY_ID
          AND  B.DRG_GROUP_SEQ_NB=1
          GROUP BY PT_BENEFICIARY_ID, YEAR(CURRENT DATE-A.BIRTH_DT), GENDER_CD)
       ;
	 %END;

%*SASDOC ------------------------------------------------------------------------
 | EXTRACT SELECTION CRITERIA AND STORE THEM INTO STRINGS.
 |  NOTE: It is assumed that Demographics - age and gender
 |        while utilization measurements
 +-------------------------------------------------------------------------SASDOC*;

PROC SQL NOPRINT;
     SELECT DISTINCT INCLUDE_IN INTO: INCLUDE_IN SEPARATED BY ''
     FROM &HERCULES..TINIT_PRTCPNT_RULE
     WHERE INITIATIVE_ID=&INITIATIVE_ID

     ORDER BY INCLUDE_IN;
     QUIT;

%LET INC_CHAR=C&INCLUDE_IN;

%LET SLCTN_STR=
     %STR(DATA _NULL;
      SET SUB_SET END=LAST;
      length _where $ 300 GENDER_STR $ 30;
      format _where $300.;
      IF GENDER_OPTION_CD=1 THEN GENDER_STR="GENDER_CD IN ('F','M',' ')";
      ELSE IF GENDER_OPTION_CD=2 THEN GENDER_STR="GENDER_CD IN ('F')";
      ELSE GENDER_STR="GENDER_CD IN ('M')";
      if operator_2_tx ne '' then do;

      _where='(BNF_AGE BETWEEN '||PUT(MINIMUM_AGE_AT,2.)||' AND '||PUT(MAXIMUM_AGE_AT,3.)||
              ' AND '|| GENDER_STR ||') '||operator_tx||' '|| '(RX_COUNT_QY BETWEEN '||
              PUT(PRTCPNT_MIN_RX_QY,4.)||' AND '|| PUT(PRTCPNT_MAX_RX_QY,5.)||' '
              &M_CST_WHERE ||')';
       end;
       else do;
        _where='(BNF_AGE BETWEEN '||PUT(MINIMUM_AGE_AT,2.)||' AND '||PUT(MAXIMUM_AGE_AT,3.)||
              ' AND '|| GENDER_STR ||') '||operator_tx||' '|| '(RX_COUNT_QY BETWEEN '||
              PUT(PRTCPNT_MIN_RX_QY,4.)||' AND '|| PUT(PRTCPNT_MAX_RX_QY,5.)||')';
       end;
      Call symput ('_where'||put(_n_,1.), _where);
      IF LAST THEN CALL SYMPUT('CRITERIA_CNT',PUT(_N_,1.) );
     RUN;);

%drop_db2_table(tbl_name=&tbl_name_out);


%*SASDOC ------------------------------------------------------------------------
 | APPLY SELECTION CRITERIA FOR INCLUSION ONLY.
 +-------------------------------------------------------------------------SASDOC*;
%IF &INC_CHAR=C1 %THEN %DO;
 DATA SUB_SET;
     SET &HERCULES..TINIT_PRTCPNT_RULE
        (WHERE=(INCLUDE_IN IN (&INCLUDE_IN) AND INITIATIVE_ID=&INITIATIVE_ID ));
     RUN;
 &SLCTN_STR;


%DO I=1 %TO &CRITERIA_CNT;
 %put &&_where&i;
  %IF &I=1 %THEN %DO;
 PROC SQL;
        CREATE TABLE &TBL_NAME_OUT(bulkload=yes) AS
        SELECT PT_BENEFICIARY_ID
%IF  (&PROGRAM_ID EQ 105 OR (&PROGRAM_ID EQ 106 AND &TASK_ID EQ 21)) %THEN %DO;
			 , MBR_ID 
			 , CLIENT_LEVEL_1
%END;
			FROM PT_TMP
        WHERE  &&_where&i;
    QUIT;
   %END;
  %ELSE %DO;
   PROC SQL;
        INSERT INTO &TBL_NAME_OUT (bulkload=yes)
        SELECT PT_BENEFICIARY_ID
%IF  (&PROGRAM_ID EQ 105 OR (&PROGRAM_ID EQ 106 AND &TASK_ID EQ 21)) %THEN %DO;
			 , MBR_ID 
			 , CLIENT_LEVEL_1 
%END;
		FROM PT_TMP
        WHERE  &&_where&i;
      QUIT;
      %END;
    %END;
%END;


%*SASDOC ---------------------------------------------------------------------
 |  APPLY SELECTION CRITERIA FOR EXCLUSION ONLY.
 +----------------------------------------------------------------------SASDOC*;

%IF &INC_CHAR=C0 %THEN %DO;

DATA SUB_SET;
     SET &HERCULES..TINIT_PRTCPNT_RULE
        (WHERE=(INCLUDE_IN IN (&INCLUDE_IN) AND INITIATIVE_ID=&INITIATIVE_ID ));
     RUN;

 &SLCTN_STR;

%DO I=1 %TO &CRITERIA_CNT;
 %put &&_where&i;
    PROC SQL;
         DELETE FROM PT_TMP
         WHERE  &&_where&i; QUIT;
   %END;
    DATA &TBL_NAME_OUT(bulkload=yes);
         SET PT_TMP(KEEP=PT_BENEFICIARY_ID 
%IF (&PROGRAM_ID EQ 105 OR (&PROGRAM_ID EQ 106 AND &TASK_ID EQ 21)) %THEN %DO;
					MBR_ID
					CLIENT_LEVEL_1
%END;
					);
         RUN;
%END;

%*SASDOC ---------------------------------------------------------------------
 |  SELECTION CRITERIA FOR INCLUSION THEN EXCLUSION.
 +----------------------------------------------------------------------SASDOC*;

%IF &INC_CHAR=C01 %THEN %DO;
     %LET INCLUDE_IN=1;
 DATA SUB_SET;
     SET &HERCULES..TINIT_PRTCPNT_RULE
        (WHERE=(INCLUDE_IN IN (&INCLUDE_IN) AND INITIATIVE_ID=&INITIATIVE_ID ));
     RUN;
          &SLCTN_STR;

 %DO I=1 %TO &CRITERIA_CNT;
   %put &&_where&i;
      %IF &I=1 %THEN %DO;
          PROC SQL;
               CREATE TABLE DATA_OUT AS
               SELECT * FROM PT_TMP
               WHERE  &&_where&i; QUIT;
         %END;
    %ELSE %DO;
          PROC SQL;
               INSERT INTO DATA_OUT
               SELECT * FROM PT_TMP
               WHERE  &&_where&i; QUIT;
          %END;
      %END;

    %LET INCLUDE_IN=0;

 DATA SUB_SET;
     SET &HERCULES..TINIT_PRTCPNT_RULE
        (WHERE=(INCLUDE_IN IN (&INCLUDE_IN) AND INITIATIVE_ID=&INITIATIVE_ID ));
     RUN;

          &SLCTN_STR;

     %DO j=1 %TO &CRITERIA_CNT;
 %put &&_where&j;
         PROC SQL;
              DELETE FROM DATA_OUT
              WHERE  &&_where&j; QUIT;
         %END;

%IF &PROGRAM_ID=79 %THEN %DO;
 PROC SQL;
      CREATE TABLE DATA_OUT AS
      SELECT A.PT_BENEFICIARY_ID
        FROM DATA_OUT A
        WHERE NOT EXISTS
              (SELECT 1 FROM CLAIMSA.TBENEF_PGM_HIS B
                WHERE A.PT_BENEFICIARY_ID=B.BENEFICIARY_ID
                 AND B.PROGRAM_ID=39
                 AND B.BENEF_PGM_STAT_CD = 1 );
     QUIT;
%END;

%*SASDOC ---------------------------------------------------------------------------
 | If the program_id = 79 (HELP mailings) check TBENEF_PGM_HIS for an effective row
 | for the beneficiary_id where program_id = 39 (C & P) and BENEF_PGM_STAT_CD = 1
 | (exclude).  You will not find program_id 79 on this table.  The idea is that
 | if the participant asks to be excluded from all C & P programs, this is the
 | same as excluding them from all HELP mailings.
 + --------------------------------------------------------------------------SASDOC*;

proc sql;
     create table &TBL_NAME_OUT (BULKLOAD=YES) as
     select * from data_out;
   quit;


  %END;

  %runstats(tbl_name=&tbl_name_out);

%*SASDOC ---------------------------------------------------------------------------
 | Move the EXIT flag to end of the program
 + --------------------------------------------------------------------------SASDOC*;
  %let err_fl=0;
/*  %EXIT:;*/

 %IF &tbl_name_out2. NE AND &err_fl=0 %THEN
   %DO;
 %drop_db2_table(tbl_name=&tbl_name_out2.);

 %LET pos=%INDEX(&tbl_name_out2,.);
 %LET Schema=%SUBSTR(&tbl_name_out2,1,%EVAL(&pos-1));
 %LET Tbl_name_out2_sh=%SUBSTR(&tbl_name_out2,%EVAL(&pos+1));

  %IF &participant_parms_tbl_exist_flag=1  %THEN
                                                        %DO;
  PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE TABLE &tbl_name_out2. AS
      (  SELECT  A.*
                          FROM  &tbl_name_in. AS A
      ) DEFINITION ONLY NOT LOGGED INITIALLY
               ) BY DB2;
   DISCONNECT FROM DB2;
  QUIT;
 %set_error_fl;

   PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
   EXECUTE
  (ALTER TABLE &tbl_name_out2. ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;
        EXECUTE(INSERT INTO &tbl_name_out2.
             SELECT A.*
                      FROM &tbl_name_in.        AS A,
                                   &tbl_name_out.               AS B
                WHERE A.PT_BENEFICIARY_ID=B.PT_BENEFICIARY_ID
                        ) BY DB2;
QUIT;
%set_error_fl;

%IF (&PROGRAM_ID EQ 105 
    OR (&PROGRAM_ID EQ 106 AND &TASK_ID EQ 21)) AND (&RX_ADJ. EQ 1 OR &RE_ADJ. EQ 1)
%THEN %DO;
   PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
		EXECUTE(INSERT INTO &tbl_name_out2.
             SELECT A.*
                      FROM &tbl_name_in.        AS A,
                                   &tbl_name_out.               AS B
                WHERE A.PT_BENEFICIARY_ID IS NULL 
				  AND A.MBR_ID = B.MBR_ID
				  AND A.CLIENT_LEVEL_1 = B.CLIENT_LEVEL_1
                        ) BY DB2;
	QUIT;
	%END;



%runstats(TBL_NAME=&tbl_name_out2.);
%table_properties(TBL_NAME=&tbl_name_out2.);
                                                        %END;
%ELSE                                           %DO;
PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
    EXECUTE(CREATE ALIAS &tbl_name_out2.  FOR &tbl_name_in. ) BY DB2;
        DISCONNECT FROM DB2;
QUIT;
%set_error_fl;
                                                        %END;
%END;

%*SASDOC ---------------------------------------------------------------------------
 | Moved the EXIT flag to end of the program
 + --------------------------------------------------------------------------SASDOC*;

  %EXIT:;

%PUT NOTE: END OF (&sysmacroname) MACRO.;

%MEND participant_parms;

/** CALL EXAMPLE **/
/***
  options sysparm='initiative_id=42 phase_seq_nb=1';
  %include '/PRG/sastest1/hercules/hercules_in.sas';
*OPTIONS MPRINT MLOGIC;
  %participant_parms(tbl_name_in=&DB2_TMP..T_42_1_CLAIMS,
                     tbl_name_out=&DB2_TMP..PTS,
                     tbl_name_out2=&DB2_TMP..PTS2   );  ***/
