/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  drop_table.sas (macro)
|
| LOCATION: /PRG/sastest1/hercules/87/macros
|
| PURPOSE:  To conditionally drop a DB2 table (i.e., only if it already exists).
|           This macro can be called from within a PROC SQL block in which a
|           DB2 connection has already been established.  A more sophisticated
|           standalone macro, DROP_DB2_TABLE, exists in /PRG/sasprod1/sas_macros
|           but it does not allow for calls from w/in a PROC.
|
| INPUT:    &TBL_NAME (parameter for the DB2 table to be dropped)
|
| OUTPUT:   None.
|
+--------------------------------------------------------------------------------
| HISTORY:  25AUG2003 - T.Kalfas  - Original.
|           09OCT2003 - T.Kalfas  - Modified to use the SYSPROCNAME macro var to
|                                   determine whether call is from open code or
|                                   proc.  If "open code", then the drop stmt is
|                                   wrapped in its own PROC SQL block.
|           15OCT2003 - T.Kalfas  - Modified to store SYSPROCNAME in OPEN_CODE_FL
|                                   since this value can change if a PROC SQL is
|                                   initiated by this program (the "QUIT" was
|                                   not being submitted to close the SQL block).
+------------------------------------------------------------------------HEADER*/

%MACRO DROP_TABLE(TBL_NAME);
  %LOCAL OPEN_CODE_FL;
  %LET OPEN_CODE_FL=&SYSPROCNAME;

  %IF %SYSFUNC(EXIST(&TBL_NAME)) %THEN %DO;
    %IF "&OPEN_CODE_FL"="" %THEN %STR(PROC SQL NOPRINT;);
      DROP TABLE &TBL_NAME;
    %IF "&OPEN_CODE_FL"="" %THEN %STR(QUIT;);
  %END;
  %ELSE %PUT NOTE: (DROP_TABLE): Table %UPCASE(&TBL_NAME) does not exist...no drop necessary.;
%MEND DROP_TABLE;
