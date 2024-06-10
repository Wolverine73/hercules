/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Monday, April 05, 2004      TIME: 10:46:03 PM
   PROJECT: macros
   PROJECT PATH: M:\Documents and Settings\qcpi514\Caremark\EG_projects\EG_projects_20\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Wednesday, March 24, 2004      TIME: 06:01:13 PM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */
/*HEADER-----------------------------------------------------------------------

 HISTORY:  MAR 2004 - Yury Vilk    - Original.
           JUL 2005 - G. Comerford - Modified to include reference to DSS_CLIN.

+-----------------------------------------------------------------------HEADER*/

%MACRO sasnode(wait=Y,user=,password=);
   /* To use this macro with the export_import macro the name of the connect
      macro must coinside with the name in the remote option and with the
      name of the signon script (preceded by underscore).
   */

%IF &user=%STR()         %THEN %LET user=&user_SASNODE.;
%IF &password=%STR() %THEN %LET password=&password_SASNODE.;

%GLOBAL _sasnode;
 %LET sasnode=sasnode;
/* Synchronous (CWAIT=Y) or Asynchronous (CWAIT=N) remote submit */
OPTIONS COMAMID=tcp REMOTE=sasnode CWAIT=&wait;
FILENAME rlink '!sasroot/misc/connect/tcpunix_sasnode.scr';
 %LET  _sasnode=rlink;
 SIGNON REMOTE=sasnode ;

 /*
 LIBNAME RDSS_CMX REMOTE SERVER=sasnode RENGINE=ORACLE ROPTIONS="PATH=&GOLD SCHEMA=DSS_CMX  DEFER=YES";
 LIBNAME &user_SASNODE REMOTE SERVER=sasnode RENGINE=ORACLE ROPTIONS="PATH=&GOLD SCHEMA=&user_SASNODE. DEFER=YES";
*/

  %LET _dir_name=/usr/saswork/DATA/sasadhoc10/&user_SASNODE.;

  %SYSLPUT GOLD=&GOLD;
  %SYSLPUT user_SASNODE=&user_SASNODE;
  %SYSLPUT _dir_name=&_dir_name;

RSUBMIT;
   LIBNAME DSS_CMX  ORACLE PATH=&GOLD SCHEMA=DSS_CMX DEFER=YES;
   LIBNAME &user_SASNODE.  ORACLE PATH=&GOLD SCHEMA=&user_SASNODE. DEFER=YES;
   libname DSS_CLIN ORACLE PATH=&GOLD SCHEMA=DSS_CLIN DEFER=YES;

   DATA _NULL_;
    IF FILEEXIST("&_dir_name")=0 THEN rc=SYSTEM("mkdir &_dir_name");
   RUN;
   LIBNAME SASDATA "&_dir_name";
ENDRSUBMIT;

LIBNAME RWORK REMOTE SERVER=SASNODE SLIBREF=WORK;
LIBNAME RSASDATA REMOTE SERVER=SASNODE SLIBREF=SASDATA;
LIBNAME RDSS_CMX REMOTE SERVER=SASNODE SLIBREF=DSS_CMX;
LIBNAME R&user_SASNODE. REMOTE SERVER=SASNODE SLIBREF=&user_SASNODE;
libname RDSSCLIN REMOTE SERVER=SASNODE SLIBREF=DSS_CLIN;

 %MEND;
