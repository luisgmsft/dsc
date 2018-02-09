-- Restore the Full Backup with NORECOVEY
RESTORE DATABASE TestDatabase1 FROM DISK = 'c:\TempDSCAssets\TestDatabase1.bak' WITH NORECOVERY
GO
 
-- Restore the TxLog Backup with NORECOVERY
RESTORE LOG TestDatabase1 FROM DISK = 'c:\TempDSCAssets\TestDatabase1.trn' WITH NORECOVERY
GO
 
-- Move the database into the Availability Group
ALTER DATABASE TestDatabase1 SET HADR AVAILABILITY GROUP = sqlaocl
GO