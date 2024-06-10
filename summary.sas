/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Wednesday, May 04, 2005      TIME: 09:39:08 AM
   PROJECT: macros
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\macros.seg
---------------------------------------- */
%MACRO summary(tbl_name_in=,
				tbl_name_sum_out=,
				tbl_name_freq_out=,
				stats_lst=N NMISS NNEG NZERO MIN MAX,
				num_vars=_NUMERIC_,
				char_vars=_CHARACTER_,
				freq_vars=,
			    colvalue_length=$ 32);
/*
 %LET tbl_name_in=RHI.MEM_ELG;
 %LET tbl_name_sum_out=RHIVLDTE.MEM_ELG_SUM;
 %LET tbl_name_freq_out=RHIVLDTE.MEM_ELG_FREQ;

 %LET stats_lst=N NMISS NNEG NZERO MIN MAX; 
 %LET num_vars=_NUMERIC_;
 %LET char_vars=_CHARACTER_;
 %LET freq_vars=FOMULARY_IN NABP_ID;
 %LET colvalue_length=$ 32;
*/


%GLOBAL ERR_CD  MESSAGE DEBUG_FLAG;
%LOCAL datasetnames datasetnames1 _ZERO _tmp_tbl Tbl_name_sh Schema pos
		num_vars_flag colvalue_type means_stat_lst;
%LET err_cd=0;
%LET num_vars_flag=0;
%LET char_vars_flag=0;

%IF &DEBUG_FLAG= %THEN %LET DEBUG_FLAG=N;

  %IF &DEBUG_FLAG=Y %THEN 
					%DO;
					 OPTIONS NOTES;
					 OPTIONS MLOGIC MPRINT SYMBOLGEN SOURCE2;
					%END;
  %ELSE %DO;
  OPTIONS NONOTES ;
  		%END;

 %IF %LENGTH(&tbl_name_in)=0 %THEN %DO; 
				  	%LET err_cd=1; 
					%LET MESSAGE=ERROR: Parameter tbl_name_in is requiered ;
						%END;
%IF &err_cd NE 0 %THEN %GOTO EXIT_S;;

 %LET tbl_name_in=%UPCASE(&tbl_name_in.);
 %LET pos=%INDEX(&tbl_name_in,.);
 %LET Schema=%SUBSTR(&Tbl_name_in,1,%EVAL(&pos-1));
 %LET Tbl_name_sh=%SUBSTR(&Tbl_name_in,%EVAL(&pos+1));

  %LET _tmp_tbl=T%SYSFUNC(INT(%SYSFUNC(DATETIME())));

 %LET colvalue_type=%INDEX(&COLVALUE_LENGTH.,$);
 %IF &colvalue_type.=0 %THEN  	%LET _ZERO=0;
 %ELSE						 	%LET _ZERO='0';;

 %IF %LENGTH(tbl_name_sum_out)=0 %THEN %LET tbl_name_sum_out=&tbl_name_sh._sum;
 
DATA &_tmp_tbl._STATS;
LENGTH _STAT_ $ 32 STAT_NB 3 means_stat_lst $ 300;
ARRAY STATS(*) FORMAT &stats_lst.;
 KEEP  _STAT_ STAT_NB ;
 means_stat_lst='';
  DO I = 1 TO DIM(STATS);
     _STAT_=VNAME(STATS[i]); 
   	 STAT_NB=I;
IF _STAT_ NOT IN ('FORMAT','NNEG', 'NZERO','NPOS') THEN
					DO;
 means_stat_lst=TRIM(means_stat_lst) || ' ' || TRIM(_STAT_) || '=';
					END;
IF I=DIM(STATS) THEN DO;
		CALL SYMPUT('means_stat_lst',TRIM(LEFT(means_stat_lst)));
					END;
   OUTPUT;
  IF  _ERROR_  THEN    DO;
                    CALL SYMPUT('err_cd','1');
                    CALL SYMPUT('Message',SYSMSG());
                      STOP;
                       END;
 END;
 RUN;
 %PUT means_stat_lst=&means_stat_lst.; 

