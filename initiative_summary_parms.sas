%include '/user1/qcpap020/autoexec_new.sas';

/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  INITIATIVE_SUMMARY_PARMS.SAS
|
| LOCATION: /PRG/sas%lowcase(&SYSMODE)1/hercules/reports
|
| PURPOSE:  Produces a summary report of all parameters entered for an
|           initiative-phase, as well as general results when applicable.
|
| LOGIC:    (1) Create a dataset for initiative/phase summary.
|               and field description file.
|           (2) Create a dataset for communications component.
|           (3) Create a dataset for client setup parameters.
|           (4) Create a dataset for drug setup parameters.
|           (5) Create a dataset for prescriber setup parameters.
|           (6) Create a dataset for participant setup parameters.
|           (7) Create a dataset for formulary setup parameters.
|           (8) Create a dataset for document setup parameters.
|           (9) Produce a report of initiative phase summary.
|          (10) Produce a report of communications component.
|          (11) Produce a report of client setup parameters.
|          (12) Produce a report of drug setup parameters.
|          (13) Produce a report of prescriber setup parameters.
|          (14) Produce a report of participant setup parameters.
|          (15) Produce a report of formulary setup parameters.
|          (16) Produce a report of document setup parameters.
|
| INPUT:    INITIATIVE_ID macro variable
|           PHASE_SEQ_NB  macro variable
|           &CLAIMSA..TCHR3_CHR_THREE_CD
|           &CLAIMSA..TCLIENT1
|           &CLAIMSA..TPROGRAM
|           &HERCULES..TDOCUMENT_VERSION
|           &HERCULES..TDRUG_SUB_GRP_DTL
|           &HERCULES..TINIT_CLIENT_RULE
|           &HERCULES..TINIT_CLT_RULE_DEF
|           &HERCULES..TINIT_DRUG_GROUP
|           &HERCULES..TINIT_DRUG_SUB_GRP
|           &HERCULES..TINIT_FORMULARY
|           &HERCULES..TINIT_FRML_INCNTV
|           &HERCULES..TINIT_PHSE_CLT_DOM
|           &HERCULES..TINIT_PHSE_RVR_DOM
|           &HERCULES..TINIT_PRSCBR_RULE
|           &HERCULES..TINIT_PRSCBR_SPLTY
|           &HERCULES..TINIT_PRTCPNT_RULE
|           &HERCULES..TINITIATIVE
|           &HERCULES..TINITIATIVE_DATE
|           &HERCULES..TINITIATIVE_PHASE
|           &HERCULES..TPGM_TASK_LTR_RULE
|           &HERCULES..TPHASE_DRG_GRP_DT
|           &HERCULES..TPHASE_RVR_FILE
|           &HERCULES..TPROGRAM_TASK
|           &HERCULES..TSCREEN_STATUS
|
|
| OUTPUT:   RPT (report file)
+-------------------------------------------------------------------------------
|
| HISTORY:  
|
| 20AUG2003 - L.Kummen  - Original
| 04SEP2004 - JHou
|             i)  made changes so that 'Setup Document' section will always be on the
|                 report as long as there is any valid docs available either at
|                 Initiative or Program/Task level.
|             ii) added output member_cost_at selections for participant setup
|
| 01MAR2007 - Greg Dudley Hercules Version  1.0  
|             Produce a report of Setup Additional Parameters.
|
| 01MAY2007 - Brian Stropich - Hercules Version  1.5.01
|             Created and updated Code to Business Requirements Specifiation for iBenefit 2.0.
|
|10MAY2008 - K.Mittapalli- Hercules Version  2.1.0.1
|             Created and updated Code to Business Requirements Specifiation for Hercules2.1
|			  i)  made changes on Client setup section across all three adjudication engines
|				  Either at Initiative Level as well as program Level.
|			  ii) made changes on Document setup section across all three adjudication engines
|				  Either at Initiative Level as well as program Level.
|			  ii) made changes so that Java screen is suppose to call only this program rather
|				  Than three different programs based on Adjudication Engine.
|
|10NOV2008 - SY - Hercules Version  2.1.2.01
| 				- MODIFIED THE LOGIC TO CORRECT THE FUNCTIONALITY.
|25NOV2008 - GOD - Hercules Version  2.1.2.02
| 				- REMOVED REFERENCE TO SYSMODE=TEST AND FIXED FORMAT ERROR FOR 
|           MACRO %QL_docmnt_rpt
|10DEC2008 - GOD - Hercules Version  2.1.2.03
| 				- Commented out the FILENAME statemment that referenced RPTFL.
|           This was preventing the Web application from displaying the 
|           report on the Java screen.
|26FEB2009 - Hercules Version  2.1.2.02
|G. DUDLEY - CHANGED THE FORMAT OF THE REPORT TO INCLUDE A COLUMN FOR THE MEMBER ID
|            RESUE QUANITY
|02JAN2012 - RS - Modify to add PSG (MSS)Parameters and to fix Segmentation Error
|23FEB2012 - S. BILETSKY - Added logic to send report to user
|					after submitting in batch. see QCPI208
|06DEC2012 - SB - Modify to add EOB filter parameters for Negative Formulary
+-----------------------------------------------------------------------HEADER*/


/* AS of 02JAN2012 the next two lines are no longer needed since this program is invoked by Hercules Task Master ; */
/*  proc printto log="/DATA/sasprod1/hercules/reports/init_summary_Report.log" new;*/
/*  run;*/

*SASDOC-------------------------------------------------------------------------
| Include file for initiative_summary_parms.sas
+-----------------------------------------------------------------------SASDOC*;

/* UNCOMMENT next line for prod */
%set_sysmode(mode=prod);  

%PUT NOTE: RUNNING FROM HERCPROD FOLDER;

/* COMMENT next two lines for prod */
/*%set_sysmode(mode=sit2);*/
/*options sysparm='INITIATIVE_ID=14823 PHASE_SEQ_NB=1 HSC_USR_ID=QCPI208';*/

%include "/herc&sysmode/prg/hercules/hercules_in.sas";

/*OPTIONS MPRINT SOURCE2 MPRINTNEST MLOGIC MLOGICNEST symbolgen   ;*/
options mlogic mprint mlogicnest mprintnest;

*SASDOC=====================================================================;
*  QCPI208 - added logic to pull requestor id by QCP ID 
*====================================================================SASDOC*;
PROC SQL NOPRINT;
        SELECT QUOTE(TRIM(email)) INTO :_em_to_user SEPARATED BY ' '
        FROM ADM_LKP.ANALYTICS_USERS
        WHERE UPCASE(QCP_ID) IN ("&HSC_USR_ID");
QUIT;

*SASDOC=====================================================================;
*  QCPI208
*  Call update_request_ts to signal the start of executing summary report in batch
*====================================================================SASDOC*;
  %update_request_ts(start);


*SASDOC-------------------------------------------------------------------------
| 10DEC2008 g.d. This filename statement should remain commented out when in 
|                production and being called by the Web application
| 02JAN2012 QCPI208 - added rptfl filename for storage of initiative summary parms report
+-----------------------------------------------------------------------SASDOC*;

FILENAME rptfl "/herc&sysmode/data/hercules/reports/initiative_summary_parms_&initiative_id..pdf"; 

options mrecall;

%include "/herc&sysmode/prg/hercules/reports/initiative_summary_parms_in.sas";

options mprint mlogic;


%macro br_space(_LN_HGTH);
*SASDOC-----------------------------------------------------------------------
| add a break space to print file.
+----------------------------------------------------------------------SASDOC*;
data _null_;
file print;
put "^S={cellheight=&_LN_HGTH}^_^S={}";
run;
%mend br_space;

%macro comp_ttl(_DATASET,_COMPONENT_TX,_COMPONENT_CD,_DISPLAY=N);
*SASDOC-----------------------------------------------------------------------
| Create Initiative component title.
+----------------------------------------------------------------------SASDOC*;
%local _HEADER_FG _NOBS;
%if (%upcase(&_DISPLAY) eq N) %then
   %let _HEADER_FG=&_hdr_bg;
%else
   %let _HEADER_FG=black;
proc sql noprint;
select NOBS
  into :_NOBS
from   DICTIONARY.TABLES
where  LIBNAME='WORK'
  and  MEMNAME="&_DATASET"
  and  MEMTYPE='DATA';
quit;
%if (&_NOBS gt 0) %then
%do;
   %br_space(0.05in);
%end;

proc report
   contents="&_COMPONENT_TX"
   data=&_DATASET
   missing
   noheader
   nowd
   split="*"
   style(report)=[rules       =none
                  frame       =box
                  just        =l
                  asis        =off]
   style(column)=[font_size   =11pt
                  font_face   ="&_tbl_fnt"];
column
   &_COMPONENT_CD;
define &_COMPONENT_CD / group
   style=[cellwidth  =10.20in
          cellheight =0.22in
          font_weight=medium
          foreground =&_HEADER_FG
          background =&_hdr_bg
          just       =l
          pretext    ="^S={font_weight=bold
                           font_size  =11pt
                           foreground =&_hdr_fg
                           background =&_hdr_bg}&_COMPONENT_TX:^_^S={}"];
run;
quit;
%mend comp_ttl;

%macro br_line(_LN_HGTH);
*SASDOC-----------------------------------------------------------------------
| add a break line to print file.
+----------------------------------------------------------------------SASDOC*;
data _null_;
file print;
put "^S={cellwidth=7.85in cellheight=&_LN_HGTH background=black foreground=black
   just=l}^S={}";
run;
%mend br_line;

*SASDOC-------------------------------------------------------------------------
| Create dataset with Initiative-Phase values.
+-----------------------------------------------------------------------SASDOC*;
data _TABLE_0;
INITIATIVE_ID=&INITIATIVE_ID;
PHASE_SEQ_NB =&PHASE_SEQ_NB;
run;

*SASDOC-------------------------------------------------------------------------
| Create macro variable for DELIVERY_SYSTEM_CDs.
+-----------------------------------------------------------------------SASDOC*;
%let DELIVERY_SYSTEM_STR=;
%macro select_delivery_system(INITIATIVE_ID);
%local MAX_DELIVERY_SYSTEM_CD;
proc sql noprint;
   select    compress(put(max(DELIVERY_SYSTEM_CD),32.))
     into    :MAX_DELIVERY_SYSTEM_CD
   from      &HERCULES..TDELIVERY_SYS_EXCL
   where     INITIATIVE_ID=&INITIATIVE_ID;

%if (&MAX_DELIVERY_SYSTEM_CD ne %str()) %then
%do;
   select    DELIVERY_SYSTEM_CD
            ,put(DELIVERY_SYSTEM_CD,dlvry.)
     into    :DELIVERY_SYSTEM_CD
            ,:DELIVERY_SYSTEM_STR separated by '    '
   from      &HERCULES..TDELIVERY_SYS_EXCL
   where     INITIATIVE_ID  = &INITIATIVE_ID
   order by  DELIVERY_SYSTEM_CD;
   quit;
%end;
%else
%do;
   %let DELIVERY_SYSTEM_STR=%sysfunc(putn(.,dlvry.));
%end; 
%mend select_delivery_system;
%select_delivery_system(&INITIATIVE_ID);

*SASDOC--------------------------------------------------------------------
| 02FEB2009 - G.D.
| Extract total number of suspect member IDs by communication role code
| and assign to either the participant or prescriber macro variable
+-------------------------------------------------------------------SASDOC*;

PROC SQL NOPRINT;
  SELECT COUNT(*) INTO :MBR_ID_REUSE_PART_QTY
  FROM QCPAP020.HERCULES_MBR_ID_REUSE MBR,
       HERCULES.TPHASE_RVR_FILE RVR
  WHERE MBR.INITIATIVE_ID=&INITIATIVE_ID
    AND MBR.INITIATIVE_ID=RVR.INITIATIVE_ID
    AND CMCTN_ROLE_CD=1
  ;
QUIT;

PROC SQL NOPRINT;
  SELECT COUNT(*) INTO :MBR_ID_REUSE_PRESC_QTY
  FROM QCPAP020.HERCULES_MBR_ID_REUSE MBR,
       HERCULES.TPHASE_RVR_FILE RVR
  WHERE MBR.INITIATIVE_ID=&INITIATIVE_ID
    AND MBR.INITIATIVE_ID=RVR.INITIATIVE_ID
    AND CMCTN_ROLE_CD=2
  ;
QUIT;

%PUT NOTE: MBR_ID_REUSE_PART_QTY = &MBR_ID_REUSE_PART_QTY;
%PUT NOTE: MBR_ID_REUSE_PRESC_QTY = &MBR_ID_REUSE_PRESC_QTY;

*SASDOC-------------------------------------------------------------------------
| Select summary data for a Initiative-Phase.
| 02FEB2009 - G.D.
| Added a CASE statement to assign the MBR_ID_REUSE_QY by communication role
| code.
+-----------------------------------------------------------------------SASDOC*;

proc sql noprint;
create table _TABLE_1 as
select
   A.INITIATIVE_ID,
   A.PROGRAM_ID,
   A.TASK_ID,
   A.OVRD_CLT_SETUP_IN,
   A.BUS_RQSTR_NM,
   A.TITLE_TX,
   A.DESCRIPTION_TX,
   "&DELIVERY_SYSTEM_STR" as DELIVERY_SYSTEM_STR,
   A.HSC_USR_ID as INITIATIVE_HSC_USR_ID,
   B.PHASE_SEQ_NB,
   B.JOB_SCHEDULED_TS,
   B.JOB_START_TS,
   B.JOB_COMPLETE_TS,
   B.HSC_USR_ID as PHASE_HSC_USR_ID,
   C.DFLT_INCLSN_IN,
   E.CMCTN_ROLE_CD,
   E.DATA_CLEANSING_CD,
   E.FILE_USAGE_CD,
   E.DESTINATION_CD,
   E.RELEASE_STATUS_CD,
   E.REJECTED_QY,
   CASE E.CMCTN_ROLE_CD
     WHEN 1 THEN &MBR_ID_REUSE_PART_QTY
     WHEN 2 THEN &MBR_ID_REUSE_PRESC_QTY
   END AS MBR_ID_REUSE_QY,
   E.ACCEPTED_QY,
   E.SUSPENDED_QY,
   E.LETTERS_SENT_QY
 from &HERCULES..TINITIATIVE A,
      &HERCULES..TINITIATIVE_PHASE B,
      &CLAIMSA..TPROGRAM C,
      &HERCULES..TPHASE_RVR_FILE E
 where A.INITIATIVE_ID eq &INITIATIVE_ID
   and B.PHASE_SEQ_NB  eq &PHASE_SEQ_NB
   and A.INITIATIVE_ID eq B.INITIATIVE_ID
   and A.PROGRAM_ID    eq C.PROGRAM_ID
   and A.INITIATIVE_ID eq E.INITIATIVE_ID
   and B.PHASE_SEQ_NB  eq E.PHASE_SEQ_NB;

*SASDOC-------------------------------------------------------------------------
| Select distinct Initiative, Phase, Program, & Task values to control selection
| of Initiative Components.
+-----------------------------------------------------------------------SASDOC*;
create table _TABLE_1d as
select distinct
   INITIATIVE_ID,
   PHASE_SEQ_NB,
   PROGRAM_ID,
   TASK_ID,
   OVRD_CLT_SETUP_IN,
   DFLT_INCLSN_IN
  from _TABLE_1;
quit;


*SASDOC-------------------------------------------------------------------------
| Add formatted variables to initiative-phase data.
+-----------------------------------------------------------------------SASDOC*;
%add_fmt_vars($_HERCF,
              _TABLE_1,
              _F_TABLE_1,
              F_,
              PROGRAM_ID,
              TASK_ID,
              CMCTN_ROLE_CD,
              DATA_CLEANSING_CD,
              FILE_USAGE_CD,
              DESTINATION_CD,
              RELEASE_STATUS_CD);

*SASDOC-------------------------------------------------------------------------
| Add formatted variables to distinct initiative-phase data.
+-----------------------------------------------------------------------SASDOC*;
%add_fmt_vars($_HERCF,
              _TABLE_1d,
              _F_TABLE_1d,
              F_,
              PROGRAM_ID);

*SASDOC-------------------------------------------------------------------------
| Select columns for Initiative-Phase / Program title.
+-----------------------------------------------------------------------SASDOC*;
proc sql noprint;
select put(A.INITIATIVE_ID,12.)||' - '||put(A.PHASE_SEQ_NB,12.),
       put(B.PROGRAM_ID,12.)||' - '||B.F_PROGRAM_ID
  into :_T_INIT_PHASE, :_T_PROGRAM
  from _TABLE_0 A left join
       _F_TABLE_1d(keep=INITIATIVE_ID PHASE_SEQ_NB PROGRAM_ID F_PROGRAM_ID) B
    on A.INITIATIVE_ID eq B.INITIATIVE_ID
   and A.PHASE_SEQ_NB  eq B.PHASE_SEQ_NB;

select nobs
  into :_nobs_TABLE_1
  from dictionary.tables
 where libname="WORK"
   and memname="_TABLE_1"
   and memtype="DATA";
quit;

*SASDOC-------------------------------------------------------------------------
| Check for valid Initiative-Phase / Program title.
+-----------------------------------------------------------------------SASDOC*;
data _NULL_;
%let _T_INIT_PHASE=%cmpres(&_T_INIT_PHASE);
if &_nobs_TABLE_1 gt 0 then
   call symput('_T_PROGRAM',trim(left("&_T_PROGRAM")));
else
   call symput('_T_PROGRAM','Program Not Found');
run;

*SASDOC-------------------------------------------------------------------------
| Select communication component data for a initiative/phase.
+-----------------------------------------------------------------------SASDOC*;
proc sql noprint;
create table _TABLE_2 as
select
   A.INITIATIVE_ID,
   A.PHASE_SEQ_NB,
   B.CLT_STS_CMPNT_CD,
   B.DRG_STS_CMPNT_CD,
   B.PBR_STS_CMPNT_CD,
   B.PIT_STS_CMPNT_CD,
   B.FRML_STS_CMPNT_CD,
   B.DOM_STS_CMPNT_CD,
   B.IBNFT_STS_CMPNT_CD
  from _TABLE_0 A left join &HERCULES..TSCREEN_STATUS B
    on A.INITIATIVE_ID eq B.INITIATIVE_ID
   and A.PHASE_SEQ_NB  eq B.PHASE_SEQ_NB;
quit;

*SASDOC-------------------------------------------------------------------------
| Add formatted variables to communication component data.
+-----------------------------------------------------------------------SASDOC*;
%add_fmt_vars($_HERCF,
              _TABLE_2,
              _F_TABLE_2,
              F_,
              CLT_STS_CMPNT_CD,
              DRG_STS_CMPNT_CD,
              PBR_STS_CMPNT_CD,
              PIT_STS_CMPNT_CD,
              FRML_STS_CMPNT_CD,
              DOM_STS_CMPNT_CD,
			  IBNFT_STS_CMPNT_CD);

proc transpose
   data=_F_TABLE_2
   out =_T_F_TABLE_2(rename=(_NAME_=COMPONENT VAR_1=COMPONENT_VAL))
   prefix=VAR_;
var
   F_CLT_STS_CMPNT_CD
   F_DRG_STS_CMPNT_CD
   F_PBR_STS_CMPNT_CD
   F_PIT_STS_CMPNT_CD
   F_FRML_STS_CMPNT_CD
   F_DOM_STS_CMPNT_CD
   F_IBNFT_STS_CMPNT_CD;
run;
*SASDOC---------------------------------------------------------------------
| If QL Adjudication is active then following macro will execute.
| IF DSPLY_CLT_SETUP_CD=1 THEN process will check on TINIT tables
| IF DSPLY_CLT_SETUP_CD=(2,3) THEN process will check on TPROGRAM_TASK tables
|10MAY2008 - K.Mittapalli- Hercules Version  2.1.0.1
+--------------------------------------------------------------------SASDOC*;

