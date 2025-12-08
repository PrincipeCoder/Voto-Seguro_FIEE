/* ========================================================================
   OBJETO: STORED PROCEDURE
   NOMBRE: sp_RegistrarVoto_Seguro
   DESCRIPCIÓN: Gestiona la transacción del voto con lógica Blockchain.
   ======================================================================== */
CREATE PROCEDURE sp_RegistrarVoto_Seguro
    @Codigo_UNI CHAR(9),
    @ID_Lista_Votada INT,
    @IP_Cliente VARCHAR(45)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Declaración de variables para la lógica Blockchain
    DECLARE @Hash_Anterior CHAR(64);
    DECLARE @Nuevo_Hash VARBINARY(32); -- SHA256 genera 32 bytes
    DECLARE @Nuevo_Hash_String CHAR(64);
    DECLARE @Fecha_Actual DATETIME2(3) = SYSDATETIME();

    -- Iniciar Transacción (ACID)
    BEGIN TRANSACTION;

    BEGIN TRY
        -- 1. VALIDACIONES DE SEGURIDAD
        -- ¿El usuario existe?
        IF NOT EXISTS (SELECT 1 FROM USUARIO WHERE Codigo_UNI = @Codigo_UNI)
        BEGIN
            THROW 51000, 'Error: El usuario no existe en el padrón.', 1;
        END

        -- ¿El usuario ya votó? (Prevención de Doble Voto)
        IF EXISTS (SELECT 1 FROM USUARIO WHERE Codigo_UNI = @Codigo_UNI AND Ha_Votado = 1)
        BEGIN
            THROW 51000, 'Alerta de Seguridad: Este usuario ya ha emitido su voto.', 1;
        END

        -- 2. LÓGICA BLOCKCHAIN (Obtener Hash Anterior)
        -- Si es el primer voto (bloque génesis), usamos ceros.
        SELECT TOP 1 @Hash_Anterior = Hash_Voto 
        FROM BLOQUE_VOTO 
        ORDER BY ID_Voto DESC;

        IF @Hash_Anterior IS NULL
            SET @Hash_Anterior = '0000000000000000000000000000000000000000000000000000000000000000';

        -- 3. CALCULAR NUEVO HASH (Criptografía)
        -- Concatenamos: Codigo + ID_Lista + Fecha + HashAnterior
        -- Usamos SHA2_256 (Estándar de seguridad actual)
        SET @Nuevo_Hash = HASHBYTES('SHA2_256', 
            CONCAT(@Codigo_UNI, CAST(@ID_Lista_Votada AS VARCHAR), FORMAT(@Fecha_Actual, 'yyyyMMddHHmmssfff'), @Hash_Anterior)
        );
        
        -- Convertir de Binario a String Hexadecimal
        SET @Nuevo_Hash_String = CONVERT(VARCHAR(64), @Nuevo_Hash, 2);

        -- 4. INSERTAR EL BLOQUE (VOTO)
        INSERT INTO BLOQUE_VOTO (Hash_Voto, Hash_Anterior, Fecha_Hora, Codigo_UNI, ID_Lista_Votada)
        VALUES (@Nuevo_Hash_String, @Hash_Anterior, @Fecha_Actual, @Codigo_UNI, @ID_Lista_Votada);

        -- 5. ACTUALIZAR ESTADO DEL USUARIO
        UPDATE USUARIO 
        SET Ha_Votado = 1 
        WHERE Codigo_UNI = @Codigo_UNI;

        -- 6. ACTUALIZAR CONTEO DE LA LISTA (Desnormalización para velocidad de lectura)
        UPDATE LISTA_ELECTORAL
        SET Cantidad_Votos = Cantidad_Votos + 1
        WHERE ID_Lista = @ID_Lista_Votada;

        -- 7. AUDITORÍA EXITOSA
        INSERT INTO AUDITORIA_SEGURIDAD (Accion, IP_Origen, Detalle, Codigo_UNI)
        VALUES ('VOTO_EXITOSO', @IP_Cliente, 'Voto registrado y bloque minado: ' + LEFT(@Nuevo_Hash_String, 10) + '...', @Codigo_UNI);

        -- Confirmar Transacción
        COMMIT TRANSACTION;
        
        SELECT 'OK' AS Estado, 'Voto registrado correctamente.' AS Mensaje, @Nuevo_Hash_String AS Hash_Generado;

    END TRY
    BEGIN CATCH
        -- En caso de error, deshacer todo (Rollback)
        ROLLBACK TRANSACTION;

        -- Registrar el intento fallido en Auditoría
        INSERT INTO AUDITORIA_SEGURIDAD (Accion, IP_Origen, Detalle, Codigo_UNI)
        VALUES ('ERROR_VOTACION', @IP_Cliente, ERROR_MESSAGE(), @Codigo_UNI);

        -- Retornar el error a la aplicación Python
        THROW;
    END CATCH
END;
GO