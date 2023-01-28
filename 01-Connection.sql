


--------------------------------------------------------------------
-- Session استخراج لیست
--Session ID بررسی مفهوم 
SP_WHO
GO
SP_WHO2
GO
SP_WHO2 51
GO
SELECT * FROM SYS.dm_exec_connections
GO
SELECT * FROM sys.sysprocesses
GO
SELECT * FROM sys.dm_exec_sessions 
----------------------------
--ها بر اساس لاگینSession تعداد 
SELECT 
	login_name ,COUNT(session_id) AS session_count 
FROM sys.dm_exec_sessions 
GROUP BY login_name;
GO
SELECT 
	login_name ,COUNT(session_id) AS session_count 
FROM sys.dm_exec_sessions  WHERE session_id>50
GROUP BY login_name;
GO
SELECT 
	des.program_name,
	des.login_name,
	des.host_name,
	COUNT(des.session_id) [Connections]
FROM sys.dm_exec_sessions des
INNER JOIN sys.dm_exec_connections DEC ON des.session_id = DEC.session_id
WHERE 
	des.is_user_process = 1
	GROUP BY 
		des.program_name,
	des.login_name,
	des.host_name
	HAVING 
		COUNT(des.session_id) > 2
	ORDER BY 
		COUNT(des.session_id) DESC
----------------------------
--مشاهده آخرین دستورات اجرا شده
--Create New Session ....

DBCC INPUTBUFFER(51)
GO
SELECT * FROM SYS.dm_exec_connections
SELECT * FROM SYS.dm_exec_sql_text(XXXXX)
SELECT * FROM SYS.dm_exec_query_plan(0x020000004B725B080003138D6645B16EDF6EF6759DBEC4730000000000000000000000000000000000000000)
GO
--Session مشاهده آخرین دستورات اجرا شده به ازای هر 
SELECT 
	dm_ec.session_id ,
	dm_es.login_name,
	dm_es.program_name,
	dm_es.host_name,
	dm_est.text,
	dm_Plan.query_plan
FROM SYS.dm_exec_connections dm_ec
INNER JOIN sys.dm_exec_sessions  dm_es ON dm_ec.session_id=dm_es.session_id
CROSS APPLY SYS.dm_exec_sql_text(dm_ec.most_recent_sql_handle) dm_est
GO

SELECT TOP 5 total_worker_time/execution_count AS [Avg CPU Time],
Plan_handle, query_plan 
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle)
ORDER BY total_worker_time/execution_count DESC;
GO
----------------------------
--های درخواست دهندهSession مشاهده 
SELECT * FROM SYS.dm_exec_requests
	WHERE session_id>=51
GO
SELECT  
	REQ.session_id,
	DB_NAME(REQ.database_id),
	REQ.command,
	REQ.start_time,
	DATEDIFF(SECOND,REQ.start_time,GETDATE()),
	SQLT.text
FROM SYS.dm_exec_requests REQ
CROSS APPLY SYS.dm_exec_sql_text(REQ.plan_handle) SQLT
WHERE REQ.session_id<>@@SPID
GO
----------------------------
GO
--Session قطع اتصال یک 
KILL 51
GO
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
