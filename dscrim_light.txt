/******************************************************************************
 * Copyright (c) 2005 by SAS Institute Inc, Cary NC 27511  USA1
 
 * This program is part of the SAS Performance Laboratory repository of
 *   customer programs used to evaluate SAS performance.  The test and
 *   results of test runs are available through the Performance Analysis
 *   Software System (PASS).
 *
 * PASS NAME:    FMM.sas
 * DESCRIPTION:  STAT Performance Litmus Test for PROC DISCRIM  
 *
 * SETUP INSTRUCTIONS: None.
 *
 *
 *   OUTPUT: None.
 *
 * SYSTEM REQUIREMENTS: None.
 *
 * ANTICIPATED RUNTIME:  minutes on Linux R64 (SPL Benchmark Standard).
 * TEST CHARACTERIZATION:  CPU Intensive
 *
 * SAS PRODUCTS INVOLVED:  STAT
 * SAS PROCEDURES INVOLVED: DISCRIM  
 *
 * DATA SOURCE: generated
 * DATA CHARACTERIZATION: N/A 
 *
 * COMMENTS:
 * DISTRIBUTION STATUS:  Internal Only SAS R&D Confidential
 * CONTRIBUTED BY: Cheryl LeSaint
 *
 * HISTORY:
 *   Date       Description                         Who
 *  16 Nov12    Cleaned Up & Added to SPL Suite     Tony
 *   
 ******************************************************************************/

/*******************************************************************************
 *                        PROGRAM SETUP
 * Use this section to alter macro variables, options, or other aspects of the
 * test.  No Edits to this Program are allowed past the Program Setup section!!
 *******************************************************************************/

/*** Set Options Not Covered by PASS MACRO ***/

/* Start timer */
%let _timer_start = %sysfunc(datetime());

/*******************************************************************************
 *                       END OF PROGRAM SETUP
 *******************************************************************************/




  
/* Do NOT edit below this line! */

options fmterr fullstimer source source2 mprint notes;

/*******************************************************************************
 *                        PASS MACRO CODE - DO NOT EDIT
 *  This section controls information printed to the log for performance analysis
 ********************************************************************************/

%macro passinfo;
       data _null_;
            temp=datetime();
            temp2=lowcase(trim(left(put(temp,datetime16.))));
            call symput('datetime', trim(temp2));

            %if ( &SYSSCP = WIN )
            %then call symput('host', "%sysget(computername)");
            %else call symput('host', "%sysget(HOST)");
            ;
            run;

            %put PASS HEADER BEGIN;
            %put PASS HEADER os=&sysscp;
            %put PASS HEADER os2=&sysscpl;
            %put PASS HEADER host=&host;
            %put PASS HEADER ver=&sysvlong;
            %put PASS HEADER date=&datetime;
            %put PASS HEADER parm=&sysparm;

            proc options group=memory; run;
            proc options group=performance; run;
            libname _all_ list; run; 

            %put PASS HEADER END;
%mend passinfo;
%passinfo;
run;

/***************************************************************************
 *                        END OF PASS MACRO CODE
 ***************************************************************************/
     /*** proc discrim ***/;
%macro makeRegressorData(nBy=1,nByFixedSize=1,nObs=2100,nCont=4,
                         nClass=3,nLev1=3,nLev2=5,nLev3=7);
   data testdata;
      drop i j;
      %if &nCont>0  %then %do; array x{&nCont}  x1-x&nCont; %end;
      %if &nClass>0 %then %do; array c{&nClass} c1-c&nClass;%end;

      do by=1 to &nBy;
        if by > &nByFixedSize then
               nObsInBy = floor(2*ranuni(1)*&nObs);
        else nObsInBy = &nObs;
        if nObsInBy < 10 then nObsInBy = 10;

        do i = 1 to nObsInBy;
           %if &nCont>0 %then %do;
              do j= 1 to &nCont;
                 x{j} = ranuni(1);
              end;
           %end;

           %if &nClass > 0 %then %do;
              do j=1 to &nClass;
                      if mod(j,3) = 0 then
                          c{j} = ranbin(1,&nLev3,.6);
                 else if mod(j,3) = 1 then
                          c{j} = ranbin(1,&nLev1,.5);
                 else if mod(j,3) = 2 then
                          c{j} = ranbin(1,&nLev2,.4);
              end;
           %end;

           weight = 1 + ranuni(1);
           freq   = 1 + mod(i,3);

           output;
         end;
       end;
    run;
%mend;
%macro AddDepVar(modelRHS =,errorStd = 1);
   data testdata;
      set testdata;
      y = &modelRHS + &errorStd * rannor(1);
   run;
%mend;

%makeRegressorData(nBy=15,nByFixedSize=1,nObs=2e6,nCont=15,
                         nClass=5,nLev1=1,nLev2=3,nLev3=3);
%AddDepVar(modelRHS=2*c1 - 0.5*x1,errorStd = 1);

ods select Counts;
proc discrim data=testdata all
   s anova manova mah pool=yes canonical posterr list listerr
   out=out outstat=outstat;
   class c3;
   var x1 - x15;
   weight weight;
   freq freq;
   by by;
run;

proc delete data=work.testdata;
proc delete data=work.out;
quit;


/***************************************************************************
 *                         PROGRAM CODE SECTION
 ***************************************************************************/

  /***************************************************************************
 *                      END OF PROGRAM CODE SECTION
 ***************************************************************************/

/* Stop timer */
data _null_;
  dur = datetime() - &_timer_start;
  put 30*'-' / ' TOTAL DURATION:' dur time13.2 / 30*'-';
run;

/***************************************************************************
 *                       END OF TEST
 ****************************************************************************/