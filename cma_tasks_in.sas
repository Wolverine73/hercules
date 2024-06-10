
*SASDOC-------------------------------------------------------------------------
| This program is an "include" file for the purpose of defining a standard
| SAS environment for Hercules - CMA tasks.
+-----------------------------------------------------------------------SASDOC*;
options mlogic mlogicnest mprint mprintnest symbolgen source2;
%LET PRIMARY_PROGRAMMER_EMAIL=&USER;

%add_to_macros_path(New_Macro_path=/herc&sysmode/prg/hercules/reports/87,New_path_position=FRONT);
%add_to_macros_path(New_Macro_path=/herc&sysmode/prg/hercules/reports/87/macros,New_path_position=FRONT);
