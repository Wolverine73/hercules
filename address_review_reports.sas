%include '/home/user/qcpap020/autoexec_new.sas'; 
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Monday, March 08, 2004      TIME: 11:40:11 AM
   PROJECT: Project
   PROJECT PATH: 
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Friday, February 20, 2004      TIME: 11:49:46 AM
   PROJECT: Project
   PROJECT PATH: 
---------------------------------------- */
/*HEADER----------------------------------------------------------------
|PROGRAM:
|   address_review_reports.sas
|
|LOCATION:
|   /PRG/sas&sysmode.1/hercules/reports/address_review_reports.sas
|
|PURPOSE:
|  	This report gives all of the records that are pending.
|   It breaks down each report based on Beneficiary_ID
|	or Prescriber_ID.
|
|	All of the Prescriber and Beneficiary Information is
|	provided including name, address, and two different
|	phone numbers.
|
|	The report is passed the initiative_id, phase_seq_nb,
|	cmctn_role_cd and data_quality_cd. The query differs
|	depending on the cmctn_role_cd.
|
|	The columns within PROC REPORT and PROC SQL are dynamically
|	created depending on the cmctn_role_cd.
|
|INPUT:
|	CLAIMSA.VBENEF_BENEFICIAR2 (View)
|	CLAIMSA.TPRSCBR_PRESCRIBE1	 
|   	HERCULES.TCMCTN_PENDING
|   	
|AUTHOR/DATE:
|   Sayeed Shariff/September 2003.
|
|MODIFICATIONS: S. Shariff - Feb 2004.
|               Changed Beneficiary table to the View, since
|               the table will no longer be populated.
+------------------------------------------------------------------HEADER*/;

%set_sysmode(mode=prod);*YM: added for Test only ;

OPTIONS MPRINT SOURCE2 MPRINTNEST MLOGIC MLOGICNEST symbolgen   ;


PROC PRINTTO LOG="/herc&sysmode/prg/hercules/reports/address_review_reports.log" NEW;
RUN;
QUIT;

 %LET DEBUG_FLAG=Y;
 OPTIONS MLOGIC MPRINT SYMBOLGEN;

%include "/herc&sysmode/prg/hercules/reports/address_review_reports_in.sas";

*SASDOC--------------------------------------------------------------------------
| 1) The ROLE_CODE Macro sets up variables depending on the particular
| 	 CMCTN_ROLE_CD. If the code is in (1 [participant],5 [cardholder])
|    then the SQL will differ.
| 2) The Record ID is matched either in the CLAIMSA.TPRSCBR_PRESCRIBE
| 	 table or in CLAIMSA.TBENEF_BENEFICIAR1 table.
| 3) If the code is in (1 [participant],5 [cardholder]) then the report
|    will also differ. External ID will be displayed and a Day and 
|    Night Phone Will be displayed.
| 4) If the code is 2 [prescriber] then External ID will not be 
|    displayed and a Phone and Fax will be displayed.
| 5) This Macro also handles the differing labels that will be 
|    displayed in the report.
+------------------------------------------------------------------------SASDOC*;
%MACRO ROLE_CODE; 
%global TABLE2 PHONE1 PHONE2 PHONE1_LABEL PHONE2_LABEL
		EXT_ID EXT_ID_SQL RECIPIENT_ID INTERNAL_ID_DISPLAY;
	%if ((&CMCTN_ROLE_CD eq 1) or
     				(&CMCTN_ROLE_CD eq 5)) %then
		%do;
   			%let TABLE2=CLAIMSA.VBENEF_BENEFICIAR2;
   			%let PHONE1=TB.DAY_AREA_CODE_NB || TB.DAY_PHONE_NB;
   			%let PHONE2=TB.NIGHT_AREA_CODE_NB || TB.NIGHT_PHONE_NB;
   			%let PHONE1_LABEL=Day Phone;
   			%let PHONE2_LABEL=Night Phone;
   			%let ext_id =External_ID;
   			%let EXT_ID_SQL=TB.CDH_EXTERNAL_ID;
   			%let RECIPIENT_ID=TB.BENEFICIARY_ID;
   			%let Internal_ID_Display=Beneficiary ID;
		%end;
	%else
	%if (&CMCTN_ROLE_CD eq 2) %then
		%do;
   			%let TABLE2=CLAIMSA.TPRSCBR_PRESCRIBE1;
   			%let PHONE1=TB.AREA_CODE_NB || TB.PHONE_NB;
   			%let PHONE2=TB.FAX_AREA_CODE_NB || TB.FAX_PHONE_NB;
   			%let PHONE1_LABEL=Phone;
   			%let PHONE2_LABEL=Fax;
   			%let ext_id =;
   			%let EXT_ID_SQL='ExternalID';
   			%let RECIPIENT_ID=TB.PRESCRIBER_ID;
   			%let Internal_ID_Display=Prescriber ID;
		%end;

