/*%include '/user1/qcpap020/autoexec_new.sas';*/
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
|           10SEP2009 - N.Williams -  Copy of file_release_wrapper code for releasing
|                                     files in batch mode. Added lines to call
|                                     set_sysmode,hercules_in, update_request_ts. 
|           10MAR2010 - G. Dudley - added new program IDs for EOMS (FORMERLY COE)
|           05APR2010 - N. Williams - added logic for program ID 5246 to place
|                                     certain values in fields for neg frm mailing.
|           27MAY2010 - N. Williams - added EOMS (aka cee,coe) program ID 5356, 5357 
|                                     for selective of the cee_check_docment.
|           05SEP2010 - D. Palmer  -  added PA program id 5371 to EOMS program list
|           15MAR2012 - R Smith 	- Added call to macro to request initiative summary parms report
+-----------------------------------------------------------------------HEADER*/

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

  %*SASDOC=====================================================================;
  %* Call update_request_ts to signal the start of executing file release in batch
  %* 
  %*====================================================================SASDOC*;
  %update_request_ts(start);

    %*SASDOC===================================================================;
    %* Initiate the CHECK DOCUMENT process.  NOTE: Indirect inheritance of the
    %* the following global macro variables occurs:  INITIATIVE_ID,
    %* PHASE_SEQ_NB, CMCTN_ROLE_CD, and DOCUMENT_LOC_CD.  Problems may arise
    %* if these variables are not assigned.
	%* 09Sept2010 D. Palmer - Added program id 5371 for Pharmacy Advisor
	%*==================================================================SASDOC*;

%if (&PROGRAM_ID=5252 or &PROGRAM_ID=5253 or &PROGRAM_ID=5254 or &PROGRAM_ID=5255 or &PROGRAM_ID=5256 or &PROGRAM_ID=5270 or &PROGRAM_ID=5296 or &PROGRAM_ID=5297 or
         &PROGRAM_ID=5349 or &PROGRAM_ID=5350 or &PROGRAM_ID=5351 or &PROGRAM_ID=5352 or &PROGRAM_ID=5353 or &PROGRAM_ID=5354 or &PROGRAM_ID=5355 or &PROGRAM_ID=5356 or 
         &PROGRAM_ID=5357 or &PROGRAM_ID=5371 or &PROGRAM_ID=5368)
    	%then %do;
	   		%cee_check_document;
%end;
%else %if (&PROGRAM_ID=5369)  %then %do;
	   		%abpd_check_document;
%end;
/*		programs were out of scope for add base columns*/
/*		and use old chaeck_document without additional columns*/

/*	AK - Changed it back to check_document from check_document_prod since release is working due to an earlier fix
	03MAR2013	*/
%else %if (&PROGRAM_ID=123 or &PROGRAM_ID=5259 or &PROGRAM_ID=5246)
		%then %do;
			%check_document; 
%end;
%else %if &program_id ne 72 and &program_id ne 5295 %then %do;
			%check_document;
%end;

/*%end; */


    %*SASDOC===================================================================;
    %* Initiate the COMPLETE DATA CLEANSING process.
    %*==================================================================SASDOC*;

    %complete_data_cleansing(init_id=&init_id, phase_id=&phase_id, com_cd=&com_cd);


    %*SASDOC===================================================================;
    %* Initiate the RELEASE DATA process.
    %*==================================================================SASDOC*;

    %release_data(init_id=&init_id, phase_id=&phase_id, com_cd=&com_cd);

  %*SASDOC=====================================================================;
  %* Call update_request_ts to signal the start of executing file release in batch
  %* 
  %*====================================================================SASDOC*;
%update_request_ts(complete);
  
  %*SASDOC=====================================================================;
  %* Redirect the log output back to its default.
  %*====================================================================SASDOC*;

  %put NOTE: (&SYSMACRONAME): Re-routing log output back to default.;

  proc printto;
  run;

%mend file_release_wrapper;


%set_sysmode;
options mprint mlogic;
/*options fullstimer mprint mlogic symbolgen source2 mprintnest mlogicnest;*/
/*options sysparm='INITIATIVE_ID=14832 PHASE_SEQ_NB=1 REQUEST_ID=8313 REPORT_ID=999 DOCUMENT_LOC_CD=1 CMCTN_ROLE_CD=2 HSC_USR_ID=QCPI208';*/
%INCLUDE "/herc&sysmode/prg/hercules/hercules_in.sas";
%file_release_wrapper;


*SASDOC-------------------------------------------------------------------------
| Request Initiative Summary Parm Report
|   - Request_Initiative_Summary_Parm macro updates/inserts Report Request Row
|   - Hercules Task Master will see request and will run Initiative_Summary_parm job
|
| 	08March2012 R. Smith - Added call to new macro
+-----------------------------------------------------------------------SASDOC*;
%REQUEST_INITIATIVE_SUMMARY_PARM(INITIATIVE_ID=&INITIATIVE_ID.);
