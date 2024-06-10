%*HEADER------------------------------------------------------------------------
| MACRO: add_fmt_vars
|
| LOCATION: /PRG/sas%lowcase(&SYSMODE)1/hercules/macros
|
| USAGE: add_fmt_vars(format name, in dataset, out dataset, column prefix,
|                     list of columns to format)
|
| Eg. %add_fmt_vars($_hercf, _TABLE_1, _F_TABLE_1, F_,
|                   PROGRAM_ID,
|                   TASK_ID,
|                   CMCTN_ROLE_CD,
|                   DATA_CLEANSING_CD,
|                   FILE_USAGE_CD,
|                   DESTINATION_CD,
|                   RELEASE_STATUS_CD)
|
| PURPOSE:
|    This macro creates new columns in the out dataset by using concatenated
|    keys to format columns in the in dataset. The column prefix is used to
|    preface the names from the list of columns to format.
|
| LOGIC:    (1) Create macro variables for the maximum column widths of
|               the concatenated keys.
|
|           (2) Create an output dataset by formatting the listed columns
|               using the concatenated key columns. The concatenated key is
|               a composite of the variable name and ordinal value.
|
| INPUT:    _FMT_NM  format name
|           _IN_DSN  dataset containing columns to be formatted
|           _OUT_DSN dataset name
|           _PRFX    prefix of new columns
|           PBUFF    list of columns to be formatted appended to above arguments
|
| OUTPUT:   _OUT_DSN dataset containing new formatted columns
+--------------------------------------------------------------------------------
| HISTORY:  28AUG2003 - L.Kummen  - Original
+------------------------------------------------------------------------HEADER*;
%macro add_fmt_vars(_FMT_NM,_IN_DSN,_OUT_DSN,_PRFX)/PBUFF;
%local _C_1_FMT _C_2_FMT _DS_ID _SORTEDBY _RC _NUM _CUR_VAR;

%* Create macro variables for maximum key column format length. *;
%let _C_1_FMT  =%sysfunc(compress(%sysfunc(putc(_C_1,&_FMT_NM..))));
%let _C_2_FMT  =%sysfunc(compress(%sysfunc(putc(_C_2,&_FMT_NM..))));

%* Create macro variable for sortedby attribute. *;
%let _DS_ID   =%sysfunc(open(&_IN_DSN, I ));
%let _SORTEDBY=%sysfunc(attrc(&_DS_ID, SORTEDBY));
%let _RC      =%sysfunc(close(&_DS_ID));

%* Parse the buffer beginning with the fifth argument. *;
%let _NUM=5;

%* _CUR_VAR is the current variable to be formatted from the variable list. *;
%let _CUR_VAR=%scan(&SYSPBUFF,&_NUM,%str(',)'));
data &_OUT_DSN;
   set &_IN_DSN;
   by &_SORTEDBY;
   %* Loop through the variable list;
   %do %while(%str(&_CUR_VAR) ne %str());
      %* Preface the current variable name and assign the value of the *;
      %* formatted concatenated key (varible name and ordinal value).  *;
      &_PRFX.&_CUR_VAR=put(input(vname(&_CUR_VAR),&_C_1_FMT)||
                       put(&_CUR_VAR,&_C_2_FMT),&_FMT_NM..);
      %let _NUM=%eval(&_NUM+1);
      %let _CUR_VAR=%scan(&SYSPBUFF,&_NUM,%str(',)'));
   %end;
run;

%mend add_fmt_vars;
