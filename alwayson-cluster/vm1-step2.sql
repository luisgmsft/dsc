
----------------------
CREATE LOGIN login_AvailabilityGroup 
WITH PASSWORD = 'y0ur$ecUr3PAssw0rd';  
GO

CREATE USER login_AvailabilityGroup  
FOR LOGIN login_AvailabilityGroup  
GO

--Associate certificate from SQLAO-VM2 with user
CREATE CERTIFICATE SQLAO_VM2_cert  
AUTHORIZATION login_AvailabilityGroup  
FROM FILE = 'C:\SQLAG\SQLAO_VM2_cert.cer'  
GO

GRANT CONNECT ON ENDPOINT::Endpoint_AvailabilityGroup 
TO [login_AvailabilityGroup];    
GO