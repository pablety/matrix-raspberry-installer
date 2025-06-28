#!/bin/bash

# Matrix Synapse + Element Web Installer for Raspberry Pi
# Autor: @pablety
# Fecha: 2025-06-28
# Descripción: Script completo para instalar servidor de chat Matrix en red local

set -e  # Salir si hay errores

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗${NC} $1"
}

# Banner
echo -e "${GREEN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    Matrix Synapse + Element Web Installer for Raspberry Pi  ║
║                     Red Local - Sin Internet                ║
║                                                              ║
║                      Creado por: @pablety                   ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Verificar que se ejecuta como usuario normal (no root)
if [ "$EUID" -eq 0 ]; then
    log_error "No ejecutes este script como root. Usa tu usuario normal."
    exit 1
fi

# Obtener información del sistema
LOCAL_IP=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname)
MATRIX_USER="matrix"
MATRIX_HOME="/opt/matrix"
ELEMENT_PATH="/var/www/element"

log "Información del sistema:"
echo "  - IP Local: $LOCAL_IP"
echo "  - Hostname: $HOSTNAME"
echo "  - Usuario Matrix: $MATRIX_USER"
echo ""

# Verificar conexión a internet
log "Verificando conexión a internet..."
if ping -c 1 google.com &> /dev/null; then
    log_success "Conexión a internet disponible"
else
    log_error "Sin conexión a internet. Necesaria para descargar paquetes."
    exit 1
fi

# Actualizar sistema
log "Actualizando lista de paquetes..."
sudo apt update

log "Actualizando sistema (esto puede tardar varios minutos)..."
sudo apt upgrade -y

# Instalar dependencias básicas
log "Instalando dependencias básicas..."
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    libffi-dev \
    libssl-dev \
    libxml2-dev \
    libxslt1-dev \
    libjpeg-dev \
    libpq-dev \
    build-essential \
    nginx \
    avahi-daemon \
    avahi-utils \
    wget \
    curl \
    git \
    htop \
    postgresql \
    postgresql-contrib \
    openssl

log_success "Dependencias instaladas"

# Crear usuario del sistema para Matrix
log "Creando usuario del sistema para Matrix..."
if ! id "$MATRIX_USER" &>/dev/null; then
    sudo adduser --system --home /home/$MATRIX_USER --disabled-login $MATRIX_USER
    log_success "Usuario $MATRIX_USER creado"
else
    log_warning "Usuario $MATRIX_USER ya existe"
fi

# Crear directorio de Matrix
log "Creando directorio de Matrix..."
sudo mkdir -p $MATRIX_HOME
sudo chown $MATRIX_USER:nogroup $MATRIX_HOME
log_success "Directorio $MATRIX_HOME creado"

# Configurar PostgreSQL
log "Configurando PostgreSQL para Matrix Synapse..."

# Iniciar y habilitar PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Crear usuario y base de datos para Matrix
DB_PASSWORD=$(openssl rand -hex 16)
sudo -u postgres psql << EOF
CREATE USER matrix WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE matrix_synapse OWNER matrix;
ALTER DATABASE matrix_synapse SET TIME ZONE 'UTC';
\q
EOF

