/*HEADER---------------------------------------------------------------------------------------------------------
|MACRO: COMBINE_ADJ.SAS
|
|PURPOSE:
|                        COMBINE RESULTS FROM ALL PLATFORMS AND GENERATE OUTPUT(TBL_NM_OUT).
|
|INPUT					 TBL_NM_QL(QL DATA SET),TBL_NM_RX(RX DATA SET),TBL_NM_RE(RE DATA SET).
|
|LOGIC:                  COMBINE RESULTS FROM ALL PLATFORMS 
|						 FORMAT FIELDS AS PER HERCULES TABLE(TFIELD_DESCRIPTION).
|						 CREATE TABLE(TBL_NM_OUT).
|						
|						
|PARAMETERS:            GLOBAL MACRO VARIABLES: INITIATIVE_ID, PHASE_SEQ_NB.
|
|OUTPUT			 		PERMANENT DATA SET (TBL_NM_OUT) IS CREATED .
|+-----------------------------------------------------------------------------------------------------------------
| HISTORY: 
|FIRST RELEASE: 		10MAY2008 - K.MITTAPALLI   - Hercules Version  2.1.01
|
|						09MAR2010 - S.BILETSKY - Changed $1. to 1. in the line 
|									NHU_TEMP=INPUT(NHU_TYPE_CD,$1.) per issue with initiatives
+-----------------------------------------------------------------------------------------------------------HEADER*/
%MACRO COMBINE_ADJ(TBL_NM_QL =,TBL_NM_RX =,TBL_NM_RE =,TBL_NM_OUT =);

LIBNAME DATA "/&DATA_DIR";

/*%IF %SYSFUNC(EXIST(&TBL_NM_QL)) %THEN %DO;*/
/*%IF &PROGRAM_ID=72 %THEN %DO;*/
/*   DATA &TBL_NM_QL;*/
/*    SET &TBL_NM_QL;*/
/*    NHU_TEMP=INPUT(NHU_TYPE_CD,$1.);*/
/*    DROP NHU_TYPE_CD;*/
/*    RENAME NHU_TEMP=NHU_TYPE_CD;*/
/*  RUN;*/
/*  %END;*/
/*  %ELSE %DO;*/
/*   DATA &TBL_NM_QL;*/
/*    SET &TBL_NM_QL;*/
/*    NHU_TEMP=INPUT(NHU_TYPE_CD,1.);*/
/*    DROP NHU_TYPE_CD;*/
/*    RENAME NHU_TEMP=NHU_TYPE_CD;*/
/*  RUN;*/
/*  %END;*/
/*%END; */
%IF %SYSFUNC(EXIST(&TBL_NM_QL)) %THEN %DO;

   DATA &TBL_NM_QL;
    SET &TBL_NM_QL;
    NHU_TEMP=INPUT(NHU_TYPE_CD,1.);
    DROP NHU_TYPE_CD;
    RENAME NHU_TEMP=NHU_TYPE_CD;
  RUN;
 
%END; 
DATA UNION_ADJ;
		 SET 
		 %IF %SYSFUNC(EXIST(&TBL_NM_QL)) %THEN %DO;
		 &TBL_NM_QL
		 %END;
		 %IF %SYSFUNC(EXIST(&TBL_NM_RX)) %THEN %DO;
		 &TBL_NM_RX
		 %END;
		 %IF %SYSFUNC(EXIST(&TBL_NM_RE)) %THEN %DO;
		 &TBL_NM_RE
		 %END;
		;
RUN;


*SASDOC -----------------------------------------------------------------------------------------------------------
 | FORMAT THE FIELDS EXISTS ON TFIELD_DESCRIPTION TABLE.
 +----------------------------------------------------------------------------------------------------------SASDOC*;
PROC SQL;
CREATE TABLE VARFMT	AS
SELECT B.FIELD_NM				AS ONE
	  ,B.FORMAT_SAS_TX			AS FMT
  FROM &HERCULES..TFILE_FIELD			A
  	  ,&HERCULES..TFIELD_DESCRIPTION	B
 WHERE	A.FIELD_ID		=	B.FIELD_ID
   AND	A.FILE_ID		= 	99
   AND  A.FILE_SEQ_NB	= 	1
   AND  A.FIELD_ID NOT IN(32,207)
;QUIT;

PROC SORT DATA = VARFMT;
       BY ONE;
RUN;

FILENAME FMTFL "/&DATA_DIR./%LEFT(FORMATS_&TABLE_PREFIX..txt)";                                         
DATA _NULL_;
   SET VARFMT;
   BY ONE;                                
   FILE FMTFL;                                             
   PUT @01 ONE $32. 
       @35 FMT $32. ;            
RUN;   
 
FILENAME FMTFL CLEAR;                
DATA FINAL2;
    FORMAT %INCLUDE "/&DATA_DIR./%LEFT(FORMATS_&TABLE_PREFIX..txt)";    
RUN;

DATA DATA.FINAL_&TABLE_PREFIX.;
   IF _N_ = 1 THEN SET FINAL2;
   SET UNION_ADJ;
   FORMAT PT_BENEFICIARY_ID 8.;
RUN;

*SASDOC -----------------------------------------------------------------------------------------------------------
 | CREATE TABLE WITH  AVAILABLE VARIABLES EXISTS ON TFIELD_DESCRIPTION TABLE.
 +----------------------------------------------------------------------------------------------------------SASDOC*;

%drop_db2_table(tbl_name=&TBL_NM_OUT);
PROC SQL;
  CREATE TABLE &TBL_NM_OUT. AS
    (
    SELECT A.*,
    1 as DRG_GROUP_SEQ_NB
    FROM DATA.FINAL_&TABLE_PREFIX. A);
QUIT;

%MEND COMBINE_ADJ;
