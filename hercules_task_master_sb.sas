%include '/user1/qcpap020/autoexec_new.sas';

/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  hercules_task_master.sas
|
| LOCATION: /PRG/sas(%SYSMODE)1/hercules/gen_utilities/sas
|
| PURPOSE:  This program manages the contents of the Hercules Job Queue.
|
| LOGIC:    The program flows as follows:
|
|           (1) Identify all outstanding initiatives (sched time is not null and start time is null).
|           (2) Of these, determine which initiatives have not already been scheduled.
|           (3) Set DELETED_IN in JOB QUEUE table for jobs that were not selected in the step 1.
|           (4) Physically delete old records from JOB_QUEUE((TODAY()- &NUMB_MONTHS_KEEP)) .
|           (5) Submit jobs (from #2). This is done by first creating a temporary script file for each queue
|			    that has commands for submitting as jobs one after another.  Below is an example of such 
|			    script file for the regular QUEUE_NB=1; The script file for batch QUEUE_NB=4 has a similar
|				structure to the regular queue but with & added at the end of each sas command. The latter 
|				insures that the next command in the script executes immediately rather then wait for the previous command to complete. 
|
|			/DATA/sas%lowcase(&SYSMODE)1/hercules/gen_utilities/job_queue/queue/queue_1.scr:
-------------------------------------------------------------------------------------------
cat /PRG/sastest1/hercules/gen_utilities/sas/job_queue_mgr_start.sas \
/PRG/sastest1/hercules/106/eligibility_tasks.sas \
/PRG/sastest1/hercules/gen_utilities/sas/job_queue_mgr_end.sas \
>/DATA/sastest1/hercules/gen_utilities/job_queue/job_queue_mgr_tmp_fl_1_tmp.sas
sas -sysin /DATA/sastest1/hercules/gen_utilities/job_queue/job_queue_mgr_tmp_fl_1_tmp.sas \
-log /DATA/sastest1/hercules/106/logs/t_1094_1_task.log \
-sysparm '~PROGRAM_ID=106~TASK_ID=8~INITIATIVE_ID=1094~PHASE_SEQ_NB=1~JOB_SCHEDULED_TS=09JUN2004:09:18:00.000000~QUEUE_NB=1' \
-noterminal
rm -f /DATA/sastest1/hercules/gen_utilities/job_queue/job_queue_mgr_tmp_fl_1_tmp.sas
---------------------------------------------------------------------------------------------------
|		    The cat command in the above script sandwiches actual program between the statement
|		   	%job_queue_mgr(S) and %job_queue_mgr(E). The primarily function of the macro %job_queue_mgr(S)
|		    is to check one more time if job has to be run. If job was canceled then the macro stop 
|		    issues ENDSAS statement and the actual program do not execute. The macro also checks if
|			if there is already a job with the same INITIATIVE_ID and PHASE_SEQ_NB running. If such jobs
|		    exists then new jobs will not be submitted. This means that the old jobs must either complete
|		    or to be killed by administrator before the new job with the same INITIATIVE_ID and PHASE_SEQ_NB
|			is submitted. The macro %job_queue_mgr also updates the information in the queue table JOB_QUE_&SYSMODE..JOB_QUE.
|			The latter information is used in job queue managing 	and auditing.
|
| ASSUMPTIONS:
|
|           (1) When task records exist in the JOB_QUEUE dataset but
|               not in TINITIATIVE_PHASE, they are assumed to be job
|               cancellations or rescheduled tasks and are processed as such.
|
| INPUT:    &HERCULES..TINITIATE_PHASE  - contains tasks to be queued.
|           &HERCULES..TINITIAVE        - contains TASK_ID necessary for join
|                                         to TPROGRAM_TASK.
|           &HERCULES..TPROGRAM_TASK    - contains task program name/location.
|           JOB_QUE.JOB_QUEUE           - "Hercules Job Queue" - a record of
|                                         task programs submitted for execution.
|
| OUTPUT:   "batch" jobs      - submissions of Hercules Task Programs.
|           JOB_QUE.JOB_QUEUE - an updated status of the "Hercules Job Queue".
|
+--------------------------------------------------------------------------------
| HISTORY:  14APR2003 - L.Kummen  - Original after T.Kalfas hercules_task_master
|           9JUN2004 - Y. Vilk
|          03FEN2006 - G. DUDLEY  - Added logic to prevent duplicates records
|                                   being inserted into JOB_QUE.JOB_QUEUE. This
|                                   would cause an abend of the job.
|          03FEN2006 - G. DUDLEY  - Added Proc report of duplicate task not
|									loaded and the new task that will be loaded.
|          10SEP2009 - N. WILLIAMS - Added logic for file release in batch.
|          23FEB2012 - S. BILETSKY - Added logic for running Initiative Summary reports
|									and Delete Initiative in batch. see QCPI208
|	
+------------------------------------------------------------------------HEADER*/

%macro GETTASKS;
%local DSID
       VAREXIST
       RC
       NEWOBS
       DELOBS
	   SCHEDOBS
	   MESSAGE_FOR_GETTASKS;
%*SASDOC-----------------------------------------------------------------------
| &JOB_SCHED_VAR is the number of minutes past JOB_SCHEDULES_TS that a job
| will be put into the batch (4) queue , provided, it has not been already scheduled
| in the regular (sequential) queue.
| &NUMB_MONTHS_KEEP is number that the data in JOB_QUEUE are kept.
+----------------------------------------------------------------------SASDOC*;

%LET err_fl=0;
%LET JOB_SCHED_VAR=2;
%LET NUMB_MONTHS_KEEP=3;
%LET DELOBS=0;
%LET SCHEDOBS=0;

%LET Q_SCRIPT=/herc%lowcase(&SYSMODE)/data/hercules/gen_utilities/job_queue/queue;
LIBNAME ADM_LKP "/herc&sysmode./data/Admin/auxtable";

PROC SQL NOPRINT;
  SELECT QUOTE(TRIM(EMAIL)) INTO :EMAIL_IT SEPARATED BY ' '
    FROM   ADM_LKP.ANALYTICS_USERS
    WHERE  UPCASE(QCP_ID) = "&USER";
 QUIT;

 DATA _NULL_;
  DATE_C=PUT(TODAY(),DOWNAME3.) || PUT(HOUR(TIME()),z2.) || PUT(MINUTE(TIME()),z2.);
  CALL SYMPUT('DATE_C',COMPRESS(DATE_C));
 RUN;

 %PUT DATE_C=&DATE_C;

%*SASDOC-----------------------------------------------------------------------
| Get all scheduled tasks from TINITIATIVE_PHASE where the JOB_START_TS is
| greater or equal to the current time, and have not completed.
|  10SEP2009 - N. WILLIAMS - Replaced HERCULES.VSCHED_INITIATIVES with the SQL
|  code from that view and added additional fields I needed selected.
|  Add sql code to remove file release initiatives from job_queue table so
|  we can schedule them.
|	23FEB2012 - S.Biletsky - Added 
+----------------------------------------------------------------------SASDOC*;
PROC SQL NOPRINT;
   DELETE FROM  JOB_QUE.JOB_QUEUE
   WHERE  PROGRAM_ID IN (999,998,997); * QCPI208 - added 998 and 997;
QUIT;
%reset_sql_err_cd;

*QCPI208 - added HCS_USR_ID to the query for 998 and 997; 
PROC SQL ;
CONNECT TO DB2 AS DB2(DSN=&UDBSPRP); 
 CREATE TABLE WORK.VSCHED_INITS AS
 select * from connection to db2 (
(SELECT INIT.INITIATIVE_ID ,
JOBS.PHASE_SEQ_NB ,
INIT.PROGRAM_ID ,
INIT.TASK_ID ,
INIT.TITLE_TX ,
JOBS.JOB_SCHEDULED_TS ,
JOBS.JOB_START_TS ,
JOBS.JOB_COMPLETE_TS ,
TASK.PROGRAM_TASK_TX ,
TASK.QUEUE_NB as ORG_QUEUE_NB ,
TASK.QUEUE_NB as QUEUE_NB,
TASK.QUEUE_NB as PARMTR_ID1,
TASK.QUEUE_NB as PARMTR_ID2,
JOBS.HSC_USR_ID as HSC_USR_ID
FROM HERCULES.TINITIATIVE_PHASE JOBS ,
HERCULES.TINITIATIVE INIT ,
HERCULES.TPROGRAM_TASK TASK
WHERE JOBS.JOB_SCHEDULED_TS IS NOT NULL 
AND JOBS.JOB_SCHEDULED_TS <= CURRENT TIMESTAMP 
AND JOBS.JOB_START_TS IS NULL 
AND JOBS.JOB_COMPLETE_TS IS NULL 
AND JOBS.INITIATIVE_ID = INIT.INITIATIVE_ID 
AND INIT.PROGRAM_ID = TASK.PROGRAM_ID 
AND INIT.TASK_ID = TASK.TASK_ID) 
UNION 
(SELECT REQ.REQUEST_ID AS INITIATIVE_ID ,
1 AS PHASE_SEQ_NB ,
REQ.REPORT_ID AS PROGRAM_ID ,
REQ.REPORT_ID  AS TASK_ID ,
RPT.RPT_DISPLAY_NM AS TITLE_TX ,
REQ.JOB_REQUESTED_TS AS JOB_SCHEDULED_TS ,
REQ.JOB_START_TS ,
REQ.JOB_COMPLETE_TS ,
RPT.SAS_PROGRAM_TX AS PROGRAM_TASK_TX ,
RPT.QUEUE_NB AS ORG_QUEUE_NB ,
RPT.QUEUE_NB AS  QUEUE_NB,
REQ.REQUIRED_PARMTR_ID AS PARMTR_ID1,
REQ.SEC_REQD_PARMTR_ID AS PARMTR_ID2,
REQ.HSC_USR_ID AS HSC_USR_ID
FROM HERCULES.TREPORT RPT, 
HERCULES.TREPORT_REQUEST REQ 
WHERE RPT.REPORT_ID=REQ.REPORT_ID 
AND REQ.JOB_REQUESTED_TS IS NOT NULL 
AND REQ.JOB_REQUESTED_TS <= CURRENT TIMESTAMP 
AND REQ.JOB_START_TS IS NULL 
AND REQ.JOB_COMPLETE_TS IS NULL      )
        );

DISCONNECT FROM DB2;
%PUT &SQLXRC &SQLXMSG;
QUIT;
%set_error_fl2; 

* QCPI208 - added HCS_USR_ID to the query for 998 and 997; 
PROC SQL NOPRINT;
   CREATE TABLE WORK.SCHED_TASKS AS
   SELECT  JOBS.INITIATIVE_ID
   		  ,JOBS.PHASE_SEQ_NB
		  ,JOBS.JOB_SCHEDULED_TS
		  ,JOBS.PROGRAM_ID
          ,JOBS.TASK_ID
          ,JOBS.TITLE_TX
          ,JOBS.JOB_START_TS
          ,JOBS.JOB_COMPLETE_TS
          ,JOBS.PROGRAM_TASK_TX
          ,JOBS.QUEUE_NB as ORG_QUEUE_NB
		  ,JOBS.QUEUE_NB as QUEUE_NB
		  ,JOBS.PARMTR_ID1
		  ,JOBS.PARMTR_ID2
		  ,JOBS.HSC_USR_ID
		FROM   WORK.VSCHED_INITS JOBS
		     WHERE  JOBS.JOB_START_TS     IS MISSING
               AND  JOBS.JOB_COMPLETE_TS  IS MISSING  
		;
 QUIT;
  		 %set_error_fl2;

%*SASDOC-----------------------------------------------------------------------
| Set the parameters for error checking.
| Filter out initiatives that have already been queued. initiative entries whose
| scheduled time and/or queue assignments have changed, are considered
| to be "new" entries.
| 1) Create a table of scheduled initiatives already in job queue.
| 2) Create a table of scheduled initiatives not in job queue.
| 3) Create a table of queued initiatives not in scheduled initiatives.
| 4) Delete scheduled initiatives already in job queue.
| 5) Delete queued initiatives not in scheduled initiatives.
+----------------------------------------------------------------------SASDOC*;

