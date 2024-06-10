/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Friday, October 31, 2003      TIME: 04:22:30 PM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Wednesday, October 22, 2003      TIME: 11:27:55 AM
   PROJECT: macros
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Sunday, October 19, 2003      TIME: 02:23:11 PM
   PROJECT: macros
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: 10Oct2001      TIME: 03:08:49 PM
   PROJECT: copay_drug_cov
   PROJECT PATH: /PRG/sasprod1/drug_coverage/copay_drug_cov.seg
---------------------------------------- */
%MACRO set_error_fl2(err_fl_l=,syserr_l=,sqlrc_l=,sqlxrc_l=);
OPTIONS NONOTES;
 %IF &err_fl_l= %THEN %LET err_fl_l=&err_fl;
 %IF &syserr_l= %THEN %LET syserr_l=&syserr;
 %IF &sqlrc_l= %THEN %LET sqlrc_l=&sqlrc;
 %IF &sqlxrc_l= %THEN %LET sqlxrc_l=&sqlxrc;

  DATA _NULL_;
   LENGTH err_fl err_fl_l syserr sqlrc sqlxrc 8;
   err_fl="&err_fl";
   err_fl_l="&err_fl_l"; syserr="&SYSERR_l"; sqlrc="&SQLRC_l"; sqlxrc="&SQLXRC_l";
   
   if sqlrc="4" then sqlrc="0";
   if sqlxrc="4" then sqlxrc="0";
   if syserr="4" then syserr="0";

   IF getoption('obs')=0 THEN err_fl=1;

   err_fl=MAX(0,ABS(err_fl),ABS(err_fl_l), ABS(syserr), ABS(sqlrc),ABS(sqlxrc));
   err_fl=(err_fl >= 1);
   CALL SYMPUT('err_fl',TRIM(LEFT(err_fl)));
  RUN;
  OPTIONS NOTES;
  %PUT 'err_fl'=&err_fl;
%MEND set_error_fl2;
