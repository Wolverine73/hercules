%include '/user1/qcpap020/autoexec_new.sas';
%set_sysmode(mode=prod);
/*%add_to_macros_path(NEW_MACRO_PATH=/herc%lowcase(&SYSMODE)/hercules/macros);*/
%let JOB_QUE=JOB_QUE;
%let JOB_QUE_SCHEMA=JOB_QUE_%upcase(&SYSMODE);
libname &JOB_QUE DB2 dsn=&UDBSPRP schema=&JOB_QUE_SCHEMA defer=YES ;
%JOB_QUEUE_MGR(S);
