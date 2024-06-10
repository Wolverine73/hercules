/**HEADER -------------------------------------------------------------------------------------------------
  | NAME:     CEE_CREATE_PRINT_DISPOSITION_FILE.SAS
  |
  | PURPOSE:  CREATE PRINT DISPOSITION FILE TO BE SENT BACK TO CEE
  |
  |          
  |          
  |
  |         
  |---------------------------------------------------------------------------------------------------------
  | HISTORY:  
  +-------------------------------------------------------------------------------------------------HEADER*/

%MACRO CEE_CREATE_PRINT_DISPOSITION_FILE;

INITIATIVEID=6493
options sysparm='INITIATIVE_ID=&INITIATIVEID PHASE_SEQ_NB=1';

%set_sysmode;		
%INCLUDE "/herc&sysmode/prg/hercules/hercules_in.sas";	

/*Once you call hercules_in you get hold off all the variables required like pending sas data set name ,its lib name*/

/*
create a sas daa set that holds all the information you need to create the file.
some columns are simple like opportunity_id,program_id and others need logic
*/


%MEND CEE_CREATE_PRINT_DISPOSITION_FILE;
