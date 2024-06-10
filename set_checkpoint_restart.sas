 /*HEADER -------------------------------------------------------------------------
 |
 |    PROGRAM NAME: 
 |        set_checkpoint_restart.sas - Macro to set program checkpoint restarts
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
 |
 +-------------------------------------------------------------------------------HEADER*/

 %macro set_checkpoint_restart
	 (
	  scr_pgm_name=
     ,scr_step_id=
	 ,scr_datadir=
	 ,scr_saslib=
	 ,scr_checkpoint_restart_file=
	 );	 

	 options nonotes 
	 ;

	 %let macro_name              = %sysfunc(lowcase(&sysmacroname));

	 x "cd &scr_datadir.";
	 x "rm &scr_checkpoint_restart_file._????.tch";
                                                             
	 %if %eval(&scr_step_id)    < %eval(&last_step_id)       %then %do;
	     x "touch &scr_checkpoint_restart_file._&scr_step_id..tch";
	 %end;

     %put  -----------------------------------------------------------------------;
     %put  SUCCESSFULLY COMPLETED MACRO STEP_&step_id IN PROGRAM &pgm_name..SAS;
     %put  -----------------------------------------------------------------------;

     options notes;

 %mend set_checkpoint_restart;
