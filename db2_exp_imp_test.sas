/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Monday, October 07, 2002      TIME: 10:39:51 AM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Wednesday, June 19, 2002      TIME: 03:33:42 PM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */
 %MACRO db2_exp_imp_test;
   %GLOBAL err_cd message;


   DATA _NULL_;
     LENGTH File_type $ 32 File_ext $ 3 Str_Coldel $ 32 del $ 1
            chardel $ 2 str_Action $ 50 str_Connect $ 1000 str_DB2 $ 10000
            db2_home_schema $ 8 Import_Method $ 32;
        
 ARRAY db_name{2}      $ 32    db_name_in        db_name_out ; 
 ARRAY tbl_name{2}     $ 1000  tbl_name_in       tbl_name_out; 
 ARRAY tb_short{2}     $ 32    tb_short_in       tb_short_out;
 ARRAY F_type{2}       $ 32    File_type_in      File_type_out;
 ARRAY str_Where{2}    $ 1000  str_Where_in      str_Where_out;
 ARRAY A_user{2}       $ 32    user_in           user_out;
 ARRAY A_passw{2}      $ 32    password_in       password_out;
       
 DO i=1 TO 2; 
          
       db_name{i}   = SYMGET(VNAME(db_name{i}));
       tbl_name{i}  = DEQUOTE(SYMGET(VNAME(tbl_name{i})));
       F_type{i}    = SYMGET(VNAME(F_type{i}));
       str_Where{i} = SYMGET(VNAME(str_Where{i}));
       A_user{i}    = SYMGET(VNAME(A_user{i}));
       A_passw{i}   = SYMGET(VNAME(A_passw{i}));

     IF F_type{i}='' THEN F_type{i}='DB2';
      IF F_type{i}='DB2' THEN   db2_home_schema=A_user{i};
     IF db2_home_schema='' THEN db2_home_schema="&SYSUSERID";
END;

 
 DO i=1 TO 2;     
   IF F_type{i}='DB2' THEN
     DO;     
         IF   INDEX(tbl_name{i},'.')=0 AND db2_home_schema NE ''
         THEN tbl_name{i}=TRIM(db2_home_schema) || '.' || TRIM(tbl_name{i});
         
            Utility_fl=i; 
  
          If i=1 THEN File_type=File_type_out;
          ELSE        File_type=File_type_in;
          
 IF tbl_name{i}='' THEN
         DO;
  CALL SYMPUT('err_cd','1');
  CALL SYMPUT('Message',"Error: Parameters " || TRIM(VNAME(tbl_name{i})) || " is not specified");
        STOP;
         END;
    END;
    
   IF A_user{i}    NE '' THEN  A_user{i} = ' USER '       || TRIM(A_user{i});
   IF A_passw{i}   NE '' THEN  A_passw{i}= ' USING '      || TRIM(A_passw{i});
   IF db_name{i}   NE '' THEN  db_name{i}= ' TO '         || TRIM(db_name{i});
   IF str_Where{i} NE '' THEN  str_Where{i}= ' WHERE '    || TRIM(str_Where{i});
  
 END; /* End of loop */

 IF (FILE_type_in NE 'DB2' AND FILE_type_out NE 'DB2' ) OR
    (FILE_type_in EQ 'DB2' AND FILE_type_out EQ 'DB2' ) 
 THEN              
                                                      DO;
      CALL SYMPUT('err_cd','1');
      CALL SYMPUT('Message',"Error in the input or output File_type for Engine DB2_Exp_Imp" || 
                            " File_Type_in=" || TRIM(File_Type_in) || 
                            " File_Type_out=" || TRIM(File_Type_out));
                                                     STOP;
                                                      END;

       Import_Method="&Import_Method";
       File_type=LEFT(UPCASE(File_type));
       File_ext=UPCASE(SUBSTR(File_type,1,3));
       Del=SUBSTR(File_type,4,1);
       IF Del='' THEN del=',';
       chardel=LEFT(SUBSTR(File_type,5,2));
       IF TRIM(chardel)='1' THEN chardel="''";

       IF       File_ext NOT IN ('DEL','IXF') OR
                del NOT IN (',','*',':','|','&','/',';','=')
       THEN  DO;
           CALL SYMPUT('err_cd','1');
           CALL SYMPUT('Message',"Invalid File_type=" || TRIM(File_type));
            STOP;
            END;

       IF   File_ext='IXF' THEN Str_Coldel='';
       ELSE
           DO;
  Str_Coldel = " MODIFIED BY COLDEL" || del;
 IF TRIM(chardel) NE ''
 THEN Str_Coldel =TRIM(Str_Coldel) || " CHARDEL" || TRIM(chardel);
            END;
            

