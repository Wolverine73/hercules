/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  update_task_ts.sas (macro)
|
|  ************** WARNING: Hardcoded USER variable value at line 67
|  ************** WARNING: Hardcoded USER variable value at line 67
|  ************** WARNING: Hardcoded USER variable value at line 67
|
| LOCATION: /PRG/sastest1/hercules/macros
|
| PURPOSE:  This macro updates either the start or complete datetime stamps
|           of a particular task record in the &hercules..tinitiative_phase
|           table.  This macro is to be called by each program task program
|           to record start and stop datetimes.  The population of these fields
|           affects the tasks eligibility to the Hercules Task Master program.
|
| MACRO PARAMETERS:
|
|           TIMEVAR  = (Required) The datetime variable to update.  Aliases are
|                      allowed.  Valid aliases for JOB_START_TS are: BEGIN and
|                      START.  Valid aliases for JOB_COMPLETE are: END, STOP
|                      and FINISH.
|           INIT_ID  = (Default: &INITIATIVE_ID) The initiative ID.
|           PHASE_ID = (Default: &PHASE_SEQ_NB) The phase sequence number.
|
| INPUT:    Parameter Values.
|
| OUTPUT:   Updates to the &HERCULES..TINITIATIVE_PHASE table/task record.
|
| EXAMPLE USAGE:
|
|   %include '../hercules_in.sas';  *** Needs to be first to parse task parms;
|   %update_task_ts(start);
|   .
|   .
|   .
|   %update_task_ts(stop);
|
+-------------------------------------------------------------------------------
| HISTORY:  01OCT2003 - T.Kalfas  - Original.
|           15OCT2003 - T.Kalfas  - Added updates to the HSU_USR_ID & HSU_TS.
|           01DEC2003 - T.Kalfas  - Removed update to HSU_USR_ID.
| 								  - Hercules Version  2.1.2.01
|           20JUN2012 - P.Landis  - Added logic to assign value to USER when it
|                                   is null/missing and corrected language in WARNING  
|                                   message at bottom from 'where made' to 'were made'
+-----------------------------------------------------------------------HEADER*/
options mprint mprintnest mlogic mlogicnest symbolgen source2;
%macro update_task_ts(timevar,
                      init_id=&initiative_id,
                      phase_id=&phase_seq_nb);
*added options statement to echo submacro processing;
/*options mprint mprintnest mlogic mlogicnest symbolgen source2;*/

  %put ;
  %put Executing hercdev2 version for testing;
  %put Executing hercdev2 version for testing;
  %put Executing hercdev2 version for testing;
  %put ;

  %let timevar=%upcase(&timevar);

  %local _badtimevar;
  %let _badtimevar=0;

  *Assign USER when missing/null;
*  %if &USER=%str() %then %let USER=&sysuserid;		* system user id macro var;
  %global USER;
  %let USER=qcpap020;
  %put &USER;
  
  %*SASDOC=====================================================================;
  %* Validate the parameters.;
  %*====================================================================SASDOC*;
    
  %isnum(init_id, phase_id);
  %isnull(user);

  %if ^%index(%str( JOB_START_TS JOB_COMPLETE_TS START STOP BEGIN END FINISH COMPLETE ),%str( &timevar ))
  %then %let _badtimevar=1;
  %else %do;
            %if %index(%str( JOB_START_TS START BEGIN ), %str( &timevar )) %then 
	           %do;
		           %let timevar=JOB_START_TS;
		           %let initiative_sts_cd = 3;
	           %end;
            %else 
               %do;
		           %let timevar=JOB_COMPLETE_TS;
		           %let initiative_sts_cd = 4;
	           %end;
        %end; *else;

*Check values for if condition below;
%if %length(&user_isnull)=0 %then %let &user_isnull=0;		%* set null values to zero;
%if %length(&isnum)=0 %then %let isnum=0;

%put Check timing variable values for if condition below;
%put Check timing variable values for if condition below;
%put Check timing variable values for if condition below;
%put "Value of isnum macro: &isnum";
%put "&_badtimevar";
%put "&user_isnull";

  %if &isnum=2 and ^&_badtimevar and ^&user_isnull %then 
     %do;
         *SASDOC=================================================================;
         * Make the updates to the appropriate datetime stamp field in the
         * &hercules..tinitiative_phase table...
         *================================================================SASDOC*;
         proc sql noprint;
            update &hercules..tinitiative_phase
               set &timevar   = datetime(),
	               initiative_sts_cd = &initiative_sts_cd.,
                   hsu_ts     = datetime()
             where initiative_id  = &init_id 
               and phase_seq_nb   = &phase_id;
         quit;

         %if &sqlrc %then %put ERROR: (UPDATE_TASK_TS): &sqlmsg;
     %end;
  %else %do;
    %if ^&init_id_isnum  %then %put ERROR: (UPDATE_TASK_TS): Invalid INIT_ID parameter (&init_id).;
    %if ^&phase_id_isnum %then %put ERROR: (UPDATE_TASK_TS): Invalid PHASE_ID parameter (&phase_id).;
    %if &_badtimevar     %then %put ERROR: (UPDATE_TASK_TS): Invalid TIMEVAR parameter (&timevar).;
    %if &user_isnull     %then %put ERROR: (UPDATE_TASK_TS): USER macro variable is null.;
    %put WARNING: (UPDATE_TASK_TS): No updates were made to &hercules..TINITIATIVE_PHASE.;
  %end; %*else;
%mend update_task_ts;
