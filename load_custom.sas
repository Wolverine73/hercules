
%set_sysmode;

*SASDOC--------------------------------------------------------------------------
| INPUT: Custom Client Hierarchies
+------------------------------------------------------------------------SASDOC*;
filename qlfile "/herc&sysmode/data/hercules/5295/ql_client_file.csv"; 
filename rxfile "/herc&sysmode/data/hercules/5295/rx_client_file.csv"; 
filename refile "/herc&sysmode/data/hercules/5295/re_client_file.csv"; 

*SASDOC--------------------------------------------------------------------------
| INPUT: Custom Drug Matrix
+------------------------------------------------------------------------SASDOC*;
filename drg    "/herc&sysmode./data/hercules/5295/Custom.csv"; 


%LET PROGRAM_ID = 5295;
%LET TASK_ID = 57;



%let schema = PBATCH;
%let user_s = QCPAP020;
%let db_name= UDBSPRP;

/*%let db_name= ANARPTAD;*/
/**/
/*%let UDBSPRP=ANARPTAD USER=&USER_UDBSPRP PASSWORD=&password_UDBSPRP;*/

LIBNAME hercules DB2 DSN=&UDBSPRP SCHEMA=hercules DEFER=YES;
LIBNAME &schema. DB2 DSN=&UDBSPRP SCHEMA=&schema. DEFER=YES;
LIBNAME &user_s. DB2 DSN=&UDBSPRP SCHEMA=&user_s. DEFER=YES;

*SASDOC--------------------------------------------------------------------------
| Get MAXIMUM GSTP Rule ID
+------------------------------------------------------------------------SASDOC*;


PROC SQL;

SELECT MAX(GSTP_QL_RUL_ID) INTO :MAX_QL
FROM HERCULES.TPMTSK_GSTP_QL_RUL
;

SELECT MAX(GSTP_RECAP_RUL_ID) INTO :MAX_RE
FROM HERCULES.TPMTSK_GSTP_RP_RUL
;

SELECT MAX(GSTP_RXCLM_RUL_ID) INTO :MAX_RX
FROM HERCULES.TPMTSK_GSTP_RX_RUL
;

QUIT;

*SASDOC--------------------------------------------------------------------------
| Read in drug file and insert recrods into temporary drug table
+------------------------------------------------------------------------SASDOC*;
data drug_detail;

infile drg 

dlm=',' 

dsd 

missover

firstobs=2;

input 


DRG_CLS_SEQ_NB        :1.
GSTP_GSA_PGMTYP_CD    :1.
DRG_CLS_EFF_DT        :$10.
DRG_CLS_EXP_DT        :$10.
DRG_CLS_CATG_TX       :$50.
DRG_CLS_CAT_DES_TX    :$200.
GSTP_GRD_FATH_IN      :1.
GSTP_GPI_CD           :$14.
GSTP_GCN_CD           :5.
GSTP_DRG_NDC_ID       :11.
DRG_EFF_DT            :$10.
DRG_EXP_DT            :$10.
DRG_DTW_CD            :1.
GSTP_GPI_NM           :$50.
MULTI_SRC_IN          :1.
RXCLAIM_BYP_STP_IN    :1.
QL_BRND_IN            :1.
DRG_LBL_NM            :$50.

;

if GSTP_GPI_CD = '' then GSTP_GPI_CD = '0';
if GSTP_GCN_CD = . then GSTP_GCN_CD = 0;
if GSTP_DRG_NDC_ID = . then GSTP_DRG_NDC_ID = 0;


run;

proc sort data = drug_detail nodupkey; by DRG_CLS_SEQ_NB GSTP_GSA_PGMTYP_CD GSTP_GPI_CD
GSTP_GCN_CD GSTP_DRG_NDC_ID;
run;


data cst_drug_class (keep = DRG_CLS_SEQ_NB GSTP_GSA_PGMTYP_CD DRG_CLS_EFF_DT DRG_CLS_EXP_DT 
DRG_CLS_CATG_TX DRG_CLS_CAT_DES_TX  GSTP_GRD_FATH_IN);
set drug_detail;
run;


