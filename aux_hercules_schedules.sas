
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  aux_hercules_schedules.sas
|
| LOCATION: /PRG/sastest1/hercules/gen_utilities/sas
|
| PURPOSE:  Set all the times for Retail to Mail, Proactive Refill, Retail DAW,
|           Retail TIP mailings.  Insert batch scheduling information into the
|           SAS scheduling dataset-HERCULES_SCHEDULES. The program runs every
|           morning within the insert_scheduled_initiative.sas.
|
| LOGIC:    The program flows as follows:
|
|           Get scheduled jobs  ---> 
|           Assign new times    --->
|           Update SAS datasets 
|
| INPUT:    HERCULES_SCHEDULES
|
| OUTPUT:   HERCULES_SCHEDULES
|
+--------------------------------------------------------------------------------
| HISTORY: JUN 2003  - Original.
|          JAN 2007  - B. Stropich - created DetermineMonthWeek macro which is logic
|                      to determine if today is the second Monday of the month and
|                      whether to schedule the Retail to Mail process in the HCE.
|
+------------------------------------------------------------------------HEADER*/

libname AUX "/herc&sysmode/data/hercules/auxtables";


*SASDOC-------------------------------------------------------------------------
|  The DetermineMonthWeek macro is logic that determines if today is the second
|  Monday of the month and whether to schedule the Retail to Mail process in the
|  HCE.  The values returned from the macro are monthweek and adhoc_flag.  The
|  value are then used in scedule query below to turn on or off the mailing.
+-----------------------------------------------------------------------SASDOC*;

%macro DetermineMonthWeek;

   %global ADHOC_FLAG ARC_FLAG GE_FLAG CPS_FLAG MONTHDAY;
   
   ** determine day of the week and the month ;
   DATA _NULL_;
     CALL SYMPUT('MONTHDAY', "'"||put(day(date()),Z2.)||"'");
     CALL SYMPUT('_DAY', put(day(date()),Z2.));
     CALL SYMPUT('WEEKKDAY', put(weekday(date()),1.));
   RUN;

   DATA _NULL_;
    FORMAT WEEKKDAY $20. ;
    IF &WEEKKDAY = 1 THEN WEEKKDAY='SUNDAY';
	ELSE IF &WEEKKDAY = 2 THEN WEEKKDAY='MONDAY';
	ELSE IF &WEEKKDAY = 3 THEN WEEKKDAY='TUESDAY';
	ELSE IF &WEEKKDAY = 4 THEN WEEKKDAY='WEDNESDAY';
	ELSE IF &WEEKKDAY = 5 THEN WEEKKDAY='THURSDAY';
	ELSE IF &WEEKKDAY = 6 THEN WEEKKDAY='FRIDAY';
	ELSE IF &WEEKKDAY = 7 THEN WEEKKDAY='SATURDAY';
	CALL SYMPUT('WEEKKDAYNAME', LEFT(WEEKKDAY));
   RUN;
 
   ** determine the week of the month ;
   DATA _NULL_;
     MONTHWEEK = ceil (&_DAY / 7 ) ;   
     CALL SYMPUT('MONTHWEEK', left(MONTHWEEK));
   RUN;
   
   ** set the adhoc flag based to turn on or off the mailing ;
   %if &MONTHWEEK = 2 and &WEEKKDAY = 2 %then %do; 
     %let ADHOC_FLAG=-1;  ** 0 turns on mailing ;
   %end;
   %else %do;
     %let ADHOC_FLAG=-1; ** -1 turns off mailing ;
   %end;
   
   ** set the arc adhoc flag based to turn on or off the mailing ;
   %if &MONTHWEEK = 2 and &WEEKKDAY = 3 %then %do; 
     %let ARC_FLAG=0;  ** 0 turns on mailing ;
   %end;
   %else %do;
     %let ARC_FLAG=-1; ** -1 turns off mailing ;
   %end;
   
   ** set the health alert ge adhoc flag based to turn on or off the mailing ;
   %if &MONTHWEEK = 2 and &WEEKKDAY = 4 %then %do; 
     %let GE_FLAG=0;  ** 0 turns on mailing ;
   %end;
   %else %do;
     %let GE_FLAG=-1; ** -1 turns off mailing ;
   %end;
   
   ** set the health alert cps adhoc flag based to turn on or off the mailing ;
   %if &MONTHWEEK = 2 and &WEEKKDAY = 4 %then %do; 
     %let CPS_FLAG=-1;  ** 0 turns on mailing ;
   %end;
   %else %do;
     %let CPS_FLAG=-1; ** -1 turns off mailing ;
   %end;
   
   %put NOTE: MONTHDAY=&MONTHDAY;
   %put NOTE: MONTHWEEK=&MONTHWEEK;
   %put NOTE: WEEKKDAY=&WEEKKDAY - &WEEKKDAYNAME.;
   %put NOTE: ADHOC_FLAG=&ADHOC_FLAG;
   %put NOTE: ARC_FLAG=&ARC_FLAG;
   %put NOTE: GE_FLAG=&GE_FLAG;
   %put NOTE: CPS_FLAG=&CPS_FLAG;

