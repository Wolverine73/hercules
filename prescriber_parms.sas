
/**HEADER ---------------------------------------------------------------------
 | NAME:     PRESCRIBER_PARMS.SAS
 |
 | PURPOSE:  SCREEN PROSCRIBERS BASED ON PROSCRIBER'S SPECIALTIES: THE RULES
 |           ARE RECORDED IN THE TINIT_PRSCBR_RULE.
 |
 | INPUT:    REQUIRED - PRESCRIBER_ID, PT_BENEFICIARY_ID, DRG_GROUP_SEQ_NB,
 |           DRG_SUB_GRP_SEQ_NB, RX_COUNT_QY
 |           REFERENCIAL TABLES: TINIT_PRSCBR_RULE, TINIT_PRSCBR_SPLTY,
 |                             CLAIMSA.TPBRSP_PRSCBR_SPC1
 |
 | OUTPUT:   A FLAG - PRESCRIBER_PARMS_TBL_EXIST_FLAG=0 IS CREATED WHEN SELECTION
 |           CRITERIA IS ONLY DEFAULT AND &tbl_name_out2 IS CREATED. OTHERWISE
 |           PRESCRIBER_PARMS_TBL_EXIST_FLAG IS SET TO 1 AND BOTH &TBL_NAME_OUT AND
 |           &TBL_NAME_OUT2 WILL BE CREATED.
 |
 |           &tbl_name_out: UDB TABLE WITH ONLY PRESCRIBER_ID FIELD FOR QUALIFIED PBR
 |           &tbl_name_out2: UDB TABLE WITH RETAINS ALL THE FIELDS FROM &TBL_NAME_IN
 |
 | USAGE:    %prescriber_parms
 |           (TBL_NAME_IN=&DB2_TMP..PBR_TEST,
 |            TBL_NAME_OUT=&DB2_TMP..PBR,
 |            TBL_NAME_OUT2=&DB2_TMP..PBR2)
 |
 | HISTORY:  SEPT. 2003, JOHN HOU
 |           JUNE 2012 - E BUKOWSKI(SLIOUNKOVA) -  TARGET BY DRUG/DSA AUTOMATION
 |           changed logic for checking on mbr_id/client_lvl1 combo in addition to pt_beneficiary_id
 |           for number of patient criteria for programs 105 and 106 (task 21)
 +-----------------------------------------------------------------------HEADER*/

 
 %MACRO prescriber_parms(tbl_name_in=,
             			 tbl_name_out=,
						 tbl_name_out2=);

 %LOCAL I J D_CHECK SLCTN_CNT INCLUDE_IN INC_CHAR RX_RANGE OPERATOR_TX SLCTN_STR DEFAULT_CNT PBR_CNT;
 %GLOBAL PRESCRIBER_PARMS_TBL_EXIST_FLAG;

 %PUT NOTE: START OF '%prescriber_parms' MACRO.;

 
%IF  &tbl_name_in= %THEN %DO;
			%LET err_fl=1;
			%PUT ERROR: Parameter tbl_name_in must be specified; %END;

%IF  &tbl_name_in= %THEN %GOTO EXIT;
						
%IF &tbl_name_out= %THEN %LET tbl_name_out=&DB2_TMP..&TABLE_PREFIX.PBR_PARMS;

  %isnull(TBL_NAME_IN, TBL_NAME_OUT);


 PROC SQL NOPRINT;
      SELECT PRESCRIBER_PARM_IN INTO: PRESCRIBER_IN
      FROM &HERCULES..TPROGRAM_TASK
      WHERE TASK_ID=&TASK_ID
       AND  PROGRAM_ID=&PROGRAM_ID;
      QUIT;

 %PUT &PRESCRIBER_IN;

*SASDOC--------------------------------------------------------------------------
|JUNE 2012 - TARGET BY DRUG/ DSA AUTOMATION
|           changed DEFAULT QUERY TO MAKE LEFT JOIN ON SPECIALTY
+------------------------------------------------------------------------SASDOC*;
 PROC SQL NOPRINT;
      SELECT COUNT(*) INTO: DEFAULT_CNT
      FROM &HERCULES..TINIT_PRSCBR_RULE A 
		LEFT JOIN &HERCULES..TINIT_PRSCBR_SPLTY B
		ON A.INITIATIVE_ID= B.INITIATIVE_ID
      WHERE A.INITIATIVE_ID=&INITIATIVE_ID
        AND (B.SPECIALTY_CD = ' ' OR B.SPECIALTY_CD IS NULL)
        AND A.MIN_PATIENTS_QY=1
        AND A.MAX_PATIENTS_QY=999
        AND A.MIN_RX_QY=1
        AND A.MAX_RX_QY=999; QUIT;


 PROC SQL NOPRINT;
      SELECT COUNT(*) INTO: PBR_CNT
      FROM &HERCULES..TINIT_PRSCBR_RULE
      WHERE INITIATIVE_ID=&INITIATIVE_ID; QUIT;

 %IF &DEFAULT_CNT=1 %THEN %DO;
    %PUT WARNING: ONLY DEFAULT SELECTIONS WERE FOUND FOR INITIATIVE &INITIATIVE_id.;
    %PUT WARNING: NO PRESCRIBERS RULE CHECK IS NEEDED. PRESCRIBER_FLAG IS SET TO 'DEFAULT'. ;

    %LET PRESCRIBER_PARMS_TBL_EXIST_FLAG=0;

    %END;

 %IF &DEFAULT_CNT=1 %THEN %GOTO EXIT;