proc sort data = cst_drug_class nodupkey; by DRG_CLS_SEQ_NB GSTP_GSA_PGMTYP_CD;
run;


%DROP_DB2_TABLE(db_name=&db_name.,TBL_NAME=&USER_S..GSTP_CST_DRG); 

	PROC SQL;
	 CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	
	    EXECUTE(CREATE TABLE &USER_S..GSTP_CST_DRG
	( 	GSTP_GSA_PGMTYP_CD	SMALLINT NOT NULL,
	DRG_CLS_SEQ_NB		SMALLINT NOT NULL,
	DRG_CLS_EFF_DT          DATE NOT NULL,
	GSTP_GPI_CD             CHAR(14) NOT NULL,
	GSTP_GCN_CD             INTEGER  NOT NULL,
	GSTP_DRG_NDC_ID         DECIMAL(11) NOT NULL,
	DRG_EFF_DT              DATE NOT NULL,
	DRG_CLS_EXP_DT          DATE NOT NULL,
	DRG_EXP_DT              DATE NOT NULL,
	DRG_DTW_CD              SMALLINT,
	GSTP_GPI_NM             VARCHAR(50),
	MULTI_SRC_IN            SMALLINT,
	RXCLAIM_BYP_STP_IN      SMALLINT,
	QL_BRND_IN              SMALLINT,
	DRG_LABEL_NM            VARCHAR(50),
	HSC_USR_ID              CHAR(8),
	HSC_TS                  TIMESTAMP WITH DEFAULT CURRENT TIMESTAMP,
	HSU_USR_ID              CHAR(8),
	HSU_TS                  TIMESTAMP WITH DEFAULT CURRENT TIMESTAMP,
	PRIMARY KEY (GSTP_GSA_PGMTYP_CD, DRG_CLS_SEQ_NB, DRG_CLS_EFF_DT, GSTP_GPI_CD, GSTP_GCN_CD, GSTP_DRG_NDC_ID)
	)	 NOT LOGGED INITIALLY) BY DB2;

	 DISCONNECT FROM DB2;
	QUIT;


			      proc sql
       ;

           insert into &USER_S..GSTP_CST_DRG
		   ( 
GSTP_GSA_PGMTYP_CD
,DRG_CLS_SEQ_NB
,DRG_CLS_EFF_DT
,GSTP_GPI_CD
,GSTP_GCN_CD
,GSTP_DRG_NDC_ID
,DRG_EFF_DT
,DRG_CLS_EXP_DT
,DRG_EXP_DT
,DRG_DTW_CD
,GSTP_GPI_NM
,MULTI_SRC_IN
,RXCLAIM_BYP_STP_IN
,QL_BRND_IN
,DRG_LABEL_NM
,HSC_USR_ID
,HSU_USR_ID

	
			 )

            
               select GSTP_GSA_PGMTYP_CD
,DRG_CLS_SEQ_NB
,input(DRG_CLS_EFF_DT,mmddyy10.)
,GSTP_GPI_CD
,GSTP_GCN_CD
,GSTP_DRG_NDC_ID
,input(DRG_EFF_DT,mmddyy10.)
,input(DRG_CLS_EXP_DT,mmddyy10.)
,input(DRG_EXP_DT,mmddyy10.)
,DRG_DTW_CD
,GSTP_GPI_NM
,MULTI_SRC_IN
,RXCLAIM_BYP_STP_IN
,QL_BRND_IN
,DRG_LBL_NM
,'QCPAP020'
,'QCPAP020'
		
      			  
      
                 from DRUG_DETAIL;                      
			quit;

*SASDOC--------------------------------------------------------------------------
| Read In client files from all platforms
+------------------------------------------------------------------------SASDOC*;
data ql_file;

infile qlfile 

dlm=',' 

dsd 

missover

firstobs=2;

input 

