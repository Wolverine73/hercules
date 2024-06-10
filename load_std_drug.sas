%SET_SYSMODE(mode=prod);
OPTIONS SOURCE2 mprint mprintnest mlogic mlogicnest symbolgen MACROGEN;


/*%include "/PRG/sastest1/hercules/macros/drop_db2_table.sas";*/
libname gspt "/herc&sysmode/data/hercules/5295";
*SASDOC--------------------------------------------------------------------------
| INPUT:  Drug File
+------------------------------------------------------------------------SASDOC*;
filename drg    "/herc&sysmode/data/hercules/5295/April0612Drugswithnewclasses_noprereqs.csv"; 


%let program_id = 5295;

%let task_id = 57;

%let schema = HERCULES;
%let user_s = QCPAP020;
%let db_name= UDBSPRP;
/**/
/*%let UDBSPRP=ANARPTAD USER=&USER_UDBSPRP PASSWORD=&password_UDBSPRP;*/

LIBNAME hercules DB2 DSN=&UDBSPRP SCHEMA=hercules DEFER=YES;

LIBNAME &schema. DB2 DSN=&UDBSPRP SCHEMA=&schema. DEFER=YES;

LIBNAME &user_s. DB2 DSN=&UDBSPRP SCHEMA=&user_s. DEFER=YES;

*SASDOC--------------------------------------------------------------------------
| Read in drug file
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


data drug_class (keep = DRG_CLS_SEQ_NB GSTP_GSA_PGMTYP_CD DRG_CLS_EFF_DT DRG_CLS_EXP_DT 
DRG_CLS_CATG_TX DRG_CLS_CAT_DES_TX  GSTP_GRD_FATH_IN);
set drug_detail;
run;


proc sort data = drug_class nodupkey; by DRG_CLS_SEQ_NB GSTP_GSA_PGMTYP_CD;
run;

*SASDOC--------------------------------------------------------------------------
| Read in current GSTP drug classes/ drugs from hercules tables
+------------------------------------------------------------------------SASDOC*;
   		PROC SQL NOPRINT;
	        CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
			CREATE TABLE TBL_DRUG_CLS AS
	        SELECT * FROM CONNECTION TO DB2
	   		(  SELECT  DRG_CLS_SEQ_NB 
			         , GSTP_GSA_PGMTYP_CD
					 , CHAR(DRG_CLS_EFF_DT) AS TBL_DRG_CLS_EFF_DT
					 , CHAR(DRG_CLS_EXP_DT) AS TBL_DRG_CLS_EXP_DT
					 , DRG_CLS_CATG_TX AS TBL_DRG_CLS_CATG_TX
					 , DRG_CLS_CAT_DES_TX AS TBL_DRG_CLS_CAT_DES_TX
					 , GSTP_GRD_FATH_IN AS TBL_GSTP_GRD_FATH_IN

					 FROM &schema..TGSTP_DRG_CLS
				WHERE PROGRAM_ID = &PROGRAM_ID.
				  AND TASK_ID    = &TASK_ID.
				  AND DRG_CLS_EFF_DT <= CURRENT DATE
				  AND DRG_CLS_EXP_DT >= CURRENT DATE
			WITH UR
			  		);
			  
			CREATE TABLE TBL_DRUG AS
	        SELECT * FROM CONNECTION TO DB2
	   		(  SELECT  DRG_CLS_SEQ_NB 
			         , GSTP_GSA_PGMTYP_CD
					 , CHAR(DRG_CLS_EFF_DT) AS TBL_DRG_CLS_EFF_DT
					 , CHAR(DRG_CLS_EXP_DT) AS TBL_DRG_CLS_EXP_DT
					 , GSTP_GPI_CD
					 , GSTP_GCN_CD
					 , GSTP_DRG_NDC_ID
					 , CHAR(DRG_EFF_DT) AS TBL_DRG_EFF_DT
					 , CHAR(DRG_EXP_DT) AS TBL_DRG_EXP_DT
					 , DRG_DTW_CD AS TBL_DRG_DTW_CD
					 , GSTP_GPI_NM AS TBL_GSTP_GPI_NM
					 , MULTI_SRC_IN AS TBL_MULTI_SRC_IN
					 , RXCLAIM_BYP_STP_IN AS TBL_RXCLAIM_BYP_STP_IN
					 , QL_BRND_IN AS TBL_QL_BRN_IN
					 , DRG_LABEL_NM AS TBL_DRG_LABEL_NM


					 FROM &schema..TGSTP_DRG_CLS_DET
				WHERE 
				      DRG_CLS_EFF_DT <= CURRENT DATE
				  AND DRG_CLS_EXP_DT >= CURRENT DATE
				  AND DRG_EFF_DT     <= CURRENT DATE
				  AND DRG_EXP_DT     >= CURRENT DATE
			WITH UR
			  		);
			  
		 	DISCONNECT FROM DB2;

		QUIT;

