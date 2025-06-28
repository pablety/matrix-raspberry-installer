#!/bin/bash

# Matrix USB Docker Portable Creator
# Crea USB con Docker + Matrix completamente portátil

set -e

USB_DEVICE="$1"
USB_MOUNT="/mnt/matrix-usb"

echo "🔧 Creando Matrix USB Docker Portable..."

if [ "$EUID" -ne 0 ]; then
    echo "Ejecutar como root: sudo $0 /dev/sdX"
    exit 1
fi

if [ -z "$USB_DEVICE" ]; then
    echo "Dispositivos disponibles:"
    lsblk -d -o NAME,SIZE,VENDOR,MODEL | grep -E "sd[b-z]"
    echo ""
    echo "Uso: sudo $0 /dev/sdX"
    exit 1
fi

# Verificar tamaño mínimo (4GB)
SIZE_BYTES=$(lsblk -b -d -o SIZE -n $USB_DEVICE)
MIN_SIZE=4000000000  # 4GB
if [ $SIZE_BYTES -lt $MIN_SIZE ]; then
    echo "❌ USB muy pequeño. Mínimo 4GB necesarios."
    exit 1
fi

echo "⚠️  Se borrará todo en $USB_DEVICE"
read -p "¿Continuar? [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Formatear USB
echo "💾 Formateando USB..."
sudo umount ${USB_DEVICE}* 2>/dev/null || true
sudo parted $USB_DEVICE --script mklabel msdos
sudo parted $USB_DEVICE --script mkpart primary ext4 1MiB 100%
sudo mkfs.ext4 -F -L "MATRIX-USB" ${USB_DEVICE}1

# Montar USB
sudo mkdir -p $USB_MOUNT
sudo mount ${USB_DEVICE}1 $USB_MOUNT

echo "📦 Creando estructura Matrix USB..."

# Crear estructura de directorios
sudo mkdir -p $USB_MOUNT/{docker,matrix-data,scripts,bin}

