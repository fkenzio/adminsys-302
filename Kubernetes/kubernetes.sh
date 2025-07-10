#!/bin/bash

# Solo falta el servicio creo
function instalarMinikube(){
    sudo apt update -y
    sudo snap install kubectl --classic
    wget https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 -O minikube
    chmod 755 minikube 
    sudo mv minikube /usr/local/bin/
    minikube version
    minikube start --memory=2048 --cpus=2
    minikube status
}

function crearPods(){
  eval $(minikube docker-env)

  tee secret.yaml > /dev/null << EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: flaskapi-secrets
type: Opaque
data:
  db_root_password: YWRtaW4=
EOF

  kubectl apply -f secret.yaml

  tee configmapmysql.yaml > /dev/null << EOF
kind: ConfigMap
apiVersion: v1
metadata:
  name: mysql-config
data:
  confluence.cnf: |-
    [mysqld]
    character-set-server=utf8
    collation-server=utf8_bin
    default-storage-engine=INNODB
    max_allowed_packet=256M
    transaction-isolation=READ-COMMITTED
EOF

  kubectl apply -f configmapmysql.yaml

  tee crearpods.yaml > /dev/null << EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  labels:
    app: db
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: mysql
        image: mysql
        imagePullPolicy: Never
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: flaskapi-secrets
              key: db_root_password
        ports:
        - containerPort: 3306
          name: db-container
        volumeMounts:
          - name: mysql-persistent-storage
            mountPath: /var/lib/mysql
          - name: mysql-config-volume
            mountPath: /etc/mysql/conf.d
      volumes:
        - name: mysql-persistent-storage
          persistentVolumeClaim:
            claimName: mysql-pv-claim
        - name: mysql-config-volume
          configMap:
            name: mysql-config


---
apiVersion: v1
kind: Service
metadata:
  name: mysql
  labels:
    app: db
spec:
  ports:
  - port: 3306
    protocol: TCP
    name: mysql
  selector:
    app: db
  type: ClusterIP
EOF

  kubectl apply -f crearpods.yaml

  echo "Esperando a que el pod mysql esté listo..."
  kubectl wait --for=condition=ready pod -l app=db --timeout=120s

  kubectl run -i --rm --tty mysql-client --image=mysql --restart=Never -- \
  mysql --host=mysql --user=root --password=admin << EOF
CREATE DATABASE IF NOT EXISTS flaskapi;
USE flaskapi;
CREATE TABLE IF NOT EXISTS usuarios (
    idUsuario INT PRIMARY KEY AUTO_INCREMENT,
    firstName VARCHAR(255),
    Correo VARCHAR(255),
    Contrasena VARCHAR(255)
);
EOF
}


function mostrarLogs(){
    echo "Ingresa el nombre del pod: "
    read pod
    if ! kubectl logs "$pod" &>/dev/null; then
        echo "El pod ingresado no existe"
    else
        kubectl logs "$pod"
    fi
}

