 %MACRO change_labels_to_names(libref,tbl_name);
OPTIONS NONOTES;
   PROC CONTENTS DATA=&libref..&tbl_name
                OUT=work.col_labels(KEEP=name label) NOPRINT;
     RUN;


     DATA  _NULL_;
      LENGTH rename_names $ 5000;
       RETAIN rename_names;
           SET work.col_labels  END=last  ;


        IF TRIM(LEFT(UPCASE(name))) NE TRIM(LEFT(UPCASE(label))) THEN
DO;

        rename_names=TRIM(LEFT(rename_names)) ||
                " " ||
                 TRIM(LEFT(name)) ||
                 "=" ||
                QUOTE(TRIM(LEFT(name))) ;
END;

   IF last THEN
DO;
CALL SYMPUT ('rename_names',TRIM(LEFT(rename_names))) ;
END;
   RUN;


  PROC DATASETS LIB=&libref;
     MODIFY &tbl_name;
       LABEL &rename_names;
  RUN;
  QUIT;

%LET rename_names= ;
OPTIONS NOTES;
 %MEND;

 /* Usage: %labels_to_names(history,allcal); */
