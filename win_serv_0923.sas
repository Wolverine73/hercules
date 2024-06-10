/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Friday, August 09, 2002      TIME: 10:23:21 AM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */
/* ----------------------------------------
   Code exported from SAS Enterprise Guide
   DATE: Wednesday, June 19, 2002      TIME: 01:02:50 PM
   PROJECT: macros
   PROJECT PATH: C:\Documents and Settings\qcpi514\Caremark\EG_projects\macros.seg
---------------------------------------- */
%MACRO win_serv(wait=Y);
   /* To use this macro with the export_import macro the name of the connect
      macro must coinside with the name in the remote option and with the 
      name of the signon script (preceded by underscore). 
   */
%GLOBAL _win_serv;     
 %LET win_serv=SF0004.psd.caremark.int 25000; 
/* Synchronous (CWAIT=Y) or Asynchronous (CWAIT=N) remote submit */
OPTIONS COMAMID=tcp REMOTE=win_serv CWAIT=&wait; 
 %LET  _win_serv=NOSCRIPT; 
 SIGNON REMOTE=win_serv USER=sasadm PASSWORD=sasadm ;
 %MEND;
