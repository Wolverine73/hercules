/*HEADER------------------------------------------------------------------------
|MACRO: abpd_create_base_file
|
| PURPOSE:
|                        Create Pending SAS dataset specific to abpd process in both the pending and
|                        results directories beneath the appropriate HERCULES Program.
|
|LOGIC:                   
|PARAMETERS:             Global macro variables: defined in hercules_in 
|			 Program_ID, Task_ID,Initiative_ID, Phase_Seq_Nb.
|                         LIBNAME DATA_PND 
|			 LIBNAME DATA_RES 
|  			 LIBNAME DATA_ARC 
|                        
|
|USAGE EXAMPLE: %abpd_create_base_file();
|
| TABLE USED : &HERCULES..TPHASE_RVR_FILE
               &HERCULES..TFILE_BASE_FIELD
|              &HERCULES..TFIELD_DESCRIPTION
|INPUT : TEMPORARY DATASET 
|
|OUTPUT : PENDING SASDATASET
|	   
| Hercules Version  1.0
| 
+-------------------------------------------------------------------------------------HEADER*/
%macro abpd_create_base_file(TBL_NAME_IN= ) ;;

 

%LET TBL_NAME_OUT_SH_MAIN=T_&INITIATIVE_ID._&PHASE_SEQ_NB._&CMCTN_ROLE_CD;

 

*** reference release file macro ***;

 

      
      %*SASDOC=================================================================;

      %* Retrieve file characteristics from &HERCULES..TPHASE_RVR_FILE and store

      %* in macro variables for conditional processing later in this macro.

      %*================================================================SASDOC* ;


      	/* GET CMCTN_ROLE_CD AND FILE_ID */
      	DATA WORK.TPHASE_RVR_FILE;
		SET &HERCULES..TPHASE_RVR_FILE(WHERE=( INITIATIVE_ID=&INITIATIVE_ID
						    AND PHASE_SEQ_NB=&PHASE_SEQ_NB))
						    END=LAST;
		KEEP CMCTN_ROLE_CD FILE_ID;
	RUN;
 	DATA _NULL_;
		SET WORK.TPHASE_RVR_FILE;
		CALL SYMPUT('CMCTN_ROLE_CD' , TRIM(LEFT(CMCTN_ROLE_CD)));
		CALL SYMPUT('FILE_ID' , TRIM(LEFT(FILE_ID)));
	RUN;

 
       **FETCHING THE REQUIRED FIELD FORM HERCULES TABLES** ;
       PROC SQL NOPRINT;
       	      CONNECT TO DB2 AS DB2(DSN=&UDBSPRP.);
		      CREATE   TABLE WORK.REQUIRED_FIELDS  AS
		      SELECT * FROM CONNECTION TO DB2
		      (
		      SELECT FDES.FORMAT_SAS_TX, FDES.FIELD_NM 
		      FROM     
			(SELECT 
				BASE.FIELD_ID,
				BASE.SEQ_NB,
				BASE.SEQ_NB AS NEW_SEQ_NB
				FROM   &HERCULES..TFILE_BASE_FIELD  AS BASE
			UNION 
			SELECT 
				FLDS0.FIELD_ID,
				FLDS0.SEQ_NB,
				(FLDS0.SEQ_NB + 1000) AS NEW_SEQ_NB
				FROM  &HERCULES..TFILE_FIELD AS FLDS0 WHERE FILE_ID=&FILE_ID) AS FLDS,
			&HERCULES..TFIELD_DESCRIPTION   AS   FDES
			WHERE 
			FDES.FIELD_ID=FLDS.FIELD_ID
			ORDER BY FLDS.NEW_SEQ_NB);
		DISCONNECT FROM DB2;
		

    	QUIT;



	** CREATE TEMPLATE ;
	DATA _NULL_;
	  SET WORK.REQUIRED_FIELDS END=EOF;
	  I+1;
	  II=LEFT(PUT(I,4.));
	  CALL SYMPUT('FIELD_NM'||II,TRIM(FIELD_NM));
	  CALL SYMPUT('FORMAT_SAS_TX'||II,TRIM(FORMAT_SAS_TX));
	  IF EOF THEN CALL SYMPUT('XREFTOTAL',II);
	RUN;


	DATA TEMPLATE;
	FORMAT %DO I = 1 %TO &XREFTOTAL. ;
				&&FIELD_NM&I &&FORMAT_SAS_TX&I 
	%END;;
	
	IF PROGRAM_ID=. THEN DELETE;
	
	RUN;

	** APPEND DATA AND ASSIGN VARIABLES;
	DATA _NULL_;
	SET aux_tab.ABPD_XREFERENCE (WHERE=(HERCULESVARS NE ABPDVARS)) END=EOF;
		I+1;
		II=LEFT(PUT(I,4.));
		CALL SYMPUT('HERCULESVARS'||II,TRIM(HERCULESVARS));
		CALL SYMPUT('ABPDVARS'||II,TRIM(ABPDVARS));
		IF EOF THEN CALL SYMPUT('HERCULESTOTAL',II);
	RUN;


	** CREATE PENDING DATASET ;
	DATA &TBL_NAME_OUT_SH_MAIN.;
	SET TEMPLATE ABPD_TEMP_DATA_&K (where=(program_id=&&PID&J));
		%DO I = 1 %TO &HERCULESTOTAL. ;
			&&HERCULESVARS&I =&&ABPDVARS&I ;
		%END;
		IF ADJ_ENGINE = 'RC' THEN DO;
			ADJ_ENGINE='RX';
