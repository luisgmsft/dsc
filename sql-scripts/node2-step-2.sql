CREATE LOGIN login_AvailabilityGroup 
WITH PASSWORD = 'y0ur$ecUr3PAssw0rd';  
GO

CREATE USER login_AvailabilityGroup  
FOR LOGIN login_AvailabilityGroup  
GO
 
-- Import the public key portion of the certificate from the other node
CREATE CERTIFICATE SQLAO1_cert
AUTHORIZATION login_AvailabilityGroup
FROM FILE = 'c:\TempDSCAssets\SQLAO1_cert.cert'
GO
 
-- Grant the CONNECT permission to the login
GRANT CONNECT ON ENDPOINT::Endpoint_AvailabilityGroup 
TO login_AvailabilityGroup;
GO