proc sql noprint;
create table WORK.SCHED_TASKS_NOT_QUEUED as
select *
from WORK.SCHED_TASKS SCHED
where not exists (select *
                  from   JOB_QUE.JOB_QUEUE JOBQ
                  where  SCHED.INITIATIVE_ID    = JOBQ.INITIATIVE_ID
                     and SCHED.PHASE_SEQ_NB     = JOBQ.PHASE_SEQ_NB
                     and SCHED.JOB_SCHEDULED_TS = JOBQ.JOB_SCHEDULED_TS
					 AND JOBQ.DELETED_IN=0
				);
QUIT;
 %set_error_fl2;

%*SASDOC-----------------------------------------------------------------------
| Identify initiatives that should be cancelled. These entries exist in the
| Hercules Job Queue (JOB_QUE.JOB_QUEUE), but have been removed from
| TINITIATIVE_PHASE (by users).
|
| NOTE: initiatives whose scheduled times entries have been
|       changed are considered "new" entries.  The revised initiative entries
|       in TINITIATIVE_PHASE result in new queue entries, but also in
|       orphaned queue entries.  The orphaned initiative entries/jobs will be
|       cancelled and removed from the job queue.
+----------------------------------------------------------------------SASDOC*;

PROC SQL NOPRINT;
CREATE TABLE WORK.QUEUED_TASKS_NOT_SCHED AS
SELECT *
FROM   JOB_QUE.JOB_QUEUE JOBQ
WHERE  NOT EXISTS (SELECT *
                    FROM   WORK.SCHED_TASKS SCHED
                    WHERE SCHED.INITIATIVE_ID    = JOBQ.INITIATIVE_ID
                       AND SCHED.PHASE_SEQ_NB     = JOBQ.PHASE_SEQ_NB
                       AND SCHED.JOB_SCHEDULED_TS = JOBQ.JOB_SCHEDULED_TS
					)
 AND JOBQ.DELETED_IN=0
