-- remove the function without retrun code to be able to create the new one
DROP FUNCTION IF EXISTS delta_snapshot_report(character varying);

create or replace FUNCTION delta_snapshot_report (p_app_name character varying)
RETURNS integer as
$body$
declare
L_ID integer := 0;
Begin
  select delta_snapshot_report(p_app_name, 0) into L_ID;
  return L_ID;
End;
$body$ 
LANGUAGE plpgsql;

create or replace FUNCTION delta_snapshot_report (p_app_name character varying, p_snapshot_id integer)
RETURNS integer as
$body$
declare
L_ID integer := 0;
L_APP_ID integer := 0;
L_SNAPSHOT_ID1 integer := 0;
L_SNAPSHOT_ID2 integer := 0;
Begin
  select COALESCE(max(ID)+1,1)
  into L_ID
  from DELTA_REPORT;

  select object_id into L_APP_ID from dss_objects where object_type_id = -102 and object_name = p_app_name;
  
  if  L_APP_ID > 0 then
    select COALESCE(max(snapshot_id),0) into L_SNAPSHOT_ID2 from dss_snapshots where application_id=L_APP_ID;
    if  L_SNAPSHOT_ID2 > 0 then
      if (p_snapshot_id > 0) then
        L_SNAPSHOT_ID1 := p_snapshot_id;
      else
        select COALESCE(max(snapshot_id),0) into L_SNAPSHOT_ID1 from dss_snapshots where application_id=L_APP_ID and snapshot_id < L_SNAPSHOT_ID2;
      end if;
      if L_SNAPSHOT_ID1 > 0 then
  
        insert into DELTA_REPORT (ID,TAG)
        select L_ID
          , (select 'Check snapshots ' || L_SNAPSHOT_ID1 || ' and ' || L_SNAPSHOT_ID2 || ' of "' || p_app_name || '" in ' || pv.version || ' at ' || current_timestamp(0) from sys_package_version pv where package_name = 'ADG_CENTRAL');
    
        perform delta_snapshot_report_data(L_ID,'B',L_SNAPSHOT_ID1,L_APP_ID);
        perform delta_snapshot_report_data(L_ID,'A',L_SNAPSHOT_ID2,L_APP_ID);
        perform delta_snapshot_report_diff(L_ID);
      end if;
    end if;
  else
    insert into DELTA_REPORT (ID,TAG)
    select L_ID
      , (select 'Check snapshots: application "' || p_app_name || '" does not exist. Failed at ' || current_timestamp(0) from sys_package_version pv where package_name = 'ADG_CENTRAL');
    return L_ID * -1;
  end if;
  return L_ID;
End;
$body$ 
LANGUAGE plpgsql;

