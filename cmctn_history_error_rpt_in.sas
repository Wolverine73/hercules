/*HEADER*************************************************************************
 Program Name     : cmctn_error_rprt_in.sas
 Purpose          : Sets up the parameter variables for the Communication HIstory 
                    error reporting

*********************************************************************************
| Apr  2007    - Greg Dudley Hercules Version  1.5
* HISTORY:  20APR2007 - G. Dudley - Original
| Oct  2010    - N. Williams Hercules Version  2.1 - update ftp user/passwd
|                should be changed to your mainframe user_id/password
*************************************************************************HEADER*/
OPTIONS NOSYNTAXCHECK;
OPTIONS MISSING='';
OPTIONS COMPRESS=NO;

			%LET FTP_user= "&USER_DSNJ_OSA";
			%LET FTP_pass= "&PASSWORD_DSNJ_OSA";

			%LET Primary_programer='PRODSUP';			
			%LET Primary_programer_MF="QCPI254","QCPU570","QCPI115";			

			%LET PRG_root=/PRG/sas&sysmode.1/hercules/gen_utilities/sas/update_cmtn;

			%LET DB2_tmp=DB2_TMP1;
LIBNAME ADM_LKP "/DATA/sas&sysmode.1/Admin/auxtable";
LIBNAME ANLLKP DB2 DSN=&UDBSPRP SCHEMA=ANLLKP DEFER=YES ;

OPTIONS MISSING='';

PROC SQL NOPRINT ;
 SELECT  QUOTE(TRIM(email)) INTO : Primary_programer_email SEPARATED BY ' ' 
  FROM ADM_LKP.ANALYTICS_USERS
   WHERE UPCASE(QCP_ID) IN (&Primary_programer)
    ;
QUIT;

%PUT Primary_programer_email=&Primary_programer_email;