;

SELECT COUNT(*) INTO :DELOBS
FROM   WORK.QUEUED_TASKS_NOT_SCHED;
QUIT;

 %set_error_fl2;

 %IF &err_fl=1 %THEN %GOTO EXIT_GETTASKS;
%if (&DELOBS gt 0) %then
%do;

%*SASDOC-----------------------------------------------------------------------
| delete jobs in job_que.job_queue that have been deleted from
| TINITIATIVE_PHASE.
+----------------------------------------------------------------------SASDOC*;

 

  PROC SQL NOPRINT;
   UPDATE  JOB_QUE.JOB_QUEUE  JOBQ
    SET DELETED_IN=1
   WHERE EXISTS (SELECT *
                 FROM  WORK.QUEUED_TASKS_NOT_SCHED QUEUED_NOT_SCHED
                 WHERE QUEUED_NOT_SCHED.INITIATIVE_ID    = JOBQ.INITIATIVE_ID
                   AND QUEUED_NOT_SCHED.PHASE_SEQ_NB     = JOBQ.PHASE_SEQ_NB
                   AND QUEUED_NOT_SCHED.JOB_SCHEDULED_TS = JOBQ.JOB_SCHEDULED_TS)
			;
   DELETE
   FROM   JOB_QUE.JOB_QUEUE  JOBQ
   WHERE DELETED_IN=1
	AND JOBQ.JOB_SCHEDULED_TS < DATETIME()-&NUMB_MONTHS_KEEP.*30*24*3600
	      ;
