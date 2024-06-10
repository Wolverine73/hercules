*SASDOC-------------------------------------------------------------------------
| CLAIMS1: Remove duplicate records based on ppt and drug we only want to send them
| letter. We will remove the minimum fill_dt
+-----------------------------------------------------------------------SASDOC*;
/*%let tbl_IN = DATA_PND.&TABLE_PREFIX._2;*/
%MACRO delete_duplicates(TBL_IN=);
proc freq data=&TBL_IN noprint;
tables RECIPIENT_ID/out=FREQCNT MISSPRINT missing sparse ;
RUN;

PROC SQL NOPRINT;
	SELECT MAX(COUNT) INTO :REC_CNT
	FROM FREQCNT		
	; 
QUIT;
%PUT REC_CNT=&REC_CNT;
;

%IF &REC_CNT NE 1 %THEN %DO;


/*PROC CONTENTS DATA = &TBL_IN OUT = CONTENTS_&TBL_IN;RUN;*/

/*	AK/RP - Nov2013 - added mbr_id, subject_id to the key */
PROC SQL NOPRINT;
      CREATE TABLE &TABLE_PREFIX._PENDING_MAXROWS AS 
			SELECT DISTINCT
				   A.RECIPIENT_ID, 
				   A.MBR_ID, 
				   A.SUBJECT_ID,
			       A.DRUG_NDC_ID, 
			       MAX(LAST_FILL_DT) AS LAST_FILL_DT
			FROM   &TBL_IN A             
GROUP BY RECIPIENT_ID, A.MBR_ID, A.SUBJECT_ID, DRUG_NDC_ID
;QUIT;

/*	AK/RP - Nov2013 - added mbr_id, subject_id to the key */
PROC SQL ;
    DELETE FROM &TBL_IN A
            WHERE NOT EXISTS
             (SELECT 1
              FROM &TABLE_PREFIX._PENDING_MAXROWS B
              WHERE A.RECIPIENT_ID      	 = B.RECIPIENT_ID
	  		  AND 	A.MBR_ID 				 = B.MBR_ID   
			  AND   A.SUBJECT_ID       		 = B.SUBJECT_ID        
              AND   A.DRUG_NDC_ID            = B.DRUG_NDC_ID
			  AND   A.LAST_FILL_DT           = B.LAST_FILL_DT
             )
;QUIT;
%set_error_fl;

%END;

%mend delete_duplicates;
