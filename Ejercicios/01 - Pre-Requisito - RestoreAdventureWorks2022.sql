-- ==============================================================
-- Workshop Dataset: AdventureWorks2022 OLTP - Modelo Estrella Optimizado (Final)
-- Autor: Mariano Kovo Microsoft MVP 
-- Taller de Modelado y Optimización
-- ==============================================================
-- PRE-REQUISITO 1
-- Restore de Base de Datos AdventureWorks2022
-- Restore de Base de Datos AdventureWorks2022LT
-- Modificar parámetros de Ubicaciones en Disco
-- =============================================================


USE [master]

RESTORE DATABASE [AdventureWorks2022] FROM  DISK = N'F:\Backups\AdventureWorks2022.bak' 
WITH  FILE = 1,  
MOVE N'AdventureWorks2022' TO N'F:\data\AdventureWorks2022.mdf',  
MOVE N'AdventureWorks2022_log' TO N'G:\log\AdventureWorks2022_log.ldf',  
NOUNLOAD,  REPLACE,  STATS = 5

GO

ALTER DATABASE [AdventureWorks2022] MODIFY FILE ( NAME = N'AdventureWorks2022', FILEGROWTH = 1048576KB )
GO
ALTER DATABASE [AdventureWorks2022] MODIFY FILE ( NAME = N'AdventureWorks2022_log', FILEGROWTH = 1048576KB )
GO


RESTORE DATABASE [AdventureWorksLT2022] FROM  DISK = N'F:\Backups\AdventureWorksLT2022.bak' 
WITH  FILE = 1,  
MOVE N'AdventureWorksLT2022_Data' TO N'F:\data\AdventureWorksLT2022.mdf',  
MOVE N'AdventureWorksLT2022_Log' TO N'G:\log\AdventureWorksLT2022_log.ldf',  
NOUNLOAD,  REPLACE,  STATS = 5

GO

