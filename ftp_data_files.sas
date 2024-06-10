/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  ftp_data_files.sas (macro)
|
| LOCATION: /PRG/sastest1/hercules/macros
|
| PURPOSE:  This macro will ftp ascii and binary files to a destination
|           using the operating system ftp.
|
| MACRO PARAMETERS:
|
|           server       - server name                                     
|           id           - id of destination server                            
|           pw           - pw of destination server                              
|           transfermode - ascii or binary                                       
|           dataset      - the dataset which will host the files needed to be transferred
|           getrootdir   - location of files on server      
|           putrootdir   - location of files on destination server
|
+-------------------------------------------------------------------------------
| HISTORY:  18DEC2008 - B.Stropich - Original.
|
+-----------------------------------------------------------------------HEADER*/ 


%macro ftp_data_files(server=, id=, pw=, transfermode=, dataset=, getrootdir=, 
                       putrootdir=, removefiles1=, removefiles2=);

	data _null_;
	  length day $ 2;
	  day= put(day(today()),z2.);
	  month= put(month(today()),z2.);
	  year= put(year(today()),z4.);
	  date=trim(year)||trim(month)||trim(day);
	  call symput('date', date);
	  call symput('day' , day);
	run;

	%put NOTE:  date = &date. ;
	%put NOTE:  day  = &day. ;

	data _null_;
	  set &dataset.  end=eof;
	  i+1;
	  ii=left(put(i,4.));
	  call symput('files'||ii,left(trim(files)));
	  if eof then call symput('files_total',ii);
	run;
	
	data _null_;
	  x "rm -f %trim(&getrootdir.)/&removefiles1.";
	  x "rm -f %trim(&getrootdir.)/&removefiles2.";
	run;

	/*-----------------------------------------------------------------*/
	/* Set up the fileref to execute the ftp command.                  */
	/*-----------------------------------------------------------------*/
	%IF &dataset. = %str(PGRMDATA.TRIGGER2) %THEN  %DO;
  		%let ftpcmds=&getrootdir./ftpput_trigger_%trim(&date.).cmd;
	%END;
	%ELSE %DO;
  		%let ftpcmds=&getrootdir./ftpput_%trim(&date.).cmd;
	%END;

	filename ftpcmds "&ftpcmds.";  
	
	data _null_;
	  file ftpcmds pad lrecl=150;
	  put "user &id &pw";
	  put "&transfermode";
	  put "cd &putrootdir";
	  %do k = 1 %to &files_total. ;
	    put "put &getrootdir./&&files&k &&files&k";
	  %end;
	  put "quit";
	run;

	/*-----------------------------------------------------------------*/
	/* The control file for ftp has been built; now run it.            */
	/*-----------------------------------------------------------------*/
	filename doftp pipe "ftp -n &server < &ftpcmds";
	
	data _null_;
	  infile doftp;
	  input;
	  put _infile_;
	run;

%mend ftp_data_files;
