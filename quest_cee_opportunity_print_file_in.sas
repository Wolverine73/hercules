

/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  cee_opportunity_print_in.sas (macro)
|
| LOCATION: /PRG/sastest1/hercules/macros
|
| PURPOSE:  
|
|
+-------------------------------------------------------------------------------
| HISTORY:           
|
+-----------------------------------------------------------------------HEADER*/ 


%PUT  note :now in print file in ;

/*SANJESH : MY CHANGE ENDS HERE***/
%GLOBAL  ceedir;


/*SANJESH ,5TH MAY,DECLARING IN TABLE FOR CREATE BASE FILE MACRO*/
%GLOBAL IN_TABLE ;


%PUT &IN_TABLE ;
/*SANJESH ,CHANGES ENDS HERE******************************************/

%LET ceedir=%str(herc&sysmode/data/hercules/gen_utilities/sas/cee/);


 
