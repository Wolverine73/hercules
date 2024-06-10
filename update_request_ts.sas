%macro update_request_ts(TIMEVAR, REQUEST_ID=);
%*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  update_request_ts.sas (macro)
|
| LOCATION: /PRG/sas(&SYSMODE)1/hercules/macros
|
| PURPOSE:  This macro updates either the JOB_START_TS or JOB_COMPLETE_TS
|           datetime stamp of a row in the &HERCULES..TREPORT_REQUEST table.
|           The HSU_USR_ID and HSU_TS columns are also updated.
|
| MACRO PARAMETERS:
|
|           TIMEVAR     = (Required) The datetime variable to update.
|                         Valid values are START and COMPLETE.
|           REQUEST_ID  = (Default: &REQUEST_ID) The request ID.
|                         If the REQUEST_ID parameter is missing, then
|                         the global macro variable value REQUEST_ID is used.
|
| INPUT:    Parameter Values.
|
| OUTPUT:   Updates to the &HERCULES..TREPORT_REQUEST table/request record.
|
| EXAMPLE USAGE:
|
|   %update_request_ts(start)
|   .
|   .
|   .
|   %update_request_ts(complete)
|   %update_request_ts(start,REQUEST_ID=99)
+-------------------------------------------------------------------------------
| HISTORY:  20MAY2004 - L.Kummen  - Original - after T.KALFAS (update_task_ts).
+-----------------------------------------------------------------------HEADER*;

%local LOCAL_REQUEST_ID _BADTIMEVAR _N_REQUEST_ID _ISNUM_REQUEST_ID _ISNUL_REQUEST_ID;
%let TIMEVAR=%upcase(&TIMEVAR);
%let _BADTIMEVAR=0;

%*SASDOC-----------------------------------------------------------------------
| Select local or global value of REQUEST_ID.
+----------------------------------------------------------------------SASDOC*;
proc sql noprint;
select trim(left(put((count(*) eq 1),8.)))
  into :LOCAL_REQUEST_ID
from DICTIONARY.MACROS
where  substr(SCOPE,1,9) eq substr("&SYSMACRONAME",1,9)
   and NAME  eq 'REQUEST_ID'
   and VALUE ne '';

%if ^&LOCAL_REQUEST_ID %then
%do;
   select trim(left(VALUE))
     into :REQUEST_ID
   from DICTIONARY.MACROS
   where  SCOPE eq 'GLOBAL'
   and    NAME  eq 'REQUEST_ID';
%end;
quit;

%*SASDOC-----------------------------------------------------------------------
| Validate input parameters.
+----------------------------------------------------------------------SASDOC*;
%let _ISNUM_REQUEST_ID=%eval(%datatyp(&REQUEST_ID)=NUMERIC);
%let _ISNUL_REQUEST_ID=%eval(&REQUEST_ID=%str());

%if ^%index(%str(START COMPLETE),%str(&TIMEVAR)) %then
   %let _BADTIMEVAR=1;
%else
%do;
   %if %index(%str(START),%str(&TIMEVAR)) %then
      %let TIMEVAR=JOB_START_TS;
   %else
      %let TIMEVAR=JOB_COMPLETE_TS;
%end;

%if ((&_ISNUM_REQUEST_ID) and (^&_BADTIMEVAR) and (^&_ISNUL_REQUEST_ID)) %then
%do;
   proc sql noprint;
   select trim(left(put((count(*) eq 1),8.))) into :_N_REQUEST_ID
   from   &HERCULES..TREPORT_REQUEST
   where  REQUEST_ID eq &REQUEST_ID;

   %if (&_N_REQUEST_ID eq 1) %then
   %do;
%*SASDOC-----------------------------------------------------------------------
| Update the appropriate datetime stamp field in the
| &HERCULES..TREPORT_REQUEST table.
+----------------------------------------------------------------------SASDOC*;
      update &HERCULES..TREPORT_REQUEST
         set  &TIMEVAR   = datetime()
             ,HSU_USR_ID = upcase("&SYSUSERID")
             ,HSU_TS     = datetime()
      where   REQUEST_ID eq &REQUEST_ID;
      %if &SQLRC %then
         %put ERROR: (UPDATE_TASK_TS): &sqlmsg;
   %end;
   %else
      %if (&_N_REQUEST_ID eq 0) %then
         %put ERROR: (UPDATE_REQUEST_TS): REQUEST_ID (&REQUEST_ID) not found in &HERCULES..TREPORT_REQUEST.;
      %else
         %put ERROR: (UPDATE_REQUEST_TS): REQUEST_ID (&REQUEST_ID) more than one row found in &HERCULES..TREPORT_REQUEST.;
   quit;
%end;
%else
%do;
   %if &_ISNUL_REQUEST_ID  %then %put ERROR: (UPDATE_REQUEST_TS): null REQUEST_ID parameter (&REQUEST_ID).;
   %if ^&_ISNUM_REQUEST_ID %then %put ERROR: (UPDATE_REQUEST_TS): non-numeric REQUEST_ID parameter (&REQUEST_ID).;
   %if &_BADTIMEVAR        %then %put ERROR: (UPDATE_REQUEST_TS): Invalid TIMEVAR parameter (&TIMEVAR).;
%end;
%if ((^&_ISNUM_REQUEST_ID) or (&_BADTIMEVAR) or (&_ISNUL_REQUEST_ID) or (&_N_REQUEST_ID ne 1)) %then
   %put WARNING: (UPDATE_TASK_TS): No updates where made to &HERCULES..TREPORT_REQUEST.;
%mend update_request_ts;
