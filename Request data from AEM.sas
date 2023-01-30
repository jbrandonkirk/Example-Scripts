/*
filename testit temp;
proc http
WEBUSERNAME="aem_data_pull"
WEBPASSWORD="!!67gjdk"
url="http://aemauthor.unx.sas.com/content/usergenerated/sascom/en_us/offers/15q1/data-mining-from-a-z-104937.1.json"
method= "GET"
out=testit;
run;
libname aemtoke JSON fileref=testit;

It takes basic authentication

Username: aem_data_pull
Password: !!67gjdk

You now have read access to ‘/content/usergenerated’ and below.
*/

%set_library(EDWSRCE);

/* Macro that simply echoes the contents of a fileref to the SAS log */ 
%macro echofile(file); 
 data _null_;  
 infile &file;  
 input;  
 put _infile_; 
run; 

%mend; 

/* http://aemauthor.unx.sas.com/content/usergenerated/sascom/en_us/offers/15q1/data-mining-from-a-z-104937/1460397752131_887.json 
*/
filename AEMresp temp;

/* Request data from AEM */
proc http
WEBUSERNAME="aem_data_pull"
WEBPASSWORD="!!67gjdk"
url="http://aemauthor.unx.sas.com/content/usergenerated/sascom/en_us/offers/15q1/data-mining-from-a-z-104937.1.json"
method= "GET"
out=AEMresp;
run;

/*%echofile(AEMresp);*/

/* Assign a JSON library to the HTTP response */
libname aem JSON fileref=AEMresp;

libname aempath '/nas/dept/mis/BITeam/GDPR';

proc copy in=aem out=aempath; run;



%set_library(VALAND);

/* Print result 
title "What did we get back? (as of &sysdate)";
proc print data=aem.table;
run;*/