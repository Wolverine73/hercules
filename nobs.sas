/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  nobs.sas (macro)
|
| LOCATION: /PRG/sasprod1/sas_macros
|
| PURPOSE:  This macro determines the number of rows/observations in the
|           specified dataset, view, or DB2 table.  This macro was designed
|           to facilitate conditional processing within SAS macros.
|
| INPUT:    &TBL_NAME - (positional) The dataset/view/DB2-table name for which
|                       to determine the number of observations.  This can be
|                       a one- or two-level name for a SAS dataset, SAS view,
|                       or DB2 table name (i.e., for which a DB2 LIBREF has
|                       been defined).
|
| OUTPUT:   &NOBS     - Number of rows/observations for &TBL_NAME.  This value
|                       is set to -1 when &TBL_NAME does not exist or cannot be
|                       opened.
|
| EXAMPLE USAGE:
|
|           %LET DSN=FOOBAR.MYDATA;
|           %NOBS(&DSN);
|
|           %IF &NOBS %THEN %DO;
|           .
|           .
|           .
|           %END;
|           %ELSE PUT ERROR: (FOOBAR): &DSN contains no observations.;
|
+-------------------------------------------------------------------------------
| HISTORY:  08OCT2003 - T.Kalfas  - Original.
|           15OCT2003 - T.Kalfas  - Modified to allow dataset options, e.g.,
|                                   "where" can be used to check the number of
|                                   observations in a subset of the table.
+-----------------------------------------------------------------------HEADER*/

%MACRO NOBS(TBL_NAME);

  %*SASDOC======================================================================
  %* Scope the macro variables.
  %*====================================================================SASDOC*;

  %global nobs
          debug_flag;

  %local  _reset_opts
          _symbolgen
          _mprint
          _mlogic
          _dsname
          _dsopts
          _dswhere_flag
          _dsid
          _varid
          _memtype_id
          _memtype
          _engine_id
          _engine
          _lib
          _dsn;


  %*SASDOC======================================================================
  %* Check the DEBUG_FLAG and set the debug macro options accordingly.
  %*====================================================================SASDOC*;

  %let _reset_opts=0;

  %if &debug_flag^= %then %do;
    %if ^%index(%str(Y1), %upcase(%substr(&debug_flag,1,1))) %then %do;
      %let _reset_opts=1;
      %let _symbolgen=%sysfunc(getoption(symbolgen));
      %let _mprint=%sysfunc(getoption(mprint));
      %let _mlogic=%sysfunc(getoption(mlogic));
      %let _notes=%sysfunc(getoption(notes));
      options nosymbolgen nomprint nomlogic nonotes;
    %end;
  %end;


  %*SASDOC======================================================================
  %* Determine whether dataset options are part of &TBL_NAME.
  %*====================================================================SASDOC*;

  %let _dsname=%bquote(&tbl_name);
  %let _dsopts=;
  %let _dswhere_flag=0;

  %if %index(%bquote(&tbl_name),%str(%()) %then %do;
    %let _dsname=%scan(%bquote(&tbl_name),1,%str(%());
    %let _dsopts=%substr(%bquote(&tbl_name), %index(%bquote(&tbl_name),%str(%()));
    %let _dswhere_flag=%eval(%index(%upcase(%bquote(&_dsopts),WHERE))>0);
  %end;


  %*SASDOC======================================================================
  %* Determine whether the table exists.
  %*====================================================================SASDOC*;

  %let nobs=-1;

  %if %sysfunc(exist(&_dsname)) or %sysfunc(exist(&_dsname, view)) %then %do;

    %*SASDOC====================================================================
    %* Determine whether the table can be opened.  If it can, then grab the
    %* number of observations from the SAS dataset header information (this is
    %* the most efficient method).
    %*==================================================================SASDOC*;
    %let _dsid=%sysfunc(open(&tbl_name));

    %if &_dsid>0 %then %do;
      %let nobs=%sysfunc(attrn(&_dsid,nobs));
      %let _dsid=%sysfunc(close(&_dsid));
    %end;


    %*SASDOC====================================================================
    %* If the table cannot be opened by SAS, then it is most likely a DB2 table
    %* and &NOBS has been left at -1.
    %*
    %* - OR -
    %*
    %* If the table is a SAS view, then the &NOBS has been set to -1 (via the
    %* the call to ATTRN).
    %*
    %* - OR -
    %*
    %* If the table contains a subsetting "where" option, then the &NOBS is not
    %* the number of records in that subset (this is a limitation of the NOBS
    %* ATTRN specification).
    %*
    %* In any case, further processing is necessary to determine the number of
    %* observations/rows in the table:
    %*
    %*   (1) Confirm that the table is in fact a VIEW or DB2-Table.
    %*   (2) Determine where the %NOBS macro was called, i.e., open code,
    %*       datastep or proc.
    %*   (3) If the call was not made from open code, then report that the table
    %*       could not be opened.
    %*   (4) Otherwise, determine the number of observations using PROC SQL
    %*       (unfortunately the least efficient manner, but unavoidable).
    %*
    %*==================================================================SASDOC*;

    %if &nobs<=0 or &_dswhere_flag %then %do;
      %let _lib=%trim(%scan(&syslast,1));
      %let _ds =%trim(%scan(&syslast,2));

      %let _dsid=%sysfunc(close(&_dsid));
      %let _dsid=%sysfunc(open(sashelp.vmember(where=(libname="&_lib" and memname="&_dsn"))));

      %let _memtype_id=%sysfunc(varnum(&_dsid, MEMTYPE));
      %let _memtype   =%sysfunc(getvarc(&_dsid, &_memtype_id));

      %let _engine_id =%sysfunc(varnum(&_dsid, ENGINE));
      %let _engine    =%sysfunc(getvarc(&_dsid, &_engine_id));

      %if &_dswhere_flag or &_memtype^=DATA or &_engine=DB2 %then %do;
        %if "&sysprocname"="" %then %do;
          proc sql noprint;
            select count(*) into :nobs
            from   &tbl_name;  *** <-- &TBLNAME is used here to include any dataset opts ***;
          quit;
        %end;
        %else %do;
          %if &_memtype^=DATA or &_engine=DB2 %then
            %put ERROR: (NOBS): %upcase(&_dsname) is not a SAS dataset, and;
          %if &_dswhere_flag %then
            %put ERROR: (NOBS): %upcase(&_dsname) contains a where= option, and;
          %put ERROR: (NOBS): %nrstr(%NOBS) is being called from within a &SYSPROCNAME..;
        %end;
      %end;
    %end;


    %*SASDOC====================================================================
    %* Report the number of observations for &TBL_NAME to the log.
    %*==================================================================SASDOC*;

    %if &nobs>=0 %then %do;
      %put NOTE: (NOBS): %upcase(&tbl_name) has %trim(%left(&nobs)) observation(s).;
      %let _dsid=%sysfunc(close(&_dsid));
    %end;
  %end;
  %else %put ERROR: (NOBS): Table %upcase(&tbl_name) does not exist.;


  %*SASDOC======================================================================
  %* Reset the macro debugging options, if necessary.
  %*====================================================================SASDOC*;

  %if &_reset_opts %then %do;
    options &_symbolgen &_mprint &_mlogic &_notes;
  %end;
%mend nobs;
