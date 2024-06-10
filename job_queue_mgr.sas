/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Wednesday, December 01, 2004      TIME: 03:52:24 PM
   PROJECT: hercules_macros
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\Hercules\hercules_macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Friday, June 25, 2004      TIME: 05:42:20 PM
   PROJECT: hercules_macros
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\Hercules\hercules_macros.seg
---------------------------------------- */
%macro JOB_QUEUE_MGR(JOB_START_END);
%local ACTIVE_JOB_FLAG OPT_SETTING EXIST_HERCULES BLK_SBLGN;

%LET ACTIVE_JOB_FLAG =0;
%LET ALREADY_EXECUTING_FLAG =0;

%IF %upcase(&SYSMODE)=PROD %THEN %LET BLK_SBLGN=*;

proc sql noprint;
select trim(left(SETTING))
  into :OPT_SETTING separated by ' '
from   DICTIONARY.OPTIONS
where  OPTNAME IN
          ('MLOGIC', 'MPRINT', 'SYMBOLGEN', 'SOURCE', 'SOURCE2', 'NOTES');
quit;

&BLK_SBLGN options nomlogic nomprint nosymbolgen nonotes nosource nosource2;
%getparms;
&BLK_SBLGN options &OPT_SETTING;

&BLK_SBLGN options mlogic mprint symbolgen notes source source2;

%let EXIST_HERCULES=%sysfunc(libref(&HERCULES));
%if (&EXIST_HERCULES ne 0) %then
%do;
    libname &HERCULES DB2 dsn=&UDBSPRP schema=&HERCULES defer=YES;
%end;

proc sql noprint;
create table WORK.SCHED_TASK as
select  JOBS.INITIATIVE_ID
	   ,JOBS.PHASE_SEQ_NB
	   ,JOBS.JOB_SCHEDULED_TS
	   ,JOBS.PROGRAM_ID
       ,JOBS.TASK_ID
       ,JOBS.TITLE_TX
       ,JOBS.JOB_START_TS
       ,JOBS.JOB_COMPLETE_TS
       ,JOBS.PROGRAM_TASK_TX
       ,JOBQ.QUEUE_NB
       ,&SYSJOBID as PID
from   &HERCULES..VSCHED_INITIATIVES JOBS
	  ,&JOB_QUE..JOB_QUEUE           JOBQ 
where  JOBS.INITIATIVE_ID    = &INITIATIVE_ID
  AND  JOBS.PHASE_SEQ_NB     = &PHASE_SEQ_NB
  AND  JOBQ.INITIATIVE_ID	 = &INITIATIVE_ID	     
  AND  JOBQ.PHASE_SEQ_NB	 = &PHASE_SEQ_NB
  /*	 AK ADDED	*/
/*  AND  JOBQ.JOB_SCHEDULED_TS=INPUT("&JOB_SCHEDULED_TS",DATETIME25.6)*/
  AND  JOBQ.JOB_COMPLETE_TS  IS NULL
  /*	 AK ADDED	*/
/*  AND  JOBS.JOB_SCHEDULED_TS=INPUT("&JOB_SCHEDULED_TS",DATETIME25.6)*/


%if (%upcase(&JOB_START_END) eq %str(S)) %then
%do;
  AND  JOBS.JOB_START_TS    IS NULL
  AND  JOBQ.JOB_START_TS    IS NULL
  AND  JOBS.JOB_COMPLETE_TS is NULL
  AND  JOBQ.DELETED_IN=0
%end;
%else
   %if (%upcase(&JOB_START_END) eq %str(E)) %then
   %do;
  AND  JOBS.JOB_START_TS    is not NULL
  AND  JOBQ.JOB_START_TS    is not NULL
   %end;
;
QUIT;
      %set_error_fl;

PROC SQL NOPRINT;
 SELECT PUT((COUNT(*)=1),1.0) INTO :ACTIVE_JOB_FLAG
 FROM WORK.SCHED_TASK
 ;
QUIT;
		 %set_error_fl;

