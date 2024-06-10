*HEADER------------------------------------------------------------------------
 |
 | PROGRAM:  table_properties.sas
 |
 | LOCATION: /PRG/sas&sysmode.1/hercules/macros
 |
 | PURPOSE:  Manipulate default DB2 table properties 
 |
 |
+-------------------------------------------------------------------------------
 | HISTORY:  Hercules Version  2.0.1
 |           December 21, 2007 - G. Dudley
 |           Make poratable across all environments
 |           Add header box
 |          
+-----------------------------------------------------------------------HEADER*/;
%MACRO table_properties(db_name=&UDBSPRP_DB, tbl_name=, print=PRINT, sort_order=colno,
						del=' ',syscat=SYSCAT,Engine=DB2,user=,password=);

 %GLOBAL _OWNER _TABLE_TYPE _ROWS_COUNT _RECORD_LENGTH _BYTES _CREATE_TIME _STATS_TIME
         _PRIMARY_KEY _COLUMN_NAMES;
options symbolgen mprint mlogic;
OPTIONS NONOTES;
OPTIONS MISSING='';
%LOCAL N TYPE pos Schema Tbl_name_sh;

%LET N=0;
%LET TYPE=T;
%LET _TABLE_TYPE=&TYPE;
%LET _OWNER=; %LET _ROWS_COUNT=; %LET _RECORD_LENGTH=; %LET _BYTES=0;
%LET _CREATE_TIME=; %LET _STATS_TIME=; %LET _PRIMARY_KEY=; 
%LET _COLUMN_NAMES=;

 %LET pos=%INDEX(&Tbl_name,.);
 %LET Schema=%SUBSTR(&Tbl_name,1,%EVAL(&pos-1));
 %LET Tbl_name_sh=%SUBSTR(&Tbl_name,%EVAL(&pos+1));

 
 %IF (&db_name =UDBSPRP OR &db_name =ANARPT OR &db_name =ANARPTAD OR &db_name =ANARPTQA)
	AND &user= AND &password= AND &user_UDBSPRP NE AND 
  &password_UDBSPRP NE  AND &password_UDBSPRP NE DUMMY
  %THEN
		%DO;

	  %LET user=&user_UDBSPRP;
	  %LET password=&password_UDBSPRP;

		%END; 

 %IF &user     NE %THEN %LET user=%STR(USER=&user);
 %IF &password NE %THEN %LET password=%STR(PASSWORD=&password);

 LIBNAME _SCHEMA DB2 DSN=&db_name &user &password SCHEMA=%UPCASE(&Schema) DEFER=YES;

%IF &Engine NE SAS %THEN 
						%DO;
 LIBNAME _SYSCAT &Engine DSN=&db_name SCHEMA=%UPCASE(&syscat) &user &password;
						 %END;
 PROC SQL NOPRINT;
 SELECT BASE_TABSCHEMA,BASE_TABNAME,TYPE INTO :BASE_TABSCHEMA, :BASE_TABNAME, :TYPE
   FROM _SYSCAT.TABLES 
  	WHERE TABSCHEMA IN ("&schema")  
  	  AND TABNAME   IN ("&tbl_name_sh")
	  ;
QUIT;

%LET _TABLE_TYPE=&TYPE;

%DO %UNTIL(&TYPE. NE A);

%IF &TYPE.=A  %THEN 
					%DO;
         %LET schema=&BASE_TABSCHEMA.;
		 %LET tbl_name_sh=&BASE_TABNAME;
					%END;

 PROC SQL NOPRINT;
 SELECT BASE_TABSCHEMA,BASE_TABNAME,TYPE INTO :BASE_TABSCHEMA, :BASE_TABNAME, :TYPE
   FROM _SYSCAT.TABLES 
  	WHERE TABSCHEMA IN ("&schema")  
  	  AND TABNAME   IN ("&tbl_name_sh")
	  ;
QUIT;
%END;
PROC SQL &PRINT;
TITLE "Main properties of the table &tbl_name";
 SELECT DISTINCT 
	 TABLES.DEFINER AS OWNER FORMAT=$128. LABEL='OWNER',
	 "&_TABLE_TYPE"		AS TYPE				  LABEL='TYPE',
	 TABLES.CARD AS NROWS AS ROWS_COUNT LABEL='ROWS COUNT' FORMAT=20.,
     SUM(COLUMNS.LENGTH) AS RECORD_LENGTH LABEL='RECORD LENGTH' FORMAT=11.,
	 SUM(COLUMNS.LENGTH)*TABLES.CARD AS BYTES LABEL='BYTES' FORMAT=15.,
	 TABLES.CREATE_TIME FORMAT=DATETIME21.0 LABEL='CREATE TIME',
	 TABLES.STATS_TIME FORMAT=DATETIME21.0	LABEL='STATS TIME'  
     INTO  :_OWNER,:_TABLE_TYPE,:_ROWS_COUNT, :_RECORD_LENGTH, :_BYTES, :_CREATE_TIME, 
           :_STATS_TIME 
FROM _SYSCAT.TABLES AS TABLES, _SYSCAT.COLUMNS AS COLUMNS 
WHERE TABLES.TABSCHEMA IN ("&schema")  
  AND TABLES.TABNAME   IN ("&tbl_name_sh")
  AND TABLES.TABSCHEMA =COLUMNS.TABSCHEMA
  AND TABLES.TABNAME =COLUMNS.TABNAME 
GROUP BY TABLES.TABSCHEMA,TABLES.TABNAME
 ;
QUIT;

