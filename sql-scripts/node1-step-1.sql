CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'y0ur$ecUr3PAssw0rd';  
GO

 CREATE CERTIFICATE SQLAO1_cert
 WITH SUBJECT = 'SQLAO1_cert_Private - Node 1',
 START_DATE = '20180301'
 GO
--CREATE CERTIFICATE SQLAO1_cert FROM FILE='c:\TempDSCAssets\SQLAO1_cert.cer' 
--    WITH PRIVATE KEY(FILE='c:\TempDSCAssets\SQLAO1_key.pvk', DECRYPTION BY PASSWORD='y0ur$ecUr3PAssw0rd'); 
--GO

-- Backup the public key of the certificate to the filesystem
-- BACKUP CERTIFICATE SQLAO1_cert
-- TO FILE = 'c:\TempDSCAssets\SQLAO1_cert.cert'
-- GO
BACKUP CERTIFICATE SQLAO1_cert
TO FILE = 'c:\TempDSCAssets\SQLAO1_cert.cert'
    WITH PRIVATE KEY   
    (   
        FILE = 'c:\TempDSCAssets\SQLAO1_key.pvk' ,  
        ENCRYPTION BY PASSWORD = 'y0ur$ecUr3PAssw0rd'   
        --, DECRYPTION BY PASSWORD = 'y0ur$ecUr3PAssw0rd'   
    )
GO

CREATE ENDPOINT Endpoint_AvailabilityGroup 
STATE = STARTED  
AS TCP
(
   LISTENER_PORT = 5022, LISTENER_IP = ALL
)  
   FOR DATABASE_MIRRORING 
(
   AUTHENTICATION = CERTIFICATE SQLAO1_cert, 
   ENCRYPTION = REQUIRED ALGORITHM AES,
   ROLE = ALL 
);  
GO