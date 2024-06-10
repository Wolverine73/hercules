%include '/user1/qcpap020/autoexec_new.sas';
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  update_cmctn_history.sas
|
| LOCATION: /PRG/sas&sysmode.1/hercules/gen_utilities/sas
|
| PURPOSE:  This program checks TPHASE_RVR_FILE for files that have reached
|           final release status. It performs several variable steps depending 
|           on how the file was used.
|
|           Note that if there are multiple files in an initiative, both
|           files must have reached the following conditions for this
|           process to apply:
|
|             (1) RELEASE_STATUS_CD = 2 (final) and ARCHIVE_STATUS_CD=0
|                 (not archived) and release_ts is not null.
|
|
|           Then:
|
|             (A) Delete records FROM TCMCTN_PENDING for that file
|                 (INITIATIVE_ID, PHASE_SEQ_NB and CMCTN_ROLE_CD).  Note there
|                 will not be records in this table for autorelease files.
|
|             (B) If the file release was final (1st condition above) and
|                 FILE_USAGE_CD = 1 (mailing):
|
|                        1.  Update Communication History tables for
|                            all programs except Retail-to-Mail.
|
|                        2.  Send the transactions FROM the SAS dataset
|                            in the pending directory to TCMCTN_TRANSACTION.
|                            Note that mailings to prescribers without subjects
|                            are not sent to TCMCTN_TRANSACTION.
|
|                 (It is important to remember that an initiative may have
|                 multiple files that can be released at separate times.)
|
|             (C) Compress and move the SAS dataset FROM the pending to the
|                 archive directory. Set the ARCHIVE_STS_CD to 1 for completed
|                 mailing 2 for complete but not mailed.
|
|             (D) Query the system catalog for the TMP UDB tables (based on
|                 initiative id).  Drop the tablCMCTN_GENERATED_TSCMCTN_GENERATED_TSes.
|
| INPUT:    &HERCULES..TPHASE_RVR_FILE  - to get completed initiatives/tasks
|           &HERCULES..TINITIAVE        - to get PROGRAM_ID and to determine
|                                         "retail to mail" programs
|
| OUTPUT:   &HERCULES..TCMCTN_PENDING     - rows deleted for completed inits
|           &HERCULES..TCMCTN_RECEIVR_HIS - updates table for completed mailings
|           &HERCULES..TCMCTN_SUBJECT_HIS - updates table for completed mailings
|           &HERCULES..TCMCTN_ADDRESS     - updates table for completed mailings
|           &HERCULES..TCMCTN_SBJ_NDC_HIS - updates table for completed mailings
|           &HERCULES..TCMCTN_TRANSACTION - updates table for completed mailings
|
|           Datasets FROM DATA_PND/DATA_RES are compressed & moved to "archive".
|
|           Temp tables are identified and dropped for completed initiatives.
|
| MACROS:   %assign_cmctn_id
|           %LOAD_INIT_HIS
|           %drop_initiative_temp_tables
|           %archive_results
|
+-------------------------------------------------------------------------------
| HISTORY:    01FEB2004 - J. HOU      - after TOM KALFAS
|
|             16JAN2006 - G. DUDLEY   - 
|                         Added code to expclude initiative 1098.
|                         This initiative caused an error which
|                         prevented the update of the Communication
|                         History.
|
|             01AUG2006 - B. STROPICH - 
|                         Added code to alert the team of missing 
|                         application values and to continue with
|                         the loop of other initiatives and not to 
|                         exit the loop.  Added code to create a daily
|                         report with the day of the month appended
|                         at the end of the report.
|
|	      07MAR2007 - G. Dudley   - Hercules Version  1.0 
|                         HERCULES II MF / RELEASE 1
|	             	  Since the GID column TRANSACTION_ID has 
|	             	  been added to the HERCULES.TCMCTN_TRANSACTION 
|	             	  table, the selection from and insertion to 
|	             	  this table will need to specify the column 
|	             	  names in the SELECT statement of the PROC SQL.
|
|             07JUN2007 - G. Dudley   - Hercules Version  1.5.1
|                         The tcmctn_transaction table has column that are
|                         not nullable and must have valid value.  With the
|                         implementation of the new standard file layout, the
|                         pending SAS data sets for all mailings will have
|                         all available columns for evey mailing, but only 
|                         populate the columns for that particular mailing.  The
|                         update_cmctn_history.sas program checks all columns for
|                         null values and change the numeric columns to 999999 and
|                         character columns to two dashes (--).  This logic was not
|                         compatible the new standard file layout.
|
|             06AUG2007 - G. Dudley   - Hercules Version  1.5.2
|                         There was a typo in the OPTIONS statement that was 
|                         preventing the data from being loaded into
|                         the TCMCTN_TRANSACTION table.
|
|             07MAR2008 - N.WILLIAMS  - Hercules Version  2.0.01
|                         1. Initial code migration into Dimensions
|                            source safe control tool. 
|                         2. Added references new program path.
|                         3. Update to adjust bulkload to SQL pass-thru for table loads.
|
|             20NOV2008 - Sudha Yaramada - Hercules Version  2.5.01
|                         ADDED LOGIC TO INCLUDE NEW TEMPLATE HISTORY TABLE 
|                         FOR IBENEFIT PROACTIVE ACCESS HEALTH ALERT FOR RHI 
|                         MESSAGING. 
|
|             18DEC2008 - Sudha Yaramada - Hercules Version  2.5.02
|                         Added logic for program data in DW.
|
|             19MAR2010 - N.WILLIAMS  - Hercules Version  2.5.03
|                         Removed logic that checks for cancelled mailings as
|                         this was causing uneccessary work/errors not need by
|                         business/hercules application team. 
|             19MAR2010 - N.WILLIAMS  - Hercules Version  2.5.03
|                         Removed logic that checks for cancelled mailings as
|                         this was causing uneccessary work/errors not need by
|                         business/hercules application team. 
|             27MAY2010 - N. Williams - Hercules Version  2.5.04
|                         added EOMS (aka cee,coe) program ID 5356, 5357 for
|                         selective execution of the cee_disposition_file.
|             01SEP2010 - D. Palmer Added a missing comma to the string sbj_ndc_rcpnt_str
|                         to prevent a syntax error during creation of table
|                         TCMCTN_SBJ_NDC_HIS. Added the qualifier - subject_id to string 
|                         transact_rvr_str when subject_id does not exist, to prevent
|                         error during update to table &user..TCMTCN_TRANSACTION.
|             09SEP2010 - D. Palmer - added PA program id 5371 to EOMS program list.
|
|			  02MAR2011 - Sathishkumar Veeraswamy (SKV), Added Task id 59 for iBenefit 3.0.
|
|             01DEC2010 - S.Biletsky - GSTP December release
|			  added logic to create program data files for GSTP
+-----------------------------------------------------------------------HEADER*/

*SASDOC-----------------------------------------------------------------
* 08/06/2007 - g.o.d.
* Corrected typo in nomlogic option.
+-----------------------------------------------------------------SASDOC*;
options mlogic mlogicnest mprint mprintnest source2 symbolgen;

%set_sysmode;

%include "/herc%lowcase(&SYSMODE)/prg/hercules/hercules_in.sas";

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
	    AND TASK_ID    in (31) /* Removed Task id 59, AK - need to add when outcomes reporting project migrates to production*/
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
			     where  upcase(QCP_ID) in ("&USER");
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

			        to =(&PROGRAMMER_EMAIL)
					cc =("Marianna.Sumoza@caremark.com")
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
	    
  	    %include "/herc%lowcase(&SYSMODE)/prg/hercules/hercules_in.sas";
	    
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
	        WHERE  UPCASE(QCP_ID) = "&USER";
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

                    %assign_cmctn_id(tbl_name=&_dsname.2);

		    /*** loop5 start - loading the mailing history ***/
		    %if &mailing_completed_flg>0 and &initiative_completed_flg>0 %then %do;

			*SASDOC--------------------------------------------------------------------------
			* Update the communication history tables for all completed
			* mailings.  The records of a completed RETAIL-TO-MAIL initiative will
			* will be inserted to TCMCTN_TRANSACTION table.
			+-----------------------------------------------------------------------SASDOC*;

			%LOAD_INIT_HIS(tbl_name=&_dsname.2);
			
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

			%if &PROGRAM_ID = 5259 and (&TASK_ID = 31)	/*OR &TASK_ID = 59) */  /* AK 20JUN2012 - COMMENTED FOR PSG (59) SINCE 
																				   THERE ARE ISSUES WITH GENERATING THE DISPOSITIONS. 
																				   INCLUDE WHEN PSG DISPOSITIONS NEED TO BE SENT */

