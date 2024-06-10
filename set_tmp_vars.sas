/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Friday, June 25, 2004      TIME: 03:19:33 PM
   PROJECT: macros
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Thursday, June 17, 2004      TIME: 04:42:23 PM
   PROJECT: macros
   PROJECT PATH: M:\qcpi514\Caremark\EG_projects\EG_projects_20\macros.seg
---------------------------------------- */
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  set_tmp_vars.sas (macro)
|
| LOCATION: /PRG/sasprod1/sas_macros
|
| PURPOSE:  This macro sets the value of the macro variable DB2_tmp for temporary 
|			DB2 schema. It requieres two global macro variable: &sysmode and &job_id. 
|			The first one is set by macro %set_sysmode and the second should be reserved in the
I			metadata tool and then defined in the parameter file before the macro %set_tmp_var
|			is called. The values of DB2_tmp variable are assigned as follows:
|				For production (&sysmode=prod)
|			      	DB2_tmp=P_&job_id.
|				For system test (&sysmode=testS)
|			   		DB2_tmp=T_&job_id.
|				For development &sysmode=test
|			  		DB2_tmp=&USER.
|
|EXAMPLE: 	%set_tmp_vars;
|          LIBNAME &DB2_tmp DB2 DSN=&UDBSPRP SCHEMA=&DB2_tmp DEFER=YES;
+--------------------------------------------------------------------------------
| HISTORY:  Jun2004 -  Yury Vilk - Original.
+------------------------------------------------------------------------HEADER*/
%MACRO set_tmp_vars;
%GLOBAL sysparm sysmode prg_root data_root rpt_root adhoc_root HERCULES PP job_id DB2_TMP;   
     %IF %length(&job_id)=0   %THEN 
								%DO; 
				%PUT ERROR: The requiered macro variable job_id is not defined.;	
								%END;
  %ELSE 
		%DO;
       %IF &sysmode.=prod %THEN 
			%DO;
        %LET DB2_tmp=P_&job_id.; 
            %END;
       %ELSE %IF &sysmode.=testS %THEN 
			%DO;
		%LET DB2_tmp=T_&job_id. ;
           %END;
      %ELSE %DO;
           %LET DB2_tmp=&USER. ;
            %END;
      %END;
%PUT NOTE: %NRSTR(&DB2_TMP)=&DB2_TMP;
%MEND /* set_tmp_vars */;

/*
%LET job_id=1;
%LET sysmode=prod;
 %set_tmp_vars ;
%LET sysmode=testS;
 %set_tmp_vars ;
%LET sysmode=test;
 %set_tmp_vars ;
*/
