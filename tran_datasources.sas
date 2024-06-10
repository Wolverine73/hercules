/* ----------------------------------------
   This Code takes a 32 bit datasourses.sas7bdat data set and transitions it to a 64 bit data set
   DATE: Monday, April 13, 2009      TIME: 10:45 AM
   PROJECT: v8.2 to v9.1 Transition
---------------------------------------- */
%LET _datasources=%STR(__home.DATASOURCES);

* OPTIONS MLOGIC MPRINT SYMBOLGEN SOURCE2;
OPTIONS NOMLOGIC NOMPRINT NOSYMBOLGEN NOSOURCE2;

%GLOBAL err_fl SYSERR SQLRC SQLXRC ;

 %LET err_fl=0;

%MACRO tran_datasources ;

   OPTIONS NONOTES;
   LIBNAME __home V9 "$HOME";

   %IF %sysfunc(exist(&_datasources))=1
      %THEN %DO ;

         DATA _&_datasources ;
            SET &_datasources ;
         run ;

         LIBNAME __home CLEAR;
         OPTIONS NOTES;

      %END ;

%MEND tran_datasources;
