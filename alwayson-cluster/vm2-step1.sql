USE master  

CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'y0ur$ecUr3PAssw0rd';  
GO

CREATE CERTIFICATE SQLAO_VM2_cert 
WITH SUBJECT = 'SQLAO-VM2 certificate for Availability Group' 
GO

CREATE ENDPOINT Endpoint_AvailabilityGroup 
STATE = STARTED 
AS TCP 
(
   LISTENER_PORT = 5022, LISTENER_IP = ALL
)  
   FOR DATABASE_MIRRORING 
(
   AUTHENTICATION = CERTIFICATE SQLAO_VM2_cert, 
   ENCRYPTION = REQUIRED ALGORITHM AES,
   ROLE = ALL 
);  
GO

BACKUP CERTIFICATE SQLAO_VM2_cert 
TO FILE = 'C:\SQLAG\SQLAO_VM2_cert.cer';  
GO

----------------------
CREATE LOGIN login_AvailabilityGroup 
WITH PASSWORD = 'y0ur$ecUr3PAssw0rd';  
GO

CREATE USER login_AvailabilityGroup  
FOR LOGIN login_AvailabilityGroup  
GO

--Associate certificate from SQLAO-VM1 with user
CREATE CERTIFICATE SQLAO_VM1_cert  
AUTHORIZATION login_AvailabilityGroup  
FROM FILE = 'C:\SQLAG\SQLAO_VM1_cert.cer'  
GO

GRANT CONNECT ON ENDPOINT::Endpoint_AvailabilityGroup 
TO [login_AvailabilityGroup];    
GO