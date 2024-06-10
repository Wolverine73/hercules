/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  isnull.sas (macro)
|
| LOCATION: /PRG/sasprod1/sas_macros
|
| PURPOSE:  This macro checks the specified macro variables for null values.
|           ISNULL is assigned to the total number of macro variables with null
|           values.  This macro was designed initially for the purpose of
|           checking macro parameters.
|
| INPUT:    &MVARNAME - (positional) The macro variable names to check for null
|                                    values.
|
|           <flags>     - Individual macro variable flags are created to retain
|                         the ISNULL result for that particular variable.
|
| OUTPUT:   &ISNULL    - Number of macro variables found to be null.
|
| CALLED PROGRAMS:
|
|           %MVAREXIST - To determine whether macro variables exist prior to
|                        the check for nulls.  If any macro variable does not
|                        exist, it is noted and then added to the null count.
|
| EXAMPLE USAGE:
|
|           %ISNULL(TABL_NAME_IN, TABL_NAME_OUT);
|           %if ^&ISNULL %then
|             %put ERROR: (FOOBAR): &ISNULL parameter(s) are missing.
|
+-------------------------------------------------------------------------------
| HISTORY:  01OCT2003 - T.Kalfas  - Original.
|
+-----------------------------------------------------------------------HEADER*/

%macro ISNULL(MVARNAME)/PBUFF;

  %let MVARNAME=%upcase(%sysfunc(compress(&SYSPBUFF,%str(()))));

  %*SASDOC======================================================================
  %* Determine whether the macro variables are null (or %str()).  If the macro
  %* variable does not exist, it is considered to be NULL.  All "null" macro
  %* variables are tallied in &ISNULL.
  %*====================================================================SASDOC*;

  %if &MVARNAME^= %then %do;

    %*** Scope the macro variables... ***;
    %global ISNULL;
    %local  MVAR I;

    %*** Initialize... ***;
    %let ISNULL=0;
    %let I=1;

    %*** Process every macro variable name provided... ***;
    %do %while(%scan("&MVARNAME",&I," ,")^=%str( ));

      %let MVAR=%scan("&MVARNAME",&I," ,");

      %global &MVAR._ISNULL;
      %let &MVAR._ISNULL=0;		%*initialize;

      %*** If the var exists, then check to see if it is null... ***;
      %MVAREXIST(&MVAR);
      %if &MVAREXIST %then %let &MVAR._ISNULL=%eval(%trim("&&&MVAR")="");
                     %else %let &MVAR._ISNULL=1;

      %*** If the var is null, then say so and increment &ISNULL... ***;
      %if &&&MVAR._ISNULL %then %do;
        %let ISNULL=%eval(&ISNULL+1);
        %if &MVAREXIST %then %put NOTE: (ISNULL): &MVAR is NULL.;
                       %else %put NOTE: (ISNULL): &MVAR is not defined and is considered to be NULL.;
      %end;
      %else %put NOTE: (ISNULL): &MVAR is NOT NULL.;

      %let I=%eval(&I+1);
    %end;
  %end;
  %else %put ERROR: (ISNULL): NO MACRO VARIABLE NAME SPECIFIED.;
%mend ISNULL;