PROGRAM_ID                 :4.
TASK_ID                    :2.
CLIENT_ID                  :5.
GROUP_CLS_CD             :9.
GROUP_CLS_SEQ_NB         :9.
BLG_REPORTING_CD           :$15.
PLAN_NM                    :$40.
PLAN_CD_TX                 :$8.
PLAN_EXT_CD_TX             :$8.
GROUP_CD_TX                :$15.
GROUP_EXT_CD_TX            :$5.
EFFECTIVE_DT               :$10.
EXPIRATION_DT              :$10.
CLT_SETUP_DEF_CD           :1.
GSTP_GSA_PGMTYP_CD        :1.
OVR_CLIENT_NM              :$100.
DRUG_CLASS_1_IN            :1.
DRUG_CLASS_2_IN            :1.
DRUG_CLASS_3_IN            :1.
DRUG_CLASS_4_IN            :1.
DRUG_CLASS_5_IN            :1.
DRUG_CLASS_6_IN            :1.
DRUG_CLASS_7_IN            :1.
DRUG_CLASS_8_IN            :1.
DRUG_CLASS_9_IN            :1.
DRUG_CLASS_10_IN           :1.
DRUG_CLASS_11_IN           :1.
DRUG_CLASS_12_IN           :1.
DRUG_CLASS_13_IN           :1.
DRUG_CLASS_14_IN           :1.
;

IF GROUP_CLS_CD = . THEN GROUP_CLS_CD = 0;
IF GROUP_CLS_SEQ_NB = . THEN GROUP_CLS_SEQ_NB = 0;
run;


data re_file;

infile refile 

dlm=',' 

dsd 

missover

firstobs=2;

input 

PROGRAM_ID                 :4.
TASK_ID                    :2.
INSURANCE_CD               :$3.
CARRIER_ID                 :$20.
GROUP_CD                   :$15.
EFFECTIVE_DT               :$10.
EXPIRATION_DT              :$10.
CLT_SETUP_DEF_CD           :1.
GSTP_GSA_PGMTYP_CD        :1.
OVR_CLIENT_NM              :$100.
DRUG_CLASS_1_IN            :1.
DRUG_CLASS_2_IN            :1.
DRUG_CLASS_3_IN            :1.
DRUG_CLASS_4_IN            :1.
DRUG_CLASS_5_IN            :1.
DRUG_CLASS_6_IN            :1.
DRUG_CLASS_7_IN            :1.
DRUG_CLASS_8_IN            :1.
DRUG_CLASS_9_IN            :1.
DRUG_CLASS_10_IN           :1.
DRUG_CLASS_11_IN           :1.
DRUG_CLASS_12_IN           :1.
DRUG_CLASS_13_IN           :1.
DRUG_CLASS_14_IN           :1.
;


run;

data rx_file;

infile rxfile 

dlm=',' 

dsd 

missover

firstobs=2;

input 

PROGRAM_ID                 :4.
TASK_ID                    :2.
CARRIER_ID                 :$20.
ACCOUNT_ID                 :$20.
GROUP_CD                   :$15.
EFFECTIVE_DT               :$10.
EXPIRATION_DT              :$10.
CLT_SETUP_DEF_CD           :1.
GSTP_GSA_PGMTYP_CD        :1.
OVR_CLIENT_NM              :$100.
DRUG_CLASS_1_IN            :1.
DRUG_CLASS_2_IN            :1.
DRUG_CLASS_3_IN            :1.
DRUG_CLASS_4_IN            :1.
DRUG_CLASS_5_IN            :1.
DRUG_CLASS_6_IN            :1.
DRUG_CLASS_7_IN            :1.
DRUG_CLASS_8_IN            :1.
DRUG_CLASS_9_IN            :1.
DRUG_CLASS_10_IN           :1.
DRUG_CLASS_11_IN           :1.
DRUG_CLASS_12_IN           :1.
DRUG_CLASS_13_IN           :1.
DRUG_CLASS_14_IN           :1.
;
run;

