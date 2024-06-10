/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  DROP_SAS_DSN.sas
|
| LOCATION: /PRG/sas&sysmode.1/hercules/macros
|
| PURPOSE:  Drop SAS Dataset
|
|
| INPUT:    MACRO VARIABLE DSN (which be reference to sas dataset name) 
|			
|
| OUTPUT:   Dropped sas dataset
|
+-------------------------------------------------------------------------------
| HISTORY:  Suresh - Hercules Version  2.1.01
|          
+-----------------------------------------------------------------------HEADER*/
%MACRO DROP_SAS_DSN(DSN = );

	%IF %SYSFUNC(EXIST(&DSN)) %THEN %DO;
		PROC SQL; 
			DROP TABLE &DSN.;
		QUIT;
	%END;

%MEND DROP_SAS_DSN;