PROC SORT DATA=TBL_DRUG_CLS NODUPKEY;by DRG_CLS_SEQ_NB GSTP_GSA_PGMTYP_CD;
RUN;


PROC SORT DATA=TBL_DRUG NODUPKEY; by DRG_CLS_SEQ_NB GSTP_GSA_PGMTYP_CD GSTP_GPI_CD
GSTP_GCN_CD GSTP_DRG_NDC_ID;
RUN;

*SASDOC--------------------------------------------------------------------------
| Compare table and file DRUG CLASS records and create insert and update records
+------------------------------------------------------------------------SASDOC*;
DATA DRG_CLS_UPDT (KEEP=DRG_CLS_SEQ_NB GSTP_GSA_PGMTYP_CD TBL_DRG_CLS_EFF_DT TBL_DRG_CLS_EXP_DT)
     DRG_CLS_INST (KEEP=DRG_CLS_SEQ_NB GSTP_GSA_PGMTYP_CD DRG_CLS_EFF_DT DRG_CLS_EXP_DT
	                    DRG_CLS_CATG_TX DRG_CLS_CAT_DES_TX GSTP_GRD_FATH_IN)
	 ;
MERGE drug_class (IN=FILE)
      TBL_DRUG_CLS (IN=TABLE)
	  ;

	   BY DRG_CLS_SEQ_NB GSTP_GSA_PGMTYP_CD;
IF FILE=1 AND TABLE=1 THEN DO;

DRG_CLS_EFF_DT_NUM= INPUT(DRG_CLS_EFF_DT,MMDDYY10.);
TBL_DRG_CLS_EXP_DT= PUT(DRG_CLS_EFF_DT_NUM - 1,YYMMDD10.);

OUTPUT DRG_CLS_UPDT;
OUTPUT DRG_CLS_INST;
END;

ELSE IF FILE=1 AND TABLE=0 THEN DO;
OUTPUT DRG_CLS_INST;
END;

ELSE IF FILE=0 AND TABLE=1 THEN DO;
TBL_DRG_CLS_EXP_DT=PUT(TODAY()-1,YYMMDD10.);
OUTPUT DRG_CLS_UPDT;
END;

*SASDOC--------------------------------------------------------------------------
| Compare table and file DRUG records and create insert and update records
+------------------------------------------------------------------------SASDOC*;
DATA DRG_UPDT (KEEP=DRG_CLS_SEQ_NB GSTP_GSA_PGMTYP_CD GSTP_GPI_CD GSTP_GCN_CD GSTP_DRG_NDC_ID
                    TBL_DRG_CLS_EFF_DT TBL_DRG_CLS_EXP_DT TBL_DRG_EFF_DT TBL_DRG_EXP_DT)
     DRG_INST (KEEP=DRG_CLS_SEQ_NB GSTP_GSA_PGMTYP_CD GSTP_GPI_CD GSTP_GCN_CD GSTP_DRG_NDC_ID
                    DRG_CLS_EFF_DT DRG_CLS_EXP_DT DRG_EFF_DT DRG_EXP_DT DRG_DTW_CD GSTP_GPI_NM
					MULTI_SRC_IN RXCLAIM_BYP_STP_IN QL_BRND_IN DRG_LBL_NM) 
