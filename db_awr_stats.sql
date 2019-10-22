-- Author v1: Oracle
-- Author v2: Murali Sriram https://github.com/muralins

set define '&'
set concat '~'
set colsep " "
set pagesize 50000
SET ARRAYSIZE 5000
REPHEADER OFF
REPFOOTER OFF


ALTER SESSION SET WORKAREA_SIZE_POLICY = manual;
ALTER SESSION SET SORT_AREA_SIZE = 268435456;


set timing off

set serveroutput on
set verify off
column cnt_dbid_1 new_value CNT_DBID noprint

define NUM_DAYS = 30
define SQL_TOP_N = 100
define AWR_MINER_VER = 4.0.10
define CAPTURE_HOST_NAMES = 'YES'

alter session set cursor_sharing = exact;


prompt 
prompt This script queries views in the AWR Repository that require 
prompt a license for the Diagnostic Pack. These are the same views used
prompt to generate an AWR report.
prompt If you are licensed for the Diagnostic Pack please type YES. 
prompt Otherwise please type NO and this script will exit.
define DIAG_PACK_LICENSE = 'NO'
prompt
accept DIAG_PACK_LICENSE CHAR prompt 'Are you licensed for the Diagnostic Pack? [NO|YES] ' 



whenever sqlerror exit
set serveroutput on
begin
    if upper('&DIAG_PACK_LICENSE') = 'YES' then
		null;
	else
        dbms_output.put_line('This script will now exit.');
        execute immediate 'bogus statement to force exit';
    end if;
end;
/

whenever sqlerror continue

SELECT count(DISTINCT dbid) cnt_dbid_1
FROM dba_hist_database_instance;
 --where rownum = 1;


define DBID = ' ' 
column :DBID_1 new_value DBID noprint
variable DBID_1 varchar2(30)

define DB_VERSION = 0
column :DB_VERSION_1 new_value DB_VERSION noprint
variable DB_VERSION_1 number



set feedback off
declare
	version_gte_11_2	varchar2(30);
	l_sql				varchar2(32767);
	l_variables	        varchar2(1000) := ' ';
	l_block_size		number;
