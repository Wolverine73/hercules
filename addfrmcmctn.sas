/*HEADER------------------------------------------------------------------------
|
| PROGRAM:     ADDFRMCMCTN.sas (macro)
|
| LOCATION:    /PRG/sastest1/hercules/87/macros/ADDFRMCMCTN
|
| PURPOSE:     Run SQL query to get drug/pod history. 
|              Checks within history a compare of current row to previous row
|              if any column changed, then compares current row to previous previous
|              row for a change in IN_FORMULARY_IN_CD or P_T_PREFERRED_CD(only for formulary
|              id 61) if so then output the current row of data as a formulary change. 
|
| INPUT:       &CLAIMSA..TFORMULARY
|              &CLAIMSA..TPOD_DRUG_HISTORY
|              &CLAIMSA..TCELL_POD
|              &CLAIMSA..TCELL
|              &CLAIMSA..TPOD
|              &CLAIMSA..TFORMULARY_POD
|              &CLAIMSA..TFORMULARY_CELL 
|              &CLAIMSA..TDRUG1 
|              &TBLIN 
|
| OUTPUT:      &TBLIN (SAS or DB2 table with appended target drugs)
|               
|
| CALLEDMODS:  %DROP_db2_TABLE
|
| Sample calls:
|
|%addfrmcmctn  (TBLIN=&DB2_TMP..&TABLE_PREFIX._NDC_CHG,
|               PRGNM=FORMULARY_PURGE,
|               HIST_EXP_DT=%str(>= &Y_Z_DT ),
|               FORMULARY_ID=&FRM_ID);
|
|
|%ADDFRMCMCTN(TBLIN=F2K_DRUG_REPORT_&FORMULARY_ID,
|                   PRGNM=F2K_DRUG_REPORT,
|                   HIST_EXP_DT=%str(>= &Y_Z_DT ),
|                   FORMULARY_ID=&FORMULARY_ID);
|
|
+--------------------------------------------------------------------------------
| HISTORY:  03APR2007 - N.Williams - Hercules Version  1.5
|                       Original
|           03DEC2007 - N.Williams - Hercules Version  1.5.01
|                                  Business user felt future dated data rows where 
|                                  being picked up early. Display additional fields 
|                                  to prove data for F2K report is correct. Also add
|                                  logic to ensure duplicate removal by drug_ndc_id 
|                                  for f2k since this field was added.
|
|           26JAN2009 - N.Williams - Hercules Version  2.1.1
|                                  1. Add fyid# 78 forumlary changes business rules 
|                                  to the code. 
|                                  2. Removed checks for formulary id 61 as now
|                                     for all formulary id will count ptv code.
|                                  3. Adjust date logic for identified formulary
|                                     changes, at the very end will check that the
|                                     identified change row effective date is less
|                                     than or equal to frm chg date.
+------------------------------------------------------------------------HEADER*/


%MACRO addfrmcmctn(TBLIN=,
                   PRGNM=,
                   FORMULARY_ID=,
		           HIST_EXP_DT=,
                   EXTRA_CRITERIA=);

%global PROGRAM_NAME;
%LET PROGRAM_NAME=ADDFRMCMCTN;


*SASDOC-------------------------------------------------------------------------
| Find the begin/change formulary dates that the mailing/report will target.
| This is determined by querying the TINITIATIVE_DATE table for records
| containing formularies/initiatives with dates for each of the following:
| Formulary Purge:
|   NON-FORMULARY DRUG DATE        (DATE_TYPE_CD = 4) --> X_N_DT
|   IN-FORMULARY BEGIN CHECK DATE  (DATE_TYPE_CD = 7) --> Y_Z_DT
| F2K Drug Report:
|   Compute the date as 1st of the Current Month
+-----------------------------------------------------------------------SASDOC*;
%if &PRGNM EQ FORMULARY_PURGE %THEN %DO;  
PROC SQL ;
  SELECT 
		 PUT(B.INITIATIVE_DT, 9.),
         PUT(C.INITIATIVE_DT, 9.)
  INTO   :ADDFRM_BEG_DT, :ADDFRM_CHG_DT
  FROM   &HERCULES..TINIT_FORMULARY A,
         &HERCULES..TINITIATIVE_DATE B,
         &HERCULES..TINITIATIVE_DATE C
  WHERE  A.INITIATIVE_ID = &INITIATIVE_ID
    AND  A.INITIATIVE_ID = B.INITIATIVE_ID
    AND  A.INITIATIVE_ID = C.INITIATIVE_ID
    AND  B.DATE_TYPE_CD = 4      /* y_z_dt - last formulary review */
    AND  C.DATE_TYPE_CD = 7      /* x_n_dt - change effective date */
    AND  A.FRML_USAGE_CD = 1;
