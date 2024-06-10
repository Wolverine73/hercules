
/*HEADER----------------------------------------------------------------------------------------
| 
| PROGRAM:   eligibility_check.sas
| 
| LOCATION: /PRG/sasprod1/hercules/macros
| 
| 
| PURPOSE:  This macro checks participant eligibility. 
| 
| LOGIC:    The macro first checks cardholder eligibility. If client provide detail eligibility
|           (there is a record for the participant in the table CLAIMSA.TELIG_DETAIL_HIS) 
|           then the patient eligibility is also checked. 
| 
| PARAMETERS:
|           The tbl_name_in is a name of input DB2 table. It must have columns: CDH_BENEFICIARY_ID, PT_BENEFICIARY_ID. 
|           The combination of CDH_BENEFICIARY_ID and PT_BENEFICIARY_ID does not have to be distinct and 
|           there may be other columns in the table.
|            
|           The tbl_name_out is a name of output DB2 table. It has only three columns: 
|           CDH_BENEFICIARY_ID,PT_BENEFICIARY_ID,CLT_PLAN_GROUP_ID. The value of CLT_PLAN_GROUP_ID is
|           the latest CLT_PLAN_GROUP_ID that participant has before &chk_dt. 
|            
|           The chk_dt is a SAS date on which one wants to check eligibility. 
|           If chk_dt is not specified (second example below) then the default value 
|           for chk_dt is the current date.
| 			
| 
|-------------------------------------------------------------------------------------------------
| History:
| 
|           Jul  2003    - Yury Vilk
|                First Release for Hercules             
|                
|                Retrieve the eligibility_dt ,eligibility_cd from the TPHASE_RVR_FILE
|                with the given initiative_id and defined as Macro Variables as elig_dt, elig_cd.
|                
|                LOGIC : If the elig_cd = 1(Current) then creates macro variables(chk_dt,chk_dt_db2)
|                eq current date and initiatize elig_str will be( effective_dt <= chk_dt_db2 and
|                expiration_dt > chk_dt_db2) and exp_dt_str (or expiration_dt >chk_dt)
|                
|                If the elig_cd = 2(Future) then creates macro variables(chk_dt,chk_dt_db2)
|                eq elig_dt .If elig_dt is greater than the current date then initiatize 
|                elig_str will be( effective_dt <= chk_dt_db2 and expiration_dt > chk_dt_db2)
|                and exp_dt_str (or expiration_dt >chk_dt)) 
|                
|                Else if Elig_dt <= current date then ERROR Email message will go to 
|                Production team members.
|                
|                If Elig_cd = 3(All are Eligibile irrespective of date) then Macro will
|                pick up all the ppts irrespective of date.
|                
|           Dec  2006    - Nick Williams 
|                Modified the Tbl_name_out_sh SQL by adding A.CDH_BENEFICIARY_ID = D.CDH_BENEFICIARY_ID
|                based on recommendation from DBAs
|                
|           Dec  2006    - Kuladeep Mittapalli 
|                Second Release for Hercules 2 - Future Eligibility
|           
|           Mar  2007    - Greg Dudley 
|                Added logic for jobs that do not use initiative ID
|                USAGE EXAMPLE:
|                
|                %eligibility_check(tbl_name_in=TMP87.T3_1_CLAIMS, tbl_name_out=TMP87.T3_1_ELIG_PT,chk_dt='21JUL2003'd);
|                %eligibility_check(tbl_name_in=TMP87.T3_1_CLAIMS, tbl_name_out=TMP87.T3_1_ELIG_PT);
|                
|           Mar  2007    - Greg Dudley Hercules Version  1.0   
|           
|           Apr  2007    - Brian Stropich Hercules Version  1.0.01                   
|                Added logic to allow the Tbl_name_out_sh SQL to complete when the observations 
|                are too large. 
|           Apr10 2007    - Gregory Dudley Hercules Version  1.0.02
|                Added logic to create a SAS date value for the macro variable chk_dt 
|
|           APR01 2008    - Carl Starks Hercules Version 2.1
|                Added logic to accommodate EDW eligibilty check processing
|                Changed the QL input and output filenames from tbl_name_in, tbl_name_out 
|                and tbl_name_out2 to tbl_name_in, tbl_name_out and tbl_name_out2
|
|                Added Recap and Rxclaim input and ouput names tbl_name_in_re, tbl_name_re_out
|                and tbl_name_re_out2,tbl_name_in_rx, tbl_name_rx_out and tbl_name_rx_out2 
|
|                Added logic to read 3 new macro variable to determine which adjudication process that
|                will be ran (ql_adj, rx_adj and re_adj). The ql_adj will run the QL process whose code
|                did not change much from the ole eligibility check macro. The rx_adj will run Rxclaim
|                and Recap will run Recap these are 2 new processes added 
|
|        OCT20 2008 - S.Y. - Hercules Version  2.1.2.01
|				ADDED LOGIC TO HANDLE ELIIGIBILITY FOR FASTSTART TO EXCLUDE THE PARTICIPANTS 
|               WHOSE BENEFITS ARE EXPIRING WITH IN SIX WEEKS FROM TODAY SO THAT WE DO NOT SEND THEM 
|               LETTERS WHO ARE ALREADY EXPIRED BY THEN.
| 
|        JUL 2009 - Nicholas Williams - Hercules Version  2.1.2.02
|				ADDED LOGIC TO HANDLE ELIIGIBILITY check for Recap & Rxclaim differently for Negative
|               Formulary Mailing.
|               
----------------------------------------------------------------------------------------HEADER*/


