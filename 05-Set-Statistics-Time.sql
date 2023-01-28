--------------------------------------------------------------------

--------------------------------------------------------------------
USE ClinicPooya
GO
--پاک کردن محتویات کش و حافظه
DBCC DROPCLEANBUFFERS
DBCC FREEPROCCACHE
GO
--Dirty Page انتقال محتوای
CHECKPOINT
GO
SET STATISTICS TIME ON
GO
SELECT * FROM tbGhabzPaziresh WHERE IDGhabz=5000
GO
SELECT * FROM tbGhabzPaziresh
GO
SET STATISTICS TIME ON
--------------------------
/*
بررسی منوی 
Query -> Query Options
*/