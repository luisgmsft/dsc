USE master
GO

ALTER AVAILABILITY GROUP [SQLAOAG] JOIN;
GO

-- REQUIRES 5022 port Windows Firewall rule pass at all nodes (In/Out)
ALTER DATABASE [Northwind] 
SET HADR AVAILABILITY GROUP = [SQLAOAG];
GO