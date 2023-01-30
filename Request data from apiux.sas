
filename current temp;

/* Neat service from Open Notify project */

proc http
url="http://api.apixu.com/v1/current.json?key=fc37f214a01c4a6c933184148170105&q=Raleigh"
method= "GET"
out=current;
run;

/* Assign a JSON library to the HTTP response */
libname weather JSON fileref=current;

/* Print result, dropping automatic ordinal metadata  */
title "What is the weather right now? (as of &sysdate)";
proc print data=weather.current (keep= temp_f wind_mph wind_dir feelslike_f);
run;


filename forecast temp;

/* Neat service from apixu */

proc http
url="http://api.apixu.com/v1/forecast.json?key=fc37f214a01c4a6c933184148170105&q=Raleigh&days=5"
method= "GET"
out=forecast;
run;

/* Assign a JSON library to the HTTP response */
libname weather2 JSON fileref=forecast;

/* Print result, dropping automatic ordinal metadata */ 
title "What is the weather going to be? (as of &sysdate)";
proc print data=weather2.forecastday_day (drop=ordinal:);
run;







