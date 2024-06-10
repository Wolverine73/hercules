
/***HEADER -------------------------------------------------------------------------
 |  MACRO NAME:     PULL_CLAIMS_FOR_QL.SAS
 |
 |  PURPOSE:    Pull claims for QL mailing
 |              
 |  INPUT:     
 |                         &CLAIMSA..&CLAIM_HIS_TBL
 |                         &CLAIMSA..TCLIENT1    
 |                         &CLAIMSA..TDRUG1   
 |                         
 |
 |  OUTPUT:     Standard datasets in /results and /pending directories
 |
 |
 |  HISTORY:    APRil 2008 - CARL STARKS
 |              
 |           Apr. 22, 2008 - Carl Starks - Hercules Version 2.1.01
 |
 |           This is a new macro used for QL claims logic is unchanged
 |           input and output file names are passed  
 | 			 - Hercules Version  2.1.2.01
 +-------------------------------------------------------------------------------HEADER*/
 

options mprint mlogic;

%MACRO pull_claims_for_ql_5799(tbl_name_in1=, tbl_name_in2=,tbl_name_in3=,
                                 tbl_name_out1=,tbl_name_out2=,tbl_name_out3=,
								 ADJ_ENGINE=
						);		
options symbolgen mlogic mprint;
%drop_db2_table(tbl_name=&tbl_name_out1.);
%drop_db2_table(tbl_name=&tbl_name_out2.);

DATA _NULL_;

%IF &RESOLVE_CLIENT_EXCLUDE_FLAG = 1 %THEN %DO;
  
    CALL SYMPUT('CLIENT_COND',TRIM(LEFT("NOT EXISTS")));
%END;
%ELSE %IF 
      &RESOLVE_CLIENT_EXCLUDE_FLAG = 0 %THEN  %DO;
       CALL SYMPUT('CLIENT_COND',TRIM(LEFT("EXISTS")));
%END;
RUN;


%IF (&PROGRAM_ID NE 105 OR &TASK_ID NE 11) %THEN %DO;
   %IF (&TASK_ID EQ 21) %THEN %DO;
	   %LET WHERECONS = %STR( 	AND &CLIENT_COND. (SELECT 1 FROM &TBL_NAME_IN1. CLT
					WHERE A.CLIENT_ID = CLT.CLIENT_ID ));
   %END;
   %ELSE %DO;
	   %LET WHERECONS = %STR( 	AND &CLIENT_COND. (SELECT 1 FROM &TBL_NAME_IN1. CLT
					WHERE A.CLT_PLAN_GROUP_ID = CLT.CLT_PLAN_GROUP_ID ));
   %END;
%END;
%ELSE %DO;
   %LET WHERECONS = %STR();
%END;

/*   %LET WHERECONS = %STR( 	AND &CLIENT_COND. (SELECT 1 FROM &TBL_NAME_IN1. CLT*/
/*                       		WHERE A.CLT_PLAN_GROUP_ID = CLT.CLT_PLAN_GROUP_ID ));*/

%PUT "CLIENT SET-UP WHERECONS = &WHERECONS.";

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE TABLE &tbl_name_out1. AS
      (  SELECT                  A.NTW_PRESCRIBER_ID AS PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID,
                                 A.PT_BENEFICIARY_ID,
                                 A.PT_BIRTH_DT          AS BIRTH_DT,
                                 B.DRG_GROUP_SEQ_NB,
                                 B.DRG_SUB_GRP_SEQ_NB,
								 &ADJ_ENGINE AS ADJ_ENGINE,
								 A.CLIENT_ID,
								 A.CLT_PLAN_GROUP_ID as CLT_PLAN_GROUP_ID2,
                                 A.RX_COUNT_QY,
                                 A.FILL_DT  AS LAST_FILL_DT,
                                 C.CLIENT_NM
                          FROM  &CLAIMSA..&CLAIM_HIS_TBL A,
                                &tbl_name_in2.             AS B,
                                &CLAIMSA..TCLIENT1                          AS C
      ) DEFINITION ONLY NOT LOGGED INITIALLY
               ) BY DB2;
   DISCONNECT FROM DB2;
QUIT;
 %set_error_fl;

%PUT CLAIMS_TBL=&CLAIMSA..&CLAIM_HIS_TBL;
*SASDOC--------------------------------------------------------------------------
|  The code below executes only if no drug information is required and
|  the drug group1 is all drugs
+------------------------------------------------------------------------SASDOC*;
%IF &ALL_DRUG_IN1=1 AND &DRUG_FIELDS_LIST=%STR() %THEN
                   %DO;
PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
EXECUTE
  (ALTER TABLE &tbl_name_out1. ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;

EXECUTE(INSERT INTO &tbl_name_out1.
        WITH PTS AS
                (SELECT                  A.NTW_PRESCRIBER_ID AS PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID,
                                 A.PT_BENEFICIARY_ID,
                                 MAX(A.PT_BIRTH_DT)     AS BIRTH_DT,
                                 MAX(1)                 AS DRG_GROUP_SEQ_NB,
                                 MAX(1)                 AS DRG_SUB_GRP_SEQ_NB,
                                 MAX(&ADJ_ENGINE) as ADJ_ENGINE,
                                 A.CLIENT_ID,
								 A.CLT_PLAN_GROUP_ID as CLT_PLAN_GROUP_ID2,
                                 SUM(A.RX_COUNT_QY)     AS  RX_COUNT_QY,
                                                                 MAX(A.FILL_DT)                 AS LAST_FILL_DT
                 FROM    &CLAIMSA..&CLAIM_HIS_TBL   AS A
         WHERE    A.FILL_DT BETWEEN &CLAIM_BEGIN_DT1. AND &CLAIM_END_DT1.
                  &WHERECONS.
                  &DELIVERY_SYSTEM_CONDITION.
         AND NOT EXISTS
              (SELECT 1
               FROM &CLAIMSA..&CLAIM_HIS_TBL
               WHERE A.BENEFIT_REQUEST_ID = BENEFIT_REQUEST_ID
               AND   A.BRLI_NB = BRLI_NB
               AND   BRLI_VOID_IN > 0)
                        GROUP BY A.NTW_PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID,
                                 A.PT_BENEFICIARY_ID,
                                 A.CLIENT_ID,
								 A.CLT_PLAN_GROUP_ID

                )
                SELECT E.*,
                           F.CLIENT_NM
                        FROM    PTS                                     AS E,
                                        &CLAIMSA..TCLIENT1              AS F
                      WHERE   E.CLIENT_ID = F.CLIENT_ID

      ) BY DB2;
          %PUT Before reset;
          %PUT SQLXRC=&SQLXRC SYSERR=&SYSERR;
      %reset_sql_err_cd;
   *  DISCONNECT FROM DB2;
QUIT;
%set_error_fl;

%IF &err_fl=0 %THEN %PUT Created table &tbl_name_out1. ;
%runstats(TBL_NAME=&DB2_TMP..&tbl_name_out1. );

                   %END; /* End of &ALL_DRUG_IN1=1 AND &DRUG_FIELDS_LIST=%STR()*/
*SASDOC--------------------------------------------------------------------------
| Check if NDC table is provided by macro %get_ndc and if yes join claims to this table.
| If the drug information is requiered the macro also joins to the STR_TDRUG1 table.
+------------------------------------------------------------------------SASDOC*;
%drop_db2_table(tbl_name=&tbl_name_out3.);

%IF &GET_NDC_NDC_TBL_FL=1 %THEN
                                        %DO;
PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE TABLE &tbl_name_out3.      AS
      (  SELECT  A.NTW_PRESCRIBER_ID AS PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID,
                                 A.PT_BENEFICIARY_ID,
                                 A.PT_BIRTH_DT AS BIRTH_DT,
                                 D.DRG_GROUP_SEQ_NB,
                                 D.DRG_SUB_GRP_SEQ_NB,
								 &ADJ_ENGINE AS ADJ_ENGINE,
                                 A.CLIENT_ID,
								 A.CLT_PLAN_GROUP_ID as CLT_PLAN_GROUP_ID2,
                                 A.RX_COUNT_QY,
                                 A.FILL_DT                                      AS LAST_FILL_DT,
                                 C.CLIENT_NM
                                 &DRUG_FIELDS_LIST_NDC.
                          FROM  &CLAIMSA..&CLAIM_HIS_TBL                        AS A,
                                &CLAIMSA..TCLIENT1                              AS C,
                                 &tbl_name_in2.  AS D,
                                 &CLAIMSA..TDRUG1                               AS G
      )DEFINITION ONLY NOT LOGGED INITIALLY
               ) BY DB2;
   DISCONNECT FROM DB2;
