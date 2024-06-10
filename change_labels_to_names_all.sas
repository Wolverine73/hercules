 %MACRO change_labels_to_names_all(libref);

   PROC CONTENTS DATA=&libref.._ALL_
                OUT=work.col_labels(KEEP=memname name label) NOPRINT;
     RUN;

 PROC SORT DATA=work.col_labels;
  BY memname name label;
 RUN;


     DATA  _NULL_;
      LENGTH rename_names $ 30000;
       RETAIN rename_names;
           SET work.col_labels  END=last  ;
	     BY memname name label;

    IF first.memname THEN 
DO;
     rename_names=TRIM(LEFT(rename_names)) ||  ' MODIFY ' 
		   || TRIM(LEFT(memname)) || ';' || ' LABEL ' ;
END;

        IF TRIM(LEFT(UPCASE(name))) NE TRIM(LEFT(UPCASE(label))) THEN
DO;

        rename_names=TRIM(LEFT(rename_names)) ||
                " " ||
                 TRIM(LEFT(name)) ||
                 "=" ||
                QUOTE(TRIM(LEFT(name))) ;
END;
    IF last.memname THEN DO;
		  rename_names=TRIM(LEFT(rename_names)) || ';'; 
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
