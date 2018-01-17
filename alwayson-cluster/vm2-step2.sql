USE master
GO

ALTER AVAILABILITY GROUP SQLAOAG JOIN;
GO

RESTORE DATABASE Northwind
	FROM DISK = N'c:\TempDSCAssets\Northwind.bak'
    WITH NORECOVERY
GO

-- REQUIRES 5022 port Windows Firewall rule pass at all nodes (In/Out)
ALTER DATABASE Northwind 
SET HADR AVAILABILITY GROUP = SQLAOAG;
GO