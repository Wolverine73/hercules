

/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  file_release_wrapper.sas
|
| LOCATION: /PRG/sastest1/hercules
|
| PURPOSE:  This macro is a "wrapper" for the following "file release" process
|           macros:
|
|             (1) %check_document          - ensures that pending files have
|                                            valid APN_CMCTN_IDs.
|             (2) %complete_data_cleansing - carries updates made by the user
|                                            into the pending file.
|             (3) %release_data            - determines the contents of the
|                                            final output based on the file
|                                            usage type code, and sends it to
|                                            the appropriate destination.
|
|           The purpose of this macro is to simplify the manner by which
|           the file release macros are invoked by SAS IT and Java.
|
| INPUT:    MACRO PARMS:
|
|             INIT_ID  = (Default: &INITIATIVE_ID)
|             PHASE_ID = (Default: &PHASE_SEQ_NB)
|             COM_CD   = (Default: &CMCNT_ROLE_CD)
|
| OUTPUT:   See individual macros for more detailed descriptions of the impact
|           of the specific macro calls initiated by this program.  The output
|           is in general a final output file/dataset, updated system tables,
|           status reports and email notification to users/client.
|
| CALLED PROGRAMS:
|
|   %ISNULL                  - to determine the presence of required parameters.
|   %CHECK_DOCUMENT          - as described above.
|   %COMPLETE_DATA_CLEANSING - as described above.
|   %RELEASE_DATA            - as described above.
|
+-------------------------------------------------------------------------------
| HISTORY:  19NOV2003 - T.Kalfas  - Original.
|           10MAR2010 - G. Dudley - added new program IDs for EOMS (FORMERLY COE)
|           05SEP2010 - D. Palmer - added PA program id 5371 to EOMS program list
+-----------------------------------------------------------------------HEADER*/
options mprint mprintnest mlogic mlogicnest symbolgen source2;

%macro file_release_wrapper(init_id=&initiative_id,
                            phase_id=&phase_seq_nb,
                            com_cd=&cmctn_role_cd,
                            doc_cd=&document_loc_cd,
			    dbg_flg=1);
			    
  options replace;			  

  %if &dbg_flg %then %do;
    options mprint symbolgen mlogic notes source source2 stimer fullstimer;
    %let debug_flag=Y;
  %end;


   %let init_id=%cmpres(&init_id);
   %let phase_id=%cmpres(&phase_id);
   %let com_cd=%cmpres(&com_cd);
   %let doc_cd=%cmpres(&doc_cd);

  %*SASDOC=====================================================================;
  %* This program is being executed by Java/SAS-IT testing, so the log
  %* information must specifically be directed to a disk file.  The program
  %* task log is handled by the Hercules Task Master and is stored in the
  %* &DATA_LOG directory.  This "wrapper" log will also be stored in the
  %* &DATA_LOG directory, but it will incorporate the &CMCTN_ROLE_CD in the
  %* log file name.
  %*====================================================================SASDOC*;

  %put NOTE: (&SYSMACRONAME): Re-routing log to &log_dir/t_&init_id._&phase_id._&com_cd._rls.log.;

  proc printto log="&log_dir/t_&init_id._&phase_id._&com_cd._rls.log" new;
  run;

  %if &dbg_flg %then %do;
    /*proc options;
     run;*/
  %end;
    %*SASDOC===================================================================;
    %* Initiate the CHECK DOCUMENT process.  NOTE: Indirect inheritance of the
    %* the following global macro variables occurs:  INITIATIVE_ID,
    %* PHASE_SEQ_NB, CMCTN_ROLE_CD, and DOCUMENT_LOC_CD.  Problems may arise
    %* if these variables are not assigned.
	%* 09Sept2010 D. Palmer - Added program id 5371 for Pharmacy Advisor
	%*==================================================================SASDOC*;

	
     %if (&PROGRAM_ID=5252 or &PROGRAM_ID=5253 or &PROGRAM_ID=5254 or &PROGRAM_ID=5255 or &PROGRAM_ID=5256 or &PROGRAM_ID=5270 or &PROGRAM_ID=5296 or &PROGRAM_ID=5297 or
         &PROGRAM_ID=5349 or &PROGRAM_ID=5350 or &PROGRAM_ID=5351 or &PROGRAM_ID=5352 or &PROGRAM_ID=5353 or &PROGRAM_ID=5354 or &PROGRAM_ID=5355 or &PROGRAM_ID=5356 or
         &PROGRAM_ID=5357 or &PROGRAM_ID=5371)
    %then %do;
       %cee_check_document;
	%end;
    %else %do;
    	%check_document_prod;
    	
      %if &program_id=72 %then %do;
        data data_pnd.T_&INITIATIVE_ID._&PHASE_SEQ_NB._1;
          set data_pnd.T_&INITIATIVE_ID._&PHASE_SEQ_NB._1_backup;
        run;
        proc datasets lib=data_pnd;
          delete T_&INITIATIVE_ID._&PHASE_SEQ_NB._1_backup;
        quit;

        data data_pnd.T_&INITIATIVE_ID._&PHASE_SEQ_NB._1_backup;
          set data_pnd.T_&INITIATIVE_ID._&PHASE_SEQ_NB._1;
        run;

        data pending_20629;
          set data_pnd.T_&INITIATIVE_ID._&PHASE_SEQ_NB._1;
          if client_id=20629;
        run;

        proc sql;
          create table claims_20629 as
          select PT_BENEFICIARY_ID,
                 CDH_BENEFICIARY_ID,
                 drug_ndc_id as claim_ndc_id,
                 refill_nb,
                 client_id,
                 fill_dt,
                 CLT_PLAN_GROUP_ID
          from claimsa.trxclm_base b
          where client_id=20629
          order by PT_BENEFICIARY_ID,CDH_BENEFICIARY_ID
        ;
        quit;


        proc sql;
          create table template_20629 as
          select RECIPIENT_ID,
                 PT_BENEFICIARY_ID,
                 b.CDH_BENEFICIARY_ID,
                 a.drug_ndc_id,
                 b.claim_ndc_id,
                 a.plan_cd,
                 a.apn_cmctn_id,
                 b.refill_nb,
                 b.fill_dt
          from pending_20629 a, claims_20629 b
         where a.RECIPIENT_ID = b.PT_BENEFICIARY_ID
            and a.drug_ndc_id = b.claim_ndc_id
