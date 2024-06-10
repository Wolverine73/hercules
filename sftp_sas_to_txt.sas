/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  ftp_sas_to_txt.sas (macro)
|
| LOCATION: /PRG/sastest1/hercules/macros
|
| PURPOSE:  This macro will accept a SAS dataset as input and utilize the
|           %export_sas_to_txt macro to generate .txt output that is then
|           transferred to another host via FTP.  .ok and .layout files can
|           also be sent (optional).
|
| MACRO PARAMETERS:
|
| TBL_IN OR TBL_NAME_IN  - Name of SAS dataset to convert/transport.
|           FILE_OUT     - Name of output file...defaults to &TBL_NAME..txt.
|           LAYOUT_OUT   - Name of layout file...defaults to &TBL_NAME..layout.
|           RHOST        - Host name, IP address or "MACH" name from .netrc.
|           RDIR         - The destination subdirectory...defaults to root.
|           RUSER        - User name for destination server.
|           RPASS        - Password to destination server.
|           SEND_OK_FILE - (0|1) Flag for including a ".ok" file w/data.
|           SEND_LAYOUT  - (0|1) Flag for including a layout file w/data.
|
| INPUT:    Parameter Values.
|
| OUTPUT:   Updates to the &HERCULES..TINITIATIVE_PHASE table/task record.
|
| EXAMPLE USAGE:
|
|   %ftp_sas_to_txt(tbl_in=work.addresses, rhost=prodftp, send_ok_file=1,
|                   send_layout=1);
|
|   or
|
|   %ftp_sas_to_txt(tbl_in=work.addresses, rhost=prodftp, ruser=qcpap020,
|                   rpass=foobar, rdir=DATAMART, send_ok_file=1, send_layout=1);
|
+-------------------------------------------------------------------------------
| HISTORY:  01DEC2003 - T.Kalfas - Original.
|           10DEC2003 - T.Kalfas - Modified to enable HOST/MACH FTP methods.
|                                  If the &RUSER and &RPASS are not specified,
|                                  then the "MACH" method is used where the
|                                  "machine name" corresponds to a pseudo host
|                                  name entry that exists in the ~/.netrc file.
+-----------------------------------------------------------------------HEADER*/


OPTIONS MPRINT NOMLOGIC NOSYMBOLGEN;

