/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  initiative_summary_parms_ql.sas
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
+-----------------------------------------------------------------------HEADER*/

*SASDOC-------------------------------------------------------------------------
| Include file for initiative_summary_parms.sas
+-----------------------------------------------------------------------SASDOC*;
%*LET sysmode=test;
%set_sysmode;
/*%let _SOCKET_ERROR_MSG=something;*/

/** %LET INITIATIVE_ID=67;
%LET PHASE_SEQ_NB =1;
 FILENAME rptfl "/DATA/sas&sysmode.1/hercules/reports/initiative_summary_parms.pdf";

PROC PRINTTO LOG="/PRG/sas&sysmode.1/hercules/reports/initiative_summary_parms.log" NEW;
RUN;
QUIT; **/

options mrecall;
%include "/herc&sysmode./prg/hercules/reports/initiative_summary_parms_in.sas";

%macro br_space(_LN_HGTH);
%*SASDOC-----------------------------------------------------------------------
| add a break space to print file.
+----------------------------------------------------------------------SASDOC*;
data _null_;
file print;
put "^S={cellheight=&_LN_HGTH}^_^S={}";
run;
%mend br_space;

%macro comp_ttl(_DATASET,_COMPONENT_TX,_COMPONENT_CD,_DISPLAY=N);
%*SASDOC-----------------------------------------------------------------------
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
   style=[cellwidth  =7.85in
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
%*SASDOC-----------------------------------------------------------------------
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

*SASDOC-------------------------------------------------------------------------
| Select summary data for a Initiative-Phase.
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
*SASDOC-------------------------------------------------------------------------
| Select client setup parameters.
+-----------------------------------------------------------------------SASDOC*;
proc sql noprint;
create table _TABLE_3_1 as
select
   C.*,
   D.CLIENT_ID,
   D.CLT_SETUP_DEF_CD
  from
      (
      select distinct
         A.INITIATIVE_ID,
         A.PHASE_SEQ_NB,
         A.PROGRAM_ID,
         A.TASK_ID,
         A.OVRD_CLT_SETUP_IN,
         A.DFLT_INCLSN_IN,
         ((A.DFLT_INCLSN_IN eq 1) and (A.OVRD_CLT_SETUP_IN eq 0)) as
         CLIENT_SETUP_INCLUSION_CD,
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
select
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
         F.PLAN_GROUP_NM,
         F.INCLUDE_IN
        from
             _TABLE_3_1 E left join
             &HERCULES..TINIT_CLIENT_RULE F
          on E.INITIATIVE_ID eq F.INITIATIVE_ID
         and E.CLIENT_ID     eq F.CLIENT_ID
      )
       G left join
     &CLAIMSA..TCLIENT1 H
    on G.CLIENT_ID eq H.CLIENT_ID
order by CLIENT_ID;
quit;
*SASDOC-------------------------------------------------------------------------
| Add formatted variables to client setup parameters data.
+-----------------------------------------------------------------------SASDOC*;
%add_fmt_vars($_HERCF,
              _TABLE_3,
              _F_TABLE_3,
              F_,
              CLIENT_SETUP_INCLUSION_CD,
              CLT_SETUP_DEF_CD,
              INCLUDE_IN);
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
| Select formulary setup parameters.
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
| Add formatted variables to formulary setup parameters data.
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
| Select iBenefit parameters.
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
		 C.MESSAGE_ID
        from _TABLE_1d A
   left join &HERCULES..TINIT_IBNFT_OPTN B
          on A.INITIATIVE_ID eq B.INITIATIVE_ID
         and A.PHASE_SEQ_NB  eq B.PHASE_SEQ_NB
   left join &HERCULES..TINIT_MODULE_MSG  C
		  on A.INITIATIVE_ID eq C.INITIATIVE_ID
		 and A.PHASE_SEQ_NB  eq C.PHASE_SEQ_NB;	
quit;

*SASDOC-------------------------------------------------------------------------
| Add formatted variables to client setup parameters data.
+-----------------------------------------------------------------------SASDOC*;
%add_fmt_vars($_HERCF,
              _TABLE_9,
              _F_TABLE_9
			   );
			   
			   
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
| Add formatted variables to client setup parameters data.
+-----------------------------------------------------------------------SASDOC*;
%add_fmt_vars($_HERCF,
              _TABLE_10,
              _F_TABLE_10
			   );			   

*SASDOC-------------------------------------------------------------------------
| Select document setup parameters.
+-----------------------------------------------------------------------SASDOC*;
proc sql noprint;
create table _TABLE_8_1 as
select B.INITIATIVE_ID,
       B.PHASE_SEQ_NB,
       B.CMCTN_ROLE_CD,
       B.LTR_RULE_SEQ_NB,
       B.PROGRAM_ID,
       A.TASK_ID,
       . AS CLIENT_ID,
       B.APN_CMCTN_ID,
       B.HSU_TS
 from  _TABLE_1d A,
       &HERCULES..TINIT_PHSE_RVR_DOM B

 where A.INITIATIVE_ID eq B.INITIATIVE_ID
 union corr
 select A.INITIATIVE_ID,
       A.PHASE_SEQ_NB,
       B.CMCTN_ROLE_CD,
       B.LTR_RULE_SEQ_NB,
       B.PROGRAM_ID,
       A.TASK_ID,
       . AS CLIENT_ID,
       B.APN_CMCTN_ID,
       B.HSU_TS
 from  _TABLE_1d A,
       &HERCULES..TPGM_TASK_DOM B,
       &HERCULES..TPROGRAM_TASK C
  WHERE A.PROGRAM_ID=B.PROGRAM_ID
    AND A.TASK_ID=B.TASK_ID
    AND A.PROGRAM_ID=C.PROGRAM_ID
    AND A.TASK_ID=C.TASK_ID
    AND EFFECTIVE_DT <= TODAY()
    AND EXPIRATION_DT>= TODAY()
    AND C.DOCUMENT_LOC_CD=2 /** DOC LOCATION AT PROGRAM LEVEL**/
union corr
 select A.INITIATIVE_ID,
       A.PHASE_SEQ_NB,
       B.CMCTN_ROLE_CD,
       B.LTR_RULE_SEQ_NB,
       B.PROGRAM_ID,
       A.TASK_ID,
       B.CLIENT_ID,
       B.APN_CMCTN_ID,
       B.HSU_TS
 from  _TABLE_1d A,
       &HERCULES..TCLT_PGM_TASK_DOM B,
       &HERCULES..TPROGRAM_TASK C
  WHERE A.PROGRAM_ID=B.PROGRAM_ID
    AND A.TASK_ID=B.TASK_ID
    AND A.PROGRAM_ID=C.PROGRAM_ID
    AND A.TASK_ID=C.TASK_ID
    AND EFFECTIVE_DT <= TODAY()
    AND EXPIRATION_DT>= TODAY()

UNION CORR

select B.INITIATIVE_ID,
       B.PHASE_SEQ_NB,
       B.CMCTN_ROLE_CD,
       B.LTR_RULE_SEQ_NB,
       A.PROGRAM_ID,
       A.TASK_ID,
       B.CLIENT_ID,
       B.APN_CMCTN_ID,
       B.HSU_TS
 from  _TABLE_1d A,
       &HERCULES..TINIT_PHSE_CLT_DOM B
 where A.INITIATIVE_ID   eq B.INITIATIVE_ID
   and A.PHASE_SEQ_NB    eq B.PHASE_SEQ_NB  ;

create table _TABLE_8 as
select C.INITIATIVE_ID,
       C.PHASE_SEQ_NB,
       C.CMCTN_ROLE_CD,
       C.LTR_RULE_SEQ_NB,
       C.PROGRAM_ID,
       C.TASK_ID,
       C.CLIENT_ID,
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
order by INITIATIVE_ID, PHASE_SEQ_NB, CLIENT_ID,
         CMCTN_ROLE_CD, APN_CMCTN_ID, LTR_RULE_SEQ_NB;
quit;

*SASDOC-------------------------------------------------------------------------
| Add formatted variables to document setup data.
+-----------------------------------------------------------------------SASDOC*;
%add_fmt_vars($_HERCF,
              _TABLE_8,
              _F_TABLE_8,
              F_,
              CMCTN_ROLE_CD);

options orientation=portrait papersize=letter nodate number missing='' pageno=1
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
   ACCEPTED_QY
   SUSPENDED_QY
   LETTERS_SENT_QY;
define F_CMCTN_ROLE_CD      / display page
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Receiver^S={}"
   style=[cellwidth=1.05in
          font_weight=bold
          just=l];
define F_DATA_CLEANSING_CD  / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Data Cleansing^S={}"
   style=[cellwidth=1.62in
          font_weight=medium
          just=l];
define F_FILE_USAGE_CD      / display
   "^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}File Usage^S={}"
   style=[cellwidth=1.63in
          font_weight=medium
          just=l];
define F_DESTINATION_CD     / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Destination^S={}"
   style=[cellwidth=1.75in
          font_weight=medium
          just=l];
define F_RELEASE_STATUS_CD  / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Release Status^S={}"
   style=[cellwidth=1.45in
          font_weight=medium
          just=l];
define REJECTED_QY          / analysis format=comma14.
   "^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Initial Records Rejected^S={}"
   style=[cellwidth=1.62in
          font_size=10pt
          font_weight=medium
          just=c];
define ACCEPTED_QY          / analysis format=comma14.
   "^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Initial Records Accepted^S={}"
   style=[cellwidth=1.63in
          font_size=10pt
          font_weight=medium
          just=c];
define SUSPENDED_QY         / analysis format=comma14.
   "^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Initial Records Suspended^S={}"
   style=[cellwidth=1.75in
          font_size=10pt
          font_weight=medium
          just=c];
define LETTERS_SENT_QY      / analysis format=comma14.
   "^S={font_weight=bold
        background =&_hdr_bg
        font_size  =9pt
        just       =c}Letters Mailed^S={}"
   style=[cellwidth=1.45in
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

*SASDOC-------------------------------------------------------------------------
| Produce a report of client setup component.
+-----------------------------------------------------------------------SASDOC*;
ods proclabel=" ";
proc sql noprint;
select (   (max(CLIENT_SETUP_INCLUSION_CD) ne 0)
        or (max(CLIENT_ID) is not missing      )   ) format=1.
  into :_COMP_TTL_F_TABLE_3
  from WORK._F_TABLE_3
quit;

%macro COMP_TTL_F_TABLE_3;
%if (&_COMP_TTL_F_TABLE_3 ne 0) %then
%do;
   %comp_ttl(_F_TABLE_3,Client Setup,F_CLIENT_SETUP_INCLUSION_CD,_DISPLAY=Y);
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
   style=[cellwidth  =0.50in
          font_weight=medium
          font_size  =9pt
          just       =r];
define CLIENT_NM                   / group
   "^S={font_weight=bold
        font_size  =9pt
        background =&_hdr_bg
        just       =c}Client Name^S={}"
   style=[cellwidth=1.50in
          font_weight=medium
          just=l];