QUIT;
%set_error_fl;

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
EXECUTE
  (ALTER TABLE &tbl_name_out3. ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;
EXECUTE(INSERT INTO &tbl_name_out3.
                WITH PTS AS
        (SELECT                                  A.NTW_PRESCRIBER_ID    AS PRESCRIBER_ID,
                                 A.CDH_BENEFICIARY_ID,
                                 A.PT_BENEFICIARY_ID,
                                 MAX(A.PT_BIRTH_DT)     AS BIRTH_DT,
                                 B.DRG_GROUP_SEQ_NB,
                                 B.DRG_SUB_GRP_SEQ_NB,
                                 MAX(&ADJ_ENGINE) as ADJ_ENGINE,
                                 A.CLIENT_ID,
								 A.CLT_PLAN_GROUP_ID as CLT_PLAN_GROUP_ID2,
                                 D.DRUG_NDC_ID,
                                 D.NHU_TYPE_CD,
                                 SUM(A.RX_COUNT_QY) AS  RX_COUNT_QY,
                                                                 MAX(FILL_DT)           AS      LAST_FILL_DT
                 FROM    &CLAIMSA..&CLAIM_HIS_TBL                       AS A,
                         &tbl_name_in2.     AS B,
                         &tbl_name_in3.           AS D
        WHERE (   (B.ALL_DRUG_IN=0)
                           OR (&DRUG_FIELDS_FLAG=1 AND B.ALL_DRUG_IN=1))
                   AND    A.FILL_DT BETWEEN CLAIM_BEGIN_DT AND CLAIM_END_DT
                   AND    B.DRG_GROUP_SEQ_NB=D.DRG_GROUP_SEQ_NB
                   AND    B.DRG_SUB_GRP_SEQ_NB=D.DRG_SUB_GRP_SEQ_NB
                   AND    A.DRUG_NDC_ID = D.DRUG_NDC_ID
                   AND    A.NHU_TYPE_CD = D.NHU_TYPE_CD
                  &WHERECONS.
                  &DELIVERY_SYSTEM_CONDITION.
         AND NOT EXISTS
              (SELECT 1
               FROM &CLAIMSA..&CLAIM_HIS_TBL
               WHERE A.BENEFIT_REQUEST_ID = BENEFIT_REQUEST_ID
               AND   A.BRLI_NB = BRLI_NB
               AND   BRLI_VOID_IN > 0)
                        GROUP BY                 A.NTW_PRESCRIBER_ID,
                                                 A.CDH_BENEFICIARY_ID,
                                         A.PT_BENEFICIARY_ID,
                                         B.DRG_GROUP_SEQ_NB,
                                         B.DRG_SUB_GRP_SEQ_NB,
                                         D.DRUG_NDC_ID,
                                         D.NHU_TYPE_CD,
                                 A.CLIENT_ID,
								 A.CLT_PLAN_GROUP_ID



           FETCH FIRST &MAX_ROWS_FETCHED. ROWS ONLY )
                 SELECT                  E.PRESCRIBER_ID,
                                 E.CDH_BENEFICIARY_ID,
                                         E.PT_BENEFICIARY_ID,
                                 E.BIRTH_DT,
                                         E.DRG_GROUP_SEQ_NB,
                                 E.DRG_SUB_GRP_SEQ_NB,
								 &ADJ_ENGINE as ADJ_ENGINE,
                                 E.CLIENT_ID,
                                 E.CLT_PLAN_GROUP_ID2,
                                 E.RX_COUNT_QY,
                                                                 E.LAST_FILL_DT,
                                 F.CLIENT_NM
                                 &DRUG_FIELDS_LIST_NDC.
                        FROM    PTS                                     AS E,
                                        &CLAIMSA..TCLIENT1              AS F
                                        &STR_TDRUG1.
                      WHERE  E.CLIENT_ID = F.CLIENT_ID
                                &DRUG_JOIN_CONDITION.

      FETCH FIRST &MAX_ROWS_FETCHED. ROWS ONLY) BY DB2;
          %PUT Before reset;
          %PUT SQLXRC=&SQLXRC SYSERR=&SYSERR;
          %reset_sql_err_cd;
  * DISCONNECT FROM DB2;
QUIT;
 %set_error_fl;
                          
 PROC SQL NOPRINT;
  SELECT COUNT(*) INTO : COUNT_FOR_&TABLE_PREFIX.PT_DRUG_NM_ql
   FROM &tbl_name_out3.
    ;
 QUIT;

 %IF &&COUNT_FOR_&TABLE_PREFIX.PT_DRUG_NM_ql. >= &MAX_ROWS_FETCHED. %THEN
                                                                        %DO;
                                                        %LET err_fl=1;
%LET Message= The number of extracted rows exceed maximum allowed &MAX_ROWS_FETCHED.;
                                                                        %END;

%IF &err_fl=0 %THEN %PUT Created table &tbl_name_out3.;
%runstats(TBL_NAME=&tbl_name_out3. );

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
EXECUTE
  (ALTER TABLE &tbl_name_out1. ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;
EXECUTE(INSERT INTO &tbl_name_out1.
                        SELECT                   PRESCRIBER_ID,
                                 CDH_BENEFICIARY_ID,
                                                 PT_BENEFICIARY_ID,
                                 MAX(BIRTH_DT) AS BIRTH_DT,
                                 DRG_GROUP_SEQ_NB,
                                 DRG_SUB_GRP_SEQ_NB, 
                                 MAX(&ADJ_ENGINE) as ADJ_ENGINE,
                                 CLIENT_ID,
                                 CLT_PLAN_GROUP_ID2,
                                 SUM(RX_COUNT_QY)                       AS    RX_COUNT_QY,
                                                                 MAX(LAST_FILL_DT)                      AS      LAST_FILL_DT,
                                 MAX(CLIENT_NM) AS CLIENT_NM
                 FROM  &tbl_name_out3.
                        GROUP BY                 PRESCRIBER_ID,
                                         CDH_BENEFICIARY_ID,
                                         PT_BENEFICIARY_ID,
                                         DRG_GROUP_SEQ_NB,
                                         DRG_SUB_GRP_SEQ_NB,
                                         CLIENT_ID,
                                         CLT_PLAN_GROUP_ID2

      ) BY DB2;
%PUT Before reset;
%PUT SQLXRC=&SQLXRC SYSERR=&SYSERR;
 %reset_sql_err_cd;
* DISCONNECT FROM DB2;
QUIT;
%set_error_fl;
%IF &err_fl=0 %THEN %PUT Updated table &tbl_name_out1.;
%runstats(TBL_NAME=&tbl_name_out1. );

*SASDOC--------------------------------------------------------------------------
| Check for existence of drug group 2 and if it exist execute code based on
| whether the therapy rule is include or exclude.
+------------------------------------------------------------------------SASDOC*;
%IF &DRUG_GROUP2_EXIST_FLAG=1 AND &err_fl=0 %THEN
                                                                        %DO;
DATA _NULL_;
  SET &HERCULES..TINIT_DRUG_GROUP(WHERE=(       INITIATIVE_ID=&INITIATIVE_ID
                                           AND DRG_GROUP_SEQ_NB=2));
IF  TRIM(LEFT(OPERATOR_TX))='NOT' THEN CALL SYMPUT('NULL_CONDITION','IS NULL');
ELSE                                   CALL SYMPUT('NULL_CONDITION','IS NOT NULL');
RUN;
%set_error_fl;


%PUT NULL_CONDITION=&NULL_CONDITION;

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
   EXECUTE(CREATE TABLE &tbl_name_out2. AS
      (  SELECT  * FROM &tbl_name_out1.
      ) DEFINITION ONLY NOT LOGGED INITIALLY
               ) BY DB2;
   EXECUTE
  (ALTER TABLE &tbl_name_out2. ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;
        EXECUTE(INSERT INTO &tbl_name_out2. 
     WITH PTS  AS
                        ( SELECT PT_BENEFICIARY_ID,COUNT(*) AS COUNT
                   FROM &tbl_name_out1. 
                                        WHERE DRG_GROUP_SEQ_NB=2
                                          GROUP BY  PT_BENEFICIARY_ID
                                )
           SELECT A.*
                 FROM &tbl_name_out1. AS A        LEFT JOIN
                 PTS                                                                            AS B
         ON A.PT_BENEFICIARY_ID=B.PT_BENEFICIARY_ID
         WHERE  B.PT_BENEFICIARY_ID &NULL_CONDITION
                        ) BY DB2;
%PUT Before reset;
%PUT SQLXRC=&SQLXRC SYSERR=&SYSERR;
%reset_sql_err_cd;
* DISCONNECT FROM DB2;
QUIT;
%set_error_fl;
%runstats(TBL_NAME=&tbl_name_out2. );
                                                        %END; /* End of &DRUG_GROUP2_EXIST_FLAG = 1*/
%ELSE
                                                                                                                %DO;

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
   EXECUTE(CREATE ALIAS &tbl_name_out2. FOR
                                                &tbl_name_out1.
           ) BY DB2;
        DISCONNECT FROM DB2;
QUIT;
%set_error_fl;
                                                                %END; /* End of &GET_NDC_NDC_TBL_FL = 1 AND &DRUG_GROUP2*/

                                   %END; /* End of &GET_NDC_NDC_TBL_FL = 1 */
%ELSE
                        %DO;
PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE ALIAS &tbl_name_out3.  FOR
                                                &tbl_name_out1. 
           ) BY DB2;
        DISCONNECT FROM DB2;
QUIT;
%set_error_fl;

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE ALIAS &tbl_name_out2. FOR
                                                &tbl_name_out1. 
           ) BY DB2;
        DISCONNECT FROM DB2;
QUIT;
%set_error_fl;
                        %END; /* End of &GET_NDC_NDC_TBL_FL NE 1 */

%IF &err_fl=0 %THEN
                                        %DO;
    %PUT Created table &tbl_name_out3. ;
        %PUT Created table &tbl_name_out2. ;
                                        %END;

%table_properties(TBL_NAME=&tbl_name_out1. );
%table_properties(TBL_NAME=&tbl_name_out3. );
%table_properties(TBL_NAME=&tbl_name_out2. );
%MEND pull_claims_for_ql_5799;