%macro QL_process;
*SASDOC-------------------------------------------------------------------------
| IF DSPLY_CLT_SETUP_CD=1 THEN process will check on TINIT tables
| Select QL client setup parameters on TINIT tables.
| HERCULES.TINIT_CLT_RULE_DEF
| HERCULES.TINIT_CLIENT_RULE
|10MAY2008 - K.Mittapalli- Hercules Version  2.1.0.1
+-----------------------------------------------------------------------SASDOC*;
%IF &DSPLY_CLT_SETUP_CD=1 %THEN %DO;
proc sql noprint;
create table _TABLE_3_1 as
select distinct
   C.*,
   D.CLIENT_ID,
   D.CLT_SETUP_DEF_CD,
   	 CASE
	 WHEN D.CLT_SETUP_DEF_CD IN(1,3) THEN 0
	 ELSE 1
	 END AS CLIENT_SETUP_INCLUSION_CD
  from
      (
      select distinct
         A.INITIATIVE_ID,
         A.PHASE_SEQ_NB,
         A.PROGRAM_ID,
         A.TASK_ID,
         A.OVRD_CLT_SETUP_IN,
         A.DFLT_INCLSN_IN,
/*         ((A.DFLT_INCLSN_IN eq 1) and (A.OVRD_CLT_SETUP_IN eq 0)) as*/
/*         CLIENT_SETUP_INCLUSION_CD,*/
         B.DSPLY_CLT_SETUP_CD,
         B.DRG_DEFINITION_CD
        from _TABLE_1d A,
             &HERCULES..TPROGRAM_TASK B
       where A.PROGRAM_ID    eq B.PROGRAM_ID
         and A.TASK_ID       eq B.TASK_ID
      )
       C left join
       &HERCULES..TINIT_CLT_RULE_DEF D
    on C.INITIATIVE_ID eq D.INITIATIVE_ID;

create table _TABLE_3 as
select distinct
   G.*,    
   H.CLIENT_NM,
   H.CLIENT_CD
  from
      (
      select
         E.*,
         F.GROUP_CLASS_CD,
         F.GROUP_CLASS_SEQ_NB,
         F.BLG_REPORTING_CD,
         F.PLAN_CD_TX,
         F.PLAN_EXT_CD_TX,
         F.GROUP_CD_TX,
         F.GROUP_EXT_CD_TX,
         F.PLAN_NM AS PLAN_GROUP_NM,
         F.INCLUDE_IN
        from
             _TABLE_3_1 E,
             &HERCULES..TINIT_CLIENT_RULE F
        where E.INITIATIVE_ID eq F.INITIATIVE_ID
         and E.CLIENT_ID     eq F.CLIENT_ID
      )
       G left join
     &CLAIMSA..TCLIENT1 H
    on G.CLIENT_ID eq H.CLIENT_ID
order by CLIENT_ID;
quit;
%END;
*SASDOC-------------------------------------------------------------------------
| IF DSPLY_CLT_SETUP_CD=(2,3) THEN process will check on TPGMTASK tables
| Select QL Program Maintanace Setup parameters on TPROGRAM TASK tables.
|10MAY2008 - K.Mittapalli- Hercules Version  2.1.0.1
+-----------------------------------------------------------------------SASDOC*;

%IF (&DSPLY_CLT_SETUP_CD=2 OR &DSPLY_CLT_SETUP_CD=3) %THEN %DO;
*SASDOC-------------------------------------------------------------------------
| Select QL Program Maintanace Setup parameters.
| HERCULES.TPGMTASK_QL_RUL
|10MAY2008 - K.Mittapalli- Hercules Version  2.1.0.1
+-----------------------------------------------------------------------SASDOC*;
proc sql noprint;
create table _TABLE_3_1 as
select distinct
   C.*,
   D.CLIENT_ID,
   D.CLT_SETUP_DEF_CD,
   CASE
    WHEN D.CLT_SETUP_DEF_CD IN(1,3) THEN 0
    ELSE 1
    END AS CLIENT_SETUP_INCLUSION_CD,
   D.HSC_TS,
   D.HSU_TS
  from
      (
      select distinct
         A.INITIATIVE_ID,
         A.PHASE_SEQ_NB,
         A.PROGRAM_ID,
         A.TASK_ID,
         A.OVRD_CLT_SETUP_IN,
         A.DFLT_INCLSN_IN,
/*         ((A.DFLT_INCLSN_IN eq 1) and (A.OVRD_CLT_SETUP_IN eq 0)) as*/
/*         CLIENT_SETUP_INCLUSION_CD,*/
         B.DSPLY_CLT_SETUP_CD,
         B.DRG_DEFINITION_CD
        from _TABLE_1d A,
             &HERCULES..TPROGRAM_TASK B
       where A.PROGRAM_ID    eq B.PROGRAM_ID
         and A.TASK_ID       eq B.TASK_ID
      )
       C left join
       &HERCULES..TPGMTASK_QL_RUL D
    on C.PROGRAM_ID eq D.PROGRAM_ID
   and C.TASK_ID eq D.TASK_ID
   and DATE() BETWEEN D.EFFECTIVE_DT AND D.EXPIRATION_DT;
create table _TABLE_3 as
select distinct
   G.*,
   H.CLIENT_NM,
   H.CLIENT_CD
  from
      (
      select
         E.*,
         F.GROUP_CLASS_CD,
         F.GROUP_CLASS_SEQ_NB,
         F.BLG_REPORTING_CD,
         F.PLAN_CD_TX,
         F.PLAN_EXT_CD_TX,
         F.GROUP_CD_TX,
         F.GROUP_EXT_CD_TX,
         F.PLAN_NM AS PLAN_GROUP_NM,
		 CASE
		 WHEN E.CLT_SETUP_DEF_CD IN(1,3) THEN 1
		 ELSE 0
		 END AS INCLUDE_IN
        from
             _TABLE_3_1 E,
             &HERCULES..TPGMTASK_QL_RUL F
	   where E.PROGRAM_ID = F.PROGRAM_ID
         and E.TASK_ID    = F.TASK_ID
		 and E.HSC_TS     = F.HSC_TS
		 and E.HSU_TS     = F.HSU_TS
 		 and E.Client_id = F.Client_id
		 and DATE()  BETWEEN F.EFFECTIVE_DT AND F.EXPIRATION_DT
      )
       G left join
     &CLAIMSA..TCLIENT1 H
    on G.CLIENT_ID eq H.CLIENT_ID
order by CLIENT_ID;
quit;
%END;
*SASDOC-------------------------------------------------------------------------
| Add formatted variables to client setup/Program Maintanance parameters data.
| 02JAN2012 - RS - Add variable DSPLY_CLT_SETUP_CD to format for client setup
+-----------------------------------------------------------------------SASDOC*;

%add_fmt_vars($_HERCF,
              _TABLE_3,
              _F_TABLE_3,
              F_,
              CLIENT_SETUP_INCLUSION_CD,
              CLT_SETUP_DEF_CD,
              INCLUDE_IN,
			  DSPLY_CLT_SETUP_CD);  /* RS 1/02/12 include for client report */

*SASDOC-------------------------------------------------------------------------
| Select QL formulary setup parameters.
+-----------------------------------------------------------------------SASDOC*;
proc sql noprint;
create table _table_7_1 as
select B.INITIATIVE_ID,
       B.FORMULARY_ID,
       B.FRML_USAGE_CD
  from _TABLE_1d A, &HERCULES..TINIT_FORMULARY B
 where A.INITIATIVE_ID eq B.INITIATIVE_ID;

create table _table_7_2 as
select B.INITIATIVE_ID,
       B.INCENTIVE_TYPE_CD,
       B.PERIOD_CD
  from _TABLE_1d A, &HERCULES..TINIT_FRML_INCNTV B
 where A.INITIATIVE_ID eq B.INITIATIVE_ID;

create table _table_7_3 as
select B.INITIATIVE_ID,
       B.DATE_TYPE_CD,
       B.INITIATIVE_DT
  from _TABLE_1d A, &HERCULES..TINITIATIVE_DATE B
 where A.INITIATIVE_ID eq B.INITIATIVE_ID;
quit;

*SASDOC-------------------------------------------------------------------------
| Add QL formatted variables to formulary setup parameters data.
+-----------------------------------------------------------------------SASDOC*;
%add_fmt_vars($_HERCF,
              _TABLE_7_1,
              _F_TABLE_7_1,
              F_,
              FORMULARY_ID,
              FRML_USAGE_CD);

%add_fmt_vars($_HERCF,
              _TABLE_7_2,
              _F_TABLE_7_2,
              F_,
              PERIOD_CD,
              INCENTIVE_TYPE_CD);

%add_fmt_vars($_HERCF,
              _TABLE_7_3,
              _F_TABLE_7_3,
              F_,
              DATE_TYPE_CD);

*SASDOC-------------------------------------------------------------------------
| IF DOCUMENT_LOC_CD=1 THEN process will check on TINIT tables
| Select QL document setup parameters on TINIT tables.
| HERCULES.TINIT_PHSE_RVR_DOM 
| HERCULES.TINIT_QL_DOC_OVR
|10MAY2008 - K.Mittapalli- Hercules Version  2.1.0.1
+-----------------------------------------------------------------------SASDOC*;
%IF &DOCUMENT_LOC_CD=1 %THEN %DO; 
proc sql noprint;
create table _TABLE_8_1 as
select B.INITIATIVE_ID,
       B.PHASE_SEQ_NB,
       B.CMCTN_ROLE_CD,
       B.LTR_RULE_SEQ_NB,
       A.PROGRAM_ID,
       A.TASK_ID,
       B.CLIENT_ID,
	   CASE 
	   WHEN B.GROUP_CLASS_CD = 0 THEN .
	   ELSE B.GROUP_CLASS_CD
	   END AS GROUP_CLASS_CD,
	   CASE
	   WHEN B.GROUP_CLASS_SEQ_NB = 0 THEN .
	   ELSE B.GROUP_CLASS_SEQ_NB
	   END AS GROUP_CLASS_SEQ_NB,
	   B.BLG_REPORTING_CD,
	   B.PLAN_NM,
	   B.PLAN_CD_TX,
	   B.PLAN_EXT_CD_TX,
	   B.GROUP_CD_TX,
	   B.GROUP_EXT_CD_TX, 
       B.APN_CMCTN_ID,
       B.HSU_TS
 from  _TABLE_1d A,
       &HERCULES..TINIT_QL_DOC_OVR B
 where A.INITIATIVE_ID   eq B.INITIATIVE_ID
   and A.PHASE_SEQ_NB    eq B.PHASE_SEQ_NB  ;

%END;
*SASDOC-------------------------------------------------------------------------
| IF DOCUMENT_LOC_CD=2 THEN process will check on TPGMTASK tables
| Select QL document setup parameters on TPGMTASK tables.
| HERCULES.TPGM_TASK_DOM
| HERCULES.TPGMTASK_QL_OVR
|10MAY2008 - K.Mittapalli- Hercules Version  2.1.0.1
+-----------------------------------------------------------------------SASDOC*;
%IF &DOCUMENT_LOC_CD=2 %THEN %DO;
proc sql noprint;
create table _TABLE_8_1 as
select A.INITIATIVE_ID,
       A.PHASE_SEQ_NB,
       B.CMCTN_ROLE_CD,
       B.LTR_RULE_SEQ_NB,
       A.PROGRAM_ID,
       A.TASK_ID,
       B.CLIENT_ID,
	   CASE 
	   WHEN B.GROUP_CLASS_CD = 0 THEN .
	   ELSE B.GROUP_CLASS_CD
	   END AS GROUP_CLASS_CD,
	   CASE
	   WHEN B.GROUP_CLASS_SEQ_NB = 0 THEN .
	   ELSE B.GROUP_CLASS_SEQ_NB
	   END AS GROUP_CLASS_SEQ_NB,
	   B.BLG_REPORTING_CD,
	   B.PLAN_NM,
	   B.PLAN_CD_TX,
	   B.PLAN_EXT_CD_TX,
	   B.GROUP_CD_TX,
	   B.GROUP_EXT_CD_TX, 
       B.APN_CMCTN_ID,
       B.HSU_TS
 from  _TABLE_1d A,
       &HERCULES..TPGMTASK_QL_OVR B
 where A.PROGRAM_ID   eq B.PROGRAM_ID
   and A.TASK_ID      eq B.TASK_ID 
   AND B.EFFECTIVE_DT <= TODAY()
   AND B.EXPIRATION_DT >= TODAY();
%END;

create table _TABLE_8 as
select C.INITIATIVE_ID,
       C.PHASE_SEQ_NB,
       C.CMCTN_ROLE_CD,
       C.LTR_RULE_SEQ_NB,
       C.PROGRAM_ID,
       C.TASK_ID,
       C.CLIENT_ID,
	   C.GROUP_CLASS_CD,
	   C.GROUP_CLASS_SEQ_NB,
	   C.BLG_REPORTING_CD,
	   C.PLAN_NM,
	   C.PLAN_CD_TX,
	   C.PLAN_EXT_CD_TX,
	   C.GROUP_CD_TX,
	   C.GROUP_EXT_CD_TX, 
       C.APN_CMCTN_ID,
       C.DESCRIPTION_TX,
       D.VERSION_TITLE_TX
  ,datepart(C.HSU_TS) as C_HSU_TS format=worddate12.
  ,D.PRODUCTION_DT as D_PRODUCTION_DT format=worddate12.
  ,D.EXPIRATION_DT as D_EXPIRATION_DT format=worddate12.
  from (
       select A.INITIATIVE_ID,
              A.PHASE_SEQ_NB,
              A.CMCTN_ROLE_CD,
              A.LTR_RULE_SEQ_NB,
              A.PROGRAM_ID,
              A.TASK_ID,
              A.CLIENT_ID,
	   		  A.GROUP_CLASS_CD,
	   		  A.GROUP_CLASS_SEQ_NB,
	   		  A.BLG_REPORTING_CD,
	   		  A.PLAN_NM,
	   		  A.PLAN_CD_TX,
	   		  A.PLAN_EXT_CD_TX,
	   	      A.GROUP_CD_TX,
	   		  A.GROUP_EXT_CD_TX, 
              A.APN_CMCTN_ID,
              A.HSU_TS,
              B.DESCRIPTION_TX
         from _TABLE_8_1 A left join
              &HERCULES..TPGM_TASK_LTR_RULE B
           on A.PROGRAM_ID      eq B.PROGRAM_ID
          and A.TASK_ID         eq B.TASK_ID
          and A.CMCTN_ROLE_CD   eq B.CMCTN_ROLE_CD
          and A.LTR_RULE_SEQ_NB eq B.LTR_RULE_SEQ_NB
          and A.PHASE_SEQ_NB    eq B.PHASE_SEQ_NB
       )
       C left join
       &HERCULES..TDOCUMENT_VERSION D
   on C.PROGRAM_ID       eq D.PROGRAM_ID
  and C.APN_CMCTN_ID     eq D.APN_CMCTN_ID
  and D.PRODUCTION_DT <= today()
  and D.EXPIRATION_DT >= today()
order by INITIATIVE_ID, PHASE_SEQ_NB, CLIENT_ID,GROUP_CLASS_CD,GROUP_CLASS_SEQ_NB,BLG_REPORTING_CD,PLAN_NM,PLAN_CD_TX,
	     PLAN_EXT_CD_TX,GROUP_CD_TX,GROUP_EXT_CD_TX,CMCTN_ROLE_CD, APN_CMCTN_ID, LTR_RULE_SEQ_NB;
quit;
%IF &DOCUMENT_LOC_CD=2 %THEN %DO;
proc sql;
create table _TABLE_8_2 as
select DISTINCT A.INITIATIVE_ID,
       A.PHASE_SEQ_NB,
       B.CMCTN_ROLE_CD,
       B.LTR_RULE_SEQ_NB,
       B.PROGRAM_ID,
       B.TASK_ID,
       B.APN_CMCTN_ID,
       B.HSU_TS,
       C.DESCRIPTION_TX,
       E.VERSION_TITLE_TX
     from  _TABLE_1d A,
          &HERCULES..TPGM_TASK_DOM 		B
left join &HERCULES..TPGM_TASK_LTR_RULE C
           on B.PROGRAM_ID      eq C.PROGRAM_ID
          and B.TASK_ID         eq C.TASK_ID
          and B.CMCTN_ROLE_CD   eq C.CMCTN_ROLE_CD
          and B.LTR_RULE_SEQ_NB eq C.LTR_RULE_SEQ_NB
		  and B.PHASE_SEQ_NB    eq C.PHASE_SEQ_NB
left join &HERCULES..TDOCUMENT_VERSION  E
   		   on C.PROGRAM_ID       eq E.PROGRAM_ID
  		  and B.APN_CMCTN_ID     eq E.APN_CMCTN_ID
  		  and E.PRODUCTION_DT <= today()
  		  and E.EXPIRATION_DT >= today()
 where A.PROGRAM_ID eq B.PROGRAM_ID
   and A.TASK_ID	eq B.TASK_ID
   AND B.EFFECTIVE_DT <= TODAY()
   AND B.EXPIRATION_DT >= TODAY()
%END;
;quit;
%IF &DOCUMENT_LOC_CD=1 %THEN %DO; 
proc sql;
create table _TABLE_8_2 as
select DISTINCT B.INITIATIVE_ID,
       B.PHASE_SEQ_NB,
       B.CMCTN_ROLE_CD,
       B.LTR_RULE_SEQ_NB,
       B.PROGRAM_ID,
       A.TASK_ID,
       B.APN_CMCTN_ID,
       B.HSU_TS,
       C.DESCRIPTION_TX,
       E.VERSION_TITLE_TX
    from  _TABLE_1d A,
          &HERCULES..TINIT_PHSE_RVR_DOM B
left join &HERCULES..TPGM_TASK_LTR_RULE C
           on B.PROGRAM_ID      eq C.PROGRAM_ID
          and B.CMCTN_ROLE_CD   eq C.CMCTN_ROLE_CD
          and B.LTR_RULE_SEQ_NB eq C.LTR_RULE_SEQ_NB
          and B.PHASE_SEQ_NB    eq C.PHASE_SEQ_NB
left join &HERCULES..TDOCUMENT_VERSION  E
   		   on C.PROGRAM_ID       eq E.PROGRAM_ID
  		  and B.APN_CMCTN_ID     eq E.APN_CMCTN_ID
  		  and E.PRODUCTION_DT <= today()
  		  and E.EXPIRATION_DT >= today()
 where A.INITIATIVE_ID eq B.INITIATIVE_ID
%END;
;
  quit;

*SASDOC-------------------------------------------------------------------------
| Add QL formatted variables to document setup data.
+-----------------------------------------------------------------------SASDOC*;
%add_fmt_vars($_HERCF,
              _TABLE_8,
              _F_TABLE_8,
              F_,
              CMCTN_ROLE_CD);
*SASDOC-------------------------------------------------------------------------
| Add QL formatted variables to default document setup data.
+-----------------------------------------------------------------------SASDOC*;
%add_fmt_vars($_HERCF,
              _TABLE_8_2,
              _F_TABLE_8_2,
              F_,
              CMCTN_ROLE_CD);