*SASDOC----------------------------------------------------------------------
|   C.J.S APR01 2008
|   The input output names have been changed for QL and added for the new EDW 
|   Rxclaim and Recap logic for the %macro call
|   
+---------------------------------------------------------------------SASDOC*;

  options mprint mlogic source2 symbolgen;


%MACRO ELIGIBILITY_CHECK_NEGFRM   (tbl_name_in=, 
                                   tbl_name_in_rx=, 
                                   tbl_name_in_re=,
                                   tbl_name_out=, 
                                   tbl_name_rx_out=, 
                                   tbl_name_re_out=,
                                   chk_dt=,
                                   CLAIMSA=CLAIMSA,
						           Execute_condition=%STR(1=1),
						           tbl_name_out2=,
                                   tbl_name_rx_out2=,
                                   tbl_name_re_out2=, 
                                   init_id=&initiative_id);

						
%GLOBAL SQLRC SQLXRC ELIG_STREDW EXP_DT_STREDW;
%PUT CLAIMSA = &CLAIMSA;
%PUT HERCULES = &HERCULES;
%LET Execute_condition_flag=%SYSFUNC(SIGN((&Execute_condition)));
%PUT Execute_condition_flag=&Execute_condition_flag;


*SASDOC----------------------------------------------------------------------
|   Retrieve the eligibility_dt ,eligibility_cd from the TPHASE_RVR_FILE
|   with the given initiative_id and defined as Macro Variables as elig_dt,
|   elig_cd.
+---------------------------------------------------------------------SASDOC*;
  
%IF &INIT_ID EQ %THEN %DO; /*** 03/20/2007 - g.d. - added logic for jobs that do not use initiative ID ****/

	%LET ELIG_CD=1;
	%LET CNTROW=0;
	%LET INIT_ID=0;

	DATA _NULL_;
	  CALL SYMPUT('ELIG_DT',TODAY());
	RUN;
	
%END;
%ELSE %DO;
	%IF &INIT_ID NE %THEN %DO; /*** 03/20/2007 - g.d. - added logic for jobs that do not use initiative ID ****/

		PROC SQL NOPRINT;
		   SELECT ELIGIBILITY_DT,
			  ELIGIBILITY_CD,
			  CASE
			    WHEN ELIGIBILITY_DT <= TODAY() AND ELIGIBILITY_CD = 2 THEN 1
			    ELSE 0
			  END AS CNTROW	
		   INTO   :ELIG_DT, :ELIG_CD, :CNTROW
		   FROM   &HERCULES..TPHASE_RVR_FILE
		   WHERE  INITIATIVE_ID in(&init_id);
		QUIT;

	%END;
%END;

%PUT NOTE: ELIG_DT=&ELIG_DT;
%PUT NOTE: ELIG_CD=&ELIG_CD;
%PUT NOTE: CNTROW=&CNTROW;

*SASDOC----------------------------------------------------------------------
| LOGIC : Following Macro will check,If the elig_cd = 1(Current) then creates 
|  	  macro variables(chk_dt,chk_dt_db2)eq current date and initiatize elig_str 
|  	  will be( effective_dt <= chk_dt_db2 and expiration_dt > chk_dt_db2) and 
|  	  exp_dt_str (or expiration_dt >chk_dt)If the elig_cd = 2(Future) then creates 
|  	  macro variables(chk_dt,chk_dt_db2)eq elig_dt .If elig_dt is greater than the 
|  	  current date then initiatize elig_str will be( effective_dt <= chk_dt_db2 
|  	  and expiration_dt > chk_dt_db2)and exp_dt_str (or expiration_dt >chk_dt)) 
|  	  Else if Elig_dt <= current date then ERROR Email message will go to 
|  	  Production team members.
|
|  	  If Elig_cd = 3(All are Eligibile irrespective of date) then Macro will
|  	  pick up all the ppts irrespective of date.
+---------------------------------------------------------------------SASDOC*;