%MEND ROLE_CODE;
%ROLE_CODE;  



%MACRO MAIN_CODE; 
*SASDOC--------------------------------------------------------------------------
| Select summary data for an initiative/phase and
| cmctn_role_cd/data_quality_cd
+------------------------------------------------------------------------SASDOC*;
PROC SQL noprint;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   CREATE TABLE WORK.ADDRESS_REVIEW_REPORTS1 AS
   SELECT * FROM CONNECTION TO DB2
      (
        SELECT 	
		distinct	TP.INITIATIVE_ID		as "INITIATIVE_ID",
					TP.PHASE_SEQ_NB			as "PHASE_SEQ_NB",
	   	    		TP.CMCTN_ROLE_CD		as "CMCTN_ROLE_CD",
		   			TP.DATA_QUALITY_CD		as "DATA_QUALITY_CD",
					TP.CMCTN_PENDING_ID 	as "Rec_ID",
					&EXT_ID_SQL				as "External_ID",
					TP.RECIPIENT_ID			as "Internal_ID",
					RTRIM(TP.RVR_FIRST_NM) || ' ' || 
					RTRIM(TP.RVR_LAST_NM)	as "Receiver_Name",
					RTRIM(TP.ADDRESS1_TX) 	as "Address1",
					RTRIM(TP.ADDRESS2_TX)	as "Address2",
					RTRIM(TP.ADDRESS3_TX)	as "Address3",
					RTRIM(TP.ADDRESS4_TX)	as "Address4",
					RTRIM(TP.CITY_TX) || ', ' || TP.STATE_CD || 
					'  ' || TP.ZIP_CD		as "CSZ",
					&PHONE1					as "Phone1",
					&PHONE2					as "Phone2"					
		FROM		&HERCULES..TCMCTN_PENDING TP, 
					&TABLE2 TB
		WHERE		TP.INITIATIVE_ID = &INITIATIVE_ID
		AND			TP.PHASE_SEQ_NB = &PHASE_SEQ_NB
		AND			TP.DATA_QUALITY_CD = &DATA_QUALITY_CD
		AND			TP.CMCTN_ROLE_CD = &CMCTN_ROLE_CD
		AND			TP.RECIPIENT_ID = &RECIPIENT_ID
                );
   DISCONNECT FROM DB2;
QUIT;

PROC SQL noprint;
    CREATE TABLE WORK.ADDRESS_REVIEW_REPORTS as
        SELECT
             	Rec_ID,
				External_ID,
				Internal_ID,
				Receiver_Name,
				Address1,
				Address2,
				Address3,
				Address4,
				CSZ,
				Phone1,
				Phone2,
				CMCTN_ROLE_CD,
				DATA_QUALITY_CD,
				INITIATIVE_ID,
				PHASE_SEQ_NB

        FROM WORK.ADDRESS_REVIEW_REPORTS1
		ORDER BY Rec_ID;

QUIT;

%add_fmt_vars(ADDRESS_REVIEW_REPORTS,
			  FADDRESS_REVIEW_REPORTS,
              F_,
              CMCTN_ROLE_CD,
			  DATA_QUALITY_CD
				);

*SASDOC--------------------------------------------------------------------------
| Select the initiative_id/phase_seq_nb/cmctn_role_cd/data_quality_cd
| and assign them to macro variables to be used within the titles.
+------------------------------------------------------------------------SASDOC*;
PROC SQL noprint;
SELECT distinct
   	INITIATIVE_ID,
	PHASE_SEQ_NB,
   	TRIM(LEFT(COMPBL(F_DATA_QUALITY_CD||" - "||F_CMCTN_ROLE_CD)))
  INTO
   	:_INITIATIVE_ID,
   	:_PHASE_SEQ_NB,
   	:_DATA_QUALITY_CD
  FROM WORK.FADDRESS_REVIEW_REPORTS;
QUIT;

