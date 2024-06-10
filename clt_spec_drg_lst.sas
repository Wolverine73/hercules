/*HEADER---------------------------------------------------------------------------------------------------------
|MACRO: 		CLT_SPEC_DRG_LST.SAS
|
|PURPOSE: 		TO LOAD CUSTOM CLIENT/DRUG LIST TO ORACLE TABLE, FOR RX/RE
|
|INPUT:			CSV FILE - ONE EACH FOR RX/RE on the /herc&sysmode./data/hercules/72/ directory.
|
|LOGIC:         READ THE USER PROVIDED CSV FILE, PERFORM LOOK UPS TO THE DSS_CLIN.V_DRUG_DENORM TABLE ON ORACLE(EDW)
|						
|OUTPUT:		TABLE INSERT THAT IS USED FOR SPECIFIC CLIENT/DRUG TARGETING			
|+-----------------------------------------------------------------------------------------------------------------
|HISTORY: 
|			    RG 02/01/2013 - Hercules Stabilization
+-----------------------------------------------------------------------------------------------------------HEADER*/


%MACRO CLT_SPEC_DRG_LST( ADJ_ENGN= , PRG_ID = );

FILENAME EXTCLTLS "/herc%LOWCASE(&SYSMODE./DATA/HERCULES/&PRG_ID/EXTERNAL_DRUG_LIST/CLIENT_SPECIFIC_DRUG_LIST_&ADJ_ENGN..CSV)";

%IF %SYSFUNC(FEXIST(EXTCLTLS))>0 %THEN %DO;


/*	Read the csv file	*/
	DATA CLIENT_SPECIFIC_DRUG_LIST_&ADJ_ENGN.;
		INFILE EXTCLTLS	DSD MISSOVER DELIMITER = ',' FIRSTOBS=2;
		FORMAT 	CLIENT_LEVEL_1 $22.	
				CLIENT_LEVEL_2 $22. 
				CLIENT_LEVEL_3 $22. 
				DRUG_ID $22.;

		INPUT 	CLIENT_LEVEL_1 $	
				CLIENT_LEVEL_2 $ 
				CLIENT_LEVEL_3 $ 
				DRUG_ID_TYPE_CD 
				DRUG_ID $;

		
	RUN;

%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..CLIENT_SPECIFIC_DRUG_LIST_&ADJ_ENGN._1);
/*	Load table on Oracle for look up and further processing	*/
		DATA &ORA_TMP..CLIENT_SPECIFIC_DRUG_LIST_&ADJ_ENGN._1;
		SET CLIENT_SPECIFIC_DRUG_LIST_&ADJ_ENGN.;
		RUN;


%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..CLNT_SPEC_DRG_LIST_&ADJ_ENGN.);
/*	Perform the look up by GP14I/NDC11/GCN					*/
		PROC SQL ;
		CONNECT TO ORACLE(PATH=&GOLD.);
		execute (
		CREATE TABLE &ORA_TMP..CLNT_SPEC_DRG_LIST_&ADJ_ENGN. AS
					SELECT distinct A.CLIENT_LEVEL_1,
						   A.CLIENT_LEVEL_2,
						   A.CLIENT_LEVEL_3,
						   A.DRUG_ID,
						   A.DRUG_ID_TYPE_CD,
		                   B.NDC_CODE AS DRUG_NDC_ID,
						   B.DRUG_GID,
						   SUBSTR(B.GPI_CODE,1,2) AS GPI_GROUP,
						   SUBSTR(B.GPI_CODE,3,2) AS GPI_CLASS,
						   B.GPI_CODE,
						   B.GCN_CODE 

		            FROM   &ORA_TMP..CLIENT_SPECIFIC_DRUG_LIST_&ADJ_ENGN._1 A
		                 , &DSS_CLIN..V_DRUG_DENORM B
		            WHERE 	  ((A.DRUG_ID_TYPE_CD   = 3 AND A.DRUG_ID = B.NDC_CODE)
		                  OR (A.DRUG_ID_TYPE_CD 	= 1 AND A.DRUG_ID = B.GPI_CODE)
		                  OR (A.DRUG_ID_TYPE_CD		= 4 AND A.DRUG_ID = B.GCN_CODE))
		               	  AND B.DRUG_VLD_FLG = 'Y'
		)by oracle;
		DISCONNECT FROM ORACLE;
		QUIT;


