/*HEADER-----------------------------------------------------------------------
| PROGRAM:  sasdoc_in.sas
|
| LOCATION: /PRG/sas%lowcase(&SYSMODE)1/hercules/gen_utilities/sas/
|
| PURPOSE:  Include file for sasdoc.sas
|           1) Create global macro variables.
|           2) Create informat for converting three character month names
|              to integers.
+-----------------------------------------------------------------------------
 | HISTORY:  February 2004 - P. Wonders  - Original
 |           Hercules Version  2.0.1
 |           December 21, 2007 - G. Dudley
 |           Make poratable across all environments
+----------------------------------------------------------------------HEADER*/

/*SASDOC-----------------------------------------------------------------------
| Create global macro variables:
|    SASDOC_START_DIR start directory
|    SASDOC_WEB_DIR   html file directory
|    MIME             file name mime
|    SASDOC           html frame, body, & contents prefix
+----------------------------------------------------------------------SASDOC*/
/**** 12/21/07 G.O.D. changed sasprod to sas&sysmode*/
%let SASDOC_START_DIR=/herc&sysmode/prg/;
/**** 12/21/07 G.O.D. changed sasprod1 to sas&sysmode.1*/
%let SASDOC_WEB_DIR  =/herc&sysmode/report_doc/PUB/sasdoc/;
%let MIME            =sas;
%let PRG_NM          =SASDOC;

/*SASDOC-----------------------------------------------------------------------
| Create informat for converting three character month names to integers.
+----------------------------------------------------------------------SASDOC*/
proc format;
invalue MMM  (upcase just)
   JAN=1 FEB=2 MAR=3 APR=4 MAY=5 JUN=6 JUL=7 AUG=8 SEP=9 OCT=10 NOV=11 DEC=12;

picture dttime (default=38)
    .=' '
other='%b %0d, %0Y %0H:%0M' (datatype=datetime);
run;
