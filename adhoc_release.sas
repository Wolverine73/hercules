/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Monday, November 14, 2005      TIME: 05:25:25 PM
   PROJECT: Project
   PROJECT PATH: 
---------------------------------------- */

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
|
+-----------------------------------------------------------------------HEADER*/

%macro file_release_wrapper(init_id=&initiative_id,
                            phase_id=&phase_seq_nb,
                            com_cd=&cmctn_role_cd,
                            doc_cd=&document_loc_cd,
                            dbg_flg=1);

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
    %*==================================================================SASDOC*;

    %check_document;

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

 %LET err_fl=0;
 %set_sysmode(mode=prod);
 * %LET DEBUG_FLAG=Y;
 * OPTIONS MLOGIC MPRINT SYMBOLGEN;
  *OPTIONS SYSPARM='INITIATIVE_ID=640 PHASE_SEQ_NB=1';
 %INCLUDE "/PRG/sas&sysmode.1/hercules/hercules_in.sas";

   %file_release_wrapper(init_id=&initiative_id,
                            phase_id=&phase_seq_nb,
                            com_cd=1,
                            doc_cd=&document_loc_cd,
                            dbg_flg=0);

    quit;
