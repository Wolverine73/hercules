/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  get_email_address.sas (macro)
|
| LOCATION: /PRG/sasprod1/sas_macros
|
| PURPOSE:  This macro retrieves an email address from an auxiliary SAS table,
|           /DATA/sasprod1/Admin/auxtable/ANALYTICS_USERS, for every userid
|           provided in &SYSPBUFFS.  NOTE: &SYSPBUFFS may also contain real
|           email addresses, but this is allowed as a convenience to the user
|           and these will be ignored by this macro.
|
| INPUT:    &SYSPBUFF - (positional) A list of userids (qcpids) and email
|                       addresses.  The userids will be processed.  The email
|                       addresses (if any) will be ignored.
|
| OUTPUT:   &EMAIL_ADDRESS - This is &SYSPBUFF but with all of the userids
|                            converted into email addresses. NOTE:  If there
|                            are ANY userids that cannot be found in
|                            ANALYTICS_USERS, an error message will be
|                            reported and EMAIL_ADDRESS will be set to null.
|
| EXAMPLE USAGE:
|
|           %GET_EMAIL_ADDRESS(qcpi445 qcpi603 yury.vilk@caremark.com);
|           %LET ADDR_TO=&EMAIL_ADDRESS;
|
|           %GET_EMAIL_ADDRESS(qcpi256);
|           %LET ADDR_CC=&EMAIL_ADDRESS;
|
|           %EMAIL_PARMS(EM_TO=&ADDR_TO,
|                        EM_CC=&ADDR_CC,
|                        EM_SUBJECT=The Zeus server is alive and well.);
|
+-------------------------------------------------------------------------------
| HISTORY:  12NOV2003 - T.Kalfas  - Original (based on SQL by Y. Vilk).
|
+-----------------------------------------------------------------------HEADER*/

%MACRO GET_EMAIL_ADDRESS/PBUFF;

  %*SASDOC======================================================================
  %* Check the DEBUG_FLAG macro variable before conditionally and temporarily
  %* turning off macro/debugging global options.
  %*====================================================================SASDOC*;

  %ISNULL(DEBUG_FLAG);
  %IF &DEBUG_FLAG_ISNULL %THEN %LET DEBUG_FLAG=N;

  %IF %UPCASE(%SUBSTR(&DEBUG_FLAG,1,1))^=Y %THEN %DO;
    %LET MPRINT=%SYSFUNC(GETOPTION(MPRINT));
    %LET MLOGIC=%SYSFUNC(GETOPTION(MLOGIC));
    %LET SYMBOLGEN=%SYSFUNC(GETOPTION(SYMBOLGEN));
    %LET SOURCE=%SYSFUNC(GETOPTION(SOURCE));
    %LET SOURCE2=%SYSFUNC(GETOPTION(SOURCE2));

    OPTIONS NOMPRINT NOMLOGIC NOSYMBOLGEN NOSOURCE NOSOURCE2;
  %END;


  %*SASDOC======================================================================
  %* Process the string of &SYSPBUFF to determine which recipients need to have
  %* email addresses identified.
  %*====================================================================SASDOC*;

  %let syspbuff=%sysfunc(compress(&syspbuff,()));

  %IF "&SYSPBUFF"^="" %THEN %DO;

    %*** Scope the macro variables... ***;

    %GLOBAL EMAIL_ADDRESS EMAIL_ADDRESS_FLG;
    %LOCAL  ID_ADDR NEW_LIB_FLG I E_ADDR;


    %*** Initialize... ***;

    %LET ID_ADDR=;
    %LET EMAIL_ADDRESS=;
    %LET EMAIL_ADDRESS_FLG=1;
    %LET NEW_LIB_FLG=0;
    %LET I=1;

    %*** Scan through &SYSPBUFF... ***;

    %DO %WHILE(%SCAN("&SYSPBUFF",&I," ,")^=%STR( ));

      %LET ID_ADDR=%SCAN("&SYSPBUFF",&I," ,");

      %IF ^%INDEX(&ID_ADDR,@) %THEN %DO;

        %LET ID_ADDR=%UPCASE(&ID_ADDR);

        %*SASDOC================================================================
        %* Check to see if the ADM_LKP library has already been defined. If not,
        %* then provide temporary access this library.
        %*==============================================================SASDOC*;

        %IF %SYSFUNC(LIBREF(ADM_LKP))^=0 %THEN %DO;
          %LET NEW_LIB_FLG=1;
