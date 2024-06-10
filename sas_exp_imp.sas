/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Monday, October 07, 2002      TIME: 10:38:54 AM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Tuesday, January 15, 2002      TIME: 05:35:50 PM
   PROJECT: macros
   PROJECT PATH: C:\Caremark\EG_projects\macros.seg
---------------------------------------- */
%MACRO sas_exp_imp;
  %GLOBAL err_cd message SYSDBMSG;
  %GLOBAL sas_tbl_name1 sas_tbl_name2;

  %LET sas_tbl_name1=; %LET sas_tbl_name2=; 

    DATA _NULL_;

 ARRAY db_name{2}      $ 32    db_name_in        db_name_out ;
 ARRAY schema{2}       $ 32    schema_in         schema_out;
 ARRAY tbl_name{2}     $ 1000  tbl_name_in       tbl_name_out;
 ARRAY sas_tbl_name{2} $ 1000  sas_tbl_name_in   sas_tbl_name_out;
 ARRAY tbl_name_sh{2}  $ 32    tbl_name_sh_in    tbl_name_sh_out;
 ARRAY F_type{2}       $ 32    File_type_in      File_type_out;
 ARRAY F_type_cd{2}      3     File_type_in_cd   File_type_out_cd;
 ARRAY A_user{2}       $ 32    user_in           user_out;
 ARRAY A_passw{2}      $ 32    password_in       password_out;

 ARRAY str_Libname{2}   $ 1000  str_Libname_in    str_Libname_out;
 ARRAY str_Libname_R{2} $ 1000  str_Libname_R_in  str_Libname_R_out;
 ARRAY connect_srv{2}  	$ 32    connect_srv_in    connect_srv_out;
 ARRAY connect_srv_M{2} $ 32   connect_srv_M_in   connect_srv_M_out;

 DO i=1 TO 2;
       db_name{i}   = SYMGET(VNAME(db_name{i}));
       tbl_name{i}  = SYMGET(VNAME(tbl_name{i}));
       F_type{i}    = SYMGET(VNAME(F_type{i}));
       A_user{i}    = SYMGET(VNAME(A_user{i}));
       A_passw{i}   = SYMGET(VNAME(A_passw{i}));

        IF  F_type{i}='' THEN F_type{i}='SAS';
        IF  F_type{i}='DB2' AND db_name{i}='' THEN db_name{i}='UDBSPRP';


      pos=INDEX(TRIM(tbl_name{i}),'.');
	  pos2=INDEX(TRIM(db_name{i}),'.');
	  

       IF pos =0 THEN  tbl_name_sh{i}=tbl_name{i};
       ELSE
                     DO;
      schema{i}=UPCASE(SUBSTR(tbl_name{i},1,pos-1));
      tbl_name_sh{i}=SUBSTR(tbl_name{i},pos+1);
                     END;

	  IF pos2 = 0 THEN  connect_srv{i}='';
	  ELSE
                     DO;
      connect_srv{i}=LOWCASE(SUBSTR(db_name{i},1,pos2-1));
	  connect_srv_M{i}='%'  || TRIM(connect_srv{i});
      db_name{i}=SUBSTR(db_name{i},pos2+1);
                     END;

 IF F_type{i} ='SAS' THEN
                      DO;
               sas_tbl_name{i}=tbl_name{i};
               F_type_cd{i}=1;
                      END;

 ELSE IF F_type{i} IN ('DB2','ODBC')  THEN
                 DO;
      F_type_cd{i}=2;
      sas_tbl_name{i}='remote' || TRIM(LEFT(i)) || '.' || TRIM(tbl_name_sh{i});

   IF schema{i}  NE '' THEN  schema{i} =' SCHEMA=' || TRIM(schema{i});
   IF A_user{i}  NE '' THEN  A_user{i} =' UID='    || TRIM(A_user{i});
   IF A_passw{i} NE '' THEN  A_passw{i}=' PWD='   || TRIM(A_passw{i});

   str_Libname{i}="remote" || TRIM(LEFT(i)) || ' ' || TRIM(F_Type{i})
                   || " DSN=" || TRIM(db_name{i}) ||
                   TRIM(schema{i}) || TRIM(A_user{i}) || TRIM(A_passw{i});

  IF str_Libname{i} NE '' THEN str_Libname{i}='LIBNAME ' || TRIM(str_Libname{i});

  IF connect_srv{i} NE '' THEN DO;
   str_Libname_R{i}=str_Libname{i};
   str_Libname{i}='remote' || TRIM(LEFT(i)) || 
				  ' REMOTE SERVER=' || TRIM(connect_srv{i}) || 
				  ' RENGINE=' || TRIM(F_Type{i})  || 
                  ' ROPTIONS= " DSN=' || TRIM(db_name{i}) ||
                    TRIM(schema{i}) || TRIM(A_user{i}) || 
					TRIM(A_passw{i}) ||
				  ' "';
 IF str_Libname{i} NE '' THEN str_Libname{i}='LIBNAME ' || TRIM(str_Libname{i});
 
  							   END;
                END;