/*%DROP_ORACLE_TABLE(TBL_NAME =  &ORA_TMP..CLNT_SPEC_DRG_LIST_&ADJ_ENGN.);*/

	PROC SQL NOPRINT;
		SELECT 	COUNT(DRUG_NDC_ID)
		INTO	:COUNT_MISSING_GIDS
		FROM  &ORA_TMP..CLNT_SPEC_DRG_LIST_&ADJ_ENGN. 
		WHERE DRUG_GID IS NULL;
	QUIT;

%PUT COUNT_MISSING_GIDS = &COUNT_MISSING_GIDS;

%IF &COUNT_MISSING_GIDS > 0 %THEN %DO;
		FILENAME MYMAIL EMAIL 'QCPAP020@TSTSAS5';
	   		DATA _NULL_;
	     		FILE MYMAIL
	         	TO=(&EMAIL_USR)
	         	SUBJECT="CLIENT SPECIFIC EXTERNAL DRUG LIST" ;
				PUT 'HI,' ;
	     		PUT / "THIS IS AN AUTOMATICALLY GENERATED MESSAGE TO INFORM YOU THAT DRUG_GIDS FOR %LEFT(%STR(&COUNT_MISSING_GIDS.)) NDCS ARE NOT AVAILABLE FOR &PRG_ID FOR &ADJ_ENGN ADJUCICATION";
				PUT / 'PLEASE LET US KNOW OF ANY QUESTIONS.';
	    		PUT / 'THANKS,';
	     		PUT / 'HERCULES PRODUCTION SUPPORT';
	   		RUN;
%END;

	%IF &ADJ_ENGN = RX %THEN %DO;

		%LET CARRIER_FIELD = CLIENT_LEVEL_1;

	%END;

	%IF &ADJ_ENGN = RE %THEN %DO;

		%LET CARRIER_FIELD = CLIENT_LEVEL_2;

	%END;


/*	Join to tclient1 table to get clint_id	*/
%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..CLIENT_SPECIFIC_DRUG_LIST_&ADJ_ENGN.);
	PROC SQL;
		CREATE TABLE &ORA_TMP..CLIENT_SPECIFIC_DRUG_LIST_&ADJ_ENGN. AS
		SELECT DISTINCT A.*, B.CLIENT_ID AS QL_CLIENT_ID
		FROM 
/*	 		 &ORA_TMP..CLIENT_SPECIFIC_DRUG_LIST_&ADJ_ENGN. A*/
			 &ORA_TMP..CLNT_SPEC_DRG_LIST_&ADJ_ENGN.	A
		LEFT JOIN
		     &CLAIMSA..TCLIENT1 B
		ON TRIM(LEFT(A.&CARRIER_FIELD.)) = TRIM(LEFT(SUBSTR(B.CLIENT_CD,2)));
	QUIT;



%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..CLIENT_SPECIFIC_DRUG_LIST2_&ADJ_ENGN.);

	PROC SQL;
		CONNECT TO ORACLE(PATH = &GOLD.);
		EXECUTE
		(
		CREATE TABLE &ORA_TMP..CLIENT_SPECIFIC_DRUG_LIST2_&ADJ_ENGN. AS
		SELECT A.*
		FROM &ORA_TMP..CLIENT_SPECIFIC_DRUG_LIST_&ADJ_ENGN. A
		LEFT JOIN
		     &ORA_TMP..EXT_CLIENT_DRUG_TABLE_&ADJ_ENGN.  B
		ON 		A.CLIENT_LEVEL_1 = B.CLIENT_LEVEL_1 
		    AND A.CLIENT_LEVEL_2 = B.CLIENT_LEVEL_2
			AND A.CLIENT_LEVEL_3 = B.CLIENT_LEVEL_3
	    	AND A.DRUG_GID = B.DRUG_GID
	    WHERE (B.DRUG_GID IS NULL AND
	           B.CLIENT_LEVEL_1 IS NULL)
        )BY ORACLE;
		DISCONNECT FROM ORACLE;
	QUIT;
