/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Wednesday, September 22, 2004      TIME: 09:21:46 AM
   PROJECT: macros
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Wednesday, September 17, 2003      TIME: 03:43:27 PM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */
OPTIONS  MPRINT MPRINTNEST MLOGIC MLOGICNEST SYMBOLGEN SOURCE2;
/*%GLOBAL SQLRC SQLXRC;*/
%MACRO reset_sql_err_cd;

%IF DEBUG_FLAG=N %THEN OPTIONS NONOTES;

%IF (&SQLXRC NE 0 AND &SQLXRC GE -1) OR &SQLRC=4 %THEN
					%DO;
				%LET SQLXRC=0;
				%LET SQLRC=0;
				DATA _NULL_;
 PUT 'Resetting &SYSERR to 0 because PROC SQL returned not an error but a warning.';
				RUN;
					%END;
OPTIONS NOTES;
%MEND;