function desplegarApp(){
    eval $(minikube docker-env)

    # Código fuente de la API
    tee flaskapi.py > /dev/null <<EOF
import os
import socket
from flask import jsonify, request, Flask
from flaskext.mysql import MySQL

app = Flask(__name__)

mysql = MySQL()

app.config["MYSQL_DATABASE_USER"] = "root"
app.config["MYSQL_DATABASE_PASSWORD"] = os.getenv("db_root_password")
app.config["MYSQL_DATABASE_DB"] = os.getenv("db_name")
app.config["MYSQL_DATABASE_HOST"] = os.getenv("MYSQL_SERVICE_HOST")
app.config["MYSQL_DATABASE_PORT"] = int(os.getenv("MYSQL_SERVICE_PORT"))
mysql.init_app(app)

@app.route("/")
def index():
    return "¡Hola desde la versión inicial de la API!"

@app.route("/create", methods=["POST"])
def add_user():
    json = request.json
    firstName = json.get("firstName")
    Correo = json.get("Correo")
    Contrasena = json.get("Contrasena")
    if firstName and Correo and Contrasena and request.method == "POST":
        sql = "INSERT INTO usuarios (firstName, Correo, Contrasena) VALUES (%s, %s, %s)"
        data = (firstName, Correo, Contrasena)
        try:
            conn = mysql.connect()
            cursor = conn.cursor()
            cursor.execute(sql, data)
            conn.commit()
            cursor.close()
            conn.close()
            pod_name = socket.gethostname()
            resp = jsonify({"status": "Éxito", "message": "Usuario registrado correctamente", "pod_info": pod_name})
            resp.status_code = 201 # Changed to 201 for resource creation
            return resp
        except Exception as e:
            return jsonify({"status": "Error", "message": str(e)})
    else:
        return jsonify({"status": "Fallo", "message": "Se requieren firstName, Correo y Contrasena"})

@app.route("/users", methods=["GET"])
def users():
    try:
        conn = mysql.connect()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM usuarios")
        rows = cursor.fetchall()
        cursor.close()
        conn.close()
        pod_name = socket.gethostname()
        resp = jsonify({"status": "Éxito", "message": "Lista de usuarios obtenida", "pod_info": pod_name, "usuarios_data": rows})
        resp.status_code = 200
        return resp
    except Exception as e:
        return jsonify({"status": "Error", "message": str(e)})

@app.route("/user/<int:idUsuario>", methods=["GET"])
def user(idUsuario):
    try:
        conn = mysql.connect()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM usuarios WHERE idUsuario=%s", (idUsuario,))
        row = cursor.fetchone()
        cursor.close()
        conn.close()
        pod_name = socket.gethostname()
        resp = jsonify({"status": "Éxito", "message": "Detalles del usuario recuperados", "pod_info": pod_name, "user_detail": row})
        resp.status_code = 200
        return resp
    except Exception as e:
        return jsonify({"status": "Error", "message": str(e)})

@app.route("/update", methods=["POST"])
def update_user():
    json = request.json
    firstName = json.get("firstName")
    Correo = json.get("Correo")
    Contrasena = json.get("Contrasena")
    idUsuario = json.get("idUsuario")
    if firstName and Correo and Contrasena and idUsuario and request.method == "POST":
        sql = "UPDATE usuarios SET firstName=%s, Correo=%s, Contrasena=%s WHERE idUsuario=%s"
        data = (firstName, Correo, Contrasena, idUsuario)
        try:
            conn = mysql.connect()
            cursor = conn.cursor()
            cursor.execute(sql, data)
            conn.commit()
            cursor.close()
            conn.close()
            pod_name = socket.gethostname()
            resp = jsonify({"status": "Éxito", "message": "Información de usuario actualizada", "pod_info": pod_name})
            resp.status_code = 200
            return resp
        except Exception as e:
            return jsonify({"status": "Error", "message": str(e)})
    else:
        return jsonify({"status": "Fallo", "message": "Se requieren idUsuario, firstName, Correo y Contrasena para actualizar"})

@app.route("/delete/<int:idUsuario>")
def delete_user(idUsuario):
    try:
        conn = mysql.connect()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM usuarios WHERE idUsuario=%s", (idUsuario,))
        conn.commit()
        cursor.close()
        conn.close()
        pod_name = socket.gethostname()
        resp = jsonify({"status": "Éxito", "message": "Usuario eliminado del sistema", "pod_info": pod_name})
        resp.status_code = 200
        return resp
    except Exception as e:
        return jsonify({"status": "Error", "message": str(e)})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF

    # Dependencias
    tee requirements.txt > /dev/null <<EOF
Flask==1.0.3  
Flask-MySQL==1.4.0  
PyMySQL==0.9.3
uWSGI==2.0.17.1
mysql-connector-python
cryptography
EOF

    # Dockerfile
    tee Dockerfile > /dev/null <<EOF
FROM python:3.6-slim

RUN apt-get clean \
    && apt-get -y update

RUN apt-get -y install \
    nginx \
    python3-dev \
    build-essential

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install -r requirements.txt --src /usr/local/src

COPY . .

EXPOSE 5000
CMD [ "python", "flaskapi.py"]
EOF

    docker build . -t flask-api

    # ConfigMap
    tee ConfigMap.yaml > /dev/null <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_SETTING: "Mensaje desde el ConfigMap"  
EOF

    # Deployment
    tee Deployment.yaml > /dev/null <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flaskapi-deployment
  labels:
    app: flaskapi
spec:
  replicas: 3
  selector:
    matchLabels:
      app: flaskapi
  template:
    metadata:
      labels:
        app: flaskapi
    spec:
      containers:
        - name: flaskapi
          image: flask-api
          imagePullPolicy: Never
          ports:
            - containerPort: 5000
          env:
            - name: db_root_password
              valueFrom:
                secretKeyRef:
                  name: flaskapi-secrets
                  key: db_root_password
            - name: db_name
              value: flaskapi

---
apiVersion: v1
kind: Service
metadata:
  name: flask-service
spec:
  ports:
  - port: 5000
    protocol: TCP
    targetPort: 5000
  selector:
    app: flaskapi
  type: LoadBalancer
EOF

    # Aplicación de recursos
    kubectl apply -f ConfigMap.yaml
    kubectl apply -f Deployment.yaml

    echo "App desplegada satisfactoriamente"

    eval $(minikube docker-env -u)

    minikube service flask-service
}


