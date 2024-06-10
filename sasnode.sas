/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Thursday, March 09, 2006      TIME: 11:00:10 AM
   PROJECT: Project
   PROJECT PATH: 
---------------------------------------- */
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
           MAR 2006 - Dan Downing  - Modified to use first 7 characters of User ID to assign
                                     remote LIBNAME over ORACLE personal schema. User IDs can
                                     be 8 characters and when concatenated with an R (for Remote) 
                                     preface, it produces an invalid SAS LIBNAME statement.
           OCT 2006 - Dan Downing  - Change to point to NEW SASNODE. Remove auto assignment of SASDATA
                                     LIBNAME and auto build of user personal directory. Remove auto assignment
                                     of DSS_CMX Oracle LIBNAME.                                 

+-----------------------------------------------------------------------HEADER*/

%MACRO sasnode(wait=Y,user=,password=);
   /* To use this macro with the export_import macro the name of the connect
      macro must coinside with the name in the remote option and with the
      name of the signon script (preceded by underscore).
   */

%IF &user=%STR()         %THEN %LET user=&user_SASNODE.;
%IF &password=%STR() %THEN %LET password=&password_SASNODE.;

%GLOBAL _sasnode;
 %LET sasnode=sasnode ;
/* Synchronous (CWAIT=Y) or Asynchronous (CWAIT=N) remote submit */
OPTIONS COMAMID=tcp REMOTE=sasnode CWAIT=&wait;
FILENAME rlink '!sasroot/misc/connect/tcpunix_sasnode.scr';
 %LET  _sasnode=rlink;
 SIGNON REMOTE=sasnode ;

  %SYSLPUT GOLD=&GOLD;
  %SYSLPUT user_SASNODE=&user_SASNODE;

RSUBMIT;
   LIBNAME &user_SASNODE.  ORACLE PATH=&GOLD SCHEMA=&user_SASNODE. DEFER=YES;
   libname DSS_CLIN ORACLE PATH=&GOLD SCHEMA=DSS_CLIN DEFER=YES;
ENDRSUBMIT;

data _null_ ; 
   R_user_SASNODE = 'R'||substr("&user_SASNODE",1,7) ;
   call symput('R_user_SASNODE',R_user_SASNODE)   ;
run ;

LIBNAME RWORK REMOTE SERVER=SASNODE SLIBREF=WORK;
LIBNAME &R_user_SASNODE. REMOTE SERVER=SASNODE SLIBREF=&user_SASNODE;
libname RDSSCLIN REMOTE SERVER=SASNODE SLIBREF=DSS_CLIN;

 %MEND;