QUIT;
 %set_error_fl2;
%end;



PROC SQL NOPRINT;
SELECT COUNT(*) INTO :SCHEDOBS
FROM   WORK.SCHED_TASKS_NOT_QUEUED
WHERE  PROGRAM_TASK_TX IS NOT NULL;
QUIT;
 %set_error_fl2;
%PUT SCHED_JOBS=&SCHEDOBS;
%IF (&SCHEDOBS.= 0) %THEN %LET MESSAGE_FOR_GETTASKS=HCE SUPPORT: NO JOBS WERE SCHEDULED ;
%IF (&SCHEDOBS.= 0) %THEN %GOTO EXIT_GETTASKS;

PROC PRINTTO NEW 
   LOG="/herc%lowcase(&SYSMODE.)/data/hercules/gen_utilities/job_queue/logs/hercules_task_master.&DATE_C.saslog";
RUN;

%*** &PRE is used to shorten the ERROR/WARNING/NOTE messages output to the log.  ;
%let pre=%str('(HERCULES_TASK_MASTER): [PROGRAM ID: ' program_id +(-1) '; INITIATIVE ID: ')
         %str(initiative_id +(-1) '; PHASE ID: ' phase_seq_nb +(-1) ']:');


%*SASDOC-----------------------------------------------------------------------
| Begin processing for queue-submission of new/revised task entries.
+----------------------------------------------------------------------SASDOC*;
   data WORK.NEW_TASKS;
   set WORK.SCHED_TASKS_NOT_QUEUED end=EOF;

   length PDIR LDIR PGM LOG PARMS $1000 Message $ 5000 
		  REPORTS_STR $ 100  ; /*n. williams 10SEP2009 - change reports_str from 50 to 100*/

    

%*SASDOC-----------------------------------------------------------------------
| Check the new or revised tasks program parameters.
+----------------------------------------------------------------------SASDOC*;
   if PROGRAM_TASK_TX = '' then
   do;
      ERR=1;
      put 'ERROR: ' &pre 'No task program specified.';
   end;

   if ^ERR then
   do;												/* Beggining of do-group ^ERR (1)*/
      IF intck('minute',JOB_SCHEDULED_TS,datetime()) GT &JOB_SCHED_VAR. THEN QUEUE_NB=4	;
      IF (QUEUE_NB = 4) and (ORG_QUEUE_NB ~= 4) THEN
         PUT 'NOTE: ' &pre "Scheduled time is more than &JOB_SCHED_VAR minutes past current time "
             '- submitting to batch queue for immediate execution.';

	

