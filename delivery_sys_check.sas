/*HEADER---------------------------------------------------------------------------------------------------------
|MACRO: DELIVERY_SYS_CHECK.SAS
|
|PURPOSE: RESOLVE EXCLUSION DELIVERY SYSTEM ACROSS ALL PLATFORMS.
|
|LOGIC:   DETERMINE IF ANY OF THE DELIVERY SYSTEMS SHOULD BE EXCLUDED FROM THE
|					INITIATIVE.  IF SO, FORM A STRING THAT WILL BE INSERTED INTO THE SQL THAT
|					QUERIES CLAIMS.
|					PROCESS WILL FIND OUT THE DELIVERY SYSTEM TO BE EXCLUDE ON ALL THREE 
|					PLATFORMS(RX,RE,QL) AND ASSIGN IT INTO MACRO VARIABLES
|					( DS_STRING(QL), DS_STRING_RX_RE(RX,RE),MAIL_DELVRY_CD(RX,RE)
|								  RETAIL_DELVRY_CD(RX,RE),EDW_DELIVERY_SYSTEM(RX,RE)).
|						
|						
|PARAMETERS:            GLOBAL MACRO VARIABLES: INITIATIVE_ID, PHASE_SEQ_NB.
|
|+-----------------------------------------------------------------------------------------------------------------
| HISTORY: 
| FIRST RELEASE: 		10MAY2008 - K.MITTAPALLI   - Hercules Version  2.1.01
| Second RELEASE: 		27AUG2009 - N.WILLIAMS     - Hercules Version  2.1.02 - Adjusted code logic as this is not working
|                                                    properly. 
|                                                    1. Adjust two if statements for multiple exlcusions
|                                                    2. Create two new macro variables. 
+-----------------------------------------------------------------------------------------------------------HEADER*/
%MACRO DELIVERY_SYS_CHECK(INITIATIVE_ID,HERCULES);

	%GLOBAL DS_STRING DS_STRING_RX_RE RETAIL_DELVRY_CD MAIL_DELVRY_CD OMIT_DS_STR EDW_DELIVERY_SYSTEM OMIT_DS
		CREATE_DELIVERY_SYSTEM_CD_RX CREATE_DELIVERY_SYSTEM_CD_RE DS_STRING_RE DS_STRING_RX;

	*SASDOC------------------------------------------------------------------------------------------------------------
	| DETERMINE IF ANY OF THE DELIVERY SYSTEMS SHOULD BE EXCLUDED FROM THE
	| INITIATIVE.  IF SO, FORM A STRING THAT WILL BE INSERTED INTO THE SQL THAT
	| QUERIES CLAIMS.
	| 	10MAY2008 - K.MITTAPALLI - HERCULES VERSION  2.1.0.1
	+-----------------------------------------------------------------------------------------------------------SASDOC*;
	PROC SQL NOPRINT;
	  SELECT COUNT(DELIVERY_SYSTEM_CD) INTO :OMIT_DS
	  FROM &HERCULES..TDELIVERY_SYS_EXCL
	  WHERE INITIATIVE_ID = &INITIATIVE_ID;
	QUIT;

		%PUT NOTE:	OMIT_DS=&OMIT_DS;
	*SASDOC-----------------------------------------------------------------------------------------------------------
	| PROCESS WILL FIND OUT THE DELIVERY SYSTEM TO BE EXCLUDE ON ALL THREE PLATFORMS(RX,RE,QL)
	| AND ASSIGN IT INTO MACRO VARIABLES( DS_STRING(QL), DS_STRING_RX_RE(RX,RE),MAIL_DELVRY_CD(RX,RE)
	|									  RETAIL_DELVRY_CD(RX,RE),EDW_DELIVERY_SYSTEM(RX,RE)). 
	| 	10MAY2008 - K.MITTAPALLI - HERCULES VERSION  2.1.0.1
	| 	27AUG2009 - N.WILLIAMS   - HERCULES VERSION  2.1.0.2 - Adjust two if statements for multiple delivery system 
	|	                                                       exclusions. 
	+----------------------------------------------------------------------------------------------------------SASDOC*;

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
			    %END;
			    %IF &OMIT_DS_STR EQ 2 %THEN %DO;   /******* target retail */
					%LET DS_STRING_RE=%STR(AND (CLAIM.MAIL_ORDR_CODE NOT IN ('Y')));
					%LET DS_STRING_RX=%STR(AND (PHMCY.PHMCY_DSPNS_TYPE NOT IN ('5') AND PHMCY.SCTDL_MDO_FLG NOT IN ('Y') AND PHMCY.PHMCY_GID NOT IN (39134,615806) ));
			    %END;
			    %IF &OMIT_DS_STR EQ 3 %THEN %DO;   /******* target mail */
					%LET DS_STRING_RE=%STR(AND (CLAIM.MAIL_ORDR_CODE='Y'));
					%LET DS_STRING_RX=%STR(AND (PHMCY.PHMCY_DSPNS_TYPE='5' OR PHMCY.SCTDL_MDO_FLG='Y' OR PHMCY.PHMCY_GID IN (39134,615806) ));
			    %END;
			    %IF &OMIT_DS_STR EQ 1,3 %THEN %DO; /******* target mail */
					%LET DS_STRING_RE=%STR(AND (CLAIM.MAIL_ORDR_CODE='Y'));
					%LET DS_STRING_RX=%STR(AND (PHMCY.PHMCY_DSPNS_TYPE='5' OR PHMCY.SCTDL_MDO_FLG='Y' OR PHMCY.PHMCY_GID IN (39134,615806) ));
			    %END;
			    %IF &OMIT_DS_STR EQ 1,2 %THEN %DO; /******* target retail */
					%LET DS_STRING_RE=%STR(AND (CLAIM.MAIL_ORDR_CODE NOT IN ('Y')));
					%LET DS_STRING_RX=%STR(AND (PHMCY.PHMCY_DSPNS_TYPE NOT IN ('5') AND PHMCY.SCTDL_MDO_FLG NOT IN ('Y') AND PHMCY.PHMCY_GID NOT IN (39134,615806) ));
			    %END;
			    %IF &OMIT_DS_STR EQ 2,3 %THEN %DO; /******* target retail-paper */
					%LET DS_STRING_RE=%STR(AND (CLAIM.MAIL_ORDR_CODE NOT IN ('Y')));
					%LET DS_STRING_RX=%STR(AND (PHMCY.PHMCY_DSPNS_TYPE NOT IN ('5') AND PHMCY.SCTDL_MDO_FLG NOT IN ('Y') AND PHMCY.PHMCY_GID NOT IN (39134,615806) ));
			    %END;

		 %END; /* END OF RX_ADJ EQ 1 OR RE_ADJ EQ 1*/

	%END;  /* END OF OMIT_DS GT 0 */
	%ELSE %DO;
			%LET  DS_STRING=%STR();
			%LET  DS_STRING_RX_RE=%STR();
			%LET  DS_STRING_RE=%STR();
			%LET  DS_STRING_RX=%STR();
	%END;

	*SASDOC-----------------------------------------------------------------------------------------------------------
	| EDW delivery system code check was reversed.  mail = NABP_CODE_6 NOT IN
	| retail = NABP_CODE_6 IN
	| 	27AUG2009 - N.WILLIAMS   - HERCULES VERSION  2.1.0.2 - Adjust two if statements for multiple delivery system 
	+----------------------------------------------------------------------------------------------------------SASDOC*;
	%IF (&RX_ADJ EQ 1 OR &RE_ADJ EQ 1) %THEN %DO;
	
	   %LET RETAIL_DELVRY_CD = %STR(AND PHMCY.NABP_CODE_6 IN('482663','146603','032664','012929','398095','459822','032691','147389','458303','100229'));
	   %LET MAIL_DELVRY_CD = %STR(AND PHMCY.NABP_CODE_6 NOT IN('482663','146603','032664','012929','398095','459822','032691','147389','458303','100229'));
	   %LET EDW_DELIVERY_SYSTEM = %STR( CASE WHEN PHMCY.NABP_CODE_6 IN ('482663','146603','032664','012929','398095','459822','032691','147389','458303','100229') 
					      THEN 'RETAIL'
					      WHEN PHMCY.NABP_CODE_6 NOT IN ('482663','146603','032664','012929','398095','459822','032691','147389','458303','100229')
					      THEN 'MAIL'
					 END AS DELIVERY_SYSTEM );
					 
	   %LET CREATE_DELIVERY_SYSTEM_CD_RE = %STR(CASE WHEN CLAIM.MAIL_ORDR_CODE='Y' THEN '2'   
							 ELSE '3'
						    END AS DELIVERY_SYSTEM_CD  );
	   %LET CREATE_DELIVERY_SYSTEM_CD_RX = %STR(CASE   WHEN PHMCY.phmcy_dspns_type='5' OR 
							PHMCY.sctdl_mdo_flg='Y'  OR 
							PHMCY.PHMCY_GID in (39134,615806) THEN '2'   
							ELSE '3'
							END AS DELIVERY_SYSTEM_CD  );
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
	%PUT *********************************************************************************;

%MEND DELIVERY_SYS_CHECK;
%DELIVERY_SYS_CHECK(&INITIATIVE_ID,&HERCULES);
