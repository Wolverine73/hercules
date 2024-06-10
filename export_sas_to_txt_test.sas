/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Monday, August 19, 2002      TIME: 05:36:35 PM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */
 OPTIONS MLOGIC MPRINT SYMBOLGEN SOURCE2;
* OPTIONS NOMLOGIC NOMPRINT NOSYMBOLGEN NOSOURCE2;

 %LET DEBUG_FLAG=Y;

* %export_sas_to_txt(Tbl_name_in=CLAIMSA.LKP_CSTM_GRP,
				   Tbl_name_out="/DATA/sastest1/adhoc/test/test.dat",
				   File_type_out='DEL',
				   obs=35,
					Col_in_fst_row=N);
 LIBNAME DATA '/DATA/sasprod1/retail_to_mail';


FILENAME listpt '/DATA/sasadhoc1/final_list_pnt.dat' ;


%export_sas_to_txt(tbl_name_in=data.final_list_pnt_tmp,
                   tbl_name_out=listpt,
                   File_type_out="ASC", L_FILE="/DATA/sasadhoc1/final_list_pnt.lat");

