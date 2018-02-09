USE master
GO
 
-- Create a new database
CREATE DATABASE TestDatabase1
GO
 
-- Use the database
USE TestDatabase1
GO
 
-- Create a simple table
CREATE TABLE Foo
(
	Bar INT NOT NULL
)
GO
 
-- Make a Full Backup of the database
BACKUP DATABASE TestDatabase1 TO DISK = 'c:\TempDSCAssets\TestDatabase1.bak'
GO
 
USE master
GO

ALTER SERVER ROLE [sysadmin] ADD MEMBER [NT AUTHORITY\SYSTEM]
GO

-- Create a new Availability Group with 2 replicas
CREATE AVAILABILITY GROUP sqlaoag
WITH
(
	AUTOMATED_BACKUP_PREFERENCE = PRIMARY,
	DB_FAILOVER = ON,
	DTC_SUPPORT = NONE
)
FOR DATABASE [TestDatabase1]
REPLICA ON
'sqlao1' WITH
(
	ENDPOINT_URL = 'TCP://sqlao1.lugizi.ao.contoso.com:5022',
	FAILOVER_MODE = AUTOMATIC,
	AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
	BACKUP_PRIORITY = 50,
	SECONDARY_ROLE
	(
		ALLOW_CONNECTIONS = NO
	),
	SEEDING_MODE = AUTOMATIC
),
'sqlao2' WITH
(
	ENDPOINT_URL = 'TCP://sqlao2.lugizi.ao.contoso.com:5022',
	FAILOVER_MODE = AUTOMATIC,
	AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
	BACKUP_PRIORITY = 50,
	SECONDARY_ROLE
	(
		ALLOW_CONNECTIONS = NO
	),
	SEEDING_MODE = AUTOMATIC
)
GO