QUIT;
%end;

%if &PRGNM EQ F2K_DRUG_REPORT %THEN %DO;
DATA _NULL_;
        LENGTH RUN_DT 8 view_dt 8;
                run_DT=today();
        *       run_dt='15JUL2003'd;   /* For adhoc runs only*/

        lst_dt=INTNX('MONTH',RUN_DT,0) -1;
        view_dt = lst_dt + 1;	

        CALL SYMPUT('ADDFRM_BEG_DT', PUT(view_dt, 9.));
		CALL SYMPUT('ADDFRM_CHG_DT', PUT(view_dt, 9.));

RUN;
%end;
*SASDOC-----------------------------------------------------------------------
|Pull drug history specified by HIST_EXP_DT PARM for data HISTORY comparsion. 
+-----------------------------------------------------------------------SASDOC*;
PROC SQL ;
 CONNECT TO DB2 AS DB2(DSN=&UDBSPRP); 
 CREATE TABLE F2KTMPTBL AS
 select * from connection to db2
 (
    SELECT 
	        POD_DRUG_HIS.*,
            CHAR(CHAR(POD_DRUG_HIS.POD_ID) || CHAR(POD_DRUG_HIS.DRUG_NDC_ID)) AS KEYVAL,
           %if &PRGNM EQ FORMULARY_PURGE %THEN %DO;         
            POD.POD_NM,
            CELL.CELL_NM,
            POD.GPI_THERA_CLS_CD AS GPI,
            DRUG.DRUG_ABBR_PROD_NM,
            DRUG.DRUG_ABBR_DSG_NM,
            DRUG.DRUG_ABBR_STRG_NM,
            DRUG.GENERIC_AVAIL_IN
           %end; 

           %else

           %if &PRGNM EQ F2K_DRUG_REPORT %THEN %DO;         
           RTRIM(DRUG.DRUG_ABBR_PROD_NM) || ' ' ||
           RTRIM(DRUG.DRUG_ABBR_STRG_NM) AS DRUG_PRODUCT,
           CASE POD_DRUG_HIS.IN_FORMULARY_IN_CD
               WHEN 3 THEN 'Y'
               WHEN 4 THEN 'Z'
               WHEN 5 THEN 'X'
               WHEN 6 THEN 'N'
               ELSE '0'
           END AS FI,
		   %IF &FORMULARY_ID EQ 61                   
		    OR &FORMULARY_ID EQ 1       %THEN %DO ;  
		       POD_DRUG_HIS.P_T_PREFERRED_CD AS PTV, 
		   %END;                                     
           CASE DRUG.GENERIC_AVAIL_IN
               WHEN 1 THEN 'Y'
               ELSE 'N'
           END AS GA,
           CASE POD_DRUG_HIS.MOR_SMT_TIP_CD
               WHEN 1 THEN 'TY'
               WHEN 2 THEN 'TX'
               WHEN 3 THEN 'T2'
               WHEN 4 THEN 'TP'
               ELSE 'N/A'
           END AS MTIP,
           CASE POD_DRUG_HIS.POS_SMT_TIP_CD
                WHEN 1 THEN 'TY'
                WHEN 2 THEN 'TX'
                WHEN 3 THEN 'T2'
                WHEN 4 THEN 'TP'
                ELSE 'N/A'
           END AS RTIP,
           CHAR(DRUG.DRUG_PRODUCT_ID) AS NDC_9,
           CHAR(GPI_GROUP || GPI_CLASS || GPI_SUBCLASS ||
           GPI_NAME || GPI_NAME_EXTENSION || GPI_FORM || GPI_STRENGTH) as GPI14,
           CELL.CELL_NM,
           POD.POD_NM,                                         /* 03DEC2007 - N.Williams (add comma) */ 
	   	   POD_DRUG_HIS.DRUG_NDC_ID,                           /* 03DEC2007 - N.Williams */
           CHAR(POD_DRUG_HIS.EFFECTIVE_DT)  AS EFFECTIVE_DT ,  /* 03DEC2007 - N.Williams */
	       CHAR(POD_DRUG_HIS.EXPIRATION_DT) AS EXPIRATION_DT,  /* 03DEC2007 - N.Williams */
	       POD_DRUG_HIS.POD_ID                                 /* 03DEC2007 - N.Williams */           
           %end; 


    FROM    CLAIMSA.TFORMULARY FORM,
            CLAIMSA.TPOD_DRUG_HISTORY POD_DRUG_HIS,
            CLAIMSA.TCELL_POD CELL_POD,
            CLAIMSA.TCELL CELL,
            CLAIMSA.TPOD POD,
            CLAIMSA.TFORMULARY_POD FORM_POD,
            CLAIMSA.TFORMULARY_CELL FORM_CELL,
            CLAIMSA.TDRUG1 DRUG


    WHERE FORM.FORMULARY_ID           IN (&FORMULARY_ID)
        AND FORM.FORMULARY_ID          = FORM_POD.FORMULARY_ID
        AND FORM_POD.POD_ID            = POD_DRUG_HIS.POD_ID
        AND FORM_POD.POD_ID            = POD.POD_ID
        AND FORM.FORMULARY_ID          = FORM_CELL.FORMULARY_ID
        AND FORM_CELL.CELL_ID          = CELL.CELL_ID
        AND POD.POD_ID                 = CELL_POD.POD_ID
        AND CELL_POD.CELL_ID           = CELL.CELL_ID
        AND POD_DRUG_HIS.DRUG_NDC_ID   = DRUG.DRUG_NDC_ID
        AND POD_DRUG_HIS.NHU_TYPE_CD   = DRUG.NHU_TYPE_CD
        AND POD_DRUG_HIS.EXPIRATION_DT   &HIST_EXP_DT
		&EXTRA_CRITERIA
        );

