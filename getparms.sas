/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  getparms.sas (macro)
|
| LOCATION: /PRG/sasprod1/sas_macros
|
| PURPOSE:  This macro parses the &SYSPARM parameter variable.
|
| ASSUMPTIONS:
|
|   The &SYSPARM is assigned in the following manner:
|
|     <delimiter><variable1>=<value1>[<delimiter><variable2>=<value2>...]
|
|     NOTE: The reserved variable name, PARMFILE, may also be specified
|           as a method for providing additional parameters within the
|           file specified.  The file must exist and must use the same
|           delimiter between the labeled pairs as was used in &SYSPARM.
|           Multiple pairs can reside on each line of the file.  It is 
|           not necessary to specify a delimiter on a line containing
|           only one labeled pair.
|
| MACRO PARAMETERS:
|
|           &SYSPARM = The name of the macro variable to which parameters
|                      are assigned by the operating system upon invocation
|                      of SAS via the -sysparm option.
|
| INPUT:    &PARMFILE = (optional) The name of a file that contains additional
|                       labeled pairs for parsing.
|
| OUTPUT:   (instream) Set of macro variables and assignments as specified in 
|                      the &SYSPARM (and &PARMFILE).
|
+--------------------------------------------------------------------------------
| HISTORY:  18SEP2003 - T.Kalfas  - Original.
|           13OCT2003 - T.Kalfas  - Modified to accept '_' as a first character
|                                   of a macro variable name, and to protect the
|                                   preceding space in &SYSPARM during the macro
|                                   function processing.
+------------------------------------------------------------------------HEADER*/

%MACRO GETPARMS();
options mlogic mprint symbolgen;
  %LOCAL DSID VAREXIST RC PARMS PARM DLM PFILE MVAR MVAL _I;

  %*SASDOC====================================================================
  %* Check for the existence of the &SYSPARM macro variable.  SCL functions
  %* are used here in order to leave the calling programs datastep or proc
  %* intact.
  %*==================================================================SASDOC*;

  %LET DSID=%SYSFUNC(OPEN(SASHELP.VMACRO(WHERE=(NAME='SYSPARM'))));
  %LET VAREXIST=%EVAL(%SYSFUNC(FETCH(&DSID))+1);
  %LET RC=%SYSFUNC(CLOSE(&DSID));

  %IF &VAREXIST=1 AND %BQUOTE(&SYSPARM)^=%STR() %THEN %DO;
    
    %LET PARMS=%BQUOTE(&SYSPARM);

    %*SASDOC==================================================================
    %* Identify the delimiter (first char) of the &SYSPARM string.  The 
    %* delimiter is assumed not to be a letter or an underscore, otherwise 
    %* default delimiters are used for parsing (scan). 
    %*================================================================SASDOC*;

    %IF ^%INDEX(ABCDEFGHIJKLMNOPQRSTUVWXYZ_, %BQUOTE(%UPCASE(%SUBSTR(%STR(&PARMS),1,1))))
    %THEN %DO;
      %LET DLM=%BQUOTE(%SUBSTR(%STR(&PARMS),1,1));
      %LET PARMS=%SUBSTR(%STR(&PARMS),2);
    %END;
    %ELSE %LET DLM=%BQUOTE( ,~|!@#^*-+); 


    %*SASDOC==================================================================
    %* Parse the &SYSPARM string, making the appropriate macrovar assignments.  
    %*================================================================SASDOC*;

    %LET PFILE=0;  %***** This is a flag indicating the existence of the PARMFILE parm. ;

    %LET _I=1;
    %DO %WHILE (%BQUOTE(%QSCAN(%STR(&PARMS),&_I,"&DLM"))^=%STR()); 
      %LET PARM=%BQUOTE(%QSCAN(%STR(&PARMS),&_I,"&DLM"));
      %LET MVAR=%UPCASE(%TRIM(%LEFT(%QSCAN(%STR(&PARM),1,=))));
      %LET MVAL=%TRIM(%LEFT(%QSCAN(%STR(&PARM),2,=)));
      %IF %UPCASE(&MVAR)=PARMFILE %THEN %LET PFILE=1; 
      %GLOBAL &MVAR;
      %LET %TRIM(%LEFT(&MVAR)) = &MVAL;
      %PUT NOTE: (GETPARMS): Parameter: &MVAR = &MVAL;
      %LET _I=%EVAL(&_I+1);
    %END;


    %*SASDOC==================================================================
    %* Check for the &PARMFILE parameter.  If it exists then process the file
    %* to get any additional macro parameter name/value pairs.
    %*================================================================SASDOC*;

    %IF &PFILE %THEN %DO;
      %IF %SYSFUNC(FILEEXIST(&PARMFILE)) %THEN %DO;
        DATA _NULL_;
	  FORMAT MVAR $32. MVAL $200.;
          INFILE "&PARMFILE" TRUNCOVER;
          INPUT XLINE & $CHAR200.;
          IF XLINE^='' THEN DO;
            I=1;
            DO WHILE (SCAN(XLINE,I,"&DLM")^=''); 
              PARM=SCAN(XLINE,I,"&DLM");
	      MVAR=UPCASE(TRIM(LEFT(SCAN(PARM,1,'='))));
	      MVAL=TRIM(SCAN(PARM,2,'='));
	      CALL EXECUTE('%global '||MVAR||';');
	      CALL EXECUTE('%let '||MVAR||'='||MVAL||';');
	      PUT 'NOTE: (GETPARMS): Parameter: ' MVAR '= ' MVAL;
	      I=I+1;
	    END;
          END;
        RUN;
      %END;
      %ELSE %PUT ERROR: (GETPARMS): Specified PARMFILE (&PARMFILE) does not exist.;
    %END;
  %END; 
  %ELSE %PUT NOTE: (GETPARMS): Macro variable SYSPARM contains no parameters.;
%MEND GETPARMS;
