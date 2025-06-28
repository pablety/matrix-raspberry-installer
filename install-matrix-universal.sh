#!/bin/bash

# Matrix Synapse + PostgreSQL Universal Installer
# Compatible con: Ubuntu, Debian, CentOS, RHEL, Fedora, openSUSE, Arch Linux

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Funciones de logging
log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
log_success() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠${NC} $1"; }
log_error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗${NC} $1"; }
log_info() { echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ${NC} $1"; }

# Banner
echo -e "${GREEN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║         Matrix Synapse Universal Installer v2.0               ║
║               PostgreSQL + Element Web + HTTPS                ║
║                                                                ║
║    Compatible: Ubuntu • Debian • CentOS • RHEL • Fedora       ║
║               openSUSE • Arch Linux • Alpine • Amazon Linux   ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Detectar sistema operativo y distribución
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
        ID_LIKE=${ID_LIKE:-$ID}
    elif [ -f /etc/redhat-release ]; then
        OS=$(cat /etc/redhat-release | cut -d' ' -f1)
        VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+' | head -1)
        ID_LIKE="rhel"
    elif [ -f /etc/debian_version ]; then
        OS="Debian"
        VERSION=$(cat /etc/debian_version)
        ID_LIKE="debian"
    else
        log_error "Sistema operativo no soportado"
        exit 1
    fi
    
    # Normalizar ID_LIKE
    case "$ID_LIKE" in
        *debian*|*ubuntu*) FAMILY="debian" ;;
        *rhel*|*fedora*|*centos*) FAMILY="rhel" ;;
        *suse*|*opensuse*) FAMILY="suse" ;;
        *arch*) FAMILY="arch" ;;
        *alpine*) FAMILY="alpine" ;;
        *) FAMILY="unknown" ;;
    esac
}

# Detectar IP local inteligentemente
detect_local_ip() {
    local ip=""
    
    # Método 1: IP hacia internet público
    ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' 2>/dev/null || true)
    
    # Método 2: hostname -I (Linux)
    if [ -z "$ip" ]; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
    fi
    
    # Método 3: ip addr show para interfaces activas
    if [ -z "$ip" ]; then
        ip=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | cut -d/ -f1 || true)
    fi
    
    # Método 4: ifconfig (sistemas más antiguos)
    if [ -z "$ip" ] && command -v ifconfig >/dev/null 2>&1; then
        ip=$(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | sed 's/addr://' || true)
    fi
    
    # Método 5: curl para obtener IP pública si es servidor cloud
    if [ -z "$ip" ]; then
        ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || true)
        if [ -n "$ip" ]; then
            log_warning "Usando IP pública: $ip (servidor cloud detectado)"
        fi
    fi
    
    # Último recurso
    if [ -z "$ip" ]; then
        ip="127.0.0.1"
        log_warning "No se pudo detectar IP, usando localhost"
    fi
    
    echo "$ip"
}

# Detectar hostname inteligentemente
detect_hostname() {
    local hostname=""
    
    # Método 1: hostname command
    hostname=$(hostname 2>/dev/null || true)
    
    # Método 2: /etc/hostname
    if [ -z "$hostname" ] && [ -f /etc/hostname ]; then
        hostname=$(cat /etc/hostname 2>/dev/null | head -1 || true)
    fi
    
    # Método 3: hostnamectl (systemd)
    if [ -z "$hostname" ] && command -v hostnamectl >/dev/null 2>&1; then
        hostname=$(hostnamectl --static 2>/dev/null || true)
    fi
    
    # Último recurso
    if [ -z "$hostname" ]; then
        hostname="matrix-server"
    fi
    
    echo "$hostname"
}

