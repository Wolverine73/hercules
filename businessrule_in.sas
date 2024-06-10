/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Tuesday, March 09, 2004      TIME: 11:13:27 AM
   PROJECT: Project
   PROJECT PATH: 
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Friday, March 05, 2004      TIME: 12:32:05 PM
   PROJECT: Project
   PROJECT PATH: 
---------------------------------------- */
*SASDOC------------------------------------------------------------------------
| PROGRAM:  busruleovrd_in.sas
|
| LOCATION: /PRG/sas%lowcase(&SYSMODE)1/hercules/reports
|
| PURPOSE:  Include file for busruleovrd.sas
|           1) Include the hercules_in file to setup hercules defaults.
|           2) Include the report_in file to setup hercules report defaults.
|           3) Create concatenated formats for use in report.
|           4) Create break space macro.
|           5) Create break line macro.
+----------------------------------------------------------------------SASDOC*;
*SASDOC------------------------------------------------------------------------
| Include hercules_in to define standard environment and common parameters.
+----------------------------------------------------------------------SASDOC*;
* option sysparm='INITIATIVE_ID=3  PHASE_SEQ_NB=1';

%include "/herc%lowcase(&SYSMODE)/prg/hercules/hercules_in.sas";

*SASDOC------------------------------------------------------------------------
| '' is the attribute for missing values of concatenated keys.
+----------------------------------------------------------------------SASDOC*;
option missing='';

*SASDOC------------------------------------------------------------------------
| Include report_in to define standard hercules report environment.
+----------------------------------------------------------------------SASDOC*;
%let RPT_NM=initiative_summary_parms;
%include "/herc%lowcase(&SYSMODE)/prg/hercules/reports/report_in.sas";

*SASDOC------------------------------------------------------------------------
| Create dataset of concatenated keys and lables to be used as cntlin
| dataset for proc format. Formats will be used to decode initiative data.
+----------------------------------------------------------------------SASDOC*;
proc sql noprint;
create table _LOAD_FMT_1 as
select left(A.COLUMN_NM) as COLUMN_NM label='COLUMN_NM',
       B.CMCTN_ENGINE_CD as CMCTN_ENGINE_CD label='CMCTN_ENGINE_CD',
       B.LONG_TX as COLUMN_TX label='COLUMN_TX'
  from &HERCULES..TCODE_COLUMN_XREF A, &HERCULES..TCMCTN_ENGINE_CD B
 where A.CMCTN_ENGN_TYPE_CD eq B.CMCTN_ENGN_TYPE_CD;
quit;

*SASDOC------------------------------------------------------------------------
| Create concatenated formats.
+----------------------------------------------------------------------SASDOC*;
%cr_fmt_vars($_hercf,_LOAD_FMT_1,COLUMN_NM,CMCTN_ENGINE_CD,COLUMN_TX);

*SASDOC------------------------------------------------------------------------
| Drop _temporary tables.
+----------------------------------------------------------------------SASDOC*;
proc sql noprint;
drop table
  _LOAD_FMT_1;
quit;