%*SASDOC-----------------------------------------------------------------------
| Assemble parameters and SYSPARM for "batch" files.
+----------------------------------------------------------------------SASDOC*;

    IF INITIATIVE_ID >= 100000	THEN DO;
		IF PROGRAM_ID=30 THEN DO;
			REPORTS_STR=  '~REQUEST_ID=' ||  COMPRESS(INITIATIVE_ID)
				 || '~REPORT_ID=' || COMPRESS(PROGRAM_ID) 
				 || '~INITIATIVE_ID=' || COMPRESS(PARMTR_ID1) 
				 || '~PHASE_SEQ_NB=' || COMPRESS(PARMTR_ID2) 
				 || '~HSC_USR_ID=' || COMPRESS(HSC_USR_ID) ;									
			reports_nm='reports/';
		END;
		ELSE IF PROGRAM_ID=31 THEN DO;
			REPORTS_STR=  '~REQUEST_ID=' ||  COMPRESS(INITIATIVE_ID)
				 || '~REPORT_ID=' || COMPRESS(PROGRAM_ID) 
				 || '~INITIATIVE_ID=' || COMPRESS(PARMTR_ID1) 
				 || '~PHASE_SEQ_NB=' || COMPRESS(PARMTR_ID2) 
				 || '~HSC_USR_ID=' || COMPRESS(HSC_USR_ID) ;									
			reports_nm='reports/';
		END;
		ELSE IF PROGRAM_ID=32 THEN DO;
			REPORTS_STR=  '~REQUEST_ID=' ||  COMPRESS(INITIATIVE_ID)
				 || '~REPORT_ID=' || COMPRESS(PROGRAM_ID) 
				 || '~RPT_PROGRAM_ID=' || COMPRESS(PARMTR_ID1) 
				 || '~RPT_TASK_ID=' || COMPRESS(PARMTR_ID2) 
				 || '~HSC_USR_ID=' || COMPRESS(HSC_USR_ID) ;									
			reports_nm='reports/';
		END;
		ELSE DO;
			REPORTS_STR=  '~REQUEST_ID=' ||  COMPRESS(INITIATIVE_ID)
			|| '~REPORT_ID=' || COMPRESS(PROGRAM_ID) 
			|| '~PHASE_SEQ_NB=' || COMPRESS(PARMTR_ID1) 
			|| '~HSC_USR_ID=' || COMPRESS(HSC_USR_ID) ;										
			reports_nm='reports/';
		END;
	END;
	ELSE DO;
			REPORTS_STR='';								
			reports_nm='';
	END;

	  IF PROGRAM_ID=999 THEN DO;
			REPORTS_STR=  '~REQUEST_ID=' ||  COMPRESS(INITIATIVE_ID) 
			|| '~REPORT_ID=' || COMPRESS(PROGRAM_ID) 
			|| '~DOCUMENT_LOC_CD=' || COMPRESS(PARMTR_ID1) 
			|| '~CMCTN_ROLE_CD=' || COMPRESS(PARMTR_ID2) 
			|| '~HSC_USR_ID=' || COMPRESS(HSC_USR_ID);;                      
			reports_nm='macros/';
	  END;
	  IF PROGRAM_ID=998 THEN DO;
			REPORTS_STR=  '~REQUEST_ID=' ||  COMPRESS(INITIATIVE_ID) 
			|| '~REPORT_ID=' || COMPRESS(PROGRAM_ID) 
			|| '~PHASE_SEQ_NB=' || COMPRESS(PARMTR_ID1) 
			|| '~HSC_USR_ID=' || COMPRESS(HSC_USR_ID);                      
			reports_nm='reports/';
	  END;
	  IF PROGRAM_ID=997 THEN DO;
			REPORTS_STR=  '~REQUEST_ID=' ||  COMPRESS(INITIATIVE_ID) 
			|| '~REPORT_ID=' || COMPRESS(PROGRAM_ID) 
			|| '~PHASE_SEQ_NB=' || COMPRESS(PARMTR_ID1) 
			|| '~HSC_USR_ID=' || COMPRESS(HSC_USR_ID);                      
			reports_nm='reports/';
	  END;

/*     IF INITIATIVE_ID >= 100000	THEN */
/*									 DO;*/
/*								REPORTS_STR=  '~REQUEST_ID=' ||  COMPRESS(INITIATIVE_ID)*/
/*												  || '~REPORT_ID=' || COMPRESS(PROGRAM_ID) ;									*/
/*								reports_nm='reports/';*/
/*									END;*/
/*		ELSE					    */
/*									 DO;*/
/*								REPORTS_STR='';								*/
/*								reports_nm='';*/
/*								    END;*/
/**/
/**/
/*      IF PROGRAM_ID=999 THEN DO;*/
/*			REPORTS_STR=  '~REQUEST_ID=' ||  COMPRESS(INITIATIVE_ID) || '~REPORT_ID=' || COMPRESS(PROGRAM_ID) ||'~DOCUMENT_LOC_CD=' || COMPRESS(PARMTR_ID1) */
/*			|| '~CMCTN_ROLE_CD=' || COMPRESS(PARMTR_ID2) || '~HSC_USR_ID=' || COMPRESS(HSC_USR_ID);                       */
/*			reports_nm='macros/';*/
/*	  END;*/
/**/
/**/
/*	   IF PROGRAM_ID=998 THEN DO;*/
/*			REPORTS_STR=  '~REQUEST_ID=' ||  COMPRESS(INITIATIVE_ID) || '~REPORT_ID=' || COMPRESS(PROGRAM_ID) ||'~PHASE_SEQ_NB=' || COMPRESS(PARMTR_ID1) || '~HSC_USR_ID=' || COMPRESS(HSC_USR_ID);                      */
/*			reports_nm='reports/';*/
/*	  END;*/
/**/
/**/
/*	  IF PROGRAM_ID=997 THEN DO;*/
/*			REPORTS_STR=  '~REQUEST_ID=' ||  COMPRESS(INITIATIVE_ID) || '~REPORT_ID=' || COMPRESS(PROGRAM_ID) ||'~PHASE_SEQ_NB=' || COMPRESS(PARMTR_ID1) || '~HSC_USR_ID=' || COMPRESS(HSC_USR_ID);                      */
/*			reports_nm='reports/';*/
/*	  END;*/


      *** Determine the program directory and program name: account for paths in PROGRAM_TASK_TX ***;
      IF INDEX(PROGRAM_TASK_TX,'/') AND INITIATIVE_ID < 100000 THEN
      DO;
         PDIR=substr(PROGRAM_TASK_TX,1,length(PROGRAM_TASK_TX)-index(left(reverse(PROGRAM_TASK_TX)),'/'));
         PGM =substr(PROGRAM_TASK_TX,length(PROGRAM_TASK_TX)-index(left(reverse(PROGRAM_TASK_TX)),'/')+2);
      END;
      ELSE
      DO;

	  *** NCW 09.10.2009 - Add custom for file release in Batch. QCPI208 included 998;
