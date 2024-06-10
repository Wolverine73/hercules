 %MACRO change_names_to_labels(libref,tbl_name);

   PROC CONTENTS DATA=&libref..&tbl_name
                OUT=work.col_labels(KEEP=name label);
     RUN;


     DATA  _NULL_;
      LENGTH rename_names $ 5000;
       RETAIN rename_names;
           SET work.col_labels  END=last  ;


        IF TRIM(label) NE " " AND TRIM(LEFT(UPCASE(name))) NE TRIM(LEFT(UPCASE(label))) THEN
DO;

        rename_names=TRIM(LEFT(rename_names)) ||
                " " ||
                 TRIM(LEFT(name)) ||
                 "=" ||
                TRIM(LEFT(label)) ;


END;

   IF last THEN
DO;
CALL SYMPUT ('rename_names',rename_names) ;
END;
   RUN;


  PROC DATASETS LIB=&libref;
     MODIFY &tbl_name;
       RENAME  &rename_names;
  RUN;
   QUIT;

%LET rename_names= ;
 %MEND;

 /* Usage: %labels_to_names(history,allcal); */