* ELSE IF SUBSTR(F_type{i},1,3) IN ('DEL') THEN F_type_cd{i}=3;
ELSE DO;
    CALL SYMPUT('err_cd','1');
    CALL SYMPUT('Message',"Invalid File_type=" || TRIM(F_type{i}) || ' for Engine SAS');
   STOP;
     END;

       CALL SYMPUT("sas_tbl_name" || TRIM(LEFT(i)),TRIM(sas_tbl_name{i}));
       CALL SYMPUT("tbl_name_sh" || TRIM(LEFT(i)),TRIM(tbl_name_sh{i}));
       CALL SYMPUT("F_type_cd" || TRIM(LEFT(i)),TRIM(F_type_cd{i}));
	   CALL SYMPUT("connect_srv" || TRIM(LEFT(i)),TRIM(connect_srv{i}));
	   CALL SYMPUT("connect_srv_M" || TRIM(LEFT(i)),TRIM(connect_srv_M{i}));
	    CALL SYMPUT("str_Libname" || TRIM(LEFT(i)), TRIM(str_Libname{i}));
 		CALL SYMPUT("str_Libname_R" || TRIM(LEFT(i)), TRIM(str_Libname_R{i}));

	  *   PUT _ALL_;
END; /* End of [i] loop */ ;

   IF  _ERROR_  THEN    DO;
                    CALL SYMPUT('err_cd','1');
                    CALL SYMPUT('Message',SYSMSG());
                      STOP;
                       END;
RUN;

     %DO i=1 %TO 2;
	   		&&connect_srv_M&i;
         %IF &&F_type_cd&i=2 %THEN
                 %DO;
           &&str_Libname&i;
            %IF &SYSLIBRC NE 0 %THEN
                               %DO;
                          %LET err_cd=2;
                          %LET MESSAGE=ERROR in  &&str_Libname&i &SYSDBMSG ;
                                %END;
                  %END;
        %END;

 %LOCAL str_DS_Opt_in  str_DS_Opt_out;