define F_CLT_SETUP_DEF_CD          / group
   "^S={font_weight=bold
        font_size  =9pt
        background =&_hdr_bg
        just       =c}Client Setup*Definition^S={}"
   style=[cellwidth=0.80in
          font_size  =8pt
          font_weight=medium
          just=l];
define F_INCLUDE_IN                / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Include/*Exclude^S={}"
   style=[cellwidth=0.52in
          font_weight=medium
          just=l];
define GROUP_CLASS_CD              / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Rpt Grp^S={}"
   style=[cellwidth=0.35in
          font_weight=medium
          just=r];
define GROUP_CLASS_SEQ_NB          / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Seq^S={}"
   style=[cellwidth=0.35in
          font_weight=medium
          just=r];
define BLG_REPORTING_CD            / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Billing*Report*Code^S={}"
   style=[cellwidth=0.70in
          font_weight=medium
          just=r];
define PLAN_CD_TX                  / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Plan Code^S={}"
   style=[cellwidth=0.70in
          font_weight=medium
          just=r];
define PLAN_EXT_CD_TX              / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Plan*Ext*Code^S={}"
   style=[cellwidth=0.70in
          font_weight=medium
          just=r];
define GROUP_CD_TX                 / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Group Code^S={}"
   style=[cellwidth=1.20in
          font_weight=medium
          just=r];
define GROUP_EXT_CD_TX             / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Group*Ext*Code^S={}"
   style=[cellwidth=0.50in
          font_weight=medium
          just=r];
define PLAN_GROUP_NM                 / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Plan*Group*Name^S={}"
   style=[cellwidth=1.20in
          font_weight=medium
          just=r];          

run;
quit;

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
      style=[cellwidth  =2.25in
             font_size  =8pt
             font_weight=medium
             just=l];
   define C_CLAIM_BEGIN_END_DT         / group
      "^S={font_weight=bold
           font_size  =8pt
           background =&_hdr_bg
           just       =c}Claim^nBegin/End^S={}"
      style=[cellwidth  =0.80in
             font_size  =8pt
             font_weight=medium
             just       =c];
   define F_EXCLUDE_OTC_IN            / group format=$4.
      "^S={font_weight=bold
           font_size  =8pt
           background =&_hdr_bg
           just       =c}OTC^S={}"
      style=[cellwidth=0.35in
             font_size  =8pt
             font_weight=medium
             just=l];
   define OPERATOR_TX                 / group
      "^S={font_weight=bold
           font_size  =8pt
           background =&_hdr_bg
           just       =c}Rule^S={}"
      style=[cellwidth=0.35in
             font_size  =8pt
             font_weight=medium
             just=c];
   define F_BRD_GNRC_OPT_CD            / group
      "^S={font_weight=bold
           font_size  =8pt
           background =&_hdr_bg
           just       =c}Brand/Generic^S={}"
      style=[cellwidth=1.00in
             font_size  =8pt
             font_weight=medium
             just=l];
   define C_F_DRUG_ID_TYPE_CD          / group
      "^S={font_weight=bold
           font_size  =8pt
           background =&_hdr_bg
           just       =c}Drug Type/ID^S={}"
      style=[cellwidth=1.20in
             font_size  =8pt
             font_weight=medium
             just=l];
   define F_INCLUDE_IN                / group format=$4.
      "^S={font_weight=bold
           font_size  =8pt
           background =&_hdr_bg
           just       =c}Incl^S={}"
      style=[cellwidth=0.30in
             font_weight=medium
             font_size  =8pt
             just=l];
   define DRG_GRP_DTL_TX             / group
      "^S={font_weight=bold
           font_size  =8pt
           background =&_hdr_bg
           just       =c}Description^S={}"
      style=[cellwidth=1.60in
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
      style=[cellwidth  =2.50in
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
   style=[cellwidth  =0.40in
          font_weight=medium
          font_size  =09pt
          just       =r
          posttext   ="^S={}^_^_^S={}"];
   define CLAIM_BEGIN_DT              / group format=dt.
      "^S={font_weight=bold
           font_size  =9pt
           background =&_hdr_bg
           just       =c}Claim Begin^S={}"
      style=[cellwidth  =1.00in
             font_weight=medium
             just       =c];
   define CLAIM_END_DT                / group format=dt.
      "^S={font_weight=bold
           font_size  =9pt
           background =&_hdr_bg
           just       =c}Claim End^S={}"
      style=[cellwidth  =1.00in
             font_weight=medium
             just       =c];
   define F_EXCLUDE_OTC_IN            / group
      "^S={font_weight=bold
           font_size  =9pt
           background =&_hdr_bg
           just       =c}OTC^S={}"
      style=[cellwidth=0.60in
             font_size  =9pt
             font_weight=medium
             just=l];
   define OPERATOR_TX                 / group
      "^S={font_weight=bold
           background =&_hdr_bg
           just       =c}Rule^S={}"
      style=[cellwidth=0.40in
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
      style=[cellwidth=2.25in
             font_size  =9pt
             font_weight=medium
             just=l];
   define F_BRD_GNRC_OPT_CD            / group
      "^S={font_weight=bold
           font_size  =8pt
           background =&_hdr_bg
           just       =c}Brand/Generic^S={}"
      style=[cellwidth=1.00in
             font_size  =8pt
             font_weight=medium
             just=l];
   define C_F_NUMERATOR_SAVINGS_IN     / group
      "^S={font_weight=bold
           font_size  =8pt
           background =&_hdr_bg
           just       =c}Num/Save^S={}"
      style=[cellwidth=0.65in
             font_size  =8pt
             font_weight=medium
             just=c];
   define C_F_DRUG_ID_TYPE_CD          / group
      "^S={font_weight=bold
           font_size  =8pt
           background =&_hdr_bg
           just       =c}Drug Type/ID^S={}"
      style=[cellwidth=1.35in
             font_size  =8pt
             font_weight=medium
             just=l];
   define F_INCLUDE_IN                / group
      "^S={font_weight=bold
           background =&_hdr_bg
           just       =c}Include^S={}"
      style=[cellwidth=0.50in
             font_weight=medium
             just=l];
   define DRG_GRP_DTL_TX             / group
      "^S={font_weight=bold
           background =&_hdr_bg
           just       =c}Description^S={}"
      style=[cellwidth=1.87in
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
   style=[cellwidth  =0.80in
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
   style=[cellwidth  =5.00in
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
   style=[cellwidth  =1in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
define MAX_PATIENTS_QY       / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Max Patients^S={}"
   style=[cellwidth  =1in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
define OPERATOR_TX           / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Rule^S={}"
   style=[cellwidth  =0.50in
          font_weight=medium
          just=c];
define MIN_RX_QY             / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Min R^{sub x}^S={font_weight=bold} Qty^S={}"
   style=[cellwidth  =1in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
define MAX_RX_QY       / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Max *R^{sub x}^S={font_weight=bold} Qty^S={}"
   style=[cellwidth  =1in
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
   style=[cellwidth  =0.55in
          just       =r
          posttext   ="^S={}^_^_^_^S={}"];
define F_GENDER_OPTION_CD    / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Gender^S={}"
   style=[cellwidth  =0.55in
          just=l];
define MINIMUM_AGE_AT        / display
   "^S={font_weight=bold
        font_size  =9pt
        background =&_hdr_bg
        just       =c
        posttext=""}Min Age^S={}"
   style=[cellwidth  =0.40in
          just=r
          posttext="^S={}^_^_^_^S={}"];
define MAXIMUM_AGE_AT        / display
   "^S={font_weight=bold
        font_size  =9pt
        background =&_hdr_bg
        just       =c
        posttext=""}Max Age^S={}"
   style=[cellwidth  =0.40in
          just=r
          posttext="^S={}^_^_^_^S={}"];
define OPERATOR_TX           / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Rule^S={}"
   style=[cellwidth  =0.50in
          just=c];
define PRTCPNT_MIN_RX_QY      / display
   "^S={font_weight=bold
        font_size  =9pt
        background =&_hdr_bg
        just       =c
        posttext=""}Min R^{sub x}^S={font_weight=bold} Qty^S={}"
   style=[cellwidth  =0.75in
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
define PRTCPNT_MAX_RX_QY      / display
   "^S={font_weight=bold
        font_size  =9pt
        background =&_hdr_bg
        just       =c
        posttext=""}Max R^{sub x}^S={font_weight=bold} Qty^S={}"
   style=[cellwidth  =0.75in
          just       =r
          posttext   ="^S={}^_^_^_^_^_^S={}"];
define OPERATOR_2_TX           / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Rule 2^S={}"
   style=[cellwidth  =0.50in
          font_weight=medium
          just=c];
define MIN_member_cost_at             / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Min *MBR Cost^S={}"
   style=[cellwidth  =0.70in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
define MAX_member_cost_at       / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Max *MBR Cost^S={}"
   style=[cellwidth  =0.70in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];

define F_INCLUDE_IN   / display
   "^S={font_weight=bold
        font_size  =9pt
        background =&_hdr_bg
        just       =c}In/Exclude^S={}"
   style=[cellwidth  =0.50in
          just       =l];

define MIN_ESM_SAVE_AT       / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Min*EsmAt^S={}"
   style=[cellwidth  =0.38in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];

define MIN_GROSS_SAVE_AT      / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Min*Gross*At^S={}"
   style=[cellwidth  =0.70in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];

define PLAN_PRTCPNT_AT      / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Plan*Ppt*At^S={}"
   style=[cellwidth  =0.38in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
run;
quit;

*SASDOC-------------------------------------------------------------------------
| Produce a report of Setup Formulary Parameters.
+-----------------------------------------------------------------------SASDOC*;
ods proclabel=" ";
%comp_ttl(_F_TABLE_7_1,Setup Formulary Parameters,INITIATIVE_ID,_DISPLAY=N);
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
   style=[cellwidth  =0.80in
          font_size  =10pt
          font_weight=medium
          just=l];
define FORMULARY_ID    / order   " "
   style=[cellwidth  =0.75in
          font_size  =10pt
          font_weight=medium
          just=r];
define F_FORMULARY_ID   / order   " "
   style=[cellwidth  =4.75in
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
   style=[cellwidth  =0.80in
          font_size  =10pt
          font_weight=medium
          just=l];
define F_INCENTIVE_TYPE_CD  / order
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =l}Incentive Type^S={}"
   style=[cellwidth  =1.05in
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
   style=[cellwidth  =3.25in
          font_size  =10pt
          font_weight=medium
          just=l];
define INITIATIVE_DT       / order  format=mmddyy10.
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c}Initiative Date^S={}"
   style=[cellwidth  =1.00in
          font_size  =10pt
          font_weight=medium
          just=c];
run;
quit;

*SASDOC-------------------------------------------------------------------------
| Produce a report of document setup component.
+-----------------------------------------------------------------------SASDOC*;
ods proclabel=" ";
%comp_ttl(_F_TABLE_8,Setup Document,INITIATIVE_ID,_DISPLAY=N);
proc report
   contents='Document Setup'
   data=_F_TABLE_8
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
   F_CMCTN_ROLE_CD
   PHASE_SEQ_NB
   APN_CMCTN_ID
   LTR_RULE_SEQ_NB
   DESCRIPTION_TX
   VERSION_TITLE_TX;
define CLIENT_ID             / order format=clnt. order=data
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c
        posttext   =""}Client ID^S={}"
   style=[cellwidth  =0.90in
          font_weight=medium
          font_size  =10pt
          just       =r
          posttext   ="^S={}^_^_^_^S={}"];
define F_CMCTN_ROLE_CD       / order
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}Receiver^S={}"
   style=[cellwidth  =1.05in
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
   style=[cellwidth  =1.15in
          font_size  =09pt
          font_weight=medium
          just=l];
define LTR_RULE_SEQ_NB       / noprint order=data;
define DESCRIPTION_TX        / display order=data
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}Letter Rule^S={}"
   style=[cellwidth  =1.80in
          font_size  =08pt
          font_weight=medium
          just=l];
define VERSION_TITLE_TX     / display
   "^S={font_weight=bold
        font_size  =10pt
        background =&_hdr_bg
        just       =c}Document Title^S={}"
   style=[cellwidth=2.55in
          font_weight=medium
          font_size  =08pt
          just=l];
run;
quit;
*SASDOC-------------------------------------------------------------------------
| Produce a report of Setup iBenefits Parameters.
+-----------------------------------------------------------------------SASDOC*;
ods proclabel=" ";
%comp_ttl(_F_TABLE_9,Setup iBenefit Parameters,INITIATIVE_ID,_DISPLAY=N);
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
       MESSAGE_ID;
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
run;
quit;

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
   style=[cellwidth  =2.78in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
define ADDITIONAL_SHORT_TX_FIELD     / display
   "^S={font_weight=bold
        background =&_hdr_bg
        just       =c
        posttext=""}Additional Short Field Name^S={}"
   style=[cellwidth  =5.00in
          font_weight=medium
          just=r
          posttext="^S={}^_^_^_^_^_^S={}"];
run;
quit;
ods pdf close;

