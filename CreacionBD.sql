/* ========================================================================
PROYECTO: SISTEMA DE VOTACIÓN ELECTRÓNICA FIEE-UNI
SECCIÓN 4.4: MODELO FÍSICO (SCRIPT DDL)
MOTOR: SQL SERVER
DESCRIPCIÓN: Creación de base de datos, tablas y restricciones de integridad.
========================================================================
*/
USE master;
GO
-- 1. Creación de la Base de Datos con soporte de caracteres latinos (tildes/ñ)
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'BD_Votacion_FIEE')
    DROP DATABASE BD_Votacion_FIEE;
GO
CREATE DATABASE BD_Votacion_FIEE
GO
USE BD_Votacion_FIEE;
GO
-- ========================================================================
-- TABLA LISTA_ELECTORAL: Representa a las agrupaciones políticas estudiantiles.
-- ========================================================================
CREATE TABLE LISTA_ELECTORAL (
    ID_Lista INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL UNIQUE,
    Descripcion VARCHAR(255) NULL,
    Cantidad_Votos INT DEFAULT 0
);
GO
-- Insertamos una lista "Voto en Blanco" por defecto (Buena práctica)
INSERT INTO LISTA_ELECTORAL (Nombre, Descripcion) VALUES ('VOTO BLANCO', 'Voto nulo o viciado');
GO
-- ========================================================================
-- TABLA USUARIO: Alumnos de la FIEE. Contiene validaciones estrictas (CHECK).
-- ========================================================================
CREATE TABLE USUARIO (
    Codigo_UNI CHAR(9) PRIMARY KEY, -- Ej: 20210345G (Longitud fija)
    DNI CHAR(8) NOT NULL UNIQUE,
    Nombre VARCHAR(50) NOT NULL,
    Apellido_Paterno VARCHAR(50) NOT NULL,
    Apellido_Materno VARCHAR(50) NOT NULL,
    Ciclo_Relativo INT CHECK (Ciclo_Relativo BETWEEN 1 AND 10),
    -- Restricción para Especialidades permitidas
    Especialidad VARCHAR(50) NOT NULL CHECK (Especialidad IN ('Electrica', 'Electronica', 'Telecomunicaciones', 'Ciberseguridad')),    
    Pertenece_a_Lista BIT DEFAULT 0, -- 0: No, 1: Sí
    -- Restricción para Cargos permitidos (Solo si pertenece a lista)
    Cargo_en_Lista VARCHAR(20) NULL CHECK (
        Cargo_en_Lista IN ('Presidente', 'Vicepresidente', 'Secretario')
    ),
    ID_Lista_Pertenece INT NULL, -- FK recursiva lógica hacia listas
    Password_Hash CHAR(64) NOT NULL, -- Para SHA-256 (Hexadecimal)
    Ha_Votado BIT DEFAULT 0,
    -- Definición de la Llave Foránea
    CONSTRAINT FK_Usuario_Lista FOREIGN KEY (ID_Lista_Pertenece) 
        REFERENCES LISTA_ELECTORAL(ID_Lista)
);
GO
-- ========================================================================
-- TABLA BLOQUE_VOTO (El Ledger / Blockchain):
-- Esta tabla garantiza la inmutabilidad. 
-- Un usuario solo puede generar UN registro aquí (Relación 1 a 1).
-- ========================================================================
CREATE TABLE BLOQUE_VOTO (
    ID_Voto BIGINT IDENTITY(1,1) PRIMARY KEY,
    -- Datos de trazabilidad
    Hash_Voto CHAR(64) NOT NULL, -- Hash del bloque actual
    Hash_Anterior CHAR(64) NOT NULL DEFAULT '0000000000000000000000000000000000000000000000000000000000000000', 
    Fecha_Hora DATETIME2(3) DEFAULT SYSDATETIME(),
    -- Relaciones
    Codigo_UNI CHAR(9) NOT NULL UNIQUE, -- UNIQUE asegura 1 voto por alumno
    ID_Lista_Votada INT NOT NULL,
    CONSTRAINT FK_Voto_Usuario FOREIGN KEY (Codigo_UNI) 
        REFERENCES USUARIO(Codigo_UNI),      
    CONSTRAINT FK_Voto_Lista FOREIGN KEY (ID_Lista_Votada) 
        REFERENCES LISTA_ELECTORAL(ID_Lista)
);
GO
-- ========================================================================
-- TABLA AUDITORIA_SEGURIDAD: Registro forense de eventos.
-- ========================================================================
CREATE TABLE AUDITORIA_SEGURIDAD (
    ID_Evento BIGINT IDENTITY(1,1) PRIMARY KEY,
    Accion VARCHAR(50) NOT NULL, -- Ej: 'LOGIN_FAIL', 'VOTE_SUCCESS', 'SQL_INJECTION_DETECTED'
    IP_Origen VARCHAR(45) NULL,  -- Soporta IPv4 e IPv6
    Detalle VARCHAR(255) NULL,
    Fecha_Hora DATETIME2(3) DEFAULT SYSDATETIME(),
    Codigo_UNI CHAR(9) NULL,      -- Puede ser NULL si el ataque es anónimo
    CONSTRAINT FK_Auditoria_Usuario FOREIGN KEY (Codigo_UNI) 
        REFERENCES USUARIO(Codigo_UNI)
);
GO