/**/
/*	%DROP_DB2_TABLE(TBL_NAME=QCPAP020.GSTP_COPY_OVER_QL_TEMP); */
/*	%DROP_DB2_TABLE(TBL_NAME=QCPAP020.GSTP_COPY_OVER_RX_TEMP); */
/*	%DROP_DB2_TABLE(TBL_NAME=QCPAP020.GSTP_COPY_OVER_RE_TEMP);*/

*SASDOC--------------------------------------------------------------------------
| Create a separate record for each drug class for all platforms
+------------------------------------------------------------------------SASDOC*;

%macro drg_cls_loop;
%DO I=1 %TO 14;
IF DRUG_CLASS_&I._IN = 1 THEN DO;
DRG_CLS_SEQ_NB = %eval(&I.);
OUTPUT;
END;
%END;
%MEND;




%macro merge_drg_cls(sys=);

DATA &sys._file_1 (DROP=DRUG_CLASS_1_IN DRUG_CLASS_2_IN DRUG_CLASS_3_IN DRUG_CLASS_4_IN DRUG_CLASS_5_IN
                   DRUG_CLASS_6_IN DRUG_CLASS_7_IN DRUG_CLASS_8_IN DRUG_CLASS_9_IN DRUG_CLASS_10_IN
                   DRUG_CLASS_11_IN DRUG_CLASS_12_IN DRUG_CLASS_13_IN DRUG_CLASS_14_IN) ;
SET &sys._file;

%drg_cls_loop;
RUN;

PROC SORT DATA =&sys._FILE_1; BY GSTP_GSA_PGMTYP_CD DRG_CLS_SEQ_NB;
		RUN;



DATA &sys._DRG_CLS;
		MERGE &sys._FILE_1 (IN=A)
			  CST_DRUG_CLASS (IN=B)
			  ;
BY GSTP_GSA_PGMTYP_CD DRG_CLS_SEQ_NB;
IF A=1 AND B=1 THEN OUTPUT;
RUN;

DATA &sys._DRG_CLS;
SET &sys._DRG_CLS;
RULE_ID = _N_ + &&MAX_&sys.;
RUN;

%mend;

%merge_drg_cls(SYS=QL);
%merge_drg_cls(SYS=RE);
%merge_drg_cls(SYS=RX);



