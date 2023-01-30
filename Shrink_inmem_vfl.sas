
cas;
caslib _all_ assign;


/**********************************************************************/
/*STEP 1 - Select caslib                                              */
/**********************************************************************/
%let caslib = ROSI35 ;
%let size_threshhold = 1; /*In GB*/
%let run_mode = Normal; /*Debug (will not copy trimmed tables back to cas), Normal*/

cas casauto cassessopts=(caslib="&caslib.");
libname ln_cas cas caslib="&caslib" datalimit=all;
%let clean_caslib = %substr(%sysfunc(compress(&caslib,'- ()&')),1,%length(%sysfunc(compress(&caslib,'- ()&'))));

/**********************************************************************/
/*STEP 2 - Gather info on files and tables for selected caslib        */
/**********************************************************************/

/*STEP 2b - Get all in-memory table info in selected caslib*/
ods output CAS.tableinfo.TableInfo=TableInfo;
proc cas;
	session casauto;
	table.tableInfo;
quit;
ods _ALL_ CLOSE;
data TableInfo(keep='name'n rows columns sourcename);
	set TableInfo;
run;


/**********************************************************************/
/*STEP 4 - Trimmed and identified tables.                             */
/**********************************************************************/

%macro trimcolumns(in=,out=);
	options varlenchk=nowarn;

	%if %sysfunc(countw(&in,"."))=2 %then %do;
		%let libname = %scan(&in,1,".");
		%let memname = %scan(&in,2,".");
		%end;
	%else %do;
		%let libname = work;
		%let memname = &in;
		%end;

	proc sql noprint;
 	     select count(*) into :nobs from &in;
		 select count(*) into :ncharVar from sashelp.vcolumn where upcase(libname)=upcase("&libname") and upcase(memname)=upcase("&memname") and upcase(type)="CHAR";
	quit;

     %if &nobs > 0 and &ncharVar > 0 %then %do;
		  data _null_;
		       set &in;
		       array qqq(*) _character_;
		       call symput('siz',put(dim(qqq),5.-L));
		       stop;
		 run;

		 data _null_;
		       set &in end=done;
		       array qqq(&siz) _character_;
		       array www(&siz.);
		       if _n_=1 then do i= 1 to dim(www);
		       www(i)=0;
		       end;
		       do i = 1 to &siz.;
		       www(i)=max(www(i),length(qqq(i)));
		       end;
		       retain _all_;
		       if done then do;
		       do i = 1 to &siz.;
		            length vvv $50;
		            vvv=catx(' ','length',vname(qqq(i)),'$',www(i),';');
		            fff=catx(' ','format ',vname(qqq(i))||' '||
		       		compress('$'||put(www(i),5.)||'.;'),' ');
		            call symput('lll'||put(i,5.-L),vvv) ;
		            call symput('fff'||put(i,5.-L),fff) ;
		       end;
		       end;
		 run;

		 data &out(compress=yes);
		       %do i = 1 %to &siz.;
		       &&lll&i
		       &&fff&i
		       %end;
		 set &in;
		 run;
	 %end;
	 %else %do;
		data &out(compress=yes);
			set &in;
		run;
	 %end;

	options varlenchk=warn;

%mend;

/*STEP 4a - Trim tables*/
filename in_trim temp;
data build_chk_tables;
	set tableinfo;
	file in_trim lrecl=100;
	executeMe = '%trimcolumns(in=ln_cas.'||trim(scan(Name,1))||',out='||trim(scan(Name,1))||');';
	put @1 executeMe;
run;
%include in_trim;



/**********************************************************************/
/*STEP 6 - Copy tables back to CAS if not in DEBUG.                   */
/**********************************************************************/
%macro copy_table_to_cas(caslib=,tableName=);
	proc casutil incaslib="&caslib" outcaslib="&caslib";
		droptable casdata="&tableName" quiet;
		load data=work.&tableName. casout="&tableName" promote;
	run;
%mend;

filename in_copy temp;
data build_chk_tables;
	set tableinfo;
	file in_copy lrecl=255;
	if symget('run_mode')='Debug' then do;
		executeMe = '%PUT Running in Debug mode, not copying '||trim(scan(Name,1))||' to CAS.;';
		end;
	if symget('run_mode')='Normal' then do;
		executeMe = '%copy_table_to_cas(caslib='||"&caslib"||',tableName='||trim(scan(Name,1))||');';
		end;
	put @1 executeMe;
run;

%include in_copy;