DATA _NULL_;
            IF "&err_cd" =2 THEN STOP;

    LENGTH Import_Method $ 32 str_Update $ 1000 keys $ 1000 
			str_Where_sub $ 5000 str_temp $ 200 str_temp2 $ 5
			sas_tbl_name1_tmp $ 1000 tbl_name_sh1_tmp $ 32
			view_name_sh1_tmp $ 32 fields_tmp $ 30000 
			str_Where_in_tmp $ 1000;

 ARRAY tbl_name{2}     $ 1000  tbl_name_in       tbl_name_out;
 ARRAY sas_tbl_name{2} $ 1000  sas_tbl_name1   sas_tbl_name2;
 ARRAY tbl_exst_fl{2}    3     tbl_exst_fl1    tbl_exst_fl2;
 ARRAY F_type{2}       $ 32   File_type_in    File_type_out;
 ARRAY F_type_cd{2}      3     F_type_cd1      F_type_cd2;
 ARRAY str_Where{2}    $ 1000  str_Where_in    str_Where_out;
 ARRAY str_DS_Opt{2}    $ 1000  str_DS_Opt_in  str_DS_Opt_out;

 RETAIN j 1  str_Where_sub str_temp '';

       Import_Method="&Import_Method";
	   keys="&keys";
	   keys=TRANSLATE(TRIM(LEFT(keys)),' ',',');

	   tbl_name_sh1_tmp='_t' || TRIM(LEFT(INT(DATETIME())));
	   view_name_sh1_tmp='_v' || TRIM(LEFT(INT(DATETIME())));

       DO i=1 TO 2;
        F_type{i}       = SYMGET(VNAME(F_type{i}));
        F_type_cd{i}    = SYMGET(VNAME(F_type_cd{i}));
        str_Where{i}    = SYMGET(VNAME(str_Where{i}));
		tbl_name{i}  	= SYMGET(VNAME(tbl_name{i}));
        sas_tbl_name{i} = SYMGET(VNAME(sas_tbl_name{i}));

  IF    str_Where{i} NE '' THEN
                               DO;
    IF    Import_Method ='INSERT_UPDATE_SAS'
    THEN  str_DS_Opt{i}=' WHERE=(' || TRIM(str_Where{i}) || ')';
          str_Where{i}=' WHERE ' || TRIM(str_Where{i});
                                END;
		tbl_exst_fl{i}=EXIST(sas_tbl_name{i},"DATA");
       END;
/*
   IF tbl_exst_fl1=0 THEN
                           DO;
    CALL SYMPUT("err_cd","1");
    CALL SYMPUT("Message","Input Table &tbl_name_in does not exist");
                          STOP;
                           END;
*/

IF  TRIM(Import_Method) IN ('CREATE','REPLACE_CREATE','REPLACE') THEN
 DO;
      str_Update='CREATE TABLE '|| TRIM(sas_tbl_name2) || ' AS ';

  IF  tbl_exst_fl2=1 THEN
   DO;
      IF     TRIM(Import_Method) IN ('CREATE') THEN
         str_Update=' DROP TABLE '|| TRIM(sas_tbl_name2) || ' ; '
                                || TRIM(str_Update) ;

      ELSE IF TRIM(Import_Method) IN ('REPLACE_CREATE','REPLACE')  THEN
         str_Update=' DELETE FROM ' || TRIM(sas_tbl_name2) || ' ' || TRIM(str_Where_out)
                    ||  ';' || ' INSERT INTO ' || TRIM(sas_tbl_name2) || ' ';
   END;
 END;