DISCONNECT FROM DB2;
%PUT &SQLXRC &SQLXMSG;
QUIT;

%set_error_fl;

*SASDOC-----------------------------------------------------------------------
| Create key for sas dataset for durg history
+-----------------------------------------------------------------------SASDOC*;
proc sql ;
create table F2KDRUGHIST as
select COMPRESS(KEYVAL) AS KEY_VL,
       A.POD_ID,           
       A.DRUG_NDC_ID,      
       A.NHU_TYPE_CD ,     
       A.EFFECTIVE_DT FORMAT=9.,    
       A.EXPIRATION_DT FORMAT=9.,
       A.IN_FORMULARY_IN_CD,
       A.SUB_POD_REASON_CD, 
       A.P_T_PREFERRED_CD, 
       A.GRACE_PERIOD_IN, 
       A.DISPLAY_POD_MSG_IN,
       A.MOR_SMT_TIP_CD, 
       A.POS_SMT_TIP_CD,
       A.HSC_TS,
       A.HSU_TS,
       A.FRML_DRG_CMN_NM,
       A.MIDRANGE_LOAD_TS
       %if &PRGNM EQ FORMULARY_PURGE %THEN %DO;         
            ,A.POD_NM,
            A.CELL_NM,
            A.GPI,
            A.DRUG_ABBR_PROD_NM,
            A.DRUG_ABBR_DSG_NM,
            A.DRUG_ABBR_STRG_NM,
            A.GENERIC_AVAIL_IN
      %end; 

      %else

      %if &PRGNM EQ F2K_DRUG_REPORT %THEN %DO;         
           ,A.DRUG_PRODUCT,
            A.FI,
		   %IF &FORMULARY_ID EQ 61                   
		    OR &FORMULARY_ID EQ 1       %THEN %DO ;  
		       A.PTV, 
		   %END;                                     
           A.GA,
           A.MTIP,
           A.RTIP,
           A.NDC_9,
		   A.GPI14,
           A.CELL_NM,
           A.POD_NM,
	   	   A.DRUG_NDC_ID,    /* 03DEC2007 - N.Williams */
           A.EFFECTIVE_DT ,  /* 03DEC2007 - N.Williams */
	       A.EXPIRATION_DT,  /* 03DEC2007 - N.Williams */
	       A.POD_ID          /* 03DEC2007 - N.Williams */        
      %end; 
 