%MACRO CHKELIGCD;

        %GLOBAL ELIG_STR EXP_DT_STR chk_dt_db2;
        OPTIONS MPRINT MLOGIC SYMBOLGEN;
	
      %IF &ELIG_CD=1 %THEN %DO;
	
  			DATA _NULL_;
              CALL SYMPUT('chk_dt',TODAY());
              CALL SYMPUT('chk_dt_db2',"'" || PUT(TODAY(), MMDDYY10.) || "'");
              CALL SYMPUT('chk_dt_oracle',"'" || PUT(TODAY(), yymmdd10.) || "'");
              CALL SYMPUT('chk_dt_oracle2',"'" || translate(PUT(TODAY(), yymmdd10.),'-','/') || "'");
            RUN;


*SASDOC----------------------------------------------------------------------
|   S.Y. OCT20 2008 - Hercules Version  2.1.2.01
|      CHANGES HAVE BEEN MADE TO THE MACRO VARIABLES ELIG_STREDW, ELIG_STR,
|      EXP_DT_STREDW, EXP_DT_STR FOR FASTSTART.
+---------------------------------------------------------------------SASDOC*;

	  		%IF &PROGRAM_ID = 73 AND &TASK_ID = 5 %THEN %DO;


				%LET ELIG_STREDW = %STR(WHERE ELIG_EFF_DT <= TO_DATE(&CHK_DT_ORACLE,'YYYY-MM-DD') AND
				              			      NVL(ELIG_END_DT - 42, '9999-12-31') > TO_DATE(&CHK_DT_ORACLE,'YYYY-MM-DD')
                                		);


				%LET ELIG_STR = %STR(AND B.EFFECTIVE_DT <= &CHK_DT_DB2 AND
                                         CASE WHEN B.EXPIRATION_DT  IS NULL
			                                  THEN '12/31/9999'
				                              ELSE EXPIRATION_DT - 42 DAYS
			                             END  > &CHK_DT_DB2
									);

				%LET EXP_DT_STREDW	= %STR(OR NVL(ELIG_END_DT - 42, '9999-12-31') > &CHK_DT_ORACLE2);



				%LET EXP_DT_STR	= %STR(OR INTNX('DAY', EXPIRATION_DT, -42) > &CHK_DT);


				%PUT NOTE: ELIG_STREDW= &ELIG_STREDW;
				%PUT NOTE: EXP_DT_STREDW= &EXP_DT_STREDW;
				%PUT NOTE: ELIG_STR= &ELIG_STR;
				%PUT NOTE: EXP_DT_STR= &EXP_DT_STR;	

			%END;

			%ELSE %DO;
                

                   /* for current eligibility */
				%LET ELIG_STREDW = %STR(WHERE ELIG_EFF_DT <= to_date(&chk_dt_oracle,'yyyy-mm-dd')
				AND NVL(ELIG_END_DT, to_date(&chk_dt_oracle,'yyyy-mm-dd'))> to_date(&chk_dt_oracle,'yyyy-mm-dd'));



                     /*
                %LET ELIG_STREDW = %STR(AND ELIG_EFF_DT <= to_date(&chk_dt_oracle,'yyyy-mm-dd')
                		     AND ELIG_END_DT > to_date(&chk_dt_oracle,'yyyy-mm-dd'));
                   */

                
                %LET ELIG_STR = %STR(AND B.EFFECTIVE_DT <= &chk_dt_db2
                		     AND B.EXPIRATION_DT > &chk_dt_db2);

                %LET EXP_DT_STREDW	= %STR(OR ELIG_END_DT > &chk_dt_oracle2);
                %PUT NOTE: ELIG_STREDW= &ELIG_STREDW;
                %PUT NOTE: EXP_DT_STREDW= &EXP_DT_STREDW;

                
                %LET EXP_DT_STR	= %STR(OR EXPIRATION_DT > &chk_dt);
                %PUT NOTE: ELIG_STR= &ELIG_STR;
                %PUT NOTE: EXP_DT_STR= &EXP_DT_STR;

			%END;

      %END;


      %ELSE %IF &ELIG_CD=2 %THEN %DO;

                DATA _NULL_;
                  CALL SYMPUT('chk_dt',&ELIG_DT);
                  CALL SYMPUT('TOD',TODAY());
                RUN;
                %put NOTE: CHK_DT = &CHK_DT;
                
         %IF  "&chk_dt" > "&tod" %THEN %DO;
                
                DATA _NULL_;
                  date = &ELIG_DT;
                  CALL SYMPUT('chk_dt_db2',"'" || PUT(date, MMDDYY10.) || "'"); 
                  CALL SYMPUT('chk_dt_oracle',"'" || PUT(date, yymmdd10.) || "'"); 
                RUN;

                %put NOTE: CHK_DT_oracle = &CHK_DT_oracle;
                /*
                %LET ELIG_STREDW = %STR(AND ELIG_EFF_DT <= to_date(&chk_dt_oracle,'yyyy-mm-dd')
                		     AND ELIG_END_DT > to_date(&chk_dt_oracle,'yyyy-mm-dd')
                              and ELIG_EFF_DT > sysdate);
                  */

     /* for FUTURE eligibility */
				%LET ELIG_STREDW = %STR(WHERE ELIG_EFF_DT > SYSDATE
				AND ELIG_EFF_DT <= to_date(&chk_dt_oracle,'yyyy-mm-dd')
				AND NVL(ELIG_END_DT, to_date(&chk_dt_oracle,'yyyy-mm-dd'))> to_date(&chk_dt_oracle,'yyyy-mm-dd'));

              
             
                %LET EXP_DT_STREDW	= %STR(OR ELIG_END_DT > &chk_dt_oracle2);
                %PUT NOTE: ELIG_STREDW=&ELIG_STREDW;
                %PUT NOTE: EXP_DT_STREDW=&EXP_DT_STREDW;


                %put NOTE: CHK_DT_DB2 = &CHK_DT_DB2;
                
                %LET ELIG_STR = %STR(AND B.EFFECTIVE_DT <= &chk_dt_db2
                		     AND B.EXPIRATION_DT > &chk_dt_db2
                             and B.EFFECTIVE_DT > current date);


                %LET EXP_DT_STR	= %STR(OR EXPIRATION_DT > &chk_dt);
                %PUT NOTE: ELIG_STR=&ELIG_STR;
                %PUT NOTE: EXP_DT_STR=&EXP_DT_STR;
                
      %END;

          %IF  &CNTROW = 1 %THEN %GOTO IEND;
   %END;

	%ELSE %IF &ELIG_CD=3 %THEN %DO;
		%LET ELIG_STR =;
		%LET EXP_DT_STR=;
      %PUT NOTE: ELIG_STR=&ELIG_STR;
      %PUT NOTE: EXP_DT_STR=&EXP_DT_STR;
       %LET ELIG_STREDW =;
	  %LET EXP_DT_STREDW=;
      %PUT NOTE: ELIG_STREDW=&ELIG_STREDW;
      %PUT NOTE: EXP_DT_STREDW=&EXP_DT_STREDW;
 %END;

         %IEND:;

	%IF &CNTROW = 1 %THEN %DO;

	  %set_error_fl(err_fl_l=&CNTROW);

	  /*
	  %on_error(ACTION=ABORT, 
		    EM_TO=&primary_programmer_email,
		    EM_SUBJECT="HCE SUPPORT:  Notification of Abend",
		    EM_MSG=%str(A problem was encountered at the ELIGIBILITY_CHECK macro.Please check the log associated with Initiative_id &initiative_id..));	
       */
	%END;
	