# Optimizar PostgreSQL para Raspberry Pi
log "Optimizando PostgreSQL para Raspberry Pi..."
sudo tee -a /etc/postgresql/*/main/postgresql.conf > /dev/null << 'EOF'

# Optimizaciones para Raspberry Pi
max_connections = 20
shared_buffers = 128MB
effective_cache_size = 512MB
maintenance_work_mem = 32MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 8MB
min_wal_size = 1GB
max_wal_size = 4GB
EOF

# Reiniciar PostgreSQL para aplicar configuración
sudo systemctl restart postgresql

# Crear archivo con credenciales de base de datos
sudo tee /opt/matrix/db_config.txt > /dev/null << EOF
DB_HOST=localhost
DB_PORT=5432
DB_NAME=matrix_synapse
DB_USER=matrix
DB_PASSWORD=$DB_PASSWORD
EOF

sudo chmod 600 /opt/matrix/db_config.txt
sudo chown matrix:nogroup /opt/matrix/db_config.txt

log_success "PostgreSQL configurado y optimizado"

# Instalar Matrix Synapse
log "Instalando Matrix Synapse (esto tardará varios minutos)..."
sudo -u $MATRIX_USER bash << EOF
cd $MATRIX_HOME
if [ ! -d "env" ]; then
    python3 -m venv env
    source env/bin/activate
    pip install --upgrade pip setuptools wheel
    pip install matrix-synapse[all] psycopg2-binary
    
    # Generar configuración
    python -m synapse.app.homeserver \\
        --server-name=matrix-chat.local \\
        --config-path=$MATRIX_HOME/homeserver.yaml \\
        --generate-config \\
        --report-stats=no
    
    echo "Matrix Synapse instalado correctamente"
else
    echo "Matrix Synapse ya está instalado"
fi
EOF

log_success "Matrix Synapse instalado"

# Configurar Matrix para red local
log "Configurando Matrix para red local..."
sudo -u $MATRIX_USER cp $MATRIX_HOME/homeserver.yaml $MATRIX_HOME/homeserver.yaml.backup

# Cargar credenciales de base de datos
source /opt/matrix/db_config.txt

# Modificar configuración
sudo -u $MATRIX_USER tee $MATRIX_HOME/homeserver.yaml > /dev/null << EOF
# Matrix Synapse Configuration for Local Network
# Generated by matrix-raspberry-installer

server_name: "matrix-chat.local"
pid_file: $MATRIX_HOME/homeserver.pid
listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    resources:
      - names: [client, federation]
        compress: false

database:
  name: psycopg2
  args:
    user: matrix
    password: $DB_PASSWORD
    database: matrix_synapse
    host: localhost
    port: 5432
    cp_min: 5
    cp_max: 10

log_config: "$MATRIX_HOME/matrix-chat.local.log.config"
media_store_path: $MATRIX_HOME/media_store
registration_shared_secret: "$(openssl rand -hex 32)"
report_stats: false
macaroon_secret_key: "$(openssl rand -hex 32)"
form_secret: "$(openssl rand -hex 32)"
signing_key_path: "$MATRIX_HOME/matrix-chat.local.signing.key"

trusted_key_servers:
  - server_name: "matrix.org"

# Permitir registro solo en red local
enable_registration: true
enable_registration_without_verification: true
registrations_require_3pid: []
allowed_local_3pids: []
enable_3pid_lookup: false
autocreate_auto_join_rooms: true

# Configuración para red local
federation_domain_whitelist: []
allow_guest_access: false
enable_metrics: false
enable_media_repo: true

# Configuración de retención
retention:
  enabled: false

# Configuración de presencia (deshabilitada para mejor rendimiento)
presence:
  enabled: false
EOF

# Crear configuración de logging
sudo -u $MATRIX_USER tee $MATRIX_HOME/matrix-chat.local.log.config > /dev/null << 'EOF'
version: 1

formatters:
  precise:
    format: '%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(request)s - %(message)s'

handlers:
  file:
    class: logging.handlers.TimedRotatingFileHandler
    formatter: precise
    filename: /opt/matrix/homeserver.log
    when: midnight
    backupCount: 3
    encoding: utf8

  console:
    class: logging.StreamHandler
    formatter: precise

loggers:
    synapse.storage.SQL:
        level: WARN

root:
    level: INFO
    handlers: [file, console]

disable_existing_loggers: false
EOF

log_success "Matrix configurado para red local"

# Crear servicio systemd
log "Creando servicio systemd..."
sudo tee /etc/systemd/system/matrix-synapse.service > /dev/null << EOF
[Unit]
Description=Matrix Synapse Homeserver
After=network.target

[Service]
Type=simple
User=$MATRIX_USER
Group=nogroup
WorkingDirectory=$MATRIX_HOME
ExecStart=$MATRIX_HOME/env/bin/python -m synapse.app.homeserver --config-path=$MATRIX_HOME/homeserver.yaml
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
SyslogIdentifier=matrix-synapse

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectHome=yes
ProtectSystem=strict
ReadWritePaths=$MATRIX_HOME

[Install]
WantedBy=multi-user.target
EOF

log_success "Servicio systemd creado"

# Configurar mDNS/Avahi
log "Configurando mDNS (Avahi)..."
sudo tee /etc/avahi/avahi-daemon.conf > /dev/null << 'EOF'
[server]
host-name=matrix-chat
domain-name=local
use-ipv4=yes
use-ipv6=no
allow-interfaces=eth0,wlan0
enable-dbus=yes

[wide-area]
enable-wide-area=yes

[publish]
publish-addresses=yes
publish-hinfo=yes
publish-workstation=yes
publish-domain=yes
publish-aaaa-on-ipv4=no
publish-a-on-ipv6=no
EOF

log_success "mDNS configurado"

# Generar certificados SSL autofirmados
log "Generando certificados SSL autofirmados..."
sudo mkdir -p /etc/ssl/matrix
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/matrix/matrix-chat.key \
    -out /etc/ssl/matrix/matrix-chat.crt \
    -subj "/C=ES/ST=Local/L=Local/O=Matrix Chat/OU=IT Department/CN=matrix-chat.local" \
    -addext "subjectAltName=DNS:matrix-chat.local,DNS:$HOSTNAME.local,IP:$LOCAL_IP,DNS:localhost"

sudo chmod 600 /etc/ssl/matrix/matrix-chat.key
sudo chmod 644 /etc/ssl/matrix/matrix-chat.crt

log_success "Certificados SSL generados"

# Configurar Nginx
log "Configurando Nginx..."
sudo tee /etc/nginx/sites-available/matrix-local > /dev/null << EOF
# Matrix Synapse + Element Web Configuration
# Local Network Setup with HTTPS

# HTTP server - redirect to HTTPS
server {
    listen 80;
    server_name matrix-chat.local $HOSTNAME.local $LOCAL_IP localhost *.local;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name matrix-chat.local $HOSTNAME.local $LOCAL_IP localhost *.local;
    
    # SSL Configuration
    ssl_certificate /etc/ssl/matrix/matrix-chat.crt;
    ssl_certificate_key /etc/ssl/matrix/matrix-chat.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Matrix Synapse
    location /_matrix {
        proxy_pass http://127.0.0.1:8008;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Host \$host;
        
        # CORS headers for Element
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
        add_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization";
    }

    # Element Web Client
    location / {
        root $ELEMENT_PATH;
        index index.html;
        try_files \$uri \$uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Health check
    location /health {
        access_log off;
        return 200 "Matrix Chat Server OK\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Habilitar sitio y deshabilitar default
sudo ln -sf /etc/nginx/sites-available/matrix-local /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Verificar configuración de Nginx
if sudo nginx -t; then
    log_success "Configuración de Nginx válida"
else
    log_error "Error en configuración de Nginx"
    exit 1
fi

# Instalar Element Web
log "Descargando Element Web..."
sudo mkdir -p $ELEMENT_PATH
cd /tmp

# Limpiar descargas anteriores
rm -f element-*.tar.gz

# Descargar última versión de Element
ELEMENT_VERSION="v1.11.69"  # Versión estable conocida
wget -q "https://github.com/vector-im/element-web/releases/download/$ELEMENT_VERSION/element-$ELEMENT_VERSION.tar.gz"

if [ -f "element-$ELEMENT_VERSION.tar.gz" ]; then
    log_success "Element Web descargado"
    tar -xzf "element-$ELEMENT_VERSION.tar.gz"
    sudo cp -r element-$ELEMENT_VERSION/* $ELEMENT_PATH/
    sudo chown -R www-data:www-data $ELEMENT_PATH
    log_success "Element Web instalado"
else
    log_error "Error descargando Element Web"
    exit 1
fi

# Configurar Element Web
log "Configurando Element Web..."
sudo tee $ELEMENT_PATH/config.json > /dev/null << EOF
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "https://matrix-chat.local",
            "server_name": "matrix-chat.local"
        },
        "m.identity_server": {
            "base_url": ""
        }
    },
    "disable_custom_urls": false,
    "disable_guests": false,
    "disable_login_language_selector": false,
    "disable_3pid_login": true,
    "brand": "Chat Local Raspberry Pi",
    "integrations_ui_url": "",
    "integrations_rest_url": "",
    "integrations_widgets_urls": [],
    "default_server_name": "matrix-chat.local",
    "default_federate": false,
    "default_theme": "light",
    "roomDirectory": {
        "servers": []
    },
    "enable_presence_by_hs_url": {
        "https://matrix-chat.local": false
    },
    "terms_and_conditions_links": [],
    "privacy_policy_links": [],
    "showLabsSettings": false,
    "features": {},
    "map_style_url": ""
}
EOF

log_success "Element Web configurado"

# Crear script de actualización automática de IP
log "Creando script de actualización automática..."
sudo tee /usr/local/bin/update-matrix-ip.sh > /dev/null << 'EOF'
#!/bin/bash

# Script para actualizar configuración cuando cambia la IP
LOG_FILE="/var/log/matrix-ip-update.log"
CURRENT_IP=$(hostname -I | awk '{print $1}')
NGINX_FILE="/etc/nginx/sites-available/matrix-local"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

# Verificar si la IP cambió en la configuración
if [ -f "$NGINX_FILE" ] && ! grep -q "$CURRENT_IP" "$NGINX_FILE"; then
    log_message "IP detectada: $CURRENT_IP, actualizando configuración..."
    
    # Backup de configuración actual
    cp "$NGINX_FILE" "${NGINX_FILE}.backup.$(date +%s)"
    
    # Reemplazar IP anterior con la nueva (mantener otros server_names)
    sed -i "s/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/$CURRENT_IP/g" "$NGINX_FILE"
    
    # Verificar configuración y recargar
    if nginx -t 2>/dev/null; then
        systemctl reload nginx
        log_message "Configuración actualizada exitosamente a IP: $CURRENT_IP"
    else
        log_message "Error en configuración de Nginx, restaurando backup"
        mv "${NGINX_FILE}.backup.$(date +%s)" "$NGINX_FILE"
    fi
fi
EOF

sudo chmod +x /usr/local/bin/update-matrix-ip.sh

# Crear cron job para actualización automática
log "Configurando actualización automática cada 10 minutos..."
(sudo crontab -l 2>/dev/null; echo "*/10 * * * * /usr/local/bin/update-matrix-ip.sh") | sudo crontab -

