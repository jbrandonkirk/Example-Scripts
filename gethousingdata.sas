options validvarname=any;

/*START*/
/*Pull data from census.gov : https://www.census.gov/data/developers/data-sets/economic-indicators.html*/

filename resjson temp;

proc http
	url='https://api.census.gov/data/timeseries/eits/resconst?get=cell_value,data_type_code,time_slot_id,error_data,category_code,geo_level_code,seasonally_adj,time_slot_name&time=from+2010'
	method='GET'
	out=resjson;
run;

/* Assign a JSON library to the HTTP response */
libname res_data JSON fileref=resjson;

data temp;
  set res_data.root;
where element1 ^= 'cell_value';
run;

data housing;
  set temp (RENAME= (element2=data_type_code element3=time_slot_id element4=error_data
element5=category_code element6=geo_level_code element7=seasonally_adj element8=time_slot_name element9=time)
);
length cell_value 8.;
cell_value = input(element1,comma9.);
run;
     
proc contents data=housing; run;

/*Copy into cas .*/
		
/*options cashost="<cas host name>" casport=<port number>;*/
cas;
caslib _all_ assign;
/*Location for files on Viya*/
proc casutil incaslib="Public" outcaslib="Public";

	droptable casdata="housing" quiet;
	load data=work.housing casout="housing" promote;
    save casdata="housing" casout="housing" replace;

run;


