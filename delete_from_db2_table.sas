 /*HEADER -------------------------------------------------------------------------
 |
 |    PROGRAM NAME: 
 |        delete_from_db2_table.sas - Macro to Delete From DB2 Table
 |
 |    LOCATION:
 |        /PRG/sasprod1/sas_macros/
 |
 |    PURPOSE:  
 |         
 |
 |    FREQUENCY: 
 |        Monthly        
 |
 |    LOGIC:
 |        
 |
 |    INPUT:
 |        -----------------------------------------------------------------------
 |        UDB TABLES:
 |        -----------------------------------------------------------------------
 |            
 |
 |        -----------------------------------------------------------------------
 |        SAS DATASETS:
 |        -----------------------------------------------------------------------
 |            
 |            
 |        -----------------------------------------------------------------------
 |        TEXT FILES
 |        -----------------------------------------------------------------------
 |            None
 |
 |    ABEND PROCEDURES:
 |         Identify where it failed.
 |         Seek help from seniors, DBA.
 |
 |    MODIFIED LOG:  
 |
 |    DATE        PROGRAMMER     DESCRIPTION
 |    ----------  ------------   ------------------------------------------------
 |    01/01/2007  N. Novik       Initial Release.
 |
 +-------------------------------------------------------------------------------HEADER*/

 %macro delete_from_db2_table
     (
      db_name=UDBSPRP
     ,table_name=
     ,user=
	 ,password=
	 ,where=
     );

	 options nonotes 
	 ;

	 %local table_name_pos db_schema table_name_temp rec_count macro_name;

	 %let macro_name              = %sysfunc(lowcase(&sysmacroname));

     %if &table_name =                                                         %then %do;
         %put MACRO &macro_name table &table_name is invalid;
     %end;
	 %else                                                                           %do;
         %let table_name_pos      = %index(&table_name,.);
         %let table_name_temp     = %substr(&table_name, %eval(&table_name_pos + 1));

         %let db_schema           = %substr(&table_name,1, %eval(&table_name_pos - 1));
	     %if &db_schema  =                                                     %then %do;
             %put MACRO &macro_name schema &db_schema is invalid;
	     %end;
		 %else                                                                       %do;     
	         %let rec_count       = 0;
	  
             %if &db_name = UDBSPRP and &user = and &password = and 
                 &USER_UDBSPRP ne and &PASSWORD_UDBSPRP ne                     %then %do;
	             %let user       = &USER_UDBSPRP;
	             %let password   = &PASSWORD_UDBSPRP;
             %end;

             %if &user ne                                                      %then %do; 
                 %let user       = %str(user=&user);
	         %end;
	  
             %if &password ne                                                  %then %do; 
                 %let password   = %str(password=&password);
	         %end;

	         %if &where ne                                                     %then %do;
	             %let where_cond = %str(where &where);
	         %end;
	         %else                                                                   %do;
	             %let where_cond =;
	         %end;

             libname _schema db2 dsn=&db_name schema=%upcase(&db_schema) &user &password;
	  
	         proc sql
             ;
                 select count(*)

                   into :rec_count

                   from &table_name;

             quit;

	         %put rec_count=&rec_count;
	  
	         %if &rec_count > 0                                                %then %do;                 
 	             %let sqlrc1         = 0;
		  
	             proc sql
                 ;
                     connect to db2 (dsn=&db_name &user &password);

                     execute  
                         ( 
	                      delete from &table_name
			   
			              &where_cond
                         )
                     by db2;

		             %let sqlrc1    = &sqlxrc; 

                     disconnect from db2;
                 quit;

                  %if (&sqlrc1 = 0 or &sqlrc1 = 513) and &sqlrc = 0             %then %do;
	                 %put MACRO &macro_name &table_name all records have been deleted;
					  
					 %reset_sql_err_cd;
                 %end;
	             %else                                                               %do;
	                 %put sqlobs=&sqlobs; 
	                 %put sqlrc=&sqlrc; 
					 %put sqlrc1=&sqlrc1;
	                 %put sqloops=&sqloops; 
	                 %put sqlxrc=&sqlxrc; 
	                 %put sqlxmsg=&sqlxmsg; 
	             %end;
	         %end;
	         %else                                                                   %do;
                 %put MACRO &macro_name &table_name contains no records;         
             %end;
  
             libname _schema clear;
	     %end;
	 %end;

     options notes;

 %mend delete_from_db2_table;
