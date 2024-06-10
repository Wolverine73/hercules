  %MACRO mk_fix_width_file(libref,tbl_name,l_file,dat_file,obs=max,select=1);
  
   
 PROC CONTENTS DATA=&libref..&tbl_name
              OUT=work.M_&tbl_name.(COMPRESS=NO KEEP=MEMNAME NAME LENGTH 
				  FORMAT INFORMAT VARNUM TYPE FORMATL INFORML 
				  FORMATD INFORMD) NOPRINT;
  RUN;
  QUIT;

DATA work.M_&tbl_name.1 (COMPRESS=NO);
 LENGTH format $ 10;
 SET work.M_&tbl_name.;
 
 
IF format='$' THEN format='$CHAR';
IF formatl=. OR formatl=0 THEN 
DO;
          IF type=1 THEN DO;
                      format='BEST12.';
                      formatl=12;
		         END;

		  ELSE			  DO;
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

PROC SORT DATA=work.M_&tbl_name.1;
 BY varnum;
 RUN;


DATA _NULL_;
 SET work.M_&tbl_name.1;
  RETAIN pos_p 1;
   FILE &l_file; 
PUT @1 '@' pos_p @10 name @44 format;
 pos_p=pos_p+formatl;
RUN;

 %IF &obs NE 0 %THEN %DO;

DATA _NULL_;
 SET  &libref..&tbl_name(OBS=&obs);
  IF &select;
 FILE &dat_file LRECL=36000;
  PUT
 %INCLUDE &l_file;;
  ;
RUN;  
                     %END;
 %MEND;

 
