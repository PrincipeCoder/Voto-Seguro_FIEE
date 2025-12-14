import pyodbc
import os
from dotenv import load_dotenv

# Cargar variables de entorno
load_dotenv()


def get_db_connection():
    """
    Establece la conexión con SQL Server usando autenticación segura.
    Retorna el objeto conexión o lanza una excepción controlada.
    """
    try:
        connection_string = (
            f"DRIVER={os.getenv('DB_DRIVER')};"
            f"SERVER={os.getenv('DB_SERVER')};"
            f"DATABASE={os.getenv('DB_NAME')};"
            f"Trusted_Connection=yes;"  # Cambiar a 'no' si usas usuario/pass de SQL
            # f"UID={os.getenv('DB_USER')};" # Descomentar si no usas Auth de Windows
            # f"PWD={os.getenv('DB_PASSWORD')};"
        )

        conn = pyodbc.connect(connection_string)
        return conn
    except Exception as e:
        print(f"Error crítico de conexión a BD: {e}")
        return None