# Instalador universal de paquetes
install_packages() {
    local packages="$*"
    
    case "$FAMILY" in
        "debian")
            log "📦 Actualizando repositorios (Debian/Ubuntu)..."
            sudo apt update
            log "📦 Instalando paquetes: $packages"
            sudo DEBIAN_FRONTEND=noninteractive apt install -y $packages
            ;;
        "rhel")
            if command -v dnf >/dev/null 2>&1; then
                log "📦 Instalando paquetes con DNF (RHEL/Fedora): $packages"
                sudo dnf install -y $packages
            elif command -v yum >/dev/null 2>&1; then
                log "📦 Instalando paquetes con YUM (CentOS): $packages"
                sudo yum install -y $packages
            fi
            ;;
        "suse")
            log "📦 Instalando paquetes (openSUSE): $packages"
            sudo zypper install -y $packages
            ;;
        "arch")
            log "📦 Instalando paquetes (Arch Linux): $packages"
            sudo pacman -Sy --noconfirm $packages
            ;;
        "alpine")
            log "📦 Instalando paquetes (Alpine Linux): $packages"
            sudo apk add $packages
            ;;
        *)
            log_error "Familia de SO no soportada: $FAMILY"
            exit 1
            ;;
    esac
}

# Obtener nombres de paquetes por distribución
get_package_names() {
    case "$FAMILY" in
        "debian")
            PYTHON_PKG="python3 python3-pip python3-venv python3-dev"
            BUILD_PKG="build-essential libffi-dev libssl-dev libxml2-dev libxslt1-dev libjpeg-dev"
            PG_PKG="postgresql postgresql-contrib python3-psycopg2 libpq-dev"
            WEB_PKG="nginx"
            UTILS_PKG="wget curl git htop nano openssl ca-certificates"
            MDNS_PKG="avahi-daemon avahi-utils"
            ;;
        "rhel")
            PYTHON_PKG="python3 python3-pip python3-devel"
            BUILD_PKG="gcc gcc-c++ make libffi-devel openssl-devel libxml2-devel libxslt-devel libjpeg-turbo-devel"
            PG_PKG="postgresql postgresql-server postgresql-contrib python3-psycopg2 postgresql-devel"
            WEB_PKG="nginx"
            UTILS_PKG="wget curl git htop nano openssl ca-certificates"
            MDNS_PKG="avahi avahi-tools"
            ;;
        "suse")
            PYTHON_PKG="python3 python3-pip python3-devel"
            BUILD_PKG="gcc gcc-c++ make libffi-devel libopenssl-devel libxml2-devel libxslt-devel libjpeg8-devel"
            PG_PKG="postgresql postgresql-server postgresql-contrib python3-psycopg2 postgresql-devel"
            WEB_PKG="nginx"
            UTILS_PKG="wget curl git htop nano openssl ca-certificates"
            MDNS_PKG="avahi avahi-utils"
            ;;
        "arch")
            PYTHON_PKG="python python-pip"
            BUILD_PKG="base-devel libffi openssl libxml2 libxslt libjpeg-turbo"
            PG_PKG="postgresql python-psycopg2"
            WEB_PKG="nginx"
            UTILS_PKG="wget curl git htop nano openssl ca-certificates"
            MDNS_PKG="avahi"
            ;;
        "alpine")
            PYTHON_PKG="python3 py3-pip python3-dev"
            BUILD_PKG="build-base libffi-dev openssl-dev libxml2-dev libxslt-dev jpeg-dev"
            PG_PKG="postgresql postgresql-contrib py3-psycopg2 postgresql-dev"
            WEB_PKG="nginx"
            UTILS_PKG="wget curl git htop nano openssl ca-certificates"
            MDNS_PKG="avahi avahi-tools"
            ;;
    esac
}

# Configurar PostgreSQL por distribución
setup_postgresql() {
    case "$FAMILY" in
        "debian")
            sudo systemctl start postgresql
            sudo systemctl enable postgresql
            ;;
        "rhel"|"suse")
            # Inicializar base de datos si es necesario
            if [ ! -f /var/lib/pgsql/data/postgresql.conf ]; then
                if command -v postgresql-setup >/dev/null 2>&1; then
                    sudo postgresql-setup initdb
                elif command -v initdb >/dev/null 2>&1; then
                    sudo -u postgres initdb -D /var/lib/pgsql/data
                fi
            fi
            sudo systemctl start postgresql
            sudo systemctl enable postgresql
            ;;
        "arch")
            # Inicializar si es necesario
            if [ ! -f /var/lib/postgres/data/postgresql.conf ]; then
                sudo -u postgres initdb -D /var/lib/postgres/data
            fi
            sudo systemctl start postgresql
            sudo systemctl enable postgresql
            ;;
        "alpine")
            sudo rc-update add postgresql
            if [ ! -f /var/lib/postgresql/data/postgresql.conf ]; then
                sudo -u postgres initdb -D /var/lib/postgresql/data
            fi
            sudo service postgresql start
            ;;
    esac
}

