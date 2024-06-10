/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Friday, January 30, 2004      TIME: 03:05:28 PM
   PROJECT: Project
   PROJECT PATH: 
---------------------------------------- */
*HEADER------------------------------------------------------------------------
| PROGRAM:  initiative_results_overview_in.sas
|
| LOCATION: /PRG/sas%lowcase(&SYSMODE)1/hercules/reports
|
| PURPOSE:  Include file for initiative_results_overview.sas
|           1) Include the hercules_in file to setup hercules defaults.
|           2) Create concatenated formats for use in report.
|     
+----------------------------------------------------------------------SASDOC*;

*SASDOC--------------------------------------------------------------------------
|  Create concatenated formats to decode initiative data.
|  Create add_fmt_vars macro to add formatted variables.
+------------------------------------------------------------------------SASDOC*;

LIBNAME &HERCULES DB2 DSN=&UDBSPRP SCHEMA=&HERCULES DEFER=YES;

* Create concatenated formats to decode initiative data.;
proc sql noprint;
** Select columns for concatenated format.;
** Append lookup tables.                  ;
create table _LOAD_FMT_1 as
select left(A.COLUMN_NM) as COLUMN_NM label='COLUMN_NM',
       B.CMCTN_ENGINE_CD as CMCTN_ENGINE_CD label='CMCTN_ENGINE_CD',
       B.LONG_TX as COLUMN_TX label='COLUMN_TX'
  from &HERCULES..TCODE_COLUMN_XREF A, &HERCULES..TCMCTN_ENGINE_CD B
 where A.CMCTN_ENGN_TYPE_CD eq B.CMCTN_ENGN_TYPE_CD
union corr
select 'PROGRAM_ID' as COLUMN_NM,
       PROGRAM_ID as CMCTN_ENGINE_CD,
       LONG_TX as COLUMN_TX
  from &CLAIMSA..TPROGRAM
union corr
select 'TASK_ID' as COLUMN_NM,
       TASK_ID as CMCTN_ENGINE_CD,
       SHORT_TX as COLUMN_TX
  from &HERCULES..TTASK
 order by COLUMN_NM, CMCTN_ENGINE_CD;

** Create macro variables for maximum format length.;
select compress("$"||put(max(length(COLUMN_NM)),8.)||"."),
       compress("Z"||put(length(input(put(max(CMCTN_ENGINE_CD),32.),$32.)),8.)||".")
  into :MAX_COLUMN_NM_LN_FMT, :MAX_CMCTN_ENGINE_CD_LN_FMT
  from _LOAD_FMT_1;

** Create format control-in data.;
create table _LOAD_FMT_2 as
select '$_HERCF' as FMTNAME,
       'C' as TYPE,
       input(COLUMN_NM,&MAX_COLUMN_NM_LN_FMT)||
       put(CMCTN_ENGINE_CD,&MAX_CMCTN_ENGINE_CD_LN_FMT) as START,
       COLUMN_TX as LABEL label='LABEL'
  from _LOAD_FMT_1
 order by START;
quit;

** Assemble concatenated format;
proc format
   cntlin=_LOAD_FMT_2;
** create datetime format;
   picture dttime (default=38)
       .=.
/* other='%A, %B %0d, %0Y %0H:%0M:%0S' (datatype=datetime); */
   other='%b %0d, %0Y %0H:%0M' (datatype=datetime);
run;

** Drop _temporary tables.;
proc sql noprint;
drop table
  _LOAD_FMT_1,
  _LOAD_FMT_2;
*  _CLIENT_SETUP_INCLUSION;
quit;

* Create add_fmt_vars macro to add formatted variables.;
%macro add_fmt_vars(_IN_DSN,_OUT_DSN,_PRFX)/PBUFF;
** Parse arguments to create formatted variables.;
%local _NUM _CUR_VAR;
%let _NUM=4;
%let _CUR_VAR=%scan(&SYSPBUFF,&_NUM,%str(',)'));
   data &_OUT_DSN;
   set &_IN_DSN;
%do %while(%str(&_CUR_VAR) ne %str());
   &_PRFX.&_CUR_VAR=put(input(vname(&_CUR_VAR),&MAX_COLUMN_NM_LN_FMT)||
                        put(&_CUR_VAR,&MAX_CMCTN_ENGINE_CD_LN_FMT),$_hercf.);
   %let _NUM=%eval(&_NUM+1);
   %let _CUR_VAR=%scan(&SYSPBUFF,&_NUM,%str(',)'));
%end;
    run;
%mend add_fmt_vars;