PROC SQL NOPRINT;
 CREATE TABLE &_tmp_tbl._CONT AS
  SELECT TRIM(LIBNAME) || TRIM(MEMNAME) AS TABNAME
  		 ,TRIM(NAME)					AS COLNAME LENGTH=32
		 ,'FORMAT'						AS _STAT_  LENGTH=32 LABEL='_STAT_'
		 ,CASE
		  WHEN FORMAT IS NOT NULL 
			THEN TRIM(FORMAT)
		  WHEN TYPE='CHAR'		  
			THEN 'CHAR' || TRIM(PUT(LENGTH,32.)) || '.'
		  ELSE	  TRIM(PUT(LENGTH,32.)) || '.'	
		 END 							AS COLVALUE
		 ,UPCASE(TYPE) 					AS TYPE	   LENGTH=4	 
    FROM SASHELP.VCOLUMN 
	WHERE LIBNAME="&SCHEMA."
	  AND MEMNAME="&Tbl_name_sh."
	  AND MEMTYPE IN ("DATA","VIEW")
	  ;
QUIT;

PROC SQL NOPRINT;
 SELECT (COUNT(*)>0) INTO :num_vars_flag
  FROM &_tmp_tbl._CONT
  WHERE TYPE='NUM' 
  ;
SELECT (COUNT(*)>0) INTO :char_vars_flag
  FROM &_tmp_tbl._CONT
  WHERE TYPE='CHAR' 
   ;
 QUIT;
  

 %IF &err_cd NE 0 %THEN %GOTO EXIT_S;;

 PROC MEANS DATA=&tbl_name_in. NOPRINT ;
 VAR &num_vars.
 ;
OUTPUT OUT=&_tmp_tbl._SUM(DROP=_TYPE_ _FREQ_) &means_stat_lst./ AUTONAME;
RUN;
QUIT;


%IF &SYSERR NE 0 %THEN %DO; 
				  	%LET err_cd=1;
					%LET MESSAGE=ERROR in PROC MEANS; 
						%END;
%IF &err_cd NE 0 %THEN %GOTO EXIT_S;;

DATA &_tmp_tbl._SUM_L;
   SET &_tmp_tbl._SUM; 
  ARRAY NUMVAR(*) &num_vars.;
 LENGTH COLNAME $ 32  _STAT_ $ 32 COLVALUE &COLVALUE_LENGTH.  VARNAME $ 32  TYPE $ 4;
KEEP COLNAME TYPE  _STAT_  COLVALUE TYPE;

  DO I = 1 TO DIM(NUMVAR); 
      CALL  VNAME(NUMVAR(I),VARNAME);
       pos=INDEX(REVERSE(VARNAME),'_');
 	  _STAT_=UPCASE(REVERSE(SUBSTR(REVERSE(VARNAME),1,pos-1)));
 	   COLNAME=REVERSE(TRIM(SUBSTR(REVERSE(VARNAME),pos+1)));

	IF %INDEX(&COLVALUE_LENGTH.,$)=0 THEN COLVALUE=NUMVAR{I};
	ELSE
					DO;
      IF _STAT_ IN('N','NMISS') 
		THEN  	COLVALUE = PUT(NUMVAR{I},32.);	 
	  ELSE 		COLVALUE = PUTN(NUMVAR{I},VFORMAT(NUMVAR{I}));
	   COLVALUE=RIGHT(COLVALUE); 
					END; 
		TYPE='NUM';
	   OUTPUT;
	  END; 
	  IF  _ERROR_  THEN    DO;
                    CALL SYMPUT('err_cd','1');
                    CALL SYMPUT('Message',SYSMSG());
                      STOP;
                       		END;
RUN;

%IF &err_cd NE 0 %THEN %GOTO EXIT_S;;

PROC FORMAT; 
VALUE SIGN_A
low -<0 = NNEG
0 = NZERO
0<- high = NPOS
 ; 
VALUE $MISSING
' '=NMISS
OTHER=N
 ;
RUN; 
QUIT;

%IF &DEBUG_FLAG=N %THEN %DO; ODS HTML FILE="DUMMY";  %END;