log_success "Actualización automática configurada"

# Configurar logrotate
sudo tee /etc/logrotate.d/matrix-synapse > /dev/null << 'EOF'
/opt/matrix/homeserver.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    postrotate
        systemctl reload matrix-synapse
    endscript
}

/var/log/matrix-ip-update.log {
    weekly
    missingok
    rotate 4
    compress
    delaycompress
    notifempty
}
EOF

# Iniciar y habilitar servicios
log "Iniciando servicios..."

# Habilitar servicios
sudo systemctl daemon-reload
sudo systemctl enable matrix-synapse
sudo systemctl enable nginx
sudo systemctl enable avahi-daemon

# Iniciar servicios
sudo systemctl start avahi-daemon
sleep 2
sudo systemctl start matrix-synapse
sleep 5
sudo systemctl restart nginx

# Verificar estado de servicios
log "Verificando estado de servicios..."

services=("postgresql" "matrix-synapse" "nginx" "avahi-daemon")
all_ok=true

for service in "${services[@]}"; do
    if sudo systemctl is-active --quiet $service; then
        log_success "$service está funcionando"
    else
        log_error "$service no está funcionando"
        all_ok=false
    fi
done

# Crear herramientas de backup y mantenimiento
log "Creando herramientas de backup y mantenimiento..."