and &RELEASE_STATUS_CD = 2 %then %do; /* Included Task id 59, SKV*/  **loop begin - 5259 31 2;

			
			     %put NOTE: INITIATIVE_ID = &INITIATIVE_ID;
			     %put NOTE: PHASE_SEQ_NB = &PHASE_SEQ_NB;
			     %put NOTE: PROGRAM_ID = &PROGRAM_ID;
			     %put NOTE: TASK_ID = &TASK_ID;
			     %put NOTE: CMCTN_ROLE_CD = &CMCTN_ROLE_CD;
			     
			     data _null_;
			       set completed_initiatives (where=(initiative_id=&INITIATIVE_ID));
			       put 'NOTE: JUNE 04 2009 (18052) = ' PDDW_TS_SAS;		
			         if pddw_ts_sas    > 18052 then do; **18052=JUNE 04 2009;
			           call symput('RLSE_AFTER_18DEC', 1);
			         end;
			         else do;
			           call symput('RLSE_AFTER_18DEC', 0);
			         end;
			     run;
			     
			     %put NOTE: RLSE_AFTER_18DEC = &RLSE_AFTER_18DEC;
			     
			     /*----------------------------------------------------------------- 
			     This code is required as we will not have all the information for 
			     the initiatives that are run in the past (history initiatives). 
                 09Sept2010 D. Palmer - Added program id 5371 for Pharmacy Advisor
				 -----------------------------------------------------------------*/
			     
			     %if &RLSE_AFTER_18DEC = 1 %then %do;  **loop begin - house keeping timestamp ;
			     
			     	%global FILEDATE FILETIME;
			     	%put NOTE: &INITIATIVE_ID. was after before 18052=JUNE 04 2009;



								     	%create_program_data_files;
			     
			     %end;  **loop end - house keeping timestamp ;

			%end;    **loop end - 5259 31 2 QL;

/** 01DEC2010 - S.Biletsky - GSTP December release - start**/ 
			%if &PROGRAM_ID = 5295 and &TASK_ID = 57 and &RELEASE_STATUS_CD = 2 %then %do;  /**loop begin - 5295 57 2 **/

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
			
			%IF &RELEASE_STATUS_CD=2 AND (&PROGRAM_ID=5252 or &PROGRAM_ID=5253 or &PROGRAM_ID=5254 or &PROGRAM_ID=5255 or &PROGRAM_ID=5256 or 
                &PROGRAM_ID=5270 or &PROGRAM_ID=5296 or &PROGRAM_ID=5297 or &PROGRAM_ID=5349 or &PROGRAM_ID=5350 or &PROGRAM_ID=5351 or 
                &PROGRAM_ID=5352 or &PROGRAM_ID=5353 or &PROGRAM_ID=5354 or &PROGRAM_ID=5355 or &PROGRAM_ID=5356 or 
                &PROGRAM_ID=5357 or &PROGRAM_ID=5368 or &PROGRAM_ID=5371)
            %then %do;
			
					%cee_disposition_file;
			
			%END; 

			%capture_cmctn_information;

          
                    %end; 
                    /*** loop5 end - loading the mailing history ***/
                    
                    %if &mailing_completed_flg=0 %then %put (&sysmacroname): &_dsname is not a mailing file, history tables are not being updated.;

	            *SASDOC--------------------------------------------------------------------------
	            * Drop all of the temp DB2 tables for this initiative, delete records
	            * of completed initiative FROM TCMCTN_PENDING table.
	            +-----------------------------------------------------------------------SASDOC*;
	            
					%if &program_id ne 5259 %then %do;

                    %drop_initiative_temp_tables;
                    
              		%end;

                    *SASDOC--------------------------------------------------------------------------
                    * When inserting to the history tables completed successfully, the files
                    * for a completed initiative in the /pending and /results directory will be
                    * moved to the /archive directory and be compressed.
                    +-----------------------------------------------------------------------SASDOC*;
                    
                    %archive_results;
                    
                    
       
	        %end;
	        /*** loop4 end - missing apn_miss_cnt ***/       

            %end; 
            /*** loop3 end - assessing table existance and history update for one initiative/cmctn_role ***/

        %end; 
        /*** loop2 end - looping through the initiatives ***/
  
    %end;
    /*** loop1 end - updating all initiatives ***/
    %exit:;

    %CREATE_PROGRAM_DATA_NOIBENFILES;
    *SASDOC--------------------------------------------------------------------------
    * remove RECORDS OVER 90 DAYS FROM TCMCTN_TRANSACTION TABLE.
    * These code are not in the init-loop since it only need to be run once
    * a day at the most.
    +-----------------------------------------------------------------------SASDOC*;
    %macro DEL_TRANS_HIS(TRANSAC_HIS_DAYS=90);
    
        options mlogic mprint mprintnest mlogicnest source2 symbolgen;
        
        PROC SQL;
           CONNECT TO DB2 (DSN=&UDBSPRP);
           CREATE TABLE GT_30DAY AS
           SELECT * FROM CONNECTION TO DB2
           (SELECT COUNT(*) AS GT_30DAY FROM &hercules..TCMCTN_TRANSACTION
                   WHERE  DAYS(CURRENT DATE) - DAYS(DATE(HSC_TS))>&TRANSAC_HIS_DAYS.
                     );
           DISCONNECT FROM DB2;
        QUIT;
        
        data _NULL_;
           set GT_30DAY;
           if GT_30DAY >0 then CALL SYMPUT('CNT_30', left(put(gt_30day, 8.)) );
           else CALL SYMPUT('CNT_30', '0'); 
        run;

        %IF &CNT_30>0 %THEN %STR(

 	    PROC SQL;
              CONNECT TO DB2 (DSN=&UDBSPRP);
              EXECUTE (DELETE  FROM &hercules..TCMCTN_TRANSACTION
                  WHERE  DAYS(CURRENT DATE) - DAYS(DATE(HSC_TS))>&TRANSAC_HIS_DAYS.
                    ) BY DB2;
              DISCONNECT FROM DB2;
            QUIT;

            PROC SQL NOPRINT;
                 SELECT count(*) into: after_rmoval 
                 FROM  &hercules..tcmctn_transaction; 
            QUIT;
 
            %put NOTE: &cnt_30 records have been removed FROM &hercules..tcmctn_transaction.;

        );

    %mend DEL_TRANS_HIS;
    %DEL_TRANS_HIS;
 
%mend update_cmctn_history;


*SASDOC--------------------------------------------------------------------------
* The following macros are "in-stream" and called by the %UPDATE_CMCTN_HISTORY
* macro.
+-----------------------------------------------------------------------SASDOC*;


*SASDOC--------------------------------------------------------------------------*
* Determine and assign CMCTN_IDs for updating TCMCTN history tables.
*    The program will:
*       1): Verify the records for the initiative to be inserted are not
*           already loaded.
*       2): if records for the initiative are already in the his table, the
*           program will deleted all the records related to the initiatives
*           FROM all the history tables and reassign cmctn_ids.
*
+-----------------------------------------------------------------------SASDOC*;

