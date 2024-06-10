/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  autorelease_file.sas (macro)
|
| LOCATION: /PRG/sas&sysmode.1/hercules/macros
|
| PURPOSE:      Checks for default conditions that will call macros for file release.
|                       All fields are found on TPHASE_RVR_FILE:
|
|                       data_cleansing_cd in (1, 2)     accept or reject all soft edits
|                       file_usage_cd = 1                               mailing
|                       release_status_cd = 2                   final release
|
|                       When all these conditions are met the file is sent to the
|                       destination.  In other words, two of the three macros that are
|                       part of file release should be called.
|
|
| INPUT:    INIT_ID  = (Default: &INITIATIVE_ID)
|           PHASE_ID = (Default: &PHASE_SEQ_NB)
|
| OUTPUT:   Sets a global autorelease value.
|
+-------------------------------------------------------------------------------
| HISTORY:  09OCT2003 - S.Shariff  - Original.
|           11JUN2004 - John Hou.
|           Added code to reset the data_quality_cd on the files to be released
|           in non-screen-mode:
|              When &data_cleansing cd = 1 (accept all) set data_quality_cd = 1
|              When &data_cleansing_cd = 2 (reject all) set data_quality_cd = 3
|
|
+--------------------------------------------------------------------------------
|             Hercules Version  2.1.01
|             Dec 10 2007 - Carl J Starks
|
|             CHANGED the code so that data_quality_cd was not recoded from 2 to 1 
|             nancy no longer wanted the soft edit codes for the data_quality_cd recoded 
|			 
|  
|
+-----------------------------------------------------------------------HEADER*/


%MACRO autorelease_file(init_id=&initiative_id,
                        phase_id=&phase_seq_nb);
%GLOBAL AUTORELEASE;
%let AUTORELEASE = 0;
%let _NUM_RECORDS = 0;

  %*SASDOC=====================================================================;
  %* update DATA_QUALITY_CD on the file to be released based on the
  %* data_cleansing_cd from &hercules..tphase_rvr_file
  %*====================================================================SASDOC*;
 %if (&DOC_COMPLETE_IN ne 0) %then %do;

     proc sql noprint;
          select count(*) into: c_role_cnt
          from &hercules..tphase_rvr_file
          where initiative_id=&initiative_id;

        create table c_role as
          select cmctn_role_cd, data_cleansing_cd
          from &hercules..tphase_rvr_file
          where initiative_id=&initiative_id; 
    quit;

  data _null;
      set c_role;
      call symput('cmctn_role_cd'||put(_n_,1.),put(cmctn_role_cd,1.));
      call symput('data_cleansing_cd'||put(_n_,1.),put(data_cleansing_cd,1.));
  run;

   /*
       %*SASDOC=======================================================;
       %* c.j.s 12/10/07
       %* deleted the following code so that data_quality_cd was not recoded from 2 to 1 
       %* the folllowin line was taken out of the program
       %*   %if &&data_cleansing_cd&i =1 %then %do
	   %* proc sql;
       %*   update DATA_PND.&TABLE_PREFIX._&&CMCTN_ROLE_CD&i
       %*   set data_quality_cd=1
       %*   where data_quality_cd=2
       %*   quit
       %*   %end
	   %*======================================================SASDOC*;
   */

 
    %do i=1 %to &c_role_cnt;
    
     %if &&data_cleansing_cd&i = 2 %then %do;
       proc sql;
           update DATA_PND.&TABLE_PREFIX._&&CMCTN_ROLE_CD&i
           set data_quality_cd=3
           where data_quality_cd =2;
         quit;
       %end;

   %end;

  %*SASDOC=====================================================================;
  %* SQL creates a macro variable "_NUM_RECORDS". This value determines
  %* if there are any records that match the given criteria.
  %*====================================================================SASDOC*;

        PROC SQL noprint;
        SELECT
                                COUNT (*)
                INTO    :_NUM_RECORDS
        FROM
                                &HERCULES..TPHASE_RVR_FILE A
        WHERE
                                A.INITIATIVE_ID = &INIT_ID
                AND             A.PHASE_SEQ_NB = &PHASE_ID
                AND             DATA_CLEANSING_CD IN (1, 2)
                AND             FILE_USAGE_CD = 1
                AND     RELEASE_STATUS_CD = 2;
        QUIT;

  %*SASDOC=====================================================================;
  %* If _NUM_RECORDS > 0, then set autorelease = 1
  %*====================================================================SASDOC*;
        %if &_NUM_RECORDS = 0 %then %do;
                %let AUTORELEASE = 0;
                %put AUTORELEASE = FALSE;
        %end;

        %if &_NUM_RECORDS > 0 %then %do;
                %let AUTORELEASE = 1;
                %put AUTORELEASE = TRUE;
        %end;

  %end;

%if (&DOC_COMPLETE_IN = 0) %then %do;
        %put AUTORELEASE = FALSE, DOC_COMPLETE_IN = FALSE;
%end;

%MEND autorelease_file;