create or replace FUNCTION delta_snapshot_report_data (p_id integer, p_delta_type character varying, p_snapshot_id integer, p_app_id integer)
RETURNS void as
$body$
declare
L_ID_MAX integer := 0;
Begin
  truncate table DELTA_WK_BCRIT;
  
  insert into DELTA_WK_BCRIT (BCRIT_ID,VALUE)
  select CRITERION_ID,CRITERION_GRADE
  from CSV_BCRIT_VALUES
  where SNAPSHOT_ID = p_snapshot_id
  and CONTEXT_ID = p_app_id;

  insert into DELTA_BCRIT (ID,TYPE,BCRIT_ID,BCRIT_NAME,VALUE)
  select p_id,p_delta_type,o.BCRIT_ID,t.METRIC_NAME,o.VALUE
  from DELTA_WK_BCRIT o
    join DSS_METRIC_TYPES t on (t.metric_id = o.BCRIT_ID);

  truncate table DELTA_WK_TCRIT;
  
  insert into DELTA_WK_TCRIT (TCRIT_ID,VALUE)
  select CRITERION_ID,CRITERION_GRADE
  from CSV_TCRIT_VALUES
  where SNAPSHOT_ID = p_snapshot_id
  and CONTEXT_ID = p_app_id;

  insert into DELTA_TCRIT (ID,TYPE,TCRIT_ID,TCRIT_NAME,VALUE)
  select p_id,p_delta_type,o.TCRIT_ID,t.METRIC_NAME,o.VALUE
  from DELTA_WK_TCRIT o
    join DSS_METRIC_TYPES t on (t.metric_id = o.TCRIT_ID);
   
  truncate table DELTA_WK_QR;
  
  insert into DELTA_WK_QR (QR_ID,VALUE,DETAIL,TOTAL)
  SELECT DISTINCT CQT.METRIC_ID,CQT.METRIC_GRADE GRADE,INNER_TAB_KO.TOTAL KO,INNER_TAB_TOTAL.TOTAL TOTAL
  FROM (SELECT METRIC_ID, METRIC_NAME, METRIC_GRADE, p_app_id "APP_ID"
    from CSV_METRIC_VALUES A
    WHERE SNAPSHOT_ID= p_snapshot_id
    AND A.CONTEXT_ID = p_app_id) CQT
  JOIN (SELECT OBJECT_ID, METRIC_ID, METRIC_NUM_VALUE TOTAL
    FROM DSS_METRIC_RESULTS
    WHERE SNAPSHOT_ID = p_snapshot_id
    AND METRIC_VALUE_INDEX = 1) INNER_TAB_KO 
      ON (INNER_TAB_KO.METRIC_ID = CQT.METRIC_ID AND INNER_TAB_KO.OBJECT_ID = CQT."APP_ID")
  JOIN (SELECT OBJECT_ID, METRIC_ID, METRIC_NUM_VALUE TOTAL
    FROM DSS_METRIC_RESULTS
    WHERE SNAPSHOT_ID = p_snapshot_id
    AND METRIC_VALUE_INDEX = 2) INNER_TAB_TOTAL
      ON (INNER_TAB_TOTAL.METRIC_ID = CQT.METRIC_ID AND INNER_TAB_TOTAL.OBJECT_ID = CQT."APP_ID");
  

  insert into DELTA_QR (ID,TYPE,QR_ID,QR_NAME,VALUE,DETAIL,TOTAL)
  select p_id,p_delta_type,o.QR_ID,t.METRIC_NAME,o.VALUE,o.DETAIL,o.TOTAL --,DMTT.METRIC_CRITICAL CRITICAL
  from DELTA_WK_QR o
    join DSS_METRIC_TYPES t on (t.metric_id = o.QR_ID)
    --JOIN DSS_METRIC_TYPE_TREES DMTT ON (CQT.METRIC_ID = DMTT.METRIC_ID)
    ;

  truncate table DELTA_WK_SM;
  
  insert into DELTA_WK_SM (SM_ID,VALUE)
  select measure_id,meas_value
  from csv_quantity_val q
    --join dss_metric_types mt on (mt.metric_id = q.measure_id and mt.metric_type = 3 and mt.metric_group = 0)
  where SNAPSHOT_ID = p_snapshot_id
  and CONTEXT_ID = p_app_id;

  insert into DELTA_SM (ID,TYPE,SM_ID,SM_NAME,VALUE)
  select p_id,p_delta_type,o.SM_ID,t.METRIC_NAME,o.VALUE
  from DELTA_WK_SM o
    join DSS_METRIC_TYPES t on (t.metric_id = o.SM_ID);
  return;
End;
$body$ 
LANGUAGE plpgsql;