%mend QL_process;
*SASDOC--------------------------------------------------------------------
| Execute RX_RE_PROCESS for RXCLAIM AND RECAP ADJUDICATION ENGINES.
| IF DSPLY_CLT_SETUP_CD=1 THEN process will check on TINIT tables
| IF DSPLY_CLT_SETUP_CD=(2,3) THEN process will check on TPROGRAM_TASK tables
| RECAP FOR INITIATIVE LEVEL(CLIENT SETUP)
| 			  HERCULES.TINIT_RECAP_CLT_RL
| RXCLAIM FOR INITIATIVE LEVEL(CLIENT SETUP)
|			  HERCULES.TINIT_RXCLM_CLT_RL
| RECAP FOR PROGRAM MAINTANANCE(CLIENT SETUP)
|			  HERCULES.TPGMTASK_RECAP_RUL
| RXCLAIM FOR PROGRAM MAINTANANCE(CLIENT SETUP)
|			  HERCULES.TPGMTASK_RXCLM_RUL
| RECAP FOR INITIATIVE LEVEL(DOCUMENT SETUP)
|			  HERCULES.TINIT_RECP_DOC_OVR
| RXCLAIM FOR INITIATIVE LEVEL(DOCUMENT SETUP)
|			  HERCULES.TINIT_RXCM_DOC_OVR
| RECAP FOR PROGRAM MAINTANANCE(DOCUMENT SETUP)
|			  HERCULES.TPGMTASK_RECAP_OVR
| RXCLAIM FOR PROGRAM MAINTANANCE(DOCUMENT SETUP)
|			  HERCULES.TPGMTASK_RXCLM_OVR
|10MAY2008 - K.Mittapalli- Hercules Version  2.1.0.1
+--------------------------------------------------------------------SASDOC*;
%macro RX_RE_process(RX_RE_TBL,RX_RE_TBL2,FORMAT_TBL,DOCMNT_TBL,DOCMNT_TBL2,DOCMNT_TBL5,HERC_TBL,HERC_TBL2,FIELD1
					,FIELD2,CODE,DOC_FIELD1,DOC_FIELD2,DOC_FIELD3,DOCMNT_TBL3,DOCMNT_TBL4);
*SASDOC-------------------------------------------------------------------------
| IF DSPLY_CLT_SETUP_CD=1 THEN process will check on TINIT tables
| Select RECAP/RXCLAIM client setup parameters on TINIT tables.
| RECAP FOR INITIATIVE LEVEL(CLIENT SETUP)
| 			  HERCULES.TINIT_RECAP_CLT_RL
| RXCLAIM FOR INITIATIVE LEVEL(CLIENT SETUP)
|			  HERCULES.TINIT_RXCLM_CLT_RL
|10MAY2008 - K.Mittapalli- Hercules Version  2.1.0.1
+-----------------------------------------------------------------------SASDOC*;
%IF &DSPLY_CLT_SETUP_CD=1 %THEN %DO;
*SASDOC-------------------------------------------------------------------------
| Select Recap/Rxclaim client setup parameters.
| 10MAY2008 - K.MITTAPALLI   - Hercules Version  2.1.0.1
+-----------------------------------------------------------------------SASDOC*;
proc sql noprint;
create table &RX_RE_TBL as
select distinct
   C.*,
   D.CLIENT_ID,
   D.CLT_SETUP_DEF_CD,
   CASE
	 WHEN D.CLT_SETUP_DEF_CD IN(1,3) THEN 0
	 ELSE 1
	 END AS CLIENT_SETUP_INCLUSION_&CODE
  from
      (
      select distinct
         A.INITIATIVE_ID,
         A.PHASE_SEQ_NB,
         A.PROGRAM_ID,
         A.TASK_ID,
         A.OVRD_CLT_SETUP_IN,
         A.DFLT_INCLSN_IN,
/*         ((A.DFLT_INCLSN_IN eq 1) and (A.OVRD_CLT_SETUP_IN eq 0)) as*/
/*         CLIENT_SETUP_INCLUSION_&CODE,*/
         B.DSPLY_CLT_SETUP_CD,
         B.DRG_DEFINITION_CD
        from _TABLE_1d A,
             &HERCULES..TPROGRAM_TASK B
       where A.PROGRAM_ID    eq B.PROGRAM_ID
         and A.TASK_ID       eq B.TASK_ID
      )
       C left join
       &HERCULES..TINIT_CLT_RULE_DEF D
       on C.INITIATIVE_ID eq D.INITIATIVE_ID;
create table &RX_RE_TBL2 as
select distinct
   G.*,
   H.CLIENT_NM,
   H.CLIENT_CD
  from
      (
      select
         E.*,
         F.CLIENT_ID,
	     &FIELD1,
         &FIELD2,
         F.GROUP_CD,
	 F.INCLUDE_IN
        from
             &RX_RE_TBL.  E,
             &HERCULES..&HERC_TBL F
          where E.INITIATIVE_ID =  F.INITIATIVE_ID
         and E.CLIENT_ID     =  F.CLIENT_ID
      )
       G left join
     &CLAIMSA..TCLIENT1 H
    on G.CLIENT_ID eq H.CLIENT_ID
order by CLIENT_ID;
quit;

%END;
*SASDOC-------------------------------------------------------------------------
| IF DSPLY_CLT_SETUP_CD=(2,3) THEN process will check on TPGMTASK tables
| Select Recap/Rxclaim Program Maintanace Setup parameters on TPROGRAM TASK tables.
| RECAP FOR PROGRAM MAINTANANCE(CLIENT SETUP)
|			  HERCULES.TPGMTASK_RECAP_RUL
| RXCLAIM FOR PROGRAM MAINTANANCE(CLIENT SETUP)
|			  HERCULES.TPGMTASK_RXCLM_RUL
|10MAY2008 - K.Mittapalli- Hercules Version  2.1.0.1
+-----------------------------------------------------------------------SASDOC*;
%IF (&DSPLY_CLT_SETUP_CD=2 OR &DSPLY_CLT_SETUP_CD=3) %THEN %DO;

*SASDOC-------------------------------------------------------------------------
| Select Recap/Rxclaim Program Maintanace Setup parameters.
| 10MAY2008 - K.MITTAPALLI   - Hercules Version  2.1.0.1 
| 30AUG2012 - S.BILETSKY - Added logic for migrated clients (SIB)
+-----------------------------------------------------------------------SASDOC*;

*create dtasets for non migr clients setup;
proc sql noprint;
create table &RX_RE_TBL as
select distinct
   C.*,
%if &CODE eq 2 %then %do;
   E.CLIENT_ID, E.CLIENT_NM, D.CARRIER_ID,
%end;
%if &CODE eq 3 %then %do;
   F.CLIENT_ID, F.CLIENT_NM, D.INSURANCE_CD, D.CARRIER_ID,
%end;
   D.CLT_SETUP_DEF_CD,
	CASE
	 WHEN D.CLT_SETUP_DEF_CD IN(1,3) THEN 0
	 ELSE 1
	 END AS CLIENT_SETUP_INCLUSION_&CODE,
/*   D.HSC_TS, D.HSU_TS*/
	 DATEPART(D.HSC_TS) AS HSC_DATE, HOUR(D.HSC_TS) AS HSC_HOUR, MINUTE(D.HSC_TS) AS HSC_MIN
  from (  select distinct
         A.INITIATIVE_ID,
         A.PHASE_SEQ_NB,
         A.PROGRAM_ID,
         A.TASK_ID,
         A.OVRD_CLT_SETUP_IN,
         A.DFLT_INCLSN_IN,
         B.DSPLY_CLT_SETUP_CD,
         B.DRG_DEFINITION_CD
        from _TABLE_1d A,
             &HERCULES..TPROGRAM_TASK B
       where A.PROGRAM_ID    eq B.PROGRAM_ID
         and A.TASK_ID       eq B.TASK_ID )
       C left join
	    &HERCULES..&HERC_TBL2 D
		  on C.PROGRAM_ID = D.PROGRAM_ID
		 and C.TASK_ID = D.TASK_ID
		 and D.PROGRAM_ID = &PROGRAM_ID. 
         and D.TASK_ID = &TASK_ID. 
/*		and D.CARRIER_ID='X9400'*/
		 and DATE() BETWEEN D.EFFECTIVE_DT AND D.EXPIRATION_DT
	%if &CODE eq 2 %then %do;
		left join &CLAIMSA..TCLIENT1 E 
    on D.CARRIER_ID eq E.CLIENT_CD;
	%end;
	%if &CODE eq 3 %then %do;
		left join &CLAIMSA..TCLIENT1 F 
    on D.CARRIER_ID eq F.CLIENT_CD;
	%end;
	
%if &CODE eq 3 %then %do;
	select distinct
   C.*, F.CLIENT_ID, F.CLIENT_NM, D.INSURANCE_CD, D.CARRIER_ID, D.CLT_SETUP_DEF_CD,
   CASE WHEN D.CLT_SETUP_DEF_CD IN(1,3) THEN 0 ELSE 1 END AS CLIENT_SETUP_INCLUSION_&CODE,
/*   D.HSC_TS, D.HSU_TS*/
	 DATEPART(D.HSC_TS) AS HSC_DATE, HOUR(D.HSC_TS) AS HSC_HOUR, MINUTE(D.HSC_TS) AS HSC_MIN
  	from  ( select distinct
         A.INITIATIVE_ID,
         A.PHASE_SEQ_NB,
         A.PROGRAM_ID,
         A.TASK_ID,
         A.OVRD_CLT_SETUP_IN,
         A.DFLT_INCLSN_IN,
         B.DSPLY_CLT_SETUP_CD,
         B.DRG_DEFINITION_CD
        from _TABLE_1d A, &HERCULES..TPROGRAM_TASK B
       where A.PROGRAM_ID = B.PROGRAM_ID
         and A.TASK_ID  = B.TASK_ID ) C, &HERCULES..&HERC_TBL2 D, &CLAIMSA..TCLIENT1 F
		  where C.PROGRAM_ID = D.PROGRAM_ID
		 and C.TASK_ID = D.TASK_ID and D.CARRIER_ID = F.CLIENT_CD
		 and D.PROGRAM_ID = &PROGRAM_ID. 
         and D.TASK_ID = &TASK_ID.
		 and DATE() BETWEEN D.EFFECTIVE_DT AND D.EXPIRATION_DT;
%end;

create table &RX_RE_TBL2 as
	select distinct  G.* ,H.CLIENT_CD
  	from ( select distinct E.*, &FIELD1, &FIELD2, F.GROUP_CD,
		 CASE WHEN E.CLT_SETUP_DEF_CD IN(1,3) THEN 1 ELSE 0 END AS INCLUDE_IN
        	from &RX_RE_TBL E, &HERCULES..&HERC_TBL2 F
			where E.PROGRAM_ID = F.PROGRAM_ID
		 	and E.TASK_ID 	  = F.TASK_ID
/*		 	and E.HSC_TS     = F.HSC_TS*/
/*		 	and E.HSU_TS     = F.HSU_TS*/
			and E.HSC_DATE = DATEPART(F.HSC_TS)
			and E.HSC_HOUR = HOUR(F.HSC_TS)
			and E.HSC_MIN = MINUTE(F.HSC_TS) 
         	and E.PROGRAM_ID = &PROGRAM_ID. 
         	and E.TASK_ID    = &TASK_ID.
		 	%if &CODE eq 2 %then %do;
        	and E.CARRIER_ID = &FIELD1
		 	%end;
		 	%if &CODE eq 3 %then %do;
		 	and E.INSURANCE_CD = &FIELD1
		 	and ((E.CARRIER_ID  = &FIELD2) or (F.CARRIER_ID IS NULL))
		 	%end;
		 	and DATE() BETWEEN F.EFFECTIVE_DT AND F.EXPIRATION_DT ) G 
		left join &CLAIMSA..TCLIENT1 H on G.CARRIER_ID eq H.CLIENT_CD
	%if &CODE eq 2 %then %do;
		order by H.CLIENT_ID;
	%end;
	%if &CODE eq 3 %then %do;
		order by G.INSURANCE_CD;
	%end;
quit;

*create datasets for migrated clients;
%if &CODE eq 2 %then %do;
 proc sql noprint;
	select distinct 1 into :is_there_migr
	from &HERCULES..TPGMTASK_RXCLM_RUL R, QCPAP020.T_CLNT_CAG_MGRTN M
    where SUBSTR(R.CARRIER_ID,2) = M.TRGT_HIER_ALGN_1_ID
		and M.SRC_HIER_ALGN_0_ID IS NOT NULL 
		and M.TRGT_PLAN_CLNT_ID NE 0
		and R.PROGRAM_ID = &PROGRAM_ID. 
        and R.TASK_ID = &TASK_ID.
	;
/*	%if &sqlobs. NE 0 %then %do;*/
	%if &is_there_migr. %then %do;


	create table &RX_RE_TBL._MIGR as
	select distinct
   		C.*, E.CLIENT_ID, SUBSTR(E.CLIENT_CD,2) AS ACCOUNT_ID, E.CLIENT_NM, D.CARRIER_ID, D.CLT_SETUP_DEF_CD,
   		CASE WHEN D.CLT_SETUP_DEF_CD IN(1,3) THEN 0 ELSE 1 END AS CLIENT_SETUP_INCLUSION_&CODE,
/*   		D.HSC_TS, D.HSU_TS*/
		DATEPART(D.HSC_TS) AS HSC_DATE, HOUR(D.HSC_TS) AS HSC_HOUR, MINUTE(D.HSC_TS) AS HSC_MIN

  		from   (select distinct
         A.INITIATIVE_ID,
         A.PHASE_SEQ_NB,
         A.PROGRAM_ID,
         A.TASK_ID,
         A.OVRD_CLT_SETUP_IN,
         A.DFLT_INCLSN_IN,
         B.DSPLY_CLT_SETUP_CD,
         B.DRG_DEFINITION_CD
        from _TABLE_1d A, &HERCULES..TPROGRAM_TASK B
       	where A.PROGRAM_ID = B.PROGRAM_ID
         and A.TASK_ID = B.TASK_ID) C, &HERCULES..&HERC_TBL2 D
		, QCPAP020.T_CLNT_CAG_MGRTN M, &CLAIMSA..TCLIENT1 E
		 where C.PROGRAM_ID = D.PROGRAM_ID
		 and C.TASK_ID = D.TASK_ID 
		 AND SUBSTR(D.CARRIER_ID,2) = M.TRGT_HIER_ALGN_1_ID
		AND E.CLIENT_ID = M.TRGT_PLAN_CLNT_ID
		AND M.TRGT_PLAN_CLNT_ID NE 0 
		 and D.PROGRAM_ID = &PROGRAM_ID. 
         and D.TASK_ID = &TASK_ID.
/*		 and D.CARRIER_ID='X8663'*/
		 and DATE() BETWEEN D.EFFECTIVE_DT AND D.EXPIRATION_DT;

	create table &RX_RE_TBL2._MIGR as
	select distinct	G.INITIATIVE_ID
		,G.PHASE_SEQ_NB
		,G.PROGRAM_ID
		,G.TASK_ID
		,G.OVRD_CLT_SETUP_IN
		,G.DFLT_INCLSN_IN
		,G.DSPLY_CLT_SETUP_CD
		,G.DRG_DEFINITION_CD
		,G.CLIENT_ID
		,G.CLIENT_NM
		,G.CARRIER_ID
		,G.CLT_SETUP_DEF_CD
		,G.CLIENT_SETUP_INCLUSION_2
		,G.HSC_DATE
		,G.HSC_HOUR
		,G.HSC_MIN
		,G.ACCOUNT_ID
		,G.GROUP_CD
		,G.INCLUDE_IN
		,H.CLIENT_CD
  		from ( select distinct E.* , &FIELD1, &FIELD2, F.GROUP_CD,
		 CASE WHEN E.CLT_SETUP_DEF_CD IN(1,3) THEN 1 ELSE 0 END AS INCLUDE_IN
        	from &RX_RE_TBL._MIGR E, &HERCULES..&HERC_TBL2 F
			where E.PROGRAM_ID = F.PROGRAM_ID
		 	and E.TASK_ID 	  = F.TASK_ID
/*		 	and E.HSC_TS     = F.HSC_TS*/
/*		 	and E.HSU_TS     = F.HSU_TS*/
			and E.HSC_DATE = DATEPART(F.HSC_TS)
			and E.HSC_HOUR = HOUR(F.HSC_TS)
			and E.HSC_MIN = MINUTE(F.HSC_TS) 
         	and E.PROGRAM_ID = &PROGRAM_ID. 
         	and E.TASK_ID    = &TASK_ID.
        	and E.CARRIER_ID = &FIELD1
			and E.ACCOUNT_ID = F.ACCOUNT_ID
		 	and DATE() BETWEEN F.EFFECTIVE_DT AND F.EXPIRATION_DT ) G 
		left join &CLAIMSA..TCLIENT1 H on G.CLIENT_ID = H.CLIENT_ID
		order by H.CLIENT_ID;
	%end;
 quit;

	%if &is_there_migr. %then %do;
*append dataset with migr clients to all others;
		proc append base = &RX_RE_TBL2.
				data = &RX_RE_TBL2._MIGR ;
		run;
	%end;
%end;

%END;

*SASDOC-------------------------------------------------------------------------
| Add formatted variables to client setup/Program Task Maintanace parameters data.
| 10MAY2008 - K.MITTAPALLI   - Hercules Version  2.1.0.1
| 02JAN2012 - RS - Add DSPLY_CLT_SETUP_CD to format for client setup report
+-----------------------------------------------------------------------SASDOC*;
%add_fmt_vars($_HERCF,
              &RX_RE_TBL2,
              _F&RX_RE_TBL2,
              F_,
              CLIENT_SETUP_INCLUSION_&CODE,
              CLT_SETUP_DEF_CD,
              INCLUDE_IN,
			  DSPLY_CLT_SETUP_CD); /* RS 1/2/12 Add for client setup report */
*SASDOC-------------------------------------------------------------------------
| Select Recap/Rxclaim formulary setup parameters.
| 10MAY2008 - K.MITTAPALLI   - Hercules Version  2.1.0.1
+-----------------------------------------------------------------------SASDOC*;
proc sql noprint;
create table &FORMAT_TBL as
select B.INITIATIVE_ID,
       B.EXT_FORMULARY_ID,
       B.FORMULARY_PRFX_CD
  from _TABLE_1d A, &HERCULES..TINIT_EXT_FORMLY B
 where A.INITIATIVE_ID eq B.INITIATIVE_ID;
quit;

*SASDOC-------------------------------------------------------------------------
| Add Recap/Rxclaim formatted variables to formulary setup parameters data.
| 10MAY2008 - K.MITTAPALLI   - Hercules Version  2.1.0.1
+-----------------------------------------------------------------------SASDOC*;
%add_fmt_vars($_HERCF,
              &FORMAT_TBL,
              _F&FORMAT_TBL);


*SASDOC-------------------------------------------------------------------------
| IF DOCUMENT_LOC_CD=1 THEN process will check on TINIT tables
| Select RECAP/REXCLAIM document setup parameters on TINIT tables.
| RECAP FOR INITIATIVE LEVEL(DOCUMENT SETUP)
|			  HERCULES.TINIT_RECP_DOC_OVR
| RXCLAIM FOR INITIATIVE LEVEL(DOCUMENT SETUP)
|			  HERCULES.TINIT_RXCM_DOC_OVR
| 10MAY2008 - K.MITTAPALLI   - Hercules Version  2.1.0.1
+-----------------------------------------------------------------------SASDOC*;
%IF &DOCUMENT_LOC_CD=1 %THEN %DO;
proc sql noprint;
create table &DOCMNT_TBL as
select B.INITIATIVE_ID,
       B.PHASE_SEQ_NB,
       B.CMCTN_ROLE_CD,
       B.LTR_RULE_SEQ_NB,
       A.PROGRAM_ID,
       A.TASK_ID,
       B.&DOC_FIELD1,
	   B.&DOC_FIELD2,
	   B.&DOC_FIELD3,
       B.APN_CMCTN_ID,
       B.HSU_TS
 from  _TABLE_1d A,
 	   &HERCULES..&DOCMNT_TBL3 B		
 where A.INITIATIVE_ID   eq B.INITIATIVE_ID
   and A.PHASE_SEQ_NB    eq B.PHASE_SEQ_NB  ;

