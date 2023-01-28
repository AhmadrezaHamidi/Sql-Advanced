--------------------------------------------------------------------

--------------------------------------------------------------------
/*
SELECT 
	st.text, r.session_id, r.status, 
	r.command, r.cpu_time, r.total_elapsed_time
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS st
GO
--The following query shows the number of connections a user has with a database
SELECT 
	db_name(dbid) as DatabaseName, 
	count(dbid) as NoOfConnections, loginame as LoginName
FROM sys.sysprocesses
WHERE dbid > 0
GROUP BY dbid, loginame
*/
--پاک کردن کلیه کانکشن ها
set nocount on
declare @databasename varchar(100)
declare @query varchar(max)
set @query = ''

set @databasename = 'xxx'
if db_id(@databasename) < 4
begin
	print 'system database connection cannot be killeed'
return
end

select @query=coalesce(@query,',' )+'kill '+convert(varchar, spid)+ '; '
from master..sysprocesses where dbid=db_id(@databasename)

if len(@query) > 0
begin
print @query
	exec(@query)
end
------------------------------------------------------
--SQL server - get list of active connections to each database
SELECT 
	DB_NAME(dbid) as [Database], COUNT(dbid) as [Number Of Open Connections],loginame as LoginName
FROM sys.sysprocesses
WHERE dbid > 0
GROUP BY dbid, loginame
------------------------------------------------------
--A. Finding users that are connected to the server
--The following example finds the users that are connected to the server and returns the number of sessions for each user.
SELECT 
	login_name ,COUNT(session_id) AS session_count 
FROM sys.dm_exec_sessions 
GROUP BY login_name;
------------------------------------------------------
--B. Finding long-running cursors
--The following example finds the cursors that have been open for more than a specific period of time, who created the cursors, and what session the cursors are on.
USE master;
GO
SELECT creation_time ,cursor_id 
    ,name ,c.session_id ,login_name 
FROM sys.dm_exec_cursors(0) AS c 
JOIN sys.dm_exec_sessions AS s 
   ON c.session_id = s.session_id 
WHERE DATEDIFF(mi, c.creation_time, GETDATE()) > 5;
------------------------------------------------------
--C. Finding idle sessions that have open transactions
--The following example finds sessions that have open transactions and are idle. An idle session is one that has no request currently running.
SELECT s.* 
FROM sys.dm_exec_sessions AS s
WHERE EXISTS 
    (
    SELECT * 
    FROM sys.dm_tran_session_transactions AS t
    WHERE t.session_id = s.session_id
    )
    AND NOT EXISTS 
    (
    SELECT * 
    FROM sys.dm_exec_requests AS r
    WHERE r.session_id = s.session_id
    );
------------------------------------------------------
--D. Finding information about a queries own connection
--Typical query to gather information about a queries own connection.
SELECT 
    c.session_id, c.net_transport, c.encrypt_option, 
    c.auth_scheme, s.host_name, s.program_name, 
    s.client_interface_name, s.login_name, s.nt_domain, 
    s.nt_user_name, s.original_login_name, c.connect_time, 
    s.login_time 
FROM sys.dm_exec_connections AS c
JOIN sys.dm_exec_sessions AS s
    ON c.session_id = s.session_id
WHERE c.session_id = @@SPID;
------------------------------------------------------
--View Active Connections
-- By Application
SELECT 
     CPU            = SUM(cpu_time)
    ,WaitTime       = SUM(total_scheduled_time)
    ,ElapsedTime    = SUM(total_elapsed_time)
    ,Reads          = SUM(num_reads) 
    ,Writes         = SUM(num_writes) 
    ,Connections    = COUNT(1) 
    ,Program        = program_name
FROM sys.dm_exec_connections con
LEFT JOIN sys.dm_exec_sessions ses
    ON ses.session_id = con.session_id
GROUP BY program_name
ORDER BY cpu DESC
GO
--View Active Connections
-- Group By User
SELECT 
     CPU            = SUM(cpu_time)
    ,WaitTime       = SUM(total_scheduled_time)
    ,ElapsedTime    = SUM(total_elapsed_time)
    ,Reads          = SUM(num_reads) 
    ,Writes         = SUM(num_writes) 
    ,Connections    = COUNT(1) 
    ,[login]        = original_login_name
FROM sys.dm_exec_connections con
LEFT JOIN sys.dm_exec_sessions ses
ON ses.session_id = con.session_id
GROUP BY original_login_name
GO
------------------------------------------------------
SELECT
    SPID                = er.session_id
    ,STATUS             = ses.STATUS
    ,[Login]            = ses.login_name
    ,Host               = ses.host_name
    ,BlkBy              = er.blocking_session_id
    ,DBName             = DB_Name(er.database_id)
    ,CommandType        = er.command
    ,SQLStatement       = st.text
    ,ObjectName         = OBJECT_NAME(st.objectid)
    ,ElapsedMS          = er.total_elapsed_time
    ,CPUTime            = er.cpu_time
    ,IOReads            = er.logical_reads + er.reads
    ,IOWrites           = er.writes
    ,LastWaitType       = er.last_wait_type
    ,StartTime          = er.start_time
    ,Protocol           = con.net_transport
    ,ConnectionWrites   = con.num_writes
    ,ConnectionReads    = con.num_reads
    ,ClientAddress      = con.client_net_address
    ,Authentication     = con.auth_scheme