%macro sftp_sas_to_txt(tbl_name_in=,
					  tbl_in=,
                      ds_opts=,
                      file_out=,
                      layout_out=,
                      rhost=,
                      rdir=,
                      ruser=,
                      send_ok_file=,
                      send_layout=,
                      compress_file=,
                      first_row_col_names=,
                      col_delimiter=
                     );

	%global ftp_ok;
	%let    ftp_ok=0;
	%let   nobs=0;

	%local  ftp_parms
	file_transferred_flg
	ready_for_ftp
	recs_transferred
	MESSAGE_FTP_SAS_TO_TXT;

	%let file_transferred_flg=0;
	%let recs_transferred=0;

	%IF tbl_in= %STR() %THEN %LET tbl_in=&tbl_name_in;

	%*SASDOC=====================================================================;
	%* Validate critical parameters.
	%*====================================================================SASDOC*;
	%IF &tbl_in= %STR() OR &rhost=%STR() OR &send_ok_file= %STR() %THEN 
	%DO;
		%LET err_fl=1;
		%LET MESSAGE_FTP_SAS_TO_TXT=%STR(ERROR: (&SYSMACRONAME): One of the madatory parameters tbl_in,rhost OR send_ok_file has not been specified);
	%END;
	
	%IF &err_fl=1 %THEN %GOTO EXIT_FTP;
	    %*SASDOC===================================================================;
	    %* Verify that the &TBL_IN dataset exists.
	    %*==================================================================SASDOC*;

	%IF %SYSFUNC(EXIST(%SCAN(&tbl_in,1,%str(%( ))))=0  AND 	%SYSFUNC(EXIST(%SCAN(&tbl_in,1,%str(%( )),VIEW))=0 %THEN 
	%DO;
		%LET err_fl=1;
		%LET MESSAGE_FTP_SAS_TO_TXT=%STR(ERROR: (&SYSMACRONAME): Table/View, &tbl_in, does not exist.);
	%END;
	%IF &err_fl=1 %THEN %GOTO EXIT_FTP;


	%*SASDOC=================================================================;
	%* If the FILE_OUT or LAYOUT_OUT parameters are not specified, then derive
	%* them using the value of TBL_IN.
	%*================================================================SASDOC*;
	%if "&file_out"="" %then %let file_out=%sysfunc(reverse(%scan(%sysfunc(reverse(&tbl_in)),1,%str(. )))).txt;
	%if "&layout_out"="" %then %let layout_out=%sysfunc(reverse(%scan(%sysfunc(reverse(&tbl_in)),1,%str(. )))).layout;

	%*SASDOC=================================================================;
	%* Use %export_sas_to_txt to generate both the final text output file and
	%* the file layout from &ds_pnd.
	%*================================================================SASDOC*;

	%if %bquote(&col_delimiter)=%str() %then 
	%do;
		%export_sas_to_txt(tbl_name_in=&tbl_in,
		tbl_option_in=&ds_opts,
		tbl_name_out="&file_out",
		l_file="&layout_out",
		file_type_out='ASC');
	%end;
	%else 
	%do;
		%if &first_row_col_names %then %let _col_names=Y;
		%else 	%let _col_names=N;
		%PUT NOTE: SYSERR = &SYSERR;
		%export_sas_to_txt(tbl_name_in=&tbl_in,
		tbl_option_in=&ds_opts,
		tbl_name_out="&file_out",
		l_file="&layout_out",
		file_type_out="DLM&col_delimiter",
		col_in_fst_row=&_col_names);
		%PUT NOTE: SYSERR = &SYSERR;
	%end;


      %*SASDOC=================================================================;
      %* Check the COMPRESS_FILE parameter and if necessary compress the file
      %* using the "compress" system utility.  This utility will generate a
      %* ".Z" version of the data file.  The .layout and .ok files are not
      %* compressed.  NOTE: The type of FTP transfer (ascii vs. binary) is
      %* determined by the COMPRESS_FILE parm as well since compressed files
      %* must be transfered as binary files.
      %*================================================================SASDOC*;

	%if &compress_file %then 
	%do;
		%let ready_for_ftp=%eval(%sysfunc(system(compress -f &file_out))=0);
		%if &ready_for_ftp %then 
		%do;
			%let ftp_transfer_mode=%str(recfm=s);
			%let file_out=&file_out..Z;
			%put NOTE: (&SYSMACRONAME): &file_out has been compressed.;
		%end; /* End of do-group for &ready_for_ftp=1 */
	%end; /* End of do-group for &compress_file=1 */
	%else 
	%do;
		%let ftp_transfer_mode=%str(recfm=v);
		%let ready_for_ftp=1;
	%end; /* End of do-group for &compress_file=0 */


	%if &ready_for_ftp=0 %then 
	%DO;
		%LET err_fl=1;
		%LET MESSAGE_FTP_SAS_TO_TXT=%STR(ERROR: (&SYSMACRONAME): &file_out could not be compressed.);
	%END;
	%IF &err_fl=1 %THEN %GOTO EXIT_FTP;

	%*SASDOC===============================================================;
	%* Setup FTP parameters based on HOST vs. MACH method.  If &RUSER and
	%* &RPASS are not specified, then the MACH method (.netrc) will be used.
	%*==============================================================SASDOC*;


	%let ftp_parms=%str(host="&rhost" user="&ruser"); 
	%IF &err_fl=1 %THEN %GOTO EXIT_FTP; 


	  %*SASDOC=============================================================;
	  %* Setup FTP filename pipes as connections to the destination through
	  %* which SAS sends the text files.  These FTP pipes handle the
	  %* platform access as well as setting the destination directory.
	  %* 4 FTP pipes are defined to send the final output file (.txt), the
	  %* file layout (.layout), and the ".ok" files for each as
	  %* confirmation of a successful FTP process.
	  %*============================================================*SASDOC;

	  %let fout=%sysfunc(reverse(%scan(%sysfunc(reverse(&file_out)),1,%str(/ ))));


	%*SASDOC -----------------------------------------------------------------------
	| Defining four files : ftp_data ,ftp_lyo,ftp_dok,ftp_lok
	| 
	+----------------------------------------------------------------------SASDOC*;

	  /*     filename ftp_data SFTP  "&rdir.&fout" &ftp_parms  ; */
	  %let ftp_data=&file_out ;  
	  %let ftp_lyo= %sysfunc(reverse(%scan(%sysfunc(reverse(&layout_out)),1,%str(/ ))));
	  %let ftp_dok=%sysfunc(reverse(%scan(%sysfunc(reverse(&file_out..ok)),1,%str(/ ))));
	  %let  ftp_lok = %sysfunc(reverse(%scan(%sysfunc(reverse(&layout_out..ok)),1,%str(/ )))) ;


	%*SASDOC -----------------------------------------------------------------------
	| This small piece of code creates source path
	| 
	+----------------------------------------------------------------------SASDOC*;


	 %let ftp_dok_1=%index(%sysfunc(reverse(&file_out)),%str(/));
	 %let len=%length(&file_out);
	 %let source_path = %substr(&file_out,1,&len-&ftp_dok_1+1);


	  %*SASDOC=============================================================;
	  %* FTP the final text (.txt) file.  If the record total matches the
	  %* number of observations in &TBL_IN, then verify the FTP with a
	  %* transfer of the .ok file.
	  %*============================================================*SASDOC;


	  PROC SQL NOPRINT;
		SELECT COUNT(*) INTO : nobs
		FROM &tbl_in ;
	  QUIT;


	 **DOING SECURE FTP ** ;



	%*SASDOC=============================================================;
	%* Secure ftp for  ftp_data
	%*============================================================*SASDOC;

	data _null_;
		file 'sftp_cmd_1';
		put    "cd &rdir"
		/ "put &ftp_data."
		/ 'quit';
	run;
	data _null_;
		rc = system("sftp &ruser@&rhost < sftp_cmd_1 > sftp_log_1 2> sftp_msg_1");
		rc = system('rm sftp_cmd_1');
		rc = system('rm sftp_log_1');
		rc = system('rm sftp_msg_1');
		
		IF   _ERROR_=0  THEN 
		DO;
			CALL SYMPUT('file_transferred_flg','1');
		END;
		ELSE  CALL SYMPUT('file_transferred_flg','0');
	run;
	
	%IF  &file_transferred_flg. %THEN
	%DO;
		%PUT NOTE: (&SYSMACRONAME): &ftp_data was successfully transferred to &rhost.;
		%let ftp_ok=1;
	%END;	  
	%ELSE  %DO;
		%put ERROR: (&SYSMACRONAME): &ftp_data was not transferred to &rhost.;
		%LET err_fl=1;
	%END;	
	 %IF &err_fl=1 %THEN %GOTO EXIT_FTP; 

	%*SASDOC=============================================================;
	%* Secure ftp for  ftp_lyo
	%*============================================================*SASDOC;
	%if &send_layout %then %do;
		data _null_;
		   file 'sftp_cmd_2';
		   put   "cd &rdir"
		     / "put &source_path.&ftp_lyo."
		     / 'quit';
		run;
		data _null_;
			rc = system("sftp &ruser@&rhost < sftp_cmd_2 > sftp_log_2 2> sftp_msg_2");
			rc = system('rm sftp_cmd_2');
			rc = system('rm sftp_log_2');
			rc = system('rm sftp_msg_2');
			
			IF   _ERROR_=0  THEN 
			DO;
				CALL SYMPUT('file_transferred_flg','1');
			END;
			ELSE  CALL SYMPUT('file_transferred_flg','0');
		run;
		
		%IF  &file_transferred_flg. %THEN
		%DO;
			%PUT NOTE: (&SYSMACRONAME): &ftp_lyo was successfully transferred to &rhost.;
		%END;	  
		%ELSE  %DO;
			%put ERROR: (&SYSMACRONAME): &ftp_lyo was not transferred to &rhost.;
		%END;	
		

	%end ;

	%*SASDOC=============================================================;
	%* Secure ftp for  ftp_dok
	%*============================================================*SASDOC;

	%if &send_ok_file %then %do;
		%if &sysrc=0 %then %do ;
			data _null_;
			file "&source_path.&ftp_dok.";
			put " data file has been  transferred to &rhost" ;
			run;
		
		


		data _null_;
			file 'sftp_cmd_3';
			put   "cd &rdir"
			/ "put &source_path.&ftp_dok."
			/ 'quit';
		run;
		data _null_;
			rc = system("sftp &ruser@&rhost < sftp_cmd_3 > sftp_log_3 2> sftp_msg_3");
			rc = system('rm sftp_cmd_3');
			rc = system('rm sftp_log_3');
			rc = system('rm sftp_msg_3');
			
		run;

		%end ;
		%*SASDOC=============================================================;
		%* Secure ftp for  ftp_lok
		%*============================================================*SASDOC;
	 	%if &send_layout %then %do;

			%if &sysrc=0 %then %do ;
				data _null_;
					file "&source_path.&ftp_lok.";
					put " layout  file has been  transferred to &rhost" ;
				run;
		
			

			data _null_;
				file 'sftp_cmd_4';
				put   "cd &rdir"
				/ "put &source_path.&ftp_lok."
				/ 'quit';
			run;
			data _null_;
				rc = system("sftp &ruser@&rhost < sftp_cmd_4 > sftp_log_4 2> sftp_msg_4");
				rc = system('rm sftp_cmd_4');
				rc = system('rm sftp_log_4');
				rc = system('rm sftp_msg_4');
			run;
				%end ;

		%end ; /* End of do-group for &send_layout=1 */

	%end ; /* End of do-group for &send_ok_file=1 */



	%EXIT_FTP: ;
	
	%IF &err_fl=1 %THEN
	%DO;
		%LET release_data_ok=0;
		%PUT MESSAGE_FTP_SAS_TO_TXT=&MESSAGE_FTP_SAS_TO_TXT;
	%END;
	
%mend sftp_sas_to_txt;