/*            and b.FILL_DT BETWEEN '06jul2009'd AND '20aug2009'd*/
            and b.refill_nb in (2,4)
            AND (a.PLAN_CD like 'CORP%'
                 OR a.PLAN_CD LIKE 'DC%'
                 OR a.PLAN_CD LIKE 'ST%')
          order by RECIPIENT_ID,PT_BENEFICIARY_ID,CDH_BENEFICIARY_ID
        ;
        quit;

        proc sql;
          create table doc_setup as
          select *
          from &HERCULES..TPGMTASK_QL_OVR
          where PROGRAM_ID = 72 AND
        			  TASK_ID = 14 AND
                CLIENT_ID=20629
                ;
        quit;

        data TEMPLATE_TO_BE_APPLIED_20629;
          set TEMPLATE_20629;
          if plan_cd =:'CORP' and refill_nb=2 then do;
             new_apn_cmctn_id='16346A';
          end;
          if plan_cd =:'CORP' and refill_nb=4 then do;
             new_apn_cmctn_id='16346C';
          end;
          if plan_cd =:'DC' and refill_nb=2 then do;
             new_apn_cmctn_id='16346B';
          end;
          if plan_cd =:'DC' and refill_nb=4 then do;
             new_apn_cmctn_id='16346D';
          end;
          if plan_cd =:'ST' and refill_nb=2 then do;
             new_apn_cmctn_id='16346B';
          end;
          if plan_cd =:'ST' and refill_nb=4 then do;
             new_apn_cmctn_id='16346D';
          end;
        run;

        proc sql;
          create table data_pnd.T_&INITIATIVE_ID._&PHASE_SEQ_NB._1_template as
          select a.*, new_apn_cmctn_id, refill_nb
          from data_pnd.T_&INITIATIVE_ID._&PHASE_SEQ_NB._1 a,
               TEMPLATE_TO_BE_APPLIED_20629 b
         where a.RECIPIENT_ID=b.RECIPIENT_ID
           and a.drug_ndc_id = b.drug_ndc_id
         ;
        quit;

        data new_pending_20629;
          set data_pnd.T_&INITIATIVE_ID._&PHASE_SEQ_NB._1_template;
          if client_id=20629;
          keep client_id RECIPIENT_ID drug_ndc_id plan_cd new_apn_cmctn_id refill_nb;
        run;

        proc sort data=new_pending_20629 nodup;
          by client_id RECIPIENT_ID drug_ndc_id plan_cd;
        run;
        proc sort data=data_pnd.T_&INITIATIVE_ID._&PHASE_SEQ_NB._1;
          by client_id RECIPIENT_ID drug_ndc_id plan_cd;
        run;

        data data_pnd.T_&INITIATIVE_ID._&PHASE_SEQ_NB._1_final;
          merge data_pnd.T_&INITIATIVE_ID._&PHASE_SEQ_NB._1 (in=a) 
                new_pending_20629 (in=b);
          by client_id RECIPIENT_ID drug_ndc_id plan_cd;
          if a;
          if new_apn_cmctn_id ^='' then do;
            apn_cmctn_id=new_apn_cmctn_id;
          end;
        run;

        /*proc sql;*/
        /*  update data_pnd.T_&INITIATIVE_ID._&PHASE_SEQ_NB._1 a*/
        /*  set apn_cmctn_id = */
        /*     (select new_apn_cmctn_id from new_pending_20629 b*/
        /*                        where a.RECIPIENT_ID=b.RECIPIENT_ID*/
        /*                          and a.drug_ndc_id = b.drug_ndc_id);*/
        /*quit;*/

        proc datasets lib=data_pnd;
          delete T_&INITIATIVE_ID._&PHASE_SEQ_NB._1;
          change T_&INITIATIVE_ID._&PHASE_SEQ_NB._1_final=T_&INITIATIVE_ID._&PHASE_SEQ_NB._1;
        quit;
        data data_pnd.T_&INITIATIVE_ID._&PHASE_SEQ_NB._1;
          set data_pnd.T_&INITIATIVE_ID._&PHASE_SEQ_NB._1;
          if client_id=20629 and apn_cmctn_id='004' then delete;
        run;
        proc freq data=data_pnd.T_&INITIATIVE_ID._&PHASE_SEQ_NB._1;
          tables client_id*apn_cmctn_id / missing;
        run;
      %end;    	
    %end; 

    %*SASDOC===================================================================;
    %* Initiate the COMPLETE DATA CLEANSING process.
    %*==================================================================SASDOC*;

    %complete_data_cleansing(init_id=&init_id, phase_id=&phase_id, com_cd=&com_cd);


    %*SASDOC===================================================================;
    %* Initiate the RELEASE DATA process.
    %*==================================================================SASDOC*;

    %release_data(init_id=&init_id, phase_id=&phase_id, com_cd=&com_cd);

  
  %*SASDOC=====================================================================;
  %* Redirect the log output back to its default.
  %*====================================================================SASDOC*;

  %put NOTE: (&SYSMACRONAME): Re-routing log output back to default.;

  proc printto;
  run;

%mend file_release_wrapper;
