

%MACRO EXCLUDE_PARTICIPANTS;
LIBNAME PRCT_EXC "/DATA/sas&sysmode.1/hercules/participant_exclusions";

DATA PRCT_EXC.PARTICIPANTS_TO_EXCLUDE;
INFILE '/DATA/sas&sysmode.1/hercules/participant_exclusions/participant_exclusion_72.csv' DSD MISSOVER DELIMITER = ',' FIRSTOBS=2;;
FORMAT 	QL_BENEFICIARY_ID $40.
                MBR_ID $25.;
		INPUT 	QL_BENEFICIARY_ID $
                MBR_GID	
				MBR_ID	$ ;
RUN;


DATA T_&INITIATIVE_ID._1_1_excl_bkup;
SET T_&INITIATIVE_ID._1_1;
RUN;


PROC SQL;
UPDATE T_&INITIATIVE_ID._1_1
SET DATA_QUALITY_CD = 3
WHERE t_&initiative_id._1_1.PT_BENEFICIARY_ID in
		(select 1 from PRCT_EXC.PARTICIPANTS_TO_EXCLUDE);

QUIT;

%MEND EXCLUDE_PARTICIPANTS;