# Configurar servicios por distribución
setup_services() {
    case "$FAMILY" in
        "alpine")
            # Alpine usa OpenRC
            sudo tee /etc/init.d/matrix-synapse > /dev/null << 'EOF'
#!/sbin/openrc-run

name="Matrix Synapse"
command="/opt/matrix/env/bin/python"
command_args="-m synapse.app.homeserver --config-path=/opt/matrix/homeserver.yaml"
command_user="matrix"
pidfile="/run/matrix-synapse.pid"
command_background="yes"

depend() {
    need net postgresql
}
EOF
            sudo chmod +x /etc/init.d/matrix-synapse
            sudo rc-update add matrix-synapse
            ;;
        *)
            # Systemd para el resto
            sudo tee /etc/systemd/system/matrix-synapse.service > /dev/null << EOF
[Unit]
Description=Matrix Synapse Homeserver
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=matrix
Group=nogroup
WorkingDirectory=/opt/matrix
ExecStart=/opt/matrix/env/bin/python -m synapse.app.homeserver --config-path=/opt/matrix/homeserver.yaml
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
SyslogIdentifier=matrix-synapse

# Security
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectHome=yes
ProtectSystem=strict
ReadWritePaths=/opt/matrix

[Install]
WantedBy=multi-user.target
EOF
            sudo systemctl daemon-reload
            sudo systemctl enable matrix-synapse nginx postgresql
            ;;
    esac
}

# Variables globales
detect_os
LOCAL_IP=$(detect_local_ip)
HOSTNAME=$(detect_hostname)
MATRIX_USER="matrix"
MATRIX_HOME="/opt/matrix"
ELEMENT_PATH="/var/www/element"
DB_NAME="synapse"
DB_USER="synapse_user"
DB_PASS=$(openssl rand -base64 32)

# Información del sistema
log_info "🖥️  Sistema detectado: $OS $VERSION ($FAMILY)"
log_info "📍 IP detectada: $LOCAL_IP"
log_info "🏠 Hostname: $HOSTNAME"
log_info "👤 Usuario actual: $(whoami)"

# Verificar permisos
if [ "$EUID" -eq 0 ]; then
    log_error "No ejecutes este script como root. Usa tu usuario normal con sudo."
    exit 1
fi

if ! sudo -n true 2>/dev/null; then
    log_error "Este script requiere permisos sudo. Ejecuta: sudo -v"
    exit 1
fi

# Confirmar instalación
echo -e "\n${YELLOW}¿Continuar con la instalación? [y/N]${NC}"
read -r confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    log "Instalación cancelada"
    exit 0
fi

# Obtener nombres de paquetes
get_package_names

# Instalar dependencias
log "📦 Instalando dependencias para $FAMILY..."
install_packages $PYTHON_PKG $BUILD_PKG $PG_PKG $WEB_PKG $UTILS_PKG

# Instalar mDNS si está disponible
if [ -n "$MDNS_PKG" ]; then
    install_packages $MDNS_PKG || log_warning "mDNS no disponible en esta distribución"
fi

log_success "Dependencias instaladas"

# Configurar PostgreSQL
log "🗄️  Configurando PostgreSQL..."
setup_postgresql

# Crear base de datos
log "🗄️  Creando base de datos Matrix..."
sudo -u postgres psql << EOF
CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';
CREATE DATABASE $DB_NAME
    ENCODING 'UTF8'
    LC_COLLATE='C'
    LC_CTYPE='C'
    template=template0
    OWNER $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
ALTER USER $DB_USER CREATEDB;
\q
EOF

log_success "Base de datos PostgreSQL configurada"