%macro assign_cmctn_id(tbl_name=);

    options mlogic mprint source2 mprintnest mlogicnest symbolgen;
    
    %global max_id init_role_exist subject_id_exists NDC_ID_exists
            CLIENT_ID_EXISTS DRUG_EXPL_DESC_CD err_fl LETTER_TYPE_QY_CD ;
    *SASDOC--------------------------------------------------------------------------
    * Determine if SUBJECT_ID, DRUG_NDC_ID, CLIENT_ID and/or DRUG_EXPL_DESC_CD
    * exist as a variable in &TBL_NAME.  These info will be used to conditionally
    * process the files to to inserted to TCMCTN_ history tables.
    +-----------------------------------------------------------------------SASDOC*;

    proc contents data=&tbl_name OUT=CNTNT(KEEP=NAME) NOPRINT; 
    run;
    
    PROC SQL NOPRINT;
         SELECT COUNT(*) INTO: subject_id_exists
         FROM  CNTNT
         WHERE UPCASE(NAME) CONTAINS 'SUBJECT_ID';
          
         SELECT COUNT(*) INTO: NDC_ID_exists
         FROM  CNTNT
         WHERE UPCASE(NAME) CONTAINS 'DRUG_NDC_ID';
    
         SELECT COUNT(*) INTO: NHU_TYPE_exists
         FROM  CNTNT
         WHERE UPCASE(NAME) CONTAINS 'NHU_TYPE_CD';
    
         SELECT COUNT(*) INTO: CLIENT_ID_exists
         FROM  CNTNT
         WHERE UPCASE(NAME) CONTAINS 'CLIENT_ID';
    
         SELECT COUNT(*) INTO: DRUG_EXPL_DESC_CD
         FROM  CNTNT
         WHERE UPCASE(NAME) CONTAINS 'DRUG_EXPL_DESC_CD';
    QUIT;
    
    PROC SQL;
         CREATE TABLE FIELD_EXISTS_CHK AS
         SELECT MAX( CASE WHEN UPCASE(NAME) CONTAINS 'SUBJECT_ID' THEN 1 ELSE 0 END)
                    AS subject_id_exists,
                MAX(CASE WHEN UPCASE(NAME) CONTAINS 'DRUG_NDC_ID' THEN 1 ELSE 0 END)
                    AS NDC_ID_EXISTS,
                MAX(CASE WHEN UPCASE(NAME) CONTAINS 'NHU_TYPE_CD' THEN 1 ELSE 0 END)
                    AS NHU_TYPE_exists,
    
                MAX(CASE WHEN UPCASE(NAME) CONTAINS 'CLIENT_ID' THEN 1 ELSE 0 END)
                    AS CLIENT_ID_exists,
                MAX(CASE WHEN UPCASE(NAME) CONTAINS 'DRUG_EXPL_DESC_CD' THEN 1 ELSE 0 END)
                    AS DRUG_EXPL_DESC_CD
         FROM CNTNT(KEEP=NAME); 
    QUIT;
       

    PROC SQL NOPRINT;
         SELECT count(*) into: init_role_exist
         FROM &hercules..TCMCTN_RECEIVR_HIS
         WHERE  initiative_id =&initiative_id
           AND  cmctn_role_cd =&cmctn_role_cd; 
    QUIT;

    %if &init_role_exist>0 %then %do;
	%PUT WARNING: Initiative &initiative_id is already in the &hercules..TCMCTN_RECEIVR_HIS table.;
        %PUT WARNING: Records for the initiative will be removed FROM all the history tables and be re-inserted.;

        PROC SQL noprint;
          SELECT max(cmctn_id) into :max_id
          FROM   &hercules..TCMCTN_RECEIVR_HIS;
        QUIT;
        
        %if &program_id ne 73 %then %do;
        
	    PROC SQL;
	         DELETE * FROM &hercules..TCMCTN_RECEIVR_HIS
	         WHERE initiative_ID=&initiative_id
	           AND cmctn_role_cd=&cmctn_role_cd;
	         
	         DELETE * FROM &hercules..TCMCTN_SUBJECT_HIS
	         WHERE initiative_ID=&initiative_id
	           AND cmctn_role_cd=&cmctn_role_cd;
	         
	         DELETE * FROM &hercules..TCMCTN_SBJ_NDC_HIS
	         WHERE initiative_ID=&initiative_id
	           AND cmctn_role_cd=&cmctn_role_cd;
	         
	         DELETE * FROM &hercules..TCMCTN_ADDRESS
	         WHERE initiative_ID=&initiative_id
	           AND cmctn_role_cd=&cmctn_role_cd;
	         QUIT;
	         
	         PROC SQL noprint;
	         SELECT COUNT(cmctn_id) into :max_id
	         FROM   &hercules..TCMCTN_RECEIVR_HIS;
	    QUIT;
	    
        %end;
        
        %put MAX_CMCTN_ID= &max_id.;
        
    %end;
    %else %do;
 
    	PROC SQL noprint;
    	  SELECT COUNT(cmctn_id) into :max_id
    	  FROM   &hercules..TCMCTN_RECEIVR_HIS;
    	QUIT;

   	%put MAX_CMCTN_ID= &max_id.;
   
    %end;   
    

    *SASDOC--------------------------------------------------------------------------
    *
    * Assign CMCTN_IDs to each recipient_id or recipient and subject
    *    NOTE: Except, retail_to_mail, when subject_id field exists, the letter
    *          is sent to both recipient and the cmctn_cd will be assigned
    *          at the subject level.
    *
    +-----------------------------------------------------------------------SASDOC*;

    PROC SQL noprint;
      CREATE   table work.__tcmctn_ids as
      SELECT   distinct
               recipient_id
               %if &LETTER_TYPE_QY_CD=1 %then %str(, subject_id);
               %if &LETTER_TYPE_QY_CD=3 %then %str(, subject_id, drug_ndc_id);
      FROM     &tbl_name
      ORDER BY recipient_id
               %if &LETTER_TYPE_QY_CD =1 %then %str(, subject_id);
               %if &LETTER_TYPE_QY_CD=3 %then %str(, subject_id, drug_ndc_id);
      ;
    QUIT;

    data data_pnd.&table_prefix._&CMCTN_ROLE_CD._tcmctn_ids;
      set work.__tcmctn_ids;
      by recipient_id
         %if &LETTER_TYPE_QY_CD=1 %then %str( subject_id);
         %if &LETTER_TYPE_QY_CD=3 %then %str( subject_id drug_ndc_id);
      ;
      cmctn_id=&max_id+_n_;
    run;
    
%mend assign_cmctn_id;





