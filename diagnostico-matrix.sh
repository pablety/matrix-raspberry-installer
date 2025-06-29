#!/bin/bash

echo "🔧 Solucionando problemas de conexión Matrix"
echo "=============================================="

# Detectar IP
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "📍 IP detectada: $LOCAL_IP"

# 1. Verificar servicios
echo ""
echo "📋 Verificando servicios..."
services=("postgresql" "matrix-synapse" "nginx")
all_running=true

for service in "${services[@]}"; do
    if systemctl is-active --quiet $service; then
        echo "  ✅ $service: Funcionando"
    else
        echo "  ❌ $service: No funciona - Reiniciando..."
        sudo systemctl start $service
        sleep 3
        if systemctl is-active --quiet $service; then
            echo "  ✅ $service: Reiniciado exitosamente"
        else
            echo "  ❌ $service: Error al reiniciar"
            all_running=false
        fi
    fi
done

# 2. Verificar puertos
echo ""
echo "🌐 Verificando puertos..."
ports=("80" "443" "8008")
for port in "${ports[@]}"; do
    if sudo netstat -tlnp | grep -q ":$port "; then
        echo "  ✅ Puerto $port: Abierto"
    else
        echo "  ❌ Puerto $port: Cerrado"
    fi
done

# 3. Probar Matrix API
echo ""
echo "🔍 Probando Matrix API..."
if curl -k -s --max-time 5 https://localhost/_matrix/client/versions >/dev/null 2>&1; then
    echo "  ✅ Matrix API HTTPS: Funciona"
elif curl -s --max-time 5 http://localhost:8008/_matrix/client/versions >/dev/null 2>&1; then
    echo "  ✅ Matrix API HTTP: Funciona"
    echo "  ⚠️  Pero HTTPS tiene problemas"
else
    echo "  ❌ Matrix API: No responde"
    echo "  🔧 Verificando logs..."
    sudo journalctl -u matrix-synapse --no-pager -n 10
fi

# 4. Configurar acceso HTTP temporal
echo ""
echo "🔧 Configurando acceso HTTP temporal..."
sudo tee /etc/nginx/sites-available/matrix-http > /dev/null << EOF
server {
    listen 80;
    server_name _;

    location /_matrix {
        proxy_pass http://127.0.0.1:8008;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto http;
        proxy_set_header Host \$host;
    }

    location / {
        root /var/www/element;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
}
EOF

# Activar configuración HTTP
sudo ln -sf /etc/nginx/sites-available/matrix-http /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# 5. Verificar firewall
echo ""
echo "🛡️  Verificando firewall..."
if command -v ufw >/dev/null 2>&1; then
    if sudo ufw status | grep -q "Status: active"; then
        echo "  ⚠️  UFW activo - Abriendo puertos..."
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        sudo ufw allow 8008/tcp
    else
        echo "  ✅ UFW inactivo"
    fi
fi

# 6. Regenerar certificados SSL
echo ""
echo "🔐 Regenerando certificados SSL..."
sudo mkdir -p /etc/ssl/matrix
sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/ssl/matrix/matrix-chat.key \
    -out /etc/ssl/matrix/matrix-chat.crt \
    -subj "/C=ES/ST=Local/L=Local/O=Matrix/CN=$LOCAL_IP" \
    -addext "subjectAltName=DNS:localhost,DNS:matrix.local,IP:127.0.0.1,IP:$LOCAL_IP"

sudo systemctl reload nginx

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    🎯 SOLUCIÓN APLICADA                        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "🌐 PRUEBA ESTAS URLs EN TU NAVEGADOR:"
echo ""
echo "   1️⃣  HTTP (fácil): http://$LOCAL_IP"
echo "   2️⃣  HTTPS (acepta certificado): https://$LOCAL_IP"
echo ""
echo "🔧 Para HTTPS, cuando aparezca el error de certificado:"
echo "   → Click 'Avanzado' o 'Advanced'"
echo "   → Click 'Continuar a $LOCAL_IP (no seguro)'"
echo ""
echo "👤 Para crear usuario después de conectar:"
echo "   sudo -u matrix /opt/matrix/env/bin/register_new_matrix_user -c /opt/matrix/homeserver.yaml http://localhost:8008"
EOF

chmod +x fix-matrix-connection.sh
./fix-matrix-connection.sh
