%MACRO LOAD_PARTICIPANT_EXCLUSION;

	%LET ERR_FL = 0;

	/*commented for testing purpose*/
	filename fst_pro "/herc&sysmode/data/hercules/participant_exclusions/participant_exclusion_72.csv";

	%IF %SYSFUNC(FEXIST("/herc&sysmode/data/hercules/participant_exclusions/participant_exclusion_72.sas7bdat")) = 0 %THEN %DO;

	libname prct_exc "/herc&sysmode/data/hercules/participant_exclusions/";
  proc datasets lib=prct_exc;
    delete PARTICIPANT_EXCLUSION;
  quit;

	/** Create an Empty sas dataset to be load in the libnmae prct_exc **/

	PROC SQL;
		CREATE TABLE PRCT_EXC.PARTICIPANT_EXCLUSION 
			(PROGRAM_ID INT, QL_BENEFICIARY_ID CHAR(40), MBR_GID INT, MBR_ID CHAR(25),
			 EFFECTIVE_DT DATE, EXPIRATION_DT DATE, 
			 HSC_USR_ID CHAR(8), HSC_TS DATE, HSU_USR_ID CHAR(8), HSU_TS DATE);
	QUIT;
  %END;	

	%IF (&PROGRAM_ID = 72) AND %SYSFUNC(FEXIST(fst_pro)) > 0 %THEN %DO;
		DATA PARTICIPANT_EXCLUSION;
			INFILE FST_PRO DSD MISSOVER DELIMITER = ',' FIRSTOBS=2;
			FORMAT 	QL_BENEFICIARY_ID $40.
	                MBR_ID $25.;
			INPUT 	QL_BENEFICIARY_ID $
	                MBR_GID	
					MBR_ID	$ ;
		RUN;

		PROC SQL;
			CREATE TABLE PARTICIPANT_EXCLUSION2 AS
			SELECT A.*
			FROM PARTICIPANT_EXCLUSION A
			WHERE NOT EXISTS (SELECT 1
								FROM PRCT_EXC.PARTICIPANT_EXCLUSION B 
								WHERE B.PROGRAM_ID IN (72,73) AND
	                                  (
	                                   (TRIM(LEFT(A.QL_BENEFICIARY_ID)) = TRIM(LEFT(B.QL_BENEFICIARY_ID)) 
	                                     AND B.QL_BENEFICIARY_ID IS NOT NULL)
	                                   OR
				                       (TRIM(LEFT(A.MBR_ID)) = TRIM(LEFT(B.MBR_ID)) 
	                                     AND B.MBR_ID IS NOT NULL)
	                                   OR
	                                   (A.MBR_GID = B.MBR_GID
									     AND B.MBR_GID IS NOT MISSING)
	                                   )
							 );
		QUIT;

		PROC SQL;
			INSERT INTO PRCT_EXC.PARTICIPANT_EXCLUSION 
				(PROGRAM_ID, QL_BENEFICIARY_ID, MBR_GID, MBR_ID,
				 EFFECTIVE_DT, EXPIRATION_DT, 
			     HSC_USR_ID, HSC_TS, HSU_USR_ID, HSU_TS)

			SELECT 
				 72, QL_BENEFICIARY_ID, MBR_GID, MBR_ID,
				 today(), '31DEC9999'D, 
				 "&USER.", today(), "&USER.", today()
			FROM 
				PARTICIPANT_EXCLUSION2
	    ;
		QUIT;

	   %SET_ERROR_FL;

		%IF &ERR_FL = 0 %THEN %DO;
			DATA _NULL_;
				CALL SYMPUT ('TIMESTAMP', PUT(TODAY(),DATE9.));
			RUN;
			%PUT &TIMESTAMP;

			systask command "mv /herc&sysmode/data/hercules/participant_exclusions/participant_exclusion_72.csv /herc&sysmode/data/hercules/participant_exclusions/archive/participant_exclusion_72_&timestamp..csv" taskname=sas1;
			WAITFOR _ALL_ SAS1;

		%END; 

	%END;

%MEND LOAD_PARTICIPANT_EXCLUSION;
%LOAD_PARTICIPANT_EXCLUSION;
