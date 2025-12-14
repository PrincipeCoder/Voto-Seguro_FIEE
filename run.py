import os
from app.routes import app

# Configuración de ejecución
if __name__ == '__main__':
    # debug=True permite que el servidor se reinicie si haces cambios en el código
    # y muestra errores detallados en el navegador (Ideal para desarrollo)
    print("--- INICIANDO SISTEMA DE VOTACIÓN FIEE-UNI ---")
    print("--- Modo: Desarrollo (Debug Activo) ---")
    app.run(debug=True, host='0.0.0.0', port=5000)