%mend DetermineMonthWeek;

%DetermineMonthWeek;


*SASDOC-------------------------------------------------------------------------
|  The schedule query which initiates all the times for retail to mail, proactive
|  refill, and retail daw.  These values are saved in the aux.hercules_schedules
|  dataset and used in the insert_scheduled_intiative to determine what mailings
|  will be scheduled for todays run.                                        
+-----------------------------------------------------------------------SASDOC*;

proc sql;
   ********************
   ** RETAIL TO MAIL **
   ********************;
   update AUX.hercules_program_schedules
     set day = &MONTHDAY.,
        hour = '20',
   	 minute='0',
   	 adhoc_flag=&ADHOC_FLAG.
     where PROGRAM_ID = 73
     and task_id = 5     
   ;
   ********************
   ** IBENEFIT ARC   **
   ********************;
   update AUX.hercules_program_schedules
     set day = &MONTHDAY.,
        hour = '20',
   	 minute='0',
   	 adhoc_flag=&ARC_FLAG.
     where PROGRAM_ID = 5259
     and task_id = 31
     and upcase(description) = 'ARC'
     and client_id > 0
   ;
   ***********************
   ** HEALTH ALERT GE   **
   ***********************;
   update AUX.hercules_program_schedules
     set day = &MONTHDAY.,
        hour = '20',
   	 minute='0',
   	 adhoc_flag=&GE_FLAG.
     where PROGRAM_ID = 5286
     and task_id = 33
     and client_id = 20441
   ;
   ***********************
   ** HEALTH ALERT CPS  **
   ***********************;
   update AUX.hercules_program_schedules
     set day = &MONTHDAY.,
        hour = '20',
   	 minute='0',
   	 adhoc_flag=&CPS_FLAG.
     where PROGRAM_ID = 5286
     and task_id = 33
     and client_id = 13425
   ;
   **********************
   ** PROACTIVE REFILL **
   **********************;
   update AUX.hercules_program_schedules
     set day = '01,15',
        hour = '20',
   	 minute='0',
   	 adhoc_flag=0
     where PROGRAM_ID = 72
     and task_id = 14
   ;
   ****************
   ** RETAIL DAW **
   ****************;
   update AUX.hercules_program_schedules
     set month='*',
        day = '*',
        hour = '20',
   	 minute='0',
   	 day_of_week='2',
   	 adhoc_flag=0
     where PROGRAM_ID = 123
     and task_id = 16
   ;
   ****************
   ** RETAIL TIP **
   ****************;
   update AUX.hercules_program_schedules
     set day = '16',
        hour = '22',
   	 minute='0',
   	 adhoc_flag=-1
     where PROGRAM_ID = 86
     and task_id = 15
   ;
quit;

proc print data=AUX.hercules_program_schedules;
run;
