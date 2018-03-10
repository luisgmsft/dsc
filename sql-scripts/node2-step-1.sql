ALTER SERVER ROLE [sysadmin] ADD MEMBER [sqlao2\testadminuser]
GO

CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'y0ur$ecUr3PAssw0rd';  
GO

CREATE CERTIFICATE SQLAO2_cert FROM FILE='c:\TempDSCAssets\SQLAO2_cert.cert' 
    WITH PRIVATE KEY(FILE='c:\TempDSCAssets\SQLAO2_key.pvk'
    , DECRYPTION BY PASSWORD='y0ur$ecUr3PAssw0rd'); 
GO

--
-- For manual creation and exchange between nodes
--
-- CREATE CERTIFICATE SQLAO2_cert
-- WITH SUBJECT = 'SQLAO2_cert_Private - Node 2',
-- START_DATE = '20180301'
-- GO
-- BACKUP CERTIFICATE SQLAO2_cert
-- TO FILE = 'c:\TempDSCAssets\SQLAO2_cert.cert'
--     WITH PRIVATE KEY   
--     (   
--         FILE = 'c:\TempDSCAssets\SQLAO2_key.pvk' ,  
--         ENCRYPTION BY PASSWORD = 'y0ur$ecUr3PAssw0rd'   
--     )
-- GO

CREATE ENDPOINT Endpoint_AvailabilityGroup 
STATE = STARTED  
AS TCP
(
   LISTENER_PORT = 5022, LISTENER_IP = ALL
)  
   FOR DATABASE_MIRRORING 
(
   AUTHENTICATION = CERTIFICATE SQLAO2_cert, 
   ENCRYPTION = REQUIRED ALGORITHM AES,
   ROLE = ALL 
);  
GO