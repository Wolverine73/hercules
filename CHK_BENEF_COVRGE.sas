proc sql;
     connect to db2 (dsn=&udbsprp);
     create table temp as
     select * from connection to db2
    ( SELECT e.*,  D.PT_BENEFICIARY_ID,
                                  max(CASE
                                         WHEN A.DELIVERY_SYSTEM_CD = 3 THEN PB_ID
                                         ELSE 0
                                      END) AS POS_PB,
                                  max(CASE
                                        WHEN A.DELIVERY_SYSTEM_CD = 2 THEN PB_ID
                                        ELSE 0
                                     END) AS MAIL_PB
                           FROM &claimsa..TCPG_PB_TRL_HIST  A,
                                &CLAIMSA..TELIG_DETAIL_HIS D,
                                &claimsa..TCPGRP_CLT_PLN_GR1  E
                           WHERE D.CLT_PLAN_GROUP_ID = A.CLT_PLAN_GROUP_ID
                           AND   D.CLT_PLAN_GROUP_ID = E.CLT_PLAN_GROUP_ID
                           AND   D.PT_BENEFICIARY_ID IN (33559348, 26135682)
                           AND   A.EXP_DT > CURRENT DATE -20 DAYS
                           AND   A.EFF_DT < CURRENT DATE -20 DAYS
                           AND   (CURRENT DATE -20 DAYS) BETWEEN D.EFFECTIVE_DT AND D.EXPIRATION_DT
                           AND   A.DELIVERY_SYSTEM_CD IN (2,3)
                        GROUP BY D.PT_BENEFICIARY_ID, e.client_id, e.clt_plan_group_id,
                              e.plan_cd, e.plan_extension_cd,
                              e.group_cd, e.group_extension_cd,
                              e.blg_reporting_cd,
                              e.plan_group_nm);
      DISCONNECT FROM DB2; QUIT;