%END;
*SASDOC-------------------------------------------------------------------------
| IF DOCUMENT_LOC_CD=2 THEN process will check on TINIT tables
| Select RECAP/REXCLAIM document setup parameters on TPGMTASK tables.
| RECAP FOR PROGRAM MAINTANANCE(DOCUMENT SETUP)
|			  HERCULES.TPGMTASK_RECAP_OVR
| RXCLAIM FOR PROGRAM MAINTANANCE(DOCUMENT SETUP)
|			  HERCULES.TPGMTASK_RXCLM_OVR
| 10MAY2008 - K.MITTAPALLI   - Hercules Version  2.1.0.1
+-----------------------------------------------------------------------SASDOC*;
%IF &DOCUMENT_LOC_CD=2 %THEN %DO;
proc sql noprint;
create table &DOCMNT_TBL as
select A.INITIATIVE_ID,
       A.PHASE_SEQ_NB,
       B.CMCTN_ROLE_CD,
       B.LTR_RULE_SEQ_NB,
       A.PROGRAM_ID,
       A.TASK_ID,
       B.&DOC_FIELD1,
	   B.&DOC_FIELD2,
	   B.&DOC_FIELD3,
       B.APN_CMCTN_ID,
       B.HSU_TS
 from  _TABLE_1d A,
       &HERCULES..&DOCMNT_TBL4 B
 where A.PROGRAM_ID   eq B.PROGRAM_ID
   and A.TASK_ID      eq B.TASK_ID 
   AND B.EFFECTIVE_DT <= TODAY()
   AND B.EXPIRATION_DT >= TODAY();
%END;

create table &DOCMNT_TBL2 as
select C.INITIATIVE_ID,
       C.PHASE_SEQ_NB,
       C.CMCTN_ROLE_CD,
       C.LTR_RULE_SEQ_NB,
       C.PROGRAM_ID,
       C.TASK_ID,
       C.&DOC_FIELD1,
	   C.&DOC_FIELD2,
	   C.&DOC_FIELD3,
       C.APN_CMCTN_ID,
       C.DESCRIPTION_TX,
       D.VERSION_TITLE_TX
  ,datepart(C.HSU_TS) as C_HSU_TS format=worddate12.
  ,D.PRODUCTION_DT as D_PRODUCTION_DT format=worddate12.
  ,D.EXPIRATION_DT as D_EXPIRATION_DT format=worddate12.
  from (
       select A.INITIATIVE_ID,
              A.PHASE_SEQ_NB,
              A.CMCTN_ROLE_CD,
              A.LTR_RULE_SEQ_NB,
              A.PROGRAM_ID,
              A.TASK_ID,
       		  A.&DOC_FIELD1,
	   		  A.&DOC_FIELD2,
	   		  A.&DOC_FIELD3,
              A.APN_CMCTN_ID,
              A.HSU_TS,
              B.DESCRIPTION_TX
         from &DOCMNT_TBL A left join
              &HERCULES..TPGM_TASK_LTR_RULE B
           on A.PROGRAM_ID      eq B.PROGRAM_ID
          and A.TASK_ID         eq B.TASK_ID
          and A.CMCTN_ROLE_CD   eq B.CMCTN_ROLE_CD
          and A.LTR_RULE_SEQ_NB eq B.LTR_RULE_SEQ_NB
          and A.PHASE_SEQ_NB    eq B.PHASE_SEQ_NB
       )
       C left join
       &HERCULES..TDOCUMENT_VERSION D
   on C.PROGRAM_ID       eq D.PROGRAM_ID
  and C.APN_CMCTN_ID     eq D.APN_CMCTN_ID
  and D.PRODUCTION_DT <= today()
  and D.EXPIRATION_DT >= today()
order by INITIATIVE_ID, PHASE_SEQ_NB,C.&DOC_FIELD1,C.&DOC_FIELD2,C.&DOC_FIELD3,CMCTN_ROLE_CD, APN_CMCTN_ID, LTR_RULE_SEQ_NB;
quit;

%IF &DOCUMENT_LOC_CD=1 %THEN %DO;
proc sql;
create table &DOCMNT_TBL5 as
select B.INITIATIVE_ID,
       B.PHASE_SEQ_NB,
       B.CMCTN_ROLE_CD,
       B.LTR_RULE_SEQ_NB,
       B.PROGRAM_ID,
       A.TASK_ID,
       B.APN_CMCTN_ID,
       B.HSU_TS,
       C.DESCRIPTION_TX,
       E.VERSION_TITLE_TX
 from  _TABLE_1d A,
       &HERCULES..TINIT_PHSE_RVR_DOM B
left join &HERCULES..TPGM_TASK_LTR_RULE C
           on B.PROGRAM_ID      eq C.PROGRAM_ID
          and B.CMCTN_ROLE_CD   eq C.CMCTN_ROLE_CD
          and B.LTR_RULE_SEQ_NB eq C.LTR_RULE_SEQ_NB
          and B.PHASE_SEQ_NB    eq C.PHASE_SEQ_NB
left join &HERCULES..TDOCUMENT_VERSION  E
   		   on C.PROGRAM_ID       eq E.PROGRAM_ID
  		  and B.APN_CMCTN_ID     eq E.APN_CMCTN_ID
  		  and E.PRODUCTION_DT <= today()
  		  and E.EXPIRATION_DT >= today()
 where A.INITIATIVE_ID eq B.INITIATIVE_ID
%END;
;quit;

%IF &DOCUMENT_LOC_CD=2 %THEN %DO;
proc sql;
create table &DOCMNT_TBL5 as
select A.INITIATIVE_ID,
       A.PHASE_SEQ_NB,
       B.CMCTN_ROLE_CD,
       B.LTR_RULE_SEQ_NB,
       B.PROGRAM_ID,
       B.TASK_ID,
       B.APN_CMCTN_ID,
       B.HSU_TS,
       C.DESCRIPTION_TX,
       E.VERSION_TITLE_TX
     from  _TABLE_1d A,
          &HERCULES..TPGM_TASK_DOM B
left join &HERCULES..TPGM_TASK_LTR_RULE C
           on B.PROGRAM_ID      eq C.PROGRAM_ID
          and B.TASK_ID         eq C.TASK_ID
          and B.CMCTN_ROLE_CD   eq C.CMCTN_ROLE_CD
          and B.LTR_RULE_SEQ_NB eq C.LTR_RULE_SEQ_NB
left join &HERCULES..TDOCUMENT_VERSION  E
   		   on C.PROGRAM_ID       eq E.PROGRAM_ID
  		  and B.APN_CMCTN_ID     eq E.APN_CMCTN_ID
  		  and E.PRODUCTION_DT <= today()
  		  and E.EXPIRATION_DT >= today()
 where A.PROGRAM_ID eq B.PROGRAM_ID
   and A.TASK_ID	eq B.TASK_ID
   AND B.EFFECTIVE_DT <= TODAY()
   AND B.EXPIRATION_DT >= TODAY()
%END;
;quit;

*SASDOC-------------------------------------------------------------------------
| Add formatted variables to document setup data.
| 10MAY2008 - K.MITTAPALLI   - Hercules Version  2.1.0.1
+-----------------------------------------------------------------------SASDOC*;
%add_fmt_vars($_HERCF,
              &DOCMNT_TBL2,
              _F&DOCMNT_TBL2,
              F_,
              CMCTN_ROLE_CD);
*SASDOC-------------------------------------------------------------------------
| Add formatted variables to Default document setup data.
| 10MAY2008 - K.MITTAPALLI   - Hercules Version  2.1.0.1
+-----------------------------------------------------------------------SASDOC*;
%add_fmt_vars($_HERCF,
              &DOCMNT_TBL5,
              _F&DOCMNT_TBL5,
              F_,
              CMCTN_ROLE_CD);


proc sql;
drop table &RX_RE_TBL;
drop table &RX_RE_TBL2;
drop table &FORMAT_TBL;
drop table &DOCMNT_TBL;
drop table &DOCMNT_TBL2;
drop table &DOCMNT_TBL5;
quit;
run;
%mend RX_RE_process;	
%macro process1;
%IF &RE_ADJ EQ 1 %THEN 
%RX_RE_process(_TABLE_3_1_RE
			  ,_TABLE_3_RE
			  ,_table_7_1_RE
			  ,_TABLE_8_1_RE
			  ,_TABLE_8_RE
			  ,_TABLE_8_2_RE
			  ,TINIT_RECAP_CLT_RL
			  ,TPGMTASK_RECAP_RUL
			  ,F.INSURANCE_CD
			  ,F.CARRIER_ID
			  ,3
			  ,INSURANCE_CD
			  ,CARRIER_ID
			  ,GROUP_CD
			  ,TINIT_RECP_DOC_OVR
			  ,TPGMTASK_RECAP_OVR);
%IF &RX_ADJ EQ 1 %THEN 
%RX_RE_process(_TABLE_3_1_RX
			  ,_TABLE_3_RX
			  ,_table_7_1_RX
			  ,_TABLE_8_1_RX
			  ,_TABLE_8_RX
			  ,_TABLE_8_2_RX
			  ,TINIT_RXCLM_CLT_RL
			  ,TPGMTASK_RXCLM_RUL
			  ,F.CARRIER_ID
			  ,F.ACCOUNT_ID
			  ,2
			  ,CARRIER_ID
			  ,ACCOUNT_ID
			  ,GROUP_CD
			  ,TINIT_RXCM_DOC_OVR
			  ,TPGMTASK_RXCLM_OVR);
%IF &QL_ADJ EQ 1 %THEN %QL_process;
%mend process1;
%process1;
*SASDOC-------------------------------------------------------------------------
| Select drug setup parameters.
+-----------------------------------------------------------------------SASDOC*;
proc sql noprint;
create table _TABLE_4_1 as
select
   C.*,
   D.DRG_GROUP_SEQ_NB,
   D.DRUG_GROUP_DSC_TX,
   D.EXCLUDE_OTC_IN,
   D.OPERATOR_TX
  from
      (
      select distinct
         A.INITIATIVE_ID,
         A.PHASE_SEQ_NB as INIT_PHASE_SEQ_NB,
         A.PROGRAM_ID,
         A.TASK_ID,
         B.DRG_DEFINITION_CD
        from _TABLE_1d A,
             &HERCULES..TPROGRAM_TASK B
       where A.PROGRAM_ID    eq B.PROGRAM_ID
         and A.TASK_ID       eq B.TASK_ID
      )
       C left join
       &HERCULES..TINIT_DRUG_GROUP D
    on C.INITIATIVE_ID eq D.INITIATIVE_ID;

create table _TABLE_4_2 as
select
   G.*,
   H.DRG_SUB_GRP_SEQ_NB,
   H.DRG_SUB_GRP_DSC_TX,
   H.SAVINGS_IN,
   H.NUMERATOR_IN,
   H.BRD_GNRC_OPT_CD,
   H.ALL_DRUG_IN
  from
      (
      select
         E.*,
         F.PHASE_SEQ_NB as DRUG_PHASE_SEQ_NB,
         F.CLAIM_BEGIN_DT,
         F.CLAIM_END_DT
        from
             _TABLE_4_1 E left join
             &HERCULES..TPHASE_DRG_GRP_DT F
          on E.INITIATIVE_ID    eq F.INITIATIVE_ID
         and E.DRG_GROUP_SEQ_NB eq F.DRG_GROUP_SEQ_NB
      )
       G left join
     &HERCULES..TINIT_DRUG_SUB_GRP H
    on G.INITIATIVE_ID    eq H.INITIATIVE_ID
   and G.DRG_GROUP_SEQ_NB eq H.DRG_GROUP_SEQ_NB;

create table _TABLE_4 as
select
   I.*,
   J.DRUG_ID_TYPE_CD,
   J.DRUG_ID,
   J.INCLUDE_IN,
   J.DRG_GRP_DTL_TX
  from _TABLE_4_2 I left join &HERCULES..TDRUG_SUB_GRP_DTL J
    on I.INITIATIVE_ID      eq J.INITIATIVE_ID
   and I.DRG_GROUP_SEQ_NB   eq J.DRG_GROUP_SEQ_NB
   and I.DRG_SUB_GRP_SEQ_NB eq J.DRG_SUB_GRP_SEQ_NB
order by I.INITIATIVE_ID, I.DRG_GROUP_SEQ_NB, I.DRG_SUB_GRP_SEQ_NB;
quit;

*SASDOC-------------------------------------------------------------------------
| Add formatted variables to drug setup parameters data.
+-----------------------------------------------------------------------SASDOC*;
%add_fmt_vars($_HERCF,
              _TABLE_4,
              _F_TABLE_4,
              F_,
              DRG_DEFINITION_CD,
              EXCLUDE_OTC_IN,
              SAVINGS_IN,
              NUMERATOR_IN,
              BRD_GNRC_OPT_CD,
              ALL_DRUG_IN,
              DRUG_ID_TYPE_CD,
              INCLUDE_IN);

*SASDOC-------------------------------------------------------------------------
| Add concatenated drug group and subgroup columns to drug setup data.
+-----------------------------------------------------------------------SASDOC*;
proc sql noprint;
create table C_F_TABLE_4 as
select
   PROGRAM_ID,
   DRG_GROUP_SEQ_NB,
      "^S={font_weight=bold}"||compress(put(DRG_GROUP_SEQ_NB,8.))||
         "^S={font_weight=medium}^_^m"||trim(left(DRUG_GROUP_DSC_TX)) as
      C_DRUG_GROUP_SEQ_NB_DSC_TX,
   DRUG_PHASE_SEQ_NB,
   CLAIM_BEGIN_DT,
   CLAIM_END_DT,
   put(CLAIM_BEGIN_DT,dt.)||"^n"||put(CLAIM_END_DT,dt.) as C_CLAIM_BEGIN_END_DT,
   F_EXCLUDE_OTC_IN,
   OPERATOR_TX,
   DRG_SUB_GRP_SEQ_NB,
   "^S={font_weight=bold}"||compress(put(DRG_SUB_GRP_SEQ_NB,8.))||
      "^S={font_weight=medium}^_^m"||trim(left(DRG_SUB_GRP_DSC_TX)) as
      C_DRG_SUB_GRP_SEQ_NB_DSC_TX,
   F_BRD_GNRC_OPT_CD,
   compress(F_NUMERATOR_IN||'/'||F_SAVINGS_IN) as C_F_NUMERATOR_SAVINGS_IN,
   F_DRUG_ID_TYPE_CD,
   DRUG_ID,
   case (ALL_DRUG_IN)
      when 1 then F_ALL_DRUG_IN
      else
         case (compress(F_DRUG_ID_TYPE_CD) eq '')
            when 1 then
               ''
            else
               compress(F_DRUG_ID_TYPE_CD||'/'||DRUG_ID)
         end
   end as C_F_DRUG_ID_TYPE_CD,
   F_INCLUDE_IN,
   DRG_GRP_DTL_TX,
   F_ALL_DRUG_IN
  from _F_TABLE_4
order by PROGRAM_ID, DRG_GROUP_SEQ_NB, DRG_SUB_GRP_SEQ_NB, F_DRUG_ID_TYPE_CD, DRUG_ID;
quit;

*SASDOC-------------------------------------------------------------------------
| Select prescriber setup parameters.
+-----------------------------------------------------------------------SASDOC*;
proc sql noprint;
create table _TABLE_5_1 as
select D.INITIATIVE_ID,
       D.SPECIALTY_CD,
       D.INCLUDE_IN,
       C.LONG_TX as F_SPECIALTY_CD
  from &CLAIMSA..TCHR3_CHR_THREE_CD C
       right join
      (
      select B.INITIATIVE_ID,
             B.SPECIALTY_CD,
             B.INCLUDE_IN
        from _TABLE_1d A,
             &HERCULES..TINIT_PRSCBR_SPLTY B
       where A.INITIATIVE_ID eq B.INITIATIVE_ID
      ) D
   on C.CHAR_THREE_TYPE_CD eq 'SPC'
  and C.CHAR_THREE_CD      eq D.SPECIALTY_CD;

create table _TABLE_5_2 as
select B.INITIATIVE_ID,
       B.MIN_PATIENTS_QY,
       B.MAX_PATIENTS_QY,
       B.MIN_RX_QY,
       B.MAX_RX_QY,
       B.OPERATOR_TX
  from _TABLE_1d A, &HERCULES..TINIT_PRSCBR_RULE B
 where A.INITIATIVE_ID eq B.INITIATIVE_ID;

create table _TABLE_5 as
select distinct INITIATIVE_ID
from
   (select distinct INITIATIVE_ID
    from   _TABLE_5_1
    union
    select distinct INITIATIVE_ID
    from   _TABLE_5_2);
quit;

*SASDOC-------------------------------------------------------------------------
| Add formatted variables to prescriber setup parameters data.
+-----------------------------------------------------------------------SASDOC*;
%add_fmt_vars($_HERCF,
              _TABLE_5_1,
              _F_TABLE_5_1,
              F_,
              INCLUDE_IN);

*SASDOC-------------------------------------------------------------------------
| Select participant setup parameters.
+-----------------------------------------------------------------------SASDOC*;
proc sql noprint;
create table _table_6_1 as
select B.INITIATIVE_ID,
       B.PRTCPNT_RL_SEQ_NB,
       B.MINIMUM_AGE_AT,
       B.MAXIMUM_AGE_AT,
       B.PRTCPNT_MIN_RX_QY,
       B.PRTCPNT_MAX_RX_QY,
       B.INCLUDE_IN,
       B.GENDER_OPTION_CD,
       B.OPERATOR_TX,
       B.MIN_MEMBER_COST_AT,
       B.MAX_MEMBER_COST_AT,
       B.OPERATOR_2_TX,
	   B.MIN_ESM_SAVE_AT,
	   B.MIN_GROSS_SAVE_AT,
	   B.PLAN_PRTCPNT_AT
  from _TABLE_1d A, &HERCULES..TINIT_PRTCPNT_RULE B
 where A.INITIATIVE_ID eq B.INITIATIVE_ID;
quit;

*SASDOC-------------------------------------------------------------------------
| Add formatted variables to participant setup parameters data.
+-----------------------------------------------------------------------SASDOC*;
%add_fmt_vars($_HERCF,
              _TABLE_6_1,
              _F_TABLE_6_1,
              F_,
              INCLUDE_IN,
              GENDER_OPTION_CD);
