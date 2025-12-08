/* ========================================================================
   OBJETO: TRIGGER
   NOMBRE: trg_Alertar_Cambio_Usuario
   DESCRIPCIÓN: Audita cambios manuales en la tabla de usuarios.
   ======================================================================== */
CREATE TRIGGER trg_Alertar_Cambio_Usuario
ON USUARIO
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Detectar si se modificó el flag 'Ha_Votado'
    IF UPDATE(Ha_Votado)
    BEGIN
        DECLARE @Codigo_Afectado CHAR(9);
        DECLARE @Estado_Antiguo BIT;
        DECLARE @Estado_Nuevo BIT;

        SELECT @Codigo_Afectado = Codigo_UNI, @Estado_Nuevo = Ha_Votado FROM inserted;
        SELECT @Estado_Antiguo = Ha_Votado FROM deleted;

        -- Si alguien "resetea" el voto (Cambio de 1 a 0), es ALTA CRITICIDAD
        IF (@Estado_Antiguo = 1 AND @Estado_Nuevo = 0)
        BEGIN
            INSERT INTO AUDITORIA_SEGURIDAD (Accion, IP_Origen, Detalle, Codigo_UNI)
            VALUES ('ALERTA_FRAUDE', 'INTERNAL', 'Se reseteó manualmente el estado HA_VOTADO del usuario.', @Codigo_Afectado);
        END
    END
END;
GO