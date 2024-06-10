/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  get_member_quality.sas (macro)
|
| LOCATION: /PRG/sasprod1/hercules/macros
|
| PURPOSE:  This macro will set the data quality code to a 4 for 
|           contaminated EDW members
|
| MACRO PARAMETERS:
|
|           initiative_id - initiaitve ID                                     
|
+-------------------------------------------------------------------------------
| HISTORY:  26FEB2009 - Brian Stropich - Hercules Version  2.5.02
|           Original.
|           26JUL2012 - P. Landis - updated to referecne new hercdev2 environment
+-----------------------------------------------------------------------HEADER*/ 

%macro get_member_quality;

	proc sql noprint;
	  select count(*) into: initiative_member_count
	  from QCPAP020.HERCULES_MBR_ID_REUSE
	  where INITIATIVE_ID = &INITIATIVE_ID.;
	quit;

	%put NOTE: initiative_member_count = &initiative_member_count. ;


	/*---------------------------------------------------------*/
	/*  processs initiatives                                   */
	/*---------------------------------------------------------*/
	%if &initiative_member_count. > 0 %then %do;  **start - initiative_member_count;

		proc sql noprint;
		  select distinct(program_id) into: program_id_directory
		  from QCPAP020.HERCULES_MBR_ID_REUSE
		  where INITIATIVE_ID = &INITIATIVE_ID.;
		quit;

		libname _pending "/herc&sysmode/DATA/sastest/hercules/%trim(&program_id_directory.)/pending";
		libname _results "/herc&sysmode/DATA/sastest/hercules/%trim(&program_id_directory.)/results";

		proc sql;
		 create table _pending  as
		 select *
		 from dictionary.members
		 where upcase(libname)='_PENDING'
		   and index(memname,"&INITIATIVE_ID.") > 0;
		run;

		proc sql;
		 create table _results  as
		 select *
		 from dictionary.members
		 where upcase(libname)='_RESULTS'
		   and index(memname,"&INITIATIVE_ID.") > 0;
		run;

		proc sql noprint;
		  select count(*) into: pending_count
		  from _pending;
		quit;

		proc sql noprint;
		  select count(*) into: results_count
		  from _results;
		quit;

		%put NOTE: pending_count = &pending_count. ;
		%put NOTE: results_count = &results_count. ;

		/*---------------------------------------------------------*/
		/*  pending SAS datasets                                   */
		/*---------------------------------------------------------*/
		%if &pending_count. > 0 %then %do; **start - pending_count;

			data _null_;
			  set _pending end=eof;
			   i+1;
			   ii=left(put(i,4.));
			   call symput('pend'||ii,left(trim(memname)));
			   if eof then call symput('pendtotal',ii);
			run;

			%do p = 1 %to &pendtotal. ; **start - pending_total;

				proc contents data= _PENDING.&&pend&p 
				              out = pending (keep = name) 
				              noprint;
				run;

				data pending;
				  set pending;
				  if upcase(name)='DATA_QUALITY_CD';
				run;

				proc sql noprint;
				  select count(*) into: dqc_count
				  from pending;
				quit;

				%put NOTE: dqc_count = &dqc_count. ;

				%if &dqc_count. > 0 %then %do; **start - dqc_count;

					proc sql noprint;
					  create table _temp001 as
					  select PT_BENEFICIARY_ID as RECIPIENT_ID,
					         CDH_BENEFICIARY_ID,
							 MAILING_LEVEL
					  from QCPAP020.HERCULES_MBR_ID_REUSE
					  where INITIATIVE_ID = &INITIATIVE_ID.;
					quit;

					proc sql noprint;
					  select max(MAILING_LEVEL) into: MAILING_LEVEL
					  from _temp001;
					quit;

					%put NOTE: MAILING_LEVEL = &MAILING_LEVEL. ;

					%if &MAILING_LEVEL = 1 %then %do; **start - mailing_level 1;
					  %put NOTE: Mailing Level = 1 - Cardholder Beneficiary ID ;

					  proc sort data = _temp001 nodupkey;
					   by CDH_BENEFICIARY_ID;
					  run;

					  proc sort data = _PENDING.&&pend&p ;
					   by CDH_BENEFICIARY_ID;
					  run;

					  data _PENDING.&&pend&p;
					   merge _PENDING.&&pend&p (in=a)
					         _temp001          (in=b);
					   by CDH_BENEFICIARY_ID;
					   if a;
					   if a and b then do;
					     DATA_QUALITY_CD=4;
					   end;
					  run; 
					%end; **end - mailing_level 1;
					%if &MAILING_LEVEL = 2 %then %do; **start - mailing_level 2;
					  %put NOTE: Mailing Level = 2 - Patient Beneficiary ID ;

					  proc sort data = _temp001 nodupkey;
					   by RECIPIENT_ID;
					  run;

					  proc sort data = _PENDING.&&pend&p ;
					   by RECIPIENT_ID;
					  run;

					  data _PENDING.&&pend&p;
					   merge _PENDING.&&pend&p (in=a)
					         _temp001          (in=b);
					   by RECIPIENT_ID;
					   if a;
					   if a and b then do;
					     DATA_QUALITY_CD=4;
					   end;
					  run;
					%end; **end - mailing_level 2;

				%end;  **end - dqc_count;

			%end; **end - pending_total;

		%end; **end - pending_count;


		/*---------------------------------------------------------*/
		/*  results SAS datasets                                   */
		/*---------------------------------------------------------*/
		%if &results_count. > 0 %then %do; **start - results_count;

			data _null_;
			  set _results end=eof;
			   i+1;
			   ii=left(put(i,4.));
			   call symput('results'||ii,left(trim(memname)));
			   if eof then call symput('resultstotal',ii);
			run;

			%do r = 1 %to &resultstotal. ; **start - results_total;

				proc contents data= _RESULTS.&&results&r 
				              out = results (keep = name) 
				              noprint;
				run;

				data results;
				  set results;
				  if upcase(name)='DATA_QUALITY_CD';
				run;

				proc sql noprint;
				  select count(*) into: dqc_count
				  from results;
				quit;

				%put NOTE: dqc_count = &dqc_count. ;

				%if &dqc_count. > 0 %then %do; **start - dqc_count;

					proc sql noprint;
					  create table _temp001 as
					  select PT_BENEFICIARY_ID as RECIPIENT_ID,
					         CDH_BENEFICIARY_ID,
							 MAILING_LEVEL
					  from QCPAP020.HERCULES_MBR_ID_REUSE
					  where INITIATIVE_ID = &INITIATIVE_ID.;
					quit;

					proc sql noprint;
					  select max(MAILING_LEVEL) into: MAILING_LEVEL
					  from _temp001;
					quit;

					%put NOTE: MAILING_LEVEL = &MAILING_LEVEL. ;

					%if &MAILING_LEVEL = 1 %then %do; **start - mailing_level 1;
					  %put NOTE: Mailing Level = 1 - Cardholder Beneficiary ID ;

					  proc sort data = _temp001 nodupkey;
					   by CDH_BENEFICIARY_ID;
					  run;

					  proc sort data = _RESULTS.&&results&r ;
					   by CDH_BENEFICIARY_ID;
					  run;

					  data _RESULTS.&&results&r;
					   merge _RESULTS.&&results&r (in=a)
					         _temp001             (in=b);
					   by CDH_BENEFICIARY_ID;
					   if a and b then do;
					     DATA_QUALITY_CD=4;
					   end;
					  run; 
					%end; **end - mailing_level 1;
					%if &MAILING_LEVEL = 2 %then %do; **start - mailing_level 2;
					  %put NOTE: Mailing Level = 2 - Patient Beneficiary ID ;

					  proc sort data = _temp001 nodupkey;
					   by RECIPIENT_ID;
					  run;

					  proc sort data = _RESULTS.&&results&r ;
					   by RECIPIENT_ID;
					  run;

					  data _RESULTS.&&results&r;
					   merge _RESULTS.&&results&r (in=a)
					         _temp001             (in=b);
					   by RECIPIENT_ID;
					   if a and b then do;
					     DATA_QUALITY_CD=4;
					   end;
					  run;
					%end; **end - mailing_level 2;

				%end;  **end - dqc_count;

			%end; **end - results_total;

		%end; **end - results_count;

	%end; **end - initiative_member_count;

%mend get_member_quality;