; 

MERGE drug_detail (IN=FILE)
      TBL_DRUG    (IN=TABLE)
	  ; 
	  BY DRG_CLS_SEQ_NB GSTP_GSA_PGMTYP_CD GSTP_GPI_CD
GSTP_GCN_CD GSTP_DRG_NDC_ID;
IF FILE=1 AND TABLE=1 THEN DO;

DRG_CLS_EFF_DT_NUM= INPUT(DRG_CLS_EFF_DT,MMDDYY10.);
TBL_DRG_CLS_EXP_DT= PUT(DRG_CLS_EFF_DT_NUM - 1,YYMMDD10.);

DRG_EFF_DT_NUM= INPUT(DRG_EFF_DT,MMDDYY10.);
TBL_DRG_EXP_DT= PUT(DRG_EFF_DT_NUM - 1,YYMMDD10.);
   
OUTPUT DRG_UPDT;
OUTPUT DRG_INST;
END;

ELSE IF FILE=1 AND TABLE=0 THEN DO;
OUTPUT DRG_INST;
END;

ELSE IF FILE=0 AND TABLE=1 THEN DO;
TBL_DRG_EXP_DT=PUT(TODAY()-1,YYMMDD10.);
OUTPUT DRG_UPDT;
END;

RUN;

*SASDOC--------------------------------------------------------------------------
| Populate temp tables for DRUG CLASS and DRUG Updates
+------------------------------------------------------------------------SASDOC*;
%DROP_DB2_TABLE(db_name=&db_name.,TBL_NAME=&USER_S..GSTP_STD_DRG_CLS_UPDT); 
%DROP_DB2_TABLE(db_name=&db_name.,TBL_NAME=&USER_S..GSTP_STD_DRG_UPDT); 

	PROC SQL;
	 CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	    EXECUTE(CREATE TABLE &user_s..GSTP_STD_DRG_CLS_UPDT
		(			DRG_CLS_SEQ_NB SMALLINT,
		            GSTP_GSA_PGMTYP_CD SMALLINT,
					DRG_CLS_EFF_DT     DATE,
					DRG_CLS_EXP_DT     DATE


		) NOT LOGGED INITIALLY) BY DB2;

	    EXECUTE(CREATE TABLE &user_s..GSTP_STD_DRG_UPDT
		(			DRG_CLS_SEQ_NB SMALLINT,
		            GSTP_GSA_PGMTYP_CD SMALLINT,
					DRG_CLS_EFF_DT     DATE,
					DRG_CLS_EXP_DT     DATE,
					DRG_EFF_DT     DATE,
					DRG_EXP_DT     DATE,
					GSTP_GPI_CD    CHAR(14),
					GSTP_GCN_CD   INTEGER,
					GSTP_DRG_NDC_ID DECIMAL(11)

		) NOT LOGGED INITIALLY) BY DB2;

	 DISCONNECT FROM DB2;
	QUIT;


	PROC SQL;
	INSERT INTO &user_s..GSTP_STD_DRG_CLS_UPDT
	(				DRG_CLS_SEQ_NB,
		            GSTP_GSA_PGMTYP_CD,
					DRG_CLS_EFF_DT,
					DRG_CLS_EXP_DT 


		)

	SELECT DRG_CLS_SEQ_NB,
		            GSTP_GSA_PGMTYP_CD,
					INPUT(TBL_DRG_CLS_EFF_DT,YYMMDD10.),
					INPUT(TBL_DRG_CLS_EXP_DT,YYMMDD10.) 
	FROM DRG_CLS_UPDT;

	QUIT;

	PROC SQL;
	INSERT INTO &user_s..GSTP_STD_DRG_UPDT
	(				DRG_CLS_SEQ_NB,
		            GSTP_GSA_PGMTYP_CD,
					DRG_CLS_EFF_DT,
					DRG_CLS_EXP_DT,
					DRG_EFF_DT,
					DRG_EXP_DT,
					GSTP_GPI_CD,
					GSTP_GCN_CD,
					GSTP_DRG_NDC_ID


		)

	SELECT 	DRG_CLS_SEQ_NB,
		            GSTP_GSA_PGMTYP_CD,
					INPUT(TBL_DRG_CLS_EFF_DT,YYMMDD10.),
					INPUT(TBL_DRG_CLS_EXP_DT,YYMMDD10.),
					INPUT(TBL_DRG_EFF_DT,YYMMDD10.),
					INPUT(TBL_DRG_EXP_DT,YYMMDD10.),
					GSTP_GPI_CD,
					GSTP_GCN_CD,
					GSTP_DRG_NDC_ID
	FROM DRG_UPDT;

	QUIT;

