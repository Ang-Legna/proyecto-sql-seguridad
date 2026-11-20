USE LabSeguridad;
GO

-- ============================================================================
-- SECCIÓN A: CIFRADO A NIVEL DE COLUMNA (Ejecutable en SQL Server / Docker)
-- ============================================================================

-- 1. Crear la clave maestra de la base de datos y el certificado
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'StrongPassword123!';
GO

CREATE CERTIFICATE SensitiveDataCert
WITH SUBJECT = 'Certificate for sensitive data encryption';
GO

-- 2. Crear la clave simétrica protegida por el certificado
CREATE SYMMETRIC KEY SensitiveDataKey
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE SensitiveDataCert;
GO

-- 3. Crear la tabla destino (necesaria antes del INSERT de Learn)
CREATE TABLE CustomerData (
    CustomerID INT PRIMARY KEY,
    CreditCardNumber VARBINARY(256)
);
GO

-- 4. Abrir la clave simétrica e insertar los datos cifrados
OPEN SYMMETRIC KEY SensitiveDataKey
DECRYPTION BY CERTIFICATE SensitiveDataCert;

INSERT INTO CustomerData (CustomerID, CreditCardNumber)
VALUES (1, ENCRYPTBYKEY(KEY_GUID('SensitiveDataKey'), '4111-1111-1111-1111'));

CLOSE SYMMETRIC KEY SensitiveDataKey;
GO

-- 5. Verificar resultado: dato cifrado vs. dato descifrado
SELECT CustomerID, CreditCardNumber AS DatoCifradoEnTabla
FROM CustomerData;
GO

OPEN SYMMETRIC KEY SensitiveDataKey
DECRYPTION BY CERTIFICATE SensitiveDataCert;

SELECT CustomerID, 
       CONVERT(varchar(20), DECRYPTBYKEY(CreditCardNumber)) AS CardNumber
FROM CustomerData;

CLOSE SYMMETRIC KEY SensitiveDataKey;
GO


-- ============================================================================
-- SECCIÓN B: ALWAYS ENCRYPTED CON AZURE KEY VAULT (Referencia sintáctica)
-- Nota: Comentado porque requiere suscripción activa a Azure Key Vault y 
-- certificados de cliente generados fuera del motor SQL.
-- ============================================================================
/*
CREATE COLUMN MASTER KEY MyCMK
WITH (
    KEY_STORE_PROVIDER_NAME = 'AZURE_KEY_VAULT',
    KEY_PATH = 'https://mykeyvault.vault.azure.net/keys/MyCMK/abc123'
);

CREATE COLUMN ENCRYPTION KEY MyCEK
WITH VALUES (
    COLUMN_MASTER_KEY = MyCMK,
    ALGORITHM = 'RSA_OAEP',
    ENCRYPTED_VALUE = 0x01700000016C006F00...
);

CREATE TABLE Employees (
    EmployeeID int PRIMARY KEY,
    SSN char(11) COLLATE Latin1_General_BIN2
        ENCRYPTED WITH (
            ENCRYPTION_TYPE = DETERMINISTIC,
            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256',
            COLUMN_ENCRYPTION_KEY = MyCEK
        ),
    Salary money
        ENCRYPTED WITH (
            ENCRYPTION_TYPE = RANDOMIZED,
            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256',
            COLUMN_ENCRYPTION_KEY = MyCEK
        )
);
*/