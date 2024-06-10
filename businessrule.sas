/* HEADER ----------------------------------------------------------------------
|  PROGRAM:  businessrule.sas
|
|  LOCATION: /PRG/sas&sysmode.1/hercules/reports/businessrule.sas
|
|  PURPOSE:
|  This report gives all applicable business rules by program and client.
|
|   INPUT:
|               &HERCULES..TCLT_BSRL_OVRD_HIS
|               &CLAIMSA..TCLIENT1
|
|   OUTPUT:
|   The report is being requested from Java and sent to the browser.
|
|   AUTHOR/DATE: Sayeed Shariff/March 9, 2004.
|
|   MODIFICATIONS:
|
|      1) Added code so that the REPORT_ID will appear in the footer at
|         the bottom of the page.  REPORT_ID is dynamically set if the
|         request is made from the Report Request Screens (QCPI134, J.Chen,
|         7/6/2004)
|
|------------------------------------------------------------------------HEADER */;

%set_sysmode(mode=prod);

%include "/herc&sysmode./prg/hercules/reports/businessrule_in.sas";

proc format;
   picture dttime
       .=' '
   other='%b %0d, %0Y ' (datatype=datetime);
run;

PROC SQL noprint;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   CREATE TABLE BUS_RULE_OVRD AS
        SELECT
                        compbl(B.CLIENT_NM||left(' ('||left(put(A.CLIENT_ID,32.)||')')))
                as CLIENT_NM_ID,
                                EFFECTIVE_TS format=dttime.,
                                BUS_RULE_TYPE_CD
        FROM            &HERCULES..TCLT_BSRL_OVRD_HIS A,
                                &CLAIMSA..TCLIENT1 B
        WHERE
                                EFFECTIVE_TS < EXPIRATION_TS
        AND                     EXPIRATION_TS > DATETIME()
        AND                     A.CLIENT_ID = B.CLIENT_ID
        AND                     A.PROGRAM_ID = &PROGRAM_ID
        ORDER BY        B.CLIENT_NM;
DISCONNECT FROM DB2;

        SELECT      LONG_TX
        INTO            :PROGRAM_NAME
    FROM        &CLAIMSA..TPROGRAM
    WHERE       PROGRAM_ID = &PROGRAM_ID;
QUIT;

PROC SQL noprint;
SELECT  COUNT(*)
INTO    :NO_RECORDS
FROM    BUS_RULE_OVRD;
QUIT;
%macro checkbusruleovrd;
%if &no_records = 0 %then %do;
PROC SQL;
INSERT INTO WORK.BUS_RULE_OVRD
VALUES (null, null,  null);
QUIT;
%end;
%mend;

%checkbusruleovrd;


%add_fmt_vars($_hercf,
              BUS_RULE_OVRD,
              FBUS_RULE_OVRD,
              F_,
              BUS_RULE_TYPE_CD);

*****ONLY FOR TEST******;
*filename RPTFL "/REPORTS_DOC/&sysmode.1/hercules/general/businessrule.pdf";
*********FOR TEST*******;

*%let _SOCKET_ERROR_MSG=something;

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
                font_size=12pt
                font_weight=bold}Business Rule Override Report^S={}";
title4 " ";
%macro businessruletitle;
%if &no_records = 0 %then %do;
title5 " ";
title6 j=c "^S={font_face=arial
                font_size=12pt
                font_weight=bold}There are no active business rule overrides for this program.^S={}";
%end;
%mend;
%businessruletitle;

%macro set_rpt_id;
%global REPORT_ID;
%IF &REPORT_ID = %STR() %THEN %DO;
/* This macro assigns a hard-coded REPORT_ID if the report is
   requested via the Program Maintenance Screen */
%LET REPORT_ID=6;
%END;
%mend;
%set_rpt_id;

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
   data=WORK.FBUS_RULE_OVRD
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
        CLIENT_NM_ID
                F_BUS_RULE_TYPE_CD
                EFFECTIVE_TS;

define CLIENT_NM_ID  / group order=data
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Client Name (ID)^S={}"
   style=[just     =l
                  cellwidth=3.00in];


define F_BUS_RULE_TYPE_CD  / display
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Business Rule^S={}"
   style=[just     =l
                  cellwidth=2.50in];

define EFFECTIVE_TS  / display
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Effective Date^S={}"
   style=[just     =r
                  cellwidth=1.0in];

run;
quit;
ods pdf close;

PROC SQL;
        DROP TABLE
                        WORK.BUS_RULE_OVRD,
                        WORK.FBUS_RULE_OVRD;
QUIT;
