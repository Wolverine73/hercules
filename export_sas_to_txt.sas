/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Monday, January 05, 2004      TIME: 11:54:19 AM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Wednesday, September 10, 2003      TIME: 06:53:56 PM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */
/* HISTORY:           
       09AUG2010 - D. PALMER Changed length of field FORMAT from 10 char to 11 char
                   to accomodate an informat greater than 10 char. 
------------------------------------------------------------------------------------*/

  %let DEBUG_FLAG=Y;
  %MACRO export_sas_to_txt(tbl_name_in=,tbl_name_out=,L_file=,File_type_out='ASC',Col_in_fst_row=N,obs=MAX,str_Where_in=" ",select=1,tbl_option_in=);
    %GLOBAL ERR_CD  MESSAGE;

	%LET err_cd=0;

  %IF &DEBUG_FLAG= %THEN %LET DEBUG_FLAG=N;

  %IF &DEBUG_FLAG=Y %THEN 
					%DO;
					 OPTIONS NOTES;
					 OPTIONS MLOGIC MPRINT SYMBOLGEN SOURCE2;
					%END;
  %ELSE %DO;
  OPTIONS NONOTES ;
  OPTIONS NOMLOGIC NOMPRINT NOSYMBOLGEN NOSOURCE2;
  		%END;

 %LET File_type=&File_type_out;
 %LET pos=%INDEX(&Tbl_name_in,.);
 %LET Schema=%SUBSTR(&Tbl_name_in,1,%EVAL(&pos-1));
 %LET Tbl_name_sh=%SUBSTR(&Tbl_name_in,%EVAL(&pos+1));

 %LET Fields_numb=1;		/* Initial values that will be overwriten latter */
 %LET Field_name1= ;
 %LET Field_del1= ;

%IF &L_file= %THEN %LET L_File="&tbl_name_in..lat";

DATA _NULL_ ;
 LENGTH str_Where_in $ 32000;
 str_Where_in=&str_Where_in;
 IF str_Where_in NE '' THEN str_Where_in='WHERE=(' || TRIM(LEFT(str_Where_in)) || ')';
 CALL SYMPUT('str_Where_in',TRIM(str_Where_in));
 * PUT _ALL_;
RUN;
  
 %IF &SYSERR NE 0 %THEN %DO; 
				  	%LET err_cd=1; 
				 	 %GOTO exit;
						%END;

 PROC CONTENTS DATA=&Tbl_name_in.(OBS=MAX &tbl_option_in.)
              OUT=work._&Tbl_name_sh.(COMPRESS=NO KEEP=MEMNAME NAME LENGTH
                                  FORMAT INFORMAT VARNUM TYPE FORMATL INFORML
                                  FORMATD INFORMD) NOPRINT;
  RUN;
  QUIT;

 %IF &SYSERR NE 0 %THEN %DO; 
				  	 %LET err_cd=1; 
				 	 %GOTO exit;
						%END;
/* 09Aug2010 D.Palmer Changed format length from 10 char to 11 char */
DATA work._&Tbl_name_sh.1 (COMPRESS=NO);
 LENGTH format $ 11;
 SET work._&Tbl_name_sh.;


IF format='$' THEN format='$CHAR';
IF formatl=. OR formatl=0 THEN
DO;
          IF type=1 THEN DO;
                      format='BEST12.';
                      formatl=12;
                         END;

                  ELSE                    DO;
                          format='$CHAR' || TRIM(LEFT(length)) || '.';
                                                  formatl=length;
                                          END;
END;

ELSE format=TRIM(LEFT(format))|| TRIM(LEFT(formatl)) || '.';

IF informat ='' THEN DO;
                  informat=format;
                  informl=formatl;
                     END;

IF type=2 THEN      DO;
                  format=TRIM(LEFT(format));
                  informat=TRIM(LEFT(informat));
                    END;

ELSE                 DO;
                  format=TRIM(LEFT(format)) || TRIM(LEFT(formatD)) ;
                  informat=TRIM(LEFT(informat)) || TRIM(LEFT(INFORMD));
                     END;
RUN;

%IF &SYSERR NE 0 %THEN %DO; 
				  	%LET err_cd=1; 
				 	 %GOTO exit;
						%END;
PROC SORT DATA=work._&Tbl_name_sh.1;
 BY varnum;
 RUN;

  %IF &SYSERR NE 0 %THEN %DO; 
				  	%LET err_cd=1; 
				 	 %GOTO exit;
						%END;
DATA _NULL_;
 SET work._&Tbl_name_sh.1 END=last;
  LENGTH Del0 $ 1 Del $ 3 File_type $ 32 File_type_ext $ 3 str_Fields $ 5000;
  RETAIN pos_p 1 str_Fields;

   File_type=&File_type;
   File_type=LEFT(UPCASE(File_type));
   File_type_ext=UPCASE(SUBSTR(File_type,1,3));
   Del0=SUBSTR(File_type,4,1);
   IF Del0='' THEN Del0=',';
   Del="'" || TRIM(Del0) || "'";

   FILE &L_file;

  IF File_type_ext='ASC' THEN DO;

PUT @1 '@' pos_p @10 name @44 format;
 pos_p=pos_p+formatl;

IF last THEN
            DO;
 CALL SYMPUT('File_opt',"Lrecl=32767");
 CALL SYMPUT('str_Fields','');
            END;
                           END;

  ELSE                     DO;
      PUT @1 name @34 ':' @36 format;

                    i+1;
       CALL SYMPUT("Field_name" || TRIM(LEFT(i)), QUOTE(TRIM(name)));

IF NOT last THEN CALL SYMPUT("Field_del" || TRIM(LEFT(i)), Del);
ELSE
            DO;
     CALL SYMPUT('File_opt',"Delimiter=" || Del || " DSD DROPOVER Lrecl=32767");
     CALL SYMPUT('str_Fields',QUOTE(TRIM(str_Fields)));
     CALL SYMPUT('Fields_numb', TRIM(LEFT(i)));
     CALL SYMPUT("Field_del" || TRIM(LEFT(i)), '" "');
            END;
                           END;
RUN;

 %IF &SYSERR NE 0 %THEN %DO; 
				  	%LET err_cd=1; 
				 	 %GOTO exit;
						%END;
OPTIONS NOTES ;

 %IF &obs NE 0 %THEN %DO;

DATA _NULL_;;
 SET  &tbl_name_in.( OBS=&obs. &tbl_option_in. &str_Where_in. );

FILE &Tbl_name_out &File_opt;

 IF _N_=1 AND (&File_type NE 'ASC' OR &File_type NE "ASC") AND ("&Col_in_fst_row"="Y" OR "&Col_in_fst_row"="'Y'") THEN
                           DO;
 PUT
     %DO i=1 %TO &Fields_numb. ;
        &&Field_name&i &&Field_del&i
     %END;
    ;
                           END;

  PUT
 %INCLUDE &L_file;
  ;
RUN;
                     %END;

   %IF &SYSERR NE 0 %THEN %DO; 
     %LET err_cd=1;
     %PUT NOTE: SYSERR = &SYSERR;
   %END;

%exit:

   %PUT err_cd=&err_cd;
 %MEND;
