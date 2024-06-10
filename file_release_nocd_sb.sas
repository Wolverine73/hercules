*options fullstimer;
%let sysmode=prod;
%set_sysmode(mode=prod);
%let log_dir=%str(/PRG/sastest1/hercules/sergey);
options sysparm= 'INITIATIVE_ID=9811 PHASE_SEQ_NB=1';
%INCLUDE "/PRG/sas&sysmode.1/hercules/hercules_in.sas";
%file_release_wrapper2(init_id=9811, phase_id=1, com_cd=1, doc_cd=1, dbg_flg=1);