# Script de backup de PostgreSQL
sudo tee /usr/local/bin/matrix-backup.sh > /dev/null << 'EOF'
#!/bin/bash
# Matrix PostgreSQL Backup Script

BACKUP_DIR="/opt/matrix/backups"
DATE=$(date +%Y%m%d_%H%M%S)
source /opt/matrix/db_config.txt

# Crear directorio de backup
mkdir -p $BACKUP_DIR

# Backup de base de datos
PGPASSWORD=$DB_PASSWORD pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME > "$BACKUP_DIR/matrix_db_$DATE.sql"

# Backup de configuración
tar -czf "$BACKUP_DIR/matrix_config_$DATE.tar.gz" /opt/matrix/homeserver.yaml /opt/matrix/*.log.config /var/www/element/config.json 2>/dev/null

# Limpiar backups antiguos (mantener 7 días)
find $BACKUP_DIR -name "matrix_*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "matrix_*.tar.gz" -mtime +7 -delete

echo "Backup completado: $BACKUP_DIR/matrix_db_$DATE.sql"
EOF

sudo chmod +x /usr/local/bin/matrix-backup.sh
sudo chown root:root /usr/local/bin/matrix-backup.sh

# Script de mantenimiento
sudo tee /usr/local/bin/matrix-maintenance.sh > /dev/null << 'EOF'
#!/bin/bash
# Matrix Maintenance Script

source /opt/matrix/db_config.txt

echo "=== Matrix Synapse Maintenance ===="
echo "Fecha: $(date)"

# Estadísticas de base de datos
echo -e "\n--- PostgreSQL Database Stats ---"
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC 
LIMIT 10;"

# Estado de servicios
echo -e "\n--- Service Status ---"
for service in postgresql matrix-synapse nginx avahi-daemon; do
    if systemctl is-active --quiet $service; then
        echo "$service: ✓ Running"
    else
        echo "$service: ✗ Stopped"
    fi
done

# Espacio en disco
echo -e "\n--- Disk Usage ---"
df -h /opt/matrix
df -h /var/www/element

# Logs recientes
echo -e "\n--- Recent Matrix Logs ---"
tail -n 5 /opt/matrix/homeserver.log

echo -e "\n=== Maintenance Complete ==="
EOF

sudo chmod +x /usr/local/bin/matrix-maintenance.sh
sudo chown root:root /usr/local/bin/matrix-maintenance.sh

# Script de monitoreo
sudo tee /usr/local/bin/matrix-monitor.sh > /dev/null << 'EOF'
#!/bin/bash
# Matrix Monitor Script

source /opt/matrix/db_config.txt

# Verificar conectividad
if curl -s -k https://localhost/_matrix/client/versions > /dev/null; then
    echo "$(date): Matrix API OK" >> /var/log/matrix-monitor.log
else
    echo "$(date): Matrix API ERROR" >> /var/log/matrix-monitor.log
    systemctl restart matrix-synapse
fi

# Verificar PostgreSQL
if PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1;" > /dev/null 2>&1; then
    echo "$(date): PostgreSQL OK" >> /var/log/matrix-monitor.log
else
    echo "$(date): PostgreSQL ERROR" >> /var/log/matrix-monitor.log
    systemctl restart postgresql
fi
EOF

sudo chmod +x /usr/local/bin/matrix-monitor.sh
sudo chown root:root /usr/local/bin/matrix-monitor.sh

# Configurar cron jobs para backup y monitoreo
log "Configurando tareas automatizadas..."
(sudo crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/matrix-backup.sh") | sudo crontab -
(sudo crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/matrix-monitor.sh") | sudo crontab -

sudo mkdir -p /opt/matrix/backups
sudo chown matrix:nogroup /opt/matrix/backups

log_success "Herramientas de backup y mantenimiento configuradas"

# Verificar conectividad
log "Verificando conectividad..."
sleep 3

if curl -s -k https://localhost/_matrix/client/versions > /dev/null; then
    log_success "Matrix Synapse responde correctamente"
else
    log_error "Matrix Synapse no responde"
    all_ok=false
fi

if curl -s -k https://localhost/ > /dev/null; then
    log_success "Element Web accesible"
else
    log_error "Element Web no accesible"
    all_ok=false
fi

# Resultados finales
echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                              ║${NC}"

if [ "$all_ok" = true ]; then
    echo -e "${GREEN}║                    ¡INSTALACIÓN EXITOSA! 🎉                 ║${NC}"
else
    echo -e "${RED}║              INSTALACIÓN CON ADVERTENCIAS ⚠️                ║${NC}"
fi

echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${YELLOW}📋 INFORMACIÓN DE ACCESO:${NC}"
echo -e "   🌐 URL Principal: ${GREEN}https://matrix-chat.local${NC}"
echo -e "   🌐 URL por IP:    ${GREEN}https://$LOCAL_IP${NC}"
echo -e "   🌐 URL Hostname:  ${GREEN}https://$HOSTNAME.local${NC}"

echo -e "\n${YELLOW}👤 CREAR PRIMER USUARIO:${NC}"
echo -e "   Ejecuta: ${GREEN}sudo -u matrix /opt/matrix/env/bin/register_new_matrix_user -c /opt/matrix/homeserver.yaml http://localhost:8008${NC}"

echo -e "\n${YELLOW}🔧 COMANDOS ÚTILES:${NC}"
echo -e "   Ver logs:     ${GREEN}sudo journalctl -u matrix-synapse -f${NC}"
echo -e "   Reiniciar:    ${GREEN}sudo systemctl restart matrix-synapse${NC}"
echo -e "   Estado:       ${GREEN}sudo systemctl status matrix-synapse${NC}"
echo -e "   Backup DB:    ${GREEN}/usr/local/bin/matrix-backup.sh${NC}"
echo -e "   Mantenimiento:${GREEN}/usr/local/bin/matrix-maintenance.sh${NC}"
echo -e "   Monitor:      ${GREEN}/usr/local/bin/matrix-monitor.sh${NC}"

echo -e "\n${YELLOW}🗄️ BASE DE DATOS POSTGRESQL:${NC}"
echo -e "   Host:         ${GREEN}localhost${NC}"
echo -e "   Puerto:       ${GREEN}5432${NC}"
echo -e "   Base de datos:${GREEN}matrix_synapse${NC}"
echo -e "   Usuario:      ${GREEN}matrix${NC}"
echo -e "   Config:       ${GREEN}/opt/matrix/db_config.txt${NC}"

echo -e "\n${YELLOW}📁 UBICACIONES IMPORTANTES:${NC}"
echo -e "   Config:       ${GREEN}/opt/matrix/homeserver.yaml${NC}"
echo -e "   Logs:         ${GREEN}/opt/matrix/homeserver.log${NC}"
echo -e "   Backups:      ${GREEN}/opt/matrix/backups/${NC}"
echo -e "   SSL Certs:    ${GREEN}/etc/ssl/matrix/${NC}"
echo -e "   Element:      ${GREEN}/var/www/element/${NC}"

echo -e "\n${BLUE}🚀 ¡Tu servidor de chat local está listo para usar!${NC}"
echo -e "${BLUE}   Accede desde cualquier dispositivo en tu red local${NC}"

# Crear usuario automáticamente si se proporciona
if [ ! -z "$AUTO_USER" ] && [ ! -z "$AUTO_PASS" ]; then
    log "Creando usuario automáticamente..."
    sudo -u matrix /opt/matrix/env/bin/register_new_matrix_user \
        -c /opt/matrix/homeserver.yaml \
        -u "$AUTO_USER" \
        -p "$AUTO_PASS" \
        --admin \
        http://localhost:8008
    log_success "Usuario $AUTO_USER creado automáticamente"
fi

echo -e "\n${GREEN}Instalación completada en $(date)${NC}"
exit 0
