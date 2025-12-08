/* ========================================================================
   OBJETO: TRIGGER
   NOMBRE: trg_Inmutabilidad_Blockchain
   DESCRIPCIÓN: Impide UPDATE o DELETE en la tabla de votos para garantizar
                la inmutabilidad del ledger.
   ======================================================================== */
CREATE TRIGGER trg_Inmutabilidad_Blockchain
ON BLOQUE_VOTO
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    -- Si alguien intenta modificar los votos desde el Management Studio o por inyección:
    RAISERROR ('ALERTA DE SEGURIDAD: Violación de integridad. El Ledger de votos es INMUTABLE. No se permiten modificaciones ni eliminaciones.', 16, 1);
    
    -- Opcional: Registrar el intento de ataque en auditoría
    INSERT INTO AUDITORIA_SEGURIDAD (Accion, IP_Origen, Detalle, Codigo_UNI)
    VALUES ('INTENTO_MANIPULACION_LEDGER', 'INTERNAL', 'Intento de UPDATE/DELETE en BLOQUE_VOTO bloqueado por Trigger.', NULL);
END;
GO