# Descargar Docker binario portátil
echo "🐳 Descargando Docker portátil..."
DOCKER_VERSION="24.0.7"
wget -O /tmp/docker.tgz "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz"
tar -xzf /tmp/docker.tgz -C /tmp/
sudo cp /tmp/docker/* $USB_MOUNT/bin/
sudo chmod +x $USB_MOUNT/bin/*

# Descargar Docker Compose
echo "🔧 Descargando Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o $USB_MOUNT/bin/docker-compose
sudo chmod +x $USB_MOUNT/bin/docker-compose

# Crear script principal ejecutable
cat > $USB_MOUNT/matrix-usb.sh << 'EOF'
#!/bin/bash

# Matrix USB Docker Portable
# Ejecuta Matrix desde USB sin instalación

set -e

# Detectar directorio del USB
USB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$USB_DIR/bin"
DATA_DIR="$USB_DIR/matrix-data"

# Añadir Docker al PATH
export PATH="$DOCKER_DIR:$PATH"

# Detectar IP
LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "localhost")

echo "🚀 Matrix USB Docker Portable"
echo "📍 IP detectada: $LOCAL_IP"
echo "💾 Datos en: $DATA_DIR"

# Verificar Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker no encontrado en PATH"
    echo "🔧 Iniciando Docker daemon portátil..."
    
    # Crear directorio para Docker daemon
    mkdir -p $DATA_DIR/docker-root
    
    # Iniciar Docker daemon en background
    sudo $DOCKER_DIR/dockerd \
        --data-root=$DATA_DIR/docker-root \
        --host=unix:///tmp/docker-usb.sock \
        --pidfile=$DATA_DIR/docker.pid \
        --iptables=false \
        --bridge=none \
        --storage-driver=overlay2 \
        > $DATA_DIR/docker.log 2>&1 &
    
    # Esperar a que Docker esté listo
    export DOCKER_HOST=unix:///tmp/docker-usb.sock
    
    echo "⏳ Esperando Docker daemon..."
    for i in {1..30}; do
        if $DOCKER_DIR/docker info >/dev/null 2>&1; then
            echo "✅ Docker daemon listo"
            break
        fi
        sleep 1
    done
    
    if [ $i -eq 30 ]; then
        echo "❌ Docker daemon no responde"
        exit 1
    fi
else
    echo "✅ Docker ya disponible"
fi

# Crear estructura de datos
mkdir -p $DATA_DIR/{postgresql,synapse,element,ssl,backups}

# Docker Compose
cat > $DATA_DIR/docker-compose.yml << COMPOSE
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
COMPOSE

# Configuración Element
cat > $DATA_DIR/element-config.json << ELEMENT
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "https://$LOCAL_IP",
            "server_name": "$LOCAL_IP"
        }
    },
    "brand": "Matrix USB Portable",
    "disable_custom_urls": false,
    "disable_guests": false,
    "features": {
        "feature_voice_messages": true,
        "feature_video_calls": true,
        "feature_audio_calls": true
    },
    "show_labs_settings": true
}
ELEMENT

# Configuración Nginx
cat > $DATA_DIR/nginx.conf << 'NGINX'
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
        ssl_protocols TLSv1.2 TLSv1.3;
        
        location /_matrix {
            proxy_pass http://synapse;
            proxy_set_header X-Forwarded-For $remote_addr;
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        
        location / {
            proxy_pass http://element;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
NGINX

# Generar certificados SSL
if [ ! -f $DATA_DIR/ssl/cert.pem ]; then
    echo "🔐 Generando certificados SSL..."
    mkdir -p $DATA_DIR/ssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout $DATA_DIR/ssl/key.pem \
        -out $DATA_DIR/ssl/cert.pem \
        -subj "/C=US/ST=USB/L=Portable/O=Matrix/CN=$LOCAL_IP" \
        -addext "subjectAltName=IP:$LOCAL_IP,DNS:localhost,DNS:matrix-usb.local"
fi

# Configuración inicial de Synapse
if [ ! -f $DATA_DIR/synapse/homeserver.yaml ]; then
    echo "⚙️ Configuración inicial de Synapse..."
    
    # Generar configuración
    docker run --rm \
        -v $DATA_DIR/synapse:/data \
        -e SYNAPSE_SERVER_NAME=$LOCAL_IP \
        -e SYNAPSE_REPORT_STATS=no \
        matrixdotorg/synapse:latest generate
    
    # Configurar PostgreSQL
    cat >> $DATA_DIR/synapse/homeserver.yaml << CONFIG

# PostgreSQL Database
database:
  name: psycopg2
  args:
    user: synapse_user
    password: usb_matrix_2024
    database: synapse
    host: postgresql
    port: 5432
    cp_min: 5
    cp_max: 10

# USB Portable settings
enable_registration: true
enable_registration_without_verification: true
registration_shared_secret: "$(openssl rand -hex 32)"
federation_domain_whitelist: []
allow_guest_access: false
enable_media_repo: true
max_upload_size: 100M

# Trust proxy
x_forwarded: true

CONFIG
fi

# Descargar imágenes Docker si no existen
echo "📥 Descargando imágenes Docker..."
docker pull postgres:15-alpine
docker pull matrixdotorg/synapse:latest
docker pull vectorim/element-web:latest
docker pull nginx:alpine

# Iniciar servicios
echo "🚀 Iniciando Matrix USB..."
cd $DATA_DIR
docker-compose up -d

echo "⏳ Esperando servicios..."
sleep 30

# Verificar servicios
echo "✅ Verificando servicios..."
if docker-compose ps | grep -q "Up"; then
    echo "✅ Servicios funcionando"
else
    echo "❌ Error en servicios"
    docker-compose logs
    exit 1
fi

# Información final
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║              🚀 Matrix USB Portable - FUNCIONANDO             ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "🌐 Acceso: https://$LOCAL_IP"
echo "🔐 Acepta el certificado autofirmado"
echo "💾 Datos persistentes en USB"
echo ""
echo "👤 Crear primer usuario:"
echo "docker exec -it matrix-usb-synapse register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008"
echo ""
echo "🛠️ Comandos útiles:"
echo "  Ver logs: docker-compose -f $DATA_DIR/docker-compose.yml logs -f"
echo "  Detener: docker-compose -f $DATA_DIR/docker-compose.yml down"
echo "  Reiniciar: docker-compose -f $DATA_DIR/docker-compose.yml restart"
echo ""
echo "🔄 Para usar en otra computadora:"
echo "  1. Conecta el USB"
echo "  2. Ejecuta: sudo ./matrix-usb.sh"
echo "  3. Todos tus datos están ahí"

# Crear archivo de información
cat > $DATA_DIR/USB_INFO.txt << INFO
Matrix USB Portable Server
=========================
Creado: $(date)
IP: $LOCAL_IP
Usuario: $USER

Contenido:
- Docker binario portátil
- PostgreSQL + Matrix Synapse + Element Web
- Certificados SSL autofirmados
- Datos persistentes

Uso:
1. Conectar USB a cualquier Linux
2. Ejecutar: sudo ./matrix-usb.sh
3. Acceder: https://IP_DETECTADA

Carpetas:
- bin/ : Docker binarios
- matrix-data/ : Datos persistentes
- scripts/ : Scripts auxiliares
INFO

EOF

# Hacer ejecutable el script principal
sudo chmod +x $USB_MOUNT/matrix-usb.sh

# Crear script de ayuda
cat > $USB_MOUNT/LEEME.txt << 'HELP'
🚀 Matrix USB Portable Server
=============================

Este USB contiene un servidor Matrix completo que funciona
en cualquier computadora Linux sin instalación.

🔧 USAR:
1. Conecta el USB a cualquier Linux
2. Abre terminal y ve al USB
3. Ejecuta: sudo ./matrix-usb.sh
4. Espera 2-3 minutos
5. Accede a https://IP_MOSTRADA

💾 DATOS:
- Todos los datos se guardan en el USB
- Usuarios, salas, mensajes persisten
- Llevalo a cualquier computadora

🛠️ REQUISITOS:
- Linux con soporte Docker
- Permisos sudo
- Puerto 80 y 443 libres

📞 FUNCIONES:
- Chat texto
- Llamadas de voz
- Videollamadas  
- Compartir archivos
- Salas grupales

🔐 SEGURIDAD:
- Certificados SSL autofirmados
- Base de datos PostgreSQL
- Red aislada por contenedores

HELP

# Crear script de limpieza
cat > $USB_MOUNT/limpiar.sh << 'CLEAN'
#!/bin/bash
# Limpia contenedores Docker del USB

USB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$USB_DIR/matrix-data"

echo "🧹 Limpiando contenedores Matrix USB..."

cd $DATA_DIR
docker-compose down --remove-orphans
docker system prune -f

echo "✅ Limpieza completada"
CLEAN

sudo chmod +x $USB_MOUNT/limpiar.sh

# Crear backup script
cat > $USB_MOUNT/backup.sh << 'BACKUP'
#!/bin/bash
# Crea backup de datos Matrix

USB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$USB_DIR/matrix-data"
BACKUP_DIR="$USB_DIR/backups"

mkdir -p $BACKUP_DIR

echo "💾 Creando backup..."

# Parar servicios
cd $DATA_DIR
docker-compose stop

# Crear backup
tar -czf "$BACKUP_DIR/matrix-backup-$(date +%Y%m%d_%H%M%S).tar.gz" \
    -C $DATA_DIR postgresql synapse element ssl

# Reiniciar servicios
docker-compose start

echo "✅ Backup creado en: $BACKUP_DIR"
BACKUP

sudo chmod +x $USB_MOUNT/backup.sh

# Desmontar USB
echo "🔧 Finalizando USB..."
sudo umount $USB_MOUNT
sudo rmdir $USB_MOUNT

echo ""
echo "✅ Matrix USB Docker Portable creado exitosamente!"
echo ""
echo "📋 Características:"
echo "  ✅ Docker portátil incluido"
echo "  ✅ Matrix + PostgreSQL + Element"
echo "  ✅ Datos persistentes en USB"
echo "  ✅ Certificados SSL automáticos"
echo "  ✅ Funciona en cualquier Linux"
echo "  ✅ No requiere instalación"
echo ""
echo "🔌 Uso:"
echo "  1. Conecta USB a cualquier Linux"
echo "  2. sudo ./matrix-usb.sh"
echo "  3. Accede a https://IP_DETECTADA"
echo ""
echo "💡 El USB contiene TODO lo necesario para Matrix"

exit 0