/*		  CLIENT_ID ='';*/
			PLAN_CD_TX =''; 
			GROUP_CLASS_CD='';		
			GROUP_CLASS_SEQ_NB='';
			INSURANCE_CD=''; 
			CARRIER_ID=CLIENT_LEVEL_1;
			ACCOUNT_ID=CLIENT_LEVEL_2;
			GROUP_CD=CLIENT_LEVEL_3;
			GROUP_CD_TX=CLIENT_LEVEL_3;
		END;
		ELSE IF ADJ_ENGINE = 'RE' THEN DO;
/*		  CLIENT_ID ='';*/
			PLAN_CD_TX =''; 
			GROUP_CLASS_CD='';		
			GROUP_CLASS_SEQ_NB='';
			ACCOUNT_ID='';
			INSURANCE_CD=CLIENT_LEVEL_1;    
			CARRIER_ID=CLIENT_LEVEL_2;
			GROUP_CD=CLIENT_LEVEL_3;
			GROUP_CD_TX=CLIENT_LEVEL_3;
		END;
		ELSE IF ADJ_ENGINE = 'QL' THEN DO;
			INSURANCE_CD='';    
			CARRIER_ID='';
			GROUP_CD='';	
			ACCOUNT_ID='';
			CLIENT_ID =CLIENT_LEVEL_1;
			PLAN_CD_TX =CLIENT_LEVEL_2;
			GROUP_CD_TX=CLIENT_LEVEL_3; 
			If GROUP_CLASS_CD=. Then GROUP_CLASS_CD=0;			
			If GROUP_CLASS_SEQ_NB=. Then GROUP_CLASS_SEQ_NB=0;
		END;
/*		IF missing(QL_BENEFICIARY_ID) or QL_BENEFICIARY_ID=. THEN DO;		*/
/*		    RECIPIENT_ID = 999999;		*/
/*		END;*/
		
	RUN;
	
    %ABPD_GET_DATA_QUALITY(TBL_NAME_IN = WORK.&TBL_NAME_OUT_SH_MAIN.,
	  TBL_NAME_OUT=DATA_PND.&TBL_NAME_OUT_SH_MAIN.);


	proc contents data = DATA_PND.&TBL_NAME_OUT_SH_MAIN 
		      out  = check_phone_var noprint;
	run;

	PROC SQL NOPRINT;
	 SELECT COUNT(*) INTO: check_phone_var
	 FROM  check_phone_var
	 WHERE UPCASE(NAME) CONTAINS 'PHY_TOLL_FREE_NUM';
	QUIT;

	%put NOTE: check_phone_var = &check_phone_var. ;

/*	%if &check_phone_var. > 0 %then %do;*/
/**/
/*		**UPDATING PHY TOLL FREE NUM** ;*/
/*		PROC SQL ;*/
/*			UPDATE DATA_PND.&TBL_NAME_OUT_SH_MAIN A SET PHY_TOLL_FREE_NUM =*/
/*			(SELECT B.PHY_TOLL_FREE_NUM FROM AUX_TAB.ABPD_TGAM_TOLL_FREE B*/
/*			WHERE A.PROGRAM_ID=B.PROGRAM_ID)*/
/*			 ;*/
/*		 QUIT ;*/
/*	%end;*/

   ** ASSIGN SUBJECT_ID ;
	DATA DATA_PND.&TBL_NAME_OUT_SH_MAIN.;
	 	SET DATA_PND.&TBL_NAME_OUT_SH_MAIN. ;
    SUBJECT_ID=RECIPIENT_ID;
    LTR_RULE_SEQ_NB=1;
	RUN;
	 ** CREATE RESULTS DATASET ;
	DATA DATA_RES.&TBL_NAME_OUT_SH_MAIN.;
	 	SET DATA_PND.&TBL_NAME_OUT_SH_MAIN. ;
	RUN;

%MEND ABPD_CREATE_BASE_FILE;