*SASDOC--------------------------------------------------------------------------
| Report colors, headers, and margins.
+------------------------------------------------------------------------SASDOC*;
%let _hdr_clr=blue;
%let _col_clr=black;
%let _hdr_fg =blue;
%let _hdr_bg =lightgrey;
%let _tbl_fnt="Arial";
options orientation=landscape papersize=letter nodate number pageno=1;
options leftmargin  ="0.00"
        rightmargin ="0.00"
        topmargin   ="0.75in"
        bottommargin="0.25in";
ods listing close;
*ods pdf file=INTSMRPT
        startpage=off
        style=my_pdf
                notoc;
ods pdf file=rptfl
        startpage=off
        style=my_pdf
                notoc;
ods escapechar "^";
title1 j=c "^S={font_face=arial
                font_size=12pt
                font_weight=bold}Hercules Communication Engine^S={}";
title2 j=c "^S={font_face=arial
                font_size=14pt
                font_weight=bold}Address Review Reports^S={}"; 
title3 j=l "^S={font_face=arial
                font_size=10pt
                font_weight=bold}Initiative - Phase: &_INITIATIVE_ID - &_PHASE_SEQ_NB^S={}"; 
title4 j=l "^S={font_face=arial
                font_size=10pt
                font_weight=bold}&_DATA_QUALITY_CD^S={}";

  
*SASDOC--------------------------------------------------------------------------
| 1) This prints the entire Address Review Report in PDF format.
| 2) The Phone numbers are formatted here so they can look legible
|    within the report.
| 3) Macro Variables are used for some of the column labels
|    to distinguish between the role codes.
+------------------------------------------------------------------------SASDOC*;
proc report
   data=WORK.FADDRESS_REVIEW_REPORTS
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
        Rec_ID
		&ext_id
		Internal_ID
		Receiver_Name
		Address1
		Address2
		Address3
		Address4
		Address
		CSZ
		Phone1
		Phone1_Display
		Phone2
		Phone2_Display;

define Rec_ID  / display 
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Record ID^S={}"
   style=[cellwidth=0.60in
          just     =c];

define External_ID  / display
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}External ID^S={}"
   style=[cellwidth=0.80in
          just     =l];

define Internal_ID  / display
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}&Internal_ID_Display^S={}"
   style=[cellwidth=0.80in
          just     =l];

define Receiver_Name  / display
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Receiver Name^S={}"
   style=[cellwidth=1.75in
          just     =l];

define ADDRESS1 /noprint;
define ADDRESS2 /noprint;
define ADDRESS3 /noprint;
define ADDRESS4 /noprint;
define ADDRESS  / computed
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Address^S={}"
   style=[cellwidth=2.00in
          just     =l];

compute ADDRESS / char length=160;
   if compress(ADDRESS2) ne '' then
      ADDRESS2="^n"||ADDRESS2;
   if compress(ADDRESS3) ne '' then
      ADDRESS3="^n"||ADDRESS3;
   if compress(ADDRESS4) ne '' then
      ADDRESS4="^n"||ADDRESS4;
   ADDRESS=ADDRESS1||ADDRESS2||
			ADDRESS3||ADDRESS4;
endcomp;

define CSZ  / display
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}City, State, Zip^S={}"
   style=[cellwidth=1.95in
          just     =l];

define Phone1 /noprint;

define Phone1_Display  / computed
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}&PHONE1_LABEL^S={}"
   style=[cellwidth=1.00in
          just     =l];

compute Phone1_Display / char length=20;
	if compress(Phone1) eq ' ' then
	  Phone1_Display="N/A";
	if compress(Phone1_Display) ne 'N/A' then
	  Phone1_Display="("||substr(Phone1,1,3)||")"||
      substr(Phone1,4,3)||"-"||substr(Phone1,7,4);
endcomp;

define Phone2 /noprint;

define Phone2_Display  / computed
"^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}&PHONE2_LABEL^S={}"
   style=[cellwidth=1.00in
          just     =l];

compute Phone2_Display / char length=20;
	if compress(Phone2) eq ' ' then
	  Phone2_Display="N/A";
	if compress(Phone2_Display) ne 'N/A' then
	  Phone2_Display="("||substr(Phone2,1,3)||")"||
      substr(Phone2,4,3)||"-"||substr(Phone2,7,4);
endcomp;
run;
quit;

ods pdf close;

*Drop Temporary Tables;
PROC SQL noprint;
	DROP TABLE
		WORK.ADDRESS_REVIEW_REPORTS,
		WORK.ADDRESS_REVIEW_REPORTS1,
		WORK.FADDRESS_REVIEW_REPORTS;
QUIT;
%MEND MAIN_CODE;

%MAIN_CODE;