*SASDOC--------------------------------------------------------------------------
| Insert records into HERCULES.TPGMTASK_*_RUL tables
+------------------------------------------------------------------------SASDOC*;


    PROC SQL;
	INSERT INTO HERCULES.TPGMTASK_QL_RUL
	( PROGRAM_ID
	,TASK_ID
	,CLIENT_ID
	,GROUP_CLASS_CD
	,GROUP_CLASS_SEQ_NB
	,BLG_REPORTING_CD
	,PLAN_NM
	,PLAN_CD_TX
	,PLAN_EXT_CD_TX
	,GROUP_CD_TX
	,GROUP_EXT_CD_TX
	,EFFECTIVE_DT
	,GSTP_GSA_PGMTYP_CD
	,EXPIRATION_DT
	,HSC_USR_ID
	,HSU_USR_ID
	,CLT_SETUP_DEF_CD
	,OVR_CLIENT_NM

	)  SELECT 
	PROGRAM_ID
	,TASK_ID
	,CLIENT_ID
	,GROUP_CLS_CD
	,GROUP_CLS_SEQ_NB
	,BLG_REPORTING_CD
	,PLAN_NM
	,PLAN_CD_TX
	,PLAN_EXT_CD_TX
	,GROUP_CD_TX
	,GROUP_EXT_CD_TX
	,INPUT(EFFECTIVE_DT,MMDDYY10.)
	,GSTP_GSA_PGMTYP_CD
	,INPUT(EXPIRATION_DT,MMDDYY10.)
	,'QCPAP020'
	,'QCPAP020'
	,CLT_SETUP_DEF_CD
	,OVR_CLIENT_NM

	FROM QL_FILE;
				QUIT;
				RUN;


				   PROC SQL;
	INSERT INTO HERCULES.TPGMTASK_RECAP_RUL
	( PROGRAM_ID
	,TASK_ID
	,INSURANCE_CD
	,CARRIER_ID
	,GROUP_CD
	,EFFECTIVE_DT
	,GSTP_GSA_PGMTYP_CD
	,EXPIRATION_DT
	,HSC_USR_ID
	,HSU_USR_ID
	,CLT_SETUP_DEF_CD
	,OVR_CLIENT_NM

	)  SELECT 
	PROGRAM_ID
	,TASK_ID
	,INSURANCE_CD
	,CARRIER_ID
	,GROUP_CD
	,INPUT(EFFECTIVE_DT,MMDDYY10.)
	,GSTP_GSA_PGMTYP_CD
	,INPUT(EXPIRATION_DT,MMDDYY10.)
	,'QCPAP020'
	,'QCPAP020'
	,CLT_SETUP_DEF_CD
	,OVR_CLIENT_NM

	FROM RE_FILE;
				QUIT;
				RUN;



   PROC SQL;
	INSERT INTO HERCULES.TPGMTASK_RXCLM_RUL
	( PROGRAM_ID
	,TASK_ID
	,CARRIER_ID
	,ACCOUNT_ID
	,GROUP_CD
	,EFFECTIVE_DT
	,GSTP_GSA_PGMTYP_CD
	,EXPIRATION_DT
	,HSC_USR_ID
	,HSU_USR_ID
	,CLT_SETUP_DEF_CD
	,OVR_CLIENT_NM

	)  SELECT 
	PROGRAM_ID
	,TASK_ID
	,CARRIER_ID
	,ACCOUNT_ID
	,GROUP_CD
	,INPUT(EFFECTIVE_DT,MMDDYY10.)
	,GSTP_GSA_PGMTYP_CD
	,INPUT(EXPIRATION_DT,MMDDYY10.)
	,'QCPAP020'
	,'QCPAP020'
	,CLT_SETUP_DEF_CD
	,OVR_CLIENT_NM

	FROM RX_FILE;
				QUIT;
				RUN;