/*	%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..CLIENT_SPECIFIC_DRUG_LIST_&ADJ_ENGN.);*/


	/*
	%DROP_ORACLE_TABLE(TBL_NAME=&ORA_TMP..EXT_CLIENT_DRUG_TABLE_&ADJ_ENGN.);
	PROC SQL;
	CONNECT TO ORACLE (PATH = &GOLD);
	EXECUTE
	(
		CREATE TABLE &ORA_TMP..EXT_CLIENT_DRUG_TABLE_&ADJ_ENGN. 
			(PROGRAM_ID INT, QL_CLIENT_ID INT, 
			 CLIENT_LEVEL_1 CHAR(22), CLIENT_LEVEL_2 CHAR(22), CLIENT_LEVEL_3 CHAR(22),
			 DRUG_GID INT, GPI_GROUP CHAR(2), GPI_CLASS CHAR(2),
			 EFFECTIVE_DT DATE, EXPIRATION_DT DATE, 
			 HSC_USR_ID CHAR(8), HSC_TS DATE, HSU_USR_ID CHAR(8), HSU_TS DATE)
	)BY ORACLE;
	DISCONNECT FROM ORACLE;
	QUIT;
	*/

/* I N S E R T    I N T O	 T H E   F I N A L   T A B L E 		T H A T 	W I L L 	B E 	U S E D 	I N 	C L A I M S	 P U L L*/

	PROC SQL;
		CONNECT TO ORACLE(PATH = &GOLD.);
		EXECUTE
		(
		INSERT INTO &ORA_TMP..EXT_CLIENT_DRUG_TABLE_&ADJ_ENGN. 
			(PROGRAM_ID, QL_CLIENT_ID, 
             CLIENT_LEVEL_1, CLIENT_LEVEL_2, CLIENT_LEVEL_3,
			 DRUG_GID, GPI_GROUP, GPI_CLASS,
			 EFFECTIVE_DT, EXPIRATION_DT, 
		     HSC_USR_ID, HSC_TS, HSU_USR_ID, HSU_TS)
		SELECT 
			 &PRG_ID., QL_CLIENT_ID,
             CLIENT_LEVEL_1, CLIENT_LEVEL_2, CLIENT_LEVEL_3,
			 DRUG_GID, GPI_GROUP, GPI_CLASS,
			 SYSDATE, '9999-12-31', 
			 %BQUOTE('&USER.'), SYSDATE,  %BQUOTE('&USER.'), SYSDATE
		FROM 
			&ORA_TMP..CLIENT_SPECIFIC_DRUG_LIST2_&ADJ_ENGN.
        )BY ORACLE;
		DISCONNECT FROM ORACLE;
	QUIT;

    %SET_ERROR_FL;

/*	%DROP_ORACLE_TABLE(TBL_NAME = &ORA_TMP..CLIENT_SPECIFIC_DRUG_LIST2_&ADJ_ENGN.);*/


/*	%IF &ERR_FL = 0 %THEN %DO;*/
/*		DATA _NULL_;*/
/*			CALL SYMPUT ('TIMESTAMP', PUT(TODAY(),DATE9.));*/
/*		RUN;*/
/*		%PUT &TIMESTAMP;*/
/**/
/*		%LET SRC_TO_MOVE = %STR(/DATA/%LOWCASE(SAS&SYSMODE.1/HERCULES/&PRG_ID./EXTERNAL_DRUG_LIST/CLIENT_SPECIFIC_DRUG_LIST_&ADJ_ENGN..CSV));*/
/*		%LET TRGT_TO_MOVE = %STR(/DATA/%LOWCASE(SAS&SYSMODE.1/HERCULES/&PRG_ID./EXTERNAL_DRUG_LIST/ARCHIVE/CLIENT_SPECIFIC_DRUG_LIST_&ADJ_ENGN._&TIMESTAMP..CSV));*/
/**/
/*		%PUT SRC_TO_MOVE = &SRC_TO_MOVE;*/
/*		%PUT TRGT_TO_MOVE = &TRGT_TO_MOVE;*/
/**/
/*		SYSTASK COMMAND "MV &SRC_TO_MOVE &TRGT_TO_MOVE " TASKNAME=SAS1;*/
/*		WAITFOR _ALL_ SAS1;*/
/**/
/*	%END; */

%END;

%MEND CLT_SPEC_DRG_LST;

%set_sysmode(mode=sit2);
%INCLUDE "/herc&sysmode/prg/hercules/hercules_in.sas";
libname dss_herc oracle path=gold user=dss_herc pw=anlt2web schema=dss_herc;

%let PROGRAM_ID = 72;
%let PRG_ID = 72;
    %CLT_SPEC_DRG_LST(ADJ_ENGN= RX, PRG_ID = &PROGRAM_ID);
    %CLT_SPEC_DRG_LST(ADJ_ENGN= RE, PRG_ID = &PROGRAM_ID);





/*%LET ADJ_ENGN= RX;*/
/*%let PRG_ID = 72;*/
/*%LET ORA_TMP=DSS_HERC;*/
