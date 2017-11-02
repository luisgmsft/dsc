USE [master]

GO

ALTER AVAILABILITY GROUP [SQLAO_AG] JOIN;
GO


-- REQUIRES 5022 port Windows Firewall rule pass at all nodes (In/Out)
ALTER DATABASE [Northwind] 
SET HADR AVAILABILITY GROUP = [SQLAO_AG];
GO
