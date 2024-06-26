/*HEADER---------------------------------------------------------------------------------------------------------
|MACRO: UPDATE_DELIVERY_SYS.SAS
|
|PURPOSE: TO UPDATE THE MAIL/RETAIL CODES TO 2/3 RESPECTIVELY, FOR THE CLAIMS UNDER PROCESS
|
|LOGIC:  THE QUERY CHECKS THE LOOKUP COLUMN (TYPICALLY DELIVERY_SYSTEM COLUMN) 
|		 AND UPDATES THE UPDATE COLUMN (TYPICALLY LAST_DELIVERY_SYS) TO EITHER 2 OR 3
|		 FOR MAIL/RETAIL IDENTIFICATION RESPECTIVELY. 
|						
|		 INITIALLY CREATED TO BE USED FOR STANDARD AND CUSTOM PROACTIVE REFILL PROGRAMS.
|		
|INPUT PARAMETERS: TABLE TO BE UPDATED, COL_UPD - COLUMN TO BE UPDATED 
|					,COL_LKP - COLUMN THAT IS LOOKED UP FOR DETERMINATION OF MAIL/RETAIL CLAIMS.
|					 THIS COLUMN WOULD TYPICALLY BE THE OUTPUT OF THE QUERY THAT USES THE 
|					 DELIVERY_SYS_CHECK PROGRAM GENERATED MACRO MACRO VARIABLE &&CREATE_DELIVERY_SYSTEM_CD_&ADJ_ENGINE.
|
|HISTORY: FIRST RELEASE - ARJUN KOLAKOTLA - 05SEP2013
+-----------------------------------------------------------------------------------------------------------HEADER*/


%MACRO UPDATE_DELIVERY_SYS(TABLE_NAME,COL_LKP,COL_UPD);

%IF &PROGRAM_ID. = 72 OR (&PROGRAM_ID. = 106 AND &TASK_ID. = 28 ) %THEN %DO;	/*EXECUTING FOR STANDARD AND CUSTOM PROACTIVE - ADD MORE PROGRAM IDS AS NEEDED */


PROC SQL NOPRINT;
CONNECT TO ORACLE(PATH=&GOLD.);

EXECUTE (
UPDATE &TABLE_NAME.
SET &COL_UPD. = '3'
WHERE TRIM(&COL_LKP.) IN ('R', 'RETAIL')
		)BY ORACLE;

EXECUTE (
UPDATE &TABLE_NAME.
SET &COL_UPD. = '2'
WHERE TRIM(&COL_LKP.) IN ('M', 'MAIL')
		)BY ORACLE;

DISCONNECT FROM ORACLE
;QUIT;


%END;		/*	END STD AND CUSTOM PROACTIVE ONLY CONDITION - ADD MORE PROGRAM IDS AS NEEDED	*/
%MEND UPDATE_DELIVERY_SYS;

/*%UPDATE_DELIVERY_SYS(TABLE_NAME=%str(%trim(&TBL_NM_RX_RE.)), COL_LKP=%STR(DELIVERY_SYSTEM),COL_UPD=%STR(LAST_DELIVERY_SYS));*/
