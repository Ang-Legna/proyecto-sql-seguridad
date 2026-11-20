-- Ejercicio inicial: Enmascaramiento dinámico de datos (Dynamic Data Masking)
CREATE DATABASE LabSeguridad;
GO
USE LabSeguridad;
GO

CREATE TABLE Clientes (
    Id INT PRIMARY KEY,
    Nombre VARCHAR(50),
    Correo VARCHAR(100) MASKED WITH (FUNCTION = 'email()'),
    Tarjeta VARCHAR(25) MASKED WITH (FUNCTION = 'partial(0,"XXXX-XXXX-XXXX-",4)')
);
GO

INSERT INTO Clientes VALUES
(1, 'Ana Perez', 'ana.perez@correo.com', '4532111122229876'),
(2, 'Carlos Ruiz', 'carlos.ruiz@empresa.org', '5412999988881234');
GO

-- Consulta como administrador (sa): datos sin enmascarar
SELECT * FROM Clientes;
GO

CREATE USER UsuarioLectura WITHOUT LOGIN;
GRANT SELECT ON Clientes TO UsuarioLectura;
GO

-- Consulta como usuario sin privilegios: datos enmascarados
EXECUTE AS USER = 'UsuarioLectura';
SELECT * FROM Clientes;
REVERT;
GO