# Crear usuario Matrix
log "👤 Configurando usuario Matrix..."
if ! id "$MATRIX_USER" &>/dev/null; then
    case "$FAMILY" in
        "alpine")
            sudo adduser -S -h /home/$MATRIX_USER -s /bin/false $MATRIX_USER
            ;;
        *)
            sudo adduser --system --home /home/$MATRIX_USER --disabled-login $MATRIX_USER 2>/dev/null ||
            sudo useradd --system --home-dir /home/$MATRIX_USER --shell /bin/false $MATRIX_USER
            ;;
    esac
    log_success "Usuario $MATRIX_USER creado"
else
    log_warning "Usuario $MATRIX_USER ya existe"
fi

sudo mkdir -p $MATRIX_HOME
sudo chown $MATRIX_USER:$(id -gn $MATRIX_USER) $MATRIX_HOME 2>/dev/null ||
sudo chown $MATRIX_USER:$MATRIX_USER $MATRIX_HOME

# Instalar Matrix Synapse
log "🔧 Instalando Matrix Synapse..."
sudo -u $MATRIX_USER bash << 'EOF'
cd /opt/matrix
python3 -m venv env
source env/bin/activate
pip install --upgrade pip setuptools wheel
pip install matrix-synapse[all] psycopg2-binary
EOF

log_success "Matrix Synapse instalado"

# Configurar Matrix con PostgreSQL
log "⚙️  Configurando Matrix Synapse..."
sudo -u $MATRIX_USER tee $MATRIX_HOME/homeserver.yaml > /dev/null << EOF
# Matrix Synapse Universal Configuration
server_name: "$LOCAL_IP"
pid_file: $MATRIX_HOME/homeserver.pid

listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    resources:
      - names: [client, federation]
        compress: false

# PostgreSQL Database
database:
  name: psycopg2
  args:
    user: $DB_USER
    password: $DB_PASS
    database: $DB_NAME
    host: localhost
    port: 5432
    cp_min: 5
    cp_max: 10
    keepalives_idle: 10
    keepalives_interval: 10
    keepalives_count: 3

log_config: "$MATRIX_HOME/homeserver.log.config"
media_store_path: $MATRIX_HOME/media_store

# Security
registration_shared_secret: "$(openssl rand -hex 32)"
macaroon_secret_key: "$(openssl rand -hex 32)"
form_secret: "$(openssl rand -hex 32)"
signing_key_path: "$MATRIX_HOME/homeserver.signing.key"

# Universal network configuration
enable_registration: true
enable_registration_without_verification: true
registrations_require_3pid: []
allowed_local_3pids: []
enable_3pid_lookup: false

# Disable federation for local/private servers
federation_domain_whitelist: []
allow_guest_access: false
enable_metrics: false
enable_media_repo: true

# Performance optimizations
retention:
  enabled: false

presence:
  enabled: false

caches:
  global_factor: 1.5

# File uploads
max_upload_size: 50M
max_image_pixels: 32M

# Trust proxy headers
x_forwarded: true

report_stats: false
EOF

# Crear configuración de logging
sudo -u $MATRIX_USER tee $MATRIX_HOME/homeserver.log.config > /dev/null << 'EOF'
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
    backupCount: 7
    encoding: utf8

root:
    level: INFO
    handlers: [file]

disable_existing_loggers: false
EOF

# Generar claves
log "🔐 Generando claves Matrix..."
sudo -u $MATRIX_USER bash << 'EOF'
cd /opt/matrix
source env/bin/activate
python -m synapse.app.homeserver \
    --config-path=/opt/matrix/homeserver.yaml \
    --generate-keys
EOF

log_success "Matrix Synapse configurado"

# Configurar HTTPS
log "🔐 Configurando certificados SSL..."
sudo mkdir -p /etc/ssl/matrix
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/matrix/matrix-chat.key \
    -out /etc/ssl/matrix/matrix-chat.crt \
    -subj "/C=US/ST=Local/L=Local/O=Matrix Chat/CN=$LOCAL_IP" \
    -addext "subjectAltName=DNS:matrix-chat.local,DNS:$HOSTNAME.local,IP:$LOCAL_IP"

log_success "Certificados SSL creados"

