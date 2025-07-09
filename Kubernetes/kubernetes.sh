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

  tee secret.yaml >> /dev/null << EOF
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

  tee configmapmysql.yaml >> /dev/null << EOF
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

  tee crearpods.yaml >> /dev/null << EOF
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

  kubectl run -i --rm --tty mysql-client --image=mysql --restart=Never -- \
  mysql --host=mysql --password=admin << EOF
CREATE DATABASE flaskapi;
USE flaskapi;
CREATE TABLE users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    user_name VARCHAR(255),
    user_email VARCHAR(255),
    user_password VARCHAR(255)
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
    return "Hello, world!"


@app.route("/create", methods=["POST"])
def add_user():
    """Function to create a user to the MySQL database"""
    json = request.json
    name = json["name"]
    email = json["email"]
    pwd = json["pwd"]
    if name and email and pwd and request.method == "POST":
        sql = "INSERT INTO users(user_name, user_email, user_password) " \
              "VALUES(%s, %s, %s)"
        data = (name, email, pwd)
        try:
            conn = mysql.connect()
            cursor = conn.cursor()
            cursor.execute(sql, data)
            conn.commit()
            cursor.close()
            conn.close()
            pod_name = socket.gethostname()
            resp = jsonify({"message": "User created succesfully", "pod": pod_name})
            resp.status_code = 200
            return resp
        except Exception as exception:
            return jsonify(str(exception))
    else:
        return jsonify("Please provide name, email and pwd")


@app.route("/users", methods=["GET"])
def users():
    """Function to retrieve all users from the MySQL database"""
    try:
        conn = mysql.connect()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users")
        rows = cursor.fetchall()
        cursor.close()
        conn.close()
        pod_name = socket.gethostname()
        resp = jsonify({"message": "Users retrieved succesfully", "pod": pod_name, "data": rows})
        resp.status_code = 200
        return resp
    except Exception as exception:
        return jsonify(str(exception))


@app.route("/user/<int:user_id>", methods=["GET"])
def user(user_id):
    """Function to get information of a specific user in the MSQL database"""
    try:
        conn = mysql.connect()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users WHERE user_id=%s", user_id)
        row = cursor.fetchone()
        cursor.close()
        conn.close()
        pod_name = socket.gethostname()
        resp = jsonify({"message": "User retrieved succesfully", "pod": pod_name, "data": row})
        resp.status_code = 200
        return resp
    except Exception as exception:
        return jsonify(str(exception))


@app.route("/update", methods=["POST"])
def update_user():
    """Function to update a user in the MYSQL database"""
    json = request.json
    name = json["name"]
    email = json["email"]
    pwd = json["pwd"]
    user_id = json["user_id"]
    if name and email and pwd and user_id and request.method == "POST":
        # save edits
        sql = "UPDATE users SET user_name=%s, user_email=%s, " \
              "user_password=%s WHERE user_id=%s"
        data = (name, email, pwd, user_id)
        try:
            conn = mysql.connect()
            cursor = conn.cursor()
            cursor.execute(sql, data)
            conn.commit()
            pod_name = socket.gethostname()
            resp = jsonify({"message": "User updated succesfully", "pod": pod_name})
            resp.status_code = 200
            cursor.close()
            conn.close()
            return resp
        except Exception as exception:
            return jsonify(str(exception))
    else:
        return jsonify("Please provide id, name, email and pwd")


@app.route("/delete/<int:user_id>")
def delete_user(user_id):
    """Function to delete a user from the MySQL database"""
    try:
        conn = mysql.connect()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM users WHERE user_id=%s", user_id)
        conn.commit()
        cursor.close()
        conn.close()
        pod_name = socket.gethostname()
        resp = jsonify({"message": "User deleted succesfully", "pod": pod_name})
        resp.status_code = 200
        return resp
    except Exception as exception:
        return jsonify(str(exception))


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

    # Código fuente de la API
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
    return "Versión dos de la API"


@app.route("/create", methods=["POST"])
def add_user():
    """Function to create a user to the MySQL database"""
    json = request.json
    name = json["name"]
    email = json["email"]
    pwd = json["pwd"]
    if name and email and pwd and request.method == "POST":
        sql = "INSERT INTO users(user_name, user_email, user_password) " \
              "VALUES(%s, %s, %s)"
        data = (name, email, pwd)
        try:
            conn = mysql.connect()
            cursor = conn.cursor()
            cursor.execute(sql, data)
            conn.commit()
            cursor.close()
            conn.close()
            pod_name = socket.gethostname()
            resp = jsonify({"message": "User created succesfully", "pod": pod_name})
            resp.status_code = 200
            return resp
        except Exception as exception:
            return jsonify(str(exception))
    else:
        return jsonify("Please provide name, email and pwd")


@app.route("/users", methods=["GET"])
def users():
    """Function to retrieve all users from the MySQL database"""
    try:
        conn = mysql.connect()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users")
        rows = cursor.fetchall()
        cursor.close()
        conn.close()
        pod_name = socket.gethostname()
        resp = jsonify({"message": "Users retrieved succesfully", "pod": pod_name, "data": rows})
        resp.status_code = 200
        return resp
    except Exception as exception:
        return jsonify(str(exception))


@app.route("/user/<int:user_id>", methods=["GET"])
def user(user_id):
    """Function to get information of a specific user in the MSQL database"""
    try:
        conn = mysql.connect()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users WHERE user_id=%s", user_id)
        row = cursor.fetchone()
        cursor.close()
        conn.close()
        pod_name = socket.gethostname()
        resp = jsonify({"message": "User retrieved succesfully", "pod": pod_name, "data": row})
        resp.status_code = 200
        return resp
    except Exception as exception:
        return jsonify(str(exception))


@app.route("/update", methods=["POST"])
def update_user():
    """Function to update a user in the MYSQL database"""
    json = request.json
    name = json["name"]
    email = json["email"]
    pwd = json["pwd"]
    user_id = json["user_id"]
    if name and email and pwd and user_id and request.method == "POST":
        # save edits
        sql = "UPDATE users SET user_name=%s, user_email=%s, " \
              "user_password=%s WHERE user_id=%s"
        data = (name, email, pwd, user_id)
        try:
            conn = mysql.connect()
            cursor = conn.cursor()
            cursor.execute(sql, data)
            conn.commit()
            pod_name = socket.gethostname()
            resp = jsonify({"message": "User updated succesfully", "pod": pod_name})
            resp.status_code = 200
            cursor.close()
            conn.close()
            return resp
        except Exception as exception:
            return jsonify(str(exception))
    else:
        return jsonify("Please provide id, name, email and pwd")


@app.route("/delete/<int:user_id>")
def delete_user(user_id):
    """Function to delete a user from the MySQL database"""
    try:
        conn = mysql.connect()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM users WHERE user_id=%s", user_id)
        conn.commit()
        cursor.close()
        conn.close()
        pod_name = socket.gethostname()
        resp = jsonify({"message": "User deleted succesfully", "pod": pod_name})
        resp.status_code = 200
        return resp
    except Exception as exception:
        return jsonify(str(exception))


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
    echo "Menu de opciones"
    echo "1. Instalar minikube"
    echo "2. Crear pods"
    echo "3. Ver logs de un pod"
    echo "4. Desplegar app"
    echo "5. Ejecutar rolling update"
    echo "6. Configurar volumenes persistentes"
    echo "7. Salir"
    echo "Selecciona una opcion"
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