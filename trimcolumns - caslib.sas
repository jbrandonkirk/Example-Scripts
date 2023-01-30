/**********************************************************************/
/*STEP 1 - Select caslib                                              */
/**********************************************************************/
%let caslib = Alliances (DNFS);
%let size_threshhold = 1; /*In GB*/
%let run_mode = Normal; /*Debug (will not copy trimmed tables back to cas), Normal*/

cas casauto cassessopts=(caslib="&caslib.");
libname ln_cas cas caslib="&caslib" datalimit=all;
%let clean_caslib = %substr(%sysfunc(compress(&caslib,'- ()&')),1,%length(%sysfunc(compress(&caslib,'- ()&'))));

/**********************************************************************/
/*STEP 2 - Gather info on files and tables for selected caslib        */
/**********************************************************************/

/*STEP 2a - Get all sashdat file info in selected caslib*/
ods output CAS.fileInfo.FileInfo=FileInfo;
proc cas;
	session casauto;
	table.fileInfo /
	kbytes=true;
quit;
ods _ALL_ CLOSE;
data FileInfo(keep='name'n size);
	set FileInfo;
run;


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
/*STEP 3 - Identify large tables (>1GB) and prep for trimming step.   */
/**********************************************************************/

/*STEP 3a - Create a list that contains all sashdat's that are over 1GB*/
data BigFiles_st;
	set FileInfo;
	/*size is in KBs*/
	if size > 1024 /*MBs*/ *1024 /*GBs*/ * &size_threshhold;
run;

/*STEP 3b - Create a list that contains all sashdat's (>1GB) that aren't loaded to memory*/
proc sql;
	create table BigFiles_To_Be_Loaded as
	select a.'name'n,
			scan(a.'name'n,1) as TableName,
			a.size,
			b.rows,
			b.columns,
			b.sourcename
	from BigFiles_st a
	left join TableInfo b
		on upcase(scan(a.'name'n,1))=upcase(scan(b.'name'n,1))
	where b.rows =.
;
quit;

/*STEP 3c - Load unloaded sashdats from above*/
%macro loadTableToCAS(fileName=,tableName=);

proc cas;
   session casauto;
   
   table.loadTable /           
      path="&fileName"
      casout={name="&tableName"};
run;
quit;
%mend;

filename in_load temp;
data _NULL_;
	set BigFiles_To_Be_Loaded;
	file in_load lrecl=100;
	executeMe = '%loadTableToCAS(fileName='||trim(Name)||',tableName='||trim(TableName)||');';
	put @1 executeMe;
run;
%include in_load;


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
	set BigFiles_st;
	file in_trim lrecl=100;
	executeMe = '%trimcolumns(in=ln_cas.'||trim(scan(Name,1))||',out='||trim(scan(Name,1))||');';
	put @1 executeMe;
run;
%include in_trim;


/**********************************************************************/
/*STEP 5 - Gather stats on tables.                                    */
/**********************************************************************/
data trim_&clean_caslib;
	length libname memname name $100.
			length noobs type 8.;
run;

%macro gather_stats(before_table=,after_table=);

	proc contents 
		data=&before_table 
		noprint
		out=contents1;
	run;

	proc sql;
		insert into trim_&clean_caslib
		select libname, memname, name, length, nobs, type
		from contents1;
	quit;

	proc contents 
		data=&after_table
		noprint
		out=contents2;
	run;

	proc sql;
		insert into trim_&clean_caslib
		select libname, memname, name, length, nobs, type
		from contents2;
	quit;

	cas;
	proc casutil incaslib="Public" outcaslib="Public";
		droptable casdata="trim_&clean_caslib" quiet;
		load data=work.trim_&clean_caslib casout="trim_&clean_caslib" promote;
	    save casdata="trim_&clean_caslib" casout="trim_&clean_caslib" replace ;
	run;

%mend;

filename in_stats temp;
data _NULL_;
	set BigFiles_st;
	file in_stats lrecl=255;
	executeMe = '%gather_stats(before_table='||"ln_cas."||trim(scan(Name,1))||',after_table='||trim(scan(Name,1))||')';
	put @1 executeMe;
run;
%include in_stats;

proc sql;
	delete from trim_&clean_caslib
	where memname = '';
quit;



/**********************************************************************/
/*STEP 6 - Copy tables back to CAS if not in DEBUG.                   */
/**********************************************************************/
%macro copy_table_to_cas(caslib=,tableName=);
	proc casutil incaslib="&caslib" outcaslib="&caslib";
		droptable casdata="&tableName" quiet;
		load data=work.&tableName. casout="&tableName" promote;
	    save casdata="&tableName" casout="&tableName" replace ;
	run;
%mend;

filename in_copy temp;
data build_chk_tables;
	set BigFiles_st;
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