/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  ischar.sas (macro)
|
| LOCATION: /PRG/sasprod1/sas_macros
|
| PURPOSE:  This macro checks the specified macro variables for character
|           values.  ISCHAR is assigned to the total number of macro variables
|           with character values.  This macro was designed initially for the
|           purpose of checking macro parameters.
|
| INPUT:    &MVARNAME - (positional) The macro variable names to check for
|                                    character values.
|
|           <flags>     - Individual macro variable flags are created to retain
|                         the ISCHAR result for that particular variable.
|
| OUTPUT:   &ISCHAR   - Number of macro variables found to be character.
|
| CALLED PROGRAMS:
|
|           %ISNULL   - To determine whether macro variables exist prior to
|                       the check for character values.  If any macro variable
|                       does not exist, it is noted and then added to the
|                       &ISCHAR count.
|
| EXAMPLE USAGE:
|
|           %ISCHAR(PROGRAM_ID, INITIATIVE_ID, PHASE_SEQ_NB);
|           %IF &ISCHAR %THEN
|             %PUT ERROR: (FOOBAR): Key parameters must be numeric.;
|
+-------------------------------------------------------------------------------
| HISTORY:  01OCT2003 - T.Kalfas  - Original.
|
+-----------------------------------------------------------------------HEADER*/

%MACRO ISCHAR(MVARNAME)/PBUFF;

  %LET MVARNAME=%UPCASE(%SYSFUNC(COMPRESS(&SYSPBUFF,%STR(()))));

  %*SASDOC======================================================================
  %* Determine whether the macro variables are character.  If the macro
  %* variable does not exist or is null, it is not considered to be character.
  %* All character macro variable values are tallied in &ISCHAR.
  %*====================================================================SASDOC*;

  %IF &MVARNAME^= %THEN %DO;

    %*** Scope the macro variables... ***;

    %GLOBAL ISCHAR;
    %LOCAL  MVAR I;

    %*** Initialize... ***;

    %LET ISCHAR=0;
    %LET I=1;

    %*** Process every macro variable name provided... ***;

    %DO %WHILE(%SCAN("&MVARNAME",&I," ,")^=%STR( ));

      %LET MVAR=%SCAN("&MVARNAME",&I," ,");

      %GLOBAL &MVAR._ISCHAR;
      %LET &MVAR._ISCHAR=0;

      %*** If the var exists, then check to see if it is character... ***;

      %ISNULL(&MVAR);
      %IF ^&ISNULL %THEN %LET &MVAR._ISCHAR=%EVAL(%DATATYP(&&&MVAR)=CHAR);

      %*** Report the findings to the log, then increment &ISCHAR if necessary... ***;

      %IF &&&MVAR._ISCHAR %THEN %DO;
        %LET ISCHAR=%EVAL(&ISCHAR+1);
        %PUT NOTE: (ISCHAR): &MVAR is CHARACTER.;
      %END;
      %ELSE %DO;
        %IF &MVAREXIST & ^&ISNULL %THEN %PUT NOTE: (ISCHAR): &MVAR is NOT CHARACTER.;
        %ELSE %IF ^&MVAREXIST %THEN %PUT NOTE: (ISCHAR): &MVAR is NOT DEFINED and is considered to be NOT CHARACTER.;
        %ELSE %IF &ISNULL %THEN %PUT NOTE: (ISCHAR): &MVAR is NULL and is considered to be NOT CHARACTER.;
      %END;

      %LET I=%EVAL(&I+1);
    %END;
  %END;
  %ELSE %PUT ERROR: (ISCHAR): NO MACRO VARIABLE NAME SPECIFIED.;
%MEND ISCHAR;