# Instalar Element Web
log "🌐 Instalando Element Web..."
sudo mkdir -p $ELEMENT_PATH
cd /tmp

ELEMENT_VERSION="v1.11.69"
ELEMENT_URL="https://github.com/vector-im/element-web/releases/download/$ELEMENT_VERSION/element-$ELEMENT_VERSION.tar.gz"

if wget -q --timeout=30 "$ELEMENT_URL"; then
    tar -xzf "element-$ELEMENT_VERSION.tar.gz"
    sudo cp -r element-$ELEMENT_VERSION/* $ELEMENT_PATH/
    
    # Configurar permisos según el sistema
    if command -v nginx >/dev/null 2>&1; then
        WEB_USER=$(ps aux | grep nginx | grep -v root | head -1 | awk '{print $1}' 2>/dev/null || echo "www-data")
        sudo chown -R $WEB_USER:$WEB_USER $ELEMENT_PATH 2>/dev/null || 
        sudo chown -R nginx:nginx $ELEMENT_PATH 2>/dev/null ||
        sudo chown -R www-data:www-data $ELEMENT_PATH
    fi
    
    log_success "Element Web instalado"
else
    log_error "Error descargando Element Web"
    exit 1
fi

# Configurar Element Web
sudo tee $ELEMENT_PATH/config.json > /dev/null << EOF
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "https://$LOCAL_IP",
            "server_name": "$LOCAL_IP"
        }
    },
    "disable_custom_urls": false,
    "disable_guests": false,
    "brand": "Matrix Chat Server",
    "default_federate": false,
    "default_theme": "light",
    "features": {
        "feature_voice_messages": true,
        "feature_video_calls": true,
        "feature_audio_calls": true
    },
    "showLabsSettings": true
}
EOF

# Configurar Nginx
log "🔧 Configurando Nginx..."
sudo tee /etc/nginx/sites-available/matrix-universal 2>/dev/null > /dev/null << EOF || sudo tee /etc/nginx/conf.d/matrix-universal.conf > /dev/null << EOF
# HTTP redirect to HTTPS
server {
    listen 80;
    server_name $LOCAL_IP $HOSTNAME.local matrix-chat.local localhost;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name $LOCAL_IP $HOSTNAME.local matrix-chat.local localhost;

    ssl_certificate /etc/ssl/matrix/matrix-chat.crt;
    ssl_certificate_key /etc/ssl/matrix/matrix-chat.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers on;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;

    # Matrix Synapse
    location /_matrix {
        proxy_pass http://127.0.0.1:8008;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Element Web
    location / {
        root $ELEMENT_PATH;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
}
EOF

# Habilitar sitio de Nginx
if [ -d /etc/nginx/sites-available ]; then
    sudo ln -sf /etc/nginx/sites-available/matrix-universal /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
fi

# Verificar configuración Nginx
if sudo nginx -t; then
    log_success "Configuración Nginx válida"
else
    log_error "Error en configuración Nginx"
    exit 1
fi

# Configurar servicios
log "🔧 Configurando servicios..."
setup_services

# Crear scripts de utilidad
log "🛠️  Creando herramientas de administración..."

sudo tee /usr/local/bin/matrix-info.sh > /dev/null << EOF
#!/bin/bash
echo "=== Matrix Server Information ==="
echo "Server IP: $LOCAL_IP"
echo "Hostname: $HOSTNAME"
echo "Access URL: https://$LOCAL_IP"
echo ""
echo "=== Database ==="
echo "Type: PostgreSQL"
echo "Name: $DB_NAME"
echo "User: $DB_USER"
echo ""
echo "=== Services Status ==="
systemctl is-active postgresql && echo "PostgreSQL: Running" || echo "PostgreSQL: Stopped"
systemctl is-active matrix-synapse && echo "Matrix Synapse: Running" || echo "Matrix Synapse: Stopped"
systemctl is-active nginx && echo "Nginx: Running" || echo "Nginx: Stopped"
EOF

sudo chmod +x /usr/local/bin/matrix-info.sh

# Guardar información importante
sudo -u $MATRIX_USER tee $MATRIX_HOME/server_info.txt > /dev/null << EOF
Matrix Synapse Universal Installation
====================================
Installation Date: $(date)
Server IP: $LOCAL_IP
Hostname: $HOSTNAME
Operating System: $OS $VERSION ($FAMILY)

Database Information:
- Type: PostgreSQL
- Name: $DB_NAME
- User: $DB_USER
- Password: $DB_PASS

Access URLs:
- HTTPS: https://$LOCAL_IP
- Local: https://$HOSTNAME.local (if mDNS available)

Useful Commands:
- Server info: sudo matrix-info.sh
- View logs: sudo journalctl -u matrix-synapse -f
- Create user: sudo -u matrix /opt/matrix/env/bin/register_new_matrix_user -c /opt/matrix/homeserver.yaml https://localhost:8008
- Restart Matrix: sudo systemctl restart matrix-synapse
EOF

# Iniciar servicios
log "🚀 Iniciando servicios..."
case "$FAMILY" in
    "alpine")
        sudo service postgresql start
        sudo service matrix-synapse start
        sudo service nginx start
        ;;
    *)
        sudo systemctl start postgresql matrix-synapse nginx
        ;;
esac

# Verificar servicios
log "✅ Verificando instalación..."
sleep 10

all_ok=true
services=("postgresql" "matrix-synapse" "nginx")

for service in "${services[@]}"; do
    case "$FAMILY" in
        "alpine")
            if sudo service $service status >/dev/null 2>&1; then
                log_success "$service funcionando"
            else
                log_error "$service no funciona"
                all_ok=false
            fi
            ;;
        *)
            if sudo systemctl is-active --quiet $service; then
                log_success "$service funcionando"
            else
                log_error "$service no funciona"
                all_ok=false
            fi
            ;;
    esac
done

# Verificar conectividad
if curl -k -s --max-time 10 https://localhost/_matrix/client/versions > /dev/null; then
    log_success "Matrix API funcionando"
else
    log_error "Matrix API no responde"
    all_ok=false
fi

# Resultados finales
echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
if [ "$all_ok" = true ]; then
    echo -e "${GREEN}║                    ✅ INSTALACIÓN EXITOSA                       ║${NC}"
else
    echo -e "${RED}║                    ⚠️  INSTALACIÓN CON ERRORES                  ║${NC}"
fi
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${PURPLE}🖥️  SISTEMA: ${NC}$OS $VERSION ($FAMILY)"
echo -e "${PURPLE}📍 IP: ${NC}$LOCAL_IP"
echo -e "${PURPLE}🏠 HOSTNAME: ${NC}$HOSTNAME"

echo -e "\n${YELLOW}🌐 ACCESO AL CHAT:${NC}"
echo -e "   🔒 URL Principal: ${GREEN}https://$LOCAL_IP${NC}"
if [ "$HOSTNAME" != "localhost" ]; then
    echo -e "   🔒 URL Local: ${GREEN}https://$HOSTNAME.local${NC}"
fi
echo -e "   ⚠️  ${CYAN}Acepta el certificado autofirmado en tu navegador${NC}"

echo -e "\n${YELLOW}👤 CREAR PRIMER USUARIO:${NC}"
echo -e "   ${GREEN}sudo -u matrix /opt/matrix/env/bin/register_new_matrix_user -c /opt/matrix/homeserver.yaml https://localhost:8008${NC}"

echo -e "\n${YELLOW}🛠️  COMANDOS ÚTILES:${NC}"
echo -e "   Información: ${GREEN}sudo matrix-info.sh${NC}"
echo -e "   Ver logs:    ${GREEN}sudo journalctl -u matrix-synapse -f${NC}"
echo -e "   Reiniciar:   ${GREEN}sudo systemctl restart matrix-synapse${NC}"

echo -e "\n${BLUE}🎉 ¡Tu servidor Matrix universal está listo!${NC}"
echo -e "${BLUE}   Compatible con micrófono, cámara y llamadas${NC}"
echo -e "${BLUE}   Funciona en cualquier distribución Linux${NC}"

log_info "Información guardada en: $MATRIX_HOME/server_info.txt"

exit 0
