%macro ftp_reports(destination_cd, getrootdir, putrootdir, file_nm, transfermode);

proc sql noprint;
select ftp_user, ftp_host, ftp_pass
into:  ftp_user, :ftp_host, :ftp_pass
from aux_tab.set_ftp
where destination_cd = &destination_cd.
;quit;

%let ftpcmds=%str(&getrootdir./ftpput);

x "compress -f &getrootdir./&file_nm";

filename ftpcmds "&ftpcmds.";  
	
	data _null_;
	  file ftpcmds pad lrecl=150;
	  put "user &ftp_user &ftp_pass";
	  put "&transfermode";
	  put "cd &putrootdir";
      put "put &getrootdir./&file_nm..Z &file_nm..Z";
	  put "quit";
	run;

filename doftp pipe "ftp -n &ftp_host < &ftpcmds";
	
data _null_;
  infile doftp;
  input;
  put _infile_;
run;

x "rm -f %trim(&ftpcmds)";


%mend ftp_reports;
