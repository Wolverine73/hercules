%*HEADER------------------------------------------------------------------------
| MACRO: cr_fmt_vars
|
| LOCATION: /PRG/sas%lowcase(&SYSMODE)1/hercules/macros
|
| USAGE: cr_fmt_vars(format name, in dataset, key column one, key column two,
|                    label column)
|
| Eg. %cr_fmt_vars($_hercf,_LOAD_FMT_1,COLUMN_NM,CMCTN_ENGINE_CD,COLUMN_TX)
|
| PURPOSE:  This macro creates a concatenated format (_FMT_NM) from
|    key column one and key column two, labeled with label column.
|
| LOGIC:    (1) Determine the maximum length of the key columns.
|
|           (2) Create the format cntlin dataset.
|
|           (3) Insert rows with key column format attributes into
|               the format cntlin dataset.
|
|           (4) Sort cntlin dataset by key value.
|
|           (5) Assemble concatenated format.
|
|           (6) Drop temporary table cntlin dataset.
|
|
| INPUT:    _FMT_NM  format name
|           _IN_DSN  dataset containing columns to be formatted
|           _C_1     key column one name of concatenated key
|           _C_2     key column two name of concatenated key
|           _LABEL   label column associated with concatenated key
|
| OUTPUT:   _FMT_NM  format
+--------------------------------------------------------------------------------
| HISTORY:  28AUG2003 - L.Kummen  - Original
+------------------------------------------------------------------------HEADER*;
%macro cr_fmt_vars(_FMT_NM,_IN_DSN,_C_1,_C_2,_LABEL);
%* create macro variables for maximum format length.;
%local _MAX_C_1_FMT_LN _MAX_C_2_FMT_LN;
proc sql noprint;
select compress("$"||put(max(length(&_C_1)),8.)||"."),
       compress("Z"||put(length(input(put(max(&_C_2),32.),$32.)),8.)||".")
  into :_MAX_C_1_FMT_LN, :_MAX_C_2_FMT_LN
  from &_IN_DSN;

%* create format control-in data.;
create table _CNTLIN as
select "&_FMT_NM" as FMTNAME,
       'C' as TYPE,
       input(&_C_1,&_MAX_C_1_FMT_LN)||
       put(&_C_2,&_MAX_C_2_FMT_LN) as START,
       &_LABEL as LABEL label='LABEL'
  from &_IN_DSN
%* insert rows for key column missing formats.;
%* where missing values do not exist.         ;
union corr
select distinct "&_FMT_NM" as FMTNAME,
       'C' as TYPE,
       input(&_C_1,&_MAX_C_1_FMT_LN) as START,
       "" as LABEL label='LABEL'
  from &_IN_DSN
 where &_C_2 not in (select &_C_2
                      from &_IN_DSN
                     where &_C_2 eq .);

%* insert rows for key column formats.;
insert into _CNTLIN
   (FMTNAME, TYPE, START, LABEL)
values
   ("&_FMT_NM", 'C', '_C_1', "&_MAX_C_1_FMT_LN")
values
   ("&_FMT_NM", 'C', '_C_2', "&_MAX_C_2_FMT_LN");

%* sort rows for cntlin database.;
create table _CNTLIN as
select FMTNAME,
       TYPE,
       START,
       LABEL
  from _CNTLIN
 order by START;
quit;

%* assemble concatenated format.;
proc format
   cntlin=_CNTLIN;
run;

%* drop _temporary tables.;
proc sql noprint;
drop table
  _CNTLIN;
quit;
%mend cr_fmt_vars;
