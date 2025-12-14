import hashlib
from flask import Flask, render_template, request, redirect, url_for, flash, session
from app.database import get_db_connection
import os

app = Flask(__name__)
# Asegúrate de que SECRET_KEY esté en tu .env
app.secret_key = os.getenv('SECRET_KEY') or 'clave_secreta_por_defecto'


# Función auxiliar para hashear
def hashear_password(password):
    return hashlib.sha256(password.encode('utf-8')).hexdigest()


# --- RUTA DE INICIO ---
@app.route('/')
def index():
    if 'usuario' in session:
        return redirect(url_for('votar'))
    return redirect(url_for('login'))


# --- RUTA DE LOGIN ---
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        codigo = request.form['codigo'].strip().upper()
        password_input = request.form['password']
        password_hash_input = hashear_password(password_input)

        conn = get_db_connection()
        if not conn:
            flash("Error crítico: No se pudo conectar a la BD", "danger")
            return render_template('login.html')

        cursor = conn.cursor()

        try:
            query = "SELECT Codigo_UNI, Nombre, Password_Hash, Ha_Votado FROM USUARIO WHERE Codigo_UNI = ?"
            cursor.execute(query, (codigo,))
            user = cursor.fetchone()

            if user:
                db_hash = user[2]
                if db_hash == password_hash_input:
                    # LOGIN EXITOSO
                    session['usuario'] = user[0]
                    session['nombre'] = user[1]

                    if user[3] == 1:
                        flash('Bienvenido. Ya has registrado tu voto anteriormente.', 'info')
                        # Si quieres ver resultados o logout, redirigimos a votar igual
                        # para que vea el menú, o a resultados.
                        return redirect(url_for('resultados'))

                    return redirect(url_for('votar'))
                else:
                    flash('Contraseña incorrecta.', 'danger')
            else:
                flash('Usuario no encontrado.', 'danger')

        except Exception as e:
            flash(f"Error en login: {e}", 'danger')
        finally:
            if conn: conn.close()

    return render_template('login.html')


# --- RUTA DE VOTACIÓN ---
@app.route('/votar', methods=['GET', 'POST'])
def votar():
    if 'usuario' not in session:
        return redirect(url_for('login'))

    conn = get_db_connection()
    if not conn:
        flash("Error de conexión a BD", "danger")
        return redirect(url_for('login'))

    cursor = conn.cursor()

    if request.method == 'POST':
        codigo_alumno = session['usuario']
        id_lista = request.form.get('lista_electoral')
        ip_cliente = request.remote_addr

        if not id_lista:
            flash("Por favor, selecciona una lista antes de votar.", "warning")
        else:
            try:
                # LLAMADA AL STORED PROCEDURE
                cursor.execute("{CALL sp_RegistrarVoto_Seguro (?, ?, ?)}",
                               (codigo_alumno, id_lista, ip_cliente))
                conn.commit()
                flash('¡Voto registrado exitosamente!', 'success')
                conn.close()
                return redirect(url_for('resultados'))  # Redirige a resultados tras votar

            except Exception as e:
                conn.rollback()
                error_msg = str(e)
                if "Alerta de Seguridad" in error_msg:
                    flash("ERROR: Ya has emitido tu voto.", 'danger')
                else:
                    flash(f"Error al procesar: {error_msg}", 'danger')

    # GET: Mostrar listas
    try:
        cursor.execute("SELECT ID_Lista, Nombre, Descripcion FROM LISTA_ELECTORAL")
        listas = cursor.fetchall()
        return render_template('votar.html', listas=listas, nombre_usuario=session.get('nombre'))
    except Exception as e:
        flash(f"Error cargando listas: {e}", 'danger')
        return redirect(url_for('login'))
    finally:
        if conn:
            try:
                conn.close()
            except:
                pass


# --- RUTA DE RESULTADOS CON GRÁFICOS ---
@app.route('/resultados')
def resultados():
    # 1. Seguridad: Solo usuarios logueados pueden ver resultados
    if 'usuario' not in session:
        return redirect(url_for('login'))

    conn = get_db_connection()
    if not conn:
        flash("Error de conexión al obtener resultados", "danger")
        return redirect(url_for('login'))

    cursor = conn.cursor()

    try:
        # 2. Consultar votos ordenados de mayor a menor
        query = "SELECT Nombre, Cantidad_Votos, Descripcion FROM LISTA_ELECTORAL ORDER BY Cantidad_Votos DESC"
        cursor.execute(query)
        datos = cursor.fetchall()  # Trae todas las filas

        # 3. Calcular el total absoluto de votos para sacar porcentajes
        total_votos = sum(fila.Cantidad_Votos for fila in datos)

        # 4. Preparar datos para el HTML (Calculamos % aquí para no ensuciar el HTML)
        resultados_procesados = []
        for fila in datos:
            porcentaje = 0
            if total_votos > 0:
                porcentaje = round((fila.Cantidad_Votos / total_votos) * 100, 1)

            resultados_procesados.append({
                'nombre': fila.Nombre,
                'votos': fila.Cantidad_Votos,
                'porcentaje': porcentaje,
                'descripcion': fila.Descripcion
            })

        return render_template('resultados.html',
                               resultados=resultados_procesados,
                               total=total_votos,
                               usuario_nombre=session.get('nombre'))

    except Exception as e:
        flash(f"Error al cargar resultados: {e}", 'danger')
        return redirect(url_for('login'))
    finally:
        if conn: conn.close()

# --- RUTA DE LOGOUT (LA QUE FALTABA) ---
@app.route('/logout')
def logout():
    session.clear()
    flash('Has cerrado sesión correctamente.', 'info')
    return redirect(url_for('login'))