/*          LIBNAME ADM_LKP '/DATA/sasprod1/Admin/auxtable';*/
/*modified for testing - Anita*/
		  LIBNAME ADM_LKP '/herc&sysmode/data/Admin/auxtable';
%END;


        %*SASDOC================================================================
        %* If the current ID/address string is a user ID, then find the users
        %* email address in ADM_LKP.ANALYTICS_USERS.
        %*==============================================================SASDOC*;

        %***** Get the email address and a record count for this user ID *****;

        %LET E_ADDR=;
        %LET E_ADDR_CNT=0;

        PROC SQL NOPRINT;
          SELECT DISTINCT TRIM(EMAIL), COUNT(*) INTO :E_ADDR, :E_ADDR_CNT
          FROM ADM_LKP.ANALYTICS_USERS
          WHERE UPCASE(QCP_ID)="&ID_ADDR";
        QUIT;


        %***** Report the query results *****;

        %IF &E_ADDR_CNT=1 %THEN %PUT NOTE: (&SYSMACRONAME): USERID &ID_ADDR has email address: %TRIM(&E_ADDR).;
        %ELSE %IF &E_ADDR_CNT=0 %THEN %PUT ERROR: (&SYSMACRONAME): USERID &ID_ADDR was not found in ADM_LKP.ANALYTICS_USERS.;
        %ELSE %PUT ERROR: (&SYSMACRONAME): USERID &ID_ADDR has multiple records in ADM_LKP.ANALYTICS_USERS.;

        %IF &E_ADDR_CNT^=1 %THEN %LET EMAIL_ADDRESS_FLG=0;


        %***** Clear the ADM_LKP libref if it was defined by this macro *****;

        %IF &NEW_LIB_FLG %THEN %STR(LIBNAME ADM_LKP CLEAR);
      %END;
      %ELSE %LET E_ADDR=&ID_ADDR;


      %*SASDOC==================================================================
      %* Build the final &EMAIL_ADDRESS string of email addresses.
      %*================================================================SASDOC*;

      %LET EMAIL_ADDRESS=%TRIM(%LEFT(&EMAIL_ADDRESS)) %CMPRES(&E_ADDR);

      %LET I=%EVAL(&I+1);
    %END;
  %END;
  %ELSE %PUT ERROR: (&SYSMACRONAME): No parameters were specified.;


  %*SASDOC======================================================================
  %* Report the final status/value of &EMAIL_ADDRESS.
  %*====================================================================SASDOC*;

  %IF &EMAIL_ADDRESS_FLG %THEN %PUT NOTE: (&SYSMACRONAME): EMAIL_ADDRESS has been set to: &EMAIL_ADDRESS..;
  %ELSE %DO;
    %LET EMAIL_ADDRESS=;
    %PUT ERROR: (&SYSMACRONAME): 1 or more users were not found.  Please double-check the USERIDs and resubmit.;
  %END;


  %*SASDOC======================================================================
  %* Check the DEBUG_FLAG macro variable before conditionally and temporarily
  %* turning resetting global options.
  %*====================================================================SASDOC*;

  %IF &DEBUG_FLAG=N %THEN %DO;
    OPTIONS &MPRINT &MLOGIC &SYMBOLGEN &SOURCE &SOURCE2;
  %END;

%MEND GET_EMAIL_ADDRESS;