PROC SQL NOPRINT;
 SELECT COLNAME INTO :_PRIMARY_KEY SEPARATED BY &DEL 
	FROM   _SYSCAT.COLUMNS AS COLUMNS 
	 WHERE TABSCHEMA IN ("&schema")  
  	   AND TABNAME   IN ("&tbl_name_sh")
  	   AND KEYSEQ IS NOT NULL
 	    ORDER BY KEYSEQ
 ;
QUIT;

PROC SQL &PRINT;
TITLE "Indexes for the table &tbl_name";
SELECT DISTINCT
	 INDEXES.COLNAMES FORMAT=$640.,
	 INDEXES.UNIQUERULE AS UNIQUERULE FORMAT=$1. LABEL='UNIQUE RULE',
	 INDEXES.INDEXTYPE AS INDEXTYPE  LABEL='INDEX TYPE',
	 MAX(CLUSTERRATIO/100.0,CLUSTERFACTOR) AS CLUSTERRATIO FORMAT=PERCENT9. LABEL='PERCENT OF CLUSTERING',
	 INDEXES.INDNAME FORMAT=$18. 
FROM _SYSCAT.INDEXES AS INDEXES 
WHERE INDEXES.TABSCHEMA IN ("&schema")
  AND INDEXES.TABNAME   IN ("&tbl_name_sh") 
 ;
QUIT; 


PROC SQL &PRINT;
TITLE "Permissions for the table &tbl_name";
 SELECT TABAUTH.GRANTOR FORMAT=$128.,
	 TABAUTH.GRANTEE FORMAT=$128.,
	 TABAUTH.CONTROLAUTH FORMAT=$1.,
	 TABAUTH.ALTERAUTH FORMAT=$1.,
	 TABAUTH.DELETEAUTH FORMAT=$1.,
	 TABAUTH.INSERTAUTH FORMAT=$1.,
	 TABAUTH.SELECTAUTH FORMAT=$1.,
	 TABAUTH.UPDATEAUTH FORMAT=$1. 
FROM _SYSCAT.TABAUTH AS TABAUTH 
WHERE TABSCHEMA IN ("&schema")
  AND TABNAME   IN ("&tbl_name_sh") 
;
QUIT;

PROC SQL &PRINT;
TITLE "Columns for the table &tbl_name";
SELECT 
	 COLUMNS.COLNAME FORMAT=$128.,
	 COLUMNS.COLNO FORMAT=6.,
	 COLUMNS.TYPENAME FORMAT=$18.,
	 COLUMNS.LENGTH FORMAT=11.,
	 COLUMNS.NULLS FORMAT=$1. 
FROM _SYSCAT.COLUMNS AS COLUMNS 
WHERE COLUMNS.TABSCHEMA IN ("&schema")
  AND COLUMNS.TABNAME   IN ("&tbl_name_sh")
ORDER BY &sort_order 
;
QUIT;

PROC SQL NOPRINT;
SELECT  COLNAME INTO :_COLUMN_NAMES SEPARATED BY &DEL  
FROM _SYSCAT.COLUMNS AS COLUMNS 
WHERE COLUMNS.TABSCHEMA IN ("&schema")
  AND COLUMNS.TABNAME   IN ("&tbl_name_sh")
ORDER BY &sort_order 
;
QUIT;

LIBNAME _SYSCAT CLEAR;
TITLE;
OPTIONS NOTES;
%IF &_COLUMN_NAMES EQ %THEN	%PUT "Table &tbl_name does not exist";

%PUT STATS_TIME=&_STATS_TIME;
%PUT ROWS_COUNT=&_ROWS_COUNT;
%PUT RECORD_LENGTH=&_RECORD_LENGTH;
%MEND;

						/* Usage examles */
/*
 This macro produce report describing main table properties. In addition,
 it creates the following global macro parameters: _OWNER, _RECORD_COUNT,
 _RECORD_LENGTH, _BYTES, _CREATE_TIMES, _STATS_TIME, _PRIMARY_KEY,
 _COLUMN_NAMES. The list of columns in the parameter _COLUMN_NAMES is 
  separated by blank or some other delimeter, that should be specify. 
 If only macro parameters are needed, one should specify PRINT=NOPRINT
  as shown in the example below. 

  For Zeus database (DSN=UDBSPRP) one must specify only the table name. 
 By default, the columns report is sorted by column 
 number and the macro parameter _COLUMN_NAMES contains list of all columns
 separated them by blanks. To overwrite defaults one need to specify
 corresponding parameters explicitly as in the second example.
*/

/*
  OPTIONS MLOGIC MPRINT SYMBOLGEN;
  OPTIONS NOMLOGIC NOMPRINT NOSYMBOLGEN;

 %table_properties(tbl_name=CLAIMSA.TRXCLM_CLMS_HISEXT);
 %table_properties(tbl_name=CLAIMSA.TDRUG1);
 %table_properties(tbl_name=SUMMARY.TDRUG_COV_LMT_SUMM);
 %table_properties(tbl_name=CLAIMSA.TDRUG1, PRINT=NOPRINT);

 %table_properties(db_name=UDBDWP,tbl_name=CLAIMSP.TDRUG1,user=qcpi514,password=mypass,
                  sort_order=colname,del=',');
*/

/*
%PUT _OWNER=&_OWNER;
%PUT _ROWS_COUNT=&_ROWS_COUNT;
%PUT _RECORD_LENGTH=&_RECORD_LENGTH;
%PUT _BYTES=&_BYTES;
%PUT _CREATE_TIME=&_CREATE_TIME;
%PUT _STATS_TIME=&_STATS_TIME;
%PUT _PRIMARY_KEY=&_PRIMARY_KEY;
%PUT _COLUMN_NAMES=&_COLUMN_NAMES;
*/