begin
	:DB_VERSION_1 :=  dbms_db_version.version + (dbms_db_version.release / 10);
	dbms_output.put_line('Database IDs in this Repository:');
	
	
	
	for c1 in (select distinct dbid,db_name FROM dba_hist_database_instance order by db_name)
	loop
		dbms_output.put_line(rpad(c1.dbid,35)||c1.db_name);
	end loop; --c1
		
	if to_number(&CNT_DBID) > 1 then
		:DBID_1 := ' ';
	else
		
		SELECT DISTINCT dbid into :DBID_1
					 FROM dba_hist_database_instance
					where rownum = 1;
		

	end if;
	
	--l_variables := l_variables||'ver_gte_11_2:TRUE';
	
	if :DB_VERSION_1  >= 11.2 then
		l_variables := l_variables||'ver_gte_11_2:TRUE';
	else
		l_variables := l_variables||'ver_gte_11_2:FALSE';
	end if;
	
	if :DB_VERSION_1  >= 11.1 then
		l_variables := l_variables||',ver_gte_11_1:TRUE';
	else
		l_variables := l_variables||',ver_gte_11_1:FALSE';
	end if;
	
	--alter session set plsql_ccflags = 'debug_flag:true';
	l_sql := q'[alter session set plsql_ccflags =']'||l_variables||q'[']';
	
	
	
	execute immediate l_sql;
end;
/

select :DBID_1 from dual;
select :DB_VERSION_1 from dual;



accept DBID2 CHAR prompt 'Which dbid would you like to use? [&DBID] '

column DBID_2 new_value DBID noprint
select case when length('&DBID2') > 3 then '&DBID2' else '&DBID' end DBID_2 from dual;


whenever sqlerror exit
set serveroutput on
begin
    if length('&DBID') > 4 then
		null;
	else
        dbms_output.put_line('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
        dbms_output.put_line('You must choose a database ID.');
        dbms_output.put_line('This script will now exit.');
		dbms_output.put_line('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
        execute immediate 'bogus statement to force exit';
    end if;
end;
/

whenever sqlerror continue

REM set heading off

select '&DBID' a from dual;

column db_name1 new_value DBNAME
prompt Will export AWR data for the following Database:

SELECT dbid,db_name db_name1
FROM dba_hist_database_instance
where dbid = '&DBID'
and rownum = 1;


define T_WAITED_MICRO_COL = 'TIME_WAITED_MICRO' 
column :T_WAITED_MICRO_COL_1 new_value T_WAITED_MICRO_COL noprint
variable T_WAITED_MICRO_COL_1 varchar2(30)

begin
	if :DB_VERSION_1  >= 11.1 then
		:T_WAITED_MICRO_COL_1 := 'TIME_WAITED_MICRO_FG';
	else
		:T_WAITED_MICRO_COL_1 := 'TIME_WAITED_MICRO';
	end if;

end;
/

select :T_WAITED_MICRO_COL_1 from dual;

column DB_BLOCK_SIZE_1 new_value DB_BLOCK_SIZE noprint
with inst as (
select min(instance_number) inst_num
  from dba_hist_snapshot
  where dbid = &DBID
	)
SELECT VALUE DB_BLOCK_SIZE_1
	FROM DBA_HIST_PARAMETER
	WHERE dbid = &DBID
	and PARAMETER_NAME = 'db_block_size'
	AND snap_id = (SELECT MAX(snap_id) FROM dba_hist_osstat WHERE dbid = &DBID AND instance_number = (select inst_num from inst))
   AND instance_number = (select inst_num from inst);

column snap_min1 new_value SNAP_ID_MIN noprint
SELECT min(snap_id) - 1 snap_min1
  FROM dba_hist_snapshot
  WHERE dbid = &DBID 
    and begin_interval_time > (
		SELECT max(begin_interval_time) - &NUM_DAYS
		  FROM dba_hist_snapshot 
		  where dbid = &DBID);
		  
column snap_max1 new_value SNAP_ID_MAX noprint
SELECT max(snap_id) snap_max1
  FROM dba_hist_snapshot
  WHERE dbid = &DBID;
  
column FILE_NAME new_value SPOOL_FILE_NAME noprint
select 'awr-hist-'||'&DBID'||'-'||'&DBNAME'||'-'||ltrim('&SNAP_ID_MIN')||'-'||ltrim('&SNAP_ID_MAX')||'.out' FILE_NAME from dual;
spool &SPOOL_FILE_NAME


-- ##############################################################################################
REPHEADER ON
REPFOOTER ON 

set linesize 1000 
set numwidth 10
set wrap off
set heading on
set trimspool on
set feedback off




set serveroutput on
DECLARE
    l_pad_length number :=60;
	l_hosts	varchar2(4000);
	l_dbid	number;
BEGIN

    dbms_output.put_line(rpad('STAT_NAME',l_pad_length)||' '||'STAT_VALUE');
    dbms_output.put_line(rpad('-',l_pad_length,'-')||' '||rpad('-',l_pad_length,'-'));
    
    FOR c1 IN (
			with inst as (
		select min(instance_number) inst_num
		  from dba_hist_snapshot
		  where dbid = &DBID
			and snap_id BETWEEN to_number(&SNAP_ID_MIN) and to_number(&SNAP_ID_MAX))
	SELECT 
                      CASE WHEN stat_name = 'PHYSICAL_MEMORY_BYTES' THEN 'PHYSICAL_MEMORY_GB' ELSE stat_name END stat_name,
                      CASE WHEN stat_name IN ('PHYSICAL_MEMORY_BYTES') THEN round(VALUE/1024/1024/1024,2) ELSE VALUE END stat_value
                  FROM dba_hist_osstat 
                 WHERE dbid = &DBID 
                   AND snap_id = (SELECT MAX(snap_id) FROM dba_hist_osstat WHERE dbid = &DBID AND instance_number = (select inst_num from inst))
				   AND instance_number = (select inst_num from inst)
                   AND (stat_name LIKE 'NUM_CPU_CORES%' or stat_name LIKE 'NUM_CPU_SOCKET%'
                   OR stat_name IN ('PHYSICAL_MEMORY_BYTES')))
    loop
        dbms_output.put_line(rpad(c1.stat_name||'_PER_NODE',l_pad_length)||' '||c1.stat_value);
    end loop; --c1
    
	for c1 in (SELECT CPU_COUNT,CPU_CORE_COUNT,CPU_SOCKET_COUNT
				 FROM DBA_CPU_USAGE_STATISTICS 
				where dbid = &DBID
				  and TIMESTAMP = (select max(TIMESTAMP) from DBA_CPU_USAGE_STATISTICS where dbid = &DBID )
				  AND ROWNUM = 1)
	loop
		dbms_output.put_line(rpad('TOTAL_CORE_COUNT',l_pad_length)||' '||c1.CPU_CORE_COUNT);
		dbms_output.put_line(rpad('TOTAL_SOCKET_COUNT',l_pad_length)||' '||c1.CPU_SOCKET_COUNT);
	end loop;
	
	FOR c2 IN (SELECT 
						$IF $$VER_GTE_11_2 $THEN
							REPLACE(platform_name,' ','_') platform_name,
						$ELSE
							'None' platform_name,
						$END
						VERSION,db_name,DBID FROM dba_hist_database_instance 
						WHERE dbid = &DBID  
						and startup_time = (select max(startup_time) from dba_hist_database_instance WHERE dbid = &DBID )
						AND ROWNUM = 1)
    loop
        dbms_output.put_line(rpad('PLATFORM_NAME',l_pad_length)||' '||c2.platform_name);
        dbms_output.put_line(rpad('VERSION',l_pad_length)||' '||c2.VERSION);
        dbms_output.put_line(rpad('DB_NAME',l_pad_length)||' '||c2.db_name);
    end loop; --c2
    
    FOR c3 IN (SELECT count(distinct s.instance_number) instances
			     FROM dba_hist_database_instance i,dba_hist_snapshot s
				WHERE i.dbid = s.dbid
				  and i.dbid = &DBID
				  AND s.snap_id BETWEEN &SNAP_ID_MIN AND &SNAP_ID_MAX)
    loop
        dbms_output.put_line(rpad('INSTANCES',l_pad_length)||' '||c3.instances);
    end loop; --c3           
	
	
	FOR c4 IN (SELECT distinct regexp_replace(host_name,'^([[:alnum:]]+)\..*$','\1')  host_name 
			     FROM dba_hist_database_instance i,dba_hist_snapshot s
				WHERE i.dbid = s.dbid
				  and i.dbid = &DBID
                  and s.startup_time = i.startup_time
				  AND s.snap_id BETWEEN &SNAP_ID_MIN AND &SNAP_ID_MAX
			    order by 1)
    loop
		if '&CAPTURE_HOST_NAMES' = 'YES' then
			l_hosts := l_hosts || c4.host_name ||',';	
		end if;
	end loop; --c4
	l_hosts := rtrim(l_hosts,',');
	dbms_output.put_line(rpad('HOSTS',l_pad_length)||' '||l_hosts);
	
	for c5 in (select max(size_gb) size_gb
				  from (
				  WITH ts_info as (
					select dbid, ts#, tsname, max(block_size) block_size
					from dba_hist_datafile
					where dbid = &DBID
					group by dbid, ts#, tsname),
					snap_info as (
						select dbid,to_char(trunc(end_interval_time,'DD'),'MM/DD/YY') dd, max(s.snap_id) snap_id
						FROM dba_hist_snapshot s
						where s.snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
						and dbid = &DBID
						group by dbid,trunc(end_interval_time,'DD'))
				select s.snap_id, round(sum(tablespace_size*f.block_size)/1024/1024/1024,2) size_gb
				from dba_hist_tbspc_space_usage sp,
				ts_info f,
				snap_info s
				WHERE s.dbid = sp.dbid
				AND s.dbid = &DBID
				and s.snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
				and s.snap_id = sp.snap_id
				and sp.dbid = f.dbid
				AND sp.tablespace_id = f.ts#
				GROUP BY  s.snap_id,s.dd, s.dbid
				order by  s.snap_id) t)
		loop
        dbms_output.put_line(rpad('Database_SIZE_GB',l_pad_length)||' '||c5.size_gb);
    end loop; --c5           
	
	for c6 in (select 	max(os_cpu) os_cpu, 
							max(sum_read_iops) read_iops,
							max(sum_read_mb_s) read_mb_s, 
							max(sum_write_iops) write_iops, 
							max(sum_write_mb_s) write_mb_s
from
(
select max(os_cpu) os_cpu, sum(read_iops) sum_read_iops, sum(read_mb_s) sum_read_mb_s, sum(write_iops) sum_write_iops, sum(write_mb_s) sum_write_mb_s
from 
(
select snap_id snap,inst inst_id,
 max(decode(metric_name,'Host CPU Utilization (%)',					average,null)) os_cpu,
max(decode(metric_name,'Physical Read Total Bytes Per Sec',         round((average)/1024/1024,1),null)) read_mb_s,
max(decode(metric_name,'Physical Read Total IO Requests Per Sec',   average,null)) read_iops,
max(decode(metric_name,'Physical Write Total Bytes Per Sec',        round((average)/1024/1024,1),null)) write_mb_s,
max(decode(metric_name,'Physical Write Total IO Requests Per Sec',  average,null)) write_iops
  from(
  select  snap_id,num_interval,to_char(end_time,'YY/MM/DD HH24:MI') end_time,instance_number inst,metric_name,round(average,1) average,
  round(maxval,1) maxval,round(standard_deviation,1) standard_deviation
 from dba_hist_sysmetric_summary
where dbid = &DBID
 and snap_id between &SNAP_ID_MIN and &SNAP_ID_MAX
 and metric_name in ('Host CPU Utilization (%)',
 'Physical Read Total Bytes Per Sec',
 'Physical Read Total IO Requests Per Sec',
 'Physical Write Total Bytes Per Sec',
 'Physical Write Total IO Requests Per Sec'
    )
 )
 group by snap_id,num_interval, end_time,inst
 order by snap_id,end_time,inst
 ) t1
 group by t1.snap ) t2)
		loop
        dbms_output.put_line(rpad('PEAK_OS_CPU',l_pad_length)||' '||c6.os_cpu);
        dbms_output.put_line(rpad('PEAK_READ_IOPS',l_pad_length)||' '||c6.read_iops);
        dbms_output.put_line(rpad('PEAK_READ_MBPS',l_pad_length)||' '||c6.read_mb_s);
        dbms_output.put_line(rpad('PEAK_WRITE_IOPS',l_pad_length)||' '||c6.write_iops);
        dbms_output.put_line(rpad('PEAK_WRITE_MBPS',l_pad_length)||' '||c6.write_mb_s);
    end loop; --c6           
	
END;
/

prompt 
prompt 

REPHEADER OFF
REPFOOTER OFF
 
spool off
exit;