%macro LOAD_INIT_HIS(tbl_name=);

    
    
    *SASDOC--------------------------------------------------------------------------
    * %LOAD_INIT_HIS: In-stream macro for updating the following tables
    *           &HERCULES..TCMCTN_RECEIVR_HIS
    *           &HERCULES..TCMCTN_SUBJECT_HIS
    *           &HERCULES..TCMCTN_ADDRESS
    *           &HERCULES..TCMCTN_SBJ_NDC_HIS
    +-----------------------------------------------------------------------SASDOC*;
    
    %global err_fl;
    
    *SASDOC--------------------------------------------------------------------------
    * Prepare temp table for inserting into TCMCTN_RECEIVR_HIS.
    +-----------------------------------------------------------------------SASDOC*;
    
    PROC SQL;
         CREATE table layout_flg as
         SELECT c.*,
                b.letter_type_qy_cd
         FROM  completed_initiatives  b, FIELD_EXISTs_CHK C
         WHERE initiative_id=&initiative_id
           and cmctn_role_cd=&cmctn_role_cd; 
    QUIT;
    
    data _null_;
         set layout_flg;
            if subject_id_exists>0 then do;
               call symput('transact_rvr_str', "1 as subject_cmm_rl_cd, x.subject_id,");
               call symput('sbj_his_rcpnt_str', "x.subject_id, &cmctn_role_cd as subject_cmm_rl_cd,");
               call symput('sbj_ndc_rcpnt_str', "x.subject_id,");
               call symput('sbj_sort_str', " subject_id");
               if letter_type_qy_cd=1 then
                  call symput('_where', "and x.subject_id=y.subject_id");
               else if letter_type_qy_cd=3 then
                  call symput('_where', "and x.subject_id=y.subject_id and x.drug_ndc_id=y.drug_ndc_id");
               else call symput('_where', ' ');
                                         end;
             if subject_id_exists=0 then do;
              /* 01SEPT2010 D.Palmer Added missing comma after x.recipient_id in string sbj_ndc_rcpnt_str */
			  /*                     Added subject_id qualifier after x.recipient_id in string transact_rvr_str  */
               call symput('_where', ' ');
               call symput('sbj_sort_str', " ");
               call symput('transact_rvr_str', "&cmctn_role_cd as subject_cmm_rl_cd, x.recipient_id as subject_id,");
               call symput('sbj_his_rcpnt_str', "x.recipient_id, &cmctn_role_cd as subject_cmm_rl_cd,");
               call symput('sbj_ndc_rcpnt_str', "x.recipient_id,");
                                          end;
    
             if client_id_exists>0 then call symput('client_str', 'x.client_id,');
                else call symput('client_str', '-1 as client_id,');
             if drug_expl_desc_cd>0 then
                   call symput('drug_expl_str', 'drug_expl_desc_cd,');
                else do;
                     if ndc_id_exists>0 then
                      call symput('drug_expl_str', '3. as drug_expl_desc_cd,');
                      else call symput('drug_expl_str', '. as drug_expl_desc_cd,');
                 end;
    
             if ndc_id_exists>0 then do;
    
                 if nhu_type_exists >0 then do;
                     call symput('ndc_id_str', 'x.drug_ndc_id, x.nhu_type_cd,');
                     call symput('ndc_sort_str', 'drug_ndc_id nhu_type_cd'); end;
    
                     else do;
                          call symput('ndc_id_str', 'x.drug_ndc_id, 1 as nhu_type_cd,');
                          call symput('ndc_sort_str', 'drug_ndc_id');         end;
    
                                    end;
    
                else do;
                     call symput('ndc_id_str', '. as drug_ndc_id, . as nhu_type_cd,');
                     call symput('ndc_sort_str', '');             end;
    run;

    %put _where=&_where;
    %put transact_rvr_str=&transact_rvr_str;
    %put sbj_his_rcpnt_str=&sbj_his_rcpnt_str;
    %put sbj_ndc_rcpnt_str=&sbj_ndc_rcpnt_str;
    
    %IF &retail_to_mail_flg=0 and &file_usage_cd ne 2 %THEN %DO;
    
        *SASDOC--------------------------------------------------------------------------
        * desides all other rules, a file has to be complete and not a sample file to
        * before being inserted to the his tables
        +-----------------------------------------------------------------------SASDOC*;
        
        %drop_db2_table(tbl_name=&user..TCMCTN_RECEIVR_HIS);
        
        proc sort data=&tbl_name
            (keep= program_id recipient_id client_id apn_cmctn_id &sbj_sort_str &ndc_sort_str
                   address1_tx  address2_tx address3_tx city_tx STATE zip_cd  zip_suffix_cd)
              out=short nodupkey;
         by program_id recipient_id  &sbj_sort_str  client_id apn_cmctn_id &ndc_sort_str
            address1_tx  address2_tx address3_tx city_tx STATE zip_cd  zip_suffix_cd;
        run;

        PROC SQL noprint;
          CREATE table TCMCTN_RECEIVR_HIS&initiative_id as
          SELECT &init_phase_role
                 cmctn_id,
                 x.recipient_id,
                 x.apn_cmctn_id,
                 &PROGRAM_ID AS program_id,
                 date() as communication_dt format=date9.,
                 "&user" as hsc_usr_id,
                  datetime() as hsc_ts,
                 "&user" as hsu_usr_id,
                  datetime() as hsu_ts
          FROM   short x left join
                 data_pnd.&table_prefix._&CMCTN_ROLE_CD._tcmctn_ids   y
          ON     x.program_id     = &program_id
                 and x.recipient_id  =  y.recipient_id
                 &_where;
        QUIT;

  	proc sort data= TCMCTN_RECEIVR_HIS&initiative_id NODUPKEY;
  	  by CMCTN_ID; 
  	run;


 	PROC SQL;
          CONNECT TO DB2 (DSN=&UDBSPRP);
          EXECUTE(
              CREATE TABLE &user..TCMCTN_RECEIVR_HIS AS
              (SELECT * 
               FROM &HERCULES..TCMCTN_RECEIVR_HIS)
               DEFINITION ONLY NOT LOGGED INITIALLY) BY DB2;
          DISCONNECT FROM DB2; 
        QUIT;
        
        PROC SQL noprint;
          INSERT INTO &user..TCMCTN_RECEIVR_HIS(bulkload=yes)
          SELECT * FROM TCMCTN_RECEIVR_HIS&initiative_id;
        QUIT;

        %set_error_fl;

	*SASDOC--------------------------------------------------------------------------
	* Prepare temp table for inserting into TCMCTN_SUBJECT_HIS
	+-----------------------------------------------------------------------SASDOC*;

	%drop_db2_table(tbl_name=&user..TCMCTN_SUBJECT_HIS);

        PROC SQL noprint;
           CREATE TABLE TCMCTN_SUBJECT_HIS&initiative_id. AS
          SELECT &init_phase_role
                 cmctn_id,
                  &sbj_his_rcpnt_str
                  &client_str
                  "&user" as hsc_usr_id,
                  datetime() as hsc_ts,
                 "&user" as hsu_usr_id,
                  datetime() as hsu_ts

          FROM   short  x left join
                 data_pnd.&table_prefix._&CMCTN_ROLE_CD._tcmctn_ids   y
          ON  x.program_id     = &program_id
             and x.recipient_id  =  y.recipient_id
             &_where ;
        QUIT;

	PROC SORT DATA= TCMCTN_SUBJECT_HIS&initiative_id NODUPKEY;
	 BY CMCTN_ID &sbj_sort_str; 
	RUN;

	PROC SQL;
	 CONNECT TO DB2 (DSN=&UDBSPRP);
	 EXECUTE(
	      CREATE TABLE &user..TCMCTN_SUBJECT_HIS AS
	      (SELECT * FROM &HERCULES..TCMCTN_SUBJECT_HIS)
	       DEFINITION ONLY NOT LOGGED INITIALLY) BY DB2;
	DISCONNECT FROM DB2; 
	QUIT;

	PROC SQL noprint;
	  INSERT INTO &user..TCMCTN_SUBJECT_HIS(bulkload=yes)
	  SELECT * 
	  FROM TCMCTN_SUBJECT_HIS&initiative_id;
	QUIT;
	
        %set_error_fl;

	*SASDOC--------------------------------------------------------------------------
	* Prepare temp table for inserting into TCMCTN_ADDRESS.
	+-----------------------------------------------------------------------SASDOC*;

	%drop_db2_table(tbl_name=&user..TCMCTN_ADDRESS);


	PROC SQL noprint;
	  CREATE TABLE TCMCTN_ADDRESS&initiative_id. AS
	  SELECT &init_phase_role
		 cmctn_id,
		 address1_tx,
		 address2_tx,
		 address3_tx,
		 '--' AS address4_tx,
		 city_tx,
		 STATE AS state_cd,
		 zip_cd,
		 zip_suffix_cd,
		 '' AS intl_postal_cd,
		 . AS country_cd,
		 "&user" as hsc_usr_id,
		  datetime() as hsc_ts,
		 "&user" as hsu_usr_id,
		  datetime() as hsu_ts

	  FROM   short      x,
		 data_pnd.&table_prefix._&CMCTN_ROLE_CD._tcmctn_ids   y
	  where  x.program_id     = &program_id
	     and x.recipient_id  =  y.recipient_id
	     &_where;
	QUIT;

	PROC SORT DATA= TCMCTN_ADDRESS&initiative_id NODUPKEY;
	 BY CMCTN_ID; 
	RUN;

	PROC SQL;
	 CONNECT TO DB2 (DSN=&UDBSPRP);
	 EXECUTE(
	      CREATE TABLE &user..TCMCTN_ADDRESS AS
	      (SELECT * FROM &HERCULES..TCMCTN_ADDRESS)
	       DEFINITION ONLY NOT LOGGED INITIALLY) BY DB2;
	DISCONNECT FROM DB2; 
	QUIT;

	PROC SQL noprint;
	  INSERT INTO &user..TCMCTN_ADDRESS(bulkload=yes)
	  SELECT * 
	  FROM TCMCTN_ADDRESS&initiative_id;
	QUIT;

        %set_error_fl;

	*SASDOC--------------------------------------------------------------------------
	* Prepare temp table for inserting into TCMCTN_SBJ_NDC_HIS.
	+-----------------------------------------------------------------------SASDOC*;

        %drop_db2_table(tbl_name=&user..TCMCTN_SBJ_NDC_HIS);
        
        %if &ndc_id_exists>0 %then %do;
        
	    PROC SQL;
	      CONNECT TO DB2 (DSN=&UDBSPRP);
	      EXECUTE(
	          CREATE TABLE &user..TCMCTN_SBJ_NDC_HIS AS
	          (SELECT * FROM &HERCULES..TCMCTN_SBJ_NDC_HIS)
	           DEFINITION ONLY NOT LOGGED INITIALLY) BY DB2;
	      DISCONNECT FROM DB2; 
	    QUIT;
	    
	    PROC SQL noprint  ;
	      CREATE TABLE TCMCTN_SBJ_NDC_HIS&initiative_id AS
	      SELECT &init_phase_role
	         cmctn_id,
	         &sbj_ndc_rcpnt_str
	         &ndc_id_str
	       "&user" as hsc_usr_id,
	        datetime() as hsc_ts,
	       "&user" as hsu_usr_id,
	        datetime() as hsu_ts
	      FROM   short          x left join
	         data_pnd.&table_prefix._&CMCTN_ROLE_CD._tcmctn_ids   y
	      on  x.program_id  = &program_id
	      and x.recipient_id  =  y.recipient_id
	      &_where ;
	    QUIT;
	    
	    PROC SORT DATA= TCMCTN_SBJ_NDC_HIS&initiative_id NODUPKEY;
	     BY CMCTN_ID drug_ndc_id nhu_type_cd; 
	    RUN;
	    
	    PROC SQL noprint;
	      INSERT INTO &user..TCMCTN_SBJ_NDC_HIS(bulkload=yes)
	      SELECT * 
	      FROM TCMCTN_SBJ_NDC_HIS&initiative_id;
	    QUIT;

	%end;

        %set_error_fl;


        %on_error(ACTION=ABORT, EM_TO=&email_it,
                  EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
                  EM_MSG="A problem was encountered. See LOG file - &mac_NAME..log for Initiative ID &Initiative_ID");


	%IF &ERR_FL>0 %THEN %PUT WARNING: ENCOUNTERED ERROR WHILE UPDATING TCMCTN HISTORY TABLES FOR INITIATIVE &initiative_id..;
	%IF &ERR_FL=0 %THEN %DO;

	    PROC SQL;
	         CONNECT TO DB2 (DSN=&UDBSPRP);
	    
	         EXECUTE ( ROLLBACK) BY DB2;
	         EXECUTE ( INSERT INTO &HERCULES..TCMCTN_RECEIVR_HIS
	    	       SELECT A.*
	    	       FROM &USER..TCMCTN_RECEIVR_HIS A) BY DB2;
	    
	         EXECUTE ( INSERT INTO &HERCULES..TCMCTN_ADDRESS
	    	       SELECT A.*
	    	       FROM &USER..TCMCTN_ADDRESS A) BY DB2;
	    
	         EXECUTE ( INSERT INTO &HERCULES..TCMCTN_SUBJECT_HIS
	    	       SELECT A.*
	    	       FROM &USER..TCMCTN_SUBJECT_HIS A) BY DB2;
	    
	         %if &ndc_id_exists>0 %then %do;
	          EXECUTE ( INSERT INTO &HERCULES..TCMCTN_SBJ_NDC_HIS
	    	       SELECT A.*
	    	       FROM &USER..TCMCTN_SBJ_NDC_HIS A) BY DB2;
	         %end;
	    
	       DISCONNECT FROM DB2;
	    QUIT;
	    
	    %SET_ERROR_FL;

	%END;
	
    %END;


    *SASDOC--------------------------------------------------------------------------
    * Prepare temp table for inserting into TCMCTN_TRANSACTION.
    *
    *   NOTE: Only mailing file (file_usage_cd=1) can be inserted to the tranaction
    *         While an analysis file will only be updated on the Hercules tables except
    *         transaction table.
    *         mostly subject_cmm_rl_cd should be participant(1) unless the subject_id
    *         field is not available then use the receipient cmctn_role_cd as
    *         subject_cmm_rl_cd.
    *         If drug_exp_des_cd is available on file, use it. Otherwise hard-code to 3
    *         (target drug) whenever the ndc is on the file but the drug_exp_des_cd
    *         does not exist.
    +-----------------------------------------------------------------------SASDOC*;

    %if &file_usage_cd = 1 %then %do;

        %drop_db2_table(tbl_name=&user..TCMCTN_TRANSACTION);
        
    *SASDOC--------------------------------------------------------------------------
	* G. Dudley 03/07/2007
    * Since the GID column TRANSACTION_ID has been added to the 
	* HERCULES.TCMCTN_TRANSACTION table, the selection from and insertion to this 
	* table will need to specify the column names in the SELECT statement of the
	* PROC SQL.
    +-----------------------------------------------------------------------SASDOC*;
        PROC SQL;
             CONNECT TO DB2 (DSN=&UDBSPRP);
             EXECUTE(
                  CREATE TABLE &user..TCMCTN_TRANSACTION AS
                  (SELECT PROGRAM_ID
							,APN_CMCTN_ID
							,CMCTN_GENERATED_TS
							,RECEIVER_CMM_RL_CD
							,RECEIVER_ID       
							,RECEIVER_NM       
							,DISTRIBUTION_CD   
							,SUBJECT_CMM_RL_CD 
							,SUBJECT_ID        
							,ADDRESS1_TX       
							,ADDRESS2_TX       
							,ADDRESS3_TX       
							,ADDRESS4_TX       
							,CITY_TX           
							,STATE_CD          
							,ZIP_CD            
							,ZIP_SUFFIX_CD     
							,INTL_POSTAL_CD    
							,COUNTRY_CD        
							,EMAIL_ADDR_TX     
							,PHONE_NB          
							,AREA_CD_NB        
							,EXTENSION_NB      
							,CMCTN_STS_CD      
							,IMAGE_ID
							,DRUG_EXPL_DESC_CD
							,DRUG_NDC_ID      
							,NHU_TYPE_CD      
							,HSC_TRN_CD       
							,HSC_SRC_CD       
							,HSC_USR_ID       
							,HSC_TS           
							,HSU_TRN_CD       
							,HSU_SRC_CD       
							,HSU_USR_ID       
							,HSU_TS
							,CMCTN_HISTORY_ID 
				   FROM &HERCULES..TCMCTN_TRANSACTION)
                   DEFINITION ONLY NOT LOGGED INITIALLY) BY DB2;
           DISCONNECT FROM DB2; QUIT;
        
            PROC SQL noprint  ;
              CREATE table TCMCTN_TRANSACTION as
              SELECT distinct
                     &program_id as program_id,
                     apn_cmctn_id,
                     &release_ts as cmctn_generated_ts,
                     &CMCTN_ROLE_CD AS receiver_cmm_rl_cd,
                     Y.recipient_id as receiver_id,
                     TRIM(LEFT(RVR_FIRST_NM))||' '||TRIM(LEFT(RVR_LAST_NM)) AS receiver_nm,
                     1 AS distribution_cd,
                     &transact_rvr_str
                     address1_tx,
                     address2_tx,
                     address3_tx,
                     '' as address4_tx,
                     city_tx,
                     STATE AS state_cd,
                     zip_cd,
                     zip_suffix_cd,
                     '' AS intl_postal_cd,
                     . AS country_cd,
                     '' as email_addr_tx,
        
                     '' as phone_nb,
                     '' as area_cd_nb,
                     '' as extension_nb,
                     2 as cmctn_sts_cd,
                     . as image_id,
                     &drug_expl_str
                     &ndc_id_str
                     0 AS hsc_trn_cd,
                     0 AS hsc_src_cd,
                     'SASADM' AS  hsc_usr_id,
                     datetime() as hsc_ts,
                     0 AS hsu_trn_cd,
                     0 AS hsu_src_cd,
                     'SASADM' AS hsu_usr_id,
                     datetime() as hsu_ts,
					 . AS CMCTN_HISTORY_ID
        
              FROM   &tbl_name          x,
                     data_pnd.&table_prefix._&CMCTN_ROLE_CD._tcmctn_ids   y
              where  x.program_id     = &program_id
                 and x.recipient_id  =  y.recipient_id
				 and x.recipient_id  <> 9999999999
				 and y.recipient_id  <> 9999999999
                &_where ;
        QUIT;

        proc sort data=TCMCTN_TRANSACTION nodupkey;
          by RECEIVER_ID &sbj_sort_str &ndc_sort_str; 
        run;

        %put NOTE: UPDATING &USER..TCMCTN_TRANSACTION FOR INITIATIVE &initiative_id..;

