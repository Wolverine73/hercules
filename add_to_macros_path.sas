/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Wednesday, November 12, 2003      TIME: 05:37:44 PM
   PROJECT: macros
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Tuesday, October 07, 2003      TIME: 06:48:17 PM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */

/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  add_to_macros_path
|
| LOCATION: /PRG/sastest1/sas_macros
|
| PURPOSE:  Add dirictories to the autocal macro path. 
|           If New_Macro_path is not specified then the macro path is reset to the
|  			default: ('!SASROOT/sasautos' '/PRG/sastest1/sas_macros').
|			The parameter New_Macro_path except list of directories separated by blank.  
|           The parameter New_path_position determines whether new directories are
|			added at the end or at the begining	of the existing path. The allowed
|			values are: FRONT and BACK. The default value is BACK.
|			
|           If the directory does not exist or if it is already in
|			the autocal path then the directory is ignored and the 
|		    corresponding message is printed to the log.
|
| INPUT:    Macro parameters:  New_Macro_path and New_path_position
| OUTPUT:   Updates value of autocal macro path
|
| USAGE EXAMPLES: 
| %add_to_macros_path; * Resets macro path to the initial value;
| %add_to_macros_path(New_Macro_path=/PRG/sastest1/hercules/macros);
| %add_to_macros_path(New_Macro_path=/PRG/sastest1/hercules/macros /PRG/sastest1/hercules/90/macros);
| %add_to_macros_path(New_Macro_path=/PRG/sastest1/hercules/macros /PRG/sastest1/hercules/90/macros, 
|					  New_path_position=FRONT);   
|
+--------------------------------------------------------------------------------
| HISTORY:  Written 05Oct2001 Yury Vilk
			MOdified 07Oct2003
|
+------------------------------------------------------------------------HEADER*/
%MACRO add_to_macros_path(New_Macro_path= ,New_path_position=BACK);
%GLOBAL DEBUG_FLAG ;
%IF &DEBUG_FLAG NE Y %THEN OPTIONS NONOTES;;

%LOCAL pos_new;
 %LET pos_new=0;

DATA _NULL_;
 LENGTH Macro_path $ 1000 New_Macro_path $ 1000 MESSAGE $ 500 New_path_position $ 5
		New_Macro_path_component $ 1000 NOTE $ 1;

  NOTE='';
  Macro_path=LEFT(GETOPTION('SASAUTOS'));
  New_Macro_path=TRIM(LEFT(SYMGET('New_Macro_path')));
  New_path_position=UPCASE(DEQUOTE(TRIM(LEFT(SYMGET('New_path_position')))));

  IF New_Macro_path='' THEN Macro_path="('!SASROOT/sasautos' '/PRG/sastest1/sas_macros')";
  ELSE
  		DO;
   i=1;
DO WHILE(SCAN(New_Macro_path,i,' ') NE ' ');
  New_Macro_path_component=DEQUOTE(SCAN(New_Macro_path,i,' '));
  pos_new=INDEX(Macro_path,TRIM(New_Macro_path_component));
  dir_exist=FILEEXIST(TRIM(New_Macro_path_component));

  IF dir_exist=0 
   THEN DO;
	Message= "Directory " || TRIM(New_Macro_path_component) 
			  || " does not exist. Macro path will not be updated.";
	PUT NOTE=Message;
	    END;

  IF pos_new > 0 
   THEN DO;
	Message="Directory " || TRIM(New_Macro_path_component) || " is already in the macro path. Macro path will not be updated.";
	PUT NOTE=Message;
		END;

  IF pos_new=0 AND dir_exist THEN 
				  DO;
  pos=INDEX(Macro_path,')');
 IF New_path_position='FRONT'
  THEN 	Macro_path ='(' || QUOTE(TRIM(New_Macro_path_component)) || ' ' 
						|| SUBSTR(TRIM(Macro_path),2);
  ELSE  SUBSTR(Macro_path,pos)=' ' || QUOTE(TRIM(New_Macro_path_component)) || ')';
                  END;
   i+1;
END; /* End of WHILE loop */

	   END;	/* End of do group for New_Macro_path ^='' */

  CALL SYMPUT('Macro_path',TRIM(Macro_path));
  CALL SYMPUT('Message',TRIM(Message));
 RUN;
  OPTIONS MAUTOSOURCE SASAUTOS =&Macro_path.  MRECALL;;	
;
 PROC OPTIONS OPTION=SASAUTOS;
   RUN;
   QUIT;

OPTIONS NOTES;
%MEND;


