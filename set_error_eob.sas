 /*HEADER -------------------------------------------------------------------------
 |
 |    PROGRAM NAME: 
 |        set_error_eob.sas - Macro to set EOB errors
 |
 |    LOCATION:
 |        /PRG/sasprod1/sas_macros/
 |
 |    PURPOSE:  
 |         
 |
 |    FREQUENCY: 
 |        Monthly        
 |
 |    LOGIC:
 |        
 |
 |    INPUT:
 |        -----------------------------------------------------------------------
 |        UDB TABLES:
 |        -----------------------------------------------------------------------
 |            
 |
 |        -----------------------------------------------------------------------
 |        SAS DATASETS:
 |        -----------------------------------------------------------------------
 |            
 |            
 |        -----------------------------------------------------------------------
 |        TEXT FILES
 |        -----------------------------------------------------------------------
 |            None
 |
 |    ABEND PROCEDURES:
 |         Identify where it failed.
 |         Seek help from seniors, DBA.
 |
 |    MODIFIED LOG:  
 |
 |    DATE        PROGRAMMER     DESCRIPTION
 |    ----------  ------------   ------------------------------------------------
 |    01/31/2008  N. Novik       Initial Release.  
 |                E. Sliounkova  
 |
 +-------------------------------------------------------------------------------HEADER*/

 %macro set_error_eob
     (
      see_error_flag=
     ,see_action_type=
	 ,see_pgm_name=
     ,see_email_to_id=
     ,see_email_subject_id=
     ,see_email_message_id= 
     );

	 options nonotes 
	 ;

	 %let macro_name              = %sysfunc(lowcase(&sysmacroname));

     %put syserr                  = &syserr;
     %put sqlrc                   = &sqlrc;
     %put sqlxrc                  = &sqlxrc;
     %put err_fl                  = &err_fl;


     %if &see_error_flag                       =             %then %do;
         %let see_error_flag      = &err_fl;
	 %end;

     %if &sqlxrc                               =                or
	     %index(&sqlxrc,&valid_return_codes.)  > 0           %then %do;
	     %let sqlxrc_l            = 0; 
	 %end;
     %else                                                         %do;
         %let sqlxrc_l            = &sqlrc;
     %end;		  

     %if &sqlrc                                =             %then %do;
         %let sqlrc_l             = 0;
	 %end;
     %else                                                         %do;
         %let sqlrc_l             = &sqlrc;
	 %end;

	 /* Warnings are valid                                                      */
     %if &syserr                               = 4              or
	     %index(&sqlxrc,&valid_return_codes.)  > 0           %then %do;
	     %let syserr_l            = 0;
	 %end;
     %else                                                         %do;
         %let syserr_l            = &syserr; 
	 %end;

     %let sas_obs                 = %sysfunc(getoption(OBS)); 

     %if &sas_obs                              = 0           %then %do;
         %let err_fl              = 1;
	 %end;
	  
     %put sas OBS option          = &sas_obs;

     %let err_fl                  = %eval(%sysfunc(max(0,
                                              %sysfunc(abs(&err_fl)),
                                              %sysfunc(abs(&see_error_flag)),
                                              %sysfunc(abs(&syserr_l)),
                                              %sysfunc(abs(&sqlrc_l)),
                                              %sysfunc(abs(&sqlxrc_l))
                                                  ))
                                         );

     %put maximum return code     = &err_fl;

     %let err_fl                  = %eval(&err_fl >= 1);

     %put err_fl                  = &err_fl;

	 %if &err_fl                              ne 0           %then %do;
	     %put ERROR: STEP &step_id completed with error(s), program &see_pgm_name aborted;
	 %end;

	 %if &see_email_to_id                     ne             %then %do;
	     %let em_to               = ;
	 %end;
	 %else                                                         %do;
	     %let em_to               = &support_email;
	 %end;

	 %if &see_email_subject_id                ne             %then %do;
	     %let em_subject          = ;
	 %end;
	 %else                                                         %do;
	     %let em_subject          = PROGRAM ABEND: &see_pgm_name..sas;
	 %end;

	 %if &see_email_message_id                ne             %then %do;
	     %let em_msg              = ;
	 %end;
	 %else                                                         %do;
	     %let em_msg              = Errors found in step &step_id, please see the SAS log for program &see_pgm_name in /apps/log/ directory on dalcdcp;
	 %end;

 
	 %on_error
         (
          action=&see_action_type
         ,em_to=&em_to
         ,em_subject="&em_subject"
         ,em_msg="&em_msg"
		 );

     options notes;

 %mend set_error_eob;