from F2KTMPTBL A
;

QUIT;

*SASDOC-----------------------------------------------------------------------
| Get me the key_vl count.
+-----------------------------------------------------------------------SASDOC*;
proc sql ;
create table DUMMYA as
select A.*,
       count(A.KEY_VL) AS KEY_VL_CNT
from F2KDRUGHIST A
group by KEY_VL
;
QUIT;

*SASDOC-----------------------------------------------------------------------
|Transpose dataset dataset observations to variables for history comparsion.
+-----------------------------------------------------------------------SASDOC*;
PROC TRANSPOSE DATA = DUMMYA  OUT = DUMMYB  PREFIX = FRMSTSCD ;
 BY KEY_VL ;
 VAR IN_FORMULARY_IN_CD ;
RUN  ;

PROC TRANSPOSE DATA = DUMMYA  OUT = DUMMYC  PREFIX = PTVCD ;
 BY KEY_VL ;
 VAR P_T_PREFERRED_CD;
RUN  ;

*SASDOC-----------------------------------------------------------------------
|sas merge 
+-----------------------------------------------------------------------SASDOC*;
DATA 
   DUMMYD (drop= _NAME_  _LABEL_ ) 
   ;

   MERGE 
       DUMMYC
       DUMMYB
	   ;
   BY 
     KEY_VL
     ;
RUN ;

*SASDOC-----------------------------------------------------------------------
|Produce for me the caremark standard high date value
+-----------------------------------------------------------------------SASDOC*;
DATA _NULL_;                      
    CALL SYMPUT('HIGH_DT', PUT('31DEC9999'D, 9.) );
RUN;

*SASDOC-----------------------------------------------------------------------
| Get me the key_vl count dataset with the transpose dataset 
+-----------------------------------------------------------------------SASDOC*;
proc sql ;
create table FRMDRGHIST as
select distinct
       A.*,
       B.*
from DUMMYA   A,
     DUMMYD   B
WHERE A.KEY_VL        = B.KEY_VL
AND   A.EXPIRATION_DT = &HIGH_DT
AND   A.KEY_VL_CNT    > 1
;
QUIT;

*SASDOC-----------------------------------------------------------------------
| Sort sas dataset for durg history
+-----------------------------------------------------------------------SASDOC*;
PROC SORT DATA=FRMDRGHIST; BY KEY_VL ; RUN;


