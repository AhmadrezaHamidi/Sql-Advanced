--------------------------------------------------------------------

--------------------------------------------------------------------
USE ClinicPooya
GO
--مشاهده دیتا تایپ ها به ازای جداول
SELECT * FROM INFORMATION_SCHEMA.COLUMNS
GO
--مشاهده دیتا تایپ های غیر مجاز
SELECT * FROM INFORMATION_SCHEMA.COLUMNS
	WHERE DATA_TYPE IN('TEXT','NTEXT','IMAGE')
GO
--------------------------------------------------------------------
--SET STATISTICS IO بررسی مثال بعد از 
GO
--استفاده کنیمText,NText,Image چرا نباید از دیتا تایپ 
GO
USE tempdb
GO
--بررسی وجود جدول
IF OBJECT_ID('Table1')>0
	DROP TABLE Table1
GO
--ایجاد جدول
CREATE TABLE Table1
(
	ID INT IDENTITY PRIMARY KEY,
	InsertDate DATETIME,
	Comments TEXT
)
GO
IF OBJECT_ID('Table2')>0
	DROP TABLE Table2
GO
--ایجاد جدول
CREATE TABLE Table2
(
	ID INT IDENTITY PRIMARY KEY,
	InsertDate DATETIME,
	Comments VARCHAR(MAX)
)
GO
--بررسی ایندکس های هر دو جدول
EXEC sp_helpindex Table1
EXEC sp_helpindex Table2
GO
--درج رکورد های تستی در هر دو جدول
INSERT INTO Table1(InsertDate,Comments) VALUES (GETDATE(),'Masoud Taheri')
GO 1000
INSERT INTO Table2(InsertDate,Comments) VALUES (GETDATE(),'Masoud Taheri')
GO 1000
--بررسی حجم رکوردهای موجود در جداول
EXEC sp_spaceused Table1
EXEC sp_spaceused Table2
GO
--IO بررسی وضعیت 
SET STATISTICS IO ON 
SELECT * FROM Table1
SELECT * FROM Table2
SET STATISTICS IO OFF
GO
--Execution Plan مقایسه
SELECT * FROM Table1
SELECT * FROM Table2