FROM sys.dm_exec_requests er
OUTER APPLY sys.dm_exec_sql_text(er.sql_handle) st
LEFT JOIN sys.dm_exec_sessions ses
ON ses.session_id = er.session_id
LEFT JOIN sys.dm_exec_connections con
ON con.session_id = ses.session_id

------------------------------------------------------
--Find Long Running Queries
SELECT TOP 100
	ObjectName          = OBJECT_NAME(qt.objectid)
	,DiskReads          = qs.total_physical_reads -- The worst reads, disk reads
	,MemoryReads        = qs.total_logical_reads  --Logical Reads are memory reads
	,Executions         = qs.execution_count
	,AvgDuration        = qs.total_elapsed_time / qs.execution_count
	,CPUTime            = qs.total_worker_time
	,DiskWaitAndCPUTime = qs.total_elapsed_time
	,MemoryWrites       = qs.max_logical_writes
	,DateCached         = qs.creation_time
	,DatabaseName       = DB_Name(qt.dbid)
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
--WHERE qt.dbid = db_id() -- Filter by current database
ORDER BY qs.total_elapsed_time DESC
------------------------------------------------------
--Find Queries Using Most Memory (IO)
/**********************************************************
*   top procedures memory consumption per execution
*   (this will show mostly reports &amp; jobs)
***********************************************************/
SELECT TOP 100 *
FROM 
(
    SELECT
         DatabaseName       = DB_NAME(qt.dbid)
        ,ObjectName         = OBJECT_SCHEMA_NAME(qt.objectid,dbid) + '.' + OBJECT_NAME(qt.objectid, qt.dbid)
        ,DiskReads          = SUM(qs.total_physical_reads)   -- The worst reads, disk reads
        ,MemoryReads        = SUM(qs.total_logical_reads)    --Logical Reads are memory reads
        ,Executions         = SUM(qs.execution_count)
        ,IO_Per_Execution   = SUM((qs.total_physical_reads + qs.total_logical_reads) / qs.execution_count)
        ,CPUTime            = SUM(qs.total_worker_time)
        ,DiskWaitAndCPUTime = SUM(qs.total_elapsed_time)
        ,MemoryWrites       = SUM(qs.max_logical_writes)
        ,DateLastExecuted   = MAX(qs.last_execution_time)
        
    FROM sys.dm_exec_query_stats AS qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
    GROUP BY DB_NAME(qt.dbid), OBJECT_SCHEMA_NAME(qt.objectid,dbid) + '.' + OBJECT_NAME(qt.objectid, qt.dbid)

) T
ORDER BY IO_Per_Execution DESC

/**********************************************************
*   top procedures memory consumption total
*   (this will show more operational procedures)
***********************************************************/
SELECT TOP 100 *
FROM 
(
    SELECT
         DatabaseName       = DB_NAME(qt.dbid)
        ,ObjectName         = OBJECT_SCHEMA_NAME(qt.objectid,dbid) + '.' + OBJECT_NAME(qt.objectid, qt.dbid)
        ,DiskReads          = SUM(qs.total_physical_reads)   -- The worst reads, disk reads
        ,MemoryReads        = SUM(qs.total_logical_reads)    --Logical Reads are memory reads
        ,Total_IO_Reads     = SUM(qs.total_physical_reads + qs.total_logical_reads)
        ,Executions         = SUM(qs.execution_count)
        ,IO_Per_Execution   = SUM((qs.total_physical_reads + qs.total_logical_reads) / qs.execution_count)
        ,CPUTime            = SUM(qs.total_worker_time)
        ,DiskWaitAndCPUTime = SUM(qs.total_elapsed_time)
        ,MemoryWrites       = SUM(qs.max_logical_writes)
        ,DateLastExecuted   = MAX(qs.last_execution_time)
        
    FROM sys.dm_exec_query_stats AS qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
    GROUP BY DB_NAME(qt.dbid), OBJECT_SCHEMA_NAME(qt.objectid,dbid) + '.' + OBJECT_NAME(qt.objectid, qt.dbid)
) T
ORDER BY Total_IO_Reads DESC



/**********************************************************
*   top adhoc queries memory consumption total
***********************************************************/
SELECT TOP 10 *
FROM 
(
    SELECT
         DatabaseName       = DB_NAME(qt.dbid)
        ,QueryText          = qt.text       
        ,DiskReads          = SUM(qs.total_physical_reads)   -- The worst reads, disk reads
        ,MemoryReads        = SUM(qs.total_logical_reads)    --Logical Reads are memory reads
        ,Total_IO_Reads     = SUM(qs.total_physical_reads + qs.total_logical_reads)
        ,Executions         = SUM(qs.execution_count)
        ,IO_Per_Execution   = SUM((qs.total_physical_reads + qs.total_logical_reads) / qs.execution_count)
        ,CPUTime            = SUM(qs.total_worker_time)
        ,DiskWaitAndCPUTime = SUM(qs.total_elapsed_time)
        ,MemoryWrites       = SUM(qs.max_logical_writes)
        ,DateLastExecuted   = MAX(qs.last_execution_time)
        
    FROM sys.dm_exec_query_stats AS qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
    WHERE OBJECT_SCHEMA_NAME(qt.objectid,dbid) + '.' + OBJECT_NAME(qt.objectid, qt.dbid) IS NULL
    GROUP BY DB_NAME(qt.dbid), qt.text, OBJECT_SCHEMA_NAME(qt.objectid,dbid) + '.' + OBJECT_NAME(qt.objectid, qt.dbid)
) T
ORDER BY Total_IO_Reads DESC