function ejecutarRollingUpdate(){
  eval $(minikube docker-env)

  # Código fuente de la API adaptado a la tabla usuarios
  tee flaskapi.py > /dev/null <<EOF
import os
import socket
from flask import jsonify, request, Flask
from flaskext.mysql import MySQL

app = Flask(__name__)

mysql = MySQL()

# MySQL configurations
app.config["MYSQL_DATABASE_USER"] = "root"
app.config["MYSQL_DATABASE_PASSWORD"] = os.getenv("db_root_password")
app.config["MYSQL_DATABASE_DB"] = os.getenv("db_name")
app.config["MYSQL_DATABASE_HOST"] = os.getenv("MYSQL_SERVICE_HOST")
app.config["MYSQL_DATABASE_PORT"] = int(os.getenv("MYSQL_SERVICE_PORT"))
mysql.init_app(app)


@app.route("/")
def index():
    """Function to test the functionality of the API"""
    return "¡Bienvenidos a la versión dos de la API de gestión de usuarios!"


@app.route("/create", methods=["POST"])
def add_usuario():
    """Function to create a usuario in the MySQL database"""
    json = request.json
    firstName = json.get("firstName")
    Correo = json.get("Correo")
    Contrasena = json.get("Contrasena")
    if firstName and Correo and Contrasena and request.method == "POST":
        sql = "INSERT INTO usuarios(firstName, Correo, Contrasena) VALUES(%s, %s, %s)"
        data = (firstName, Correo, Contrasena)
        try:
            conn = mysql.connect()
            cursor = conn.cursor()
            cursor.execute(sql, data)
            conn.commit()
            cursor.close()
            conn.close()
            pod_name = socket.gethostname()
            resp = jsonify({"status": "Creación exitosa", "message": "Nuevo usuario añadido", "pod_origin": pod_name})
            resp.status_code = 201
            return resp
        except Exception as exception:
            return jsonify({"status": "Error en creación", "message": str(exception)})
    else:
        return jsonify({"status": "Datos incompletos", "message": "Por favor, proporcione firstName, Correo y Contrasena"})


@app.route("/usuarios", methods=["GET"])
def usuarios():
    """Function to retrieve all usuarios from the MySQL database"""
    try:
        conn = mysql.connect()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM usuarios")
        rows = cursor.fetchall()
        cursor.close()
        conn.close()
        pod_name = socket.gethostname()
        resp = jsonify({"status": "Consulta exitosa", "message": "Todos los usuarios listados", "pod_origin": pod_name, "lista_usuarios": rows})
        resp.status_code = 200
        return resp
    except Exception as exception:
        return jsonify({"status": "Error al consultar", "message": str(exception)})


@app.route("/usuario/<int:idUsuario>", methods=["GET"])
def usuario(idUsuario):
    """Function to get information of a specific usuario in the MySQL database"""
    try:
        conn = mysql.connect()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM usuarios WHERE idUsuario=%s", (idUsuario,))
        row = cursor.fetchone()
        cursor.close()
        conn.close()
        pod_name = socket.gethostname()
        resp = jsonify({"status": "Usuario encontrado", "message": "Información detallada del usuario", "pod_origin": pod_name, "usuario_detalles": row})
        resp.status_code = 200
        return resp
    except Exception as exception:
        return jsonify({"status": "Error al buscar usuario", "message": str(exception)})


@app.route("/update", methods=["POST"])
def update_usuario():
    """Function to update a usuario in the MySQL database"""
    json = request.json
    firstName = json.get("firstName")
    Correo = json.get("Correo")
    Contrasena = json.get("Contrasena")
    idUsuario = json.get("idUsuario")
    if firstName and Correo and Contrasena and idUsuario and request.method == "POST":
        sql = "UPDATE usuarios SET firstName=%s, Correo=%s, Contrasena=%s WHERE idUsuario=%s"
        data = (firstName, Correo, Contrasena, idUsuario)
        try:
            conn = mysql.connect()
            cursor = conn.cursor()
            cursor.execute(sql, data)
            conn.commit()
            pod_name = socket.gethostname()
            resp = jsonify({"status": "Actualización completa", "message": "Datos de usuario modificados", "pod_origin": pod_name})
            resp.status_code = 200
            cursor.close()
            conn.close()
            return resp
        except Exception as exception:
            return jsonify({"status": "Error al actualizar", "message": str(exception)})
    else:
        return jsonify({"status": "Faltan datos", "message": "Se requieren idUsuario, firstName, Correo y Contrasena para la actualización"})


@app.route("/delete/<int:idUsuario>")
def delete_usuario(idUsuario):
    """Function to delete a usuario from the MySQL database"""
    try:
        conn = mysql.connect()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM usuarios WHERE idUsuario=%s", (idUsuario,))
        conn.commit()
        cursor.close()
        conn.close()
        pod_name = socket.gethostname()
        resp = jsonify({"status": "Eliminación exitosa", "message": "Usuario borrado del sistema", "pod_origin": pod_name})
        resp.status_code = 200
        return resp
    except Exception as exception:
        return jsonify({"status": "Error al eliminar", "message": str(exception)})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF

  # Dependencias
  tee requirements.txt > /dev/null <<EOF
Flask==1.0.3  
Flask-MySQL==1.4.0  
PyMySQL==0.9.3
uWSGI==2.0.17.1
mysql-connector-python
cryptography
EOF

  # Dockerfile
  tee Dockerfile > /dev/null <<EOF
FROM python:3.6-slim

RUN apt-get clean \
    && apt-get -y update

RUN apt-get -y install \
    nginx \
    python3-dev \
    build-essential

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install -r requirements.txt --src /usr/local/src

COPY . .

EXPOSE 5000
CMD [ "python", "flaskapi.py"]
EOF

  docker build . -t flask-api:v2

  # ConfigMap
  tee ConfigMap.yaml > /dev/null <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_SETTING: "Mensaje desde el ConfigMap"  
EOF

  # Deployment
  tee Deployment.yaml > /dev/null <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flaskapi-deployment
  labels:
    app: flaskapi
spec:
  replicas: 3
  selector:
    matchLabels:
      app: flaskapi
  template:
    metadata:
      labels:
        app: flaskapi
    spec:
      containers:
        - name: flaskapi
          image: flask-api:v2
          imagePullPolicy: Never
          ports:
            - containerPort: 5000
          env:
            - name: db_root_password
              valueFrom:
                secretKeyRef:
                  name: flaskapi-secrets
                  key: db_root_password
            - name: db_name
              value: flaskapi

---
apiVersion: v1
kind: Service
metadata:
  name: flask-service
spec:
  ports:
  - port: 5000
    protocol: TCP
    targetPort: 5000
  selector:
    app: flaskapi
  type: LoadBalancer
EOF

  # Aplicación de recursos
  kubectl apply -f ConfigMap.yaml
  kubectl apply -f Deployment.yaml

  kubectl rollout status deployment flaskapi-deployment

  for i in {1..5}; do
    curl $(minikube service flask-service --url)
  done

  echo "Rolling update realizada satisfactoriamente"

  eval $(minikube docker-env -u)

  minikube service flask-service
}