*SASDOC-------------------------------------------------------------------------
| Select iBenefit parameters.
| 02JAN2021 - RS - added union to handle new PSG (MSS)specific table
+-----------------------------------------------------------------------SASDOC*;
proc sql noprint;
create table _TABLE_9 as
      select distinct
         A.INITIATIVE_ID,
         A.PHASE_SEQ_NB,
		 CASE
         WHEN B.EXCL_MAIL_IN IS NULL THEN 0
		 ELSE B.EXCL_MAIL_IN
		 END	AS	EXCL_MAIL_IN,
		 CASE
		 WHEN B.EXCL_GENC_IN IS NULL THEN 0
		 ELSE B.EXCL_GENC_IN
		 END	AS	EXCL_GENC_IN,
		 CASE
		 WHEN B.EXCL_PREFR_IN IS NULL THEN 0
		 ELSE B.EXCL_PREFR_IN
		 END  	AS	EXCL_PREFR_IN,
         CASE
		 WHEN B.SENIOR_AGE_NB IS NULL THEN 0
		 ELSE B.SENIOR_AGE_NB
		 END 	AS SENIOR_AGE_NB,
		 C.MODULE_NB,
		 C.MESSAGE_ID,
		 'N/A' AS DATA_DRIVEN_TX
        from _TABLE_1d A
   	left join &HERCULES..TINIT_IBNFT_OPTN B
          on A.INITIATIVE_ID eq B.INITIATIVE_ID
         and A.PHASE_SEQ_NB  eq B.PHASE_SEQ_NB
   	left join &HERCULES..TINIT_MODULE_MSG  C
		  on A.INITIATIVE_ID eq C.INITIATIVE_ID
		 and A.PHASE_SEQ_NB  eq C.PHASE_SEQ_NB 
    WHERE C.MODULE_NB IS NOT MISSING 
	UNION   /* 1/2/12 RS Added for PSG (MSS) specifc parameters */
	select distinct
         A.INITIATIVE_ID,
         A.PHASE_SEQ_NB,
		 CASE
         WHEN B.EXCL_MAIL_IN IS NULL THEN 0
		 ELSE B.EXCL_MAIL_IN
		 END	AS	EXCL_MAIL_IN,
		 CASE
		 WHEN B.EXCL_GENC_IN IS NULL THEN 0
		 ELSE B.EXCL_GENC_IN
		 END	AS	EXCL_GENC_IN,
		 CASE
		 WHEN B.EXCL_PREFR_IN IS NULL THEN 0
		 ELSE B.EXCL_PREFR_IN
		 END  	AS	EXCL_PREFR_IN,
         CASE
		 WHEN B.SENIOR_AGE_NB IS NULL THEN 0
		 ELSE B.SENIOR_AGE_NB
		 END 	AS SENIOR_AGE_NB,
		 D.MODULE_NB,
		 D.MESSAGE_ID,
		 CASE
		 WHEN D.DATA_DRIVEN_TX IS NULL THEN 'N/A'
		 WHEN D.DATA_DRIVEN_TX = '0' THEN 'YES'
		 ELSE 'N/A'
		 END AS DATA_DRIVEN_TX
        from _TABLE_1d A
   	left join &HERCULES..TINIT_IBNFT_OPTN B
          on A.INITIATIVE_ID eq B.INITIATIVE_ID
         and A.PHASE_SEQ_NB  eq B.PHASE_SEQ_NB   
   	left join &HERCULES..TINIT_MOD3_DAT_IBEN3 D
		  on A.INITIATIVE_ID eq D.INITIATIVE_ID
		 and A.PHASE_SEQ_NB  eq D.PHASE_SEQ_NB
	WHERE D.MODULE_NB IS NOT MISSING
   ORDER BY 7;	

quit;

*SASDOC-------------------------------------------------------------------------
| Add formatted variables to client setup parameters data.
+-----------------------------------------------------------------------SASDOC*;
%add_fmt_vars($_HERCF,
              _TABLE_9,
              _F_TABLE_9
			   );

*SASDOC-------------------------------------------------------------------------
| PSG (MSS) specfic parameters 
| 02JAN2012 - RS - Added doc box for PSG (MSS) macro - Executed only for task 59
+-----------------------------------------------------------------------SASDOC*;
%macro ibenefit3_sql_section;
	%if &task_id = 59 %then %do;

		%put NOTE: The initiative summary report is a iBenefit 3 initiative. ;

		proc sql noprint;
		create table _TABLE_11 as
		      select distinct
		         A.INITIATIVE_ID,
		         A.PHASE_SEQ_NB,
				 CASE
				 WHEN B.INCL_HIST_SPEND_IN = 1 then 'Exclude'
				 ELSE 'Include'
				 END AS INCL_HIST_SPEND_IN,
				 'N/A' as INCL_MED_EXP_IN,
				 B.PROJECT_PER_FRM_DT,
				 B.PROJECT_PER_TO_DT,				 
				 CASE
				 WHEN B.SAME_BASLINE_IN = 1 then 'Exclude'
				 ELSE 'Include'
				 END AS SAME_BASLINE_IN,
				 CASE
				 WHEN B.STACK_CLAIM_IN = 1 then 'Exclude'
				 ELSE 'Include'
				 END AS STACK_CLAIM_IN,
				 CASE
				 WHEN B.INCL_CURR_ACCT_IN = 1 then 'Exclude'
				 ELSE 'Include'
				 END AS INCL_CURR_ACCT_IN,
				 CASE
				 WHEN B.INCL_DRG_MAINT_IN = 1 then 'Exclude'
				 ELSE 'Include'
				 END AS INCL_DRG_MAINT_IN,
				 CASE
				 WHEN B.INCL_DRG_ACUTE_IN = 1 then 'Exclude'
				 ELSE 'Include'
				 END AS INCL_DRG_ACUTE_IN,
				 CASE
				 WHEN B.INCL_DRG_SUBST_IN = 1 then 'Exclude'
				 ELSE 'Include'
				 END AS INCL_DRG_SUBST_IN,
				 CASE
				 WHEN B.INCL_DRG_SPEC_IN = 1 then 'Exclude'
				 ELSE 'Include'
				 END AS INCL_DRG_SPEC_IN,
				 CASE
				 WHEN B.INCL_DRG_GENER_IN = 1 then 'Exclude'
				 ELSE 'Include'
				 END AS INCL_DRG_GENER_IN,
				 CASE
				 WHEN B.INCL_DRG_FORM_IN = 1 then 'Exclude'
				 ELSE 'Include'
				 END AS INCL_DRG_FORM_IN,
				 CASE
				 WHEN B.INCL_DRG_BRAND_IN = 1 then 'Exclude'
				 ELSE 'Include'
				 END AS INCL_DRG_BRAND_IN,	
				 CASE 
				 WHEN B.INCL_DRG_OTC_IN = 1 then 'Exclude'
				 ELSE 'Include'
				 END AS INCL_DRG_OTC_IN
		        from _TABLE_1d A
		   left join &HERCULES..TINIT_MOD3_PRM_IBEN3 B
		          on A.INITIATIVE_ID eq B.INITIATIVE_ID
		         and A.PHASE_SEQ_NB  eq B.PHASE_SEQ_NB ;	

		quit;


		proc sql noprint;
		create table _TABLE_12 as
		      select distinct
		         A.INITIATIVE_ID,
		         A.PHASE_SEQ_NB, 
				 CASE
				 WHEN B.INCL_CHL_MAINT_IN = 1 then 'Exclude'
				 ELSE 'Include'
				 END AS INCL_CHL_MAINT_IN,
				 CASE
				 WHEN B.INCL_CHL_SPEC_IN = 1 then 'Exclude'
				 ELSE 'Include'
				 END AS INCL_CHL_SPEC_IN,
				 CASE
				 WHEN B.INCL_CHL_DEF_IN = 1 then 'Exclude'
				 ELSE 'Include'
				 END AS INCL_CHL_DEF_IN,
				 CASE
				 WHEN B.INCL_CHL_CVS90_IN = 1 then 'Exclude'
				 ELSE 'Include'
				 END AS INCL_CHL_CVS90_IN,
				 B.PREF_MFR_CD
		        from _TABLE_1d A
		   left join &HERCULES..TINIT_MOD3_PRM_IBEN3 B
		          on A.INITIATIVE_ID eq B.INITIATIVE_ID
		         and A.PHASE_SEQ_NB  eq B.PHASE_SEQ_NB ;	

		quit;


		*SASDOC-------------------------------------------------------------------------
		| Add formatted variables to client setup parameters data.
		+-----------------------------------------------------------------------SASDOC*;
		%add_fmt_vars($_HERCF,
		              _TABLE_11,
		              _F_TABLE_11
					   );

		%add_fmt_vars($_HERCF,
		              _TABLE_12,
		              _F_TABLE_12
					   );
	%end;
	%else %do;
		%put NOTE: The initiative summary report is not a iBenefit 3 initiative. ;
	%end;
%mend ibenefit3_sql_section;
%ibenefit3_sql_section; 

*SASDOC-------------------------------------------------------------------------
| 
| 06DEC2012 - SB - Added Negative Formulary specific parameters 
+-----------------------------------------------------------------------SASDOC*;
%macro negative_formulary;
	%if &program_id = 5246 %then %do;

		%put NOTE: The initiative summary report is a Negative Formulary initiative. ;

		proc sql noprint;
		create table _TABLE_13 as
		      select distinct
		         A.INITIATIVE_ID,
		         A.PHASE_SEQ_NB,
				 CASE 
				 	WHEN B.EOB_INDICATOR=1 THEN 'Enabled'
					ELSE 'Disabled'
					END AS EOB_INDICATOR,
				 B.EOB_DESCRIPTION,
				 put(B.EOB_BEGIN_DT,dt.) AS EOB_BEGIN_DT,
				 put(B.EOB_END_DT,dt.) AS EOB_END_DT,
				 CASE 
					WHEN B.EOB_RUN_SEQ=1 THEN 'First Run'
					WHEN B.EOB_RUN_SEQ=2 THEN 'Catch-Up Run'
					WHEN B.EOB_RUN_SEQ=3 THEN 'Periodic Run'
					ELSE 'N/A'
					END AS EOB_RUN_SEQ,
				 CASE 
					WHEN B.EOB_RUN_SEQ=1 THEN 'N/A'
					ELSE put(B.FIRST_RUN_INIT, 6.)
					END AS FIRST_RUN_INIT
				from _TABLE_1d A
		   left join QCPAP020.TEOB_FILTER_DTL B
		          on A.INITIATIVE_ID eq B.INITIATIVE_ID
		       	;	

		quit;
		*SASDOC-------------------------------------------------------------------------
		| Add formatted variables to client setup parameters data.
		+-----------------------------------------------------------------------SASDOC*;
		%add_fmt_vars($_HERCF,
		              _TABLE_13,
		              _F_TABLE_13
					   );
	%end;
	%else %do;
		%put NOTE: The initiative summary report is not Negative Formulary initiative. ;
	%end;
%mend negative_formulary;
%negative_formulary; 
 
*SASDOC-------------------------------------------------------------------------
| Select Additional parameters.
+-----------------------------------------------------------------------SASDOC*;
proc sql noprint;
create table _TABLE_10 as
      select distinct
         A.INITIATIVE_ID,
         A.PHASE_SEQ_NB,
		 CASE
         WHEN C.FIELD_NM IS NULL THEN 'N/A'
		 ELSE C.FIELD_NM
		 END	AS	ADDITIONAL_FIELD_NM,
		 CASE
         WHEN C.SHORT_TX IS NULL THEN 'N/A'
		 ELSE C.SHORT_TX
		 END	AS	ADDITIONAL_SHORT_TX_FIELD
        from _TABLE_1d A
   left join &HERCULES..TINIT_ADHOC_FIELD   B
          on A.INITIATIVE_ID eq B.INITIATIVE_ID
         and A.PHASE_SEQ_NB  eq B.PHASE_SEQ_NB
   left join &HERCULES..TFIELD_DESCRIPTION  C
		  on B.FIELD_ID eq C.FIELD_ID;	
quit;

*SASDOC-------------------------------------------------------------------------
| Add formatted variables to Additional parameters data.
+-----------------------------------------------------------------------SASDOC*;
%add_fmt_vars($_HERCF,
              _TABLE_10,
              _F_TABLE_10
			   );			   

options orientation=landscape nodate number missing='' linesize=179 pagesize=65
        leftmargin  ="0.35in"
        rightmargin ="0.00in"
        topmargin   ="0.00in"
        bottommargin="0.00in";
ods listing close;
ods pdf file     =RPTFL
        startpage=off
        style    =my_pdf
        notoc;
ods escapechar "^";
title1 j=r "^S={font_face=&_tbl_fnt
                font_size=9pt
                font_weight=bold}%sysfunc(datetime(),dttime.)^_^_^_^_^_Page^S={}";
title2 j=c "^S={font_face=&_tbl_fnt
                font_size=12pt
                font_weight=bold}Hercules Communication Engine^S={}";
title3 j=c "^S={font_face=&_tbl_fnt
                font_size=14pt
                font_weight=bold}Initiative Summary Parameter Report^S={}";
title4 " ";
title5 j=l "^S={font_face  =&_tbl_fnt
                font_size  =11pt
                foreground =&_hdr_fg
                font_weight=bold}Initiative - Phase:^_^_^S={
                font_face  =&_tbl_fnt
                font_size  =11pt
                font_weight=bold}&_T_INIT_PHASE^_^_^_^_^_^S={}"
           "^S={font_face  =&_tbl_fnt
                font_size  =11pt
                foreground =&_hdr_fg
                font_weight=bold}Program:^_^_^S={
                font_face  =&_tbl_fnt
                font_size  =11pt
                font_weight=bold}&_T_PROGRAM^S={}";
footnote1;

*SASDOC-------------------------------------------------------------------------
| Produce a report of initiative phase summary.
+-----------------------------------------------------------------------SASDOC*;
ods proclabel="Initiative Summary Parameter Report";
proc report
   contents='Initiative Summary'
   data=_F_TABLE_1
   missing
   noheader
   nowd
   split="*"
   style(report)=[rules       =none
                  frame       =void
                  just        =l
                  cellspacing =0.00in
                  cellpadding =0.00in
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =10pt
                  font_face   ="&_tbl_fnt"];
column
   L_TASK_ID
   F_TASK_ID
   L_BUS_RQSTR_NM
   BUS_RQSTR_NM
   TITLE_TX
   L_DESCRIPTION_TX
   DESCRIPTION_TX
   DELIVERY_SYSTEM_STR
   INITIATIVE_HSC_USR_ID
   PHASE_HSC_USR_ID
   JOB_SCHEDULED_TS
   JOB_START_TS
   JOB_COMPLETE_TS;
define L_TASK_ID           / computed page
   style=[cellwidth  =0.40in
          font_weight=bold
          foreground =&_hdr_fg
          just=l
          pretext="Task:"];
compute L_TASK_ID          / char length=1;
   L_TASK_ID='';
endcomp;
define F_TASK_ID           / group
   style=[cellwidth=3.20in
          just     =l];
define L_BUS_RQSTR_NM      / computed
   style=[cellwidth  =1.55in
          font_weight=bold
          foreground =&_hdr_fg
          just       =l
          pretext    ="^S={}^_^_Business Requestor:^S={}"];
compute L_BUS_RQSTR_NM     / char length=1;
   L_BUS_RQSTR_NM='';
endcomp;
define BUS_RQSTR_NM        / group
   style=[cellwidth=2.35in
          just     =l];
define TITLE_TX            / group page
   style=[cellwidth  =7.50in
          font_weight=medium
          just       =l
          pretext    ="^S={font_weight=bold
                           foreground =&_hdr_fg}Title:^_^S={}"];
define L_DESCRIPTION_TX    / computed page
   style=[cellwidth  =0.85in
          font_weight=bold
          foreground =&_hdr_fg
          just       =l
          pretext    ="Description:"];
compute L_DESCRIPTION_TX   / char length=1;
   L_DESCRIPTION_TX='';
endcomp;
define DESCRIPTION_TX      /  group
   style=[cellwidth=6.65in
          just     =l];
define DELIVERY_SYSTEM_STR / group page
   style=[cellwidth  =6.65in
          font_weight=medium
          just       =l
          pretext    ="^S={font_weight=bold
                           foreground=&_hdr_fg}Exclude Delivery Systems:^_^_^S={}"];
define INITIATIVE_HSC_USR_ID/ group page
   style=[cellwidth  =2.75in
          font_weight=medium
          just       =l
          pretext    ="^S={font_weight=bold
                           foreground=&_hdr_fg}Initiative Requestor:^_^_^S={}"];
define PHASE_HSC_USR_ID     / group
   style=[cellwidth  =4.75in
          font_weight=medium
          just       =l
          pretext    ="^S={font_weight=bold
                           foreground =&_hdr_fg}Phase Requestor:^_^_^S={}"];
define JOB_SCHEDULED_TS    / group format=dttime.
   style=[cellwidth  =2.75in
          font_weight=medium
          just       =l
          pretext    ="^S={font_weight=bold
                           foreground =&_hdr_fg}Job Scheduled:^_^_^S={}"];
define JOB_START_TS        / group format=dttime.
   style=[cellwidth  =2.40in
          font_weight=medium
          just       =l
          pretext    ="^S={font_weight=bold
                           foreground =&_hdr_fg}Job Start:^_^_^S={}"];
define JOB_COMPLETE_TS     / group format=dttime.
   style=[cellwidth  =2.35in
          font_weight=medium
          just       =l
          pretext    ="^S={font_weight=bold
                           foreground =&_hdr_fg}Job Complete:^_^_^S={}"];
run;
quit;
ods proclabel=" ";
/****************************************************
 **** FOR TESTING ONLY
 ***************************************************/
/*DATA _F_TABLE_1;*/
/*  SET _F_TABLE_1;*/
/*  MBR_ID_REUSE_QY=&MBR_ID_REUSE_OTY;*/
/*RUN;*/

*SASDOC-------------------------------------------------------------------------
| 02FEB2009 - G.D.
| Added the column MBR_ID_REUSE_QY to the report
| 02FEB2009 - G.D.
| Changed the Cell width to 1.70in for columns REJECTED_QY, MBR_ID_REUSE_QY
| ACCEPTED_QY, SUSPENDED_QY and LETTERS_SENT_QY so all columns would fit on 
| one line.  A "*" was added to the column titles to wrap text to mutiple
| lines.
+-----------------------------------------------------------------------SASDOC*;
proc report
   contents='Receiver Component'
   data=_F_TABLE_1
   missing
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =9pt
                  font_face   =&_tbl_fnt];
column
   F_CMCTN_ROLE_CD
   F_DATA_CLEANSING_CD
   F_FILE_USAGE_CD
   F_DESTINATION_CD
   F_RELEASE_STATUS_CD
   F_CMCTN_ROLE_CD
   REJECTED_QY
   MBR_ID_REUSE_QY
   ACCEPTED_QY
   SUSPENDED_QY
   LETTERS_SENT_QY;
define F_CMCTN_ROLE_CD      / display page
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Receiver^S={}"
   style=[cellwidth=1.59in
          font_weight=bold
          just=l];
define F_DATA_CLEANSING_CD  / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Data Cleansing^S={}"
   style=[cellwidth=2.16in
          font_weight=medium
          just=l];
define F_FILE_USAGE_CD      / display
   "^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}File Usage^S={}"
   style=[cellwidth=2.17in
          font_weight=medium
          just=l];
define F_DESTINATION_CD     / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Destination^S={}"
   style=[cellwidth=2.29in
          font_weight=medium
          just=l];
define F_RELEASE_STATUS_CD  / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Release Status^S={}"
   style=[cellwidth=1.99in
          font_weight=medium
          just=l];
define REJECTED_QY          / analysis format=comma14.
   "^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Initial*Records*Rejected^S={}"
   style=[cellwidth=1.70in
          font_size=10pt
          font_weight=medium
          just=c];
define MBR_ID_REUSE_QY          / analysis format=comma14.
   "^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Mbr ID*Reuse Records*Rejected^S={}"
   style=[cellwidth=1.70in
          font_size=10pt
          font_weight=medium
          just=c];
define ACCEPTED_QY          / analysis format=comma14.
   "^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Initial*Records*Accepted^S={}"
   style=[cellwidth=1.70in
          font_size=10pt
          font_weight=medium
          just=c];
define SUSPENDED_QY         / analysis format=comma14.
   "^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Initial*Records*Suspended^S={}"
   style=[cellwidth=1.70in
          font_size=10pt
          font_weight=medium
          just=c];
define LETTERS_SENT_QY      / analysis format=comma14.
   "^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Letters Mailed^S={}"
   style=[cellwidth=1.70in
          font_size=10pt
          font_weight=medium
          rightmargin=0.50in
          just=c];
run;
quit;


