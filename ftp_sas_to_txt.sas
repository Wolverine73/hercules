/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Friday, September 17, 2004      TIME: 03:21:59 PM
   PROJECT: macros
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Wednesday, August 11, 2004      TIME: 02:34:09 PM
   PROJECT: macros
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Thursday, March 18, 2004      TIME: 05:33:00 PM
   PROJECT: hercules_macros
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\Hercules\hercules_macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Tuesday, March 09, 2004      TIME: 12:21:13 PM
   PROJECT: hercules_macros
   PROJECT PATH: M:\qcpi514\Caremark\EG_projects\EG_projects_20\Hercules\hercules_macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Friday, January 30, 2004      TIME: 11:01:25 AM
   PROJECT: Project
   PROJECT PATH: 
---------------------------------------- */
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

%macro ftp_sas_to_txt(tbl_name_in=,
					  tbl_in=,
                      ds_opts=,
                      file_out=,
                      layout_out=,
                      rhost=,
                      rdir=,
                      ruser=,
                      rpass=,
                      send_ok_file=0,
                      send_layout=0,
                      compress_file=0,
                      first_row_col_names=0,
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

  %let    file_transferred_flg=0;
  %let    recs_transferred=0;

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

    %IF 	%SYSFUNC(EXIST(%SCAN(&tbl_in,1,%str(%( ))))=0 
	   AND 	%SYSFUNC(EXIST(%SCAN(&tbl_in,1,%str(%( )),VIEW))=0 %THEN 
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
        %else 							%let _col_names=N;

        %export_sas_to_txt(tbl_name_in=&tbl_in,
                           tbl_option_in=&ds_opts,
                           tbl_name_out="&file_out",
                           l_file="&layout_out",
                           file_type_out="DLM&col_delimiter",
                           col_in_fst_row=&_col_names);
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

        %if &ruser=%STR() OR &rpass=%STR() %then 
						  			%do;
          %if %sysfunc(fileexist(~/.netrc)) and %sysfunc(system(cut -d' ' -f2 ~/.netrc | grep -i &rhost))=0
          %then %let ftp_parms=%str(mach="&rhost" cd="&rdir");
		  %ELSE  %DO;
			%LET err_fl=1;
			%LET MESSAGE_FTP_SAS_TO_TXT=%STR(ERROR: (&SYSMACRONAME): &rhost was not found in ~/.netrc.);
			    %END; /* End of do-group for host entry existence in .netrc AND parameters ruser and/or rpass are not defined*/
		          				 	%end; /* End of do-group for missing*/
        %else %let ftp_parms=%str(host="&rhost" user="&ruser" pass="&rpass" cd="&rdir");

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
          filename ftp_datn FTP "&file_out" mach='localhost' &ftp_transfer_mode. Lrecl=32767 debug;
          filename ftp_data FTP "&fout" &ftp_parms &ftp_transfer_mode. Lrecl=32767 debug;

          %if &send_layout %then 
								 	%do;
            filename ftp_lyo ftp "%sysfunc(reverse(%scan(%sysfunc(reverse(&layout_out)),1,%str(/ ))))" &ftp_parms recfm=v Lrecl=32767;
          						 	%end; /* End of do-group for &send_layout=1 */
          %if &send_ok_file %then 
								  	%do;
            filename ftp_dok ftp "%sysfunc(reverse(%scan(%sysfunc(reverse(&file_out..ok)),1,%str(/ ))))" &ftp_parms recfm=v ;
            %if &send_layout %then 
							%do;
              filename ftp_lok ftp "%sysfunc(reverse(%scan(%sysfunc(reverse(&layout_out..ok)),1,%str(/ ))))" &ftp_parms recfm=v ;
            				%end; /* End of do-group for &send_layout=1 */
          						  	%end; /* End of do-group for &send_ok_file=1 */

          %*SASDOC=============================================================;
          %* FTP the final text (.txt) file.  If the record total matches the
          %* number of observations in &TBL_IN, then verify the FTP with a
          %* transfer of the .ok file.
          %*============================================================*SASDOC;


		  PROC SQL NOPRINT;
	   		SELECT COUNT(*) INTO : nobs
	     		FROM &tbl_in
		 		;
	  	 QUIT;

     DATA _NULL_; 
           %if &compress_file %then %str(n=-1;); 
            INFILE ftp_datn LRECL=32767 SHAREBUFFERS END=eof  %if &compress_file %then %str(nbyte=n);;
            FILE   ftp_data LRECL=32767                       %if &compress_file %then %str(nbyte=n);;
            INPUT;
            PUT _INFILE_;

			nobs=&nobs.;
			first_row_col_names=&first_row_col_names.;
			compress_file=&compress_file.;
			send_ok_file=&send_ok_file.;

            recno+1;

 IF EOF THEN DO;
	      IF   _ERROR_=0  
            AND (compress_file=1 OR (compress_file=0 AND recno=nobs+first_row_col_names)) 
		 			THEN 
						DO;
			    CALL SYMPUT('file_transferred_flg','1');
           		CALL SYMPUT('recs_transferred', PUT(nobs+first_row_col_names,best.));
						END;				   			 /* End of do-group for ^_ERROR_=1 */
		 ELSE  CALL SYMPUT('file_transferred_flg','0');  /* End of do-group for _ERROR_=1 */	   	     
                END; /* End of do-group for eof=1 */
       RUN;

	   %IF  &file_transferred_flg. %THEN
				%DO;
		  %IF &send_ok_file. 	%THEN 
								   %DO;
								DATA _NULL_; 
								  FILE ftp_dok;
								RUN;	
								   %END;
				%END;

	  %ELSE  
				%DO;
		    %LET err_fl=1;
			%LET MESSAGE_FTP_SAS_TO_TXT=%STR(ERROR: (&SYSMACRONAME): &ds_pnd does not exist.);
            %put ERROR: (&SYSMACRONAME): &file_out was not successfully transferred to &rhost.;
            %put ERROR: (&SYSMACRONAME): %cmpres(&recs_transferred) of %cmpres(&first_row_col_names) records were transferred.;
          		%END; /* End of do-group &file_transferred_flg NE 1 */

	  %IF &err_fl=1 %THEN %GOTO EXIT_FTP; 

           %PUT NOTE: (&SYSMACRONAME): &file_out was successfully transferred to &rhost.;
           %PUT NOTE: (&SYSMACRONAME): %cmpres(&recs_transferred) of %cmpres(&nobs) +%cmpres(&first_row_col_names) records were transferred.;

            	%let ftp_ok=1;

          %if &send_layout %then 
			 %do;
              data _null_;
                infile "&layout_out" sharebuffers end=eof;
                file ftp_lyo;
                input;
                put _infile_;
              run;

              %if &send_ok_file %then 
				  %do;
                	  %if &sysrc=0 %then 
								    	 %do;
                  data _null_;
                    file ftp_lok;
                  run;
                  %if &sysrc=0 %then %put NOTE: (&SYSMACRONAME): &layout_out was successfully transferred to &rhost.;
                  						%end; /* End of do-group &sysrc=0 */
                  %else %put ERROR: (&SYSMACRONAME): &layout_out was not successfully transferred to &rhost.;
              	   %end; /* End of do-group &send_ok_file=1 */
            %end; /* End of do-group &send_layout=1 */    

  %EXIT_FTP: ;
   %IF &err_fl=1 %THEN
					%DO;
			%LET release_data_ok=0;
			%PUT MESSAGE_FTP_SAS_TO_TXT=&MESSAGE_FTP_SAS_TO_TXT;
					%END;
%mend ftp_sas_to_txt;
