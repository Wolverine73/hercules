/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  single_prescriber_cmctn.sas
|
| LOCATION: /PRG/sasadhoc1/hercules/templates
|
| PURPOSE:  Gives a list of all the communcations a given prescriber received.
|           The list will be for all systems and not just HCE.
|
| INPUT:    BEGIN_DATE, END_DATE, PRESCRIBER_ID
|
| OUTPUT:
|
+-------------------------------------------------------------------------------
| HISTORY:  13APR2004 - S.Shariff  - Original.
|           24JUN2004 - S.Shariff  - Modified report to work from Java.
|
+-----------------------------------------------------------------------HEADER*/
*SASDOC--------------------------------------------------------------------------
| The following formats the Begin & End Dates that are coming from Java
+------------------------------------------------------------------------SASDOC*;
%LET BEGIN_DATE = &BEGIN_DT;
%LET END_DATE = &END_DT;
%LET BEGIN_DT =%STR("&BEGIN_DT");
%LET END_DT =%STR("&END_DT");
%LET BEGIN_DT = %sysfunc(translate(&BEGIN_DT,%str(%'),%str(%")));
%LET END_DT = %sysfunc(translate(&END_DT,%str(%'),%str(%")));
%PUT &BEGIN_DT, &END_DT, &PRESCRIBER_ID;

PROC SQL NOPRINT;
    SELECT      DISTINCT FILE_ID
    INTO    :FILE_IDS       SEPARATED BY ','
    FROM    &HERCULES..TFILE_FIELD
    WHERE   FIELD_ID <> 13;
QUIT;
%let STR_FILE_IDS = %str((&FILE_IDS));
%put &STR_FILE_IDS;

PROC SQL;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
CREATE TABLE ALLSYSTEMS_PRESCRIBER AS
SELECT * FROM CONNECTION TO DB2
(
    SELECT      DATE(A.CMCTN_GENERATED_TS) AS COMMUNICATION_DT,
            RTRIM(E.BNF_FIRST_NM) || ' ' || RTRIM(E.BNF_LAST_NM) AS BENEFICIARY,
            C.SHORT_TX AS PROGRAM_NAME,
            B.VERSION_TITLE_TX
    FROM    &CLAIMSA..TCMCTN_HISTORY A,
            &HERCULES..TDOCUMENT_VERSION B,
            &CLAIMSA..TPROGRAM C,
            &CLAIMSA..TCMCTN_SUBJECT_HIS D,
            &CLAIMSA..TBENEF_XREF_DN E
    WHERE   A.RECEIVER_CMM_RL_CD = 2
    AND     A.TEMPLATE_ID = B.TEMPLATE_ID
    AND     RECEIVER_ID = &PRESCRIBER_ID
    AND     DATE(A.CMCTN_GENERATED_TS) BETWEEN &BEGIN_DT and &END_DT
    AND     A.VERSION_ID = B.VERSION_ID
    AND     B.PROGRAM_ID = C.PROGRAM_ID
    AND     A.CMCTN_HISTORY_ID = D.CMCTN_HISTORY_ID
    AND     D.SUBJECT_ID = E.BENEFICIARY_ID);
DISCONNECT FROM DB2;
QUIT;

PROC SQL;
 CREATE TABLE ALLSYSTEMS_PRESCRIBER2 AS
        SELECT  put(COMMUNICATION_DT, mmddyy10.) AS COMMUNICATION_DT,
                        BENEFICIARY,
                        PROGRAM_NAME,
                        VERSION_TITLE_TX
        FROM    ALLSYSTEMS_PRESCRIBER;
QUIT;

PROC SQL;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
CREATE TABLE HERCULES_PRESCRIBER AS
SELECT * FROM CONNECTION TO DB2
(
    SELECT  D.COMMUNICATION_DT,
            CASE F.SUBJECT_CMM_RL_CD
            WHEN 2 THEN NULL
            ELSE G.BNF_FIRST_NM || ' ' || G.BNF_LAST_NM
            END AS BENEFICIARY,
            C.LONG_TX AS PROGRAM_NAME,
            E.VERSION_TITLE_TX
    FROM    &HERCULES..TINITIATIVE A,
            &HERCULES..TPHASE_RVR_FILE B,
            &CLAIMSA..TPROGRAM C,
            &HERCULES..TCMCTN_RECEIVR_HIS D,
            &HERCULES..TDOCUMENT_VERSION E,
            (&HERCULES..TCMCTN_SUBJECT_HIS F LEFT JOIN
            &CLAIMSA..TBENEF_XREF_DN G ON (F.SUBJECT_ID = G.BENEFICIARY_ID))
    WHERE   B.CMCTN_ROLE_CD = 2
    AND     B.FILE_ID IN &STR_FILE_IDS
    AND     B.FILE_USAGE_CD = 1             /*MAILING*/
    AND     B.RELEASE_STATUS_CD = 2         /*FINAL*/
    AND     A.PROGRAM_ID = C.PROGRAM_ID
    AND     A.INITIATIVE_ID = B.INITIATIVE_ID
    AND     B.INITIATIVE_ID = D.INITIATIVE_ID
    AND     B.PHASE_SEQ_NB  = D.PHASE_SEQ_NB
    AND     B.CMCTN_ROLE_CD = D.CMCTN_ROLE_CD
    AND     D.INITIATIVE_ID = F.INITIATIVE_ID
    AND     D.PHASE_SEQ_NB  = F.PHASE_SEQ_NB
    AND     D.CMCTN_ROLE_CD = F.CMCTN_ROLE_CD
    AND     D.CMCTN_ID              = F.CMCTN_ID
    AND     D.RECIPIENT_ID = &PRESCRIBER_ID
    AND     DATE(B.RELEASE_TS) BETWEEN &BEGIN_DT AND &END_DT
    AND     C.PROGRAM_ID = E.PROGRAM_ID
    AND     D.APN_CMCTN_ID = E.APN_CMCTN_ID
    AND     D.COMMUNICATION_DT BETWEEN E.PRODUCTION_DT AND E.EXPIRATION_DT);
DISCONNECT FROM DB2;
QUIT;

PROC SQL;
 CREATE TABLE HERCULES_PRESCRIBER2 AS
        SELECT  put(COMMUNICATION_DT, mmddyy10.) AS COMMUNICATION_DT,
                        BENEFICIARY,
                        PROGRAM_NAME,
                        VERSION_TITLE_TX
        FROM    HERCULES_PRESCRIBER;
QUIT;

PROC SQL;
        CREATE TABLE COMPLETE_PRESCRIBER_CMCTN AS
        SELECT * FROM ALLSYSTEMS_PRESCRIBER2
        UNION
        SELECT * FROM HERCULES_PRESCRIBER2;

        DROP TABLE
        ALLSYSTEMS_PRESCRIBER,
        ALLSYSTEMS_PRESCRIBER2,
        HERCULES_PRESCRIBER,
        HERCULES_PRESCRIBER2;
QUIT;

PROC SQL;
    SELECT PRESCRIBER_NM, PRESCRIBER_DEA_NB
    INTO   :PRESCRIBER_NM,
           :DEA_NB
    FROM   &CLAIMSA..TPRSCBR_PRESCRIBE1
    WHERE  PRESCRIBER_ID = &PRESCRIBER_ID;
QUIT;

PROC SQL noprint;
SELECT 	COUNT(*)
INTO	:NO_RECORDS
FROM 	COMPLETE_PRESCRIBER_CMCTN;
QUIT;

%macro checkprescribercmctn;
%if &no_records = 0 %then %do;
PROC SQL;
INSERT INTO WORK.COMPLETE_PRESCRIBER_CMCTN
VALUES (null, null,  null, null);
QUIT;
%end;
%put no_records = &no_records;
%mend;
%checkprescribercmctn;

*****ONLY FOR TEST******;
*filename RPTFL "/REPORTS_DOC/test1/hercules/general/&PRESCRIBER_ID._pres_cmctn.pdf";
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
                font_weight=bold}Prescriber Communication Report^S={}";
title3 j=c "^S={font_face=arial
                font_size=12pt
                font_weight=bold}&BEGIN_DATE thru &END_DATE^S={}";
title5 " ";
title6 j=l "^S={font_face=arial
                font_size=12pt
                font_weight=bold}%str(Prescriber: &PRESCRIBER_NM)^S={}";
title7 j=l "^S={font_face=arial
                font_size=12pt
                font_weight=bold}%str(Prescriber ID: &PRESCRIBER_ID)^S={}";
title8 j=l "^S={font_face=arial
                font_size=12pt
                font_weight=bold}%str(DEA No.: &DEA_NB)^S={}";

%macro reporttitle;
%if &no_records = 0 %then %do;
title9 " ";
title10 j=c "^S={font_face=arial
                font_size=12pt
                font_weight=bold}There are no communications for this prescriber for the given period.^S={}";
%end;
%mend;
%reporttitle;

footnote1 j=l "^S={font_face=arial
                font_size=9pt
                font_weight=bold}Report ID: 22^S={}";

footnote2 j=l "^S={font_face=arial
                font_size=9pt
                font_weight=bold}%sysfunc(datetime(),datetime19.)^S={}";


*SASDOC--------------------------------------------------------------------------
| This prints the report in PDF format.
+------------------------------------------------------------------------SASDOC*;
proc report
   data=WORK.COMPLETE_PRESCRIBER_CMCTN
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
        COMMUNICATION_DT
                BENEFICIARY
                PROGRAM_NAME
                VERSION_TITLE_TX;

define COMMUNICATION_DT / display
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Date^S={}"
   style=[just=r];


define BENEFICIARY  / display
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Participant^S={}"
   style=[just     =l];


define PROGRAM_NAME  / display
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Program^S={}"
   style=[just     =l];

define VERSION_TITLE_TX  / display
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Communication Description^S={}"
   style=[just     =l];

run;
quit;

ods pdf close;


PROC SQL;
        DROP TABLE
                WORK.COMPLETE_PRESCRIBER_CMCTN;
QUIT;