*SASDOC-----------------------------------------------------------------------
| Create a output SAS dataset that contains the data that changed in there
| drug history within date range that normal logic missed. 
| 1st comparsion check:
| Here we will take current drug history row compare it to the prior row and look
| for any columns that changed. If change flag the current pass onto next comparsion.
| 2nd comparsion check: 
| Here we will take current drug history row compare it to the prior prior row and look
| for column changes on IN_FORMULARY_IN_CD(aka Formulary Status code) OR 
| P_T_PREFERRED_CD(aka PTV_CD) within specified date range. 
| 26JAN2009 - N.Williams - Adjust formulary logic per requirements.
+-----------------------------------------------------------------------SASDOC*;
DATA
   F2KDRGOUTA
   ;
   SET
      FRMDRGHIST 
      ;
   BY 
      KEY_VL
      ;

      /* formulary changes logic */
	  ARRAY AFRMS(*) FRMSTSCD1-FRMSTSCD99 ;
      
	  do i=1 to dim(AFRMS) ;

        IF AFRMS{i}=. THEN GOTO EXITLP;

	    IF IN_FORMULARY_IN_CD NE AFRMS{i} THEN DO ;
 
		   IF ((IN_FORMULARY_IN_CD IN (5,6) AND AFRMS{i}IN (3,4))
		   OR (IN_FORMULARY_IN_CD =5 AND AFRMS{i}=6))
           THEN DO;
		     OLD_FRMSTSCD=AFRMS{i};
             OUTPUT ;
		     GOTO EXITLP;
		   END;
		END;
      end; 

     EXITLP:
	
RUN;

DATA
   F2KDRGOUTB
   ;
   SET
      FRMDRGHIST 
      ;
   BY 
      KEY_VL
      ;


	  ARRAY AFRMS(*) FRMSTSCD1-FRMSTSCD99 ;
      
	  /* ptv changes logic */

      if ( (&PRGNM EQ FORMULARY_PURGE AND (&FORMULARY_ID EQ 61 OR &FORMULARY_ID EQ 78))  /*26JAN2009 - N.Williams*/
           OR
           (&PRGNM EQ F2K_DRUG_REPORT AND (&FORMULARY_ID EQ 1 OR &FORMULARY_ID EQ 61))
         )  then do;

	   ARRAY APTVS(*) PTVCD1-PTVCD99 ;

	   do a=1 to dim(APTVS) ;

	     IF (APTVS{a}=. or AFRMS{a}=.) THEN GOTO EXITLP;   

		 IF ( 
		      ( 
                ( IN_FORMULARY_IN_CD IN (3,4) AND P_T_PREFERRED_CD=7 ) /** NEW STATUS **/
			    OR
			    (IN_FORMULARY_IN_CD IN (5,6) AND P_T_PREFERRED_CD IN (5,6,7)) /** NEW STATUS **/
               ) 

			  AND
			  ( AFRMS{a} IN (3,4) AND APTVS(a) IN (5,6) ) /** OLD STATUS **/
            ) THEN DO;

			 OLD_PTVCD=APTVS{a};
			 OLD_FRMSTSCD=AFRMS{a};
             OUTPUT ;
		     GOTO EXITLP;
		 END;		   

      end;

     end;

     EXITLP:
	
RUN;


PROC SORT DATA=F2KDRGOUTA ; BY KEY_VL ; RUN;
PROC SORT DATA=F2KDRGOUTB ; BY KEY_VL ; RUN;

*SASDOC-------------------------------------------------------------------------
| Merge formulary status changes & PTV code changes into one sas dataset.
| 26JAN2009 - N.Williams - Change from SET statement to a Merge By.
+-----------------------------------------------------------------------SASDOC*;
DATA 
   F2KDRGOUT
   ;

   MERGE 
       F2KDRGOUTA
       F2KDRGOUTB
	   ;
   BY 
     KEY_VL
     ;

RUN ;

*SASDOC-------------------------------------------------------------------------
| Sort . 
| 26JAN2009 - N.Williams - Requirement to check date values of effective date
| to ensure that identified formulary change row is within the change date range.
+-----------------------------------------------------------------------SASDOC*;
PROC SORT DATA=F2KDRGOUT ; BY KEY_VL ;  WHERE EFFECTIVE_DT BETWEEN &ADDFRM_BEG_DT AND &ADDFRM_CHG_DT;
RUN;


*SASDOC-------------------------------------------------------------------------
| Output data to approriate destination based on &PRGNM for formulary_purge
| send output to DB2 Temporary table. Else f2k_drug_report output to SAS dataset.
+-----------------------------------------------------------------------SASDOC*;
%NOBS(F2KDRGOUT);

