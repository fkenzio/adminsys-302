#!/bin/bash

# Script completo de Kubernetes para Ubuntu Server
# Ejecutar como usuario normal (no root)

set -e

echo "Iniciando instalacion completa de Kubernetes..."

# 1. INSTALACION DEL ENTORNO
echo "Actualizando sistema..."
sudo apt update && sudo apt upgrade -y

echo "Instalando dependencias..."
sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release

# Instalar Docker
echo "Instalando Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker $USER
    sudo systemctl enable docker
    sudo systemctl start docker
fi

# Instalar kubectl
echo "Instalando kubectl..."
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
fi

# Instalar Minikube
echo "Instalando Minikube..."
if ! command -v minikube &> /dev/null; then
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
fi

# Reiniciar para aplicar cambios de grupo docker
echo "Aplicando cambios de grupo docker..."
newgrp docker << 'DOCKEREOF'

# Iniciar Minikube
echo "Iniciando Minikube..."
minikube start --driver=docker --cpus=2 --memory=4096
minikube addons enable dashboard
minikube addons enable metrics-server

# 2. CREAR APLICACION FLASK
echo "Creando aplicacion Flask..."
mkdir -p ~/k8s-app
cd ~/k8s-app

# Aplicacion Python
cat > app.py << 'EOF'
from flask import Flask, jsonify
import os
import socket

app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({
        'message': 'Hello from Kubernetes',
        'hostname': socket.gethostname(),
        'version': os.getenv('APP_VERSION', '1.0'),
        'environment': os.getenv('ENVIRONMENT', 'development')
    })

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

# Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.9-slim
WORKDIR /app
RUN pip install flask
COPY app.py .
EXPOSE 5000
CMD ["python", "app.py"]
EOF

# Construir imagen
echo "Construyendo imagen Docker..."
eval $(minikube docker-env)
docker build -t flask-app:v1 .

# 3. CREAR MANIFIESTOS KUBERNETES

# ConfigMap
cat > configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: flask-config
data:
  APP_VERSION: "1.0"
  ENVIRONMENT: "kubernetes"
  DATABASE_URL: "postgresql://localhost:5432/myapp"
EOF

# Secret
cat > secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: flask-secret
type: Opaque
data:
  DB_PASSWORD: cGFzc3dvcmQxMjM=
  API_KEY: YWJjZGVmZ2hpams=
EOF

# Deployment
cat > deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flask-app
  labels:
    app: flask-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: flask-app
  template:
    metadata:
      labels:
        app: flask-app
    spec:
      containers:
      - name: flask-app
        image: flask-app:v1
        imagePullPolicy: Never
        ports:
        - containerPort: 5000
        env:
        - name: APP_VERSION
          valueFrom:
            configMapKeyRef:
              name: flask-config
              key: APP_VERSION
        - name: ENVIRONMENT
          valueFrom:
            configMapKeyRef:
              name: flask-config
              key: ENVIRONMENT
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: flask-secret
              key: DB_PASSWORD
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 5
          periodSeconds: 5
EOF

# Service
cat > service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: flask-service
spec:
  selector:
    app: flask-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5000
  type: ClusterIP
EOF

# LoadBalancer Service
cat > loadbalancer.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: flask-loadbalancer
spec:
  selector:
    app: flask-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5000
  type: LoadBalancer
EOF

# Persistent Volume
cat > pv.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: flask-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /tmp/flask-data
EOF

# Persistent Volume Claim
cat > pvc.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: flask-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# 4. DESPLEGAR APLICACION
echo "Desplegando aplicacion..."
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
kubectl apply -f pv.yaml
kubectl apply -f pvc.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f loadbalancer.yaml

# Esperar a que los pods esten listos
echo "Esperando a que los pods esten listos..."
kubectl wait --for=condition=ready pod -l app=flask-app --timeout=300s

# 5. CREAR SCRIPTS DE UTILIDAD

# Script de monitoreo
cat > monitor.sh << 'EOF'
#!/bin/bash
echo "=== ESTADO DEL CLUSTER ==="
kubectl get nodes
echo
echo "=== PODS ==="
kubectl get pods -o wide
echo
echo "=== SERVICES ==="
kubectl get services
echo
echo "=== LOGS DE LA APLICACION ==="
kubectl logs -l app=flask-app --tail=10
EOF

chmod +x monitor.sh

# Script de actualizacion
cat > update.sh << 'EOF'
#!/bin/bash
echo "Actualizando aplicacion..."
eval $(minikube docker-env)
docker build -t flask-app:v2 .
kubectl set image deployment/flask-app flask-app=flask-app:v2
kubectl rollout status deployment/flask-app
echo "Actualizacion completada"
EOF

chmod +x update.sh

# Script de limpieza
cat > cleanup.sh << 'EOF'
#!/bin/bash
echo "Limpiando recursos..."
kubectl delete deployment flask-app
kubectl delete service flask-service flask-loadbalancer
kubectl delete configmap flask-config
kubectl delete secret flask-secret
kubectl delete pvc flask-pvc
kubectl delete pv flask-pv
echo "Limpieza completada"
EOF

chmod +x cleanup.sh

# 6. MOSTRAR INFORMACION FINAL
echo
echo "=== INSTALACION COMPLETADA ==="
echo "Directorio de trabajo: ~/k8s-app"
echo
echo "=== ESTADO ACTUAL ==="
kubectl get all
echo
echo "=== ACCESO A LA APLICACION ==="
echo "Para acceder desde el servidor:"
echo "kubectl port-forward service/flask-service 8080:80"
echo "Luego visitar: http://localhost:8080"
echo
echo "Para acceso externo:"
minikube service flask-loadbalancer --url
echo
echo "=== COMANDOS UTILES ==="
echo "./monitor.sh     - Ver estado del cluster"
echo "./update.sh      - Actualizar aplicacion"
echo "./cleanup.sh     - Limpiar recursos"
echo "kubectl logs -l app=flask-app - Ver logs"

DOCKEREOF

echo "Script completado. Reinicia la terminal o ejecuta: newgrp docker"