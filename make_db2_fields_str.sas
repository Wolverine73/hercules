%MACRO make_db2_fields_str(Tbl_name_in);
OPTIONS NONOTES;
 %GLOBAL DB2_fields;
 %LET DB2_fields=;

 %LET pos=%INDEX(&Tbl_name_in,.);
 %LET Schema=%SUBSTR(&Tbl_name_in,1,%EVAL(&pos-1));
 %LET Tbl_name_sh=%SUBSTR(&Tbl_name_in,%EVAL(&pos+1));

  PROC SQL;
   CREATE TABLE work.&Tbl_name_sh._cols(COMPRESS=NO) AS
    SELECT name
     FROM &Schema..syscolumns(SCHEMA=SYSIBM)
      WHERE Tbcreator="&Schema"
        AND Tbname="&Tbl_name_sh"
        AND (Name LIKE '%_HSC_TS%' OR Name NOT LIKE '%_HSC_%')
        AND (Name LIKE '%_HSU_TS%' OR Name NOT LIKE '%_HSU_%')
        ORDER BY colno
    ;
   QUIT;

    DATA _NULL_;
     LENGTH fields $3000 New_name $ 32 Comma $ 1;
     RETAIN fields;
      SET work.&Tbl_name_sh._cols END=last;

    IF _N_=1 THEN comma='';
    ELSE          comma=',';

      New_name=SUBSTR(Name,5);
      fields=TRIM(fields) || comma || TRIM(Name) || ' AS ' || TRIM(New_name);

     IF last THEN CALL SYMPUT('DB2_fields',TRIM(LEFT(fields)));
    RUN;

PROC SQL; DROP TABLE work.&Tbl_name_sh._cols;
QUIT;
OPTIONS NOTES;
 %MEND;