/*        PROC SQL noprint  ;*/
/*          INSERT INTO &user..TCMCTN_TRANSACTION*/
/*          SELECT **/
/*            FROM TCMCTN_TRANSACTION;*/
/*        QUIT;*/


/* AK ADDED 26APR2012 TO FIX THE NHU_TYPE_CD BUG WHICH IS A SMALL INT IN THE TRANSACTION TABLE.*/
/* INPUT TCMCTN_TRANSACTION HAS A VALUE OF 999999 (LARGE INT) IF THE PENDING */
/* DATASET WAS HAVING NULL NHU_TYPE_CD VALUE 8*/

		PROC SQL;
		  insert into &user..TCMCTN_TRANSACTION
		      (PROGRAM_ID,
		   APN_CMCTN_ID,
		   CMCTN_GENERATED_TS,
		   RECEIVER_CMM_RL_CD,
		   RECEIVER_ID,
		   RECEIVER_NM,
		   DISTRIBUTION_CD,
		   SUBJECT_CMM_RL_CD,
		   SUBJECT_ID,
		   ADDRESS1_TX,
		   ADDRESS2_TX,
		   ADDRESS3_TX,   
		   CITY_TX,
		   STATE_CD,
		   ZIP_CD,
		   ZIP_SUFFIX_CD,   
		   CMCTN_STS_CD,     
		   DRUG_NDC_ID,
		   NHU_TYPE_CD, 
		   HSC_TRN_CD,
		   HSC_SRC_CD,
		   HSC_USR_ID,
		   HSC_TS,
		   HSU_TRN_CD,
		   HSU_SRC_CD,
		   HSU_USR_ID,
		   HSU_TS) 
		   select 
		    PROGRAM_ID,
		   APN_CMCTN_ID,
		   CMCTN_GENERATED_TS,
		   RECEIVER_CMM_RL_CD,
		   RECEIVER_ID,
		   RECEIVER_NM,
		   DISTRIBUTION_CD,
		   SUBJECT_CMM_RL_CD,
		   SUBJECT_ID,
		   ADDRESS1_TX,
		   ADDRESS2_TX,
		   ADDRESS3_TX,   
		   CITY_TX,
		   STATE_CD,
		   ZIP_CD,
		   ZIP_SUFFIX_CD,   
		   CMCTN_STS_CD,   
		   DRUG_NDC_ID,
		   CASE 					
	WHEN NHU_TYPE_CD > 32767 THEN . ELSE NHU_TYPE_CD		
	END AS NHU_TYPE_CD, 									
		   HSC_TRN_CD,							
		   HSC_SRC_CD,
		   HSC_USR_ID,
		   HSC_TS,
		   HSU_TRN_CD,
		   HSU_SRC_CD,
		   HSU_USR_ID,
		   HSU_TS
		  FROM TCMCTN_TRANSACTION;
		quit;

        %set_error_fl;

	%if &ERR_FL>0 %then %put WARNING: ENCOUNTERED ERROR WHILE UPDATING &HERCULES..TCMCTN_TRANSACTION FOR INITIATIVE &initiative_id..;

	%if &ERR_FL=0 %then %do;

            PROC SQL;
               CONNECT TO DB2 (DSN=&UDBSPRP);
               CREATE TABLE MAX_TS AS
               SELECT * FROM CONNECTION TO DB2
                  (SELECT distinct PROGRAM_ID, cmctn_generated_ts
                            FROM &HERCULES..TCMCTN_TRANSACTION
                            WHERE PROGRAM_ID=&PROGRAM_ID
                            );
               DISCONNECT FROM DB2; 
            QUIT;
            
            PROC SQL NOPRINT;
               SELECT COUNT(*) INTO: MATCH_TS
               FROM MAX_TS
               WHERE PUT(CMCTN_GENERATED_TS,20.)="&RELEASE_TS";
            QUIT; 
            %put max_ts = &max_ts;
	    %if &MATCH_TS>0 %then %put NOTE: Records for Initiative &initiative_id are already in the TCMCTN_TRANSACTION table.;

	    %if &MATCH_TS =0 %then %do;

		*SASDOC--------------------------------------------------------------------------
		* G. Dudley 03/07/2007
		* Since the GID column TRANSACTION_ID has been added to the 
		* HERCULES.TCMCTN_TRANSACTION table, the selection from and insertion to this 
		* table will need to specify the column names in the SELECT statement of the
		* PROC SQL.
		+-----------------------------------------------------------------------SASDOC*;

		%put NOTE: UPDATING &HERCULES..TCMCTN_TRANSACTION FOR INITIATIVE &initiative_id..;
                PROC SQL;
                   CONNECT TO DB2 (DSN=&UDBSPRP);
                   EXECUTE (
                             INSERT INTO &HERCULES..TCMCTN_TRANSACTION
                                   ( PROGRAM_ID
									,APN_CMCTN_ID
									,CMCTN_GENERATED_TS
									,RECEIVER_CMM_RL_CD
									,RECEIVER_ID       
									,RECEIVER_NM       
									,DISTRIBUTION_CD   
									,SUBJECT_CMM_RL_CD 
									,SUBJECT_ID        
									,ADDRESS1_TX       
									,ADDRESS2_TX       
									,ADDRESS3_TX       
									,ADDRESS4_TX       
									,CITY_TX           
									,STATE_CD          
									,ZIP_CD            
									,ZIP_SUFFIX_CD     
									,INTL_POSTAL_CD    
									,COUNTRY_CD        
									,EMAIL_ADDR_TX     
									,PHONE_NB          
									,AREA_CD_NB        
									,EXTENSION_NB      
									,CMCTN_STS_CD      
									,IMAGE_ID
									,DRUG_EXPL_DESC_CD
									,DRUG_NDC_ID      
									,NHU_TYPE_CD      
									,HSC_TRN_CD       
									,HSC_SRC_CD       
									,HSC_USR_ID       
									,HSC_TS           
									,HSU_TRN_CD       
									,HSU_SRC_CD       
									,HSU_USR_ID       
									,HSU_TS )
                             SELECT  PROGRAM_ID
									,APN_CMCTN_ID
									,CMCTN_GENERATED_TS
									,RECEIVER_CMM_RL_CD
									,RECEIVER_ID       
									,RECEIVER_NM       
									,DISTRIBUTION_CD   
									,SUBJECT_CMM_RL_CD 
									,SUBJECT_ID        
									,ADDRESS1_TX       
									,ADDRESS2_TX       
									,ADDRESS3_TX       
									,ADDRESS4_TX       
									,CITY_TX           
									,STATE_CD          
									,ZIP_CD            
									,ZIP_SUFFIX_CD     
									,INTL_POSTAL_CD    
									,COUNTRY_CD        
									,EMAIL_ADDR_TX     
									,PHONE_NB          
									,AREA_CD_NB        
									,EXTENSION_NB      
									,CMCTN_STS_CD      
									,IMAGE_ID
									,DRUG_EXPL_DESC_CD
									,DRUG_NDC_ID      
									,NHU_TYPE_CD      
									,HSC_TRN_CD       
									,HSC_SRC_CD       
									,HSC_USR_ID       
									,HSC_TS           
									,HSU_TRN_CD       
									,HSU_SRC_CD       
									,HSU_USR_ID       
									,HSU_TS           
                             FROM &USER..TCMCTN_TRANSACTION
                           ) BY DB2;
                
                   DISCONNECT FROM DB2;
                QUIT;

   	    %end;
   	    
 	%end;
 	
	%set_error_fl;

    %end;

    %EXIT_LOAD:;
    
    %put _LOCAL_;


