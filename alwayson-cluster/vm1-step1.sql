USE master
GO

RESTORE DATABASE Northwind
	FROM DISK = N'c:\Northwind.bak'
GO

ALTER DATABASE Northwind SET RECOVERY FULL;  
GO

CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'y0ur$ecUr3PAssw0rd';  
GO

CREATE CERTIFICATE SQLAO_VM1_cert FROM FILE='c:\SQLAO_VM1_cert.cer'
	WITH PRIVATE KEY(FILE='c:\SQLAO_VM1_key.pvk', DECRYPTION BY PASSWORD='y0ur$ecUr3PAssw0rd');
GO

CREATE LOGIN login_AvailabilityGroup 
WITH PASSWORD = 'y0ur$ecUr3PAssw0rd';  
GO

CREATE USER login_AvailabilityGroup  
FOR LOGIN login_AvailabilityGroup  
GO

CREATE CERTIFICATE SQLAO_VM2_cert
AUTHORIZATION login_AvailabilityGroup
FROM FILE='c:\SQLAO_VM2_cert.cer'
	WITH PRIVATE KEY(FILE='c:\SQLAO_VM2_key.pvk', DECRYPTION BY PASSWORD='y0ur$ecUr3PAssw0rd');
GO

CREATE ENDPOINT Endpoint_AvailabilityGroup 
STATE = STARTED  
AS TCP
(
   LISTENER_PORT = 5022, LISTENER_IP = ALL
)  
   FOR DATABASE_MIRRORING 
(
   AUTHENTICATION = CERTIFICATE SQLAO_VM1_cert, 
   ENCRYPTION = REQUIRED ALGORITHM AES,
   ROLE = ALL 
);  
GO

GRANT CONNECT ON ENDPOINT::Endpoint_AvailabilityGroup 
TO login_AvailabilityGroup;
GO