%MEND CHKELIGCD;
%CHKELIGCD;


*SASDOC----------------------------------------------------------------------
|   C.J.S APR01 2008
|   The logic for this code is unchanged ecept for changing the name of the inputs
|   and outputs to identify what adjudication created them and making this part of the logic a Macro
|   so that it is ran based on adjudication. 
|   
+---------------------------------------------------------------------SASDOC*;

/*%let ELIG_STR =%str(AND B.EFFECTIVE_DT <= '03/01/2008' AND B.EXPIRATION_DT > 
            '03/01/2008');

*/
 %MACRO QLCHKELIG; 

%IF  &tbl_name_in= %THEN %DO;
	%LET err_fl=1;
	%PUT ERROR: Parameter tbl_name_in must be specified;
%END;

%IF &tbl_name_in= %THEN %GOTO EXIT1;

%IF &tbl_name_out= %THEN %LET tbl_name_out=&DB2_TMP..&TABLE_PREFIX.CPG_ELIG;

%table_properties(tbl_name=&CLAIMSA..TELIG_DETAIL_HIS,PRINT=NOPRINT);


%PUT NOTE: ELIG_STR=&ELIG_STR;
%PUT NOTE: EXP_DT_STR=&EXP_DT_STR;

%set_error_fl;
%PUT chk_dt_db2=&chk_dt_db2;

