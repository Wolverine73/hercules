/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  email_parms2.sas (macro)
|
| LOCATION: /PRG/sastest1/hercules/macros
|
| PURPOSE:  This macro is used to send emails with or without attachments
|           from a SAS program/environment.  This macro is the 2nd generation
|           of email_parms.sas (by Y.Vilk).  New features are: (1) automatic
|           translation of qcpids into email addresses (via get_email_address
|           macro), and (2) specification of attachment types (to allow
|           error-free opening by recipient regardless of the condition of
|           the file associations as stored in the SAS catalogs).
|
| INPUT:    MACRO PARMS:
|
|             EM_TO      = "to" IDs or addresses (required)
|             EM_CC      = "cc" IDs or addresses
|             EM_SUBJECT = email subject text (space-delimited)
|             EM_MSG     = email message text
|             EM_ATTACH  = email attachment(s) (space-delimited)
|             EM_FROM    = email sender id/address (required - default: &user)
|
|           DATASETS:
|
|             ADM_LKP.ANALYTICS_USERS (indirectly) for ID/address lookup.
|
| OUTPUT:   Email message is sent to addresses (if valid) with any attachments.
|
+-------------------------------------------------------------------------------
| HISTORY:  14JAN2004 - T.Kalfas  - Original.
|
+-----------------------------------------------------------------------HEADER*/

%macro email_parms2(em_to=,
                    em_cc=,
                    em_subject=,
                    em_msg=,
                    em_type=,
                    em_attach=,
                    em_from=%upcase(&user));


  %*===========================================================================;
  %* Scope the macro variables.
  %*====================================================================SASDOC*;

  %global err_cd message;
  %local  unk_attach_type_flg;
  %let    unk_attach_type_flg=0;

  %*===========================================================================;
  %* Proceed only if the "to" and "from" IDs/addresses have been provided.
  %*====================================================================SASDOC*;

  %isnull(em_to, em_from);
  %if ^&isnull %then %do;

    %*=========================================================================;
    %* Use the %get_email_address macro to retrieve email addresses for any
    %* QCP IDs in EM_TO and EM_CC.
    %*==================================================================SASDOC*;

    %let em_to=%sysfunc(dequote(&em_to));
    %get_email_address(&em_to);
    %let em_to=&email_address;

    %let em_from=%sysfunc(dequote(&em_from));
    %get_email_address(&em_from);
    %let em_from=&email_address;


    %isnull(em_cc, em_subject, em_msg, em_type, em_attach);

    %if ^&em_cc_isnull %then %do;
      %let em_cc=%upcase(%sysfunc(dequote(&em_cc)));
      %get_email_address(&em_cc);
      %let em_cc=&email_address;
    %end;
    %else %let em_cc=;

    %if ^&em_subject_isnull %then %let em_subject=%sysfunc(dequote(&em_subject));
    %if ^&em_msg_isnull     %then %let em_msg=%sysfunc(dequote(&em_msg));
    %if ^&em_type_isnull    %then %let em_type=%sysfunc(dequote(&em_type));


    %*=========================================================================;
    %* If an EM_ATTACH parameter has been specified, then determine the
    %* the attachment types based on the filename extensions. Each filename is
    %* processed or rather identified and assigned a CT= value (i.e., content
    %* type) which is added immediately following the filename in a new
    %* _ATTACHMENTS macro variable/string to be used during the email process.
    %*==================================================================SASDOC*;

    %if ^&em_attach_isnull  %then %do;

      %let i=1;

      %let em_attach=%sysfunc(compress(&em_attach,%str(%')%str(%")));

      %let _attachments=;

      %do %while(%qscan(%cmpres(&em_attach),&i,%str( ))^=);

        %let _attach=%sysfunc(dequote(%qscan(%cmpres(&em_attach),&i,%str( ))));

        %if "%substr(%left(&_attach),1,3))"="%str(ct=)" %then %let ct=%substr(%left(&_attach,4));
        %else %do;
          %if       %index(%upcase(&_attach),.PDF) %then %let ct=application/pdf;
          %else %if %index(%upcase(&_attach),.RTF) %then %let ct=application/rtf;
          %else %if %index(%upcase(&_attach),.XLS) or
                    %index(%upcase(&_attach),.DOC) or
                    %index(%upcase(&_attach),.SSD) or
                    %index(%upcase(&_attach),.SAS7BDAT) or
                    %index(%upcase(&_attach),.MDE) or
                    %index(%upcase(&_attach),.MDB) or
                    %index(%upcase(&_attach),.SAS7BCAT) or
                    %index(%upcase(&_attach),.SD2) or
                    %index(%upcase(&_attach),.SD7) %then %let ct=application/octet-stream;
          %else %let ct=;
        %end;

        %let _attachments=%left(%str(&_attachments %'%cmpres(&_attach)%'));
        %if "&ct"^="" %then %let _attachments=%left(%str(&_attachments ct=%'%cmpres(&ct)%'));

        %let i=%eval(&i+1);
      %end;
    %end;


    %*=========================================================================;
    %* The email process begins with defining a filename with an EMAIL engine.
    %*==================================================================SASDOC*;
    %*=========================================================================;
    %* NOTE: The email options can be specified directly in the datastep rather
    %*       than in the filename statement, but there were problems experienced
    %*       when attempting to specify multiple attachments in the datastep.
    %*==================================================================SASDOC*;

    filename mail_out email "&em_from"
                            to="&em_to"
                            %if ^&em_cc_isnull %then %str(cc="&em_cc");
                            %if ^&em_type_isnull %then %str(type="&em_type");
                            %if ^&em_subject_isnull %then %str(subject="&em_subject");
                            %if ^&em_attach_isnull  %then %str(attach=%(&_attachments%));
    ;

    data _null_;
      file mail_out lrecl=32767;
      put  "&em_msg";
      if _error_ then do;
        call symput('err_cd', put(1,1.));
        call symput('message', sysmsg());
      end;
      else call symput('err_cd', put(0,1.));
    run;

    %****** Clear the fileref *****;
    filename mail_out clear;

  %end;
  %else %do;
    %if &em_from_isnull %then %put ERROR: (&sysmacroname): The EM_FROM parameter has not been specified.;
    %if &em_to_isnull   %then %put ERROR: (&sysmacroname): The EM_TO   parameter has not been specified.;
  %end;
%mend email_parms2;
