
filename Orapi temp;

/* Neat service from Open Notify project */

proc http
url=""
method= "GET"
out=orionapi;
run;

/* Assign a JSON library to the HTTP response */
libname oriapi JSON fileref=orionapi;

/* Print result, dropping automatic ordinal metadata  */
title "What is the result? (as of &sysdate)";
proc print data=oriapi.alldata (keep= contact_id);
run;