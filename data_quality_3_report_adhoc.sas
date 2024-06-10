%include '/user1/qcpap020/autoexec_new.sas';

/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  data_quality_3_report.sas
|
| PURPOSE:  The report will list participants with DATA_QALITY_CD=3.
|
| OUTPUT:   csv report file
+--------------------------------------------------------------------------------
| HISTORY:  03OCT2012 - SB - Original version.
+------------------------------------------------------------------------*/
%set_sysmode(mode=prod);

/*%set_sysmode(mode=sit2);*/
/*options fullstimer mprint mlogic symbolgen source2 mprintnest mlogicnest;*/
options mprint mlogic;
OPTIONS sysparm="initiative_id=15092 REQUEST_ID=108153 HSC_USR_ID=QCPUD92G phase_seq_nb=1";

%include "/herc&sysmode./prg/hercules/hercules_in.sas";

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

%macro dq3_report;
	PROC SQL NOPRINT;
		CREATE TABLE work.dq3_&initiative_id. AS
		SELECT * FROM DATA_PND.T_&initiative_id._1_1 
		WHERE DATA_QUALITY_CD=3;
	QUIT;

	%if &sqlobs. NE 0 %then %do;

      	filename ftp_txt ftp "/users/patientlist/MED_D/Reports/dq3_&initiative_id._report.csv"
           mach='sfb006.psd.caremark.int' RECFM=V DEBUG;
		%export_sas_to_txt(tbl_name_in=work.dq3_&initiative_id.,
                   tbl_name_out=ftp_txt,
                   l_file="layout_out",
                   File_type_out='CSV',
                   Col_in_fst_row=Y);

		%email_parms( EM_TO=&_em_to_user
		,EM_SUBJECT="The Data Quality 3 Report for Negative Formulary Initiative=&initiative_id."
		,EM_MSG="The Data Quality 3 report for Initiative=&initiative_id. is located on patientlist drive in MED_D/Reports folder.");
	%end;
	%else %do;
		%email_parms( EM_TO=&_em_to_user
		,EM_SUBJECT="The Data Quality 3 Report for Negative Formulary Initiative=&initiative_id."
		,EM_MSG="There were no rows with data quality code 3 in Initiative=&initiative_id.");
	%end;
%mend dq3_report;
%dq3_report;

*SASDOC=====================================================================;
* QCPI208
* Call update_request_ts to complete of executing summary report in batch
*====================================================================SASDOC*;
%update_request_ts(complete);
