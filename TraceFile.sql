USE master
GO
--Trace File مشاهده محتوای یک
SELECT * FROM SYS.fn_trace_gettable('C:\DUMP\TraceFile.trc',-1)
GO
--Trace مشاهده لیست 
SELECT * FROM SYS.traces
GO
