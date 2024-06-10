/*HEADER------------------------------------------------------------------------
|
|  PROGRAM:    add_rocc_cd.sas
|
|  LOCATION:   /PRG/sas&sysmode.1/hercules/macros
|
|  PURPOSE:    Attaching ROCC location code (FACILITY_CD) to the mailing file.
|              The value of Facility Code will be used to populate MOC_PHM_CD.
|              The change is applicable only if MOC_PHM_CD is listed as a required
|              field of the mailing file.
|
|              Using ROCC location enables clinical OPS to create letters accordingly
|              with the correct address.
|
|              Add ROCC locations (FACILITY_CD) to the file.
|
|              FACILITY_CD is renamed as MOC_PHM_CD to be inline with original system design.
|
|
|    Note 1:   Apply 'distinct' to &CLAIMSA..TFACIL_ZIP_XREF_HS (TFZX) due to that there
|              are dups in the table.
|
|    Note 2:   This program is writen only to be included into the %create_base_file
|              macro.
|
|    Note 3:   AIX and Mainframe mapping:
|
|              CLAIMSA.TFACIL_ZIP_XREF_HS (TFZX)
|              CLAIMSA.TCLIENT_CMK_RTNADR (TCCE)
|
+--------------------------------------------------------------------------------
|
|  HISTORY:  
|
|  May 05 2005  - J. Hou / G. Comerford 
|                 Initial Release.
|                             
|  Mar 16 2007  - Greg Dudley - Hercules Version  1.0 
|                 Changed HERCULET schema to HERCULES after the 
|                 TCLT_FAC_OVRD_HIS was created in HERCULES SCHEMA     
|
|  Dec 21 2007  - Brian Stropich - Hercules Version  1.5.01
|                 Added code to update TCLT_FAC_OVRD_HIS with values of AFW for 
|                 new clients that were added to the mainframe TCCE list and
|                 inform Hercules Support with an email
|
|  Jul 23 2011  - Paul Landis
|                 Modified to use run date parameter, CURRENTDATE2, in 
|                 place of today() function to facilitate hercdev2 testing
|
+-----------------------------------------------------------------------HEADER*/

options mprint;