%IF &PBR_CNT=0 %THEN %DO;
    %PUT WARNING: NO ENTRY IN &HERCULES..TINIT_PRSCBR_RULE WAS FOUND FOR INITIATIVE &INITIATIVE_id.;
    %LET PRESCRIBER_PARMS_TBL_EXIST_FLAG=0;

    %END;

 %IF &PBR_CNT=0 %THEN %GOTO EXIT;


 %IF &DEFAULT_CNT=0 AND &PBR_CNT>0 %THEN %DO;
  %LET PRESCRIBER_PARMS_TBL_EXIST_FLAG=1;


  PROC SQL NOPRINT;
       SELECT 'BETWEEN '||PUT(MIN_PATIENTS_QY,3.)||' AND '||PUT(MAX_PATIENTS_QY,5.),
              'BETWEEN '||PUT(MIN_RX_QY,3.)||' AND '||PUT(MAX_RX_QY,5.),
              OPERATOR_TX
        INTO: PT_CNT_STR, :RX_QY_STR, :OPERATOR_TX
        FROM  &HERCULES..TINIT_PRSCBR_RULE
        WHERE INITIATIVE_ID=&INITIATIVE_ID;
    QUIT;
%PUT &PT_CNT_STR &RX_QY_STR &OPERATOR_TX;


 PROC SQL NOPRINT;
      SELECT DISTINCT COUNT(*), INCLUDE_IN, SPECIALTY_CD
             INTO :SPCLTY_CNT,
                  :INCLUDE_IN,
                  :SPCLTY_LST SEPARATED BY ','
      FROM &HERCULES..TINIT_PRSCBR_SPLTY
      WHERE INITIATIVE_ID= &INITIATIVE_ID
       ORDER BY INCLUDE_IN DESCENDING;
      QUIT;
  %PUT &SPCLTY_CNT &INCLUDE_IN &SPCLTY_LST;
%*SASDOC ------------------------------------------------------------------------
 | INCLUDE_IN IS NULL or There is not entry in the TINIT_PBR_SPLTY table, 
 | SELECT ALL PRESCRIBERS WHO MEET THE PT AND RX COUNT RANGE
 +------------------------------------------------------------------------ SASDOC*;

%DROP_DB2_TABLE(TBL_NAME=&TBL_NAME_OUT);