ODS OUTPUT OneWayFreqs(MATCH_ALL=datasetnames)=&_tmp_tbl._C;

PROC FREQ DATA=&tbl_name_in. ;
%IF &char_vars_flag.=1 %THEN %THEN %DO;
 TABLES &char_vars. /MISSING;
 								 %END;
%IF &num_vars_flag.=1 %THEN 		%DO;
TABLES &num_vars. /;
								%END;
;
FORMAT  &char_vars. $MISSING.  &num_vars.  SIGN_A.;
RUN;
QUIT;

%IF &SYSERR NE 0 %THEN %DO; 
				  	%LET err_cd=1;
					%LET MESSAGE=ERROR in PROC FREQ for missing; 
						%END;
%IF &err_cd NE 0 %THEN %GOTO EXIT_S;;

DATA &_tmp_tbl._C_ALL(RENAME=(TABLE=COLNAME));
LENGTH TABLE $ 32  _STAT_ $ 32 COLVALUE &COLVALUE_LENGTH. TYPE $ 4;
  KEEP TABLE  _STAT_ COLVALUE TYPE;
SET &datasetnames.;
ARRAY CHARVAR(*) &char_vars.; 

  DO I = 1 TO DIM(CHARVAR); 
      VARNAME=VNAME(CHARVAR{I}); 
	IF UPCASE(TRIM(VARNAME))='F_' || UPCASE(TRIM(TABLE)) 
    THEN  _STAT_=CHARVAR[I];
  END;
   _STAT_=LEFT(_STAT_);
   COLVALUE=RIGHT(Frequency);
IF _STAT_ IN('N','NMISS') THEN  TYPE='CHAR';
ELSE					  		TYPE='NUM';
   OUTPUT;
IF  _ERROR_  THEN    DO;
                    CALL SYMPUT('err_cd','1');
                    CALL SYMPUT('Message',SYSMSG());
                      STOP;
                       END;
RUN;
%IF &err_cd NE 0 %THEN %GOTO EXIT_S;;

DATA &_tmp_tbl._ALL_L0;
LENGTH TABNAME $ 32;
SET &_tmp_tbl._SUM_L 
	&_tmp_tbl._C_ALL
%IF &colvalue_type.>0 %THEN &_tmp_tbl._CONT;
;
TABNAME="&tbl_name_in";
RUN;

PROC SQL;
 CREATE TABLE &tbl_name_sum_out._L AS
  SELECT  B.TABNAME
		 ,B.COLNAME
		 ,B._STAT_
		 ,CASE
		  WHEN A.COLVALUE IS NULL
			AND(	B._STAT_ IN ('N','NMISS') 
				 OR (B._STAT_ IN ('NNEG','NZERO','NPOS') AND B.TYPE='NUM' )
				)
			THEN &_ZERO.
		  ELSE 							  A.COLVALUE
		 END AS COLVALUE
		 ,B.STAT_NB
		 ,B.TYPE
   FROM 	(SELECT DISTINCT TABNAME,COLNAME,X._STAT_,STAT_NB,TYPE 
				FROM &_tmp_tbl._ALL_L0,&_tmp_tbl._STATS X) B
    LEFT JOIN	&_tmp_tbl._ALL_L0 				 A
	  ON B.TABNAME=A.TABNAME
     AND B.COLNAME=A.COLNAME
	 AND B._STAT_=A._STAT_	
	 ORDER BY B.TABNAME,B.COLNAME, B.STAT_NB
	
	 ;
QUIT;

%IF &SQLRC NE 0 %THEN %DO; 
				  	%LET err_cd=1;
					%LET MESSAGE=ERROR in CREATE TABLE &tbl_name_sum_out._L; 
						%END;
%IF &err_cd NE 0 %THEN %GOTO EXIT_S;;

%PUT MESSAGE=SUMMARY table in the list format &tbl_name_sum_out._L has been successfully created;

PROC TRANSPOSE DATA=&tbl_name_sum_out._L
			    OUT=&tbl_name_sum_out.(DROP=_NAME_);
VAR COLVALUE;
BY TABNAME COLNAME ;
 ID _STAT_;
 RUN;