ELSE IF TRIM(Import_Method) IN('INSERT','INSERT_UPDATE_SAS','INSERT_UPDATE')  THEN
 DO;

    sas_tbl_name1_tmp=sas_tbl_name1;
	str_Where_in_tmp=str_Where_in;
	fields_tmp=SYMGET('fields');

	IF "&connect_srv1" NE "&connect_srv2" AND  ("&connect_srv1" NE '' OR "&connect_srv2" NE '')
	THEN DO;
 		sas_tbl_name1_tmp=tbl_name_sh1_tmp;
		str_Where_in_tmp='';
		fields_tmp='*';
		 END;

   IF  tbl_exst_fl2=0 THEN
    DO;
   CALL SYMPUT('err_cd','1');
   CALL SYMPUT('Message',"Output Table tbl_name_out=" || TRIM(tbl_name_out) || " does not exist."
                         || " Tbl_name_out must exist for Import_Method=&Import_Method");
   STOP;
    END;

   ELSE IF TRIM(Import_Method) IN('INSERT')  THEN
            str_Update=' INSERT INTO ' || TRIM(sas_tbl_name2) || ' ';

   ELSE IF TRIM(Import_Method)  IN ('INSERT_UPDATE_SAS','INSERT_UPDATE')  THEN
    DO;
       IF "&keys" ='' THEN
                                DO;
         CALL SYMPUT('err_cd','1');
         CALL SYMPUT('Message',"Error: Keys must be defined for Import_Method=&Import_Method");
                               STOP;
                                END;
       ELSE
                                 DO;
       str_DS_Opt_out =" DBKEY=(" || TRIM(keys) || ')';
   IF str_DS_Opt_in  NE '' THEN str_DS_Opt_in= '( ' || TRIM(str_DS_Opt_in)  || ')';
         
  IF TRIM(Import_Method)  IN ('INSERT_UPDATE_SAS') THEN 
          DO; 
   IF str_DS_Opt_out NE '' THEN str_DS_Opt_out='( ' || TRIM(str_DS_Opt_out) || ')';
          END;
	 ELSE DO;
	           		j=1;
	           DO UNTIL (str_temp = ' ' );			   
    str_temp=TRIM(LEFT(SCAN(keys,j,' ')));
	IF j=1 THEN str_temp2='';
	ELSE 		str_temp2=' AND ';
	str_Where_sub=TRIM(str_Where_sub) || str_temp2 ||
				  TRIM(str_temp) || '=X.' || TRIM(str_temp);
	          j=j+1;
	str_temp= TRIM(LEFT(SCAN(keys,j,' ')));
			    END;

	str_Where_sub='WHERE EXISTS (SELECT 1 '  ||
				   ' FROM (SELECT ' || TRIM(fields_tmp) || ' FROM ' || 
					TRIM(sas_tbl_name1_tmp) || ' ' || TRIM(str_Where_in_tmp) || ") AS X "	||
					'WHERE ' ||  TRIM(str_Where_sub) || ')';

	   str_Update=' DELETE FROM ' || TRIM(sas_tbl_name2) || ' ' || TRIM(str_Where_sub)
                    ||  ';' || ' INSERT INTO ' || TRIM(sas_tbl_name2) || ' ';
	      END;

         CALL SYMPUT("str_DS_Opt_in" ,TRIM(str_DS_Opt_in));
         CALL SYMPUT("str_DS_Opt_out",TRIM(str_DS_Opt_out));
                                 END;
    END;  /*End INSERT_UPDATE*/
   ELSE
           DO;
     CALL SYMPUT('err_cd','1');
     CALL SYMPUT('Message',"Invalid Import_Method=&Import_Method.");
   STOP;
           END;
 END;
              CALL SYMPUT("str_Update",TRIM(str_Update));
              CALL SYMPUT("str_Where_in" ,TRIM(str_Where_in));
              CALL SYMPUT("str_Where_out" ,TRIM(str_Where_out));
			  CALL SYMPUT("tbl_name_sh1_tmp" ,TRIM(tbl_name_sh1_tmp));
			  CALL SYMPUT("view_name_sh1_tmp" ,TRIM(view_name_sh1_tmp));

    IF  _ERROR_  THEN    DO;
                     CALL SYMPUT('err_cd','1');
                     CALL SYMPUT('Message',SYSMSG());
                       STOP;
                        END;
		PUT _ALL_;
    RUN;


  %IF &connect_srv1	NE AND &err_cd=0 %THEN 
	%DO;

    %IF &connect_srv2 NE  AND &connect_srv1 NE &connect_srv2 
	%THEN 	SIGNOFF REMOTE=&connect_srv2 CSCRIPT=&&_&connect_srv2;;

		     &connect_srv_M1;;

		   %SYSLPUT connect_srv1=&connect_srv1;
		   %SYSLPUT connect_srv2=&connect_srv2;	
		   %SYSLPUT sas_tbl_name1=&sas_tbl_name1;
		   %SYSLPUT tbl_name_sh1_tmp=&tbl_name_sh1_tmp;
		   %SYSLPUT view_name_sh1_tmp=&view_name_sh1_tmp;
		   %SYSLPUT str_Libname_R1=&str_Libname_R1;
		   %SYSLPUT fields=&fields;
		   %SYSLPUT str_Where_in=&str_Where_in;
		   %SYSLPUT Err_cd=&Err_cd;
		   %SYSLPUT Message=&Message;
		   %SYSLPUT SYSDBMSG=&SYSDBMSG;

		    RSUBMIT REMOTE=&connect_srv1;
	%MACRO download;
		&str_Libname_R1;