*SASDOC--------------------------------------------------------------------------
| Perform DRUG CLASS and DRUG Updates
+------------------------------------------------------------------------SASDOC*;

	 PROC SQL;
	  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	  EXECUTE(

  	UPDATE	 &schema..TGSTP_DRG_CLS  A
     SET  DRG_CLS_EXP_DT = ( SELECT B.DRG_CLS_EXP_DT
	                         FROM &user_s..GSTP_STD_DRG_CLS_UPDT B
							 WHERE A.DRG_CLS_SEQ_NB = B.DRG_CLS_SEQ_NB
                              AND  A.GSTP_GSA_PGMTYP_CD = B.GSTP_GSA_PGMTYP_CD
                              AND  A.DRG_CLS_EFF_DT     = B.DRG_CLS_EFF_DT)
        , HSU_TS = CURRENT TIMESTAMP
  	 WHERE 
           EXISTS ( SELECT * FROM &user_s..GSTP_STD_DRG_CLS_UPDT C
	  				 WHERE A.DRG_CLS_SEQ_NB = C.DRG_CLS_SEQ_NB
                              AND  A.GSTP_GSA_PGMTYP_CD = C.GSTP_GSA_PGMTYP_CD
                              AND  A.DRG_CLS_EFF_DT     = C.DRG_CLS_EFF_DT )
               
	 ) BY DB2;
  	QUIT;


	 PROC SQL;
	  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	  EXECUTE(

  	UPDATE	 &schema..TGSTP_DRG_CLS_DET  A
     SET  DRG_CLS_EXP_DT = ( SELECT B.DRG_CLS_EXP_DT
	                         FROM &user_s..GSTP_STD_DRG_CLS_UPDT B
							 WHERE A.DRG_CLS_SEQ_NB = B.DRG_CLS_SEQ_NB
                              AND  A.GSTP_GSA_PGMTYP_CD = B.GSTP_GSA_PGMTYP_CD
                              AND  A.DRG_CLS_EFF_DT     = B.DRG_CLS_EFF_DT)
        , HSU_TS = CURRENT TIMESTAMP
  	 WHERE EXISTS ( SELECT * FROM &user_s..GSTP_STD_DRG_CLS_UPDT C
	  				 WHERE A.DRG_CLS_SEQ_NB = C.DRG_CLS_SEQ_NB
                              AND  A.GSTP_GSA_PGMTYP_CD = C.GSTP_GSA_PGMTYP_CD
                              AND  A.DRG_CLS_EFF_DT     = C.DRG_CLS_EFF_DT
                              AND  C.DRG_CLS_EXP_DT     = CURRENT DATE - 1 DAY)
	 ) BY DB2;
  	QUIT;


		 PROC SQL;
	  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	  EXECUTE(

  	UPDATE	 &schema..TGSTP_DRG_CLS_DET  A
     SET  
	      DRG_CLS_EXP_DT    = ( SELECT B.DRG_CLS_EXP_DT
	                         FROM &user_s..GSTP_STD_DRG_UPDT B
							 WHERE A.DRG_CLS_SEQ_NB = B.DRG_CLS_SEQ_NB
                              AND  A.GSTP_GSA_PGMTYP_CD = B.GSTP_GSA_PGMTYP_CD
							  AND  A.GSTP_GPI_CD        = B.GSTP_GPI_CD
							  AND  A.GSTP_GCN_CD        = B.GSTP_GCN_CD
							  AND  A.GSTP_DRG_NDC_ID    = B.GSTP_DRG_NDC_ID
                              AND  A.DRG_CLS_EFF_DT     = B.DRG_CLS_EFF_DT
                              AND  A.DRG_EFF_DT         = B.DRG_EFF_DT)
		, DRG_EXP_DT    = ( SELECT D.DRG_EXP_DT
	                         FROM &user_s..GSTP_STD_DRG_UPDT D
							 WHERE A.DRG_CLS_SEQ_NB = D.DRG_CLS_SEQ_NB
                              AND  A.GSTP_GSA_PGMTYP_CD = D.GSTP_GSA_PGMTYP_CD
							  AND  A.GSTP_GPI_CD        = D.GSTP_GPI_CD
							  AND  A.GSTP_GCN_CD        = D.GSTP_GCN_CD
							  AND  A.GSTP_DRG_NDC_ID    = D.GSTP_DRG_NDC_ID
                              AND  A.DRG_CLS_EFF_DT     = D.DRG_CLS_EFF_DT
                              AND  A.DRG_EFF_DT         = D.DRG_EFF_DT)
        , HSU_TS = CURRENT TIMESTAMP
  	 WHERE EXISTS ( SELECT * FROM &user_s..GSTP_STD_DRG_UPDT C
	  				 WHERE A.DRG_CLS_SEQ_NB = C.DRG_CLS_SEQ_NB
                              AND  A.GSTP_GSA_PGMTYP_CD = C.GSTP_GSA_PGMTYP_CD
							  AND  A.GSTP_GPI_CD        = C.GSTP_GPI_CD
							  AND  A.GSTP_GCN_CD        = C.GSTP_GCN_CD
							  AND  A.GSTP_DRG_NDC_ID    = C.GSTP_DRG_NDC_ID
                              AND  A.DRG_CLS_EFF_DT     = C.DRG_CLS_EFF_DT
                              AND  A.DRG_EFF_DT         = C.DRG_EFF_DT)
	 ) BY DB2;
	 DISCONNECT FROM DB2;
  	QUIT;
