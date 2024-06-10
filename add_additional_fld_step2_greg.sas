*Step 2 :;
%set_sysmode(mode=prod);
OPTIONS SYSPARM='initiative_id=12020 phase_seq_nb=1';
%include "/PRG/sas&sysmode.1/hercules/hercules_in.sas";
OPTIONS FULLSTIMER MPRINT MPRINTNEST MLOGIC MLOGICNEST SYMBOLGEN SOURCE2;

/*proc sql;*/
/*  create table temp4 as*/
/*  select a.PT_BENEFICIARY_ID, a.drug_ndc_id*/

/*data temp5;*/
/*  set &DB2_TMP..i&INITIATIVE_ID._FILL_DT;*/
/*run;*/

/*data data_pnd.t_&initiative_id._1_1;*/
/*  set data_pnd.t_&initiative_id._1_1_bkp;*/
/*run;*/

/*proc sql;*/
/*  create table temp6 as*/
/*  select **/
/*  from &CLAIMSA..&CLAIM_HIS_TBL*/
/*  where PT_BENEFICIARY_ID in (29802159*/
/*                             ,228901186*/
/*                             ,24375675*/
/*                             ,168373655*/
/*                             ,168373655*/
/*                             ,274957645*/
/*                             ,715422573*/
/*                             ,504708666*/
/*                             ,378831208*/
/*                             ,555620393*/
/*                             ,250793341*/
/*                             ,926679031*/
/*                             ,750277727*/
/*                             ,355242738*/
/*                             ,941719885*/
/*                             ,172107012*/
/*                             ,718683488*/
/*                             ,639332578)*/
/*;*/
/*quit;*/

proc sort data = &DB2_TMP..i&INITIATIVE_ID._FILL_DT out = i&INITIATIVE_ID. ;
 by drug_ndc_id;
run;

data pending;
  set data_pnd.t_&INITIATIVE_ID._1_2 ;
run;

proc contents data=&CLAIMSA..&CLAIM_HIS_TBL varnum;
run;


data i&INITIATIVE_ID.;
  length gpi14 $14;
  set i&INITIATIVE_ID.;
  GPI14=trim(left(GPI_GROUP)) || trim(left(GPI_CLASS)) || trim(left(GPI_SUBCLASS)) || 
      trim(left(GPI_NAME)) || trim(left(GPI_NAME_EXTENSION)) || trim(left(GPI_FORM)) ||
      trim(left(GPI_STRENGTH));
run;

PROC SORT DATA = &DB2_TMP..&TABLE_PREFIX._NDC_QL
           OUT = NDC (KEEP= DRUG_NDC_ID) 
          NODUPKEY;
  BY DRUG_NDC_ID;
RUN;

data i&INITIATIVE_ID.;
 merge i&INITIATIVE_ID. (in=a)
       ndc (in=b);
 by drug_ndc_id;
 if a;
 recipient_id=pt_beneficiary_id;
run;

proc sql;
  create table i&INITIATIVE_ID.b as
  select  *
/*  select  pt_beneficiary_id as recipient_id, prescriber_id, GPI14, */
/*          DRUG_ABBR_PROD_NM, DRUG_ABBR_DSG_NM, DRUG_ABBR_STRG_NM,*/
/*          GPI_GROUP,GPI_CLASS,GPI_SUBCLASS,GPI_NAME,GPI_NAME_EXTENSION,GPI_FORM,*/
/*          GPI_STRENGTH,drug_ndc_id, DELIVERY_SYSTEM_CD, DISPENSED_QY,DAY_SUPPLY_QY*/
  /*        max(drug_ndc_id) as drug_ndc_id, max(DELIVERY_SYSTEM_CD) as DELIVERY_SYSTEM_CD, sum(DISPENSED_QY) as DISPENSED_QY*/
  from i&INITIATIVE_ID.
  order by recipient_id
  ;
run;

proc sort data = data_pnd.t_&INITIATIVE_ID._1_2 ;
  by recipient_id;
run;

proc sql;
  select count(*)
  from data_pnd.t_&INITIATIVE_ID._1_2;
quit;


data t_&INITIATIVE_ID._1_2_new;
 length match $4;
 merge data_pnd.t_&INITIATIVE_ID._1_2 (in=b   rename=(DRUG_NDC_ID=dni 
                                              DISPENSED_QY=dq
                                              DAY_SUPPLY_QY=DAYS
                                              DRUG_ABBR_PROD_NM=ABBR_PROD_NM 
                                              DRUG_ABBR_DSG_NM=ABBR_DSG_NM
                                              DRUG_ABBR_STRG_NM=ABBR_STRG_NM))
       i&INITIATIVE_ID.b        (in=a );
 BY RECIPIENT_ID;
 if b; 
 if a and b then match="Yes";
 if a and not b then match="Drug";
 if b and not a then match="Orig";
  DRUG_NDC_ID=dni ;
  DISPENSED_QY=dq;
  DAY_SUPPLY_QY=days;
  DRUG_ABBR_PROD_NM=ABBR_PROD_NM;
  DRUG_ABBR_DSG_NM=ABBR_DSG_NM;
  DRUG_ABBR_STRG_NM=ABBR_STRG_NM;
run;

proc freq;
  tables match / missing;
run;

proc sql;
  select count(*) as all_recs
  from data_pnd.t_&INITIATIVE_ID._1_1;
quit;


proc sql;
  select count(distinct recipient_id) as good_recs
  from data_pnd.t_&INITIATIVE_ID._1_1
  where data_quality_cd ne 3;
quit;

proc datasets lib=data_pnd;
  delete T_&INITIATIVE_ID._&PHASE_SEQ_NB._1;
  change T_&INITIATIVE_ID._&PHASE_SEQ_NB._1_new=T_&INITIATIVE_ID._&PHASE_SEQ_NB._1;
quit;

OPTIONS NOMPRINT NOMPRINTNEST NOMLOGIC NOMLOGICNEST NOSYMBOLGEN NOSOURCE2;