%macro add_rocc_cd;

   %let PROGRAM_NAME=ADD_ROCC_CD;
   %LOCAL HEC_TMP;
   
   /** change it to &HERCULES after the TCLT_FAC_OVRD_HIS is in HERCULES SCHEMA **/
   %let hec_tmp=&HERCULES;                             
   
   proc sql noprint;
        select count(*) into: rocc_exist_in
        from tfile_fields
        where field_nm ='MOC_PHM_CD';
   quit;
   
   
   /** apply ROCC location code only when file layout has MOC_PHM_CD **/
   %if &rocc_exist_in>0 %then %do; ** loop start - rocc_exist_in ;
   
   	proc sql noprint;
   	  select count(distinct a.client_id)
   	    into  :new_clt_cnt
   	    from  &claimsa..tclient_cmk_rtnadr  a
   	    where not exists
   		   (select 1 
   		   from &hec_tmp..tclt_fac_ovrd_his  b
   		   where a.client_id=b.client_id
   		     and b.expiration_dt > today()
   		     and b.effective_dt <= today()
   		     );
   	quit;
   
   	proc sql noprint;
   	   select distinct a.client_id
   	     into  : new_client separated by ','
   	     from  &claimsa..tclient_cmk_rtnadr  a
   	     where not exists
   		   (select 1 
   		   from &hec_tmp..tclt_fac_ovrd_his  b
   		   where a.client_id=b.client_id
   		     and b.expiration_dt > today()
   		     and b.effective_dt <= today()
   		    );
   	quit;
   
   	%put NOTE: NEW_CLT_CNT = &NEW_CLT_CNT. ;
   	%put NOTE: NEW_CLIENT  = &NEW_CLIENT.  ;
   
   	%if &new_clt_cnt > 0 %then %do;  ** loop start - new_clt_cnt ;
   	
 	
	%*SASDOC-------------------------------------------------------------------------
	| Dec 21 2007  - Brian Stropich 
	| Added code to update TCLT_FAC_OVRD_HIS with values of AFW for new clients 
	| that were added to the mainframe TCCE list and inform Hercules Support with  
	| an email.
	+-----------------------------------------------------------------------SASDOC;
   
	   %macro InsertFacilityCodes(update_prod);
	   
              %macro insert_client(clientid, facilitycode);
                
		           data client;
		              set &hec_tmp..TCLT_FAC_OVRD_HIS (where =(EXPIRATION_DT ='31DEC9999'D));
		               if _n_=2 then stop;
              	      facility_cd="&facilitycode.";
              	      client_id=&clientid.;
		              override_cd=1;
		              put _all_;
		           run;                
                
              	   proc append base = &hec_tmp..TCLT_FAC_OVRD_HIS
              	 	           data = client;
              	   run;
              
              %mend insert_client;
              
              ** retrieve list of clients that need update ;
              proc sql noprint;
                 create table clients as
                 select distinct a.client_id
                 from  &claimsa..tclient_cmk_rtnadr  a
                 where not exists
              	   (select 1 
              	    from &hec_tmp..tclt_fac_ovrd_his  b
              	    where a.client_id=b.client_id
              	      and b.expiration_dt > today()
              	      and b.effective_dt <= today()
              	   );
              quit;
              
              ** set temporary facility code ;
              data clients;
                format facility_code $3. ;
                set clients;
                facility_code='AFW';  ** default value ;
              run;
              
              proc sort data = clients nodupkey;
                     by client_id facility_code ;
              run;
              
              %let client_total = 0;
              
              data _null_;
                set clients end=eof ;
                  n=compress(put (_n_,4.));
                  call symput('client_id' || n, compress(client_id));
                  call symput('facility_code' || n, compress(facility_code));
                  if eof then call symput('client_total', n);
              run;
              
              %put NOTE:  Total number of clients: &client_total. ;
              
		** insert new clients into hercules table ;
		%if %upcase(&update_prod.) eq YES %then %do;
		  %if &client_total. ne 0 %then %do;
		    %do i = 1 %to &client_total. ;
		      %insert_client(&&client_id&i, &&facility_code&i);
		    %end;
		  %end;
		%end;
	   
	   %mend InsertFacilityCodes;
	   
	   %InsertFacilityCodes(yes);
	   
	   * ---> Set the email address for notification/reporting to the business users;
	   proc sql noprint;
	     select quote(trim(email)) into :business_user_email separated by ' '
	     from adm_lkp.analytics_users
	     where lowcase(qcp_id) in ('qcpu626', 'qcph016'); **nancy.jermolowicz sherri.duncan ;
	   quit;
	   
  	   %put NOTE: business_user_email = &business_user_email.;
 
	   
	   ** email list of clients that were inserted into TCLT_FAC_OVRD_HIS to hercules support ;
	   filename mymail email 'qcpap020@dalcdcp';
	   
	   data _null_;
	     set clients end=end;
	       file mymail
	   
	       to =(&primary_programmer_email)
	       cc =(&business_user_email)
	       subject='HCE SUPPORT: New Client Facility Codes (ACTION REQUIRED)' ;
	   
	       if _n_ =1 then put 'Hello:' ;
	       if _n_ =1 then put / "This is an automatically generated message to inform Hercules Support of the new client facility codes that were added to TCLT_FAC_OVRD_HIS for the Hercules Communication Engine.";
	       if _n_ =1 then put / "The add_rocc_cd.sas program updated a default facility code (AFW) to the following new client(s) which were added to Mainframe TCCE list: ";
		   if _n_ =1 then put  " " ;
	       put   client_id;
		   if end then put / "Please contact the business ASAP to receive the actual values for these faciltiy codes and update the clients in &hercules..TCLT_FAC_OVRD_HIS.";
	       if end then put / 'Thanks,';
	       if end then put   'Hercules Support';
	   run;
   
   	%end;  ** loop end - new_clt_cnt ;
   
   
   	*SASDOC-------------------------------------------------------------------------
   	  Remove duplicates from production facility xref zip3 table.
   	+-----------------------------------------------------------------------SASDOC*;
   	proc sql;
   	 create table work.tfacil_zip_xref_hs as
   	 select distinct facility_cd,
   		         first_three_zip_cd,
   		         eff_dt,
   		         exp_dt
   	 from claimsa.tfacil_zip_xref_hs
   	 where exp_dt > today()
   	   and eff_dt <= today()
	  ;
   	quit;
   	
	proc sort data = work.tfacil_zip_xref_hs ;
	       by first_three_zip_cd descending eff_dt;
	run;

	proc sort data = work.tfacil_zip_xref_hs nodupkey;
	       by first_three_zip_cd ;
	run;   	
   
   	*SASDOC-------------------------------------------------------------------------
   	  Apply the overrides of faciltiy code (MOC_PHM_CD) where the first 3 digits
   	  of the recipient zip code match the facility zip3 xref table. Exempt any
   	  facilities which are flagged with override code 0 in facility override table.
   	  Those will not be overriden at all and will use method in get_mocc_csphone
   	  macro.
   	+-----------------------------------------------------------------------SASDOC*;
   	proc sql;
   	  update work.&tbl_name_out_sh. as a
   	  set moc_phm_cd =
   	     (select b.facility_cd
   	      from   work.tfacil_zip_xref_hs  b
   	      where substr(a.zip_cd,1,3)=b.first_three_zip_cd
   		and b.exp_dt  > today()
   		and b.eff_dt <= today()
   	      )
   
   	  where a.client_id not in
   	     (select c.client_id
   	      from  &hec_tmp..tclt_fac_ovrd_his  c
   	      where c.override_cd=0
   		and c.expiration_dt > today()
   		and c.effective_dt <= today()
   	      );
   	quit;
   
   
   	*SASDOC-------------------------------------------------------------------------
   	  Apply the overrides of facility code (MOC_PHM_CD) for each client flagged
   	  to override (1 = Override) in the facility override rule table. These will
   	  override the zip3 overrides from the previous step also.
   	+-----------------------------------------------------------------------SASDOC*;
   	proc sql;
   	  update work.&tbl_name_out_sh.  a
   	  set moc_phm_cd =
   	     (select b.facility_cd
   	      from  &hec_tmp..tclt_fac_ovrd_his  b
   	      where a.client_id=b.client_id
   		and b.override_cd=1
   		and b.expiration_dt > today()
   		and b.effective_dt <= today()
   	      )
   
   	  where a.client_id in
   	     (select c.client_id
   	      from  &hec_tmp..tclt_fac_ovrd_his  c
   	      where c.override_cd=1
   		and c.expiration_dt > today()
   		and c.effective_dt <= today()
   	      );
   	quit;
   
   %end;   ** loop end - rocc_exist_in ;

%mend add_rocc_cd;

%add_rocc_cd;