%LET pos=%INDEX(&tbl_name_in,.);
%LET Schema=%SUBSTR(&tbl_name_in,1,%EVAL(&pos-1));
%LET Tbl_name_in_sh=%SUBSTR(&tbl_name_in,%EVAL(&pos+1));

%LET pos=%INDEX(&tbl_name_out,.);
%LET Schema=%SUBSTR(&tbl_name_out,1,%EVAL(&pos-1));
%LET tbl_name_out_sh=%SUBSTR(&tbl_name_out,%EVAL(&pos+1));


*SASDOC----------------------------------------------------------------------
| Apr  2007    - Brian Stropich
| Added logic to allow the SQL to complete when the observations are too large.
+---------------------------------------------------------------------SASDOC*;
 
 %drop_db2_table(tbl_name=&db2_tmp..PTS&INIT_ID.); 

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   CREATE TABLE &db2_tmp..PTS&INIT_ID. as
   SELECT * FROM CONNECTION TO DB2
        (    
	  select   CDH_BENEFICIARY_ID, 
		   PT_BENEFICIARY_ID,
		   COUNT(*) AS COUNT 
	  from     &tbl_name_in.
	  group by CDH_BENEFICIARY_ID, 
	           PT_BENEFICIARY_ID
        );
   DISCONNECT FROM DB2;
QUIT;
 
PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   CREATE TABLE WORK.&tbl_name_out_sh AS
   SELECT DISTINCT * FROM CONNECTION TO DB2 
   (  
	  SELECT A.CDH_BENEFICIARY_ID AS CDH_BENEFICIARY_ID,
                 A.PT_BENEFICIARY_ID,
    		 COALESCE(D.CLT_PLAN_GROUP_ID,B.CLT_PLAN_GROUP_ID) AS CLT_PLAN_GROUP_ID,
		 MIN(D.EFFECTIVE_DT)  	 AS EFFECTIVE_DT ,
		 MAX(D.EXPIRATION_DT) 	 AS EXPIRATION_DT,
		 MIN(B.EFFECTIVE_DT)  	 AS CDH_EFFECTIVE_DT ,
		 MAX(B.EXPIRATION_DT) 	 AS CDH_EXPIRATION_DT
		 
          FROM  (&db2_tmp..PTS&INIT_ID. A 	 
          
          	 INNER JOIN
          	 
                 &CLAIMSA..TELIG_DETAIL_HIS B
                 ON A.CDH_BENEFICIARY_ID = B.CDH_BENEFICIARY_ID
                 &ELIG_STR.
		 AND B.PT_BENEFICIARY_ID=B.CDH_BENEFICIARY_ID 		 
		)
		
		 LEFT JOIN 
		 
		 &CLAIMSA..TELIG_DETAIL_HIS D
                 ON A.PT_BENEFICIARY_ID = D.PT_BENEFICIARY_ID
                 AND A.CDH_BENEFICIARY_ID = D.CDH_BENEFICIARY_ID /*** Dec  2006    - Nick Williams  ***/
                 GROUP BY A.CDH_BENEFICIARY_ID,
                          A.PT_BENEFICIARY_ID, 
                          COALESCE(D.CLT_PLAN_GROUP_ID,B.CLT_PLAN_GROUP_ID) 
   )
   ORDER BY  CDH_BENEFICIARY_ID,PT_BENEFICIARY_ID,EXPIRATION_DT,CLT_PLAN_GROUP_ID ;
   DISCONNECT FROM DB2;
QUIT;


%set_error_fl;

DATA WORK.&tbl_name_out_sh.1;
  SET WORK.&tbl_name_out_sh;
  BY CDH_BENEFICIARY_ID PT_BENEFICIARY_ID; 
  IF last.PT_BENEFICIARY_ID;
  IF EXPIRATION_DT=. &EXP_DT_STR.;  
RUN;

%set_error_fl;

%drop_db2_table(tbl_name=&db2_tmp..PTS&INIT_ID.);

%drop_db2_table(tbl_name=&tbl_name_out);

