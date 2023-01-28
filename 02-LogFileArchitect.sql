--------------------------------------------------------------------

--------------------------------------------------------------------
USE master
GO
--بررسی جهت وجود بانک اطلاعاتی و حذف آن
IF DB_ID('Test01')>0
	DROP DATABASE Test01
GO
CREATE DATABASE Test01
GO
USE Test01
GO
SP_HELPFILE
GO
--Check Recovery Model
SELECT 
	database_id,name,recovery_model_desc 
FROM SYS.databases
WHERE name='Test01'
GO
--هاVLF مشاهده
DBCC LOGINFO
GO
--مشاهده محتوای لاگ رکوردها
SELECT * FROM SYS.fn_dblog(NULL,NULL)
GO
ALTER DATABASE Test01 SET RECOVERY SIMPLE
GO
CHECKPOINT
SELECT * FROM SYS.fn_dblog(NULL,NULL)
GO
--ایجا یک جدول
CREATE TABLE VLF_Test
(
	C1 INT,
	C2 NVARCHAR(100),
	C3 NVARCHAR(100)
)
GO
--مشاهده محتوای لاگ رکوردها
SELECT * FROM SYS.fn_dblog(NULL,NULL)
GO
CHECKPOINT
GO
--درج یک رکورد ساده
INSERT INTO VLF_Test VALUES (1,'A','A')
GO
--مشاهده محتوای لاگ رکوردها
SELECT * FROM SYS.fn_dblog(NULL,NULL)
GO
CHECKPOINT
SELECT * FROM SYS.fn_dblog(NULL,NULL)
GO
BEGIN TRANSACTION
UPDATE VLF_Test SET C2='B',C3='B' WHERE C1=1
ROLLBACK TRANSACTION
GO
SELECT * FROM SYS.fn_dblog(NULL,NULL)
GO
--------------------------------------------------------------------

--Check Recovery Model
SELECT 
	database_id,name,recovery_model_desc 
FROM SYS.databases
WHERE name='ClinicPooya'
GO
SELECT 
	name ,
	recovery_model_desc ,
	log_reuse_wait_desc
FROM	sys.databases
WHERE	name = 'ClinicPooya'
GO
/*
1. Don’t create multiple log files : As transactions will be logged into log file sequential manner it would not help for data stripping across multiple files
2. Keep the transaction log file on the separate drive
3. choose the recovery model and correct log backup strategy
4. RAID 1 + 0 is high recommended for transaction log
5. AUTO SHRINK should be always off on the database
6. Pre-allocate the space to transaction log file, it will improve the performance. Don’t depend on the auto growth option.
7. Always set the values of Initial size, max size and growth property of the transaction log file
8. Always set auto growth value, don’t set in percentage
9. Transaction Log file internal fragmentation can also lead the performance and database recovery issue. Database should not have an excessive number of Virtual Log Files (VLFs) inside the Transaction Log. Having a large number of small VLFs can slow down the recovery process that a database goes through on startup or after restoring a backup. Make sure transaction log initial size and log growth defined well to avoid internal fragmentation
10. External fragmentation can be removed by using disk defragmentation utility
11. In case of Transaction log full, please use below query to check the cause of the log full and take the decision accordingly.
*/