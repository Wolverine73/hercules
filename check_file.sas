/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Monday, September 23, 2002      TIME: 02:28:10 PM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: 09Oct2001      TIME: 11:45:33 AM
   PROJECT: copay_drug_cov
   PROJECT PATH: /PRG/sasprod1/drug_coverage/copay_drug_cov.seg
---------------------------------------- */
%MACRO check_file(Fileref=,Method=EXIST,Date_Informat=YYMMDD8.,days_pass=10,hours_pass=0,minutes_pass=0,sign=1,CONDITION_CD=0);
 %GLOBAL err_fl;
 %LOCAL err_fl_l File_name Today_datetime;

 %LET err_fl_l=1;
 %IF &err_fl= %THEN %LET err_fl=0;
 %LET Today_datetime=;

 %IF &CONDITION_CD NE 0  %THEN  %LET err_fl_l=0; 
 %IF &CONDITION_CD NE 0  %THEN	%GOTO exit_check_file;
 
DATA _NULL_;
 LENGTH Open_mode $ 1 Fileref $ 8 File_name $ 5000 Method $ 32 lrec 8 
        str_INFILE $ 32000 Today_datetime 8;

  Fileref=LEFT(SYMGET('Fileref'));
  Method=UPCASE(LEFT(SYMGET('Method')));

  pos_err=0;
  err_fl_l=1;
  str_INFILE='';

  IF 		Method='CREATE' THEN Open_mode='O';
  ELSE IF 	Method='UPDATE' THEN Open_mode='U';
  ELSE 							 Open_mode='I';

   				fid=FOPEN(Fileref,Open_mode);
				err_fl_l=(fid=0);

IF fid NE 0 AND Open_mode='I' THEN 
   					DO;
            File_name=FINFO(fid,'File Name');
            rc1=FREAD(fid); 
            lrec=FRLEN(fid);
		    rc2=FGET(fid,str_INFILE,lrec);
			str_INFILE=UPCASE(LEFT(str_INFILE));
			pos_err=INDEX(str_INFILE,'ERROR');
  IF TRIM(Method)='ERROR' AND pos_err > 0  THEN err_fl_l=1 ; 
  IF TRIM(Method)='INFILE_DATE' 
  THEN Today_datetime=DHMS(INPUT(TRIM(str_INFILE),&Date_Informat),0,0,0) ; 
  					END;	
   rc=FCLOSE(fid);
  
  CALL SYMPUT('err_fl_l',TRIM(LEFT(err_fl_l)));
  CALL SYMPUT('File_name',TRIM(File_name));
  CALL SYMPUT('Method',TRIM(Method));
  CALL SYMPUT('Today_datetime',TRIM(Today_datetime));
 * PUT fid= Fileref= File_name= Open_mode= rc1= rc2= Lrec=  str_INFILE= pos_err= Today_daytime=; 
RUN;

%IF &Method=DATE AND %SUPERQ(File_name) NE  %THEN
                    %DO;
FILENAME ls_flag PIPE "ls -la &File_name";

DATA _NULL_;
  LENGTH permisions $ 12 dummy $ 8 QCP_ID $ 8 group $ 8 File_size 8 
		month_C $ 3 day 8 time_C $ 5 File_name $ 2000 year 8 Today_datetime 8
		date_C $ 9 ;
   FORMAT permisions $12. QCP_ID $8. group $8. month_C $3. date DATE9.;
   INFORMAT permisions $12. QCP_ID $8. group $8. month_C $3. date DATE9.;
     INFILE ls_flag LRECL=100 EXPANDTABS  MISSOVER PAD ;
      INPUT permisions dummy QCP_ID group file_size month_C day time_C file_name ;
	     time_C=LEFT(time_C);
	     pos_col=INDEX(time_C,':');
         IF pos_col>0 THEN DO; 
                         year=YEAR(today());
						 hours=SUBSTR(time_C,1,2);
						 minutes=SUBSTR(time_C,4,2);
						   END;
         ELSE 				DO;
              			year=time_c;
			  			hours=0;
			  			minutes=0;
			  				END;
         date_C=PUT(day,z2.) ||UPCASE(month_C) || TRIM(LEFT(year)) ;
         date=INPUT(date_C,DATE9.);
		  IF date > today() THEN date=MDY(MONTH(date),DAY(date),YEAR(date)-1);
		 Today_datetime=DHMS(date,hours,minutes,0);
         CALL SYMPUT('Today_datetime',TRIM(Today_datetime));
RUN;

		FILENAME ls_flag CLEAR;

%IF &Today_datetime NE   %THEN
						 		%DO;
 DATA _NULL_;
    LENGTH Today_datetime 8 datetime_diff 8 datetime_pass 8;
	      Today_datetime=SYMGET('Today_datetime');
		  datetime_diff=SUM(DATETIME(),-Today_datetime);
		  datetime_pass=24*3600*&days_pass+3600*&hours_pass+60*&minutes_pass;
       *  PUT datetime_diff= datetime_pass=;  
          IF &sign * (datetime_diff - datetime_pass)>0 THEN CALL SYMPUT('err_fl_l',1); 
  RUN;
 								%END;
						%END;

%IF (&Method=NOT_EXIST) %THEN %LET err_fl_l=%EVAL((&err_fl_l=0));

%exit_check_file:

%LET err_fl=%SYSFUNC(MAX(&err_fl,&err_fl_l));

 %PUT err_fl=&err_fl; 
%MEND;