*SASDOC--------------------------------------------------------------------------
| SY - 20NOV2008
|
| Added logic to include new template history table for 5286 - ibenefit proactive 
| access health alert for rhi messaging.  
+-----------------------------------------------------------------------SASDOC*;

%IF &PROGRAM_ID = 5286 AND &TASK_ID = 33 %THEN %DO;

	*SASDOC--------------------------------------------------------------------------
	| Retrieve the 5286 participants and their rhi messages.
	+-----------------------------------------------------------------------SASDOC*;
	DATA &TABLE_PREFIX._RECID_RHIMSG (KEEP  = PT_BENEFICIARY_ID APN_CMCTN_ID DISPLAY_SEQ_NB 
	                                  WHERE = (APN_CMCTN_ID IS NOT MISSING));
	  RETAIN DISPLAY_SEQ_NB;
	  SET &DB2_TMP..&TABLE_PREFIX._HEALTHALERT;
	  BY PT_BENEFICIARY_ID;
		APN_CMCTN_ID=RHI_MSG1; DISPLAY_SEQ_NB = 1; OUTPUT;
		APN_CMCTN_ID=RHI_MSG2; DISPLAY_SEQ_NB = 2; OUTPUT;
		APN_CMCTN_ID=RHI_MSG3; DISPLAY_SEQ_NB = 3; OUTPUT;
	RUN;
	
	DATA TCMCTN_TRN_TPL_CMP_TEMPLATE;
	  FORMAT RECEIVER_ID 12.;
	  SET &HERCULES..TCMCTN_TRN_TPL_CMP (OBS = 0);	  
	RUN;
	
	*SASDOC--------------------------------------------------------------------------
	| The 5286 participants are only eligible for one letter per 12 months.
	+-----------------------------------------------------------------------SASDOC*;	

	PROC SQL;
	  CREATE TABLE TCMCTN_TRN_TPL_CMP AS
	  SELECT DISTINCT A.RECEIVER_ID,
			  A.TRANSACTION_ID, 
			  &PROGRAM_ID AS PROGRAM_ID,
			  B.APN_CMCTN_ID,
			  B.DISPLAY_SEQ_NB
	  FROM &HERCULES..TCMCTN_TRANSACTION	A,
	       &TABLE_PREFIX._RECID_RHIMSG	B
	  WHERE A.PROGRAM_ID  = &PROGRAM_ID
	    AND A.RECEIVER_ID = B.PT_BENEFICIARY_ID
	    AND A.HSC_TS > datetime() - 43200  
            AND A.TRANSACTION_ID NOT IN  
                                (SELECT TRANSACTION_ID
                                 FROM &HERCULES..TCMCTN_TRN_TPL_CMP);
	QUIT;
	
	DATA TCMCTN_TRN_TPL_CMP;
	 MERGE TCMCTN_TRN_TPL_CMP_TEMPLATE
	       TCMCTN_TRN_TPL_CMP ;
	 IF RECEIVER_ID = . THEN DELETE;
	RUN;

	PROC SQL NOPRINT;
	  DROP TABLE &DB2_TMP..TCMCTN_TRN_TPL_CMP ;
	QUIT;

	PROC SQL NOPRINT;
	  CREATE TABLE &DB2_TMP..TCMCTN_TRN_TPL_CMP AS
	  SELECT * 
	  FROM TCMCTN_TRN_TPL_CMP;
	QUIT;

	%set_error_fl;

	%IF &ERR_FL>0 %THEN %PUT WARNING: ENCOUNTERED ERROR WHILE UPDATING &HERCULES..TCMCTN_TRN_TPL_CMP FOR INITIATIVE &INITIATIVE_ID..;

	%LET TCMCTN_COUNT = 0;
	
	PROC SQL NOPRINT;
	  SELECT COUNT(*) INTO: TCMCTN_COUNT
	  FROM &DB2_TMP..TCMCTN_TRN_TPL_CMP ;
	QUIT;
	
	%PUT NOTE:  TCMCTN_COUNT = &TCMCTN_COUNT. ;
	
	%IF &ERR_FL=0 AND &TCMCTN_COUNT. > 0 %THEN %DO;
	
		*SASDOC--------------------------------------------------------------------------
		| Load 5286 participants into TCMCTN_TRN_TPL_CMP.
		+-----------------------------------------------------------------------SASDOC*;	

		PROC SQL;
		  CONNECT TO DB2 (DSN=&UDBSPRP);
		  EXECUTE 
		     (
			INSERT INTO &HERCULES..TCMCTN_TRN_TPL_CMP
			  (TRANSACTION_ID,
			   PROGRAM_ID,
			   APN_CMCTN_ID,
			   DISPLAY_SEQ_NB)
			SELECT 
			   TRANSACTION_ID, 
			   PROGRAM_ID,
			   APN_CMCTN_ID,
			   DISPLAY_SEQ_NB

			FROM &DB2_TMP..TCMCTN_TRN_TPL_CMP
		      ) BY DB2;
		  DISCONNECT FROM DB2;
		QUIT;

	%END;