function configurarVolumenesPersistentes(){
  # Crear PV y PVC
  tee pvmysql.yaml > /dev/null << EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-pv-volume
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  hostPath:
    path: "/mnt/data"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pv-claim
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
EOF

  sudo mkdir -p /mnt/data/
  sudo chmod 777 /mnt/data/

  # Aplicar PV y PVC
  kubectl apply -f pvmysql.yaml
}


while :
do
    echo "===============Menu de opciones============================="
echo "Menú Principal de Opciones"
    echo "1. Establecer Minikube"
    echo "2. Generar Contenedores"
    echo "3. Consultar Registros de Contenedor"
    echo "4. Implementar Aplicacion"
    echo "5. Iniciar Actualizacion Continua"
    echo "6. Ajustar Almacenamiento Persistente"
    echo "7. Finalizar"
    echo "Elige tu opcion"
    echo "============================================================="
    read opc

    case $opc in
        "1")
            instalarMinikube
        ;;
        "2")
            crearPods
        ;;
        "3")
            mostrarLogs
        ;;
        "4")
            desplegarApp
        ;;
        "5")
            ejecutarRollingUpdate
        ;;
        "6")
            configurarVolumenesPersistentes
        ;;
        "7")
          echo "Saliendo..."
          break
        ;;
        *)
            echo "Selecciona una opcion valida"
        ;;
    esac
done