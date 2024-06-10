/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Saturday, January 24, 2004      TIME: 03:10:32 PM
   PROJECT: hercules_macros
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\Hercules\hercules_macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Tuesday, January 20, 2004      TIME: 11:26:04 AM
   PROJECT: Project
   PROJECT PATH: 
---------------------------------------- */
/*HEADER---------------------------------------------------------------
PROGRAM:
   address_review_reports_in.sas

LOCATION:
   /PRG/sas&sysmode.1/hercules/reports/address_review_reports_in.sas

PURPOSE:
   	This input file is for address_review_reports.sas. Its purpose is
	to set the schemas that will be used within the program.

	The report PDF file is also specified and its location is defined.

	Column Names are also extracted from this file for the source
	program. Hercules_in.sas is also included within this program.

INPUT:
	&HERCULES..TCODE_COLUMN_XREF
	&HERCULES..TCMCTN_ENGINE_CD
	&CLAIMSA..TPROGRAM
	&HERCULES..TTASK
	
	
OUTPUT:
	

AUTHOR/DATE:
   Sayeed Shariff/September 2003.

MODIFICATIONS:

-----------------------------------------------------------------HEADER*/;
/*FOR TEST ONLY*/
*option sysparm='INITIATIVE_ID=20 PHASE_SEQ_NB=1';
*option sysparm='INITIATIVE_ID=20 PHASE_SEQ_NB=1 CMCTN_ROLE_CD=1 DATA_QUALITY_CD=3';	

LIBNAME &HERCULES DB2 DSN=&UDBSPRP SCHEMA=&HERCULES DEFER=YES;	
filename INTSMRPT "/REPORTS_DOC/&sysmode.1/hercules/general/address_review_reports.pdf";

*SASDOC
   Create concatenated formats to decode initiative data.
   Create add_fmt_vars macro to add formatted variables.
*SASDOC;

* Create format for client setup inclusion.;
data _CLIENT_SETUP_INCLUSION;
retain COLUMN_NM 'CLIENT_SETUP_INCLUSION_CD';
input @1 CMCTN_ENGINE_CD @3 COLUMN_TX $char65.;
datalines;
1 Book of Business Mailing. See Clinical Services System for Client Exclusions
0 The following clients will be included in this mailing
;
run;

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
union corr
select COLUMN_NM,
       CMCTN_ENGINE_CD,
       COLUMN_TX
  from _CLIENT_SETUP_INCLUSION
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
  _LOAD_FMT_2,
  _CLIENT_SETUP_INCLUSION;
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
 
