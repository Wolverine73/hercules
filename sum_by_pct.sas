/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Friday, October 25, 2002      TIME: 05:37:13 PM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */
%MACRO sum_by_pct(tbl_name_in=,tbl_name_out=,by_var=,WEIGHT=,x_var=,y_var=,groups=20);
%LOCAL by_var1;

%IF &by_var= %THEN %DO; %LET by_var1=; 			%END;
%ELSE			   
					%DO; 
			%LET by_var1=BY &by_var;
 
			PROC SORT DATA=&tbl_name_in.;
			  BY &by_var;
			RUN;
					%END;

%IF &WEIGHT NE  %THEN %DO; %LET WEIGHT1=WEIGHT &WEIGHT; %END;
%ELSE				  %DO;  %LET WEIGHT1=; 				%END;

DATA _NULL_;
 LENGTH tbl_name_tmp1 $ 32;
 tbl_name_tmp1='_t' || TRIM(LEFT(INT(DATETIME())));
 CALL SYMPUT('tbl_name_tmp1',TRIM(tbl_name_tmp1));
RUN;

 PROC RANK DATA=&tbl_name_in(KEEP=&by_var &WEIGHT. &x_var &y_var) 
		   OUT=&tbl_name_tmp1 TIES=LOW GROUPS=&groups. ;
 &by_var1;
  VAR &x_var ;
 RANKS Rank_&x_var. ;
 RUN;
 QUIT;

 PROC SORT DATA=&tbl_name_tmp1;
  BY &by_var Rank_&x_var. ;
 RUN;
 QUIT;


PROC MEANS DATA=&tbl_name_tmp1 NOPRINT;
  BY &by_var Rank_&x_var. ;
  VAR  &y_var;
  &WEIGHT1;
   OUTPUT OUT=&tbl_name_out(DROP=_TYPE_) MEAN(&x_var)=&x_var._Mean
								MEAN= VAR= STD=  MIN(&x_var)=&x_var._min MAX(&x_var)=&x_var._max/AUTONAME AUTOLABEL ;
 RUN;
 QUIT;

 %MEND;

