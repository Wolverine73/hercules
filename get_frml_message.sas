  proc sql;
      connect to db2 (dsn=&udbsprp);
      create table frm_1_19 as
      select *
       from connection to db2
      (Select NDC.*,
              FRM.in_formulary_in_cd,
              frm.formulary_id,
              FRM.POD_ID,
              client_id,
              FRM.pod_nm
        from
        (select drug_ndc_id,
                drug_abbr_prod_nm,
                drug_brand_cd,
                drug_mult_src_in
            from claimsa.tdrug1 a, QCPAP020.FORM_NDC B
            WHERE A.DRUG_NDC_ID=B.NDC)            AS NDC

        LEFT JOIN

        (SELECT B.DRUG_NDC_ID,
                b.in_formulary_in_cd,
                fm.formulary_id,
                pod.POD_ID,
                pod.client_id,
                pod.pod_nm,
                fhs.frml_message_tx
          FROM  claimsa.tpod_drug_history b,
                claimsa.tpod pod, claimsa.tformulary_pod fm,
                claimsa.tfrml_message_hist fhs
         where  fm.effective_dt <= current date
                and fm.expiration_dt > current date
                and fm.formulary_id in (1,19)
                and b.pod_id=pod.pod_id
                and pod.pod_id=fm.pod_id
                and b.pod_id=fhs.pod_id
                and fhs.client_id=0
                and current date between fhs.effective_dt and fhs.expiration_dt
                and b.effective_dt <= current date
                and b.expiration_dt > current date)  AS FRM
      ON NDC.DRUG_NDC_ID=FRM.DRUG_NDC_ID
       order by ndc.drug_ndc_id
      ) ;
     disconnect from db2;
      quit;