*SASDOC-------------------------------------------------------------------------
| Produce a report of communications component.
+-----------------------------------------------------------------------SASDOC*;
ods proclabel=" ";
proc report
   contents='Communications Component'
   data=_T_F_TABLE_2
   missing
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  font_size   =10pt
                  font_face   =&_tbl_fnt
                  just        =l
                  cellspacing =0.00in
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =10pt
                  font_face   =&_tbl_fnt];
format COMPONENT $compf.;
column
   COMPONENT
   COMPONENT_VAL;
define COMPONENT            / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Communication Component^S={}"
   style=[cellwidth=3.25in
          font_weight=bold
          just=l];
define COMPONENT_VAL        / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Status^S={}"
   style=[cellwidth=1.75in
          font_weight=medium
          just=l];
run;
quit;
%macro QL_clnt_rpt;
*SASDOC----------------------------------------------------------------------------
| Produce a report of client setup/Program Maintanace setup component for QL Report.
+---------------------------------------------------------------------------SASDOC*;
ods proclabel=" ";
proc sql noprint;
select (   (max(CLIENT_SETUP_INCLUSION_CD) ne 0)
        or (max(CLIENT_ID) is not missing      )   ) format=1.
  into :_COMP_TTL_F_TABLE_3
  from WORK._F_TABLE_3
quit;

*SASDOC----------------------------------------------------------------------------
| QL Client Setup Heading 
| 02JAN2012 - RS - Modify to format and decode based on on client setup type.
|                  This will prevent segmentation error
+---------------------------------------------------------------------------SASDOC*;

%macro COMP_TTL_F_TABLE_3;

%PUT NOTE: DSPLY_CLT_SETUP_CD = &DSPLY_CLT_SETUP_CD;   /* 1/2/2012 RS - Display setup type */

%if (&_COMP_TTL_F_TABLE_3 ne 0) %then
%do;
 %if (&DSPLY_CLT_SETUP_CD=1 OR &DSPLY_CLT_SETUP_CD=2 OR &DSPLY_CLT_SETUP_CD=3) %then %do; /* 1/2/2012 RS - added setup code 2 and 3 */
/* 01/10/12 RAS - Added following to prevent segmentation error - Display QL Client Setup and type of setup */
   PROC SQL NOPRINT;
  		SELECT 'QL Client Setup: '
      	INTO :CLT_DESC
   FROM WORK._F_TABLE_3
   QUIT;
   %comp_ttl(_F_TABLE_3,&CLT_DESC.,F_DSPLY_CLT_SETUP_CD,_DISPLAY=Y);
/*   %comp_ttl(_F_TABLE_3,&CLT_DESC.,CLIENT_ID,_DISPLAY=Y);  1/2/12 RS commented out*/
 %end;
 %else %do;  /* 1/2/2012 - This code executes for client setup code other than 1,2,3 - 4 which is N/A - This part is does not work correctly, but now does not fail */
   PROC SQL NOPRINT;
  		SELECT 'QL Program Maintanance Setup: '||F_CLIENT_SETUP_INCLUSION_CD
      	INTO :CLT_DESC
  	from WORK._F_TABLE_3
	QUIT;
/* 01/10/12 RAS - Added following to prevent segmentation error */
/* 01/10/12 RAS %comp_ttl(_F_TABLE_3,Program Maintanance Setup,F_CLIENT_SETUP_INCLUSION_CD,_DISPLAY=Y); */
   %comp_ttl(_F_TABLE_3,&CLT_DESC.,CLIENT_ID,_DISPLAY=Y); 
 %end;
%end;
%mend COMP_TTL_F_TABLE_3;
%COMP_TTL_F_TABLE_3;

proc report
   contents='Client Setup'
   data=_F_TABLE_3
      (where=(CLIENT_ID ne .))
   missing
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =8pt
                  font_face   =&_tbl_fnt];

column
   CLIENT_ID
   CLIENT_NM
   F_CLT_SETUP_DEF_CD
   F_INCLUDE_IN
   GROUP_CLASS_CD
   GROUP_CLASS_SEQ_NB
   BLG_REPORTING_CD
   PLAN_CD_TX
   PLAN_EXT_CD_TX
   GROUP_CD_TX
   GROUP_EXT_CD_TX
   PLAN_GROUP_NM;
define CLIENT_ID                   / group page
   "^S={font_weight=bold
        font_size  =9pt
        background =&_hdr_bg
        just       =c}Client ID^S={}"
   style=[cellwidth  =0.69in
          font_weight=medium
          font_size  =9pt
          just       =r];
define CLIENT_NM                   / group
   "^S={font_weight=bold
        font_size  =9pt
        background =&_hdr_bg
        just       =c}Client Name^S={}"
   style=[cellwidth=1.39in
          font_weight=medium
          just=l];
define F_CLT_SETUP_DEF_CD          / group
   "^S={font_weight=bold
        font_size  =9pt
        background =&_hdr_bg
        just       =c}Client Setup*Definition^S={}"
   style=[cellwidth=0.89in
          font_size  =8pt
          font_weight=medium
          just=l];
