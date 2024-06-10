*Step 2 :;
%set_sysmode(mode=prod);
OPTIONS SYSPARM='initiative_id=10798 phase_seq_nb=1';
%include "/PRG/sas&sysmode.1/hercules/hercules_in.sas";
OPTIONS FULLSTIMER MPRINT MPRINTNEST MLOGIC MLOGICNEST SYMBOLGEN SOURCE2;

/*data data_pnd.t_&initiative_id._1_1;*/
/*  set data_pnd.t_&initiative_id._1_1_bkp;*/
/*run;*/

proc sort data = &DB2_TMP..i&INITIATIVE_ID. out = i&INITIATIVE_ID. ;
 by drug_ndc_id;
run;

proc contents data=i&INITIATIVE_ID. varnum;
run;


data i&INITIATIVE_ID.;
/*  length gpi14 $14;*/
  set i&INITIATIVE_ID.;
/*  GPI14=trim(left(GPI_GROUP)) || trim(left(GPI_CLASS)) || trim(left(GPI_SUBCLASS)) || */
/*      trim(left(GPI_NAME)) || trim(left(GPI_NAME_EXTENSION)) || trim(left(GPI_FORM)) ||*/
/*      trim(left(GPI_STRENGTH));*/
run;

PROC SORT DATA = TMP106.T_&INITIATIVE_ID._NDC_QL
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
  select  recipient_id, prescriber_id, DRUG_ABBR_PROD_NM, DRUG_ABBR_DSG_NM, drug_Abbr_strg_nm,
          GPI_GROUP,GPI_CLASS,GPI_SUBCLASS,GPI_NAME,GPI_NAME_EXTENSION,GPI_FORM,
          GPI_STRENGTH,drug_ndc_id, DELIVERY_SYSTEM_CD, DISPENSED_QY,DAY_SUPPLY_QY
  /*        max(drug_ndc_id) as drug_ndc_id, max(DELIVERY_SYSTEM_CD) as DELIVERY_SYSTEM_CD, sum(DISPENSED_QY) as DISPENSED_QY*/
  from i&INITIATIVE_ID.
  order by recipient_id, prescriber_id, DRUG_ABBR_PROD_NM, DRUG_ABBR_DSG_NM, drug_Abbr_strg_nm
  ;
run;

proc sort data = data_pnd.t_&INITIATIVE_ID._1_1 ;
  by recipient_id prescriber_id DRUG_ABBR_PROD_NM DRUG_ABBR_DSG_NM drug_Abbr_strg_nm;
run;

proc sql;
  select count(*)
  from data_pnd.t_&INITIATIVE_ID._1_1;
quit;

data data_pnd.t_&INITIATIVE_ID._1_1_new;
 merge i&INITIATIVE_ID.b        (in=a rename=(DRUG_NDC_ID=dni 
                                              DISPENSED_QY=dq
                                              DELIVERY_SYSTEM_CD=ds
                                              DAY_SUPPLY_QY=DAYS
                                              DRUG_ABBR_PROD_NM=ABBR_PROD_NM 
                                              DRUG_ABBR_DSG_NM=ABBR_DSG_NM
                                              DRUG_ABBR_STRG_NM=ABBR_STRG_NM))
       data_pnd.t_&INITIATIVE_ID._1_1 (in=b);
 by recipient_id prescriber_id DRUG_ABBR_PROD_NM DRUG_ABBR_DSG_NM drug_Abbr_strg_nm;
 if b; 
  DRUG_NDC_ID=dni ;
  DISPENSED_QY=dq;
  DELIVERY_SYSTEM=ds;
  DAY_SUPPLY_QY=days;
  DRUG_ABBR_PROD_NM=ABBR_PROD_NM;
  DRUG_ABBR_DSG_NM=ABBR_DSG_NM;
  DRUG_ABBR_STRG_NM=ABBR_STRG_NM;
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