/*        IF PROGRAM_ID^=. AND INITIATIVE_ID < 100000 AND (PROGRAM_ID^=999 AND TASK_ID^=999) */
	  IF PROGRAM_ID^=. AND INITIATIVE_ID < 100000 AND PROGRAM_ID NOT IN (998,999,997)
		 THEN PDIR="/herc%lowcase(&SYSMODE)/prg/hercules/"||trim(left(put(PROGRAM_ID,8.))) || '/';
         ELSE  PDIR="/herc%lowcase(&SYSMODE)/prg/hercules/" || COMPRESS(reports_nm);

		 PGM=program_task_tx;


        ***** Adjust the value of PROGRAM_TASK_TX to contain the default directory specification *****;
		 IF INDEX(PGM,'/') =1 AND LENGTH(compress(PGM)) >1	THEN PGM=SUBSTR(compress(PGM),2);

		  PROGRAM_TASK_TX=compress(PDIR) || compress(PGM);
      end;
      if ^ERR and ^fileexist(PROGRAM_TASK_TX) then
      do;
         ERR=1;
         put 'ERROR: ' &pre 'Specified task program (' +(-1) PROGRAM_TASK_TX +(-1) ') does not exist.';
      end;
      if ^ERR and abs(datepart(JOB_SCHEDULED_TS)-today()) >365 then
      do;
         ERR=1;
         put 'ERROR: ' &pre 'Scheduled datetime is more than a year from today.';
      end;

      if ^ERR then
      do;	  /* Beggining of do-group ^ERR (2)*/

         *** Derive the task log directory and log name ***;
        * LDIR=tranwrd(compress(PDIR), '/PRG/', '/DATA/')||'/logs';
	
		 LDIR="/herc%lowcase(&SYSMODE)/data/hercules/" || COMPRESS(reports_nm)
			  || COMPRESS(put(PROGRAM_ID,8.))
			  || '/logs';

		 *** NCW 09.10.2009 - Make release log filename according to naming conventions.;
		 IF PROGRAM_ID=999 THEN 
		    LOG =compress(LDIR)||'/t_'||compress(put(INITIATIVE_ID,8.))
              ||'_'||compress(put(PHASE_SEQ_NB,8.))||'_rls.log';
		 ELSE
		 	LOG =compress(LDIR)||'/t_'||compress(put(INITIATIVE_ID,8.))
              ||'_'||compress(put(PHASE_SEQ_NB,8.))||'_task.log';

         *** Make sure that the log directory exists.  If not, then create it. ***;
         if ^fileexist(LDIR) then
         do;
            put 'NOTE: ' &PRE 'Creating directory ' LDIR '...';
			
            RC=system('mkdir -p '|| COMPRESS(LDIR));
            if RC^=0 then
            do;
               put 'ERROR: ' &PRE 'Unable to create log directory ' LDIR;
              /* LDIR=tranwrd(compress(PDIR), '/PRG/', '/DATA/');
               put 'NOTE: ' &PRE 'ALTLOG reset to ' log;	*/
            end;
         end;	 /* End of do-group ^fileexist(LDIR) */

         *** Build the SYSPARM parameter string ***;
         PARMS= '~PROGRAM_ID=' || trim(left(put(PROGRAM_ID,8.)))
               ||'~TASK_ID='||trim(left(put(TASK_ID,8.)))
               ||'~INITIATIVE_ID=' ||trim(left(put(INITIATIVE_ID,8.)))
               ||'~PHASE_SEQ_NB='||trim(left(put(PHASE_SEQ_NB,8.)))
			   || COMPRESS(REPORTS_STR)
               ||'~JOB_SCHEDULED_TS='||put(JOB_SCHEDULED_TS,datetime25.6)
               ||'~QUEUE_NB='||trim(left(put(QUEUE_NB,8.)));
      end; 	/* End of do-group ^ERR (2)*/
   end;	 /* End of do-group ^ERR (1) */
  * LOG=  "/DATA/sas%lowcase(&SYSMODE)1/hercules"
       ||'/logs/t_'||compress(put(INITIATIVE_ID,8.))||'_'||compress(put(PHASE_SEQ_NB,8.))
       ||'_task.log';

   if ERR then DO;
      delete; *** Only keep the valid/queued task entries (to ease updates of job_id). ;
	  CALL SYMPUT('err_fl',1);
	    	   END;
