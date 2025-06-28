#!/bin/bash

# Matrix USB Docker Portable - Versión mejorada
# Detecta y soluciona problemas de Docker

set -e

USB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$USB_DIR/bin"
DATA_DIR="$USB_DIR/matrix-data"

echo "🚀 Matrix USB Docker Portable"
echo "👤 Usuario: $(whoami)"
echo "💾 Datos en: $DATA_DIR"

# Función para verificar Docker
check_docker() {
    if command -v docker &> /dev/null; then
        echo "✅ Docker encontrado: $(docker --version)"
        
        # Verificar si el daemon está corriendo
        if docker info >/dev/null 2>&1; then
            echo "✅ Docker daemon funcionando"
            USE_SUDO=""
        else
            echo "⚠️  Docker daemon not accessible, trying with sudo..."
            if sudo docker info >/dev/null 2>&1; then
                echo "✅ Docker daemon funcionando con sudo"
                USE_SUDO="sudo"
            else
                echo "❌ Docker daemon no está corriendo"
                echo "🔧 Intentando iniciar Docker daemon..."
                sudo systemctl start docker
                sleep 5
                if sudo docker info >/dev/null 2>&1; then
                    USE_SUDO="sudo"
                else
                    echo "❌ No se pudo iniciar Docker daemon"
                    exit 1
                fi
            fi
        fi
    else
        echo "❌ Docker no está instalado en este sistema"
        echo "🔧 Instalando Docker..."
        curl -fsSL https://get.docker.com | sh
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $(whoami)
        echo "⚠️  Necesitas reiniciar sesión para usar Docker sin sudo"
        echo "💡 Por ahora usaremos sudo"
        USE_SUDO="sudo"
    fi
}

# Función para verificar Docker Compose
check_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        echo "✅ Docker Compose encontrado"
    else
        echo "⚠️  Docker Compose no encontrado, usando el del USB..."
        export PATH="$DOCKER_DIR:$PATH"
        if [ -f "$DOCKER_DIR/docker-compose" ]; then
            echo "✅ Docker Compose del USB disponible"
        else
            echo "❌ Docker Compose no disponible"
            echo "🔧 Descargando Docker Compose..."
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o "$DOCKER_DIR/docker-compose"
            sudo chmod +x "$DOCKER_DIR/docker-compose"
        fi
    fi
}

# Verificaciones iniciales
check_docker
check_docker_compose

# Detectar IP
LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "localhost")
echo "📍 IP detectada: $LOCAL_IP"

# Crear estructura de datos
mkdir -p $DATA_DIR/{postgresql,synapse,element,ssl,backups}

# Docker Compose con sudo condicional
cat > $DATA_DIR/docker-compose.yml << EOF
version: '3.8'

services:
  postgresql:
    image: postgres:15-alpine
    container_name: matrix-usb-postgres
    environment:
      POSTGRES_DB: synapse
      POSTGRES_USER: synapse_user
      POSTGRES_PASSWORD: usb_matrix_2024
      POSTGRES_INITDB_ARGS: "--encoding=UTF8 --lc-collate=C --lc-ctype=C"
    volumes:
      - $DATA_DIR/postgresql:/var/lib/postgresql/data
    restart: unless-stopped
    networks:
      - matrix-usb-net

  synapse:
    image: matrixdotorg/synapse:latest
    container_name: matrix-usb-synapse
    environment:
      SYNAPSE_SERVER_NAME: $LOCAL_IP
      SYNAPSE_REPORT_STATS: 'no'
    volumes:
      - $DATA_DIR/synapse:/data
    depends_on:
      - postgresql
    ports:
      - "8008:8008"
    restart: unless-stopped
    networks:
      - matrix-usb-net

  element:
    image: vectorim/element-web:latest
    container_name: matrix-usb-element
    volumes:
      - $DATA_DIR/element-config.json:/app/config.json:ro
    restart: unless-stopped
    networks:
      - matrix-usb-net

  nginx:
    image: nginx:alpine
    container_name: matrix-usb-nginx
    volumes:
      - $DATA_DIR/nginx.conf:/etc/nginx/nginx.conf:ro
      - $DATA_DIR/ssl:/etc/ssl/matrix:ro
    ports:
      - "80:80"
      - "443:443"
    depends_on:
      - synapse
      - element
    restart: unless-stopped
    networks:
      - matrix-usb-net

networks:
  matrix-usb-net:
    driver: bridge
EOF

# Configuración Element
cat > $DATA_DIR/element-config.json << EOF
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "https://$LOCAL_IP",
            "server_name": "$LOCAL_IP"
        }
    },
    "brand": "Matrix USB Portable",
    "disable_custom_urls": false,
    "disable_guests": false
}
EOF

# Configuración Nginx
cat > $DATA_DIR/nginx.conf << 'EOF'
events { worker_connections 1024; }
http {
    upstream synapse { server synapse:8008; }
    upstream element { server element:80; }
    
    server {
        listen 80;
        return 301 https://$server_name$request_uri;
    }
    
    server {
        listen 443 ssl;
        ssl_certificate /etc/ssl/matrix/cert.pem;
        ssl_certificate_key /etc/ssl/matrix/key.pem;
        
        location /_matrix {
            proxy_pass http://synapse;
            proxy_set_header X-Forwarded-For $remote_addr;
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header Host $host;
        }
        
        location / {
            proxy_pass http://element;
            proxy_set_header Host $host;
        }
    }
}
EOF

# Generar certificados SSL
if [ ! -f $DATA_DIR/ssl/cert.pem ]; then
    echo "🔐 Generando certificados SSL..."
    mkdir -p $DATA_DIR/ssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout $DATA_DIR/ssl/key.pem \
        -out $DATA_DIR/ssl/cert.pem \
        -subj "/CN=$LOCAL_IP"
fi

# Configuración inicial de Synapse
if [ ! -f $DATA_DIR/synapse/homeserver.yaml ]; then
    echo "⚙️ Configuración inicial de Synapse..."
    
    $USE_SUDO docker run --rm \
        -v $DATA_DIR/synapse:/data \
        -e SYNAPSE_SERVER_NAME=$LOCAL_IP \
        -e SYNAPSE_REPORT_STATS=no \
        matrixdotorg/synapse:latest generate
    
    # Configurar PostgreSQL
    cat >> $DATA_DIR/synapse/homeserver.yaml << EOF

database:
  name: psycopg2
  args:
    user: synapse_user
    password: usb_matrix_2024
    database: synapse
    host: postgresql
    port: 5432

enable_registration: true
enable_registration_without_verification: true
EOF
fi

# Descargar imágenes Docker
echo "📥 Descargando imágenes Docker..."
$USE_SUDO docker pull postgres:15-alpine
$USE_SUDO docker pull matrixdotorg/synapse:latest
$USE_SUDO docker pull vectorim/element-web:latest
$USE_SUDO docker pull nginx:alpine

# Iniciar servicios
echo "🚀 Iniciando Matrix USB..."
cd $DATA_DIR

if [ -n "$USE_SUDO" ]; then
    sudo docker-compose up -d
else
    docker-compose up -d
fi

echo "⏳ Esperando servicios..."
sleep 30

echo ""
echo "✅ Matrix USB funcionando!"
echo "🌐 Acceso: https://$LOCAL_IP"
echo ""
echo "👤 Crear usuario:"
echo "$USE_SUDO docker exec -it matrix-usb-synapse register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008"
EOF
