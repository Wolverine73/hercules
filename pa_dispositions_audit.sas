%include '/user1/qcpap020/autoexec_new.sas';  
%set_sysmode;
OPTIONS MPRINT SOURCE2 MPRINTNEST MLOGIC MLOGICNEST symbolgen ; 
options cleanup fullstimer sysparm='INITIATIVE_ID=10658 PHASE_SEQ_NB=1';
%include "/herc&sysmode/prg/hercules/hercules_in.sas";

LIBNAME SAVING "/herc&sysmode/data/hercules/gen_utilities/sas/cee_temp_dataset" ;

PROC CONTENTS DATA=SAVING.HERCULES_DISPOSITIONS VARNUM;
RUN;

PROC FREQ DATA=SAVING.HERCULES_DISPOSITIONS NOPRINT;
  TABLES DELIVERY_DATE_TIME*CEE_OPP_STATUS_CD*CEE_OPP_STATUS_RSN_CD / MISSING OUT=DISP_CHECK;
RUN;

DATA SAVING.HERCULES_DISPOSITIONS;
  SET SAVING.PRINT_DISPOSITION_FILE_10094
      SAVING.PRINT_DISPOSITION_FILE_9700
      SAVING.PRINT_DISPOSITION_FILE_10658
      SAVING.PRINT_DISPOSITION_FILE_10357
      SAVING.PRINT_DISPOSITION_FILE_9852
      SAVING.PRINT_DISPOSITION_FILE_9467;
RUN;

x "compress /herc&sysmode/data/hercules/gen_utilities/sas/cee_temp_dataset/PRINT_DISPOSITION_FILE_10094.sas7bdat ";
x "compress /herc&sysmode/data/hercules/gen_utilities/sas/cee_temp_dataset/PRINT_DISPOSITION_FILE_9700.sas7bdat ";
x "compress /herc&sysmode/data/hercules/gen_utilities/sas/cee_temp_dataset/PRINT_DISPOSITION_FILE_10658.sas7bdat ";
x "compress /herc&sysmode/data/hercules/gen_utilities/sas/cee_temp_dataset/PRINT_DISPOSITION_FILE_10357.sas7bdat ";
x "compress /herc&sysmode/data/hercules/gen_utilities/sas/cee_temp_dataset/PRINT_DISPOSITION_FILE_9852.sas7bdat ";
x "compress /herc&sysmode/data/hercules/gen_utilities/sas/cee_temp_dataset/PRINT_DISPOSITION_FILE_9467.sas7bdat ";

DATA WORK.ALIGN;
RENAME
SOURCE1 = SOURCE
OPPORTUNITY_ID1 = OPPORTUNITY_ID
CEE_CHANNEL_CODE1 = CEE_CHANNEL_CODE
CEE_PATIENT_ID1 = CEE_PATIENT_ID
CEE_OPP_STATUS_CD1 = CEE_OPP_STATUS_CD
CEE_OPP_STATUS_RSN_CD1 = CEE_OPP_STATUS_RSN_CD
CEE_OPT_OUT1 = CEE_OPT_OUT
DELIVERY_DATE_TIME1 = DELIVERY_DATE_TIME;
drop SOURCE
OPPORTUNITY_ID
CEE_CHANNEL_CODE
CEE_PATIENT_ID
CEE_OPP_STATUS_CD
CEE_OPP_STATUS_RSN_CD
CEE_OPT_OUT
DELIVERY_DATE_TIME;

SET SAVING.HERCULES_DISPOSITIONS  ;
SOURCE1 = left(SOURCE);
OPPORTUNITY_ID1 = left(OPPORTUNITY_ID);
CEE_CHANNEL_CODE1 = left(CEE_CHANNEL_CODE);
CEE_PATIENT_ID1 = left(CEE_PATIENT_ID);
CEE_OPP_STATUS_CD1 = left(CEE_OPP_STATUS_CD);
CEE_OPP_STATUS_RSN_CD1 = left(CEE_OPP_STATUS_RSN_CD);
CEE_OPT_OUT1 = left(CEE_OPT_OUT);
DELIVERY_DATE_TIME1 = left(DELIVERY_DATE_TIME);
RUN;

PROC CONTENTS VARNUM;
RUN;

/*SASDOC -----------------------------------------------------------------------
 | CREATION OF DISPOSITION FILE IN .DAT FORMAT.IT IS VARIABLE LENGTH PIPE DELIMITED
 | FLAT FILES .
 +----------------------------------------------------------------------SASDOC*/
** SET OPTIONS TO USE BLANK FOR MISSING NUMERIC DATA **;
OPTIONS MISSING='';

DATA _NULL_;
SET WORK.ALIGN;
FILE "/herc&sysmode/data/hercules/gen_utilities/sas/cee_temp_dataset/eoms_print_hercules_dispositions.dat" dlm='|' dsd;
PUT
SOURCE :$5.  
OPPORTUNITY_ID :$10.
CEE_CHANNEL_CODE :$5. 
CEE_PATIENT_ID :$20. 
CEE_OPP_STATUS_CD :$5. 
CEE_OPP_STATUS_RSN_CD :$5. 
COMMUNICATION_ID :$30. 
WP_PHONE_NUMBER :$10. 
CEE_OPT_OUT :1.
DELIVERY_DATE_TIME :$19.	
;
RUN;
