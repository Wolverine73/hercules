%set_sysmode;
/*%include "/herc&sysmode/prg/hercules/hercules_in.sas";*/
%add_to_macros_path(NEW_MACRO_PATH=/herc&sysmode/prg/hercules/macros);
%let JOB_QUE=JOB_QUE;
%let JOB_QUE_SCHEMA=JOB_QUE_%upcase(&SYSMODE);
/*%let JOB_QUE_SCHEMA=JOB_QUE_TEST;*/
libname &JOB_QUE DB2 dsn=&UDBSPRP schema=&JOB_QUE_SCHEMA defer=YES ;
%JOB_QUEUE_MGR(S);
