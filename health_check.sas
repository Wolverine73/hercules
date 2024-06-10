/* stlnt_health updatecomm_health hlth;*/
options mprint mlogic mprintnest mlogicnest symbolgen;
%macro check_log_health(logdir=,hlth=);
%local hlth;
%global &hlth.;
filename stlnt pipe "ls -ltr &logdir";		/*	Macro Var - log directory - 1	*/

data _null_;
length logfl $35.;
infile stlnt truncover end=eof;
input logfl :$59-92;
if eof then do;
call symput('logfl',logfl);								/*	Macro Var, name of the logfile - Ex. stlnt_logfl - 2*/
output;
end;
run;
%put &logfl;
%put "&logdir/%trim(&logfl)";

data check;
length LINE $1000.;
infile "&logdir/%trim(&logfl)" pad truncover;		/*	Use the log directory and log file macro variables in the infile statement*/
input line $1000.;
if index(line,'ERROR:') then output;
run;

proc sql;
select count(*) into: check_count from check;
quit;

data _null_;
%if &check_count>0 
%then %do; call symput("&hlth",'R');%end;
%else %do;
call symput("&hlth",'G');%end;
run;

%put &hlth;

proc sql;drop table check; quit;

%mend check_log_health;



%check_log_health(logdir=%str(/DATA/sasprod1/stellent/logs),hlth=stlnt_health);
%check_log_health(logdir=%str(/hercprod/data/hercules/gen_utilities/sas/update_cmctn),hlth=%str(updatecomm_health));

%put &stlnt_health;
%put &updatecomm_health;


/*All mainframe batch jobs completed without abends*/

/*External feed loads*/

/*Hercules communication engine front end accessible?*/




/*Servers accessible? - prdsas1*/



data abc;
length Check $100. Status $20.;
infile datalines dlm=',' dsd;
input Check $ Status $20.;
Health_status=resolve(Status);
drop status;
datalines;												/*	Use the health status color macro variable here, with the description	*/
Stellent Check, &stlnt_health
Update Communication History SAS Program, &updatecomm_health
;run;




ods html file = "/REPORTS_DOC/prod1/PUB/Project_Hercules/health_checks/health_check_&sysdate9..html" style=egdefault;
proc report data = abc nowd style=[rules=all];
title1 'SITE UNDER CONSTRUCTION';
title2 "Hercules Health Check - &sysdate9.";
define health_status / width=200 "Health Status";				/*		Make this dynamic	*/
compute health_status/ length=200;
		 if health_status='R' then call define(_col_, "style", "style=[background=red foreground=red rules=all]");
	else if health_status='G' then call define(_col_, "style", "style=[background=green foreground=green rules=all]");
	else call define(_col_, "style", "style=[background=white rules=all]");
endcomp;
run;
ods html close;
title1;
title2;
