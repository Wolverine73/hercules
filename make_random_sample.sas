
  %MACRO Make_random_sample(tbl_name_in=,tbl_name_out=,sample_size=10, seed=0);
    DATA &tbl_name_out.(drop=sampsize obsleft);
      RETAIN sampsize &sample_size obsleft;

       IF _N_=1 THEN  DO;
         IF      0< &sample_size < 1  THEN sampsize=CEIL(totobs*&sample_size);
         ELSE                              sampsize=&sample_size;
         
         IF &sample_size <0 THEN DO;
           PUT "Invalid value for sample size sampsize=&sample_size";
             STOP;
              END;
                   obsleft=totobs;
                      END;
          SET &tbl_name_in  NOBS=totobs;
        IF ranuni(&seed)<sampsize/obsleft then
          DO;
             OUTPUT;
             sampsize=sampsize-1;
          END;
             obsleft=obsleft-1;
              IF sampsize=0 THEN    STOP;
     RUN;
  %MEND;
