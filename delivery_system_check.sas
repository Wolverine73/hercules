/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Friday, September 19, 2003      TIME: 07:50:23 PM
   PROJECT: hercules_macros
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\Hercules\hercules_macros.seg
---------------------------------------- */
/*HEADER
MACRO: delivery_system_check

PURPOSE:
  		This macro excludes ineligible delivery system for each initiative. 

LOGIC: The macro first checks if the output table exist and if yes, it drops and
	   creates and empty table with the same structure as an input table. 
	   It then does a left join between &tbl_name_in and &HERCULE..TDELIVERY_SYS_EXCL
		and excludes records found in the &HERCULE..TDELIVERY_SYS_EXCL. Finally
		the resulting record set is inserted  into the output table.

PARAMETERS:
  			The tbl_name_in is a name of input DB2 table. It must have columns 
			DELIVERY_SYSTEM_CD. The combination of There may be 
			other columns in the table. The parameter HERCULE for HERCULES schema 
			can be also specified but it is optional. If it is not specified then 
			the value of the global macro variable &HERCULES is used. If the later
	        is blank then the parameter defaults to the production schema HERCULES. 

  			The tbl_name_out is a name of output DB2 table. It has the same columns as
			input table and only those delivery systems from the input that were not
			found in the output table.. 
 			
FIRST RELEASE: Yury Vilk, September, 12 2003

USAGE EXAMPLE:

 %delivery_system_check(initiative_id=133,tbl_name_in=QCPI514.TEST_EXCL_DEL_SYS, 
					   tbl_name_out=QCPI514.TEST_EXCL_DEL_SYS2);
%delivery_system_check(initiative_id=&initiative_id,tbl_name_in=QCPI514.TEST_EXCL_DEL_SYS, 
					  tbl_name_out=QCPI514.TEST_EXCL_DEL_SYS3,
					  HERCULE=QCPI514); 	Can be useful in development;
HEADER*/

%MACRO delivery_system_check(initiative_id=,tbl_name_in=, tbl_name_out=,HERCULE=);
%GLOBAL err_fl SYSERR SQLRC SQLXRC SYSDBMSG DEBUG_FLAG;
%GLOBAL HERCULES;

%drop_db2_table(tbl_name=&tbl_name_out);

%IF &DEBUG_FLAG=Y %THEN 
					%DO;
					 OPTIONS NOTES;
					 OPTIONS MLOGIC MPRINT SYMBOLGEN SOURCE2;
					%END;
%ELSE %DO;
  OPTIONS NONOTES ;
  OPTIONS NOMLOGIC NOMPRINT NOSYMBOLGEN NOSOURCE2;
  		%END;
					/* Set default value to the &HERCULE schema */
%IF &HERCULE= %THEN %DO;
          %IF &HERCULES= %THEN %LET HERCULE=HERCULES;
		  %ELSE					%LET HERCULE=&HERCULES;
					 %END;


PROC SQL;
 CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
  EXECUTE (CREATE TABLE &tbl_name_out AS
    (SELECT	 *
              FROM &tbl_name_in) DEFINITION ONLY)
BY DB2;
  EXECUTE (INSERT INTO &tbl_name_out
		 SELECT 			A.* 
                FROM  		&tbl_name_in 	AS A LEFT JOIN  
							&HERCULE..TDELIVERY_SYS_EXCL 	AS B
                            ON A.DELIVERY_SYSTEM_CD = B.DELIVERY_SYSTEM_CD
							AND	B.INITIATIVE_ID=&initiative_id 
				WHERE 		B.DELIVERY_SYSTEM_CD IS NULL
				  
	 )BY DB2;
	;
 DISCONNECT FROM DB2;
 QUIT;
  %IF &SQLXRC=0 %THEN 	%DO;
  			%PUT The Table &tbl_name_out was created succesfuly.;
  						%END;
  %ELSE					%DO;
            %PUT &SYSDBMSG;
			%LET err_fl=1;
  						%END;
%runstats(tbl_name=&tbl_name_out);

%IF &DEBUG_FLAG NE Y %THEN 
					%DO;
 OPTIONS NOMLOGIC NOMPRINT NOSYMBOLGEN;
 					%END;
 OPTIONS NOTES DATE;
%MEND;