*SASDOC--------------------------------------------------------------------------
| Insert records into HERCULES.TPMTSK_GSTP_*_RUL tables
+------------------------------------------------------------------------SASDOC*;

	%DROP_DB2_TABLE(db_name=&db_name.,TBL_NAME=QCPAP020.GSTP_QL_RUL); 

	%DROP_DB2_TABLE(db_name=&db_name.,TBL_NAME=QCPAP020.GSTP_RX_RUL); 

	%DROP_DB2_TABLE(db_name=&db_name.,TBL_NAME=QCPAP020.GSTP_RP_RUL); 

	PROC SQL;
	 CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	 EXECUTE(CREATE TABLE QCPAP020.GSTP_QL_RUL
(GSTP_QL_RUL_ID INTEGER NOT NULL, 		
 PROGRAM_ID INTEGER,
 TASK_ID INTEGER,
 CLIENT_ID INTEGER,
 GROUP_CLS_CD SMALLINT,
 GROUP_CLS_SEQ_NB SMALLINT,
 BLG_REPORTING_CD CHAR(15) NOT NULL WITH DEFAULT '',
 PLAN_NM CHAR(40) NOT NULL WITH DEFAULT '',
 PLAN_CD_TX CHAR(8) NOT NULL WITH DEFAULT '',
 PLAN_EXT_CD_TX CHAR(8) NOT NULL WITH DEFAULT '',
 GROUP_CD_TX CHAR(15) NOT NULL WITH DEFAULT '',
 GROUP_EXT_CD_TX CHAR(5) NOT NULL WITH DEFAULT '',
 DRG_CLS_SEQ_NB		SMALLINT NOT NULL, 
 DRG_CLS_CATG_TX		CHAR(50),
 DRG_CLS_CAT_DES_TX	CHAR(50),
 GSTP_GSA_PGMTYP_CD	SMALLINT NOT NULL,
 GSTP_GRD_FATH_IN        SMALLINT,	
 CLT_EFF_DT              DATE,
 DRG_CLS_EFF_DT          DATE,
 DRG_CLS_EXP_DT          DATE,
 HSC_USR_ID              CHAR(8),
 HSC_TS                  TIMESTAMP WITH DEFAULT CURRENT TIMESTAMP,
 HSU_USR_ID              CHAR(8),
 HSU_TS                  TIMESTAMP WITH DEFAULT CURRENT TIMESTAMP
) NOT LOGGED INITIALLY) BY DB2;
	 DISCONNECT FROM DB2;
	QUIT;


		PROC SQL;
	 CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	 EXECUTE(CREATE TABLE QCPAP020.GSTP_RP_RUL
(GSTP_RECAP_RUL_ID INTEGER NOT NULL, 		
 PROGRAM_ID INTEGER,
 TASK_ID INTEGER,
 INSURANCE_CD CHAR(3) NOT NULL WITH DEFAULT '',
 CARRIER_ID   CHAR(20) NOT NULL WITH DEFAULT '',
 GROUP_CD     CHAR(15) NOT NULL WITH DEFAULT '',
 DRG_CLS_SEQ_NB		SMALLINT NOT NULL, 
 DRG_CLS_CATG_TX		CHAR(50),
 DRG_CLS_CAT_DES_TX	CHAR(50),
 GSTP_GSA_PGMTYP_CD	SMALLINT NOT NULL,
 GSTP_GRD_FATH_IN        SMALLINT,	
 CLT_EFF_DT              DATE,
 DRG_CLS_EFF_DT          DATE,
 DRG_CLS_EXP_DT          DATE,
 HSC_USR_ID              CHAR(8),
 HSC_TS                  TIMESTAMP WITH DEFAULT CURRENT TIMESTAMP,
 HSU_USR_ID              CHAR(8),
 HSU_TS                  TIMESTAMP WITH DEFAULT CURRENT TIMESTAMP
) NOT LOGGED INITIALLY) BY DB2;
	 DISCONNECT FROM DB2;
	QUIT;


		PROC SQL;
	 CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	 EXECUTE(CREATE TABLE QCPAP020.GSTP_RX_RUL
(GSTP_RXCLM_RUL_ID INTEGER NOT NULL, 		
 PROGRAM_ID INTEGER,
 TASK_ID INTEGER,
 CARRIER_ID   CHAR(20) NOT NULL WITH DEFAULT '',
 ACCOUNT_ID   CHAR(20) NOT NULL WITH DEFAULT '',
 GROUP_CD     CHAR(15) NOT NULL WITH DEFAULT '',
 DRG_CLS_SEQ_NB		SMALLINT NOT NULL, 
 DRG_CLS_CATG_TX		CHAR(50),
 DRG_CLS_CAT_DES_TX	CHAR(50),
 GSTP_GSA_PGMTYP_CD	SMALLINT NOT NULL,
 GSTP_GRD_FATH_IN        SMALLINT,	
 CLT_EFF_DT              DATE,
 DRG_CLS_EFF_DT          DATE,
 DRG_CLS_EXP_DT          DATE,
 HSC_USR_ID              CHAR(8),
 HSC_TS                  TIMESTAMP WITH DEFAULT CURRENT TIMESTAMP,
 HSU_USR_ID              CHAR(8),
 HSU_TS                  TIMESTAMP WITH DEFAULT CURRENT TIMESTAMP
) NOT LOGGED INITIALLY) BY DB2;
	 DISCONNECT FROM DB2;
	QUIT;

	


	PROC SQL;
