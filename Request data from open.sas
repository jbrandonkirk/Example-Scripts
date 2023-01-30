filename resp temp;

/* Neat service from Open Notify project */

proc http
url="http://api.open-notify.org/astros.json"
method= "GET"
out=resp;
run;

/* Assign a JSON library to the HTTP response */
libname space JSON fileref=resp;

/* Print result, dropping automatic ordinal metadata */
title "Who is in space right now? (as of &sysdate)";
proc print data=space.people (drop=ordinal:);
run;