%IF (&ACTIVE_JOB_FLAG.=1) %THEN
 %DO;
 /*
   filename PS_LST temp lrecl=1024;
   proc sql noprint;
   select trim(XPATH) into :PS_LST
   from   DICTIONARY.EXTFILES
   where  FILEREF eq 'PS_LST';
   quit;

   %PUT PS_SLT=&PS_LST;

   %sysexec ps -u$USER -opid=,ppid=,user=,stat=,start=,time=,etime=,args= > &PS_LST;
  */

    FILENAME PS_LST PIPE "ps -e -opid=,ppid=,user=,stat=,start=,time=,etime=,args=  | grep 'sas ' | grep -i $USER" ;

   DATA WORK.CURR_TASKS
    (keep=PID PPID USER STAT START TIME_DD TIME_HMS ETIME_DD ETIME_HMS ARGS); 
   format PID PPID 8. USER $char8. STAT $1. START datetime19.
          TIME_DD ETIME_DD 2. TIME_HMS ETIME_HMS time8. ARGS $char512.;
  LENGTH PID 8 PPID 8 USER $8 STAT $ 1 T_START $ 10 T_TIME  $ 12 
         T_ETIME $ 12 ARGS $ 512 pos 3 pos1 3 pos2 3 pos3 3;

	INFILE PS_LST LRECL=1000 PAD ;
  *input @1 PID 6.                  @7 PPID 8.                  @15 USER $char9.
         @24 STAT  $1.              @25 T_START $char10.      @35 T_TIME  $char12.
         @47 T_ETIME $char12.     @59  ARGS $char512.;
   INPUT;

PID=SCAN(_INFILE_,1,' ');
PPID=SCAN(_INFILE_,2,' ');
USER=SCAN(_INFILE_,3,' ');
STAT=SCAN(_INFILE_,4,' ');
T_START=SCAN(_INFILE_,5,' ');
T_TIME =SCAN(_INFILE_,6,' ');
T_ETIME=SCAN(_INFILE_,7,' ');
pos1=INDEXW(_INFILE_,TRIM(T_START));
pos2=INDEXW(_INFILE_,TRIM(T_TIME));
pos3=INDEXW(_INFILE_,TRIM(T_ETIME));
pos=MAX(pos1,pos2,pos3)+LENGTH(TRIM(T_ETIME))+1;

ARGS=SUBSTR(_INFILE_,pos);


   if index(T_TIME,'-') then
   do;
      TIME_DD=input(scan(T_TIME,1,'-'),2.);
      TIME_HMS=input(scan(T_TIME,2,'-'),time8.);
    end;
   else
      TIME_HMS=max(0,input(T_TIME,time8.));
   TIME_DD=max(TIME_DD,0);

   if index(T_ETIME,'-') then
   do;
      ETIME_DD=input(scan(T_ETIME,1,'-'),2.);
      ETIME_HMS=input(scan(T_ETIME,2,'-'),time8.);
   end;
   else
   do;
      T_ETIME_HMS=trim(left(T_ETIME));
      if (length(T_ETIME_HMS) eq 8) then
         ETIME_HMS=input(T_ETIME_HMS,time8.);
      else if index(T_ETIME_HMS,':') then
         ETIME_HMS=input(substr('00:00:00',1,8-LENGTH(COMPRESS(T_ETIME_HMS)))|| COMPRESS(T_ETIME_HMS),time8.);
	  else ETIME_HMS=.;
   end;
   ETIME_DD=max(ETIME_DD,0);

   if index(T_START,':') then
      START=input(put(today(),date9.)||' '||put(input(COMPRESS(T_START),time8.),time8.),datetime18.);
   else
      START=.;
   label PID      ='process ID'
         PPID     ='parent process ID'
         USER     ='user name'
         STAT     ='state'
         START    ='start time'
         TIME_DD  ='cumulative CPU time - Days'
         TIME_HMS ='cumulative CPU time - HH:MM:SS'
         ETIME_DD ='elapsed time - Days'
         ETIME_HMS='elapsed time - HH:MM:SS'
         ARGS     ='full command';

		* PUT _ALL_;
	 DROP pos pos1 pos2 pos3;

	RUN;

		/* Check if the previously scheduled job with the same INITIATIVE_ID is currently running.
	       If yes, stop new job from continuing. The old job must be gone before 
		   new job with the same initiative is allowed to run.
	   */

PROC SQL NOPRINT;
 SELECT PUT((COUNT(*)=1),1.0) INTO : ALREADY_EXECUTING_FLAG 
 FROM WORK.CURR_TASKS      CUR,
	  &JOB_QUE..JOB_QUEUE  QUE
  WHERE QUE.INITIATIVE_ID=&INITIATIVE_ID.
    AND QUE.PHASE_SEQ_NB=&PHASE_SEQ_NB.
	AND QUE.PID IS NOT NULL
	AND QUE.PID=CUR.PID
	;