/**********************************************************
*   top adhoc queries memory consumption per execution
***********************************************************/
SELECT TOP 100 *
FROM 
(
    SELECT
         DatabaseName       = DB_NAME(qt.dbid)
        ,QueryText          = qt.text       
        ,DiskReads          = SUM(qs.total_physical_reads)   -- The worst reads, disk reads
        ,MemoryReads        = SUM(qs.total_logical_reads)    --Logical Reads are memory reads
        ,Total_IO_Reads     = SUM(qs.total_physical_reads + qs.total_logical_reads)
        ,Executions         = SUM(qs.execution_count)
        ,IO_Per_Execution   = SUM((qs.total_physical_reads + qs.total_logical_reads) / qs.execution_count)
        ,CPUTime            = SUM(qs.total_worker_time)
        ,DiskWaitAndCPUTime = SUM(qs.total_elapsed_time)
        ,MemoryWrites       = SUM(qs.max_logical_writes)
        ,DateLastExecuted   = MAX(qs.last_execution_time)
        
    FROM sys.dm_exec_query_stats AS qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
    WHERE OBJECT_SCHEMA_NAME(qt.objectid,dbid) + '.' + OBJECT_NAME(qt.objectid, qt.dbid) IS NULL
    GROUP BY DB_NAME(qt.dbid), qt.text, OBJECT_SCHEMA_NAME(qt.objectid,dbid) + '.' + OBJECT_NAME(qt.objectid, qt.dbid)
) T
ORDER BY IO_Per_Execution DESC
GO
------------------------------------------------------
--Get Latest SQL Query for Sessions – DMV
SELECT 
	session_id, TEXT
FROM sys.dm_exec_connections
CROSS APPLY sys.dm_exec_sql_text(most_recent_sql_handle) AS ST
GO
------------------------------------------------------
--This query shows all queries executed at the moment, the session id, status, used cpu time and the execution duration
SELECT 
	st.text, r.session_id, r.status, 
	r.command, r.cpu_time, r.total_elapsed_time
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS st
GO
--The following query shows the number of connections a user has with a database
SELECT 
	db_name(dbid) as DatabaseName, 
	count(dbid) as NoOfConnections, loginame as LoginName
FROM sys.sysprocesses
WHERE dbid > 0
GROUP BY dbid, loginame
------------------------------------------------------
-- Who is running what at this instant
SELECT 
	dest.text AS [Command text] ,
	der.total_elapsed_time as 'total_elapsed_time (ms)', 
	-- cast(cast(der.total_elapsed_time as float) / 1000 as decimal(10,3)) as 'total_elapsed_time (secs)',
	DB_NAME(der.database_id) AS DatabaseName ,
	der.command ,
	des.login_time ,
	des.[host_name] ,
	des.[program_name] ,
	der.session_id
FROM sys.dm_exec_requests der
INNER JOIN sys.dm_exec_connections dec
ON der.session_id = dec.session_id
INNER JOIN sys.dm_exec_sessions des
ON des.session_id = der.session_id
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS dest
WHERE des.is_user_process = 1
-- and DB_NAME(der.database_id) = 'blogcfc'
------------------------------------------------------
--SQL SERVER – Find Currently Running Query – T-SQL
SELECT 
	sqltext.TEXT,
	req.session_id,
	req.status,
	req.command,
	req.cpu_time,
	req.total_elapsed_time
FROM sys.dm_exec_requests req
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS sqltext
------------------------------------------------------
--How to check current pool size of SQL Server
SELECT  
	des.program_name
    , des.login_name
    , des.host_name
    , COUNT(des.session_id) [Connections]
FROM    sys.dm_exec_sessions des
INNER JOIN sys.dm_exec_connections DEC
        ON des.session_id = DEC.session_id
WHERE   des.is_user_process = 1
        AND des.status != 'running'
GROUP BY des.program_name
      , des.login_name
      , des.host_name
HAVING  COUNT(des.session_id) > 2
ORDER BY COUNT(des.session_id) DESC
------------------------------------------------------
SELECT 
	session_id,
	most_recent_session_id,
	connection_id,
	connect_time,
	net_transport,
	protocol_type,
	encrypt_option,
	auth_scheme,
	node_affinity,
	num_reads,
	num_writes,
	last_read,
	last_write,
	net_packet_size,
	client_net_address,
	client_tcp_port,
	most_recent_sql_handle
FROM sys.dm_exec_connections
------------------------------------------------------