IF Utility_fl=1 THEN    
                        DO;
  str_Connect="CONNECT" || TRIM(db_name_in) || TRIM(user_in) || TRIM(password_in) ;
  str_Connect1 = "TEST FOR CONNECT STATEMENT";
  
str_Connect=QUOTE(TRIM(str_Connect1)) || " >> &tbl_name_out..msg";
 
  str_DB2="EXPORT TO " || TRIM(tbl_name_out) || " OF " || TRIM(File_ext) ||
           TRIM(Str_Coldel) ||
           " SELECT &fields FROM " || TRIM(tbl_name_in) || TRIM(str_Where_in);
             CALL SYMPUT('msg_tmp'," &tbl_name_out..msg");
  str_DB2=QUOTE(TRIM(str_DB2)) || " >> &tbl_name_out..msg";           
                         END;

ELSE                     DO;

IF      TRIM(Import_Method)='CREATE' THEN    str_Action="CREATE INTO";
ELSE    str_Action= TRIM(Import_Method) || " INTO" ;

 str_Connect="CONNECT" || TRIM(db_name_out) || TRIM(user_out) || TRIM(password_out);
 str_Connect1 = "TEST FOR CONNECT STATEMENT";
 str_Connect=QUOTE(TRIM(str_Connect1)) || " >> &tbl_name_in..msg";

 str_DB2="IMPORT FROM " || TRIM(tbl_name_in) || " OF " || File_ext ||
          TRIM(Str_Coldel) || ' ' || TRIM(str_Action) ||
          " " || TRIM(tbl_name_out);
           CALL SYMPUT('msg_tmp'," &tbl_name_in..msg");
 str_DB2=QUOTE(TRIM(str_DB2)) || " >> &tbl_name_in..msg"; 
                         END;

  rc1=SYSTEM('db2 '|| TRIM(str_Connect));
  
 IF rc1 THEN  CALL SYMPUT('err_cd','2');

 ELSE                 DO;

  rc2=SYSTEM('db2 ' || TRIM(str_DB2));

 IF rc2 THEN CALL SYMPUT('err_cd','3');


  rc3=SYSTEM("db2 connect reset") ;
  rc4=SYSTEM("db2 terminate") ;
                     END;

  rc=MAX(rc1,rc2,rc3,rc4);

IF  _ERROR_  THEN    DO;
                 CALL SYMPUT('err_cd','1');
                 CALL SYMPUT('Message',SYSMSG());
                   STOP;
                    END;
     PUT _ALL_ ;    
  RUN;


%IF   &err_cd NE 1 %THEN
                         %DO;
      DATA _NULL_;
       LENGTH Message $ 2000;
       RETAIN Message '';
        INFILE "&msg_tmp"  END=end TRUNCOVER ;
         INPUT ;

      _INFILE_ =LEFT(COMPBL(_INFILE_));
      end_pos=LENGTH(TRIM(Message));

  IF      TRIM(Message)=''  THEN Message=TRIMN(_INFILE_);
  ELSE IF SUBSTR(Message,end_pos,1)='.'
   THEN   Message=TRIMN(Message) || ' '|| TRIMN(_INFILE_);
  ELSE    Message=TRIMN(Message) || '. '|| TRIMN(_INFILE_);

     IF end  THEN CALL SYMPUT('Message',TRIM(Message));
    * IF end  THEN   PUT Message=;
       RUN;

                         %END;

%MEND;
