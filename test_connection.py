import pyodbc

# CONFIGURACIÓN BÁSICA (Ajusta si tu BD tiene otro nombre)
DB_NAME = "BD_Votacion_FIEE"

# LISTA DE VARIANTES A PROBAR
# Probaremos diferentes formas de escribir el servidor y el driver
servidores = [
    r".\SQLEXPRESS",  # El punto significa "esta máquina" (Más común)
    r"localhost\SQLEXPRESS",  # Localhost estándar
    r"(local)\SQLEXPRESS",  # Alias de SQL
    r"DESKTOP-RGDOC8P\SQLEXPRESS",  # Tu nombre de PC específico
    r"127.0.0.1\SQLEXPRESS",  # IP local
    r".",  # A veces la instancia por defecto es solo punto
    r"localhost"  # A veces es solo localhost
]

drivers = [
    "{SQL Server}",  # Driver genérico (viene en todos los Windows)
    "{ODBC Driver 17 for SQL Server}"  # Driver moderno
]

print("--- INICIANDO DIAGNÓSTICO DE CONEXIÓN ---")

exito = False

for server in servidores:
    for driver in drivers:
        print(f"\nProbando con:\n SERVER: {server}\n DRIVER: {driver}")

        # Intentamos conexión con Autenticación de Windows (Trusted_Connection)
        conn_str = (
            f"DRIVER={driver};"
            f"SERVER={server};"
            f"DATABASE={DB_NAME};"
            f"Trusted_Connection=yes;"
        )

        try:
            conn = pyodbc.connect(conn_str, timeout=3)
            print("  ✅ ¡CONEXIÓN EXITOSA!")
            print("  --------------------------------------------------")
            print(f"  >>> COPIA ESTO EN TU .ENV <<<")
            print(f"  DB_DRIVER={driver}")
            # En el .env a veces hay que escapar la barra, pero intenta primero tal cual
            print(f"  DB_SERVER={server}")
            print("  --------------------------------------------------")
            conn.close()
            exito = True
            break  # Salir del loop de drivers
        except Exception as e:
            # Simplificamos el error para no llenar la pantalla
            err_msg = str(e).split(']')[0] if ']' in str(e) else str(e)
            print(f"  ❌ Falló: {err_msg}...")

    if exito: break  # Salir del loop de servidores

if not exito:
    print("\n--- DIAGNÓSTICO FINAL: FALLÓ ---")
    print("Posibles causas:")
    print("1. El servicio 'SQL Server Browser' está detenido (Requerido para instancias con nombre).")
    print("2. El protocolo TCP/IP está deshabilitado en SQL Configuration Manager.")
    print("3. Tu instancia no se llama 'SQLEXPRESS'. Revisa en 'Servicios' de Windows.")