create or replace FUNCTION delta_snapshot_report_diff (p_id integer)
RETURNS void as
$body$
declare
L_ID_MAX integer := 0;
Begin
  delete from DELTA_BCRIT where ID = p_id and TYPE in ('X','N','D');

  insert into DELTA_BCRIT (ID,TYPE,BCRIT_ID,BCRIT_NAME,VALUE)
  select a.ID,'X',a.BCRIT_ID,a.BCRIT_NAME,(a.VALUE - b.VALUE)
  from DELTA_BCRIT a
    join DELTA_BCRIT b on (b.ID = a.ID and b.TYPE = 'B' and b.BCRIT_ID = a.BCRIT_ID)
  where a.ID = p_id
  and a.TYPE = 'A'
  and a.VALUE <> b.VALUE;

  insert into DELTA_BCRIT (ID,TYPE,BCRIT_ID,BCRIT_NAME,VALUE)
  select a.ID,'x',a.BCRIT_ID,a.BCRIT_NAME,(a.VALUE - b.VALUE)
  from DELTA_BCRIT a
    join DELTA_BCRIT b on (b.ID = a.ID and b.TYPE = 'M' and b.BCRIT_ID = a.BCRIT_ID)
  where a.ID = p_id
  and a.TYPE = 'A'
  and a.VALUE <> b.VALUE;
  
  insert into DELTA_BCRIT (ID,TYPE,BCRIT_ID,BCRIT_NAME,VALUE)
  select a.ID,'N',a.BCRIT_ID,a.BCRIT_NAME,a.VALUE
  from DELTA_BCRIT a
  where a.ID = p_id
  and a.TYPE = 'A'
  and not exists (select 1 from DELTA_BCRIT b where b.ID = a.ID and b.TYPE = 'B' and b.BCRIT_ID = a.BCRIT_ID);

  insert into DELTA_BCRIT (ID,TYPE,BCRIT_ID,BCRIT_NAME,VALUE)
  select a.ID,'n',a.BCRIT_ID,a.BCRIT_NAME,a.VALUE
  from DELTA_BCRIT a
  where a.ID = p_id
  and a.TYPE = 'M'
  and not exists (select 1 from DELTA_BCRIT b where b.ID = a.ID and b.TYPE = 'B' and b.BCRIT_ID = a.BCRIT_ID);

  insert into DELTA_BCRIT (ID,TYPE,BCRIT_ID,BCRIT_NAME,VALUE)
  select b.ID,'D',b.BCRIT_ID,b.BCRIT_NAME,b.VALUE * -1
  from DELTA_BCRIT b
  where b.ID = p_id
  and b.TYPE = 'B'
  and not exists (select 1 from DELTA_BCRIT a where a.ID = b.ID and a.TYPE = 'A' and a.BCRIT_ID = b.BCRIT_ID);


  delete from DELTA_TCRIT where ID = p_id and TYPE in ('X','N','D');

  insert into DELTA_TCRIT (ID,TYPE,TCRIT_ID,TCRIT_NAME,VALUE)
  select a.ID,'X',a.TCRIT_ID,a.TCRIT_NAME,(a.VALUE - b.VALUE)
  from DELTA_TCRIT a
    join DELTA_TCRIT b on (b.ID = a.ID and b.TYPE = 'B' and b.TCRIT_ID = a.TCRIT_ID)
  where a.ID = p_id
  and a.TYPE = 'A'
  and a.VALUE <> b.VALUE;

  insert into DELTA_TCRIT (ID,TYPE,TCRIT_ID,TCRIT_NAME,VALUE)
  select a.ID,'x',a.TCRIT_ID,a.TCRIT_NAME,(a.VALUE - b.VALUE)
  from DELTA_TCRIT a
    join DELTA_TCRIT b on (b.ID = a.ID and b.TYPE = 'M' and b.TCRIT_ID = a.TCRIT_ID)
  where a.ID = p_id
  and a.TYPE = 'A'
  and a.VALUE <> b.VALUE;
  
  insert into DELTA_TCRIT (ID,TYPE,TCRIT_ID,TCRIT_NAME,VALUE)
  select a.ID,'N',a.TCRIT_ID,a.TCRIT_NAME,a.VALUE
  from DELTA_TCRIT a
  where a.ID = p_id
  and a.TYPE = 'A'
  and not exists (select 1 from DELTA_TCRIT b where b.ID = a.ID and b.TYPE = 'B' and b.TCRIT_ID = a.TCRIT_ID);

  insert into DELTA_TCRIT (ID,TYPE,TCRIT_ID,TCRIT_NAME,VALUE)
  select a.ID,'n',a.TCRIT_ID,a.TCRIT_NAME,a.VALUE
  from DELTA_TCRIT a
  where a.ID = p_id
  and a.TYPE = 'M'
  and not exists (select 1 from DELTA_TCRIT b where b.ID = a.ID and b.TYPE = 'B' and b.TCRIT_ID = a.TCRIT_ID);

  insert into DELTA_TCRIT (ID,TYPE,TCRIT_ID,TCRIT_NAME,VALUE)
  select b.ID,'D',b.TCRIT_ID,b.TCRIT_NAME,b.VALUE * -1
  from DELTA_TCRIT b
  where b.ID = p_id
  and b.TYPE = 'B'
  and not exists (select 1 from DELTA_TCRIT a where a.ID = b.ID and a.TYPE = 'A' and a.TCRIT_ID = b.TCRIT_ID);


  delete from DELTA_QR where ID = p_id and TYPE in ('X','N','D');

  insert into DELTA_QR (ID,TYPE,QR_ID,QR_NAME,VALUE,DETAIL,TOTAL)
  select a.ID,'X',a.QR_ID,a.QR_NAME,(a.VALUE - b.VALUE),(a.DETAIL - b.DETAIL),(a.TOTAL - b.TOTAL)
  from DELTA_QR a
    join DELTA_QR b on (b.ID = a.ID and b.TYPE = 'B' and b.QR_ID = a.QR_ID)
  where a.ID = p_id
  and a.TYPE = 'A'
  and (a.VALUE <> b.VALUE
    or a.DETAIL <> b.DETAIL
    or a.TOTAL <> b.TOTAL
  );

  insert into DELTA_QR (ID,TYPE,QR_ID,QR_NAME,VALUE,DETAIL,TOTAL)
  select a.ID,'x',a.QR_ID,a.QR_NAME,(a.VALUE - b.VALUE),(a.DETAIL - b.DETAIL),(a.TOTAL - b.TOTAL)
  from DELTA_QR a
    join DELTA_QR b on (b.ID = a.ID and b.TYPE = 'M' and b.QR_ID = a.QR_ID)
  where a.ID = p_id
  and a.TYPE = 'A'
  and (a.VALUE <> b.VALUE
    or a.DETAIL <> b.DETAIL
    or a.TOTAL <> b.TOTAL
  );
  
  insert into DELTA_QR (ID,TYPE,QR_ID,QR_NAME,VALUE,DETAIL,TOTAL)
  select a.ID,'N',a.QR_ID,a.QR_NAME,a.VALUE,a.DETAIL,a.TOTAL
  from DELTA_QR a
  where a.ID = p_id
  and a.TYPE = 'A'
  and not exists (select 1 from DELTA_QR b where b.ID = a.ID and b.TYPE = 'B' and b.QR_ID = a.QR_ID);

  insert into DELTA_QR (ID,TYPE,QR_ID,QR_NAME,VALUE,DETAIL,TOTAL)
  select a.ID,'n',a.QR_ID,a.QR_NAME,a.VALUE,a.DETAIL,a.TOTAL
  from DELTA_QR a
  where a.ID = p_id
  and a.TYPE = 'M'
  and not exists (select 1 from DELTA_QR b where b.ID = a.ID and b.TYPE = 'B' and b.QR_ID = a.QR_ID);

  insert into DELTA_QR (ID,TYPE,QR_ID,QR_NAME,VALUE,DETAIL,TOTAL)
  select b.ID,'D',b.QR_ID,b.QR_NAME,b.VALUE * -1,b.DETAIL * -1,b.TOTAL * -1
  from DELTA_QR b
  where b.ID = p_id
  and b.TYPE = 'B'
  and not exists (select 1 from DELTA_QR a where a.ID = b.ID and a.TYPE = 'A' and a.QR_ID = b.QR_ID);

  
  delete from DELTA_SM where ID = p_id and TYPE in ('X','N','D');

  insert into DELTA_SM (ID,TYPE,SM_ID,SM_NAME,VALUE)
  select a.ID,'X',a.SM_ID,a.SM_NAME,(a.VALUE - b.VALUE)
  from DELTA_SM a
    join DELTA_SM b on (b.ID = a.ID and b.TYPE = 'B' and b.SM_ID = a.SM_ID)
  where a.ID = p_id
  and a.TYPE = 'A'
  and a.VALUE <> b.VALUE;

  insert into DELTA_SM (ID,TYPE,SM_ID,SM_NAME,VALUE)
  select a.ID,'x',a.SM_ID,a.SM_NAME,(a.VALUE - b.VALUE)
  from DELTA_SM a
    join DELTA_SM b on (b.ID = a.ID and b.TYPE = 'M' and b.SM_ID = a.SM_ID)
  where a.ID = p_id
  and a.TYPE = 'A'
  and a.VALUE <> b.VALUE;
  
  insert into DELTA_SM (ID,TYPE,SM_ID,SM_NAME,VALUE)
  select a.ID,'N',a.SM_ID,a.SM_NAME,a.VALUE
  from DELTA_SM a
  where a.ID = p_id
  and a.TYPE = 'A'
  and not exists (select 1 from DELTA_SM b where b.ID = a.ID and b.TYPE = 'B' and b.SM_ID = a.SM_ID);

  insert into DELTA_SM (ID,TYPE,SM_ID,SM_NAME,VALUE)
  select a.ID,'n',a.SM_ID,a.SM_NAME,a.VALUE
  from DELTA_SM a
  where a.ID = p_id
  and a.TYPE = 'M'
  and not exists (select 1 from DELTA_SM b where b.ID = a.ID and b.TYPE = 'B' and b.SM_ID = a.SM_ID);

  insert into DELTA_SM (ID,TYPE,SM_ID,SM_NAME,VALUE)
  select b.ID,'D',b.SM_ID,b.SM_NAME,b.VALUE * -1
  from DELTA_SM b
  where b.ID = p_id
  and b.TYPE = 'B'
  and not exists (select 1 from DELTA_SM a where a.ID = b.ID and a.TYPE = 'A' and a.SM_ID = b.SM_ID);
  return;
End;
$body$ 
LANGUAGE plpgsql;
