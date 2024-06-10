 %MACRO change_names_to_labels_all(libref);

   PROC CONTENTS DATA=&libref.._ALL_
                OUT=work.col_labels(KEEP=memname name label) NOPRINT;
     RUN;

 PROC SORT DATA=work.col_labels;
  BY memname name label;
 RUN;


     DATA  _NULL_;
      LENGTH rename_names rename_names1 $ 30000;
       RETAIN rename_names rename_names1 flag;
           SET work.col_labels  END=last  ;
	     BY memname name label;

    IF first.memname THEN 
DO;
     flag=0;
     rename_names1=TRIM(LEFT(rename_names)) ||  ' MODIFY ' 
		   || TRIM(LEFT(memname)) || ';' || ' RENAME ' ;
END;

    IF TRIM(LEFT(label)) NE ' ' AND TRIM(LEFT(UPCASE(name))) NE TRIM(LEFT(UPCASE(label))) THEN
DO;

        rename_names1=TRIM(LEFT(rename_names1)) ||
                " " ||
                 TRIM(LEFT(name)) ||
                 "=" ||
                 TRIM(LEFT(label)) ;
         flag=1;
END;
    IF last.memname AND flag THEN DO;
		  rename_names=TRIM(LEFT(rename_names1)) || ';'; 
		      END;

   IF last THEN
DO;
	rename_names=TRIM(LEFT(rename_names)) || ';'; 
	CALL SYMPUT ('rename_names',TRIM(LEFT(rename_names))) ;
END;
   RUN;


  PROC DATASETS LIB=&libref;
      &rename_names;
  RUN;
  QUIT;

%LET rename_names= ;
 %MEND;

 /* Usage: %labels_to_names(history); */
