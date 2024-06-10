%set_sysmode(mode=prod);
%let log_dir=%str(/hercprod/prg/hercules/test);
options sysparm= 'INITIATIVE_ID=14594 PHASE_SEQ_NB=1 hsc_usr_id=QCPI208';
%INCLUDE "/herc&sysmode./prg/hercules/hercules_in.sas";
%file_release_wrapper(init_id=14594, phase_id=1, com_cd=1, doc_cd=1, dbg_flg=1);
