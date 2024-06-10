
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  negfrm_eob_report.sas
|
| PURPOSE:  The program selects descriptive and communication data for an
|           initiative/phase and produces a report.
|
| OUTPUT:   csv report file
+--------------------------------------------------------------------------------
| HISTORY:  31JAN2013 - SB - Original version.
+------------------------------------------------------------------------*/
%set_sysmode(mode=prod);

/*%set_sysmode(mode=sit2);*/
/*OPTIONS SYSPARM='initiative_id=8319 hsc_usr_id=QCPI208 request_id=';*/

%include "/herc&sysmode/prg/hercules/hercules_in.sas";

*SASDOC=====================================================================;
*  QCPI208 - added logic to pull requestor id by QCP ID 
*====================================================================SASDOC*;
PROC SQL NOPRINT;
        SELECT QUOTE(TRIM(email)) INTO :_em_to_user SEPARATED BY ' '
        FROM ADM_LKP.ANALYTICS_USERS
        WHERE UPCASE(QCP_ID) IN ("&HSC_USR_ID");
QUIT;

*SASDOC=====================================================================;
*  QCPI208
*  Call update_request_ts to signal the start of executing summary report in batch
*====================================================================SASDOC*;
%update_request_ts(start);

%macro eob_report(ADJ_ENGINE=);
 
	PROC SQL;
		CREATE TABLE WORK.EOB_MBRS_REM_&initiative_id._&adj_engine. AS
		SELECT * 
		FROM &ORA_TMP..EOB_MBRS_REMOVED_&initiative_id._&adj_engine.;
	QUIT;

	%if &sqlobs. NE 0 %then %do;
      	filename ftp_txt ftp "/users/patientlist/MED_D/Reports/eob_mbrs_rem_&initiative_id._report.csv"
           mach='sfb006.psd.caremark.int' RECFM=V DEBUG;
		%export_sas_to_txt(tbl_name_in=WORK.EOB_MBRS_REM_&initiative_id._&adj_engine.,
                   tbl_name_out=ftp_txt,
                   l_file="layout_out",
                   File_type_out='CSV',
                   Col_in_fst_row=Y);

		%email_parms( EM_TO=&_em_to_user
		,EM_SUBJECT="EOB Members Removed Report for Negative Formulary Initiative=&initiative_id."
		,EM_MSG="EOB Members Removed report for Initiative=&initiative_id. is located on patientlist drive in MED_D/Reports folder.");
	%end;
	%else %do;
		%email_parms( EM_TO=&_em_to_user
		,EM_SUBJECT="EOB Members Removed Report for Negative Formulary Initiative=&initiative_id."
		,EM_MSG="There were no rows for EOB Memebres Removed report for Initiative=&initiative_id.");
	%end;
%mend eob_report;

%macro run_eob_report;
	PROC SQL;
		SELECT EOB_INDICATOR INTO :EOB_INDICATOR
		FROM QCPAP020.TEOB_FILTER_DTL
		WHERE INITIATIVE_ID = &INITIATIVE_ID;
	QUIT;
	%if &EOB_INDICATOR. = 1 %then %do; *if EOB indicator enabled;
		%if &RX_ADJ EQ 1 %then %do;
			%EOB_REPORT(ADJ_ENGINE=RX);
		%end;
		%if &RE_ADJ EQ 1 %then %do;
			%EOB_REPORT(ADJ_ENGINE=RE);
    	%end;
		%else %do;
			%email_parms( EM_TO=&_em_to_user
			,EM_SUBJECT="Negative Formulary runs for RxClaim and Recap clients only."
			,EM_MSG="Please check Initiative=&initiative_id. to make sure only RxClaim and/or Recap clients were setup.");
		%end;
	%end;
	%else %do;
		%email_parms( EM_TO=&_em_to_user
		,EM_SUBJECT="EOB filter disabled for Negative Formulary Initiative=&initiative_id."
		,EM_MSG="The EOB Memebres Removed report for Initiative=&initiative_id. was not produced because EOB filter is disabled for this initiative.");
	%end;
%mend run_eob_report;
%run_eob_report;

*SASDOC=====================================================================;
* QCPI208
* Call update_request_ts to complete of executing summary report in batch
*====================================================================SASDOC*;
%update_request_ts(complete);