*SASDOC--------------------------------------------------------------------------
|JUNE 2012 - TARGET BY DRUG/ DSA AUTOMATION
|           changed logic for checking on mbr_id in addition to pt_beneficiary_id
|          for number of patient criteria for programs 105 and 106 (task 21)
+------------------------------------------------------------------------SASDOC*;
 %if &include_in= OR &SPCLTY_CNT=0 %then %do;
  PROC SQL;
       CONNECT TO DB2 AS DB2 (DSN=&UDBSPRP);
       CREATE TABLE &TBL_NAME_OUT AS
       SELECT * FROM CONNECTION TO DB2
       (SELECT DISTINCT A.PRESCRIBER_ID
        FROM &TBL_NAME_IN A
             GROUP BY A.PRESCRIBER_ID
                   HAVING SUM(RX_COUNT_QY) &RX_QY_STR
                  &OPERATOR_TX (COUNT(PT_BENEFICIARY_ID) &PT_CNT_STR
					%IF (&PROGRAM_ID EQ 105 
    				OR (&PROGRAM_ID EQ 106 AND &TASK_ID EQ 21)) AND (&RX_ADJ. EQ 1 OR &RE_ADJ. EQ 1)
				   %THEN %DO;
				   		OR COUNT(MBR_CLNT) &PT_CNT_STR
				   %END;
				   )
        );
        DISCONNECT FROM DB2;
        QUIT;
 %end;

 %*SASDOC ------------------------------------------------------------------------
 | INCLUDE_IN IS 0, ASSUME ALL PRESCRIBERS EXCEPT EXCLUSIONS.
 +------------------------------------------------------------------------ SASDOC*;
 %if &include_in=0 %then %do;
  PROC SQL;
       CONNECT TO DB2 AS DB2 (DSN=&UDBSPRP);
       CREATE TABLE &TBL_NAME_OUT AS
       SELECT * FROM CONNECTION TO DB2
          ( WITH PBR_OUT AS
             (SELECT A.PRESCRIBER_ID
                FROM &TBL_NAME_IN A,
                     &CLAIMSA..TPBRSP_PRSCBR_SPC1 B,
                     &HERCULES..TINIT_PRSCBR_SPLTY C
               WHERE A.PRESCRIBER_ID=B.PRESCRIBER_ID
                AND  B.SPECIALTY_CD = C.SPECIALTY_CD
                AND  C.INITIATIVE_ID=&INITIATIVE_ID
                AND  C.INCLUDE_IN = 0
               GROUP BY A.PRESCRIBER_ID
                     HAVING SUM(RX_COUNT_QY) &RX_QY_STR
                    &OPERATOR_TX (COUNT(PT_BENEFICIARY_ID) &PT_CNT_STR
					%IF (&PROGRAM_ID EQ 105 
    				OR (&PROGRAM_ID EQ 106 AND &TASK_ID EQ 21)) AND (&RX_ADJ. EQ 1 OR &RE_ADJ. EQ 1)
				   %THEN %DO;
				   		OR COUNT(MBR_CLNT) &PT_CNT_STR
				   %END;
				   )
             )

      SELECT A.PRESCRIBER_ID
        FROM &TBL_NAME_IN A
        WHERE NOT EXISTS (SELECT 1 FROM PBR_OUT XOT
                           WHERE A.PRESCRIBER_ID=XOT.PRESCRIBER_ID)
        );
        DISCONNECT FROM DB2;
        QUIT;
  %end;
 %*SASDOC ------------------------------------------------------------------------
 | INCLUDE_IN IS 1, SELECT BASED ON INCLUSION RULES ONLY.
 +------------------------------------------------------------------------ SASDOC*;
%if &include_in=1 %then %do;

 PROC SQL;
       CONNECT TO DB2 AS DB2 (DSN=&UDBSPRP);
       CREATE TABLE &TBL_NAME_OUT AS
       SELECT * FROM CONNECTION TO DB2
       (SELECT A.PRESCRIBER_ID
        FROM &TBL_NAME_IN A,
             &CLAIMSA..TPBRSP_PRSCBR_SPC1 B,
             &HERCULES..TINIT_PRSCBR_SPLTY C
        WHERE A.PRESCRIBER_ID=B.PRESCRIBER_ID
         AND  B.SPECIALTY_CD = C.SPECIALTY_CD
         AND  C.INITIATIVE_ID=&INITIATIVE_ID
         AND  C.INCLUDE_IN = 1

        GROUP BY A.PRESCRIBER_ID
              HAVING SUM(RX_COUNT_QY) &RX_QY_STR
             &OPERATOR_TX (COUNT(PT_BENEFICIARY_ID) &PT_CNT_STR
			 %IF (&PROGRAM_ID EQ 105 
    			OR (&PROGRAM_ID EQ 106 AND &TASK_ID EQ 21)) AND (&RX_ADJ. EQ 1 OR &RE_ADJ. EQ 1)
			  %THEN %DO;
				   		OR COUNT(MBR_CLNT) &PT_CNT_STR
			  %END;
				   )
        );
        DISCONNECT FROM DB2;
        QUIT;

 %end;

 %*SASDOC ------------------------------------------------------------------------
 | INCLUDE_IN HAS BOTH 0 AND 1, SELECT INCLUSIONS FIRST AND FOLLOWED BY EXCLUSIONS
 +------------------------------------------------------------------------ SASDOC*;
%if %index(&include_in, 10)>0 %then %do;