%IF &connect_srv1 NE &connect_srv2 %THEN 
 										  %DO;
	PROC SQL DQUOTE=ANSI; 
      CREATE VIEW &view_name_sh1_tmp AS SELECT &fields FROM &sas_tbl_name1
		&str_Where_in;
	 QUIT;

    PROC DOWNLOAD DATA=&view_name_sh1_tmp OUT=&tbl_name_sh1_tmp STATUS=NO ;	 
     RUN;
    QUIT;
	 %IF &SYSINFO NE 0 %THEN 
							%DO;
						  %LET err_cd=2;
						  %LET MESSAGE=ERROR in PROC DOWNLOAD;
							%END;
	PROC SQL DQUOTE=ANSI; DROP VIEW &view_name_sh1_tmp ; QUIT;

		%SYSRPUT err_cd=&err_cd;
		%SYSRPUT MESSAGE=&MESSAGE;
		%SYSRPUT sas_tbl_name1=&tbl_name_sh1_tmp;
											%END;
	%MEND download;
					%download;
					ENDRSUBMIT;;

		%LET fields=*;
		%LET str_Where_in=;
		%LET str_DS_Opt_in= ;
	%END;

	 %IF &connect_srv1	NE AND &connect_srv1 NE &connect_srv2 %THEN 
								%DO;
		SIGNOFF REMOTE=&connect_srv1 CSCRIPT=&&_&connect_srv1;
				                %END;
 
   %IF &connect_srv2 NE AND &err_cd=0 %THEN 
															%DO; /* connect_srv2 */
		   &connect_srv_M2;;

	 PROC SQL DQUOTE=ANSI; 
      CREATE VIEW &view_name_sh1_tmp AS SELECT &fields FROM &sas_tbl_name1
		&str_Where_in;
	 QUIT;
		  
		   %SYSLPUT connect_srv1=&connect_srv1;
		   %SYSLPUT connect_srv2=&connect_srv2;
		   %SYSLPUT err_cd=&err_cd;
		   %SYSLPUT Message=&Message;	
		   %SYSLPUT sas_tbl_name1=&sas_tbl_name1;
		   %SYSLPUT sas_tbl_name2=&sas_tbl_name2;
		   %SYSLPUT tbl_name_sh1=&tbl_name_sh1;
		   %SYSLPUT tbl_name_sh2=&tbl_name_sh2;
		   %SYSLPUT tbl_name_sh1_tmp=&tbl_name_sh1_tmp;
		   %SYSLPUT view_name_sh1_tmp=&view_name_sh1_tmp;
		   %SYSLPUT str_Libname_R2=&str_Libname_R2;
		   %SYSLPUT Import_Method=&Import_Method;		  
		   %SYSLPUT str_DS_Opt_in= ;
		   %SYSLPUT str_DS_Opt_out=&str_DS_Opt_out;
		   %SYSLPUT str_Where_in= ;
		   %SYSLPUT str_Where_out=&str_Where_out;
		   %SYSLPUT str_Update=&str_Update;
		   %SYSLPUT fields=*;

		   RSUBMIT REMOTE=&connect_srv2;
 
%MACRO upload;
			 &str_Libname_R2;
%IF &connect_srv1 NE &connect_srv2 %THEN 
 										  %DO;
    PROC UPLOAD DATA=&view_name_sh1_tmp. OUT=&tbl_name_sh1_tmp STATUS=NO ;
     RUN;
    QUIT;

	 %IF &SYSINFO NE 0 %THEN 
							%DO;
					     %LET err_cd=2;
						 %LET MESSAGE=ERROR in PROC UPLOAD;
							%END;
	 %ELSE				 %LET sas_tbl_name1=&tbl_name_sh1_tmp;

										   %END;