PROC SQL;
   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
   EXECUTE(CREATE TABLE &tbl_name_out
                       (CDH_BENEFICIARY_ID INTEGER,
                        PT_BENEFICIARY_ID INTEGER,
                        CLT_PLAN_GROUP_ID INTEGER) NOT LOGGED INITIALLY) BY DB2;
   EXECUTE (ALTER TABLE &tbl_name_out ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;
   DISCONNECT FROM DB2;
QUIT;

%set_error_fl;

PROC SQL ;
   INSERT INTO &tbl_name_out(BULKLOAD=YES)
   SELECT 
	 CDH_BENEFICIARY_ID,
	 PT_BENEFICIARY_ID,
         CLT_PLAN_GROUP_ID
   FROM WORK.&tbl_name_out_sh.1;
QUIT;

%set_error_fl;
%runstats(tbl_name=&tbl_name_out);
%let err_fl = 0;

%IF &tbl_name_out2. NE AND &err_fl=0 %THEN %DO;

	%drop_db2_table(tbl_name=&tbl_name_out2);

	%LET pos=%INDEX(&tbl_name_out2,.);
	%LET Schema=%SUBSTR(&tbl_name_out2,1,%EVAL(&pos-1));
	%LET tbl_name_out2_sh=%SUBSTR(&tbl_name_out2,%EVAL(&pos+1));

	PROC SQL;
	   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
	   EXECUTE(CREATE TABLE &tbl_name_out2	AS
	   (   SELECT  A.*,B.CLT_PLAN_GROUP_ID
	       FROM  &tbl_name_in. 	AS A,
	       &tbl_name_out. 		AS B
	   ) DEFINITION ONLY NOT LOGGED INITIALLY
	   ) BY DB2;
	   DISCONNECT FROM DB2;
	QUIT;
	%set_error_fl;

	%IF &Execute_condition_flag.=1 %THEN  %DO;

		PROC SQL;
		   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
		   EXECUTE
		   (ALTER TABLE &tbl_name_out2 ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;    
		   EXECUTE(INSERT INTO &tbl_name_out2 
			   SELECT A.*,
				  B.CLT_PLAN_GROUP_ID
			   FROM &tbl_name_in. 		AS A,
				&tbl_name_out. 		AS B
			   WHERE A.CDH_BENEFICIARY_ID = B.CDH_BENEFICIARY_ID
			     AND A.PT_BENEFICIARY_ID = B.PT_BENEFICIARY_ID
		   ) BY DB2;
		   %reset_sql_err_cd;
		QUIT;

		%set_error_fl;
		%runstats(TBL_NAME=&tbl_name_out2);
		%table_properties(TBL_NAME=&tbl_name_out2);

	%END; /* End of &Execute_condition_flag.=1 */
	%ELSE %DO;

		PROC SQL;
		   CONNECT TO DB2 AS DB2(DSN=&UDBSPRP AUTOCOMMIT=NO);
		   EXECUTE
		   (ALTER TABLE &tbl_name_out2 ACTIVATE NOT LOGGED INITIALLY  ) BY DB2;    
		   EXECUTE(INSERT INTO &tbl_name_out2 
			   SELECT A.*,
				  COALESCE(B.CLT_PLAN_GROUP_ID,-1)
			   FROM &tbl_name_in. 		AS A 
			   LEFT JOIN
				&tbl_name_out. 		AS B
			   ON A.CDH_BENEFICIARY_ID = B.CDH_BENEFICIARY_ID
			   AND A.PT_BENEFICIARY_ID = B.PT_BENEFICIARY_ID
		   ) BY DB2;
		QUIT;

		%set_error_fl;

	%END;

%END;

%EXIT1:;
%mend QLCHKELIG;


%if &ql_adj eq 1 %then %do;
%QLCHKELIG;
%end;


 %MACRO EDWCHKELIG(adj=,tbl_name_in_edw=,tbl_name_out_edw=,tbl_name_out2_edw=,adj2=,hier_cd=) ; 




%IF  &tbl_name_in_edw= %THEN %DO;
	%LET err_fl=1;
	%PUT ERROR: Parameter &tbl_name_in_edw must be specified;
%END;

%IF &tbl_name_in_edw= %THEN %GOTO EXIT2;

%IF &tbl_name_out_edw= %THEN %LET TBL_name_OUT_edw=&ora_TMP..&TABLE_PREFIX.&adj2._ELIG;

%drop_oracle_table(tbl_name=&ora_tmp..PTSa&adj2.&INIT_ID.);
%drop_oracle_table(tbl_name=&ora_tmp..PTSb&adj2.&INIT_ID.);

*SASDOC----------------------------------------------------------------------
|   N. Williams July 2009 - begin
|   Added this query to custom edw eligilibity check for Med-D members
|11JUL2011 - G. Dudley - Added constraint for Payer ID.
|
+---------------------------------------------------------------------SASDOC*;
	%IF &RX_ADJ. = 1 %THEN %DO;
		%LET SRC_SYS_CD = %STR(X);
		%LET PAYER_ID_CONS = %STR(< 100000);
	%END;
	%IF &RE_ADJ. = 1 %THEN %DO;
		%LET SRC_SYS_CD = %STR(R);
		%LET PAYER_ID_CONS = %STR(BETWEEN 500000 AND 2000000);
	%END;

  %if &rx_adj eq 1 AND &adj='X' %then %do;
   proc sql;
        CONNECT TO ORACLE(PATH=&GOLD );
        CREATE TABLE &ora_tmp..PTSa&adj2.&INIT_ID AS
        SELECT * FROM CONNECTION TO ORACLE
      (
	    select   A.mbr_id, 
	 	         A.payer_id,
		        COUNT(*) AS COUNT 
	    from     &tbl_name_in_edw.  A,
		         DSS_CLIN.V_ALGN_LVL_GRP_DTL B, 
                 DSS_CLIN.V_MBR_ELIG C, 
                 DSS_CLIN.V_MBR D, 
                 DSS_CLIN.V_ALGN_LVL_DENORM E

        where  B.ALGN_GRP_STUS_CD = 'A'
          AND  B.ALGN_GRP_EFF_DT <= to_date(&chk_dt_oracle,'yyyy-mm-dd') 
          and  B.ALGN_GRP_END_DT >= to_date(&chk_dt_oracle,'yyyy-mm-dd') 
		      AND  B.ALGN_LVL_GID = C.ALGN_LVL_GID
          and  C.ELIG_REC_STUS_CD = 'A' 
		      and  C.SRC_SYS_CD = &ADJ
          and  C.ELIG_EFF_DT <= to_date(&chk_dt_oracle,'yyyy-mm-dd') 
          and  C.ELIG_END_DT >= to_date(&chk_dt_oracle,'yyyy-mm-dd')  
          and  C.MBR_GID = A.MBR_GID 
          and  C.PAYER_ID = A.PAYER_ID
    		  and  C.mbr_id   = A.mbr_id
          and  C.MBR_GID = D.MBR_GID 
		      and  A.ALGN_LVL_GID_KEY = C.ALGN_LVL_GID 
          and  C.ALGN_LVL_GID     = E.ALGN_LVL_GID_KEY 
          and a.payer_id &PAYER_ID_CONS.
 
	    group by A.mbr_id, 
	             A.payer_id
        );
     DISCONNECT FROM oracle;
   QUIT;
  %end;

  %if &re_adj eq 1 AND &adj='R' %then %do;
   proc sql;
        CONNECT TO ORACLE(PATH=&GOLD );
        CREATE TABLE &ora_tmp..PTSa&adj2.&INIT_ID AS
        SELECT * FROM CONNECTION TO ORACLE
      (
	    select   A.mbr_id, 
	 	         A.payer_id,
		        COUNT(*) AS COUNT 
	    from     &tbl_name_in_edw.  A,
		         DSS_CLIN.V_ALGN_LVL_INFO B, 
                 DSS_CLIN.V_MBR_ELIG C, 
                 DSS_CLIN.V_MBR D 

        where  B.ALGN_GRP_EFF_DT <= to_date(&chk_dt_oracle,'yyyy-mm-dd') 
          and  B.ALGN_GRP_END_DT >= to_date(&chk_dt_oracle,'yyyy-mm-dd') 
    		  AND  B.ALGN_LVL_GID = C.ALGN_LVL_GID
          and  C.ELIG_REC_STUS_CD = 'A' 
    		  and  C.SRC_SYS_CD = &ADJ
          and  C.ELIG_EFF_DT <=  to_date(&chk_dt_oracle,'yyyy-mm-dd') 
          and  C.ELIG_END_DT >=  to_date(&chk_dt_oracle,'yyyy-mm-dd')  
    		  and  C.MBR_GID = A.MBR_GID 
    		  and  C.PAYER_ID = A.PAYER_ID 
    		  and  C.mbr_id   = A.mbr_id
          and  C.MBR_GID = D.MBR_GID
          and  A.ALGN_LVL_GID_KEY = C.ALGN_LVL_GID 
          and a.payer_id &PAYER_ID_CONS.
 
	    group by A.mbr_id, 
	             A.payer_id
        );
     DISCONNECT FROM oracle;
   QUIT;
  %end;

    proc sql;
      CONNECT TO ORACLE(PATH=&GOLD );
      CREATE TABLE &ora_tmp..PTSb&adj2.&INIT_ID. AS	  
      SELECT * FROM CONNECTION TO ORACLE
     (

	  SELECT  distinct A.mbr_id,
                       A.payer_id
       FROM   &ora_tmp..PTSa&adj2.&INIT_ID. A          
       ORDER BY  a.mbr_id, a.payer_id
      );
     DISCONNECT FROM oracle;
     QUIT;



*SASDOC----------------------------------------------------------------------
|   N. Williams July 2009 - end
|   Added this query to custom edw eligilibity check for Med-D members
+---------------------------------------------------------------------SASDOC*;


/* this is the old logic*/
/*     proc sql;*/
/*        CONNECT TO ORACLE(PATH=&GOLD );*/
/*        CREATE TABLE &ora_tmp..PTSa&adj2.&INIT_ID AS*/
/*        SELECT * FROM CONNECTION TO ORACLE*/
/*      (*/
/*	    select   mbr_id, */
/*	 	         payer_id,*/
/*		        COUNT(*) AS COUNT */
/*	    from     &tbl_name_in_edw.*/
/*	    group by mbr_id, */
/*	           payer_id*/
/*        );*/
/*     DISCONNECT FROM oracle;*/
/*   QUIT;*/
/**/
/**/
/*    proc sql;*/
/*       CONNECT TO ORACLE(PATH=&GOLD );*/
/*      CREATE TABLE &ora_tmp..PTSb&adj2.&INIT_ID. AS*/
/*      SELECT * FROM CONNECTION TO ORACLE*/
/*     (*/
/**/
/*	  SELECT  distinct A.mbr_id,*/
/*                       A.payer_id*/
/*          FROM  &ora_tmp..PTSa&adj2.&INIT_ID. A 	 */
/*          */
/*          	 INNER JOIN*/
/*          	 */
/*             DSS_CLIN.V_MBR_ELIG B*/
/*                 ON A.mbr_id = B.mbr_id and*/
/*				    a.payer_id = b.payer_id*/
/*                 &ELIG_STREDW.*/
/*				 and SRC_SYS_CD = &ADJ */
/*           ORDER BY  a.mbr_id, a.payer_id*/
/*      );*/
/*     DISCONNECT FROM oracle;*/
/*     QUIT;*/

%drop_oracle_table(tbl_name=&tbl_name_out2_edw);

%IF &Execute_condition_flag.=1 %THEN  %DO;

      proc sql;
        CONNECT TO ORACLE(PATH=&GOLD );
        CREATE TABLE &tbl_name_out2_edw. AS
        SELECT * FROM CONNECTION TO ORACLE
      (

	    SELECT A.*
          FROM  &tbl_name_in_edw. A 	 
          
          	 inner JOIN
          	 
                &ora_tmp..PTSb&adj2.&INIT_ID. B
                 ON A.mbr_id = B.mbr_id and
				    a.payer_id = b.payer_id

      );
     DISCONNECT FROM oracle;
     QUIT;

%END; /* End of &Execute_condition_flag.=1 */
%ELSE %DO;

      proc sql;
       CONNECT TO ORACLE(PATH=&GOLD );
       CREATE TABLE &tbl_name_out2_edw. AS
        SELECT * FROM CONNECTION TO ORACLE
      (

	    SELECT A.*
          FROM  &tbl_name_in_edw. A 	 
          
          	 left JOIN
          	 
             &ora_tmp..PTSb&adj2.&INIT_ID. B
                 ON A.mbr_id = B.mbr_id and
				    a.payer_id = b.payer_id

           ORDER BY  a.mbr_id,a.payer_id
       );
         DISCONNECT FROM oracle;
        QUIT;

%END;



%set_error_fl;


%drop_oracle_table(tbl_name=&ora_tmp..PTSa&adj2.&INIT_ID.);
%drop_oracle_table(tbl_name=&ora_tmp..PTSb&adj2.&INIT_ID.); 
      
%EXIT2:;
%mend EDWCHKELIG;


*SASDOC----------------------------------------------------------------------
| Apr  2008    - CARL STARKS
| Added logic to check to see which adjudication to run and pass the input and 
| output names.
|
+---------------------------------------------------------------------SASDOC*;


%if &rx_adj eq 1 %then %do;
  %EDWCHKELIG(adj='X',tbl_name_in_edw=&tbl_name_in_rx,tbl_name_out_edw=&tbl_name_rx_out,
              tbl_name_out2_edw=&tbl_name_rx_out2,adj2=RX,hier_cd=Account_Id) ; 
%end;

%if &re_adj eq 1 %then %do;
  %EDWCHKELIG(adj='R',tbl_name_in_edw=&tbl_name_in_re,tbl_name_out_edw=&tbl_name_re_out,
              tbl_name_out2_edw=&tbl_name_re_out2,adj2=RE,hier_cd=insurance_cd) ; 
%end;

%MEND ELIGIBILITY_CHECK_NEGFRM;