%put NOTE: SELECTION HAS BOTH INCLUSION AND EXCLUSION;

 PROC SQL;
       CONNECT TO DB2 AS DB2 (DSN=&UDBSPRP);
       CREATE TABLE &TBL_NAME_OUT AS
       SELECT * FROM CONNECTION TO DB2
       (     WITH PBR_OUT AS
             (SELECT A.PRESCRIBER_ID
                FROM &TBL_NAME_IN A,
                     &CLAIMSA..TPBRSP_PRSCBR_SPC1 B,
                     &HERCULES..TINIT_PRSCBR_SPLTY C
               WHERE A.PRESCRIBER_ID=B.PRESCRIBER_ID
                AND  B.SPECIALTY_CD = C.SPECIALTY_CD
                AND  C.INITIATIVE_ID=&INITIATIVE_ID
                AND  C.INCLUDE_IN = 0
               GROUP BY A.PRESCRIBER_ID
                     HAVING SUM(RX_COUNT_QY) &RX_QY_STR
                    &OPERATOR_TX (COUNT(PT_BENEFICIARY_ID) &PT_CNT_STR
				%IF (&PROGRAM_ID EQ 105 
    			OR (&PROGRAM_ID EQ 106 AND &TASK_ID EQ 21)) AND (&RX_ADJ. EQ 1 OR &RE_ADJ. EQ 1)
			  	%THEN %DO;
				   		OR COUNT(MBR_CLNT) &PT_CNT_STR
			  	%END;
				   )
             )
      SELECT A.PRESCRIBER_ID
        FROM &TBL_NAME_IN A,
             &CLAIMSA..TPBRSP_PRSCBR_SPC1 B,
             &HERCULES..TINIT_PRSCBR_SPLTY C
        WHERE A.PRESCRIBER_ID=B.PRESCRIBER_ID
         AND  B.SPECIALTY_CD = C.SPECIALTY_CD
         AND  C.INITIATIVE_ID=&INITIATIVE_ID
         AND  C.INCLUDE_IN = 1
         AND  NOT EXISTS
              (SELECT 1 FROM PBR_OUT XOT
                        WHERE A.PRESCRIBER_ID=XOT.PRESCRIBER_ID)
        GROUP BY A.PRESCRIBER_ID
              HAVING SUM(RX_COUNT_QY) &RX_QY_STR
             &OPERATOR_TX (COUNT(PT_BENEFICIARY_ID) &PT_CNT_STR
			 	%IF (&PROGRAM_ID EQ 105 
    			OR (&PROGRAM_ID EQ 106 AND &TASK_ID EQ 21)) AND (&RX_ADJ. EQ 1 OR &RE_ADJ. EQ 1)
			  	%THEN %DO;
				   		OR COUNT(MBR_CLNT) &PT_CNT_STR
			  	%END;
				   )
        );
        DISCONNECT FROM DB2;
        QUIT;

 %end;
%END;

%if &program_id=79 %then %STR(
    PROC SQL;
         CONNECT TO DB2 (DSN=&UDBSPRP);
        EXECUTE(
         DELETE FROM &tbl_name_out A
          WHERE NOT EXISTS
                (SELECT 1 FROM &CLAIMSA..TPRSCBR_PRESCRIBE1 B
                   WHERE A.PRESCRIBER_ID=B.PRESCRIBER_ID
                     AND B.PBR_CLASS_CD = 1
                     AND B.PRCBR_STATUS_CD = 0
                     AND B.PRCBR_MLG_PRMSN_CD < 2
                     AND B.PRESCRIBER_ID > 0)) BY DB2;
         DISCONNECT FROM DB2;
         QUIT;
         );

%EXIT:;
  
 %IF &tbl_name_out2. NE AND &err_fl=0 %THEN
   %DO;
%drop_db2_table(tbl_name=&tbl_name_out2.);

 %LET pos=%INDEX(&tbl_name_out2,.);
 %LET Schema=%SUBSTR(&tbl_name_out2,1,%EVAL(&pos-1));
 %LET Tbl_name_out2_sh=%SUBSTR(&tbl_name_out2,%EVAL(&pos+1));

%IF &prescriber_parms_tbl_exist_flag=1 %THEN 
							%DO;	
  PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE TABLE &tbl_name_out2.	AS
      (  SELECT  A.*
			  FROM  &tbl_name_in AS A
      ) DEFINITION ONLY NOT LOGGED INITIALLY
	       ) BY DB2;
   DISCONNECT FROM DB2;
  QUIT;
  %set_error_fl;

  PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
   EXECUTE
  (ALTER TABLE &tbl_name_out2 ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;    
	EXECUTE(INSERT INTO &tbl_name_out2 
    	     SELECT A.*
		      FROM &tbl_name_in 	AS A,
		 		   &tbl_name_out 	AS B
                WHERE A.PRESCRIBER_ID=B.PRESCRIBER_ID
			) BY DB2;
QUIT;
 %set_error_fl;
%runstats(TBL_NAME=&tbl_name_out2);
%table_properties(TBL_NAME=&tbl_name_out2);
							%END;
%ELSE						
							%DO;
PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
    EXECUTE(CREATE ALIAS &tbl_name_out2.  FOR &tbl_name_in. ) BY DB2;
	DISCONNECT FROM DB2;
QUIT;
%set_error_fl;
							%END;
  %END;
%PUT NOTE: END OF '%prescriber_parms' MACRO.;
%MEND prescriber_parms;

 

 