RUN;
     %set_error_fl2;


 *SASDOC-----------------------------------------------------------------------
 | Identify task that have been loaded into the job_que.job_queue SAS data set
 | already.
 +----------------------------------------------------------------------SASDOC*;
 PROC SQL NOPRINT;
   CREATE TABLE WORK.DUPLICATE_TASKS AS
   (SELECT PROGRAM_ID
          ,TASK_ID
          ,INITIATIVE_ID
          ,TITLE_TX
          ,PHASE_SEQ_NB
          ,JOB_SCHEDULED_TS
          ,PROGRAM_TASK_TX
          ,QUEUE_NB
   FROM WORK.NEW_TASKS
   WHERE INITIATIVE_ID IN      
   (SELECT INITIATIVE_ID
      FROM JOB_QUE.JOB_QUEUE)
 );
 QUIT;
     %set_error_fl2;

 *SASDOC-----------------------------------------------------------------------
 | Remove duplicate task.
 +----------------------------------------------------------------------SASDOC*;
 PROC SQL NOPRINT;
   CREATE TABLE WORK.NO_DUPLICATE_TASKS1 AS
   (SELECT *
   FROM WORK.NEW_TASKS
   WHERE INITIATIVE_ID NOT IN      
   (SELECT INITIATIVE_ID
      FROM JOB_QUE.JOB_QUEUE) );
 QUIT;
 
 * QCPI208 - added changes for 998 and 997;
 PROC SQL NOPRINT;
   CREATE TABLE WORK.NO_DUPLICATE_TASKS2 AS
   (SELECT *
   FROM WORK.NEW_TASKS
   WHERE INITIATIVE_ID NOT IN      
   (SELECT INITIATIVE_ID
      FROM JOB_QUE.JOB_QUEUE
      WHERE PROGRAM_ID IN (999,998,997))
   AND PROGRAM_ID IN (999,998,997));
 QUIT;
 
 DATA WORK.NO_DUPLICATE_TASKS;
  SET WORK.NO_DUPLICATE_TASKS1 WORK.NO_DUPLICATE_TASKS2;
 RUN;
 
 PROC SORT DATA=WORK.NO_DUPLICATE_TASKS NODUPKEY;
   BY INITIATIVE_ID PHASE_SEQ_NB JOB_SCHEDULED_TS;
 RUN;
     %set_error_fl2;

 PROC SQL NOPRINT;
   SELECT DISTINCT QUEUE_NB
   INTO   :QUEUE_NB_LST SEPARATED BY ','
   FROM WORK.NO_DUPLICATE_TASKS
   ORDER BY QUEUE_NB;
		
     %set_error_fl2;

PROC SQL NOPRINT;
   INSERT INTO JOB_QUE.JOB_QUEUE
      ( PROGRAM_ID,TASK_ID,INITIATIVE_ID,TITLE_TX,PHASE_SEQ_NB
       ,JOB_SCHEDULED_TS,PROGRAM_TASK_TX,QUEUE_NB,DELETED_IN)
   SELECT  PROGRAM_ID,TASK_ID,INITIATIVE_ID,TITLE_TX,PHASE_SEQ_NB
          ,JOB_SCHEDULED_TS,PROGRAM_TASK_TX,QUEUE_NB,0
   FROM    WORK.NO_DUPLICATE_TASKS;
 QUIT;
       %set_error_fl2;

  PROC SQL NOPRINT;
   CREATE TABLE WORK.NO_DUPLICATE_TASKS AS
   SELECT  *
   FROM    WORK.NO_DUPLICATE_TASKS
   ORDER BY QUEUE_NB, JOB_SCHEDULED_TS, INITIATIVE_ID, PHASE_SEQ_NB;
   QUIT;
		 %set_error_fl2;

   %IF &err_fl=1 %THEN %GOTO EXIT_GETTASKS;
   %let JOB_QUEUE_MGR_S=/herc%lowcase(&SYSMODE)/prg/hercules/gen_utilities/sas/job_queue_mgr_start.sas;
   %let JOB_QUEUE_MGR_E=/herc%lowcase(&SYSMODE)/prg/hercules/gen_utilities/sas/job_queue_mgr_end.sas;
   %let JOB_QUEUE_MGR_TMP_FL=/herc%lowcase(&SYSMODE)/data/hercules/gen_utilities/job_queue/job_queue_mgr_tmp_fl;
   %let _NUM=1;
   %let _CUR_QUEUE_NB=%scan(%quote(&QUEUE_NB_LST),&_NUM,%str(,));
   %do %while(%str(&_CUR_QUEUE_NB) ne %str());
      data _NULL_;
      set WORK.NO_DUPLICATE_TASKS(where=(QUEUE_NB = &_CUR_QUEUE_NB));
      by QUEUE_NB JOB_SCHEDULED_TS INITIATIVE_ID PHASE_SEQ_NB;;
      if QUEUE_NB = 4 then
      do;
         TMP_FL="&JOB_QUEUE_MGR_TMP_FL"||'_4_'||trim(left(put(PROGRAM_ID,8.)))
                ||'_t_'||compress(put(INITIATIVE_ID,8.))||'_'||compress(put(PHASE_SEQ_NB,8.))
                ||'_tmp.sas';
         BATCH_AT='&';
      end;
      else
      do;
         TMP_FL="&JOB_QUEUE_MGR_TMP_FL"||'_'||compress(put(QUEUE_NB,8.))||'_tmp.sas';
         BATCH_AT=' ';
      end;
      line_1 ="cat &JOB_QUEUE_MGR_S \";
      line_2 ='    ' || trim(left(PROGRAM_TASK_TX)) || ' \';
      line_3 ="    &JOB_QUEUE_MGR_E \";
      line_4 ='    >' || trim(left(TMP_FL));
      line_5 ='sas -sysin ' || trim(left(TMP_FL)) || ' \';
      line_6 ='    -log ' || compress(log) || ' \';
      line_7 ="    -sysparm '" || trim(left(PARMS)) || "' \";
      line_8 ='    -noterminal ' || trim(BATCH_AT);
