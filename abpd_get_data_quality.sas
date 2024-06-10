/*HEADER-----------------------------------------------------------------------
| MACRO: abpd_get_data_quality
|
| LOCATION: /PRG/sas%lowcase(&SYSMODE)1/hercules/macros
|
| USAGE: get_data_quality(TBL_NAME_IN =SAS input dataset,
|                         TBL_NAME_OUT=SAS output dataset)
|
| Eg. %get_data_quality(TBL_NAME_IN =    WORK.T_29_1_2,
|                       TBL_NAME_OUT=DATA_PND.T_29_1_2)
|
| PURPOSE:
|    This macro adds the DATA_QUALITY_CD column to a SAS dataset.
|    The macro uses the edit strings contained in TDATA_QUALITY_EDIT_CD
|    to validate whether an name/address has no edit (1), soft edit (2),
|    or hard edit (3).
|
+------------------------------------------------------------------------------
|
+----------------------------------------------------------------------HEADER*/
%macro abpd_get_data_quality(TBL_NAME_IN=, TBL_NAME_OUT=);

%*SASDOC------------------------------------------------------------------------
| 13aug2008 - SR - Added logic to partition the input dataset into 
| 25000 observations at a time
+-----------------------------------------------------------------------SASDOC*;
proc sql;
 select count(*) into :cnt
 from &TBL_NAME_IN.;
 quit;

%let firstobs = 1;
%let lastobs = 25000;

%if %sysfunc(exist(&TBL_NAME_OUT.)) %then %do;
proc sql;
 drop table &TBL_NAME_OUT.;
quit;
%end;

%let doloop = %eval(%sysfunc(ceil(&cnt/&lastobs)));

%LOCAL i;

%do i = &firstobs %to &doloop;

proc sql noprint;
create table datpart&i as
select  B.DATA_QUALITY_CD, A.*
%*SASDOC------------------------------------------------------------------------
| DATA_QUALITY_CD is added to each row of the SAS input file by Recipient.
| B.DATA_QUALITY_CD is selected BEFORE A.* so DATA_QUALITY_CD will be replaced
| (if it is a column on TBL_NAME_IN).
+-----------------------------------------------------------------------SASDOC*;
from    &TBL_NAME_IN (firstobs = &firstobs. obs = &lastobs.) as A left join
       (
        select  A.RECIPIENT_ID
%*SASDOC------------------------------------------------------------------------
| The maximum DATA_QUALITY_CD is found for each Recipient.
+-----------------------------------------------------------------------SASDOC*;
               ,max(case (A.ZIP_CD is NULL)
%*SASDOC------------------------------------------------------------------------
| If the Zip Code field of the SAS input dataset is missing (null) then
|    DATA_QUALITY_CD is 3 (hard edit - reject)
+-----------------------------------------------------------------------SASDOC*;
                       when (1) then 3
                       else
%*SASDOC------------------------------------------------------------------------
| When RESULT_IN is 'H' then DATA_QUALITY_CD is 3 (hard edit - reject)
|      RESULT_IN is 'S' then DATA_QUALITY_CD is 2 (soft edit - review)
| else (If an Edit String does not match an address field)
|                            DATA_QUALITY_CD is 1 (No Edit - passes all edit checks)
|
|   cjs 03MAR2008 added address3_tx to the select statement
+-----------------------------------------------------------------------SASDOC*;
                          case (B.RESULT_IN)
                            when ('S') then 2
                            when ('H') then 3
                            else 1
                         end
                    end) as DATA_QUALITY_CD
        from    (
                select distinct  RECIPIENT_ID, ZIP_CD, RVR_FIRST_NM, RVR_LAST_NM
                                ,ADDRESS1_TX, ADDRESS2_TX ,CITY_TX ,STATE,ADDRESS3_TX
                from   &TBL_NAME_IN (firstobs = &firstobs. obs = &lastobs.)
                )
                as A left join
                &CLAIMSA..TDATA_QLTY_EDIT_CD as B
%*SASDOC------------------------------------------------------------------------
| The CLAIMSA.TDATA_QUALITY_EDIT_CD edit must be within the effective date range.
+-----------------------------------------------------------------------SASDOC*;
        on     (B.EFFECTIVE_DT  <= today()
                and
                B.EXPIRATION_DT >= TODAY())
         and   (case (B.EDIT_RLTNSHP_CD)
%*SASDOC------------------------------------------------------------------------
| When the value of EDIT_RLTNSHP_CD is 1 then
|    Edit String should be matched as an excerpt within the name/address field.
|    when there is a match a numeric value is passed and used to determine data quality code
|
|    03MAR2008 CJS added case 8 and 7 for address3 and zip code 
+-----------------------------------------------------------------------SASDOC*;
                  when 1 then
                     case (B.FIELD_NM_CD)
                        when (1) then index(A.RVR_FIRST_NM, trim(left(B.EDIT_STRING_TX)))
                        when (2) then index(A.RVR_LAST_NM,  trim(left(B.EDIT_STRING_TX)))
                        when (3) then index(A.ADDRESS1_TX,  trim(left(B.EDIT_STRING_TX)))
                        when (4) then index(A.ADDRESS2_TX,  trim(left(B.EDIT_STRING_TX)))
                        when (5) then index(A.CITY_TX,      trim(left(B.EDIT_STRING_TX)))
                        when (6) then index(A.STATE,        trim(left(B.EDIT_STRING_TX)))
                        when (7) then index(A.zip_cd,       trim(left(B.EDIT_STRING_TX)))
                        when (8) then index(A.address3_tx,  trim(left(B.EDIT_STRING_TX)))
                      else 0
                     end
%*SASDOC------------------------------------------------------------------------
| When the value of EDIT_RLTNSHP_CD is 2 then
|    Edit String should be exactly matched with the name/address field.
|    when there is a match a numeric value is passed and used to determine data quality code
|
|    03MAR2008 CJS added case 8 and 7 for address3 and zip code 
+-----------------------------------------------------------------------SASDOC*;
                  when 2 then
                     case (B.FIELD_NM_CD)
                        when (1) then A.RVR_FIRST_NM = B.EDIT_STRING_TX
                        when (2) then A.RVR_LAST_NM  = B.EDIT_STRING_TX
                        when (3) then A.ADDRESS1_TX  = B.EDIT_STRING_TX
                        when (4) then A.ADDRESS2_TX  = B.EDIT_STRING_TX
                        when (5) then A.CITY_TX      = B.EDIT_STRING_TX
                        when (6) then A.STATE        = B.EDIT_STRING_TX
                        when (7) then A.zip_cd       = B.EDIT_STRING_TX
                        when (8) then A.address3_tx  = B.EDIT_STRING_TX
                        else 0
                     end
                     else 0
               end ne 0)
        group by RECIPIENT_ID) as B
on      (A.RECIPIENT_ID eq B.RECIPIENT_ID);
quit;

proc append base = &TBL_NAME_OUT data=datpart&i;
run;quit;

%let firstobs = %eval(&lastobs + 1);
%let lastobs = %eval(&lastobs + 25000);

proc sql;
 drop table datpart&i;
quit;

%end;

%mend abpd_get_data_quality;
