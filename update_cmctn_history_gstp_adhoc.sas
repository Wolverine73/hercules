*SASDOC-----------------------------------------------------------------
* 08/06/2007 - g.o.d.
* Corrected typo in nomlogic option.
+-----------------------------------------------------------------SASDOC*;
options mlogic mlogicnest mprint mprintnest nosource2 symbolgen;

%set_sysmode(mode=prod);

%include "/PRG/sas&sysmode.1/hercules/hercules_in.sas";

LIBNAME &USER DB2 DSN=&UDBSPRP SCHEMA=&USER DEFER=YES;



%macro update_cmctn_history();

    *SASDOC--------------------------------------------------------------------------
    * Scope the macro variables.
    +-----------------------------------------------------------------------SASDOC*;
    
    %global program_id task_id err_fl
            release_ts retail_to_mail_flg
            mailing_completed_flg
            file_completed_flg
            initiative_completed_flg
            letter_type_qy_cd
            mac_name;
  
    %let err_fl=0;
    %let missing_dataset=0;
    %let mac_name=update_cmctn_history;
    
    *SASDOC--------------------------------------------------------------------------
    * Identify initiatives for which there are no other pending files (i.e. all
    * files have reached final release (release status = 2 and release_ts is not
    * null). 
    *
    * Three flags introduced in this query: FILE_COMPLETED_FLG (file has
    * reached final release or canceled), MAILING_COMPLETED_FLG (the file has been
    * released and is a mailing), and INITIATIVE_COMPLETED_FLG (all files
    * have reached final release/canceled for the initiative).
	*
    * 19MAR2010 - N.WILLIAMS  - Hercules Version  2.5.03
    * Removed logic that checks for cancelled mailings.    
    +-----------------------------------------------------------------------SASDOC*;
  
    PROC SQL noprint;
      CONNECT TO DB2 (DSN=&UDBSPRP);
      CREATE table work.completed_initiatives as
      SELECT * FROM CONNECTION TO DB2
      ( with init_cm_rl as
            (SELECT  file.initiative_id,  init.program_id, init.task_id, file.cmctn_role_cd,
                     file.phase_seq_nb, file.release_status_cd,
                     file.archive_sts_cd, task.letter_type_qy_cd, file.file_usage_cd,
                     file.release_ts,  
                     MIN(case when ((release_status_cd=2 AND release_ts is not null )) then 1 
                         else 0
                         end) as file_completed_flg,
                     MIN(case when (release_status_cd=2 AND LETTERS_SENT_QY>0 and
                                    file_usage_cd=1 ) then 1
                         else 0
                         end) as mailing_completed_flg,
  
	   /*SASDOC====================================================================
	    * Identify RETAIL_TO_MAIL programs.  The RETAIL_TO_MAIL_FLG will help
	    * determine when to update the communications tables and also the
	    * the &hercules..tcmctn_transaction table.
	    *==================================================================SASDOC*/
      
                     case when (init.program_id=73) then 1
                          else 0
                     end as RETAIL_TO_MAIL_FLG,
                     init.HSC_TS as PDDW_TS  
                 FROM     &hercules..tphase_rvr_file    file ,
                          &hercules..tinitiative        init ,
                          &hercules..tprogram_task      task  
      where   file.initiative_id = init.initiative_id 
        and   init.program_id    = task.program_id
        and   init.task_id    = task.task_id
        and   archive_sts_cd=0
      group by file.initiative_id, init.program_id, init.task_id, file.phase_seq_nb,
               file.cmctn_role_cd, file.release_status_cd, file.archive_sts_cd,
               task.letter_type_qy_cd, file.file_usage_cd, file.release_ts, init.HSC_TS
  
      having  MIN(case when ((release_status_cd=2 AND release_ts is not null)) then 1                             
                       else 0  end)>0)
  
         , init_cmlt as
               (SELECT file.initiative_id,
                   min(case when ((release_status_cd=2 and release_ts is not null)) then 1
                       else 0 end) as initiative_completed_flg
  
         FROM     &hercules..tphase_rvr_file  file
      where   archive_sts_cd=0
      group by file.initiative_id  )
  
           select a.*, 
                  b.initiative_completed_flg
           from init_cm_rl a, init_cmlt b
           where a.initiative_id=b.initiative_id
            and initiative_completed_flg>0
           order by initiative_id, task_id, phase_seq_nb, cmctn_role_cd
        );
     DISCONNECT FROM DB2;
    QUIT;
    
	PROC SQL;
	CREATE TABLE WORK.COMPLETED_INITIATIVES AS
	SELECT *, DATEPART(PDDW_TS) AS PDDW_TS_SAS
	FROM WORK.COMPLETED_INITIATIVES;
	QUIT;

	PROC SORT DATA = WORK.COMPLETED_INITIATIVES;
	BY INITIATIVE_ID;
	QUIT;

    PROC SQL noprint;
      SELECT count(*) into :completed_initiatives_count
      FROM work.completed_initiatives;
    QUIT;

	PROC SQL NOPRINT;
	  SELECT MIN(INITIATIVE_ID), 
	         MAX(INITIATIVE_ID), 
	         COUNT(*) 
		INTO :MIN_INITIATIVE_ID_IBNF,
		     :MAX_INITIATIVE_ID_IBNF, 
		     :COMPLETED_INIT_CNT_IBNF
	  FROM work.completed_initiatives
	  WHERE PROGRAM_ID = 5259 
	    AND TASK_ID    in (31,59) /* Included Task id 59, SKV*/
		AND mailing_completed_flg > 0
		AND file_completed_flg > 0
	    AND PDDW_TS_SAS    > 18052; **release 2=18052=JUNE 04 2009;
	QUIT;				

	%put NOTE: MAX_INITIATIVE_ID_IBNF       = &MAX_INITIATIVE_ID_IBNF ;	
	%put NOTE: MIN_INITIATIVE_ID_IBNF       = &MIN_INITIATIVE_ID_IBNF ;	
	%put NOTE: COMPLETED_INIT_CNT_IBNF      = &COMPLETED_INIT_CNT_IBNF. ; 

	/** 01DEC2010 - S.Biletsky - GSTP December release - start**/	
	PROC SQL NOPRINT;
	  SELECT MIN(INITIATIVE_ID), 
	         MAX(INITIATIVE_ID), 
	         COUNT(*) 
		INTO :MIN_INITIATIVE_ID_GSTP,
		     :MAX_INITIATIVE_ID_GSTP, 
		     :COMPLETED_INIT_CNT_GSTP
	  FROM work.completed_initiatives
	  WHERE PROGRAM_ID = 5295 
	    AND TASK_ID    = 57
		AND mailing_completed_flg > 0
		AND file_completed_flg > 0
	    AND PDDW_TS_SAS    > 18567; 
/*		18567 = NOV 01 2010*/
/*		18597 = DEC 01 2010*/
	QUIT;				

	%put NOTE: MAX_INITIATIVE_ID_GSTP       = &MAX_INITIATIVE_ID_GSTP ;	
	%put NOTE: MIN_INITIATIVE_ID_GSTP       = &MIN_INITIATIVE_ID_GSTP;	
	%put NOTE: COMPLETED_INIT_CNT_GSTP      = &COMPLETED_INIT_CNT_GSTP. ; 
	
	/** 01DEC2010 - S.Biletsky - GSTP December release - finish**/

	%put NOTE: COMPLETED_INITIATIVES_COUNT  = &COMPLETED_INITIATIVES_COUNT. ; 
	    
 
    %if &completed_initiatives_count=0 %then %goto exit;
  
    /*** loop1 start - updating all initiatives ***/
    %else %if &completed_initiatives_count>0 %then %do;

    *SASDOC--------------------------------------------------------------------------
    * 19MAR2010 - N.WILLIAMS  - Hercules Version  2.5.03
    * Added this report so we know what initatives are going to be processed by this run.
    +-----------------------------------------------------------------------SASDOC*;
			%macro sent_cmctn_prcrpt;

			  *SASDOC-----------------------------------------------------------------------
			  | Produce report of completed initiatives to be processed. 
			  +----------------------------------------------------------------------SASDOC*;
			 %if &completed_initiatives_count>0 %then %do;

			   proc sql noprint;
			     select quote(trim(left(email)))
			     into   :PROGRAMMER_EMAIL separated by ' '
			     from   ADM_LKP.ANALYTICS_USERS
			     where  upcase(QCP_ID) in ("QCPI208");
			   quit;

			  *SASDOC-----------------------------------------------------------------------
			  | Modify ODS template.
			  +----------------------------------------------------------------------SASDOC*;
			  ods path sasuser.templat(read) sashelp.tmplmst(read) work.templat(update);
			  proc template;
			  define style MAIN_DIR / store=WORK.TEMPLAT;
			     parent=styles.minimal;
			       style TABLE /
			         rules = NONE
			         frame = VOID
			         cellpadding = 0
			         cellspacing = 0
			         borderwidth = 1pt;
			     end;
			  run;


			     filename RPTDEL temp;
			     ods listing close;
			     ods html
			        file =RPTDEL
			        style=MAIN_DIR;
			     title1 j=l "Hercules Released Initiatives Processed for &sysdate9.";

			     proc print
			        data=work.completed_initiatives
			        noobs;
			     run;
			     quit;
			     ods html close;
			     ods listing;
			     run;
			     quit;

			     %let RPTDEL=%sysfunc(PATHNAME(RPTDEL));
			     %let RPT   =%sysfunc(PATHNAME(RPT));

			 filename mymail email 'qcpap020@dalcdcp';

			  data _null_;
			    file mymail

			        to =("sergey.biletsky@caremark.com")
			        subject="HCE SUPPORT: List of Hercules Released Initiatives Processed on &sysdate9 "
			        attach=( "&RPTDEL" ct='application/xls' ext='xls' );;

			    put 'Hello:' ;
			    put / "Attached is a list of initiatives(s) that were released by the business user that will be processed by update_cmtcn_history.sas to update midrange transaction table";	
			    put / 'Please check the initiative(s) and make needed corrections';
			 run;
			 quit;
			%end;
			%mend sent_cmctn_prcrpt;

			%sent_cmctn_prcrpt;



        *SASDOC--------------------------------------------------------------------------
        * Process the completed intitiative/task records:
        +-----------------------------------------------------------------------SASDOC*;
        
        data _null_;
          set work.completed_initiatives end=endf;
          by initiative_id phase_seq_nb cmctn_role_cd;
            call symput('initiative_id'||compress(put(_n_,2.)), compress(put(initiative_id, 8.)));
            call symput('phase_seq_nb'||compress(put(_n_,2.)), put(phase_seq_nb, 1.));
            call symput('cmctn_role_cd'||compress(put(_n_,2.)), put(cmctn_role_cd, 1.) );
        run;

        /*** loop2 start - looping through the initiatives ***/
        %do i=1 %to &completed_initiatives_count;
            %let initiative_id=&&initiative_id&i;
            %let cmctn_role_cd=&&cmctn_role_cd&i;
            %let phase_seq_nb=&&phase_seq_nb&i;
            %let init_phase_role=%str(&initiative_id as initiative_id,
                                 &phase_seq_nb as phase_seq_nb,
                                 &cmctn_role_cd as cmctn_role_cd,);
    
	    %put initiative_id=&initiative_id, cmctn_role_cd=&cmctn_role_cd;
	    
	    *SASDOC--------------------------------------------------------------------------
	    | Establishing a std environment for each completed initiative.
	    +-----------------------------------------------------------------------SASDOC*;
	    
	    *SASDOC--------------------------------------------------------------------------	    
            | 24JUN2008 - Brian Stropich
            | Changed the program ID format from a length of 3 to
            | a length of 4. 	    
	    +-----------------------------------------------------------------------SASDOC*;
	    
  	    %include "/PRG/sas&sysmode.1/hercules/hercules_in.sas";
	    
  	    libname SYSCAT DB2 dsn=&UDBSPRP SCHEMA=SYSCAT DEFER=YES;
	    
	    data _null;
	      set work.completed_initiatives
	    	(where=(initiative_id=&initiative_id
	    	  and cmctn_role_cd=&cmctn_role_cd)) end=endf;
	        call symput('program_id', compress(put(program_id, 4.)));
	        call symput('task_id', compress(put(task_id, 3.)));
	        call symput('_dsname', 'data_pnd.'||"&table_prefix."||'_'||"&cmctn_role_cd.");
	        call symput('release_ts', put(release_ts, 20.));
			call symput('release_status_cd', put(release_status_cd, 1.));
	        call symput('retail_to_mail_flg', put(retail_to_mail_flg,1.));
	        call symput('mailing_completed_flg', put(mailing_completed_flg, 1.) );
	        call symput('file_completed_flg', put(file_completed_flg, 1.) );
	        call symput('initiative_completed_flg', put(initiative_completed_flg, 1.) );
	        call symput('letter_type_qy_cd', put(letter_type_qy_cd,1.));
	        call symput('file_usage_cd', put(file_usage_cd,1.));
	    run;
	    
            %put program_id=&program_id dat_name=&_dsname;
            %put NOTE: DATASET TO BE PROCESSED IS &_dsname;
	    
	    
	    PROC SQL NOPRINT;
	       SELECT QUOTE(TRIM(EMAIL)) INTO :email_it SEPARATED BY ' '
	        FROM   ADM_LKP.ANALYTICS_USERS
	        WHERE  UPCASE(QCP_ID) = "QCPI208";
	    QUIT;
	    
	    *SASDOC--------------------------------------------------------------------------
	    | Check if dataset exists and send an email if it does not exist.  
	    +-----------------------------------------------------------------------SASDOC*;	    

	    %if %sysfunc(exist(&_dsname))=0 %then %do;
	    
                %put WARNING (&sysmacroname): The &_dsname does not exist and &sysmacroname aborted.;
                %let err_fl=1;
                %let missing_dataset=1;

        %on_error(ACTION=ABORT, EM_TO=&email_it,
			  EM_SUBJECT="HCE SUPPORT:  Notification of Missing Dataset",
			  EM_MSG="A problem was encountered with non-existing pending dataset. See LOG file - &mac_NAME..log for Initiative ID &Initiative_ID");
		
		
		*SASDOC--------------------------------------------------------------------------
		* Capture missing dataset information in the ReportFile dataset.                     
		+-----------------------------------------------------------------------SASDOC*;		
		
		%capture_cmctn_information;
			  

	        
            %end;

	    %let d_exist=%sysfunc(exist(&_dsname)); %put &d_exist;

            /*** loop3 start - assessing table existance and history update for one initiative/cmctn_role  ***/
            %if %sysfunc(exist(&_dsname))>0 %then %do;
            
		*SASDOC--------------------------------------------------------------------------
		* Check if apn_cmctn_id and send an email if it is not populated.
		+-----------------------------------------------------------------------SASDOC*;
		
		PROC SQL NOPRINT;
		   SELECT COUNT(*) into: apn_miss_cnt
		   FROM   &_dsname
		   WHERE COMPRESS(APN_CMCTN_ID) IS NULL;
		QUIT;
		
		    
		/*** loop4 start - missing apn_miss_cnt ***/    
		%if &apn_miss_cnt > 0 and &file_usage_cd=1 and &release_ts > 0  %then %do;
		
		    %put WARNING: (&sysmacroname) Archive process failed becase of missing apn_cmctn_id for Initiative ID &Initiative_ID.;
		    
		    %let err_fl=1;
		    
		    %email_parms(EM_TO=&email_it,
		                 EM_CC=,
		                 EM_SUBJECT="HCE SUPPORT:  Notification of missing apn_cmctn_id.",
		                 EM_MSG="A problem was encountered with missing apn_cmctn_id. See LOG file - &mac_NAME..log for Initiative ID &Initiative_ID",
		                 EM_ATTACH=);		
		
		    *SASDOC--------------------------------------------------------------------------
		    * Capture missing apn_cmctn_id information in the ReportFile dataset.                     
		    +-----------------------------------------------------------------------SASDOC*;
		    
		    %capture_cmctn_information;
		    
		    

	        %end;
		%else %do;

		    *SASDOC--------------------------------------------------------------------------
		    *  NOTE: to avoid inserting nulls to the history tables. Missing values
		    *        in any fields of mailing file will be converted to 999999 in
		    *        numeric fields and '--' in character field.
	        *  NOTE: 06/07/2007 G. Dudley
	        *  Due to the New Standard File Layout Subject ID will now be in every pending
	        *  SAS dataset.  Some mailings like Retail to Mail and iBenefit do not 
	        *  utilize the Subject ID and will always have a missing value.
	        *  If the Subject Id is missing then it is set equal to the Receiver ID
	        *  If the Subject Communication Role Code is missing it is set equal to 
	        *  the Receiver Communication Role Code.  This is a business rule per 
	        *  Nancy Jermolowicz.
		    +-----------------------------------------------------------------------SASDOC*;
		    
		    proc contents data = &_dsname out = subject_check noprint;
		    run;
		    
		    PROC SQL NOPRINT;
			 SELECT COUNT(*) INTO: subjectid_exists
			 FROM  subject_check
			 WHERE UPCASE(NAME) CONTAINS 'SUBJECT_ID';

			 SELECT COUNT(*) INTO: subjectcmmrolecd_exists
			 FROM  subject_check
			 WHERE UPCASE(NAME) CONTAINS 'SUBJECT_CMM_ROLE_CD';
		    QUIT;
		    
		    %put NOTE: subjectid_exists = &subjectid_exists. ;
		    %put NOTE: subjectcmmrolecd_exists = &subjectcmmrolecd_exists. ;

		    data &_dsname.2;
		      set &_dsname(where=(data_quality_cd=1));
		      array ary_one{*} _numeric_;
		      array ary_two{*} _character_;
		      do i=1 to dim(ary_one);
		        if ary_one{i} <0 then  ary_one{i}=999999;
		      end;
		      do J=1 to dim(ary_two);
		        if ary_two{j} ='' then  ary_two{j}='--';
		      end;
		      %if &subjectid_exists. > 0 %then %do;
          		if subject_id=999999 then subject_id=recipient_id; /*** 06/07/2007 g.o.d. *****/
          	      %end;
          	      %if &subjectcmmrolecd_exists. > 0 %then %do;
          		if subject_cmm_role_cd=999999 then subject_cmm_role_cd=&cmctn_role_cd; /*** 06/07/2007 g.o.d. *****/
          	      %end;
		    run;

/*                    %assign_cmctn_id(tbl_name=&_dsname.2);*/

		    /*** loop5 start - loading the mailing history ***/
		    %if &mailing_completed_flg>0 and &initiative_completed_flg>0 %then %do;

			*SASDOC--------------------------------------------------------------------------
			* Update the communication history tables for all completed
			* mailings.  The records of a completed RETAIL-TO-MAIL initiative will
			* will be inserted to TCMCTN_TRANSACTION table.
			+-----------------------------------------------------------------------SASDOC*;

/*			%LOAD_INIT_HIS(tbl_name=&_dsname.2);*/
			
		        *SASDOC--------------------------------------------------------------------------
		        * Capture successful and unsuccessful initiatives information in the ReportFile dataset.                     
		        +-----------------------------------------------------------------------SASDOC*;			

			*SASDOC--------------------------------------------------------------------------
			| 10OCT2008 SY
			|
			| Added logic for program data in data warehouse.
			|		-  
			+-----------------------------------------------------------------------SASDOC*;			

			/*-----------------------------------------------------------------
			check for the ibenefit initiatives. if so, call the macro 
			createprogramdatafiles. until the program data process runs for 
			edw too, we just run this for ql adjudication engine. 
			-----------------------------------------------------------------*/

/*			%if &PROGRAM_ID = 5259 and (&TASK_ID = 31 OR &TASK_ID = 59) and &RELEASE_STATUS_CD = 2 %then %do; /* Included Task id 59, SKV*/  **loop begin - 5259 31 2;*/
/**/
/*			     %put NOTE: INITIATIVE_ID = &INITIATIVE_ID;*/
/*			     %put NOTE: PHASE_SEQ_NB = &PHASE_SEQ_NB;*/
/*			     %put NOTE: PROGRAM_ID = &PROGRAM_ID;*/
/*			     %put NOTE: TASK_ID = &TASK_ID;*/
/*			     %put NOTE: CMCTN_ROLE_CD = &CMCTN_ROLE_CD;*/
/*			     */
/*			     data _null_;*/
/*			       set completed_initiatives (where=(initiative_id=&INITIATIVE_ID));*/
/*			       put 'NOTE: JUNE 04 2009 (18052) = ' PDDW_TS_SAS;		*/
/*			         if pddw_ts_sas    > 18052 then do; **18052=JUNE 04 2009;*/
/*			           call symput('RLSE_AFTER_18DEC', 1);*/
/*			         end;*/
/*			         else do;*/
/*			           call symput('RLSE_AFTER_18DEC', 0);*/
/*			         end;*/
/*			     run;*/
/*			     */
/*			     %put NOTE: RLSE_AFTER_18DEC = &RLSE_AFTER_18DEC;*/
			     
			     /*----------------------------------------------------------------- 
			     This code is required as we will not have all the information for 
			     the initiatives that are run in the past (history initiatives). 
                 09Sept2010 D. Palmer - Added program id 5371 for Pharmacy Advisor
				 -----------------------------------------------------------------*/
			     
/*			     %if &RLSE_AFTER_18DEC = 1 %then %do;  **loop begin - house keeping timestamp ;*/
/*			     */
/*			     	%global FILEDATE FILETIME;*/
/*			     	%put NOTE: &INITIATIVE_ID. was after before 18052=JUNE 04 2009;*/
/*			     	%create_program_data_files;*/
/*			     */
/*			     %end;  **loop end - house keeping timestamp ;*/

			%end;    **loop end - 5259 31 2 QL;

/** 01DEC2010 - S.Biletsky - GSTP December release - start**/ 
			%if &PROGRAM_ID = 5295 and &TASK_ID = 57 and &RELEASE_STATUS_CD = 2 %then %do;  
			/**loop begin - 5295 57 2 **/

			     %put NOTE: INITIATIVE_ID = &INITIATIVE_ID;
			     %put NOTE: PHASE_SEQ_NB = &PHASE_SEQ_NB;
			     %put NOTE: PROGRAM_ID = &PROGRAM_ID;
			     %put NOTE: TASK_ID = &TASK_ID;
			     %put NOTE: CMCTN_ROLE_CD = &CMCTN_ROLE_CD;
			     
			     data _null_;
			       set completed_initiatives (where=(initiative_id=&INITIATIVE_ID));
			       put 'NOTE: NOV 01 2010 (18567) = ' PDDW_TS_SAS;		
			         if pddw_ts_sas    > 18567 then do; /**18567=NOV 01 2010**/
			           call symput('RLSE_AFTER_01NOV', 1);
			         end;
			         else do;
			           call symput('RLSE_AFTER_01NOV', 0);
			         end;
			     run;
			     
			     %put NOTE: RLSE_AFTER_01NOV = &RLSE_AFTER_01NOV.;
			     
			     /*----------------------------------------------------------------- 
			     This code is required as we will not have all the information for 
			     the initiatives that are run in the past (history initiatives). 
			     -----------------------------------------------------------------*/
			     
			     %if &RLSE_AFTER_01NOV = 1 %then %do;  /**loop begin - house keeping timestamp **/
			     
			     	%global FILEDATEGSTP FILETIMEGSTP; 
			     	%create_program_data_files_gstp;
			     
			     %end;  /**loop end - house keeping timestamp **/
			          
			%end; /**loop end - 5295 57 2 **/
			
/** 01DEC2010 - S.Biletsky - GSTP December release - finish**/
			
/*			%IF &RELEASE_STATUS_CD=2 AND (&PROGRAM_ID=5252 or &PROGRAM_ID=5253 or &PROGRAM_ID=5254 or &PROGRAM_ID=5255 or &PROGRAM_ID=5256 or */
/*                &PROGRAM_ID=5270 or &PROGRAM_ID=5296 or &PROGRAM_ID=5297 or &PROGRAM_ID=5349 or &PROGRAM_ID=5350 or &PROGRAM_ID=5351 or */
/*                &PROGRAM_ID=5352 or &PROGRAM_ID=5353 or &PROGRAM_ID=5354 or &PROGRAM_ID=5355 or &PROGRAM_ID=5356 or */
/*                &PROGRAM_ID=5357 or &PROGRAM_ID=5371)*/
/*            %then %do;*/
/*			*/
/*					%cee_disposition_file;*/
/*			*/
/*			%END; */

/*			%capture_cmctn_information;*/

          
                    %end; 
                    /*** loop5 end - loading the mailing history ***/
                    
                    %if &mailing_completed_flg=0 %then %put (&sysmacroname): &_dsname is not a mailing file, history tables are not being updated.;

	            *SASDOC--------------------------------------------------------------------------
	            * Drop all of the temp DB2 tables for this initiative, delete records
	            * of completed initiative FROM TCMCTN_PENDING table.
	            +-----------------------------------------------------------------------SASDOC*;
	            
/*                    %drop_initiative_temp_tables;*/
                    
              
                    *SASDOC--------------------------------------------------------------------------
                    * When inserting to the history tables completed successfully, the files
                    * for a completed initiative in the /pending and /results directory will be
                    * moved to the /archive directory and be compressed.
                    +-----------------------------------------------------------------------SASDOC*;
                    
/*                    %archive_results;*/
                    
                    
       
	        %end;
	        /*** loop4 end - missing apn_miss_cnt ***/       

            %end; 
            /*** loop3 end - assessing table existance and history update for one initiative/cmctn_role ***/

        %end; 
        /*** loop2 end - looping through the initiatives ***/
  
    %end;
    /*** loop1 end - updating all initiatives ***/

    %exit:;

/*    %CREATE_PROGRAM_DATA_NOIBENFILES;*/

%mend update_cmctn_history;

%update_cmctn_history;
