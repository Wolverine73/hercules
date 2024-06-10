/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  release_data.sas (macro)
|
| LOCATION: /PRG/sastest1/hercules/macros
|
| PURPOSE:  This macro creates a text file or SAS dataset (depending on the
|           TPHASE_RVR_FILE.FILE_USAGE_CD), and sends the file to the
|           appropriate destination.  The program also updates the letter count
|           quantity (TPHASE_RVR_FILE.LETTERS_SENT_QY), and notifies the users
|           of the status upon completion.
|
| INFO:     File_Usage_Code     Type of File
|           ---------------     ------------
|           1 = Mailing         text file
|           2 = Sample          text file
|           3 = Analysis        SAS dataset (only if destination is Zeus)
|
|           This macro expects to receive a dataset that contains all necessary
|           fields to produce the file layout.  The layout of the file is
|           determined by reading TFILE_BASE_FIELD (1st 12 fields are the same
|           on all files).  The variable fields are stored in TFILE_FIELD.  To
|           find the file_id, see TPGM_TASK_RVR_FILE.  Note that all fields
|           with SEQ_NB >= 200 are only included in "sample" files.
|
|           Additionally, if CLAIMSA.TPROGRAM.DFLT_INCLSN_IN = 1 and
|           TINITIATIVE.OVRD_CLT_SETUP_IN = 0 (book of business mailing), a
|           sample file should contain 1 record from each client.  Otherwise,
|           the sample file should contain a random 10% sample of the records.
|
| INPUT:    MACRO PARMS:
|
|             INIT_ID  = (Default: &INITIATIVE_ID)
|             PHASE_ID = (Default: &PHASE_SEQ_NB)
|             COM_CD   = (Default: &CMCNT_ROLE_CD)
|
|           DATASETS:
|
|             &hercules..tphase_rvr_file
|             &hercules..tinitiative
|             &claimsa..tprogram
|             DATA_DIR.T_&INIT_ID._&PHASE_ID._&COM_CD
|             &hercules..tfile_base_field
|             &hercules..tfile
|             &hercules..tfile_base_field
|             &hercules..tfile_field
|             aux_tab.set_ftp
|
| OUTPUT:   Updates to the particular task SAS dataset in the "pending" folder
|           and, upon a successful release process, email notifications to the
|           user and/or vendor, and updates to the TPHASE_RVR_FILE.
|
+-------------------------------------------------------------------------------
| HISTORY:  14OCT2003 - T.Kalfas  - Original.
|           08DEC2003 - T.Kalfas  - Modified to include/exclude the layout and
|                                   .ok files during the FTP_SAS_TO_TXT macro
|                                   call based on the &FTP_HOST value.
|           26DEC2003 - T.Kalfas  - Modified to compress fields in the final
|                                   output file and to format dates/datetimes
|                                   as DATE9./DATETIME25.6.
|           01JAN2004 - T.Kalfas  - Modified to pull SEND_OK_FILE & SEND_LAYOUT
|                                   FTP parameters from AUX_TAB.SET_FTP.
|           07JAN2004 - T.Kalfas  - Modified to conditionally compress character
|                                   columns based on SET_FTP.COMPRESS_COLS flag.
|                                   Also, added formatting of _AT (amount)
|                                   columns as 11.2 (per P. Wonders).
|           11JAN2004 - T.Kalfas  - Modified to compress all text files prior
|                                   FTP process.  %FTP_SAS_TO_TXT had to be
|                                   modified to be able to process binary files.
|           12JAN2004 - T.Kalfas  - Per P.Wonders, all Zeus-bound files should
|                                   be as SAS datasets.  Everything else goes
|                                   as text files.
|           23MAR2004 - J.Chen    - The decision was made to no longer filter out
|                                   fields with seq_nb > 200 for analysis files.
|                                   The program was modified accordingly.
|           24MAR2004 - J.Chen    - The DATA_QUALITY_CD was previously only being
|                                   kept on "analysis" files.  The program has 
|                                   been modified so that it will be kept on
|                                   "sample" files as well.
|           24MAR2004 - J.Chen    - Add logic to handle the LTR_RULE_SEQ_NB so that
|                                   it ends up in the correct location on the 
|                                   output file. (%else %do; where seq_nb ^= 999;
|			                        %end;)
|           12APR2006 - G.Dudley  - Added logic to add the "rtml_" prefix to the 
|                                   output file for program ID 73 only.  All other
|                                   output files will be create without the prefix
|
|	    Mar  2007 - Greg Dudley Hercules Version  1.0 
|
|           May  2007 - Brian Stropich Hercules Version  1.5.01
|                                   Modified the proc surveyselect to select 1 participant
|                                   per client and to create vendor files when released as
|                                   zeus.  When releasing as zeus the vendor files will reside
|                                   in the log directory of the program id.
|
|       Hercules Version  1.5.02
|       Sep 19 2007 - Carl J Starks
|                                   Add a filter (DATA_QUALITY_CD=1) to the &DS_PND dataset name for
|                                   RELEASED files.  All records from &DS_PND will be
|                                   retained EXCEPT FOR THE HARD EDITS (DATA_QUALITY_CD=3)
|                                   FOR FILES THAT HAVE "ACCEPT ALL" THE DATA_QUALITY_CD=2 WAS RECODED 
|                                   AS DATA_QUALITY_CD=1 and only records with DATA_QUALITY_CD=1 is kept on the
|                                   output final.
|
|       Hercules Version  1.5.03
|       Dec 10 2007 - Carl J Starks
|                                   Add a filter (DATA_QUALITY_CD in(1,2)) to the &DS_PND dataset name for
|                                   RELEASED files.  All records from &DS_PND will be
|                                   retained EXCEPT FOR THE HARD EDITS (DATA_QUALITY_CD=3)
|                                   FOR FILES THAT HAVE "ACCEPT ALL" THE DATA_QUALITY_CD=2 use to be RECODED 
|                                   AS DATA_QUALITY_CD=1 but now is kept as DATA_QUALITY_CD=2 and only records with 
|                                   DATA_QUALITY_CD=1 was kept on the
|                                   output final but now data_quality_cd = 1 and 2 are kept on the final output.
|                 
|                                  letters sent quanity summed only data_quality_cd of 1 because we use to change
|                                  data_quality_cd from 2 to 1 now we keep the data_quality_cd of 2 we   
|                                  CHANGED the case statement from when 1 to when (1,2) 
|                                  so that letters_sent_qy would be summed when data_quality_cd was 1 or  2 
|
|       Hercules Version  2.0.01
|       Apr 18 2008 - Carl J Starks
|		                           added logic to Identify whether the file is a book of business mailing, i.e.,
|                                  TPROGRAM_TASK.DEFLT_CLT_SETUP_CD=1 or 2 & TPROGRAM_TASK.BOOK_OF_BUS_IN=1.
|                                  &QL_ADJ=1 & TPROGRAM_TASK.BOOK_OF_BUS_IN=0.		
|        
|       Jul 22 2008 - Gregory Dudley
|                              Replaced %sysfunc(compress( with %cmpres(
|      
|		01OCT2008 - SY
| 					- ADDED LOGIC TO UPDATE THE &DWHM..T_MLNG TABLE NEEDED FOR IBENEFIT PROACTIVE ACCESS 
| 						HEALTH ALERT REPORT.
|
|       			- ALSO ADDED TWO CONDITIONAL STATEMENTS TO RESET THE DATA QUALITY CODE TO NULL FOR 
|					  FILE SEQUENCE 2 AND 3 WHEN PROCESSING IBENEFIT HEALTH ALERT REPORT.
|
|	  18NOV2008 SR    : FIX ADDED TO RELEASE INITIATIVES THAT WERE CREATED/EXECUTED
|	                    PRIOR TO 20NOV2008 TO BE RELEASED WITHOUT THE ADDITION
|	                    OF THE NEWLY ADDED BASE COLUMNS ADJ_ENGINE, CLIENT_LEVEL_1,
|	                    CLIENT_LEVEL_2, CLIENT_LEVEL_3
|					- Hercules Version  2.1.2.01
|					 
+-----------------------------------------------------------------------HEADER*/

/*SASDOC===================================================================
 * 07/23/2008 g.o.d.
 * Super Blocking SAS system option for diagnostics
 *==================================================================SASDOC*/
proc options group=memory;
run;

options symbolgen;
%macro release_data2(init_id=&initiative_id,
                    phase_id=&phase_seq_nb,
                    com_cd=&cmctn_role_cd);
                    
 %GLOBAL adhoc_root ftp_ok vendor_email autorelease;
options symbolgen mlogic mprint;
  %*SASDOC=====================================================================;
  %* Scope the macro variables.
  %*====================================================================SASDOC*;

  %global  letter_type_qy_cd
	   	   release_data_ok;

  %let release_data_ok=0;

  %local _col_delimiter
         _col_name_sfx
         _compress_file
         _destination
         _destination_cd
         _destination_type_cd
         _ds_opts
         _first_row_col_names
         _send_ok_file
         _send_layout
	 	 book_of_business
         compress_cols
         copy_ok
         destination_flg
         destination_root_dir
         destination_sub_dir
         ds_pnd
         ds_pnd_where
         file_id
		 file_id99
         file_name
         file_transferred_flg
         file_usage_cd
         hsc_usr_id
	 	 hsu_usr_id
         librc
         max_base_seq_nb
         missing_fields
         recip_sub_sort_str
         recs_transferred
         required_fields
         rtp_nm
         rvr_file_path_tx
         transfer_ok
         update_err_flg
         vendor_email
		 MESSAGE_FOR_RELEASE_DATA
  ;


  %*SASDOC=====================================================================;
  %* Make sure that the initiative ID, phase sequence number, and communication
  %* role code parameters contain numeric values.
  %*====================================================================SASDOC*;

    proc sql noprint;
      %*SASDOC=================================================================;
      %* Retrieve file characteristics from &HERCULES..TPHASE_RVR_FILE and store
      %* in macro variables for conditional processing later in this macro.
      %*================================================================SASDOC* ;

      select  COMPRESS(PUT(file_id,8.)),  
			  COMPRESS(PUT(file_usage_cd,8.)),
			  COMPRESS(PUT(destination_cd,8.)),
			  COMPRESS(hsu_usr_id),  
			  COMPRESS(hsc_usr_id),  
			  COMPRESS(PUT(release_status_cd,8.)),
			  COUNT(*)
      into   :file_id, :file_usage_cd, :_destination_cd, 
			 :hsu_usr_id, :hsc_usr_id, :release_status_cd,
			 : n_rows
      from   &hercules..tphase_rvr_file
      where  initiative_id = &init_id    and
             phase_seq_nb  = &phase_id   and
             cmctn_role_cd = &com_cd ;
		QUIT;

		%PUT   destination_cd=&destination_cd.;

      %IF &n_rows. =0 %THEN 
							%DO;
						%LET err_fl=1;
    %LET MESSAGE_FOR_RELEASE_DATA=Invalid combination of initiative_id phase_seq_nb cmctn_role_cd  ;
							%END;


	 %*SASDOC=================================================================;
	  %* C.J.S APR2008
      %* Identify whether the file is a book of business mailing, i.e.,
      %* TPROGRAM_TASK.DEFLT_CLT_SETUP_CD=1 or 2 & TPROGRAM_TASK.BOOK_OF_BUS_IN=1.
      %* &QL_ADJ=1 & TPROGRAM_TASK.BOOK_OF_BUS_IN=0.
      %* This is necessary in determining the content of sample files later in
      %* in this macro.
      %*================================================================SASDOC*;

	 proc sql noprint;
      select   /* case
                  when(init.ovrd_clt_setup_in=0 and prog.dflt_inclsn_in=1)
                  then 1
                  else 0
                  end, */
                  translate(compbl(trim(left(short_tx))),'_',' ','_','/')
      into     /* :book_of_business_flg, */
                  :destination_sub_dir
      from    &hercules..tinitiative   init,
              &claimsa..tprogram       prog
      where   init.initiative_id     = &init_id       
         and  prog.program_id        = init.program_id ;
       QUIT;

  %let MAX_FILE_SEQ_NB = .;
  PROC SQL NOPRINT;
      SELECT DISTINCT MAX(FILE_SEQ_NB) INTO : MAX_FILE_SEQ_NB
       FROM &HERCULES..TFILE_FIELD
         WHERE FILE_ID =&FILE_ID;
                ;
	QUIT; 	

  %put MAX_FILE_SEQ_NB = &MAX_FILE_SEQ_NB.;
  %IF &MAX_FILE_SEQ_NB. EQ . %THEN %LET MAX_FILE_SEQ_NB = 1;
  %put MAX_FILE_SEQ_NB = &MAX_FILE_SEQ_NB.;

  %DO FILE_SEQ_NB=1 %TO &MAX_FILE_SEQ_NB.;

	%IF &FILE_SEQ_NB = 1 and &FILE_ID = 17 %THEN %LET FILE_ID99 = 17;
  	%ELSE %IF &FILE_SEQ_NB = 1 %THEN %LET FILE_ID99 = 99;
	%ELSE %LET FILE_ID99 = &FILE_ID.;
	
	%put file_id = &FILE_ID. ;
	%put FILE_ID99 = &FILE_ID99. ;
	%let err_fl=0;

    %IF &err_fl=1 %THEN %GOTO EXIT_RD;

     %LET _ds_opts=%str();
     %LET copy_ok=0;
     %LET ds_pnd=;
     %LET ds_pnd_where=;
     %LET file_name=;
     %LET file_transferred_flg=0;
     %LET max_base_seq_nb=0;
     %LET missing_fields=;
     %LET recip_sub_sort_str=;
     %LET recs_transferred=0;
     %LET required_fields=;
     %LET transfer_ok=0;
	 %LET strata=;
           
      %*SASDOC=================================================================;
      %* Identify the fields that are expected to be in the file layout.  These
      %* fields are pulled from the &HERCULES..TPHASE_RVR_FILE, TFILE,
      %* TFILE_FIELD, TFILE_BASE_FIELD, and TFILE_FIELD tables.
	  %* When a mailing file is being generated, only fields with seq_nb
	  %* less than 200 will be considered.  When a sample or analysis file
	  %* is being generated, seq_nb 999 is not considered in determining
	  %* max_base_seq_nb because it corresponds to LTR_RULE_SEQ_NB and
	  %* that field should be at the end of the layout.
      %*================================================================SASDOC*;

      /** SR 18NOV2008: FIX ADDED TO RELEASE INITIATIVES THAT WERE CREATED/EXECUTED
	                    PRIOR TO 20NOV2008 TO BE RELEASED WITHOUT THE ADDITION
	                    OF THE NEWLY ADDED BASE COLUMNS ADJ_ENGINE, CLIENT_LEVEL_1,
	                    CLIENT_LEVEL_2, CLIENT_LEVEL_3 **/
/*		PROC SQL NOPRINT;*/
/*			SELECT HSC_TS INTO: HSC_TS*/
/*			FROM &HERCULES..TINITIATIVE*/
/*			WHERE INITIATIVE_ID=&INITIATIVE_ID;*/
/*		QUIT;*/
/*		%PUT NOTE: HSC_TS = &HSC_TS. ;*/
/**/
/*		%IF &HSC_TS. > 20NOV2008:01:00:00.000000 %THEN %DO; */
/*			%let seq_cons_history = %str();*/
/*		%end;*/
/*		%else %do;*/
/*			%let seq_cons_history = %str(and seq_nb not in (13,14,15,16));*/
/*		%end;*/

	/** 02DEC2008: MODIFIED THE ABOVE FIX TO MAKE IT WORK FOR SAS VERSION 9 **/


		PROC SQL NOPRINT;
			SELECT DATEPART(HSC_TS) INTO: HSC_TS
			FROM &HERCULES..TINITIATIVE
			WHERE INITIATIVE_ID=&INITIATIVE_ID;
		QUIT;

		%PUT NOTE: HSC_TS = &HSC_TS.;

		DATA _NULL_;
			HSC_TS_SAS=&HSC_TS.;
			PUT 'NOTE: HSC_TS_SAS = ' HSC_TS_SAS MMDDYY10.;
			IF HSC_TS_SAS > '20NOV2008'D THEN DO; 
				CALL SYMPUT('SEQ_CONS_HISTORY',' ');
			END;

			ELSE DO;
				CALL SYMPUT('SEQ_CONS_HISTORY','AND SEQ_NB NOT IN (13,14,15,16)');
			END;
		RUN;

		%PUT NOTE: SEQ_CONS_HISTORY = &SEQ_CONS_HISTORY.;


	  proc sql noprint;
       select   COALESCE(max(seq_nb),0)
        into     :max_base_seq_nb
        from     &hercules..tfile_base_field

      %***;


      %*if &file_usage_cd^=2 %then (J.Chen, 3/23/04);

		%if &file_usage_cd=1 %then
					%do;
              where seq_nb<200
			        &seq_cons_history.
      				%end;

		%else %do;
		      where seq_nb ^= 999
			        &seq_cons_history.
			  %end;
		AND &FILE_SEQ_NB.=1
			;
      ;
    QUIT;

	 proc sql noprint;
      create   table work.required_fields  as
      select   rcvr.initiative_id,
               rcvr.phase_seq_nb,
               rcvr.cmctn_role_cd,
               rcvr.letters_sent_qy,
               rcvr.file_usage_cd,
               rcvr.destination_cd,
               rcvr.file_id,
               rcvr.hsc_usr_id,
               rcvr.hsu_usr_id,
               file.short_tx          as file_short_tx,
               file.long_tx           as file_long_tx,
               flds.seq_nb            as field_seq_nb,
               flds.new_seq_nb        as field_new_seq_nb,
               fdes.format_sas_tx,

               upcase(fdes.field_nm)  as field_nm,
               fdes.short_tx          as field_short_tx,
               fdes.long_tx           as field_long_tx
      from     &hercules..tphase_rvr_file 					AS rcvr,	
               &hercules..tfile(WHERE=(file_id=&file_id99))   AS file,
              (select &file_id99 as file_id,
                      base.field_id,
                      base.seq_nb,
                      base.seq_nb as new_seq_nb
               from   &hercules..tfile_base_field(WHERE=(seq_nb=&FILE_SEQ_NB. * seq_nb &seq_cons_history.))  AS base
			   union corresponding
               select flds0.file_id,
                      flds0.field_id,
                      flds0.seq_nb,
                     (flds0.seq_nb + &max_base_seq_nb.) as new_seq_nb
               from   &hercules..tfile_field(WHERE=(file_id=&file_id99.
			   	 							 AND  FILE_SEQ_NB=&FILE_SEQ_NB.)) AS flds0   
				)        						AS  flds,
               &hercules..tfield_description   	AS	fdes

      where    rcvr.initiative_id   = &init_id      and
               rcvr.phase_seq_nb    = &phase_id     and
               rcvr.cmctn_role_cd   = &com_cd       and(
               rcvr.file_id         = file.file_id or &file_id99 = 99 or &file_id99 = 17) and
			   file.file_id			= flds.file_id  and
               flds.field_id        = fdes.field_id

      %*SASDOC=================================================================;
      %* If the output file is not a "sample" then exclude all of the fields
      %* where SEQ_NB >= 200.
	  %*
	  %* Modifications: 1) SEQ_NB >= 200 is now only being excluded for 
	  %*                   "mailings" (QCPI134, 3/24/04)
      %*================================================================SASDOC*;

      %*if &file_usage_cd^=2 %then %str( and flds.seq_nb < 200 ) (J.Chen, 3/23/04);
      %if &file_usage_cd=1 %then %str( and flds.seq_nb < 200 );

      order by flds.new_seq_nb;

    quit;

	 %set_error_fl; 
    
    %*SASDOC===================================================================;
    %* Cleanup the &destination_sub_dir macro variable.  &, <space>, and /
    %* were translated to _ in the initial query.  Now, the remaining spaces
    %* are removed.
    %*==================================================================SASDOC*;

    %*SASDOC===================================================================;
    %* 07/22/2008 g.o.d.
    %* Replaced %sysfunc(compress( with %cmpres(
    %*==================================================================SASDOC*;

    %let destination_sub_dir=%cmpres(&destination_sub_dir);
    %*SASDOC===================================================================;
    %* Store the name of the pending dataset in a macro variable.
    %*==================================================================SASDOC*;

    %LET ds_pnd_main=data_pnd.t_&init_id._&phase_id._&com_cd;
    %IF &FILE_SEQ_NB=1 %THEN %let ds_pnd=&ds_pnd_main.;
    %ELSE %let ds_pnd=&ds_pnd_main._&FILE_SEQ_NB.;		


    %*SASDOC===================================================================;
    %* Confirm that the task pending library and dataset exist.
    %*==================================================================SASDOC*;

    %if %sysfunc(exist(&ds_pnd)) NE 1 %then  %do;
			%LET err_fl=1;
			%LET MESSAGE_FOR_RELEASE_DATA=%STR(ERROR: (&SYSMACRONAME): &ds_pnd does not exist.);
    %end;
    %IF &err_fl=1 %THEN %GOTO EXIT_RD;

	/*
      %*SASDOC=================================================================;
      %* Add a filter (DATA_QUALITY_CD=1) to the &DS_PND dataset name for
      %* mailing  files.  All records from &DS_PND will be
      %* retained for "Analysis" datasets as will the DATA_QUALITY_CD variable.
	  %*C.J.S - 09/19/07
      %*deleted the following line so that the pgm will keep all records with
      %*DATA_QUALITY_CD=1 
      %*      if &file_usage_cd^=3 AND &FILE_SEQ_NB.=1 %then
      %*================================================================SASDOC*;

	  %*SASDOC=================================================================;
      %* Add a filter (DATA_QUALITY_CD=1) to the &DS_PND dataset name for
      %* mailing  files.  All records from &DS_PND will be
      %* retained for "Analysis" datasets as will the DATA_QUALITY_CD variable.
	  %*C.J.S - 12/10/07
      %*CHANGED the following line so that the pgm will keep all records with
      %*DATA_QUALITY_CD=1 AND 2 
      %*      %let ds_pnd_where=%str((where=(data_quality_cd=1)));
      %*================================================================SASDOC*;
      
    */
      %if &file_id. = 17 and &FILE_SEQ_NB=2 %then %do;  **ibenefit 1.0 - detail file;
        %let ds_pnd_where=%str();
      %end;
      %else %if &file_id. = 26 and &FILE_SEQ_NB=2 %then %do;  **ibenefit 2.0 - detail file;
        %let ds_pnd_where=%str();
      %end;
	  %else %if &file_id. = 28 and &FILE_SEQ_NB=2 %then %do;  **proactive access health alert - detail file;
	 	 %let ds_pnd_where=%str();
      %end;
	  %else %if &file_id. = 28 and &FILE_SEQ_NB=3 %then %do;  **proactive access health alert - health alert file;
	 	 %let ds_pnd_where=%str();
      %end;
      %else %if &file_usage_cd ne 1 and &file_id. = 26 %then %do;  **edw member id issue - not a mailing and ibenefits;
        %let ds_pnd_where=%str((where=(data_quality_cd IN(1,2,4))));
      %end;      
      %else %do;
        %let ds_pnd_where=%str((where=(data_quality_cd IN(1,2))));
      %end;

	  proc sql noprint;
	   select COUNT(*) INTO : n_obs
	   from &ds_pnd.&ds_pnd_where;
	  quit;
	  
          %if &FILE_SEQ_NB.=1 %then %let n_obs_main=&n_obs.;

          %if &n_obs=0 %then  %do;
            
               %LET err_fl=1;
               %LET MESSAGE_FOR_RELEASE_DATA=%STR(ERROR: (&SYSMACRONAME): &ds_pnd has &n_obs observations.);
               
               PROC SQL NOPRINT;
                 SELECT QUOTE(TRIM(email)) INTO :_em_to_user SEPARATED BY ' '
                 FROM ADM_LKP.ANALYTICS_USERS
                 WHERE UPCASE(QCP_ID) IN ("&hsu_usr_id");
               QUIT;
               
               PROC SQL NOPRINT;
                 SELECT QUOTE(TRIM(email)) INTO :_em_c_user SEPARATED BY ' '
                 FROM ADM_LKP.ANALYTICS_USERS
                 WHERE UPCASE(QCP_ID) IN ("&hsc_usr_id");
               QUIT;
               
               %let msg_str1=%bquote(There were no records that meet your selected criteria for Initiative &&initiative_id.);
               %let msg_str2=%bquote(If any records were generated, the daily quality code was not "good".);
               %LET MESSAGE_FOR_RELEASE_DATA_USER=%str(&msg_str1. &msg_str2.);
               
               %email_parms(EM_TO=&_em_to_user,
                            EM_CC=&_em_c_user,
                            EM_SUBJECT=No record were found for Initiative &initiative_id. ,
                            EM_MSG=%str(&MESSAGE_FOR_RELEASE_DATA_USER.)  );
               
          %end; /* End of do-group for &n_obs=0 */

          %if &err_fl=1 %then %goto EXIT_RD;

	 
          %*SASDOC===============================================================;
          %* Determine whether all of the "layout" fields exist in the pending
          %* dataset.  If any fields do not exist, then they are identified in
          %* the log and the process is aborted (and the release_ts is set to
          %* null so that the file continues to be presented to the user).
          %*==============================================================SASDOC*;

          proc contents data=&ds_pnd out=work.pnd_fields(keep=name) noprint;
          run;
          
          proc sql noprint;
            create   table work.missing_fields as
            select   field_seq_nb, field_nm
            from     work.required_fields
            where    upcase(field_nm) not in (select upcase(name) from work.pnd_fields)
            order by field_new_seq_nb;

            select   (count(*)>0)
            into     :missing_fields_flg
            from     work.missing_fields;
          quit;

	   %set_error_fl; 

	  data work.required_fields;
            set work.required_fields;
            format field_nm_fmt $60.;
            field_nm_fmt=trim(field_nm)||' format='||format_sas_tx;
          run;

          %if ^&missing_fields_flg %then %do;
          
/*               proc sql noprint;*/
/*                 select   field_nm_fmt into     :required_fields   separated by ', '*/
/*                 from     work.required_fields*/
/*                 order by field_new_seq_nb;*/
/*               quit;*/
/*			   %reset_sql_err_cd;*/

			   proc sql noprint;
                 select   field_nm_fmt 
                 into     :required_fields   separated by ', '
                 from     work.required_fields
				 group by field_nm_fmt 
				 having field_new_seq_nb = min(field_new_seq_nb)
                 order by field_new_seq_nb;
               quit;
          
               %put required_fields &required_fields ;

          %end;    
          %else %do;
          
               proc sql noprint;
                 select   field_nm into     :missing_fields    separated by ', '
                 from     work.required_fields
                 where    field_nm not in (select upcase(name) from work.pnd_fields)
                 order by field_new_seq_nb;
               quit;

	  %let err_fl=1;
          %let MESSAGE_FOR_RELEASE_DATA=%STR(ERROR: (&SYSMACRONAME): The folowing requiered fields are missing from the input dataset : &missing_fields..);
							%END;
          proc sql noprint;
            drop  table work.missing_fields;
          quit;

          %if &err_fl=1 %then %goto EXIT_RD;

          %*SASDOC=============================================================;
          %* Sort the incoming dataset by receiver and subject ID, only keep
          %* the required variables/columns, and filter the records/rows for
          %* "sample" files.
          %*============================================================SASDOC*;
          %*SASDOC=============================================================;
          %* Temporarily add the DATA_QUALITY_CD to the list of "required
          %* fields".  This is necessary to retain the DATA_QUALITY_CD until
          %* the updates have been made to the TPHASE_RVR_FILE.LETTERS_SENT_QY.
          %* DATA_QUALITY_CD is permanently retained for "analysis" datasets.
          %*============================================================SASDOC*;
          %IF &FILE_SEQ_NB.=1 %THEN %LET required_fields=&required_fields, DATA_QUALITY_CD;
          %*SASDOC=============================================================;
          %* Determine if SUBJECT_ID exists as a variable in WORK.FINAL.  This
          %* will define the sort key.
          %*============================================================SASDOC*;

          %let dsid=%sysfunc(open(&ds_pnd));
          %if %sysfunc(varnum(&dsid,SUBJECT_ID)) %then %let recip_sub_sort_str=recipient_id, subject_id;
          %else %let recip_sub_sort_str=recipient_id;
          
          %if %sysfunc(varnum(&dsid,RANK_SAVING))  %then %let recip_sub_sort_str=&recip_sub_sort_str., RANK_SAVING;
          
          %if %sysfunc(varnum(&dsid,CLIENT_ID)) %then %do;
              %let recip_sub_sort_str=CLIENT_ID, &recip_sub_sort_str. ;
              %let strata=%STR(STRATA CLIENT_ID);
          %end;
          %let dsid=%sysfunc(close(&dsid));

          proc sql noprint;
            create   table work.final as
            select   *
            from     &ds_pnd.&ds_pnd_where
            order by &recip_sub_sort_str.;
          quit;

           %set_error_fl; 

          %*SASDOC=============================================================;
          %*  May  2007    - Brian Stropich                                               
          %*  For "sample" files, use proc surveyselect to randomly select records
          %*  at the rate of .0001% with min records of 1 and max records of 1000000
          %*  sampling will be evenly applied among client.
          %*
          %*  Business requests that there is 1 participant per client.
          %*============================================================SASDOC*;


          %if &file_usage_cd=2 and &n_obs_main>0 AND &FILE_SEQ_NB.=1 %then %do;
          
	     proc surveyselect data=work.final method=srs
                  nmin=1 nmax=1000000 samprate=0.000001
                  seed=121718 out=work.final;
                  strata client_id;
             run;
					 
    
          %end; /* End of do-group for &file_usage_cd=2 */

		  %IF &FILE_SEQ_NB.=1 %THEN %DO;
             
			data final_main;
			 set work.final;
			run;
			
                  %END; /* End of do-group for &FILE_SEQ_NB.=1 */
                  %ELSE	 %DO;
                  
			 proc sql;
			  create table work.final_temp as
			  select a.*
			  from work.final 		as a,
			       work.final_main 	as b
			  where a.recipient_id=b.recipient_id
			  order by &recip_sub_sort_str.  ;
			quit;

		   data WORK.FINAL;
		    set WORK.FINAL_temp;
			run;
			
                  %END; /* End of do-group for &FILE_SEQ_NB. NE 1 */

          proc sql noprint;

            %*SASDOC===========================================================;
            %* Determine where to send the final output.  The destinations are
            %* stored in an auxiliary table (AUX_TAB.SET_FTP).  The file,
            %* whether a text file or SAS dataset, will be compressed and FTPd
            %* to that location.
            %*==========================================================SASDOC*;

            select   count(*),
                     destination_type_cd,
                     COMPRESS(destination),
                     destination_root_dir,
                     COMPRESS(ftp_host),
                     send_ok_file,
                     send_layout,
                     compress_cols,
                     compress_file,
                     COMPRESS(notify_email)
            into     :destination_flg,
                     :_destination_type_cd,
                     :_destination,
                     :destination_root_dir,
                     :ftp_host,
                     :_send_ok_file,
                     :_send_layout,
                     :compress_cols,
                     :_compress_file,
                     :vendor_email
            from     aux_tab.set_ftp
            where    destination_cd = &_destination_cd
			;
         QUIT;
             %set_error_fl; 
            %*SASDOC===========================================================;
            %* Report the destination and FTP macro parameters.
            %*==========================================================SASDOC*;

	    %put NOTE: (&SYSMACRONAME):  PROGRAM_ID           = &PROGRAM_ID;
	    %put NOTE: (&SYSMACRONAME):  DESTINATION_FLG      = &DESTINATION_FLG;
	    %put NOTE: (&SYSMACRONAME):  _DESTINATION_CD      = &_DESTINATION_CD;
	    %put NOTE: (&SYSMACRONAME):  _DESTINATION_TYPE_CD = &_DESTINATION_TYPE_CD;
            %put NOTE: (&SYSMACRONAME):  _DESTINATION         = &_DESTINATION;
            %put NOTE: (&SYSMACRONAME):  DESTINATION_ROOT_DIR = &DESTINATION_ROOT_DIR;
            %put NOTE: (&SYSMACRONAME):  FTP_HOST             = &FTP_HOST;
            %put NOTE: (&SYSMACRONAME):  _SEND_OK_FILE        = &_SEND_OK_FILE;
            %put NOTE: (&SYSMACRONAME):  _SEND_LAYOUT         = &_SEND_LAYOUT;
            %put NOTE: (&SYSMACRONAME):  COMPRESS_COLS        = &COMPRESS_COLS;
            %put NOTE: (&SYSMACRONAME):  _COMPRESS_FILE       = &_COMPRESS_FILE;
            %put NOTE: (&SYSMACRONAME):  VENDOR_EMAIL         = &VENDOR_EMAIL;

            %*SASDOC===========================================================;
            %* Create a WORK.FINAL dataset to contain only the "required fields"
            %* or rather the file layout fields.
            %*==========================================================SASDOC*;
          
			PROC SQL;
            CREATE  TABLE WORK.FINAL_temp AS
            	SELECT DISTINCT &required_fields.
                  FROM     work.final
            ORDER BY &recip_sub_sort_str;
	  	   QUIT;

		   data WORK.FINAL;
		    set WORK.FINAL_temp;
			run;

/*		   		%reset_sql_err_cd;*/
				 %set_error_fl; 
	    	   %*SASDOC================================================;
               %* Specify formats for any date/datetime columns. These  
		       %* columns are identified by suffix, i.e., "_DT" = DATE,
		       %* "_TS" = DATETIME.  Columns with the suffix "_AT" are 
		       %* formatted as 11.2 per P.Wonders (01/08/04).  Per
		       %* J.Hou (01/12/04), format should be changed to 13.2.
               %*===============================================SASDOC*;

               
          %*SASDOC=============================================================;
          %* Send final output files to the appropriate destination.
          %*============================================================SASDOC*;

          %IF &destination_flg NE 1 %THEN 
								%DO;
			%LET err_fl=1;
			%LET MESSAGE_FOR_RELEASE_DATA=%STR(ERROR: (&SYSMACRONAME): Invalid destination code: &_destination_cd..);
								%END;
		  %IF &err_fl=1 %THEN %GOTO EXIT_RD;

            %*SASDOC===========================================================;
            %* Determine the number of observations in the final output file.
            %* This will be used to determine a successful transport process.
            %*==========================================================SASDOC*;

			PROC SQL noprint;
	   			SELECT COUNT(*) INTO : _nobs
	    	 FROM work.final
		 		;
	  		QUIT;
			%IF &_nobs=0 %THEN
					%DO;
			%LET err_fl=1;
			%LET MESSAGE_FOR_RELEASE_DATA=%STR(ERROR: (&SYSMACRONAME): No records to send.);
					%END;
		    %IF &err_fl=1 %THEN %GOTO EXIT_RD;
            %*=================================================================;
            %* Determine the full directory path on the destination based on
            %* the DESTINATION_CD and FILE_USAGE_CD.
            %*================================================================*;
            %if &_destination_cd=1 %then 
			 %do;

              %*SASDOC=========================================================;
              %* Derive the full directory path on the ftp destination for
              %* "Clinical Ops" files:
              %*
              %* The root directory has already been derived from the
              %* CLAIMSA.TPROGRAM.SHORT_TX field by replacing spaces, slashes,
              %* and ampersands with underscores.
              %*
              %* Adjust the &DESTINATION_SUB_DIR for "Clinical Ops" to add
              %* another subdirectory for the particular file based on the
              %* FILE_USAGE_CD:  1 = ./Mailing, 2 = ./Sample, 3 = ./Analysis.
              %*========================================================SASDOC*;

            %IF &FILE_SEQ_NB.=1 
			%THEN  %let destination_sub_dir=%cmpres(&destination_sub_dir)%str(/)%scan(MAILING SAMPLE ANALYSIS,%upcase(&file_usage_cd));

            %end; /* End of do-group for &_destination_cd=1 */
            %else %if &_destination_cd=2 %then 
						%do;

              %*SASDOC=========================================================;
              %* Derive the full directory path on the ftp destination for
              %* "Zeus" files: The file will be sent to the &ADHOC_ROOT dir
              %* (should be something like /DATA/sasadhoc1/hercules).
              %*========================================================SASDOC*;
                      
              %if "&adhoc_root."="" %then %let adhoc_root=%bquote(/DATA/sasadhoc);

              %let destination_sub_dir=%bquote(&adhoc_root.1/hercules);

            			%end;  /* End of do-group for &_destination_cd=2 */	
              %else 
				  		%do;
              %*SASDOC=========================================================;
              %* Derive the full directory path on the ftp destination for
              %* "Client" files: The root directory is stored in the AUX_TAB.
              %* SET_FTP.DESTINATION_ROOT_DIR field.
              %*========================================================SASDOC*;

              %let destination_sub_dir=&destination_root_dir;

            			%end; /* End of do-group for &_destination_cd NOT IN (1,2) */

	    %put NOTE:(&sysmacroname): Task output will be directory to %upcase(&ftp_host):&destination_sub_dir..;
            %*SASDOC===========================================================;
            %* Remove the DATA_QUALITY_CD from the list of required fields
            %* prior to generating the final output file, unless the dataset
            %* is for analysis.  Note that this is only done with a "drop"
            %* as a dataset option in the call to %FTP_SAS_TO_TXT, and so
            %* the DATA_QUALITY_CD is left in WORK.FINAL for subsequent use
            %* in determining the new LETTERS_SENT_QY for update.
      			%*
      			%* Modifications: 1) DATA_QUALITY_CD will now be retained in 
      			%*                   "sample" files as well. (QCPI134, 3/24/04)
            %*==========================================================SASDOC*;

            %*if &file_usage_cd^=3 (J.Chen, 3/24/04);

            %if &file_usage_cd.=1 AND &FILE_SEQ_NB.=1
            %then %let _ds_opts=%str(drop=data_quality_cd);
            %else %let _ds_opts=%str();
            
              %*SASDOC===========================================================;
              %* Determine whether the final output file is to be a text file or
              %* a SAS dataset.  "Mailing" and "Sample" files (FILE_USAGE_CD = 1
              %* and 2, respectively) are always generated as text files.  A file
              %* used for "Analysis" (FILE_USAGE_CD = 3) will be a SAS dataset if
              %* the destination is Zeus (DESTINATION_CD = 2), otherwise, it will
              %* be a text file.
              %*==========================================================SASDOC*;
              %*=================================================================;
              %* FTP TEXT OUTPUT FILES TO APPROPRIATE DESTINATION.
              %*================================================================*;

              %IF &err_fl=1 %THEN %GOTO EXIT_RD;

	      %if &_destination_cd^=2 %then %do;
	           
                   %*SASDOC=========================================================;
                   %* Create a new file name for text output files to also contain
                   %* the FILE_ID: t_&init_id._&phase_id._&com_cd._&file_id.  The
                   %* extension of this file will be attached as appropriate during
                   %* the copy/FTP process.
                   %*========================================================SASDOC*;
                   %*SASDOC=========================================================;
                   %* If the file is destined for the TESTFTP or PRODFTP servers,
                   %* it will ultimately be making its way out to an external client
                   %* and the layout and .ok files should be sent with the data file.
                   %* Otherwise, only the data file is sent.  These flags have been
                   %* retrieved from AUX_TAB.SET_FTP as _SEND_OK_FILE & _SEND_LAYOUT.
                   %*
                   %*NOTE:
                   %* 04/12/2006 G. Dudley - Added logic to add the prefix "rtml_" to 
                   %*                        the output file when program ID is 73
                   %*========================================================SASDOC*;
		     	  %if &program_id=73 %then %do;
                   %let file_name_main=&adhoc_root.1/hercules/rtml_t_&init_id._&phase_id._&com_cd._&file_id;
		     	  %end;
		     	  %else %do;
                   %let file_name_main=&adhoc_root.1/hercules/t_&init_id._&phase_id._&com_cd._&file_id;
		     	  %end;
		     	  %IF &FILE_SEQ_NB.=1 %THEN %LET file_name=&file_name_main.;
		     	  %ELSE 					%LET file_name=&file_name_main._&FILE_SEQ_NB.; 
	           
                   %if &_destination_type_cd=0 %then 
		     			%do;
                     %let _first_row_col_names=1;
                     %let _col_delimiter=%str(|);
                   		%end; /* End of do-group for &_destination_type_cd=0 */
                   %else 
		     			%do;
                     %let _first_row_col_names=0;
                     %let _col_delimiter=%str();
                   		%end; /* End of do-group for &_destination_type_cd NE 0 */
                   %ftp_sas_to_txt(tbl_in=work.final,
                                   ds_opts=&_ds_opts,
                                   file_out=&file_name..txt,
                                   layout_out=&file_name..txt.layout,
                                   rhost=&ftp_host,
                                   rdir=&destination_sub_dir,
                                   send_ok_file=&_send_ok_file,
                                   send_layout=&_send_layout,
                                   compress_file=&_compress_file,
                                   first_row_col_names=&_first_row_col_names,
                                   col_delimiter=&_col_delimiter
                                  );
	           
              %end; /* End of do-group for &_destination_cd^=2 */
              %else  %do;  
	           %***** All Zeus-bound files will be SAS datasets. *****;
                   %let librc=%sysfunc(libname(_tmpout,&destination_sub_dir));
				   %let librc = 0;
                   %if &librc=0 %then %do;
                   
                        %LET copy_ok=0;
                          
                        proc sql noprint;
		          create table _tmpout.%scan(&ds_pnd,2,.) as
		          select  distinct * 
		          from work.final
                        quit;
                        
                        %IF &SQLRC=0 %THEN  %LET copy_ok=1;
                        
                        %*SASDOC=============================================================;
                        %*  May  2007    - Brian Stropich                                               
                        %*  For file destination ZEUS, the release files will be exported to the      
                        %*  log folder of the program id which is known as zeus_root (i.e., log_dir) 
                        %*  for the program.                                               
                        %*============================================================SASDOC*;
                        %let zeus_root=&LOG_DIR.;
                        
	                %if &program_id=73 %then %do;
                          %let file_name_main=&zeus_root./rtml_t_&init_id._&phase_id._&com_cd._&file_id;
	                %end;
	                %else %do;
                          %let file_name_main=&zeus_root./t_&init_id._&phase_id._&com_cd._&file_id;
	                %end;
	                
	                %if &FILE_SEQ_NB.=1 %then %let file_name=&file_name_main.;
	                %else  %let file_name=&file_name_main._&FILE_SEQ_NB.; 
	                
                        %if &_destination_type_cd=0 %then  %do;
                          %let _first_row_col_names=1;
                          %let _col_delimiter=%str(|);
                        %end; /* End of do-group for &_destination_type_cd=0 */
                        %else %do;
                          %let _first_row_col_names=0;
                          %let _col_delimiter=%str();
                        %end; /* End of do-group for &_destination_type_cd NE 0 */
                        
                        %ftp_sas_to_txt(tbl_in=work.final,
                                      ds_opts=&_ds_opts,
                                      file_out=&file_name..txt,
                                      layout_out=&file_name..txt.layout,
                                      rhost=&ftp_host,
                                      rdir=&destination_sub_dir,
                                      send_ok_file=&_send_ok_file,
                                      send_layout=&_send_layout,
                                      compress_file=&_compress_file,
                                      first_row_col_names=&_first_row_col_names,
                                      col_delimiter=&_col_delimiter
                                     );
		        	
		        %put NOTE:  ********************************************************; 
		        %put NOTE:  Vendor files for destination ZEUS may be found in: &zeus_root. ;
		        %put NOTE:  ********************************************************;
		        
		        %***** Deassign the temporary libref for _tmpout *****;
		        %let librc=%sysfunc(libname(_tmpout,%str()));
		        
                   %end; /* End of do-group &librc=0 */
                   %else %put ERROR: (&SYSMACRONAME): A libname could not be assigned for &destination_sub_dir..;
            %end; /* End of do-group &_destination_cd=2 */

            %if &ftp_ok NE %then %let transfer_ok=&ftp_ok;
            %else %let transfer_ok=&copy_ok;

            %if &transfer_ok=0 %then %do;
                 %LET err_fl=1;
                 %LET MESSAGE_FOR_RELEASE_DATA=%STR(ERROR:(&SYSMACRONAME): &ds_pnd could not be transferred to &_destination(&destination_sub_dir).;);
            %end;
		    
            %if &err_fl=1 %then %goto EXIT_RD;

              %*SASDOC=========================================================;
              %* If the final output file has been successfully FTPd to its
              %* destination, then update the TPHASE_RVR_FILE.LETTERS_SENT_QY
              %* field (if the file was for a mailing -- FILE_USAGE_CD=1), the
              %* RELEASE_TS and the HSU_TS fields are also updated.
              %*========================================================SASDOC*;

              %*SASDOC=========================================================;
              %* 11/24/03: Per P. Wonders: The RELEASE_TS should only be set by
              %* this program when the FINAL_STATUS_CD=2 (i.e., "final").
              %*========================================================SASDOC*;

			

              %*SASDOC=========================================================;
              %* If the final output file has been successfully FTPd to its
              %* destination, then generate an Initiative Results Overview
	          %* report (for attachment to notification email).
              %*========================================================SASDOC*;

			  %IF &FILE_SEQ_NB.=&MAX_FILE_SEQ_NB. %THEN
			  						%DO;
			/*
                %*SASDOC=======================================================;
                %* If this is a "mailing", then determine the total number of
                %* letters sent.  This value will be used to update the
                %* &HERCULES..TPHASE_RVR_FILE.LETTERS_SENT_QY field.
				%* NOTE: &LETTER_TYPE_QY_CD is assigned by hercules_in.sas.
                %*======================================================SASDOC*;

                %*SASDOC=======================================================;
                %* c.j.s 12/10/07
                %* CHANGED the case statement from when 1 to when (1,2) 
                %* so that data_quality code would be summed for both 1 and 2 
				%*======================================================SASDOC*;
           */

		
			  proc sql noprint;	
                update &hercules..tphase_rvr_file
                set    %if &file_usage_cd=1 %then %do;
                         letters_sent_qy = (select sum(case data_quality_cd when 1 then letters 
                                                                            when 2 then letters else 0 end)
/*                         letters_sent_qy = (select sum(case data_quality_cd when (1,2) then letters else 0 end)*/
                                            from   (select distinct
                                                           recipient_id,
                                                           data_quality_cd,
                                                           %if &letter_type_qy_cd=1 %then %str(count(distinct subject_id));
                                                           %else %str(1); as letters
                                                    from   work.final_main
                                                    %if &letter_type_qy_cd=1
                                                    %then %str(group by recipient_id, data_quality_cd);)),
                       %end;
                       release_ts = (case when &release_status_cd=2 then datetime() else release_ts end),
                       hsu_ts     = datetime()
                where  initiative_id = &init_id        and
                       phase_seq_nb  = &phase_id       and
                       cmctn_role_cd = &com_cd  ;
              quit;

              %let update_err_flg=0;

              %if ^&sqlrc %then %put NOTE: (&SYSMACRONAME): TPHASE_RVR_FILE has been updated.;
              %else %do;
                %let update_err_flg=1;
                %put ERROR: (&SYSMACRONAME): TPHASE_RVR_FILE may not have been updated: &sysmsg..;
              		%end;
			



              %let RPT_NM=&RPT_ROOT.1/hercules/general/&init_id._initiative_results_overview.pdf;
/*               %include "&PRG_ROOT.1/hercules/reports/initiative_results_overview.sas";*/
/*			  modified for testing purpose - Anita*/
%include "herc&sysmode/prg/hercules/reports/initiative_results_overview.sas";
		*SASDOC -----------------------------------------------------------------------------
		| ADDED LOGIC TO UPDATE THE &DWHM..T_MLNG TABLE NEEDED FOR IBENEFIT PROACTIVE ACCESS 
		| HEALTH ALERT DATA.
		| SY - 20OCT2008.
		+ ----------------------------------------------------------------------------SASDOC*;

		%IF &PROGRAM_ID = 5286 AND &TASK_ID = 33 AND &RELEASE_STATUS_CD = 2 %THEN %DO;

			%macro update_edw_mailing_history;

				**-----------------------------------------------------------------------;
				** update pending participants as complete;
				**-----------------------------------------------------------------------;
				PROC SQL; 
				  UPDATE &DWHM..T_MLNG
				  SET RLSE_TS     = %SYSFUNC(DATETIME()),
				      REC_CHG_TS  = %SYSFUNC(DATETIME()),
				      STUS_CD     = 9
				  WHERE INITIATIVE_ID = &INITIATIVE_ID
				    AND STUS_CD  = 1	
				    AND QL_BNFCY_ID IN (SELECT DISTINCT A.RECIPIENT_ID 
							FROM DATA_PND.&TABLE_PREFIX._1 A 
							WHERE A.DATA_QUALITY_CD = 1);
				QUIT; 

				**-----------------------------------------------------------------------;
				** update pending participants as data quality code not equal to accepted;
				** data_quality_cd  - 1=accepted 2=rejected 3=suspended);
				**-----------------------------------------------------------------------;
				PROC SQL; 
				  UPDATE &DWHM..T_MLNG
				  SET RLSE_TS     = %SYSFUNC(DATETIME()),
				      REC_CHG_TS  = %SYSFUNC(DATETIME()),
				      STUS_CD     = 3
				  WHERE INITIATIVE_ID = &INITIATIVE_ID
				    AND STUS_CD  = 1	
				    AND QL_BNFCY_ID IN (SELECT DISTINCT A.RECIPIENT_ID 
							FROM DATA_PND.&TABLE_PREFIX._1 A 
							WHERE A.DATA_QUALITY_CD NE 1);
				QUIT; 
				
				**-----------------------------------------------------------------------;
				** update participants as removed by clinical ops;
				**-----------------------------------------------------------------------;				
				PROC SQL; 
				  UPDATE &DWHM..T_MLNG 
				  SET REC_CHG_TS  = %SYSFUNC(DATETIME()),
				      STUS_CD     = 4 
				  WHERE INITIATIVE_ID = &INITIATIVE_ID
				    AND STUS_CD NOT IN (2, 3, 9);  ** 2=NOT ELIGIBLE, 3=DATA QUALITY CODE NOT 1, 9=COMPLETE ;
				QUIT; 


			%mend update_edw_mailing_history;
			%update_edw_mailing_history;

		%END;

			
              %*SASDOC=========================================================;
              %* If the final output file has been successfully FTPd to its
              %* destination and the Initiative Results Overview report has been
              %* generated, send notification emails to the FTP contact at the
              %* vendor site (AUX_TAB.SET_FTP.NOTIFY_EMAIL), if appropriate.
              %*
              %* NOTE: The file layout and Initiative Results Overview report
              %*       are sent as attachments to the email.
              %*========================================================SASDOC*;
              
                %*SASDOC=======================================================;
                %* Who gets the emails (Part 1)?  If the file has been 
				%* "autoreleased", the user who scheduled the job should be 
                %* notified (TPHASE_RVR_FILE.HSU_USR_ID) -- otherwise, the user 
                %* who released the file gets the notifications (TINITIATIVE_PHASE.
                %* HSU_USER_ID).  The autorelease process will set a macro
                %* variable, &AUTORELEASE, to 1 if called/applicable.  So, the
                %* &AUTORELEASE will determine which user to notify.
                %*======================================================SASDOC*;

                  %if &autorelease=1 %then 
								%do;
                    proc sql noprint;
                      select hsc_usr_id,
			     			 hsu_usr_id
                      into   :hsc_usr_id,
			     			 :hsu_usr_id
                      from   &hercules..tinitiative_phase
                      where  initiative_id = &init_id  and
                             phase_seq_nb  = &phase_id;
                    quit;
                  				%end; /* End of do-group &autorelease=1 */

 		
        %*SASDOC=======================================================;
        %* Who gets the emails (Part 2)?  If there is an email address
		%* specified in the AUX_TAB.SET_FTP.NOTIFY_EMAIL field, then
		%* this address becomes the "to" address and the internal
		%* user IDs/addresses are moved to the "cc" address.
        %*======================================================SASDOC*;
        PROC SQL NOPRINT;
    	   SELECT QUOTE(TRIM(email)) INTO :_em_to_user SEPARATED BY ' '
    		FROM ADM_LKP.ANALYTICS_USERS
    		 WHERE UPCASE(QCP_ID) IN ("&hsu_usr_id");
 		QUIT;

		PROC SQL NOPRINT;
    	   SELECT QUOTE(TRIM(email)) INTO :_em_c_user SEPARATED BY ' '
    		FROM ADM_LKP.ANALYTICS_USERS
    		 WHERE UPCASE(QCP_ID) IN ("&hsc_usr_id");
 		QUIT;



		%if &vendor_email NE %STR() %then 
					%do;
		  %let _em_to="&vendor_email";
		  %let _em_cc=&_em_to_user;
                	%end;
		%else 
					%do;	  
		  %let _em_to=&_em_to_user;

          %*SASDOC=====================================================;
          %* Who gets the emails (Part 3)?  If the file is AUTORELEASED,
		  %* then the TINITIATIVE_PHASE.HSC_USR_ID is "copied" on the
		  %* email if it is not QCPAP020 (production support) and is 
		  %* not the same as the HSU_USR_ID.  NOTE: &HSC_USR_ID is reset
		  %* if "autoreleased" in an earlier step to reset &HSU_USR_ID.
          %*====================================================SASDOC*;

		  %if %upcase(&hsc_usr_id)^=QCPAP020 and %upcase(&hsc_usr_id)^=%upcase(&hsu_usr_id)
		  %then %let _em_cc=&_em_c_user;
		  %else %let _em_cc=%str();
					%end; 

		%if %sysfunc(fileexist(&RPT_NM)) NE 1 %then 
					%DO;
				%LET err_fl=1;
				%LET MESSAGE_FOR_RELEASE_DATA=%STR(ERROR: (&SYSMACRONAME): The Initiative Results Overview could not be generated.);
					%END;
			 %IF &err_fl=1 %THEN %GOTO EXIT_RD;
         %let _task_name=%upcase(%scan(&ds_pnd,2,%str(.)));

		%if &_destination_cd=2 %then %let file_name=%scan(&ds_pnd,2,%str(.));

		%let _fname_root=%scan(%sysfunc(reverse(%bquote(&file_name))),1,%str(/));
		%let _fname_root=%sysfunc(reverse(%bquote(&_fname_root)));
        %if &_destination_cd=2 %then %let _fname=%bquote(&_fname_root..sas7bdat);
		%else %let _fname=%bquote(&_fname_root..txt);

         %if &_compress_file %then 
		%let _fname=&_fname..Z;

		%IF &err_fl=0 %THEN     
					 %DO; 
	    %LET release_data_ok=1;
		%let _em_msg=%bquote(&_task_name has been processed and has completed successfully.  The file &_fname can be found on %upcase(&FTP_HOST) in the &destination_sub_dir directory.  Please see the attachment);
		%if &_send_layout %then %let _em_msg=%bquote(&_em_msg.(s));
		%let _em_msg=%bquote(&_em_msg for);
		%if &_send_layout %then %let _em_msg=%bquote(&_em_msg layout information and);
		%let _em_msg=%bquote(&_em_msg an Initiative Results Overview Report.);

        %if &_send_layout %then %let _em_attach="&file_name..txt.layout" "&RPT_NM";
		%else %let _em_attach="&RPT_NM";

                %email_parms(EM_TO=&_EM_TO,
			      			 EM_CC=&_EM_CC,
			      			 EM_SUBJECT=Task %upcase(&_task_name) has been processed successfully,
			      			 EM_MSG=&_EM_MSG,
                             EM_ATTACH=&_EM_ATTACH);
                %*SASDOC=======================================================;
                %* Set the global RELEASE_DATA_OK macro variable to signal a
                %* successfull "release" and transfer.  This variable is
                %* available as a return code to the calling program/wrapper.
                %*======================================================SASDOC*;
			%END; /* End of do-group for release_data_ok=1 */
		%END; /* End of do-group for &FILE_SEQ_NB.=&MAX_FILE_SEQ_NB. */

%EXIT_RD:;              
 %END; /* END OF FILE_SEQ_NB LOOP */

%IF &err_fl=1 %THEN
					%DO;
			%PUT err_fl=1;
			%LET release_data_ok=0;
			%PUT MESSAGE_FOR_RELEASE_DATA=&MESSAGE_FOR_RELEASE_DATA;
					%END;
%put _all_;
%mend release_data2;
%PUT run_ok=1;
