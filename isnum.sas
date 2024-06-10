/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  isnum.sas (macro)
|
| LOCATION: /PRG/sasprod1/sas_macros
|
| PURPOSE:  This macro checks the specified macro variables for numeric values.
|           ISNUM is assigned to the total number of macro variables with
|           numeric values.  This macro was designed initially for the purpose
|           of checking macro parameters.
|
| INPUT:    &MVARNAME - (positional) The macro variable names to check for
|                                    numeric values.
|
|           <flags>     - Individual macro variable flags are created to retain
|                         the ISNUM result for that particular variable.
|
| OUTPUT:   &ISNUM    - Number of macro variables found to be numeric.
|
| CALLED PROGRAMS:
|
|           %ISNULL   - To determine whether macro variables exist prior to
|                       the check for numeric values.  If any macro variable
|                       does not exist, it is noted and then added to the
|                       &ISNUM count.
|
| EXAMPLE USAGE:
|
|           %ISNUM(PROGRAM_ID, INITIATIVE_ID, PHASE_SEQ_NB);
|           %IF &ISNUM^=3 %THEN
|             %PUT ERROR: (FOOBAR): Key parameters must be numeric.;
|
+-------------------------------------------------------------------------------
| HISTORY:  01OCT2003 - T.Kalfas  - Original.
|
+-----------------------------------------------------------------------HEADER*/

%MACRO ISNUM(MVARNAME)/PBUFF;

  %LET MVARNAME=%UPCASE(%SYSFUNC(COMPRESS(&SYSPBUFF,%STR(()))));

  %*SASDOC======================================================================
  %* Determine whether the macro variables are numeric.  If the macro
  %* variable does not exist or is null, it is not considered to be numeric.
  %* All numeric macro variable values are tallied in &ISNUM.
  %*====================================================================SASDOC*;

  %IF &MVARNAME^= %THEN %DO;

    %*** Scope the macro variables... ***;

    %GLOBAL ISNUM;
    %LOCAL  MVAR I;

    %*** Initialize... ***;

    %LET ISNUM=0;
    %LET I=1;

    %*** Process every macro variable name provided... ***;

    %DO %WHILE(%SCAN("&MVARNAME",&I," ,")^=%STR( ));

      %LET MVAR=%SCAN("&MVARNAME",&I," ,");

      %GLOBAL &MVAR._ISNUM;
      %LET &MVAR._ISNUM=0;

      %*** If the var exists, then check to see if it is null... ***;

      %ISNULL(&MVAR);
      %IF ^&ISNULL %THEN %LET &MVAR._ISNUM=%EVAL(%DATATYP(&&&MVAR)=NUMERIC);

      %*** Report the findings to the log, then increment &ISNUM if necessary... ***;

      %IF &&&MVAR._ISNUM %THEN %DO;
        %LET ISNUM=%EVAL(&ISNUM+1);
        %PUT NOTE: (ISNUM): &MVAR is NUMERIC.;
      %END;
      %ELSE %DO;
        %IF ^&MVAREXIST %THEN %PUT NOTE: (ISNUM): &MVAR is NOT DEFINED and is considered to be NOT NUMERIC.;
        %ELSE %IF &ISNULL %THEN %PUT NOTE: (ISNUM): &MVAR is NULL and is considered to be NOT NUMERIC.;
        %ELSE %PUT NOTE: (ISNUM): &MVAR is NOT NUMERIC.;
      %END;

      %LET I=%EVAL(&I+1);
    %END;	%*DO WHILE;
  %END;		%*&MVARNAME^=;
  %ELSE %PUT ERROR: (ISNUM): NO MACRO VARIABLE NAME SPECIFIED.;
%MEND ISNUM;