/*	  line_9 =' ';*/
      line_9 ='rm -f '|| trim(left(TMP_FL));

      file "&Q_SCRIPT._&_CUR_QUEUE_NB..scr" lrecl=32676;
      put @1 line_1 / @1 line_2 / @1 line_3 / @1 line_4 / @1 line_5
        / @1 line_6 / @1 line_7 / @1 line_8
%*SASDOC-----------------------------------------------------------------------
| If asynchronous batch then sleep for 5 seconds before deleting TMP_FL.
+----------------------------------------------------------------------SASDOC*;
      %if (&_CUR_QUEUE_NB=4) %then
      %do;
        / @1 'sleep 5'
      %end;
        / @1 line_9;
      run;
            %set_error_fl2;

	%PUT ;
	%PUT Contents of the file &Q_SCRIPT._&_CUR_QUEUE_NB..scr:;
	%PUT ;

	DATA _NULL_;
     INFILE "&Q_SCRIPT._&_CUR_QUEUE_NB..scr" lrecl=32676;
	  INPUT;
      PUT _INFILE_;
    RUN;

      %sysexec chmod ugo+x &Q_SCRIPT._&_CUR_QUEUE_NB..scr;
      %sysexec . &Q_SCRIPT._&_CUR_QUEUE_NB..scr > &Q_SCRIPT._&_CUR_QUEUE_NB..syslog 2>&1 &;

	  %IF &SYSRC NE 0 %THEN %LET err_fl=1;
      %let _NUM=%eval(&_NUM+1);
      %let _CUR_QUEUE_NB=%scan(%quote(&QUEUE_NB_LST),&_NUM,%str(,));
   %END; /* END OF %DO %WHILE LOOP.*/

%EXIT_GETTASKS:;
	
 %IF &err_fl=1 %THEN
					%DO;
			%PUT &err_fl=1;
			%LET MESSAGE_FOR_GETTASKS=HCE SUPPORT: ERROR IN THE SCHEDULER hercules_task_master.sas ;
			%email_parms(EM_TO=&EMAIL_IT.,
			      			 EM_SUBJECT=&MESSAGE_FOR_GETTASKS.,
			      			 EM_MSG=&MESSAGE_FOR_GETTASKS.. Some of the jobs were not scheduled. For detail see log in /herc%lowcase(&SYSMODE)/data/hercules/gen_utilities/job_queue/logs/ );
					%END;

%MEND GETTASKS;


%set_sysmode(mode=prod);

%LET DEBUG_FLAG=N;
/*OPTION MLOGIC MPRINT SYMBOLGEN;*/
options fullstimer mprint mlogic symbolgen source2 mprintnest mlogicnest;

ODS LISTING CLOSE;
%include "/herc&sysmode./prg/hercules/hercules_in.sas";
libname &HERCULES DB2 dsn=&UDBSPRP schema=&HERCULES defer=YES;
%let JOB_QUE=JOB_QUE;
%let JOB_QUE_SCHEMA=JOB_QUE_%upcase(&SYSMODE);
/*%let JOB_QUE_SCHEMA=JOB_QUE_TEST;*/
libname &JOB_QUE DB2 dsn=&UDBSPRP schema=&JOB_QUE_SCHEMA defer=YES ;
libname saslib "/herc&sysmode./data/hercules/gen_utilities/job_queue";

%GETTASKS;
