/*HEADER-----------------------------------------------------------------------
|
| PROGRAM:  validate_edw_member.sas (macro)
|
| LOCATION: /PRG/sasprod1/hercules/macros
|
| PURPOSE:  This macro will validate and capture contaminated EDW members
|
|
+-------------------------------------------------------------------------------
| HISTORY:  26FEB2009 - Brian Stropich - Hercules Version  2.5.03
|           Original.
|
+-----------------------------------------------------------------------HEADER*/ 

%macro validate_edw_member;

	/*------------------------------------------------*/
	/*  remove initiative from qcpap020 table         */
        /*  if exist.                                     */
	/*------------------------------------------------*/
	PROC SQL;
	  DELETE *
          FROM QCPAP020.HERCULES_MBR_ID_REUSE
	  WHERE INITIATIVE_ID = &INITIATIVE_ID. ;
	QUIT;

	/*------------------------------------------------*/
	/*  create list of member IDs to validate         */
	/*------------------------------------------------*/
	proc sql noprint;
	  create table member_ids as
	  select member_id
	  from &DB2_TMP..t_&INITIATIVE_ID._1_main ;
	quit;

	data member_ids;
	 set member_ids;
	 mbr_id= "'" || TRIM(LEFT(member_id)) || "'";
	run;

	proc sql noprint;
	 drop table v_memeber;
	quit;

	proc sql noprint;
	 select count(*) into :cnt
	 from member_ids;
	quit;

	%put Member ID count: &cnt. ;
	
	%if &cnt. > 0 %then %do;

	%let interval = 500;
	%let firstobs = 1;
	%let lastobs  = &interval. ;

	%let doloop = %eval(%sysfunc(ceil(&cnt/&lastobs)));
	%put NOTE: doloop = &doloop. ;
	%local i;

	/*------------------------------------------------*/
	/*  perform validation of member IDs              */
	/*------------------------------------------------*/
	%do i = &firstobs %to &doloop;

		proc sql noprint;
		 create table member_ids_list as
		 select *
		 from member_ids (firstobs = &firstobs. obs = &lastobs.);
		quit;

		proc sql noprint;
		 select mbr_id into:  mbr_id separated by ','
		 from member_ids_list ;
		quit;

		PROC SQL;
		  CONNECT TO ORACLE(PATH=&GOLD PRESERVE_COMMENTS);
		  create table v_memeber_list as
		  SELECT * FROM CONNECTION TO ORACLE
		  (
			SELECT  MBR_ID as MEMBER_ID,
			        MBR_REUSE_LAST_UPDT_DT
			FROM &DSS_CLIN..V_MBR
			WHERE MBR_ID IN ( &mbr_id.   )
			AND   MBR_REUSE_RISK_FLG = 'Y'
		  ) ;
		  DISCONNECT FROM ORACLE;
		QUIT;

		proc append base = v_memeber 
                    data = v_memeber_list;
		run;

		%let firstobs = %eval(&lastobs + 1);
		%let lastobs  = %eval(&lastobs + &interval.);

	%end;

	proc sort data = v_memeber nodupkey;
	  by member_id;
	run;

	proc sql noprint;
	  select count(*) into: member_count
	  from v_memeber;
	quit;

	%put NOTE:  member_count = &member_count. ;

	%if &member_count. > 0 %then %do;

		proc sort data = &DB2_TMP..t_&INITIATIVE_ID._1_main
		          out  = main;
		  by member_id;
		run;

		/*------------------------------------------------*/
		/*  create main file to load into qcpap020        */
		/*------------------------------------------------*/
		DATA MAIN (RENAME=(RVR_FIRST_NM=MBR_FIRST_NAME
		                   RVR_LAST_NM=MBR_LAST_NAME ));
		  MERGE MAIN	   (IN=A)
		        V_MEMEBER  (IN=B);
		  BY MEMBER_ID;
		  IF A AND B;
		  INITIATIVE_ID=&INITIATIVE_ID.;
		  PROGRAM_ID=&PROGRAM_ID.;
		  TASK_ID=&TASK_ID.;
		  REUSE_DT=MBR_REUSE_LAST_UPDT_DT;
		  MAILING_LEVEL=2;
		  HSC_USER_ID='QCPAP020';
		  KEEP INITIATIVE_ID PROGRAM_ID TASK_ID PT_BENEFICIARY_ID
                       CDH_BENEFICIARY_ID MEMBER_ID RVR_FIRST_NM RVR_LAST_NM 
                       REUSE_DT MAILING_LEVEL HSC_USER_ID;
		RUN;

		PROC SQL;
		  INSERT INTO QCPAP020.HERCULES_MBR_ID_REUSE
		  SELECT 
			    INITIATIVE_ID,
				PROGRAM_ID,
				TASK_ID,
		       	        PT_BENEFICIARY_ID,
				CDH_BENEFICIARY_ID,
				MEMBER_ID,
				MBR_FIRST_NAME,
				MBR_LAST_NAME,
				REUSE_DT,
				MAILING_LEVEL,
				HSC_USER_ID,
				input("&SYSDATE9."||PUT(TIME(),TIME16.6),DATETIME25.6) AS HSU_TS FORMAT=DATETIME25.6
		  FROM  MAIN ;
		QUIT;

	%end;

	%end;

%mend validate_edw_member;
