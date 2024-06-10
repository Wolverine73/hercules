/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Saturday, January 24, 2004      TIME: 10:47:12 AM
   PROJECT: hercules_macros
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\Hercules\hercules_macros.seg
---------------------------------------- */
*SASDOC------------------------------------------------------------------------
| PROGRAM:  report_in.sas
|
| LOCATION: /PRG/sas%lowcase(&SYSMODE)1/hercules/reports
|
| PURPOSE:  To define a standard environment and common parameters for Hercules
|           reports programs.
|
|           Including:
|           1) Global Macro variables:
|                REPORT_FNT _TBL_FNT _HDR_FG _HDR_BG
|           2) Fileref associated with report output.
|                RPT
|           2) dttime format - used to display date/time in title line.
|
| INPUT:    RPT_NM   report name
|
| OUTPUT:   HERCULES report global macro parameters and setup the environment.
+------------------------------------------------------------------------------
| HISTORY:  12Sep2003 - L.Kummen  - Original
|           30June2010 - N.WILLIAMS - Update run statement to quit.
+-----------------------------------------------------------------------SASDOC*;

*SASDOC------------------------------------------------------------------------
| Assign report/table font, header fore/background macro variables.
+----------------------------------------------------------------------SASDOC*;
%let REPORT_FNT=arial;
%let _TBL_FNT=&REPORT_FNT; /* report font       */
%let _HDR_FG =blue;        /* header foreground */
%let _HDR_BG =lightgrey;   /* header background */

*SASDOC------------------------------------------------------------------------
| Assign program level fileref for report output.
+----------------------------------------------------------------------SASDOC*;
*filename RPT "/REPORTS_DOC/%lowcase(&SYSMODE)1/hercules/general/&RPT_NM..pdf";
* filename RPTFL "/REPORTS_DOC/%lowcase(&SYSMODE)1/hercules/general/&RPT_NM..pdf";
*SASDOC------------------------------------------------------------------------
| Create datetime format.
+----------------------------------------------------------------------SASDOC*;
proc format;
   picture dttime (default=38)
       .=' '
   other='%b %0d, %0Y %0H:%0M' (datatype=datetime);
   picture dt (default=12)
       .=' '
   other='%b %0d, %0Y' (datatype=date);
quit;
