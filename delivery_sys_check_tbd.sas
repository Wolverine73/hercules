/*HEADER---------------------------------------------------------------------------------------------------------
|MACRO: DELIVERY_SYS_CHECK_TBD.SAS
|
|PURPOSE: RESOLVE EXCLUSION DELIVERY SYSTEM FOR RECAP AND RXCLAIM FOR TARGET BY DRUG (106) AND 
|         DSA/ NCQA (105)
|LOGIC:   DETERMINE IF ANY OF THE DELIVERY SYSTEMS SHOULD BE EXCLUDED FROM THE
|					INITIATIVE.  IF SO, FORM A STRING THAT WILL BE INSERTED INTO THE SQL THAT
|					QUERIES CLAIMS.
|					PROCESS WILL FIND OUT THE DELIVERY SYSTEM TO BE EXCLUDE ON RX OR RE 
|					PLATFORMS AND ASSIGN IT INTO MACRO VARIABLES
|					( DS_STRING_RX_RE(RX,RE),MAIL_DELVRY_CD(RX,RE)
|								  RETAIL_DELVRY_CD(RX,RE),EDW_DELIVERY_SYSTEM(RX,RE))
|         MAIL ORDER = CVS/CAREMARK MAIL ORDER PHARMACIES
|						
|INPUT: DWCORP.T_IBEN_ECOE_MOC_PHMCY_CD					
|PARAMETERS:            GLOBAL MACRO VARIABLES: INITIATIVE_ID, PHASE_SEQ_NB.
|
|+-----------------------------------------------------------------------------------------------------------------
| HISTORY: 
| FIRST RELEASE: JUNE 2012 - E BUKOWSKI(SLIOUNKOVA) - CREATED - TARGET BY DRUG/DSA AUTOMATION
|
| DEC 2013 BSR - Voided Claims and other fixes - Delivery System check
+-----------------------------------------------------------------------------------------------------------HEADER*/
		LIBNAME DWCORP ORACLE SCHEMA=DWCORP PATH=&GOLD;