INSERT INTO QCPAP020.GSTP_QL_RUL
			(
GSTP_QL_RUL_ID
,PROGRAM_ID
,TASK_ID
,CLIENT_ID
,GROUP_CLS_CD
,GROUP_CLS_SEQ_NB
,BLG_REPORTING_CD
,PLAN_NM
,PLAN_CD_TX
,PLAN_EXT_CD_TX
,GROUP_CD_TX
,GROUP_EXT_CD_TX
,DRG_CLS_SEQ_NB
,DRG_CLS_CATG_TX
,DRG_CLS_CAT_DES_TX
,GSTP_GSA_PGMTYP_CD
,CLT_EFF_DT
,DRG_CLS_EFF_DT
,DRG_CLS_EXP_DT
,HSC_USR_ID
,HSU_USR_ID



			)
SELECT  
RULE_ID
,PROGRAM_ID
,TASK_ID
,CLIENT_ID
,GROUP_CLS_CD
,GROUP_CLS_SEQ_NB
,BLG_REPORTING_CD
,PLAN_NM
,PLAN_CD_TX
,PLAN_EXT_CD_TX
,GROUP_CD_TX
,GROUP_EXT_CD_TX
,DRG_CLS_SEQ_NB
,DRG_CLS_CATG_TX
,DRG_CLS_CAT_DES_TX
,GSTP_GSA_PGMTYP_CD
,input(EFFECTIVE_DT,MMDDYY10.)
,input(DRG_CLS_EFF_DT,MMDDYY10.)
,input(DRG_CLS_EXP_DT,MMDDYY10.)
,'QCPAP020'
,'QCPAP020'

FROM QL_DRG_CLS;
QUIT;


	PROC SQL;
	 CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	    EXECUTE(

		INSERT INTO HERCULES.TPMTSK_GSTP_QL_RUL
		SELECT * FROM QCPAP020.GSTP_QL_RUL


		) BY DB2;
	 DISCONNECT FROM DB2;
	QUIT;

PROC SQL;
INSERT INTO QCPAP020.GSTP_RP_RUL
			(
GSTP_RECAP_RUL_ID
,PROGRAM_ID
,TASK_ID
,INSURANCE_CD
,CARRIER_ID
,GROUP_CD
,DRG_CLS_SEQ_NB
,DRG_CLS_CATG_TX
,DRG_CLS_CAT_DES_TX
,GSTP_GSA_PGMTYP_CD
,CLT_EFF_DT
,DRG_CLS_EFF_DT
,DRG_CLS_EXP_DT
,HSC_USR_ID
,HSU_USR_ID


			)
				SELECT  
RULE_ID
,PROGRAM_ID
,TASK_ID
,INSURANCE_CD
,CARRIER_ID
,GROUP_CD
,DRG_CLS_SEQ_NB
,DRG_CLS_CATG_TX
,DRG_CLS_CAT_DES_TX
,GSTP_GSA_PGMTYP_CD
,input(EFFECTIVE_DT,MMDDYY10.)
,input(DRG_CLS_EFF_DT,MMDDYY10.)
,input(DRG_CLS_EXP_DT,MMDDYY10.)
,'QCPAP020'
,'QCPAP020'
FROM RE_DRG_CLS;
QUIT;


	PROC SQL;
	 CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	    EXECUTE(

		INSERT INTO HERCULES.TPMTSK_GSTP_RP_RUL
		SELECT * FROM QCPAP020.GSTP_RP_RUL


		) BY DB2;
	 DISCONNECT FROM DB2;
	QUIT;

PROC SQL;
INSERT INTO QCPAP020.GSTP_RX_RUL
			(
GSTP_RXCLM_RUL_ID
,PROGRAM_ID
,TASK_ID
,CARRIER_ID
,ACCOUNT_ID
,GROUP_CD
,DRG_CLS_SEQ_NB
,DRG_CLS_CATG_TX
,DRG_CLS_CAT_DES_TX
,GSTP_GSA_PGMTYP_CD
,CLT_EFF_DT
,DRG_CLS_EFF_DT
,DRG_CLS_EXP_DT
,HSC_USR_ID
,HSU_USR_ID
	

			)
