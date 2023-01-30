filename current temp;

/* Neat service from Open Notify project */

proc http
url="http://api.weatherstack.com/current?access_key=daad60d5039e3b277dfe00cb1d5cdc49&units=f&query=Raleigh"
method= "GET"
out=current;
run;

/* Assign a JSON library to the HTTP response */
libname weather JSON fileref=current;

data current;
 set weather.current;
run;
data current_weather_descriptions;
 set weather.current_weather_descriptions;
run;
data location;
 set weather.location;
run;


proc sql;
  create table combined as 
    select t1.temperature, t1.wind_speed, t1.feelslike, t2.weather_descriptions1, t3.name 
      from work.current t1
		left join work.current_weather_descriptions t2
				on t1.ordinal_current = t2.ordinal_current
        left join work.location t3
                on t1.ordinal_root = t3.ordinal_root;
quit;


/* Print result, dropping automatic ordinal metadata  */
title "What is the weather right now? (as of &sysdate)";
proc print data=work.combined ;
run;