%END;

%mend LOAD_INIT_HIS;

*SASDOC--------------------------------------------------------------------------
* MACRO %ARCHIVE_RESULTS: Archives SAS datasets in data_pnd and DATA_RES as
* compressed files and stores them in the ./archive folder.
+-----------------------------------------------------------------------SASDOC*;

%macro archive_results(tbl_name=);

    options mlogic mprint source2 mlogicnest mprintnest symbolgen;
    
    %global err_fl;

    *SASDOC--------------------------------------------------------------------------
    * If all goes well set archieve_sts_cd =1 for the perspective inititive.
    +-----------------------------------------------------------------------SASDOC*;

    %if &ERR_FL=0 and &initiative_completed_flg >0 %then %do;
    
    	%if &mailing_completed_flg>0 %then %STR(
    	
	    PROC SQL;
		 update &hercules..TPHASE_RVR_FILE
		 SET ARCHIVE_STS_CD=1
		 WHERE INITIATIVE_ID=&initiative_id
		   AND CMCTN_ROLE_CD=&CMCTN_ROLE_CD; 
	    QUIT;
	    
    	);

    	%else  %STR(
    	
	     PROC SQL;
	        UPDATE &hercules..TPHASE_RVR_FILE
	        SET ARCHIVE_STS_CD=2
	        WHERE INITIATIVE_ID=&initiative_id
	          AND CMCTN_ROLE_CD=&CMCTN_ROLE_CD; 
	     QUIT;
         
         );

    %end;


    %if &err_fl=0 %then %do;

	*SASDOC--------------------------------------------------------------------------
	* Move/rename the pending dataset into the archive folder.
	+-----------------------------------------------------------------------SASDOC*;

	data DATA_ARC.&table_prefix._&cmctn_role_cd._pending(COMPRESS=YES);
	  set &_DSNAME; 
	run;

	PROC SQL;
	  DROP TABLE &_DSNAME;
	  DROP TABLE data_pnd.&table_prefix._&cmctn_role_cd._tcmctn_ids;
	  DROP TABLE &_DSNAME.2; 
	QUIT;

	%set_error_fl;

	%if &ERR_FL=0 %then %put NOTE: (&sysmacroname): &tbl_name (pending) has been archived.;
	%else %PUT WARNING: (&sysmacroname): &tbl_name (pending) could not be archived.;
	    
    %end;

    %if &err_fl=0 %then %do;
    
	*SASDOC--------------------------------------------------------------------------
	* Move/rename the results dataset into the archive folder.
	+-----------------------------------------------------------------------SASDOC*;

	data DATA_ARC.&table_prefix._&cmctn_role_cd._results(COMPRESS=YES);
	  set DATA_RES.&table_prefix._&cmctn_role_cd.; 
	run;

	PROC SQL;
	DROP TABLE DATA_RES.&table_prefix._&cmctn_role_cd.;
	QUIT;

	%set_error_fl;
	%if &err_fl=0 %then %put NOTE: (&sysmacroname): &tbl_name (results) has been archived.;
	%else %PUT WARNING: (&sysmacroname): &data_dir/results/&_dsname..sas7bdat could not be archived.;
     
    %end;

    %if %sysfunc(exist(&_dsname._2))>0 %then %do;
    
	data DATA_ARC.&table_prefix._&cmctn_role_cd._2_pending(COMPRESS=YES);
	  set &_DSNAME._2; 
	run;

	data DATA_ARC.&table_prefix._&cmctn_role_cd._2_results(COMPRESS=YES);
	  set DATA_RES.&table_prefix._&cmctn_role_cd._2; 
	run;

	%set_error_fl;
	
        %if &err_fl=0 %then %str(
        
             PROC SQL;
                DROP TABLE data_res.&table_prefix._&cmctn_role_cd._2;
                DROP TABLE &_DSNAME._2; 
             QUIT;
             
        );

    %end;

    x "compress -f &DATA_DIR./archive/%lowcase(&table_prefix.)_&cmctn_role_cd.*";

    *SASDOC--------------------------------------------------------------------------
    * REMOVE RECORDS FROM TCMCTN_PENDING TABLE
    +-----------------------------------------------------------------------SASDOC*;
    
    %let pending_cnt=;
    
    PROC SQL noprint;
         SELECT count(*) into: pending_cnt
         FROM &HERCULES..TCMCTN_PENDING
         where INITIATIVE_ID=&initiative_id
         AND   CMCTN_ROLE_CD=&CMCTN_ROLE_CD; 
    QUIT;
    
    %if &pending_cnt>0 %then %do;

	PROC SQL;
	     CONNECT TO DB2 (DSN=&UDBSPRP);
	     EXECUTE (DELETE  FROM &HERCULES..TCMCTN_PENDING
		       WHERE INITIATIVE_ID=&initiative_id
		       AND   CMCTN_ROLE_CD=&CMCTN_ROLE_CD) BY DB2;
	     DISCONNECT FROM DB2;
	QUIT;

	/*************************************************************
	
		PROC SQL;
		     CONNECT TO DB2 (DSN=&UDBSPRP);
		     EXECUTE (
		     DELETE  FROM &HERCULES..TCMCTN_PENDING a
			       WHERE NOT EXISTS
				 (SELECT 1
				  FROM (SELECT DISTINCT INITIATIVE_ID FROM
					 &HERCULES..TINITIATIVE) b
				  where A.INITIATIVE_ID=B.INITIATIVE_ID)
				) BY DB2;
		     %reset_sql_err_cd;
		     DISCONNECT FROM DB2;
		QUIT;

	*************************************************************/

    %end;

    %set_error_fl;

    %on_error(ACTION=ABORT, EM_TO=&email_it,
              EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
              EM_MSG="A problem was encountered. See LOG file - &mac_NAME..log for Initiative ID &Initiative_ID");