*SASDOC--------------------------------------------------------------------------
| Perform DRUG CLASS and DRUG Inserts
+------------------------------------------------------------------------SASDOC*;
        proc sql
       ;

           insert into &schema..tgstp_drg_cls
		   ( PROGRAM_ID
			 ,TASK_ID
			 ,DRG_CLS_SEQ_NB
			 ,GSTP_GSA_PGMTYP_CD
			 ,DRG_CLS_EFF_DT
			 ,DRG_CLS_EXP_DT
             ,DRG_CLS_CATG_TX
			 ,DRG_CLS_CAT_DES_TX
             ,GSTP_GRD_FATH_IN
			 ,HSC_USR_ID		
			 ,HSU_USR_ID
	
   
			 )

            
               select &PROGRAM_ID.
			 ,&TASK_ID.
			 ,DRG_CLS_SEQ_NB
			 ,GSTP_GSA_PGMTYP_CD
			 ,input(DRG_CLS_EFF_DT,mmddyy10.)
			 ,input(DRG_CLS_EXP_DT,mmddyy10.)
             ,DRG_CLS_CATG_TX
			 ,DRG_CLS_CAT_DES_TX
			 ,GSTP_GRD_FATH_IN
			 ,'QCPAP020'		
			 ,'QCPAP020'

      			  
      
                 from DRG_CLS_INST;                      
			quit;

			      proc sql
       ;

           insert into &schema..tgstp_drg_cls_det
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
		
      			  
      
                 from DRG_INST;                      
			quit;
