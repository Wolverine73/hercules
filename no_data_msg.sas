
%MACRO NO_DATA_MSG(DS);
OPTIONS SPOOL;
proc sql noprint;
select nobs into :OBS_COUNT from dictionary.tables		/* OBS_COUNT macro variable stores number of observations */
where trim(libname)||"."||"%upcase(&DS)";				
quit;

%if &OBS_COUNT = 0 %then %do;
data _null_;
file print notitles;
put "No data available in the dataset WORK.&DS" ;			/* Print message if &OBS_COUNT = 0 */
stop;
run;
%end;

%put DS = &DS.;
%put obs_count = &obs_count;	/* Only if OBS_COUNT = 0 then this will print the above message */

%mend;