%IF &NOBS NE 0 %THEN %DO;
  %if &PRGNM EQ FORMULARY_PURGE %THEN %DO;

      %*SASDOC-----------------------------------------------------------------------
      | Assign name of DB2 TEMP TABLE to macro variable.
      +----------------------------------------------------------------------SASDOC*;
      %local DB2_TMP_TBL;
      %let DB2_TMP_TBL=&DB2_TMP..&TABLE_PREFIX._NDC_ADDCHG;

      %drop_db2_table(TBL_NAME=&DB2_TMP_TBL); 
       
       *SASDOC-------------------------------------------------------------------------
       | Get table name of &tblin that was passed into this macro.
       +-----------------------------------------------------------------------SASDOC*;
	    %local tblnmi;
	    %let tblnmi=&user..&TABLE_PREFIX._ADDFRMDRGS;
      
      *SASDOC-------------------------------------------------------------------------
      | create a db2 table based on definition only
      +-----------------------------------------------------------------------SASDOC*;
	   %drop_db2_table(TBL_NAME=&tblnmi);  

        PROC SQL ;
          CONNECT TO DB2 (DSN=&UDBSPRP);
          EXECUTE(
              CREATE TABLE &tblnmi AS
              (SELECT * 
               FROM &TBLIN )
               DEFINITION ONLY NOT LOGGED INITIALLY) BY DB2;
          DISCONNECT FROM DB2; 
        QUIT;
	   
      *SASDOC-------------------------------------------------------------------------
      | PROC SQL - format data for comparision to db2 temp table so changes can be 
	  | output in correct format for ease of insertion. 
      +-----------------------------------------------------------------------SASDOC*;

        PROC SQL ;
        CREATE table ADDFRMDRGS as
        SELECT       T1.DRUG_NDC_ID,
                     T1.NHU_TYPE_CD,
                     T1.POD_ID,
                     T1.POD_NM,
                     T1.CELL_NM,
                     T1.DRUG_ABBR_PROD_NM,
                     T1.DRUG_ABBR_DSG_NM,
                     T1.DRUG_ABBR_STRG_NM,
                     T1.GENERIC_AVAIL_IN,
                    CASE SUBSTR(T1.GPI, 1,2)
                          WHEN '00' THEN '  '
                          ELSE SUBSTR(T1.GPI, 1, 2)
                    END,
                    CASE SUBSTR(T1.GPI, 3,2)
                          WHEN '00' THEN '  '
                          ELSE SUBSTR(T1.GPI, 3, 2)
                    END,
                    CASE SUBSTR(T1.GPI, 5,2)
                          WHEN '00' THEN '  '
                          ELSE SUBSTR(T1.GPI, 5, 2)
                    END,
                    CASE SUBSTR(T1.GPI, 7,2)
                          WHEN '00' THEN '  '
                          ELSE SUBSTR(T1.GPI, 7, 2)
                    END,
                    CASE SUBSTR(T1.GPI, 9,2)
                          WHEN '00' THEN '  '
                          ELSE SUBSTR(T1.GPI, 5, 2)
                    END,
                    CASE SUBSTR(T1.GPI, 11,2)
                          WHEN '00' THEN '  '
                          ELSE SUBSTR(T1.GPI, 11, 2)
                    END,
                    CASE SUBSTR(T1.GPI, 13,2)
                          WHEN '00' THEN '  '
                          ELSE SUBSTR(T1.GPI, 13, 2)
                    END,
                    CASE T1.OLD_FRMSTSCD
                      WHEN 3 THEN 'Y'
                      WHEN 4 THEN 'Z'
                      WHEN 5 THEN 'X'
                      ELSE 'N'
                    END AS ORG_FRM_STS,
                    CASE T1.IN_FORMULARY_IN_CD
                      WHEN 3 THEN 'Y'
                      WHEN 4 THEN 'Z'
                      WHEN 5 THEN 'X'
                      ELSE 'N'
                    END AS NEW_FRM_STS,					
					T1.OLD_PTVCD AS ORG_PTV_CD,
                    T1.P_T_PREFERRED_CD   AS NEW_PTV_CD
					
              FROM   F2KDRGOUT T1
		  ;
        QUIT;
 
	    PROC SQL ;
          INSERT INTO &tblnmi (bulkload=yes)
          SELECT * 
            FROM ADDFRMDRGS ;
        QUIT;
		%PUT &SQLXRC &SQLXMSG;

      *SASDOC-------------------------------------------------------------------------
      | DB2 table comparsion here we want to see if formulary changes within the history
      | that where not picked up by normal formulary logic should be output into a 
      |	table so it can be processed for this mailing as a formulary change. 
      +-----------------------------------------------------------------------SASDOC*;
		*SASDOC-------------------------------------------------------------------------
		| Remove duplicate rows: Delete when a drug_ndc_id has already been created 
		+-----------------------------------------------------------------------SASDOC*;

		PROC SQL ;
		  CONNECT TO DB2 AS DB2(DSN=&UDBSPRP);
		    EXECUTE(DELETE FROM &tblnmi A                     
		            WHERE EXISTS 
		             (SELECT 1
		              FROM &TBLIN B
		              WHERE A.DRUG_NDC_ID = B.DRUG_NDC_ID
		              AND   A.POD_ID      = B.POD_ID)) BY DB2;
		  %reset_sql_err_cd;
		QUIT;

   %NOBS(&tblnmi );

    %IF &NOBS NE 0 %THEN %DO;
       %SET_ERROR_FL;
   
       %RUNSTATS(TBL_NAME=&tblnmi);
        PROC SQL ;
        INSERT INTO &TBLIN (bulkload=yes)
        SELECT * FROM &tblnmi;
        QUIT;
		%PUT &SQLXRC &SQLXMSG;
    %END;	 

  %END;

  %ELSE

   %if &PRGNM EQ F2K_DRUG_REPORT %THEN %DO;
    PROC SORT DATA=F2KDRGOUT OUT=F2KADD
    (KEEP = DRUG_PRODUCT 
            FI 
           %IF &FORMULARY_ID EQ 61
		    OR &FORMULARY_ID EQ 1       %THEN %DO ;  
			 PTV
		   %END;
		   GA
		   MTIP
		   RTIP
		   NDC_9
		   GPI14
		   CELL_NM
		   POD_NM
		   POD_ID            /* 03DEC2007 - N.Williams */
		   DRUG_NDC_ID       /* 03DEC2007 - N.Williams */
		   EFFECTIVE_DT      /* 03DEC2007 - N.Williams */
		   EXPIRATION_DT     /* 03DEC2007 - N.Williams */
           
	 )
     ;                
     BY DRUG_PRODUCT
     ; 
     RUN
     ;
		*SASDOC-------------------------------------------------------------------------
		| 03DEC2007 - N.Williams 
		| Remove duplicate rows: Delete when a drug_ndc_id has already been created 
		+-----------------------------------------------------------------------SASDOC*;

		PROC SQL ;
		  DELETE FROM F2KADD A                     
          WHERE EXISTS 
          (SELECT 1
           FROM &TBLIN B
           WHERE A.DRUG_NDC_ID = B.DRUG_NDC_ID
           AND   A.POD_ID      = B.POD_ID)
		  ;
		QUIT;

	   %NOBS(F2KADD);
*SASDOC---------------------------------------------------------------*
| Append data to original SAS dataset for f2k_drug_report
*--------------------------------------------------------------------*;
   %IF &NOBS NE 0 %THEN %DO; /* 03DEC2007 - N.Williams */
	   PROC APPEND
	   BASE=&TBLIN
	   DATA=F2KADD
	   FORCE
	   ;
	  RUN;
   %END;
 %END; /* 03DEC2007 - N.Williams */
%else
  %PUT NOTE: SAS DATASET F2KDRGOUT is empty, no additional formulary changes needed to be created.;
%END;    

%MEND addfrmcmctn;