QUIT;
		 %set_error_fl;
  %END;
 		/* Stop the job if it was removed from the &HERCULES..TINITIATIVE_PHASE 
  		  or if the job with the same INITIATIVE_ID is already running. */

%IF (%upcase(&JOB_START_END.) eq %str(S)) 
    AND (&ACTIVE_JOB_FLAG. =0 OR &ALREADY_EXECUTING_FLAG. =1) %THEN	
  %DO;
    %IF &ACTIVE_JOB_FLAG. =0 %THEN
									%DO;
   %put NOTE: The job was initially in the queue but was removed from the table &HERCULES..TINITIATIVE_PHASE after the scheduler started. The job will not run;
            						%END;
   %IF &ALREADY_EXECUTING_FLAG. =1  
									%THEN
											%DO;
   %put NOTE: The job with the same INITIATIVE_ID is already running. The new job will not continue;
            								 %END;

   %put NOTE: PROGRAM_ID      =&PROGRAM_ID;
   %put NOTE: TASK_ID         =&TASK_ID;
   %put NOTE: INITIATIVE_ID   =&INITIATIVE_ID;
   %put NOTE: PHASE_SEQ_NB    =&PHASE_SEQ_NB;
   %put NOTE: JOB_SCHEDULED_TS=&JOB_SCHEDULED_TS;
   ENDSAS;
 %END;

DATA _NULL_;
 SET WORK.CURR_TASKS(WHERE=(PID=&SYSJOBID.));

   JOB_SCHEDULED_TS_DB2=INPUT("&JOB_SCHEDULED_TS",DATETIME25.6);
   call symput('m_PID',right(put(PID,6.)));
   call symput('m_PPID',right(put(PPID,6.)));
   call symput('m_USER',"'"||trim(left(USER))||"'");
   call symput('m_STAT',"'"||STAT||"'");
   call symput('m_START',
      "'"||put(datepart(START),yymmddd10.)||'-'
      ||put(hour(timepart(START)),z2.)
      ||translate(substr(right(put(timepart(START),time15.6)),3,13),'.',':')
      ||"'");
   call symput('m_TIME_DD',put(TIME_DD,2.));
   call symput('m_TIME_HMS',"'"||trim(left(put(TIME_HMS,time8.)))||"'");
   call symput('m_ETIME_DD',put(ETIME_DD,2.));
   call symput('m_ETIME_HMS',"'"||trim(left(put(ETIME_HMS,time8.)))||"'");
   call symput('m_ARGS',"'"||trim(left(ARGS))||"'");
   call symput('JOB_SCHEDULED_TS_DB2',
      "'"||put(datepart(JOB_SCHEDULED_TS_DB2),yymmddd10.)||'-'
      ||put(hour(timepart(JOB_SCHEDULED_TS_DB2)),z2.)
      ||translate(substr(right(put(timepart(JOB_SCHEDULED_TS_DB2),time15.6)),3,13),'.',':')
      ||"'");
   RUN;
		 %set_error_fl;

   proc sql noprint;
   connect to DB2 as DB2(dsn=&UDBSPRP);
   execute
   (
   update &JOB_QUE_SCHEMA..JOB_QUEUE
   set
   %if (%upcase(&JOB_START_END) eq %str(E)) %then
   %do;
        JOB_COMPLETE_TS = CURRENT TIMESTAMP
   %end;
   %else
   %do;
        JOB_START_TS = CURRENT TIMESTAMP
       ,PID       = &m_PID
       ,PPID      = &m_PPID
       ,USER      = &m_USER
       ,START     = TIMESTAMP(&m_START)
       ,ARGS      = &m_args
   %end;
       ,STAT      = &m_STAT
       ,TIME_DD   = &m_TIME_DD
       ,TIME_HMS  = TIME(&m_TIME_HMS)
       ,ETIME_DD  = &m_ETIME_DD
       ,ETIME_HMS = TIME(&m_ETIME_HMS)
   where   INITIATIVE_ID    = &INITIATIVE_ID
      and  PHASE_SEQ_NB     = &PHASE_SEQ_NB
      and JOB_SCHEDULED_TS = TIMESTAMP(&JOB_SCHEDULED_TS_DB2)
   )
   by DB2;
   disconnect from DB2;
   quit;
		 %set_error_fl;

%if (&EXIST_HERCULES ne 0) %then
%do;
    libname &HERCULES clear;
%end;

%mend JOB_QUEUE_MGR;