define F_INCLUDE_IN                / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Include/*Exclude^S={}"
   style=[cellwidth=0.61in
          font_weight=medium
          just=l];
define GROUP_CLASS_CD              / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Rpt Grp^S={}"
   style=[cellwidth=0.54in
          font_weight=medium
          just=r];
define GROUP_CLASS_SEQ_NB          / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Seq^S={}"
   style=[cellwidth=0.54in
          font_weight=medium
          just=r];
define BLG_REPORTING_CD            / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Billing*Report*Code^S={}"
   style=[cellwidth=0.89in
          font_weight=medium
          just=r];
define PLAN_CD_TX                  / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Plan Code^S={}"
   style=[cellwidth=0.89in
          font_weight=medium
          just=r];
define PLAN_EXT_CD_TX              / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Plan*Ext*Code^S={}"
   style=[cellwidth=0.69in
          font_weight=medium
          just=r];
define GROUP_CD_TX                 / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Group Code^S={}"
   style=[cellwidth=1.09in
          font_weight=medium
          just=r];
define GROUP_EXT_CD_TX             / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Group*Ext*Code^S={}"
   style=[cellwidth=0.69in
          font_weight=medium
          just=r];
define PLAN_GROUP_NM                 / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Plan*Group*Name^S={}"
   style=[cellwidth=1.19in
          font_weight=medium
          just=r];          
run;
quit;
%mend QL_clnt_rpt;
*SASDOC----------------------------------------------------------------------------
| Call checkinsurancecodeinitiative Macro for RECAP client Initiative
| 10MAY2008 - K.MITTAPALLI   - Hercules Version  2.1.0.1
+---------------------------------------------------------------------------SASDOC*;
%macro CheckInsuranceCodeInitiative;

	PROC SQL NOPRINT;
	CREATE TABLE RECAP AS
	SELECT DISTINCT 
		 A.INITIATIVE_ID
		,A.CLIENT_ID
		,A.INSURANCE_CD	
		,A.CARRIER_ID
		,A.GROUP_CD
	   FROM &HERCULES..TINIT_RECAP_CLT_RL		A
	   WHERE A.INITIATIVE_ID IN(&INITIATIVE_ID);
	QUIT;

	DATA EDW_CLIENT_FLAG (RENAME=(CLIENT_ID=CLIENT_ID_FLAG));
	  SET  RECAP ;
	  ** FOR RECAP ONLY ;
	  IF INSURANCE_CD NE '' AND 
	     CARRIER_ID EQ '' AND 
	     GROUP_CD EQ '' THEN CLIENT_FLAG = 1;**  INSURANCE CODE;
	  ELSE CLIENT_FLAG = 0;
	  KEEP INITIATIVE_ID CLIENT_ID CLIENT_FLAG ;
	RUN;
	
	DATA _NULL_;
	  SET EDW_CLIENT_FLAG;
	    I+1;
	    II=LEFT(PUT(I,4.));
	    CALL SYMPUT('INSURANCE_CODE',TRIM(CLIENT_FLAG));
	RUN;
	
	%if &INSURANCE_CODE. eq 1 %then %do ;
	
	  %put NOTE: Recap Initiative is at a insurance code level. ;
	  %put NOTE: There are many clients at an insurance code level - blank out client id and client name;
	
	  DATA _F&RX_RE_TBL;
	    SET _F&RX_RE_TBL;
	    CLIENT_ID=.;
	  RUN;
	
	%end;
	%else %do ;
	
	  %put NOTE: Recap Initiative is not at a insurance code level. ;
	
	%end;	
	  

%mend CheckInsuranceCodeInitiative;
*SASDOC----------------------------------------------------------------------------
| Call checkinsurancecodeinitiative Macro for RECAP Program Maintanance Initiative
| 10MAY2008 - K.MITTAPALLI   - Hercules Version  2.1.0.1
+---------------------------------------------------------------------------SASDOC*;
%macro CheckInsuranceCoderxre;

	PROC SQL NOPRINT;
	CREATE TABLE RECAP AS
	SELECT DISTINCT 
		 A.INITIATIVE_ID
		,A.CLIENT_ID
		,A.INSURANCE_CD	
		,A.CARRIER_ID
		,A.GROUP_CD
	   FROM _F_TABLE_3_RE		A;
	QUIT;

	DATA EDW_CLIENT_FLAG (RENAME=(CLIENT_ID=CLIENT_ID_FLAG));
	  SET  RECAP ;
	  ** FOR RECAP ONLY ;
	  IF INSURANCE_CD NE '' AND 
	     CARRIER_ID EQ '' AND 
	     GROUP_CD EQ '' THEN CLIENT_FLAG = 1;**  INSURANCE CODE;
	  ELSE CLIENT_FLAG = 0;
	  KEEP INITIATIVE_ID CLIENT_ID CLIENT_FLAG ;
	RUN;
	
	DATA _NULL_;
	  SET EDW_CLIENT_FLAG;
	    I+1;
	    II=LEFT(PUT(I,4.));
	    CALL SYMPUT('INSURANCE_CODE',TRIM(CLIENT_FLAG));
	RUN;
	
	%if &INSURANCE_CODE. eq 1 %then %do ;
	
	  %put NOTE: Recap Initiative is at a insurance code level. ;
	  %put NOTE: There are many clients at an insurance code level - blank out client id and client name;
	
	  DATA _F&RX_RE_TBL;
	    SET _F&RX_RE_TBL;
	    CLIENT_ID=.;
	  RUN;
	
	%end;
	%else %do ;
	
	  %put NOTE: Recap Initiative is not at a insurance code level. ;
	
	%end;	
	  

%mend CheckInsuranceCoderxre;

%macro RX_RE_clnt_rpt(RX_RE_TBL,TITLE1,TITLE2,FIELD1,FIELD2,CODE);

*SASDOC----------------------------------------------------------------------------
| Produce a Recap/Rxclaim report of client setup/Program Maintanance setup component.
| 10MAY2008 - K.MITTAPALLI   - Hercules Version  2.1.0.1
+---------------------------------------------------------------------------SASDOC*;
ods proclabel=" ";
	%if &CODE eq 2 %then %do;
proc sql noprint;
select (   (max(CLIENT_SETUP_INCLUSION_&CODE) ne 0)
        or (max(CLIENT_ID) is not missing      ) ) format=1.
  into :_COMP_TTL_F_TBL
  from WORK._F&RX_RE_TBL;
quit;
	%end;
	%if &CODE eq 3 %then %do;
proc sql noprint;
select (   (max(CLIENT_SETUP_INCLUSION_&CODE) ne 0)
        or (max(INSURANCE_CD) is not missing      ) ) format=1.
  into :_COMP_TTL_F_TBL
  from WORK._F&RX_RE_TBL;
quit;
	%end;
%PUT NOTE:	_COMP_TTL_F_TBL = &_COMP_TTL_F_TBL;

*SASDOC----------------------------------------------------------------------------
| RxClaim/Recap Client Setup Heading
| 02JAN2011 RS - Change Client Setup Heading to Align with QL 
+---------------------------------------------------------------------------SASDOC*;
%macro COMP_TTL_F_RX_RE_TBL;
%if (&_COMP_TTL_F_TBL ne 0) %then
%do;
 %if &DSPLY_CLT_SETUP_CD=1 OR &DSPLY_CLT_SETUP_CD=2 OR &DSPLY_CLT_SETUP_CD=3 %then %do;
   PROC SQL NOPRINT;
      SELECT CASE WHEN &CODE = 2 THEN 'RxClaim Client Setup'
	              WHEN &CODE = 3 THEN 'Recap Client Setup'
				  ELSE 'Client Setup' END AS CLT_DESC
	  INTO :CLT_DESC
	  FROM _F&RX_RE_TBL;
   QUIT;
   %comp_ttl(_F&RX_RE_TBL,&CLT_DESC.,F_DSPLY_CLT_SETUP_CD,_DISPLAY=Y);
 %end;
 %else %do;
   PROC SQL NOPRINT;
      SELECT CASE WHEN &CODE = 2 THEN 'RxClaim Program Maintenance Setup' 
	              WHEN &CODE = 3 THEN 'Recap Program Maintenance Setup' 
				  ELSE 'Program Maintenance'  END AS CLT_DESC
	  INTO :CLT_DESC
	  FROM _F&RX_RE_TBL;
   QUIT;
   %comp_ttl(_F&RX_RE_TBL,&CLT_DESC.,F_CLIENT_SETUP_INCLUSION_&CODE,_DISPLAY=Y);
 %end;
%end;
%mend COMP_TTL_F_RX_RE_TBL;
%COMP_TTL_F_RX_RE_TBL;

%if &CODE. eq 3 %then %CheckInsuranceCoderxre;

proc report
   contents='Client Setup'
   data=_F&RX_RE_TBL
   %if &CODE eq 2 %then %do;
       (where=(CLIENT_ID ne .)) 
   %end;
   %if &CODE eq 3 %then %do;
       (where=(INSURANCE_CD ne ' ')) 
   %end;
   missing
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =8pt
                  font_face   =&_tbl_fnt];

column
   &FIELD1
   CLIENT_NM
   F_CLT_SETUP_DEF_CD
   F_INCLUDE_IN
   &FIELD2
   CLIENT_ID
   GROUP_CD;

define &FIELD1            / group page 
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}&TITLE1^S={}"
   style=[cellwidth=1.14in
          font_weight=medium
          just=r];
define CLIENT_NM                   / group
   "^S={font_weight=bold
        font_size  =9pt
        background =&_hdr_bg
        just       =c}Client Name^S={}"
   style=[cellwidth=1.84in
          font_weight=medium
          just=l];
define F_CLT_SETUP_DEF_CD          / group
   "^S={font_weight=bold
        font_size  =9pt
        background =&_hdr_bg
        just       =c}Client Setup*Definition^S={}"
   style=[cellwidth=1.84in
          font_size  =8pt
          font_weight=medium
          just=l];
define F_INCLUDE_IN                / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Include/*Exclude^S={}"
   style=[cellwidth=0.86in
          font_weight=medium
          just=l];
define &FIELD2         		/ order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}&TITLE2^S={}"
   style=[cellwidth=1.14in
          font_weight=medium
          just=r];
define CLIENT_ID               / order    
   "^S={font_weight=bold
        font_size  =9pt
        background =&_hdr_bg
        just       =c}Client ID^S={}"
   style=[cellwidth  =1.84in
          font_weight=medium
          font_size  =9pt
          just       =r];
define GROUP_CD            		/ order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Group*Code^S={}"
   style=[cellwidth=1.54in
          font_weight=medium
          just=r];
run;
quit;

%mend RX_RE_clnt_rpt;	

*SASDOC-------------------------------------------------------------------------
| Produce RxClaim and/or Recap Client Setup Report
| 
| 02JAN2021 - RS - Added Doc and Check for no setup information
|                  Skip adj platform if no client setup information
+-----------------------------------------------------------------------SASDOC*;
%macro process2;

%IF &QL_ADJ EQ 1 %THEN
	%QL_clnt_rpt;

%IF &RE_ADJ EQ 1 %THEN %DO;
	PROC SQL NOPRINT;
        SELECT COUNT(*)
	    	INTO :RE_SETUP_CNT
	    FROM _F_TABLE_3_RE;
    QUIT; 
    %IF &RE_SETUP_CNT GT 0 %THEN 
  		%RX_RE_clnt_rpt(_TABLE_3_RE
					    ,Insurance*Cd
			   			,Carrier*Id
			   			,INSURANCE_CD
			   			,CARRIER_ID
			   			,3);
%END;
%IF &RX_ADJ EQ 1 %THEN %DO; 
	PROC SQL NOPRINT;
        SELECT COUNT(*)
	    	INTO :RX_SETUP_CNT
	    FROM _F_TABLE_3_RX;
    QUIT; 
    %IF &RX_SETUP_CNT GT 0 %THEN
		%RX_RE_clnt_rpt(_TABLE_3_RX
					    ,Carrier Id
			   			,Account Id
					    ,CARRIER_ID
			   			,ACCOUNT_ID
			   			,2);
%END;

%mend process2;
%process2;
*SASDOC-------------------------------------------------------------------------
| Produce a report of drug setup component.
| If Program is not Physician Profiling (55) then consolidate Drug and
| Drug Subgroup. If Program is Physician Profiling then list Drug and
| Drug Subgroup detail.
+-----------------------------------------------------------------------SASDOC*;
ods proclabel=" ";
%comp_ttl(_F_TABLE_4,Drug Setup,F_DRG_DEFINITION_CD,_DISPLAY=Y);
%macro rpt_table_4(DRG_GROUP_SEQ_NB,_PROGRAM_ID);
%if (&_PROGRAM_ID ne 55) %then
%do;
   proc report
      missing
      contents='Drug Setup'
      data=C_F_TABLE_4(where=(DRG_GROUP_SEQ_NB is not missing))
      nowd
      split="*"
      style(report)=[rules       =all
                     frame       =box
                     background  =_undef_
                     just        =l
                     leftmargin  =0.00in
                     rightmargin =0.00in
                     topmargin   =0.00in
                     bottommargin=_undef_
                     asis        =off]
      style(column)=[font_size   =9pt
                     font_face   =&_tbl_fnt];
   column
      C_DRUG_GROUP_SEQ_NB_DSC_TX
      C_CLAIM_BEGIN_END_DT
      F_EXCLUDE_OTC_IN
      OPERATOR_TX
      F_BRD_GNRC_OPT_CD
      C_F_DRUG_ID_TYPE_CD
      F_INCLUDE_IN
      DRG_GRP_DTL_TX;

   define C_DRUG_GROUP_SEQ_NB_DSC_TX  / group page
      "^S={font_weight=bold
           font_size  =9pt
           background =&_hdr_bg
           just       =l}^_^_^_^_^_Drug Group^S={}"
      style=[cellwidth  =2.54in
             font_size  =8pt
             font_weight=medium
             just=l];
   define C_CLAIM_BEGIN_END_DT         / group
      "^S={font_weight=bold
           font_size  =8pt
           background =&_hdr_bg
           just       =c}Claim^nBegin/End^S={}"
      style=[cellwidth  =1.09in
             font_size  =8pt
             font_weight=medium
             just       =c];
   define F_EXCLUDE_OTC_IN            / group format=$4.
      "^S={font_weight=bold
           font_size  =8pt
           background =&_hdr_bg
           just       =c}OTC^S={}"
      style=[cellwidth=0.64in
             font_size  =8pt
             font_weight=medium
             just=l];
   define OPERATOR_TX                 / group
      "^S={font_weight=bold
           font_size  =8pt
           background =&_hdr_bg
           just       =c}Rule^S={}"
      style=[cellwidth=0.64in
             font_size  =8pt
             font_weight=medium
             just=c];
   define F_BRD_GNRC_OPT_CD            / group
      "^S={font_weight=bold
           font_size  =8pt
           background =&_hdr_bg
           just       =c}Brand/Generic^S={}"
      style=[cellwidth=1.29in
             font_size  =8pt
             font_weight=medium
             just=l];
   define C_F_DRUG_ID_TYPE_CD          / group
      "^S={font_weight=bold
           font_size  =8pt
           background =&_hdr_bg
           just       =c}Drug Type/ID^S={}"
      style=[cellwidth=1.49in
             font_size  =8pt
             font_weight=medium
             just=l];
   define F_INCLUDE_IN                / group format=$4.
      "^S={font_weight=bold
           font_size  =8pt
           background =&_hdr_bg
           just       =c}Incl^S={}"
      style=[cellwidth=0.59in
             font_weight=medium
             font_size  =8pt
             just=l];
   define DRG_GRP_DTL_TX             / group
      "^S={font_weight=bold
           font_size  =8pt
           background =&_hdr_bg
           just       =c}Description^S={}"
      style=[cellwidth=1.89in
             font_size  =8pt
             font_weight=medium
             just=l];
   run;
   quit;
%end;
%else
%do;
   proc report
      contents='Drug Setup'
      missing
      data=C_F_TABLE_4(where=(DRG_GROUP_SEQ_NB=&DRG_GROUP_SEQ_NB))
      nowd
      split="*"
      style(report)=[rules       =all
                     frame       =box
                     background  =_undef_
                     just        =l
                     leftmargin  =0.00in
                     rightmargin =0.00in
                     topmargin   =0.00in
                     bottommargin=_undef_
                     asis        =off]
      style(column)=[font_size   =9pt
                     font_face   =&_tbl_fnt];
   column
      C_DRUG_GROUP_SEQ_NB_DSC_TX
      DRUG_PHASE_SEQ_NB
      CLAIM_BEGIN_DT
      CLAIM_END_DT
      F_EXCLUDE_OTC_IN
      OPERATOR_TX;
   define C_DRUG_GROUP_SEQ_NB_DSC_TX  / group page
      "^S={font_weight=bold
           font_size  =9pt
           background =&_hdr_bg
           just       =l}^_^_^_^_^_Drug Group^S={}"
      style=[cellwidth  =3.21in
             font_size  =9pt
             font_weight=medium
             just=l];
define DRUG_PHASE_SEQ_NB              / order
   "^S={font_weight=bold
        font_size  =7.5pt
        background =&_hdr_bg
        just       =c
        cellpadding=0.00in
        posttext   =""}Phase^S={}"
   style=[cellwidth  =1.11in
          font_weight=medium
          font_size  =09pt
          just       =r
          posttext   ="^S={}^_^_^S={}"];
   define CLAIM_BEGIN_DT              / group format=dt.
      "^S={font_weight=bold
           font_size  =9pt
           background =&_hdr_bg
           just       =c}Claim Begin^S={}"
      style=[cellwidth  =1.71in
             font_weight=medium
             just       =c];
   define CLAIM_END_DT                / group format=dt.
      "^S={font_weight=bold
           font_size  =9pt
           background =&_hdr_bg
           just       =c}Claim End^S={}"
      style=[cellwidth  =1.71in
             font_weight=medium
             just       =c];
   define F_EXCLUDE_OTC_IN            / group
      "^S={font_weight=bold
           font_size  =9pt
           background =&_hdr_bg
           just       =c}OTC^S={}"
      style=[cellwidth=1.31in
             font_size  =9pt
             font_weight=medium
             just=l];
   define OPERATOR_TX                 / group
      "^S={font_weight=bold
           background =&_hdr_bg
           just       =c}Rule^S={}"
      style=[cellwidth=1.11in
             font_weight=medium
             just=c];
   run;
   quit;

   proc report
      contents='Drug Setup'
      data=C_F_TABLE_4 (where=(   (DRG_GROUP_SEQ_NB=&DRG_GROUP_SEQ_NB)
                              and (DRG_SUB_GRP_SEQ_NB is not missing )))
      missing
      headline
      nowd
      split="*"
      style(report)=[rules       =all
                     frame       =box
                     background  =_undef_
                     just        =r
                     leftmargin  =_undef_
                     rightmargin =0.00in
                     topmargin   =_undef_
                     bottommargin=_undef_
                     asis        =off]
      style(column)=[font_size   =8pt
                     font_face   =&_tbl_fnt];

   column
      C_DRG_SUB_GRP_SEQ_NB_DSC_TX
      F_BRD_GNRC_OPT_CD
      C_F_NUMERATOR_SAVINGS_IN
      C_F_DRUG_ID_TYPE_CD
      F_INCLUDE_IN
      DRG_GRP_DTL_TX;
   define C_DRG_SUB_GRP_SEQ_NB_DSC_TX / group
      "^S={font_weight=bold
           font_size  =9pt
           background =&_hdr_bg
           just       =l}^_^_^_^_^_Drug Subgroup^S={}"
      style=[cellwidth=2.68in
             font_size  =9pt
             font_weight=medium
             just=l];
   define F_BRD_GNRC_OPT_CD            / group
      "^S={font_weight=bold
           font_size  =8pt
           background =&_hdr_bg
           just       =c}Brand/Generic^S={}"
      style=[cellwidth=1.43in
             font_size  =8pt
             font_weight=medium
             just=l];
   define C_F_NUMERATOR_SAVINGS_IN     / group
      "^S={font_weight=bold
           font_size  =8pt
           background =&_hdr_bg
           just       =c}Num/Save^S={}"
      style=[cellwidth=1.08in
             font_size  =8pt
             font_weight=medium
             just=c];
   define C_F_DRUG_ID_TYPE_CD          / group
      "^S={font_weight=bold
           font_size  =8pt
           background =&_hdr_bg
           just       =c}Drug Type/ID^S={}"
      style=[cellwidth=1.78in
             font_size  =8pt
             font_weight=medium
             just=l];
   define F_INCLUDE_IN                / group
      "^S={font_weight=bold
           background =&_hdr_bg
           just       =c}Include^S={}"
      style=[cellwidth=0.93in
             font_weight=medium
             just=l];
   define DRG_GRP_DTL_TX             / group
      "^S={font_weight=bold
           background =&_hdr_bg
           just       =c}Description^S={}"
      style=[cellwidth=2.30in
             font_weight=medium
             just=l];
   run;
   quit;
   %br_line(0.50pt);
%end;
%mend rpt_table_4;

*SASDOC--------------------------------------------------------------------------
| Use call execute to process by PROGRAM_ID and DRG_GROUP_SEQ_NB.
+------------------------------------------------------------------------SASDOC*;
data _null_;
set C_F_TABLE_4;
by PROGRAM_ID DRG_GROUP_SEQ_NB;
if (PROGRAM_ID ne 55) then
do;
   if (first.PROGRAM_ID) then
      call execute('%rpt_table_4('||put(DRG_GROUP_SEQ_NB,8.)||','||put(PROGRAM_ID,8.)||')');
end;
else
   if (first.DRG_GROUP_SEQ_NB) and (DRG_GROUP_SEQ_NB ne .) then
      call execute('%rpt_table_4('||put(DRG_GROUP_SEQ_NB,8.)||','||put(PROGRAM_ID,8.)||')');
run;

*SASDOC-------------------------------------------------------------------------
| Produce a report of Setup Prescriber Parameters.
+-----------------------------------------------------------------------SASDOC*;
ods proclabel=" ";
%comp_ttl(_TABLE_5,Setup Prescriber Parameters,INITIATIVE_ID,_DISPLAY=N);
proc report
   contents='Setup Prescriber Parameters'
   data=_F_TABLE_5_1
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  font_size   =10pt
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =10pt
                  background =white
                  font_face   =&_tbl_fnt]
   style(header)=[font_size   =10pt
                  font_face   =&_tbl_fnt
                  font_weight =bold
                  background =&_hdr_bg
                  just       =l];
column
    F_INCLUDE_IN
    SPECIALTY_CD
    F_SPECIALTY_CD
    C_F_SPECIALTY_CD;
define F_INCLUDE_IN   / display
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}In/Exclude^S={}"
   style=[cellwidth  =4.00in
          font_size  =10pt
          font_weight=medium
          just=l];
define SPECIALTY_CD          / noprint;
define F_SPECIALTY_CD        / noprint;
define C_F_SPECIALTY_CD      / computed
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =l}^_^_^_^_Specialty^S={}"
   style=[cellwidth  =6.20in
          font_size  =10pt
          font_weight=medium
          just=l];
compute C_F_SPECIALTY_CD     / char length=85;
   C_F_SPECIALTY_CD=substr(left(SPECIALTY_CD),1,3)||' - '||left(F_SPECIALTY_CD);
endcomp;
run;
quit;

proc report
   contents='Setup Prescriber Parameters'
   data=_TABLE_5_2
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  font_size   =10pt
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =10pt
                  background =white
                  font_face   =&_tbl_fnt]
   style(header)=[font_size   =10pt
                  font_face   =&_tbl_fnt
                  font_weight =bold
                  background =&_hdr_bg
                  just       =l];
column
   MIN_PATIENTS_QY
   MAX_PATIENTS_QY
   OPERATOR_TX
   MIN_RX_QY
   MAX_RX_QY
   ;
define MIN_PATIENTS_QY      / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Min Patients^S={}"
   style=[cellwidth  =2.48in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
define MAX_PATIENTS_QY       / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Max Patients^S={}"
   style=[cellwidth  =2.48in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
define OPERATOR_TX           / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Rule^S={}"
   style=[cellwidth  =1.28in
          font_weight=medium
          just=c];
define MIN_RX_QY             / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Min R^{sub x}^S={font_weight=bold} Qty^S={}"
   style=[cellwidth  =1.98in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
define MAX_RX_QY       / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Max *R^{sub x}^S={font_weight=bold} Qty^S={}"
   style=[cellwidth  =1.98in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];


run;
quit;

*SASDOC-------------------------------------------------------------------------
| Produce a report of Setup Participant Parameters.
+-----------------------------------------------------------------------SASDOC*;
ods proclabel=" ";
%comp_ttl(_F_TABLE_6_1,Setup Participant Parameters,INITIATIVE_ID,_DISPLAY=N);
proc report
   contents='Setup Participant Parameters'
   data=_F_TABLE_6_1
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  font_size   =9pt
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =9pt
                  font_weight =medium
                  font_face   =&_tbl_fnt
                  just        =l];

column PRTCPNT_RL_SEQ_NB
       F_GENDER_OPTION_CD
       MINIMUM_AGE_AT
       MAXIMUM_AGE_AT
       OPERATOR_TX
       PRTCPNT_MIN_RX_QY
       PRTCPNT_MAX_RX_QY
       OPERATOR_2_TX
       MIN_MEMBER_COST_AT
       MAX_MEMBER_COST_AT
       F_INCLUDE_IN
	   MIN_ESM_SAVE_AT
	   MIN_GROSS_SAVE_AT
	   PLAN_PRTCPNT_AT;
define PRTCPNT_RL_SEQ_NB     / order
   "^S={font_weight=bold
        font_size  =9pt
        background =&_hdr_bg
        just       =c
        posttext=""}Seq No^S={}"
   style=[cellwidth  =0.72in
          just       =r
          posttext   ="^S={}^_^_^_^S={}"];
define F_GENDER_OPTION_CD    / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Gender^S={}"
   style=[cellwidth  =0.72in
          just=l];
define MINIMUM_AGE_AT        / display
   "^S={font_weight=bold
        font_size  =9pt
        background =&_hdr_bg
        just       =c
        posttext=""}Min Age^S={}"
   style=[cellwidth  =0.57in
          just=r
          posttext="^S={}^_^_^_^S={}"];
define MAXIMUM_AGE_AT        / display
   "^S={font_weight=bold
        font_size  =9pt
        background =&_hdr_bg
        just       =c
        posttext=""}Max Age^S={}"
   style=[cellwidth  =0.57in
          just=r
          posttext="^S={}^_^_^_^S={}"];
define OPERATOR_TX           / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Rule^S={}"
   style=[cellwidth  =0.67in
          just=c];
define PRTCPNT_MIN_RX_QY      / display
   "^S={font_weight=bold
        font_size  =9pt
        background =&_hdr_bg
        just       =c
        posttext=""}Min R^{sub x}^S={font_weight=bold} Qty^S={}"
   style=[cellwidth  =0.92in
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
define PRTCPNT_MAX_RX_QY      / display
   "^S={font_weight=bold
        font_size  =9pt
        background =&_hdr_bg
        just       =c
        posttext=""}Max R^{sub x}^S={font_weight=bold} Qty^S={}"
   style=[cellwidth  =0.92in
          just       =r
          posttext   ="^S={}^_^_^_^_^_^S={}"];
define OPERATOR_2_TX           / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Rule 2^S={}"
   style=[cellwidth  =0.67in
          font_weight=medium
          just=c];
define MIN_member_cost_at             / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Min *MBR Cost^S={}"
   style=[cellwidth  =0.87in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
define MAX_member_cost_at       / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Max *MBR Cost^S={}"
   style=[cellwidth  =0.87in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];

define F_INCLUDE_IN   / display
   "^S={font_weight=bold
        font_size  =9pt
        background =&_hdr_bg
        just       =c}In/Exclude^S={}"
   style=[cellwidth  =0.67in
          just       =l];

define MIN_ESM_SAVE_AT       / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Min*EsmAt^S={}"
   style=[cellwidth  =0.55in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];

define MIN_GROSS_SAVE_AT      / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Min*Gross*At^S={}"
   style=[cellwidth  =0.87in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];

define PLAN_PRTCPNT_AT      / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Plan*Ppt*At^S={}"
   style=[cellwidth  =0.55in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
run;
quit;

%macro QL_frm_rpt;
*SASDOC-------------------------------------------------------------------------
| Produce a report of Setup Formulary Parameters.
+-----------------------------------------------------------------------SASDOC*;
ods proclabel=" ";
%comp_ttl(_F_TABLE_7_1,Setup QL Formulary Parameters,INITIATIVE_ID,_DISPLAY=N);
proc report
   contents='Setup Formulary Parameters'
   data=_F_TABLE_7_1
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  font_size   =10pt
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =10pt
                  background =white
                  font_face   =&_tbl_fnt]
   style(header)=[font_size   =10pt
                  font_face   =&_tbl_fnt
                  font_weight =bold
                  background =&_hdr_bg
                  just       =l];
column
   ("^S={}^_^_^_Usage^S={}"
    F_FRML_USAGE_CD)
   ("^S={}^_^_^_Formulary ID^S={}"
    FORMULARY_ID
    F_FORMULARY_ID);
define F_FRML_USAGE_CD  / order   " "
   style=[cellwidth  =2.10in
          font_size  =10pt
          font_weight=medium
          just=l];
define FORMULARY_ID    / order   " "
   style=[cellwidth  =2.05in
          font_size  =10pt
          font_weight=medium
          just=r];
define F_FORMULARY_ID   / order   " "
   style=[cellwidth  =6.05in
          font_size  =10pt
          font_weight=medium
          just=l];
run;
quit;

proc report
   contents='Setup Formulary Parameters'
   data=_F_TABLE_7_2
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =10pt
                  background =white
                  font_face   =&_tbl_fnt];
column
    F_PERIOD_CD
    F_INCENTIVE_TYPE_CD;
define F_PERIOD_CD          / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =l}^_^_^_Period^S={}"
   style=[cellwidth  =5.1in
          font_size  =10pt
          font_weight=medium
          just=l];
define F_INCENTIVE_TYPE_CD  / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =l}Incentive Type^S={}"
   style=[cellwidth  =5.1in
          font_size  =10pt
          font_weight=medium
          just=l];
run;
quit;

proc report
   contents='Setup Formulary Parameters'
   data=_F_TABLE_7_3
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =10pt
                  background =white
                  font_face   =&_tbl_fnt];
column
    F_DATE_TYPE_CD
    INITIATIVE_DT;
define F_DATE_TYPE_CD       / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =l}^_^_^_Date Type^S={}"
   style=[cellwidth  =5.1in
          font_size  =10pt
          font_weight=medium
          just=l];
define INITIATIVE_DT       / order  format=mmddyy10.
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Initiative Date^S={}"
   style=[cellwidth  =5.1in
          font_size  =10pt
          font_weight=medium
          just=c];
run;
quit;
%mend QL_frm_rpt;

%macro RX_RE_frm_rpt(FRM_TBL,CODE);
ods proclabel=" ";
%comp_ttl(_F&FRM_TBL,Setup &CODE Formulary Parameters,INITIATIVE_ID,_DISPLAY=N);
proc report
   contents='Setup Formulary Parameters'
   data=_F&FRM_TBL
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  font_size   =9pt
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =9pt
                  font_weight =medium
                  font_face   =&_tbl_fnt
                  just        =l];

column EXT_FORMULARY_ID
       FORMULARY_PRFX_CD;
define EXT_FORMULARY_ID             / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Formulary Id^S={}"
   style=[cellwidth  =4.60in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
define FORMULARY_PRFX_CD      		/ display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Formulary Prefix Code^S={}"
   style=[cellwidth  =5.60in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
run;
quit;
%mend RX_RE_frm_rpt;
%macro process3;
%IF &QL_ADJ EQ 1 %THEN %QL_frm_rpt;
%IF &RX_ADJ EQ 1 %THEN 
%RX_RE_frm_rpt(_table_7_1_RX,Rx Claim);
%IF &RE_ADJ EQ 1 %THEN 
%RX_RE_frm_rpt(_table_7_1_RE,Recap);
%mend process3;
%process3;
%macro Dflt_docmnt_rpt;
*SASDOC-------------------------------------------------------------------------
| Produce a QL report of default document setup component.
+-----------------------------------------------------------------------SASDOC*;
DATA _F_TABLE_8_2;
 SET 
 %if &ql_adj eq 1 %then %do;
 _F_TABLE_8_2 
 %end;
 %if &rx_adj eq 1 %then %do;
 _F_TABLE_8_2_RX
 %end;
 %if &re_adj eq 1 %then %do;
 _F_TABLE_8_2_RE
 %end;
;
RUN;
PROC SORT DATA = _F_TABLE_8_2 nodupkey;BY F_CMCTN_ROLE_CD DESCRIPTION_TX PHASE_SEQ_NB APN_CMCTN_ID VERSION_TITLE_TX;RUN;

DATA _F_TABLE_8_2;
 SET _F_TABLE_8_2;
 LTR_CMCTN_CD = LEFT(F_CMCTN_ROLE_CD||'-'||DESCRIPTION_TX);
 RUN;

ods proclabel=" ";
%comp_ttl(_F_TABLE_8_2,Default Setup Document,INITIATIVE_ID,_DISPLAY=N);
proc report
   contents='Default Document Setup'
   data=_F_TABLE_8_2
   missing
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =09pt
                  background  =white
                  font_face   =&_tbl_fnt];
column
   LTR_CMCTN_CD
   PHASE_SEQ_NB
   APN_CMCTN_ID
   VERSION_TITLE_TX;
define LTR_CMCTN_CD       / display order=data
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}Receiver-Letter Rule^S={}"
   style=[cellwidth  =3.55in
          font_weight=medium
          font_size  =09pt
          just       =l];
define PHASE_SEQ_NB          / order
   "^S={font_weight=bold
        font_size  =7.5pt
        background =&_hdr_bg
        just       =c
        cellpadding=0.00in
        posttext   =""}Phase^S={}"
   style=[cellwidth  =1.55in
          font_weight=medium
          font_size  =09pt
          just       =r
          posttext   ="^S={}^_^_^S={}"];
define APN_CMCTN_ID          / display order=data
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}Application ID^S={}"
   style=[cellwidth  =2.15in
          font_size  =09pt
          font_weight=medium
          just=l];
define VERSION_TITLE_TX     / display
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}Document Title^S={}"
   style=[cellwidth=2.95in
          font_weight=medium
          font_size  =08pt
          just=l];
run;
quit;
%mend Dflt_docmnt_rpt;
%Dflt_docmnt_rpt;
%macro QL_docmnt_rpt;
*SASDOC-------------------------------------------------------------------------
| Produce a QL report of document setup component.
+-----------------------------------------------------------------------SASDOC*;
DATA _F_TABLE_8;
 SET _F_TABLE_8;
 LTR_CMCTN_CD = LEFT(F_CMCTN_ROLE_CD||'-'||DESCRIPTION_TX);
 RUN;

*SASDOC-------------------------------------------------------------------------
| 25NOV2008 G.D. REMOVED FORMAT=1. STATEMENT IN PROC SQL
+-----------------------------------------------------------------------SASDOC*;
proc sql noprint;
select count(*)
  into :_COMP_TTL_D_TBL
  from WORK._F_TABLE_8;
quit;
%PUT NOTE:	_COMP_TTL_D_TBL = &_COMP_TTL_D_TBL;
%if (&_COMP_TTL_D_TBL ne 0) %then %do;
ods proclabel=" ";
%comp_ttl(_F_TABLE_8,QL Setup Document,INITIATIVE_ID,_DISPLAY=N);
%end;
proc report
   contents='Document Setup'
   data=_F_TABLE_8
       (where=(&_COMP_TTL_D_TBL ne 0)) 
   missing
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =09pt
                  background  =white
                  font_face   =&_tbl_fnt];
column
   CLIENT_ID
   GROUP_CLASS_CD
   GROUP_CLASS_SEQ_NB
   BLG_REPORTING_CD
   PLAN_NM
   PLAN_CD_TX
   PLAN_EXT_CD_TX
   GROUP_CD_TX
   GROUP_EXT_CD_TX 
   LTR_CMCTN_CD
   PHASE_SEQ_NB
   APN_CMCTN_ID
   VERSION_TITLE_TX;
define CLIENT_ID             / order format=clnt. order=data
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c
        posttext   =""}Client ID^S={}"
   style=[cellwidth  =0.65in
          font_weight=medium
          font_size  =10pt
          just       =r
          posttext   ="^S={}^_^_^_^S={}"];
define GROUP_CLASS_CD      / order
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}Grp Class Cd^S={}"
   style=[cellwidth  =0.60in
          font_weight=medium
          font_size  =09pt
          just       =l];
define GROUP_CLASS_SEQ_NB      / order
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}Grp Seq Nb^S={}"
   style=[cellwidth  =0.35in
          font_weight=medium
          font_size  =09pt
          just       =l];
define BLG_REPORTING_CD      / order
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}Blg RptCd^S={}"
   style=[cellwidth  =0.50in
          font_weight=medium
          font_size  =09pt
          just       =l];
define PLAN_NM       / order
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}Plan nm^S={}"
   style=[cellwidth  =0.80in
          font_weight=medium
          font_size  =09pt
          just       =l];
define PLAN_CD_TX       / order
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}Plan Cd ^S={}"
   style=[cellwidth  =0.45in
          font_weight=medium
          font_size  =09pt
          just       =l];
define PLAN_EXT_CD_TX      / order
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}Plan Ext Cd ^S={}"
   style=[cellwidth  =0.45in
          font_weight=medium
          font_size  =09pt
          just       =l];
define GROUP_CD_TX       / order
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}Grp Cd^S={}"
   style=[cellwidth  =0.40in
          font_weight=medium
          font_size  =09pt
          just       =l];
define GROUP_EXT_CD_TX        / order
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}Grp Ext Cd^S={}"
   style=[cellwidth  =0.40in
          font_weight=medium
          font_size  =09pt
          just       =l];
define LTR_CMCTN_CD       / display order=data
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}Receiver-Letter Rule^S={}"
   style=[cellwidth  =2.40in
          font_weight=medium
          font_size  =09pt
          just       =l];
define PHASE_SEQ_NB          / order
   "^S={font_weight=bold
        font_size  =7.5pt
        background =&_hdr_bg
        just       =c
        cellpadding=0.00in
        posttext   =""}Phase^S={}"
   style=[cellwidth  =0.40in
          font_weight=medium
          font_size  =09pt
          just       =r
          posttext   ="^S={}^_^_^S={}"];
define APN_CMCTN_ID          / display order=data
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}Application ID^S={}"
   style=[cellwidth  =1.00in
          font_size  =09pt
          font_weight=medium
          just=l];
define LTR_RULE_SEQ_NB       / noprint order=data;
define VERSION_TITLE_TX     / display
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}Document Title^S={}"
   style=[cellwidth=1.80in
          font_weight=medium
          font_size  =08pt
          just=l];
run;
quit;

%mend QL_docmnt_rpt;

%macro RX_RE_docmnt_rpt(DOCMNT_TBL,CODE,DOC_FIELD1,DOC_FIELD2,DOC_FIELD3,DOC_TITL1,DOC_TITL2,DOC_TITL3);

*SASDOC-------------------------------------------------------------------------
| Produce a Recap/Rxclaim report of document setup component.
| 10MAY2008 - K.MITTAPALLI   - Hercules Version  2.1.0.1
| 02JAN2012 - RS - Change format=1. to format=3. to handle multiple documents 
+-----------------------------------------------------------------------SASDOC*;
DATA _F&DOCMNT_TBL;
 SET _F&DOCMNT_TBL;
 LTR_CMCTN_CD = LEFT(F_CMCTN_ROLE_CD||'-'||DESCRIPTION_TX);
 RUN;

proc sql noprint;
select count(*) format=3.   /* changed to format=3. 1/2/2012 RS */
  into :_COMP_TTL_DX_TBL
  from WORK._F&DOCMNT_TBL;
