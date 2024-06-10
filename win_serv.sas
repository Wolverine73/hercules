/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  win_serv.sas
|
| LOCATION: /PRG/sasprod1/hercules/macros
|
| PURPOSE:  This macro purpose is to connect remotely to Mini-Zeus.  This
|           macro is used with the export_import macro the name of the connect macro
|      		must coinside with the name in the remote option and with the 
|      		name of the signon script (preceded by underscore). 
|  
|
| LOGIC:	(1) Determines current environment.
|		(2) Modifies output destination.
|
| INPUT:    Current Environment
|
| OUTPUT:   Standard output variables.
|
| USAGE:    sasprogram(DEV);
|
+--------------------------------------------------------------------------------
| HISTORY:  09AUG2002 - Yury Vilk    - Original.
|           17MAR2008 - N.WILLIAMS   - Hercules Version  2.0.01
|                                      1. Update win_serv macro variable value for 
|                                      changes to the windows network domain change.
|           28AUG2008 - R Smith      - Hercules Version  2.1.01
|                                      1. Change user name from sasadm to caremarkrx\sasadm
|                                         This fully qualifies user id.
+------------------------------------------------------------------------HEADER*/

%MACRO win_serv(wait=Y);

%GLOBAL _win_serv;     
%LET win_serv=SF0004.caremarkrx.net 25000; 

/* Synchronous (CWAIT=Y) or Asynchronous (CWAIT=N) remote submit */

OPTIONS COMAMID=tcp REMOTE=win_serv CWAIT=&wait; 
%LET  _win_serv=NOSCRIPT; 
SIGNON REMOTE=win_serv USER="caremarkrx\sasadm" PASSWORD=sasadm ;

%MEND;