%MEND upload;
				  %upload;
															%END; /* connect_srv2 */
 %IF &err_cd=0 %THEN
  %DO;

%MACRO update;
    %IF   &Import_Method EQ INSERT_UPDATE_SAS %THEN
     %DO;
       DATA work.&tbl_name_sh2.;
        UPDATE &sas_tbl_name2.&str_DS_Opt_out
               &sas_tbl_name1.&str_DS_Opt_in;
         BY &keys;
		  IF  _ERROR_  THEN    DO;
                     CALL SYMPUT('err_cd','1');
                     CALL SYMPUT('Message',SYSMSG());
                       STOP;
                        END;
       RUN;
	   %LET MESSAGE=%SUPERQ(Message);

        %IF &SYSERR=0 %THEN
                            %DO;
     PROC SQL DQUOTE=ANSI UNDO_POLICY=REQUIRED;
      DELETE FROM &sas_tbl_name2.;
      INSERT INTO  &sas_tbl_name2.
        SELECT * FROM work.&tbl_name_sh2.;
      DROP TABLE  work.&tbl_name_sh2.;
      QUIT;
	   %IF  &SQLRC NE 0 %THEN %DO; %LET Err_cd=3; %END; 
                             %END;
		%ELSE				 %DO;
		        		%LET Err_cd=3;
						%LET Message=Error in the Update statement;
							 %END;
	
      %END; /* End of do-group for INSERT_UPDATE_SAS */

    %ELSE %IF &Import_Method EQ CREATE OR &Import_Method EQ REPLACE_CREATE OR
              &Import_Method EQ REPLACE OR &Import_Method EQ INSERT	OR
			  &Import_Method EQ INSERT_UPDATE
            %THEN
                 %DO;
     PROC SQL DQUOTE=ANSI  UNDO_POLICY=REQUIRED;
      &str_Update
       SELECT  &fields
        FROM &sas_tbl_name1
         &str_Where_in;
     QUIT;

	  %IF  &SQLRC NE 0 OR &SYSDBRC NE 0 OR &SYSERR NE 0 %THEN 
								%DO; 
							%LET Err_cd=3;
							%LET Message=Error in the SQL statement.; 
								%END; 
                  %END;
     %ELSE
       %DO;
          %LET err_cd=1;
          %LET Message=Invalid Import_Method &Import_Method;
        %END;

 %IF &err_cd=0 AND &SQLRC NE 0 %THEN %LET err_cd=3;
  %LET MESSAGE=%SUPERQ(Message) &SYSDBMSG;
					
%IF &connect_srv2 NE  %THEN 
								%DO;
		          	%SYSRPUT err_cd=&err_cd;
					%SYSRPUT MESSAGE=&MESSAGE;
				                %END;
%MEND update;
			 %update;
 %END; /* Do-group for  err_cd=0 */
			 %IF &connect_srv2	NE  %THEN 
								%DO;
				  ENDRSUBMIT;
				  SIGNOFF REMOTE=&connect_srv2 CSCRIPT=&&_&connect_srv2;
				                %END;

	%IF &connect_srv1 NE  AND %SYSFUNC(EXIST(&tbl_name_sh1_tmp,DATA))=1 %THEN 
					%DO;
			PROC SQL; DROP TABLE  &tbl_name_sh1_tmp; QUIT;
					%END;;

 %IF &connect_srv2 NE  AND %SYSFUNC(EXIST(&view_name_sh1_tmp,VIEW))=1 %THEN 
					%DO;
		   PROC SQL DQUOTE=ANSI; DROP VIEW &view_name_sh1_tmp ; QUIT;
		    		%END;;
  %LET rc=%SYSFUNC(LIBNAME(remote1));
  %LET rc=%SYSFUNC(LIBNAME(remote2));
 


 * %PUT tbl_name_out=&sas_tbl_name2 Err_cd=&Err_cd MESSAGE=%SUPERQ(Message); 
%MEND;