quit;

%PUT NOTE:	_COMP_TTL_DX_TBL = &_COMP_TTL_DX_TBL;

%if (&_COMP_TTL_DX_TBL ne 0) %then %do;
ods proclabel=" ";
%comp_ttl(_F&DOCMNT_TBL,&CODE Setup Document,INITIATIVE_ID,_DISPLAY=N);
%end;

proc report
   contents='Document Setup'
   data=_F&DOCMNT_TBL
       (where=(&_COMP_TTL_DX_TBL ne 0)) 
   missing
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =09pt
                  background  =white
                  font_face   =&_tbl_fnt];
column
   &DOC_FIELD1
   &DOC_FIELD2
   &DOC_FIELD3
   LTR_CMCTN_CD
   PHASE_SEQ_NB
   APN_CMCTN_ID
   LTR_RULE_SEQ_NB
   VERSION_TITLE_TX;
define &DOC_FIELD1             / order 
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c
        posttext   =""}&DOC_TITL1^S={}"
   style=[cellwidth  =0.98in
          font_weight=medium
          font_size  =10pt
          just       =r
          posttext   ="^S={}^_^_^_^S={}"];
define &DOC_FIELD2       / order
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}&DOC_TITL2.^S={}"
   style=[cellwidth  =1.28in
          font_weight=medium
          font_size  =09pt
          just       =l];
define &DOC_FIELD3       / order
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}&DOC_TITL3.^S={}"
   style=[cellwidth  =0.66in
          font_weight=medium
          font_size  =09pt
          just       =l];
define LTR_CMCTN_CD       / display order=data
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}Receiver-Letter Rule^S={}"
   style=[cellwidth  =3.09in
          font_weight=medium
          font_size  =09pt
          just       =l];
define PHASE_SEQ_NB          / order
   "^S={font_weight=bold
        font_size  =7.5pt
        background =&_hdr_bg
        just       =c
        cellpadding=0.00in
        posttext   =""}Phase^S={}"
   style=[cellwidth  =0.73in
          font_weight=medium
          font_size  =09pt
          just       =r
          posttext   ="^S={}^_^_^S={}"];
define APN_CMCTN_ID          / display order=data
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}Application ID^S={}"
   style=[cellwidth  =1.33in
          font_size  =09pt
          font_weight=medium
          just=l];
define LTR_RULE_SEQ_NB       / noprint order=data;
define VERSION_TITLE_TX     / display
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}Document Title^S={}"
   style=[cellwidth=2.13in
          font_weight=medium
          font_size  =08pt
          just=l];
run;
quit;

%MEND RX_RE_docmnt_rpt;
%macro process4;
%IF &QL_ADJ EQ 1 %THEN %QL_docmnt_rpt;
%IF &RX_ADJ EQ 1 %THEN 
%RX_RE_docmnt_rpt(_TABLE_8_RX,Rx Claim,CARRIER_ID,ACCOUNT_ID,GROUP_CD,Carrier ID,Accound Id, Group Cd);
%IF &RE_ADJ EQ 1 %THEN 
%RX_RE_docmnt_rpt(_TABLE_8_RE,Recap,INSURANCE_CD,CARRIER_ID,GROUP_CD,Insurance Cd,Carrier ID, Group Cd);
%mend process4;
%process4;
*SASDOC-------------------------------------------------------------------------
| Produce a report of Setup iBenefits Parameters.
| 02JAN2012 - RS Changes title to iBenefit/PSG Parameters, add data-driven text, and adjust widths
+-----------------------------------------------------------------------SASDOC*;
ods proclabel=" ";
%comp_ttl(_F_TABLE_9,Setup iBenefit/PSG Parameters,INITIATIVE_ID,_DISPLAY=N); /* 1/2/2012- RS Change title */
proc report
   contents='Setup iBenefit Parameters'
   data=_F_TABLE_9
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  font_size   =9pt
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =9pt
                  font_weight =medium
                  font_face   =&_tbl_fnt
                  just        =l];

column EXCL_MAIL_IN
       EXCL_GENC_IN
       EXCL_PREFR_IN
       SENIOR_AGE_NB
       MODULE_NB
       MESSAGE_ID
       DATA_DRIVEN_TX; /* 02JAN2012 RS - Add data driven tx */
define EXCL_MAIL_IN             / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Mail Opportunity^S={}"
   style=[cellwidth  =1.40in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
define EXCL_GENC_IN       		/ display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Generic Opportunity^S={}"
   style=[cellwidth  =1.40in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
define EXCL_PREFR_IN       	/ display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Formulary Opportunity^S={}"
   style=[cellwidth  =1.40in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
define SENIOR_AGE_NB             / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Senior Age^S={}"
   style=[cellwidth  =1.00in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
define MODULE_NB       		/ display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Module Number^S={}"
   style=[cellwidth  =1.20in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
define MESSAGE_ID       	/ display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Message Id^S={}"
   style=[cellwidth  =1.38in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
define DATA_DRIVEN_TX       	/ display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Data Driven^S={}"
   style=[cellwidth  =1.38in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];

run;
quit;

*SASDOC-------------------------------------------------------------------------
| Produce a report of PSG (MSS) only Setup Parameters.
| 02JAN2012 - RS Initial addition of PSG Parameters report section macro
+-----------------------------------------------------------------------SASDOC*;
%macro ibenefit3_report_section;
		%if &task_id = 59 %then %do;

		%comp_ttl(_F_TABLE_11,Setup PSG Parameters: Savings and Drug Alternatives,INITIATIVE_ID,_DISPLAY=N);
		proc report
		   contents='Setup iBenefit Parameters'
		   data=_F_TABLE_11
		   nowd
		   split="*"
		   style(report)=[rules       =all
		                  frame       =box
		                  background  =_undef_
		                  just        =l
		                  font_size   =9pt
		                  leftmargin  =0.00in
		                  rightmargin =0.00in
		                  topmargin   =0.00in
		                  bottommargin=_undef_
		                  asis        =off]
		   style(column)=[font_size   =9pt
		                  font_weight =medium
		                  font_face   =&_tbl_fnt
		                  just        =l];

		column  
				 INCL_HIST_SPEND_IN
				 INCL_MED_EXP_IN
				 PROJECT_PER_FRM_DT
				 PROJECT_PER_TO_DT
				 SAME_BASLINE_IN
				 STACK_CLAIM_IN
				 INCL_CURR_ACCT_IN
				 INCL_DRG_MAINT_IN
				 INCL_DRG_ACUTE_IN
				 INCL_DRG_SUBST_IN
				 INCL_DRG_SPEC_IN
				 INCL_DRG_GENER_IN
				 INCL_DRG_FORM_IN
				 INCL_DRG_BRAND_IN
				 INCL_DRG_OTC_IN;

		define INCL_HIST_SPEND_IN             / display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Historical Claims^S={}"
		   style=[cellwidth  =1.00in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"];
		define INCL_MED_EXP_IN       		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Medical Expenses^S={}"
		   style=[cellwidth  =1.00in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"];
		define PROJECT_PER_FRM_DT       		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Project From Date^S={}"
		   style=[cellwidth  =1.00in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"];
		define PROJECT_PER_TO_DT       		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Project To Date^S={}"
		   style=[cellwidth  =1.00in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"];
		define SAME_BASLINE_IN       		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Same as Baseline^S={}"
		   style=[cellwidth  =1.00in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"];
		define STACK_CLAIM_IN       		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Stack Claims^S={}"
		   style=[cellwidth  =1.00in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"];
		define INCL_CURR_ACCT_IN       		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Current Accums^S={}"
		   style=[cellwidth  =1.00in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"]; 
		define INCL_DRG_MAINT_IN      		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Maintenance Drugs^S={}"
		   style=[cellwidth  =1.00in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"]; 
		define INCL_DRG_ACUTE_IN      		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Acute Drugs^S={}"
		   style=[cellwidth  =1.00in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"]; 
		define INCL_DRG_SUBST_IN      		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Controlled Substances^S={}"
		   style=[cellwidth  =1.00in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"]; 
		define INCL_DRG_SPEC_IN      		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Specialty Drugs^S={}"
		   style=[cellwidth  =1.00in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"]; 
		define INCL_DRG_GENER_IN      		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Generic Drugs^S={}"
		   style=[cellwidth  =1.00in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"]; 
		define INCL_DRG_FORM_IN      		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Formulary Drugs^S={}"
		   style=[cellwidth  =1.30in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"]; 
		define INCL_DRG_BRAND_IN      		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Select Brands (GSTP)^S={}"
		   style=[cellwidth  =1.30in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"]; 
		define INCL_DRG_OTC_IN      		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}OTC Drugs^S={}"
		   style=[cellwidth  =1.00in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"]; 
		run;
		quit;

		%comp_ttl(_F_TABLE_12,Setup PSG Parameters: Channel Alternatives and Manufacturer Codes,INITIATIVE_ID,_DISPLAY=N);
		proc report
		   contents='Setup iBenefit Parameters'
		   data=_F_TABLE_12
		   nowd
		   split="*"
		   style(report)=[rules       =all
		                  frame       =box
		                  background  =_undef_
		                  just        =l
		                  font_size   =9pt
		                  leftmargin  =0.00in
		                  rightmargin =0.00in
		                  topmargin   =0.00in
		                  bottommargin=_undef_
		                  asis        =off]
		   style(column)=[font_size   =9pt
		                  font_weight =medium
		                  font_face   =&_tbl_fnt
		                  just        =l];

		column  
		         INCL_CHL_MAINT_IN
				 INCL_CHL_SPEC_IN
				 INCL_CHL_DEF_IN
				 INCL_CHL_CVS90_IN
				 PREF_MFR_CD  ;

		define INCL_CHL_MAINT_IN             / display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Target Opportnunities Mail^S={}"
		   style=[cellwidth  =1.70in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"];
		define INCL_CHL_SPEC_IN       		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Target Opportnunities Specialty^S={}"
		   style=[cellwidth  =1.70in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"];
		define INCL_CHL_DEF_IN       		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Channel Alternatives Default to Plan^S={}"
		   style=[cellwidth  =1.70in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"];
		define INCL_CHL_CVS90_IN       		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Channel Alternatives CVS 90^S={}"
		   style=[cellwidth  =1.70in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"];
		define PREF_MFR_CD       		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Preferred Manufacturer Codes^S={}"
		   style=[cellwidth  =2.70in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"];
		run;
		quit;
	%end;
%mend ibenefit3_report_section;
%ibenefit3_report_section;

*SASDOC-------------------------------------------------------------------------
| Produce a report of Negative Formulary only Setup Parameters.
| 06DEC2012 - SB - Initial addition of Negative Formulary Parameters report section macro
+-----------------------------------------------------------------------SASDOC*;
%macro negative_formulary_section;
		%if &program_id = 5246 %then %do;

		%comp_ttl(_F_TABLE_13,Setup Negative Formulary EOB Parameters,INITIATIVE_ID,_DISPLAY=N);
		proc report
		   contents='Setup Negative Formulary Parameters'
		   data=_F_TABLE_13
		   nowd
		   split="*"
		   style(report)=[rules       =all
		                  frame       =box
		                  background  =_undef_
		                  just        =l
		                  font_size   =9pt
		                  leftmargin  =0.00in
		                  rightmargin =0.00in
		                  topmargin   =0.00in
		                  bottommargin=_undef_
		                  asis        =off]
		   style(column)=[font_size   =9pt
		                  font_weight =medium
		                  font_face   =&_tbl_fnt
		                  just        =l];

		column  
				EOB_INDICATOR
				EOB_DESCRIPTION
				EOB_BEGIN_DT
				EOB_END_DT
				EOB_RUN_SEQ
				FIRST_RUN_INIT;

		define EOB_INDICATOR             / display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}EOB Filter^S={}"
		   style=[cellwidth  =1.00in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"];
		define EOB_DESCRIPTION       		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Description^S={}"
		   style=[cellwidth  =1.00in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"];
		define EOB_BEGIN_DT       		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Begin Date^S={}"
		   style=[cellwidth  =1.00in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"];
		define EOB_END_DT       		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}End Date^S={}"
		   style=[cellwidth  =1.00in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"];
		define EOB_RUN_SEQ       		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}Run Sequence^S={}"
		   style=[cellwidth  =1.00in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"];
		define FIRST_RUN_INIT       		/ display
		   "^S={font_weight=bold
		        background =&_hdr_bg
		        just       =c
		        posttext=""}First Initiative #^S={}"
		   style=[cellwidth  =1.00in
		          font_weight=medium
		          just=r
		          posttext="^S={}^_^_^_^_^_^S={}"]; 
		run;
		quit;
	%end;
%mend negative_formulary_section;
%negative_formulary_section;

*SASDOC-------------------------------------------------------------------------
| Produce a report of Setup Additional Parameters.
+-----------------------------------------------------------------------SASDOC*;
ods proclabel=" ";
%comp_ttl(_F_TABLE_10,Setup Additional Parameters,INITIATIVE_ID,_DISPLAY=N);
proc report
   contents='Setup Additional Parameters'
   data=_F_TABLE_10
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  font_size   =9pt
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =9pt
                  font_weight =medium
                  font_face   =&_tbl_fnt
                  just        =l];

column ADDITIONAL_FIELD_NM
       ADDITIONAL_SHORT_TX_FIELD
			;
define ADDITIONAL_FIELD_NM      / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Additional Field Nm^S={}"
   style=[cellwidth  =3.99in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
define ADDITIONAL_SHORT_TX_FIELD     / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Additional Short Field Name^S={}"
   style=[cellwidth  =6.21in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
run;
quit;
ods pdf close;

*SASDOC=====================================================================;
* QCPI208
* Call update_request_ts to complete of executing summary report in batch
*====================================================================SASDOC*;
%update_request_ts(complete);

*SASDOC=====================================================================;
* QCPI208
* Send Summary Initiative report to requestor by e-mail
*====================================================================SASDOC*;

%email_parms( EM_TO=&_em_to_user
	,EM_CC="hercules.support@caremark.com"
	,EM_SUBJECT="The Initiative Summary Report for &initiative_id."
	,EM_MSG="The Initiative Summary Report you requested is attached"
  ,EM_ATTACH="/herc&sysmode/data/hercules/reports/initiative_summary_parms_&initiative_id..pdf"  ct="application/pdf");


/*proc printto;*/
/*run;*/