%mend archive_results;
*SASDOC--------------------------------------------------------------------------
* MACRO %DROP_INITIATIVE_TEMP_TABLES: In-stream macro for dropping the
* DB2 temp tables for an initiative FROM the &DB2_TMP schema.
*
*  NOTE: do not think the program should be here
+-----------------------------------------------------------------------SASDOC*;

%macro drop_initiative_temp_tables;

    options mlogic mprint source2 mlogicnest mprintnest symbolgen;
    
    %if &err_fl=0 %then %do;

        *SASDOC--------------------------------------------------------------------------
        * REMOVE TEMP TABLES                        
        +-----------------------------------------------------------------------SASDOC*;
        
        PROC SQL NOPRINT;
           SELECT 'DROP TABLE '||COMPRESS(TABSCHEMA)||'.'||COMPRESS(TABNAME), count(*)
            INTO: DROP_TBL SEPARATED BY "%STR(;)", :drp_tbl_cnt
           FROM SYSCAT.TABLES
           WHERE TABSCHEMA="&DB2_TMP"
           AND TABNAME CONTAINS ("&table_prefix")
           AND COMPRESS(DEFINER)="&USER"
           AND TYPE NOT IN ('A','V')
           ;
        QUIT;
        
        %if &drp_tbl_cnt > 0 %then %str(
        
            PROC SQL;
               &drop_tbl; 
            QUIT;
        
        );
        
        *SASDOC--------------------------------------------------------------------------
        * REMOVE ALIAS                              
        +-----------------------------------------------------------------------SASDOC*;
        
        PROC SQL NOPRINT;
            SELECT 'EXECUTE (DROP ALIAS '||COMPRESS(TABSCHEMA)||'.'||COMPRESS(TABNAME)||')', count(*)
               INTO: DROP_ALIAS SEPARATED BY "%STR(BY DB2;)", :drp_alias_cnt
            FROM SYSCAT.TABLES
            WHERE TABSCHEMA="&DB2_TMP"
             AND TABNAME CONTAINS ("&table_prefix")
             AND COMPRESS(DEFINER)="&USER"
             AND TYPE IN ('A')
             ;
        QUIT;
        
        %if &drp_alias_cnt>0 %then %do;
        
	    PROC SQL;
	       CONNECT TO DB2 (DSN=&UDBSPRP);
	       &DROP_ALIAS BY DB2;
	       DISCONNECT FROM DB2;
	    QUIT;
        
        %end;
        
        PROC SQL NOPRINT;
           SELECT 'DROP TABLE '||COMPRESS(TABSCHEMA)||'.'||COMPRESS(TABNAME), count(*)
            INTO: DROP_TBL2 SEPARATED BY "%STR(;)", :drp_tbl_cnt2
           FROM SYSCAT.TABLES
           WHERE TABSCHEMA="&DB2_TMP"
            AND TABNAME IN ("TCMCTN_RECEIVR_HIS&initiative_id.", "TCMCTN_SUBJECT_HIS&initiative_id.",
                            "TCMCTN_SBJ_NDC_HIS&initiative_id.", "TCMCTN_ADDRESS&initiative_id.",
                            "TCMCTN_TRANSACTION&initiative_id.")
            AND COMPRESS(DEFINER)="&USER"
            ;
        QUIT;
    
        %if &drp_tbl_cnt2>0 %then %str( 
    
    	    PROC SQL;
               &drop_tbl2; 
            QUIT;
            
        );

    %end;

%mend drop_initiative_temp_tables;


			

*SASDOC--------------------------------------------------------------------------
* MACRO %CAPTURE_CMCTN_INFORMATION: Captures the status of each initiative in the    
* update communication history process and saves them in a temporary dataset
+-----------------------------------------------------------------------SASDOC*;

%macro capture_cmctn_information;

    data temp;
      length INITIATIVE $10 ERROR_FLAG $10 STATUS $150 ;
      INITIATIVE="&INITIATIVE_ID.";
      ERROR_FLAG="&err_fl.";
          %if &apn_miss_cnt > 0 %then %do;
            STATUS="Update communication history process was unsuccessful.  Missing apn_cmctn_id was present. Examine log for details.";
          %end;
          %else %if &missing_dataset > 0 %then %do;
            STATUS="Update communication history process was unsuccessful.  Missing dataset.  Examine log for details.";
          %end;
          %else %if &err_fl>0 %then %do;
            STATUS="Update communication history process was unsuccessful.  Examine log for details.";
          %end;
          %else %do;
            STATUS="Update communication history process was successful.";
          %end;
    run; 
        
    %let err_fl=0;
    %let missing_dataset=0;
    

    %if %SYSFUNC(EXIST(WORK.REPORTFILE)) %then %do;

        data ReportFile;
          set ReportFile temp;
        run;

    %end; 
    %else %do;

        data ReportFile;
          set temp;
        run;

    %end;	

    proc sort data = ReportFile;
      by descending ERROR_FLAG INITIATIVE;
    run;

%mend capture_cmctn_information;


*SASDOC--------------------------------------------------------------------------
* MACRO %CREATE_CMCTN_HISTORY_REPORT: Creates a pdf report of the initiatives in the    
* update communication history process.
+-----------------------------------------------------------------------SASDOC*;
%macro create_cmctn_history_report;

    DATA _NULL_;
     LENGTH day $ 2;
     day= PUT(DAY(today()),z2.);
      CALL SYMPUT('day', day);
    RUN;

    libname  CMCTNHIS "/herc%lowcase(&SYSMODE)/data/hercules/gen_utilities/sas/update_cmctn";
    filename RPTFL "/herc%lowcase(&SYSMODE)/data/hercules/gen_utilities/sas/update_cmctn/update_communication_history_status_&day..pdf";
 
	%if %SYSFUNC(EXIST(WORK.REPORTFILE)) %then %do;
	    data CMCTNHIS.reportfile_&day.;
	     set reportfile;
	    run;
	%end;
    
%mend create_cmctn_history_report;


*SASDOC ----------------------------------------------------------------------
| Execute the UPDATE_CMCTN_HISTORY process                             
+-----------------------------------------------------------------------SASDOC*;
%update_cmctn_history;


*SASDOC ----------------------------------------------------------------------
| UPDATE TCMCTN_TRANSACTION STATUS
+-----------------------------------------------------------------------SASDOC*;
%include "/herc%lowcase(&SYSMODE)/prg/hercules/gen_utilities/sas/transac_his_sum.sas";


*SASDOC--------------------------------------------------------------------------
* Create a report of the initiatives information.                     
+-----------------------------------------------------------------------SASDOC*;
%create_cmctn_history_report;