%MACRO DELIVERY_SYS_CHECK_TBD(INITIATIVE_ID,HERCULES);

	%GLOBAL DS_STRING DS_STRING_RX_RE RETAIL_DELVRY_CD MAIL_DELVRY_CD OMIT_DS_STR EDW_DELIVERY_SYSTEM OMIT_DS
		CREATE_DELIVERY_SYSTEM_CD_RX CREATE_DELIVERY_SYSTEM_CD_RE DS_STRING_RE DS_STRING_RX DS_STRING_SAS;


	PROC SQL NOPRINT;
	  SELECT COUNT(DELIVERY_SYSTEM_CD) INTO :OMIT_DS
	  FROM &HERCULES..TDELIVERY_SYS_EXCL
	  WHERE INITIATIVE_ID = &INITIATIVE_ID;
	QUIT;

		%PUT NOTE:	OMIT_DS=&OMIT_DS;



	PROC SQL NOPRINT;
	  SELECT "'" || SUBSTR(MOC_PHMCY_NPI_ID,1,10) ||"'" INTO :CMX_MAIL_NPI SEPARATED BY ','
	  FROM DWCORP.T_IBEN_ECOE_MOC_PHMCY_CD;
	QUIT;




	%IF &OMIT_DS > 0 %THEN %DO;

		PROC SQL NOPRINT;
		  SELECT DELIVERY_SYSTEM_CD INTO :OMIT_DS_STR SEPARATED BY ','
		  FROM &HERCULES..TDELIVERY_SYS_EXCL
		  WHERE INITIATIVE_ID = &INITIATIVE_ID
		  ORDER BY DELIVERY_SYSTEM_CD;
		QUIT;

		%LET DS_STRING=%STR( AND DELIVERY_SYSTEM_CD NOT IN (&OMIT_DS_STR));
		%IF (&RX_ADJ EQ 1 OR &RE_ADJ EQ 1) %THEN %DO;


			    %IF &OMIT_DS_STR EQ 1 %THEN %DO;  /******* target mail and retail  */
					%LET DS_STRING_RE=%STR();
					%LET DS_STRING_RX=%STR();
					%LET DS_STRING_SAS=%STR();
			    %END;
			    %IF &OMIT_DS_STR EQ 2 %THEN %DO;   /******* target retail */
					%LET DS_STRING_RE=%STR(AND (SUBSTR(PHMCY.CURR_NPI_ID,1,10) NOT IN (&CMX_MAIL_NPI.)));
					%LET DS_STRING_RX=%STR(AND (SUBSTR(PHMCY.CURR_NPI_ID,1,10) NOT IN (&CMX_MAIL_NPI.)));
					%LET DS_STRING_SAS=%STR(IF DELIVERY_SYSTEM = 'RETAIL' THEN OUTPUT;);
			    %END;
			    %IF &OMIT_DS_STR EQ 3 %THEN %DO;   /******* target mail */
					%LET DS_STRING_RE=%STR(AND (SUBSTR(PHMCY.CURR_NPI_ID,1,10) IN (&CMX_MAIL_NPI.)));
					%LET DS_STRING_RX=%STR(AND (SUBSTR(PHMCY.CURR_NPI_ID,1,10) IN (&CMX_MAIL_NPI.)));
					%LET DS_STRING_SAS=%STR(IF DELIVERY_SYSTEM = 'MAIL' THEN OUTPUT;);
			    %END;
			    %IF &OMIT_DS_STR EQ 1,3 %THEN %DO; /******* target mail */
					%LET DS_STRING_RE=%STR(AND (SUBSTR(PHMCY.CURR_NPI_ID,1,10) IN (&CMX_MAIL_NPI.)));
					%LET DS_STRING_RX=%STR(AND (SUBSTR(PHMCY.CURR_NPI_ID,1,10) IN (&CMX_MAIL_NPI.)));
					%LET DS_STRING_SAS=%STR(IF DELIVERY_SYSTEM = 'MAIL' THEN OUTPUT;);
			    %END;
			    %IF &OMIT_DS_STR EQ 1,2 %THEN %DO; /******* target retail */
					%LET DS_STRING_RE=%STR(AND (SUBSTR(PHMCY.CURR_NPI_ID,1,10) NOT IN (&CMX_MAIL_NPI.)));
					%LET DS_STRING_RX=%STR(AND (SUBSTR(PHMCY.CURR_NPI_ID,1,10) NOT IN (&CMX_MAIL_NPI.)));
					%LET DS_STRING_SAS=%STR(IF DELIVERY_SYSTEM = 'RETAIL' THEN OUTPUT;);
			    %END;
			    %IF &OMIT_DS_STR EQ 2,3 %THEN %DO; /******* target paper-no results for RxClaim and RECAP */
					%LET DS_STRING_RE=%STR(AND (1>1));
					%LET DS_STRING_RX=%STR(AND (1>1));
					%LET DS_STRING_SAS=%STR();
			    %END;

		 %END; /* END OF RX_ADJ EQ 1 OR RE_ADJ EQ 1*/

	%END;  /* END OF OMIT_DS GT 0 */
	%ELSE %DO;
			%LET  DS_STRING=%STR();
			%LET  DS_STRING_RX_RE=%STR();
			%LET  DS_STRING_RE=%STR();
			%LET  DS_STRING_RX=%STR();
			%LET DS_STRING_SAS=%STR();
	%END;

	
	%IF (&RX_ADJ EQ 1 OR &RE_ADJ EQ 1) %THEN %DO;
	
	   %LET RETAIL_DELVRY_CD = %STR(AND SUBSTR(PHMCY.CURR_NPI_ID,1,10) NOT IN (&CMX_MAIL_NPI.));
	   %LET MAIL_DELVRY_CD = %STR(AND SUBSTR(PHMCY.CURR_NPI_ID,1,10) IN (&CMX_MAIL_NPI.));
	   %LET EDW_DELIVERY_SYSTEM = %STR( CASE WHEN SUBSTR(PHMCY.CURR_NPI_ID,1,10) NOT IN (&CMX_MAIL_NPI.) 
					      THEN 'RETAIL'
					      WHEN SUBSTR(PHMCY.CURR_NPI_ID,1,10) IN (&CMX_MAIL_NPI.)
					      THEN 'MAIL'
/* DEC 2013 BSR - Voided Claims and other fixes - Delivery System check */
					      ELSE 'RETAIL'
					 END AS DELIVERY_SYSTEM );
					 
	   %LET CREATE_DELIVERY_SYSTEM_CD_RE = %STR(CASE WHEN SUBSTR(PHMCY.CURR_NPI_ID,1,10) NOT IN (&CMX_MAIL_NPI.) 
					      THEN 'RETAIL'
					      WHEN SUBSTR(PHMCY.CURR_NPI_ID,1,10) IN (&CMX_MAIL_NPI.)
					      THEN 'MAIL'
/* DEC 2013 BSR - Voided Claims and other fixes - Delivery System check */
					      ELSE 'RETAIL'
					 END AS DELIVERY_SYSTEM   );
	   %LET CREATE_DELIVERY_SYSTEM_CD_RX = %STR(CASE WHEN SUBSTR(PHMCY.CURR_NPI_ID,1,10) NOT IN (&CMX_MAIL_NPI.) 
					      THEN 'RETAIL'
					      WHEN SUBSTR(PHMCY.CURR_NPI_ID,1,10) IN (&CMX_MAIL_NPI.)
					      THEN 'MAIL'
/* DEC 2013 BSR - Voided Claims and other fixes - Delivery System check */
					      ELSE 'RETAIL'
					 END AS DELIVERY_SYSTEM   );
	%END;

	%PUT *********************************************************************************;
	%PUT NOTE: OMIT_DS_STR = &OMIT_DS_STR;
	%PUT NOTE: DS_STRING=&DS_STRING;
	%PUT NOTE: DS_STRING_RX_RE = &DS_STRING_RX_RE;
	%PUT NOTE: RETAIL_DELVRY_CD = &MAIL_DELVRY_CD;
	%PUT NOTE: MAIL_DELVRY_CD = &MAIL_DELVRY_CD;
	%PUT NOTE: CREATE_DELIVERY_SYSTEM_CD_RX = &CREATE_DELIVERY_SYSTEM_CD_RX;
	%PUT NOTE: CREATE_DELIVERY_SYSTEM_CD_RE = &CREATE_DELIVERY_SYSTEM_CD_RE;
	%PUT NOTE: DS_STRING_RX = &DS_STRING_RX;
	%PUT NOTE: DS_STRING_RE = &DS_STRING_RE;
	%PUT NOTE: DS_STRING_SAS = &DS_STRING_SAS;
	%PUT *********************************************************************************;

%MEND DELIVERY_SYS_CHECK_TBD;
%DELIVERY_SYS_CHECK_TBD(&INITIATIVE_ID,&HERCULES);