SELECT  
RULE_ID
,PROGRAM_ID
,TASK_ID
,CARRIER_ID
,ACCOUNT_ID
,GROUP_CD
,DRG_CLS_SEQ_NB
,DRG_CLS_CATG_TX
,DRG_CLS_CAT_DES_TX
,GSTP_GSA_PGMTYP_CD
,input(EFFECTIVE_DT,MMDDYY10.)
,input(DRG_CLS_EFF_DT,MMDDYY10.)
,input(DRG_CLS_EXP_DT,MMDDYY10.)
,'QCPAP020'
,'QCPAP020'
FROM RX_DRG_CLS;
QUIT;
			
	PROC SQL;
	 CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	    EXECUTE(

		INSERT INTO HERCULES.TPMTSK_GSTP_RX_RUL
		SELECT * FROM QCPAP020.GSTP_RX_RUL


		) BY DB2;
	 DISCONNECT FROM DB2;
	QUIT;


*SASDOC--------------------------------------------------------------------------
| Insert recaords into HERCULES.TPMTSK_GSTP_*_DET tables
+------------------------------------------------------------------------SASDOC*;
%macro ins_drg_det(sys=,sys1=);

	PROC SQL;
			INSERT INTO HERCULES.TPMTSK_GSTP_&SYS._DET
			(
					  GSTP_&SYS1._RUL_ID
					, GSTP_GPI_CD
					, GSTP_GCN_CD
					, GSTP_DRG_NDC_ID
					, DRG_EFF_DT
					, DRG_EXP_DT
					, DRG_DTW_CD
					, GSTP_GPI_NM
					, MULTI_SRC_IN
					, RXCLAIM_BYP_STP_IN
					, QL_BRND_IN
					, DRG_LABEL_NM
					, HSC_USR_ID
					, HSU_USR_ID



			)
				SELECT  A.GSTP_&SYS1._RUL_ID
					, B.GSTP_GPI_CD
					, B.GSTP_GCN_CD
					, B.GSTP_DRG_NDC_ID
					, B.DRG_EFF_DT
					, B.DRG_EXP_DT
					, B.DRG_DTW_CD
					, B.GSTP_GPI_NM
					, B.MULTI_SRC_IN
					, B.RXCLAIM_BYP_STP_IN
					, B.QL_BRND_IN
					, B.DRG_LABEL_NM
					,'QCPAP020'
					,'QCPAP020'

				FROM HERCULES.TPMTSK_GSTP_&SYS._RUL   A
                    ,&USER_S..GSTP_CST_DRG    B
               WHERE A.GSTP_GSA_PGMTYP_CD = B.GSTP_GSA_PGMTYP_CD 
                AND  A.DRG_CLS_SEQ_NB     = B.DRG_CLS_SEQ_NB
				AND  A.DRG_CLS_EFF_DT    = B.DRG_CLS_EFF_DT
				AND  A.GSTP_GSA_PGMTYP_CD IN (4)

				AND A.GSTP_&SYS1._RUL_ID NOT IN 

				( SELECT DISTINCT Z.GSTP_&SYS1._RUL_ID
				   FROM HERCULES.TPMTSK_GSTP_&SYS._DET Z
				 )
                   ;
		QUIT;
				RUN;
%mend;

%ins_drg_det(sys=QL,sys1=QL);
%ins_drg_det(sys=RP,sys1=RECAP);
%ins_drg_det(sys=RX,sys1=RXCLM);

*SASDOC--------------------------------------------------------------------------
| Delete temporary tables
+------------------------------------------------------------------------SASDOC*;
%DROP_DB2_TABLE(db_name=&db_name.,TBL_NAME=&USER_S..GSTP_CST_DRG); 
%DROP_DB2_TABLE(db_name=&db_name.,TBL_NAME=QCPAP020.GSTP_QL_RUL); 
%DROP_DB2_TABLE(db_name=&db_name.,TBL_NAME=QCPAP020.GSTP_RX_RUL); 
%DROP_DB2_TABLE(db_name=&db_name.,TBL_NAME=QCPAP020.GSTP_RP_RUL); 