QUIT;

 %IF &SYSERR NE 0 %THEN %DO; 
				  	%LET err_cd=1;
					%LET MESSAGE=ERROR in PROC TRANSPOSE; 
						%END;
%IF &err_cd NE 0 %THEN %GOTO EXIT_S;;

%PUT MESSAGE=SUMMARY table &tbl_name_sum_out. in the list format has been successfully created;

%IF &DEBUG_FLAG=N %THEN %DO; ODS HTML FILE="DUMMY";  %END;

ODS OUTPUT OneWayFreqs(MATCH_ALL=datasetnames1)=&_tmp_tbl._F;

%IF %LENGTH(&tbl_name_freq_out.)>0 AND %LENGTH(&freq_vars.)>0 %THEN 
									%DO;
PROC FREQ DATA=&tbl_name_in. ;
TABLES &freq_vars. /MISSING;
;
RUN;
QUIT;

%IF &SYSERR NE 0 %THEN %DO; 
				  	%LET err_cd=1;
					%LET MESSAGE=ERROR in PROC FREQ; 
						%END;
DATA &tbl_name_freq_out.(RENAME=(TABLE=COLNAME));
LENGTH TABNAME $ 32 TABLE $ 32 COLVALUE $ 32 TYPE $ 4 VARNAME $ 32;
KEEP TABNAME TABLE  COLVALUE FREQUENCY PERCENT  CUMFREQUENCY CUMPERCENT;

 SET &datasetnames1.;
 ARRAY CHARVAR(*) &char_vars.;
  DO I = 1 TO DIM(CHARVAR); 
      VARNAME=VNAME(CHARVAR{I}); 
	IF UPCASE(TRIM(VARNAME))='F_' || UPCASE(TRIM(TABLE)) 
    THEN  COLVALUE=CHARVAR[I];
  END;
  TABNAME="&tbl_name_in";
  IF  _ERROR_  THEN    DO;
                    CALL SYMPUT('err_cd','1');
                    CALL SYMPUT('Message',SYSMSG());
                      STOP;
                       END;
RUN;

PROC SORT DATA=&tbl_name_freq_out.;
 BY TABNAME COLNAME COLVALUE;
RUN;
											%END;
%IF &err_cd NE 0 %THEN %GOTO EXIT_S;;

%PUT MESSAGE=Frequency table &tbl_name_freq_out. for the variables &freq_vars. has been successfully created;


PROC DATASETS LIB=WORK  NOLIST;
DELETE &_tmp_tbl._STATS &_tmp_tbl._CONT &_tmp_tbl._SUM &_tmp_tbl._SUM_L
		&_tmp_tbl._C_ALL &_tmp_tbl._ALL_L0 
 &datasetnames &datasetnames1.
 ;
RUN;
QUIT;

/*
Code examples for generating reports using  summary tables produced by this macro.

PROC REPORT DATA=&tbl_name_sum_out. STYLE(COLUMN)=[JUST=R];
DEFINE COLNAME/ DISPLAY STYLE(COLUMN)=[JUST=L];
TITLE "Summary statistic for table &tbl_name_in.";
RUN;
TITLE;

PROC REPORT DATA=&tbl_name_sum_out._L(DROP=STAT_NB) STYLE(COLUMN)=[JUST=R];
DEFINE COLNAME/ GROUP STYLE(COLUMN)=[JUST=L];
DEFINE _STAT_/ DISPLAY STYLE(COLUMN)=[JUST=R];
TITLE "Summary statistic for table &tbl_name_in. in the list format";
RUN;
TITLE;

PROC REPORT DATA=&tbl_name_freq_out. STYLE(COLUMN)=[JUST=R];
DEFINE COLNAME/ DISPLAY STYLE(COLUMN)=[JUST=L];
 TITLE "Table &tbl_name_in.. Frequency distribution for variables &freq_vars. ";
RUN;
TITLE;

*/

%EXIT_S:

OPTIONS NOTES ;
   %PUT err_cd=&err_cd;
   %IF &err_cd NE 0 %THEN %PUT MESSAGE=&MESSAGE.;;
%MEND;
