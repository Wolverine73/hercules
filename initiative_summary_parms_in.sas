/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Saturday, January 24, 2004      TIME: 10:46:51 AM
   PROJECT: hercules_macros
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\Hercules\hercules_macros.seg
---------------------------------------- */
*SASDOC------------------------------------------------------------------------
| PROGRAM:  initiative_summary_parms_in.sas
|
| LOCATION: /PRG/sas%lowcase(&SYSMODE)1/hercules/reports
|
| PURPOSE:  Include file for initiative_summary_parms_in.sas
|           1) Include the hercules_in file to setup hercules defaults.
|           2) Include the report_in file to setup hercules report defaults.
|           3) Create concatenated formats for use in report.
|           4) Create break space macro.
|           5) Create break line macro.
|
| HISTORY:  
| 26FEB2009 - N. WILLIAMS - Hercules Version  2.1.2.01
|             Added formating for communication code labels F_IBNFT_STS_CMPNT_CD 
|             which is the new communication component for ibenefit.
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
| Create format for client setup inclusion.
+----------------------------------------------------------------------SASDOC*;
data _CLIENT_SETUP_INCLUSION;
infile datalines missover;
input @1 COLUMN_NM $25. @26 CMCTN_ENGINE_CD 3. @30 COLUMN_TX $char80.;
datalines;
CLIENT_SETUP_INCLUSION_CD  1 Book of Business Mailing. See Clinical Services System for Client Exclusions
CLIENT_SETUP_INCLUSION_CD  0 The following clients will be included in this mailing
EXCLUDE_OTC_IN             1 Exclude
EXCLUDE_OTC_IN             0 Include
INCLUDE_IN                 0 Exclude
INCLUDE_IN                 1 Include
SAVINGS_IN                 0 No
SAVINGS_IN                 1 Yes
NUMERATOR_IN               0 No
NUMERATOR_IN               1 Yes
ALL_DRUG_IN                0
ALL_DRUG_IN                1 All Drugs
INCENTIVE_TYPE_CD          1 OPEN
INCENTIVE_TYPE_CD          2 CLOSED
INCENTIVE_TYPE_CD          3 INCENTIVIZED
CLIENT_ID                  . Default
;
run;

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
union corr
select 'FORMULARY_ID' as COLUMN_NM,
       FORMULARY_ID as CMCTN_ENGINE_CD,
       FORMULARY_NM as COLUMN_TX
  from &CLAIMSA..TFORMULARY
 order by COLUMN_NM, CMCTN_ENGINE_CD;
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
  _LOAD_FMT_1,
  _CLIENT_SETUP_INCLUSION;
quit;

*SASDOC------------------------------------------------------------------------
| Create format for communication code labels.
+----------------------------------------------------------------------SASDOC*;
proc format;
value $compf
   F_CLT_STS_CMPNT_CD ='Client Setup'
   F_DRG_STS_CMPNT_CD ='Drug Setup'
   F_PBR_STS_CMPNT_CD ='Setup Prescriber Parameters'
   F_PIT_STS_CMPNT_CD ='Setup Participant Parameters'
   F_FRML_STS_CMPNT_CD='Setup Formulary Parameters'
   F_DOM_STS_CMPNT_CD ='Setup Document'
   F_IBNFT_STS_CMPNT_CD='Setup iBenefits Parameters'
;
value clnt
       .=Default;
value dlvry
   1=Paper
   2=Mail
   3=POS
   other='No Excluded Systems';
run;
