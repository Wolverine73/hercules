/* HEADER ----------------------------------------------------------------------
|  PROGRAM:  program_drug_gpi.sas
|
|  LOCATION: /PRG/sas&sysmode.1/hercules/reports/program_drug_gpi.sas
|
|  PURPOSE:
|  This report provides a breakdown of drugs for a specific program to
|  user in PDF format. It also provides inclusionary details about each
|  drug. This report will be accessed through the Java screens.
|
|  LOGIC:
|      1.  Determine the location of the data depending on whether the dataset
|          has been archived.  If the dataset was archived, this means that
|          the data is now located in UDB.
|      2.  In the next phase, this report can be requested from the Java screen.
|          If Java, the request report is sent to the browser.  If the Java
|          "indicator" is false, the report is being requested from a
|          Task-Program and the report is sent to the patientlist network drive
|          When the network drive applies, it is sent to the Program subfolder
|          and the initiative_phase are appended to the title.
|           (e.g. CUSTOM_MAILINGS\reports\12344_Client_Initiative_summary.pdf)
|
|   INPUT:
|         &HERCULES..TPROGRAM_GPI_HIS TGH,
|     &CLAIMSA..TGPITC_GPI_THR_CLS TGT
|
|   OUTPUT:
|   The report is being requested from Java and sent to the browser.
|
|   AUTHOR/DATE: Sayeed Shariff/January 2004.
|
|   MODIFICATIONS:
|
|      1) Added code so that the REPORT_ID will appear in the footer at
|         the bottom of the page.  REPORT_ID is dynamically set if the
|         request is made from the Report Request Screens (QCPI134, J.Chen,
|         7/6/2004)
|------------------------------------------------------------------------HEADER */;

PROC SQL;
   CREATE TABLE PROGRAM_DRUG_GPI AS
        SELECT DISTINCT
                        LEFT(TGH.GPI_CD)   as  GPI_CD,
                        CASE TGH.INCLUDE_IN
                        WHEN 0 THEN 'EXCLUDE'
                        ELSE        'INCLUDE'
                        END  as  STATUS,
                        UPCASE(COMPRESS(TGT.GPI_THERA_CLS_NM,'*'))    as  DRUGCLASS
    FROM        &HERCULES..TPROGRAM_GPI_HIS TGH,
                &CLAIMSA..TGPITC_GPI_THR_CLS TGT
    WHERE       TGH.PROGRAM_ID                  =   &PROGRAM_ID
    AND                 TGT.GPI_THERA_CLS_CD    =
                                substr(left(trim(TGH.GPI_CD)||'00000000000000'),1,14)
        AND                     TGH.EFFECTIVE_DT  <=   date()
    AND                 TGH.EXPIRATION_DT >=  date();

        SELECT      LONG_TX
                INTO            :PROGRAM_NAME
        FROM        claimsa.tPROGRAM
        WHERE       PROGRAM_ID = &PROGRAM_ID;
QUIT;

proc format;
   picture dttime
       .=.
   other='%b %0d, %0Y ' (datatype=datetime);
run;

%macro set_rpt_id;
%global REPORT_ID;
%IF &REPORT_ID = %STR() %THEN %DO;
/* This macro assigns a hard-coded REPORT_ID if the report is
   requested via the Program Maintenance Screen */
%LET REPORT_ID=8;
%END;
%mend;
%set_rpt_id;

*****ONLY FOR TEST******;
*filename RPTFL "/REPORTS_DOC/&sysmode.1/hercules/general/&PROGRAM_ID._program_report.pdf";
*********FOR TEST*******;

%let _hdr_clr=blue;
%let _col_clr=black;
%let _hdr_fg =blue;
%let _hdr_bg =lightgrey;
%let _tbl_fnt="Arial";
options orientation=portrait papersize=letter nodate nonumber pageno=1
                leftmargin  ="0.00"
        rightmargin ="0.00"
        topmargin   ="0.75in"
        bottommargin="0.25in";
ods listing close;
ods pdf file=RPTFL
        startpage=off
        style=my_pdf
                notoc;
ods escapechar "^";
title1 j=c "^S={font_face=arial
                font_size=12pt
                font_weight=bold}Hercules Communication Engine^S={}";
title2 j=c "^S={font_face=arial
                font_size=14pt
                font_weight=bold}%TRIM(&PROGRAM_NAME)^S={}";
title3 j=c "^S={font_face=arial
                font_size=10pt
                font_weight=bold}Therapeutic Drug Class^S={}";
title4 j=c "^S={font_face=arial
                font_size=9pt
                font_weight=bold}%sysfunc(datetime(),dttime.)^S={}";
title5 " ";
title6 j=l "^S={font_face=arial
                font_size=9pt
                font_weight=bold}%str(All drugs with the First Databank maintenance indicators are included unless an EXCLUDE applies below.)^S={}";
footnote1 j=r "^S={font_face=arial
                font_size=7pt
                font_weight=bold}Caremark IT Analytics^S={}";
footnote2 j=r "^S={font_face=arial
                font_size=7pt
                font_weight=bold}Report Generated: %sysfunc(datetime(),datetime19.)^S={}";
footnote3 j=r "^S={font_face=arial
                font_size=7pt
                font_weight=bold}Report ID: &REPORT_ID ^S={}";


*SASDOC--------------------------------------------------------------------------
| This prints the report in PDF format.
+------------------------------------------------------------------------SASDOC*;
proc report
   data=WORK.PROGRAM_DRUG_GPI
   missing
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =c
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_face=arial
                  font_size   =9pt
                  font_face   =&_tbl_fnt];

column
        GPI_CD
                DRUGCLASS
                STATUS;

define GPI_CD  / display
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}GPI^S={}"
   style=[just     =r];


define DRUGCLASS  / display
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Therapeutic Drug Class^S={}"
   style=[just     =l];


define STATUS  / display
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}STATUS^S={}"
   style=[just     =l];

run;
quit;

ods pdf close;


PROC SQL;
        DROP TABLE
                WORK.PROGRAM_DRUG_GPI;
QUIT;
