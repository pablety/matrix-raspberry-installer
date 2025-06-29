#!/bin/bash

echo "🔍 Diagnóstico Matrix Server"
echo "=============================="

# Verificar servicios
echo "📋 Estado de servicios:"
services=("postgresql" "matrix-synapse" "nginx")
for service in "${services[@]}"; do
    if systemctl is-active --quiet $service; then
        echo "  ✅ $service: Funcionando"
    else
        echo "  ❌ $service: Parado"
        echo "     Logs recientes:"
        sudo journalctl -u $service --no-pager -n 5 | sed 's/^/       /'
    fi
done

echo ""
echo "🌐 Conectividad de red:"
# Verificar puertos
ports=("5432:PostgreSQL" "8008:Matrix" "80:HTTP" "443:HTTPS")
for port_info in "${ports[@]}"; do
    port=$(echo $port_info | cut -d: -f1)
    service=$(echo $port_info | cut -d: -f2)
    if sudo netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        echo "  ✅ Puerto $port ($service): Abierto"
    else
        echo "  ❌ Puerto $port ($service): Cerrado"
    fi
done

echo ""
echo "🗄️  Base de datos PostgreSQL:"
# Verificar PostgreSQL
if sudo -u postgres psql -c '\l' >/dev/null 2>&1; then
    echo "  ✅ PostgreSQL responde"
    
    # Verificar base de datos synapse
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw synapse; then
        echo "  ✅ Base de datos 'synapse' existe"
    else
        echo "  ❌ Base de datos 'synapse' no existe"
    fi
    
    # Verificar usuario synapse_user
    if sudo -u postgres psql -t -c "SELECT 1 FROM pg_roles WHERE rolname='synapse_user'" | grep -q 1; then
        echo "  ✅ Usuario 'synapse_user' existe"
    else
        echo "  ❌ Usuario 'synapse_user' no existe"
    fi
else
    echo "  ❌ PostgreSQL no responde"
    echo "     Intentando diagnóstico detallado..."
    
    # Verificar si está instalado
    if command -v psql >/dev/null 2>&1; then
        echo "     ✅ PostgreSQL instalado"
    else
        echo "     ❌ PostgreSQL no instalado"
    fi
    
    # Verificar archivos de configuración
    pg_configs=(
        "/etc/postgresql/*/main/postgresql.conf"
        "/var/lib/pgsql/data/postgresql.conf"
        "/usr/local/pgsql/data/postgresql.conf"
    )
    
    found_config=false
    for config in "${pg_configs[@]}"; do
        if ls $config 2>/dev/null; then
            echo "     ✅ Configuración encontrada: $config"
            found_config=true
            break
        fi
    done
    
    if [ "$found_config" = false ]; then
        echo "     ❌ No se encontró configuración PostgreSQL"
        echo "     💡 Posible solución: sudo postgresql-setup --initdb"
    fi
fi

echo ""
echo "📁 Archivos Matrix:"
# Verificar archivos importantes
matrix_files=(
    "/opt/matrix/homeserver.yaml:Configuración Matrix"
    "/opt/matrix/homeserver.log:Log Matrix"
    "/opt/matrix/homeserver.signing.key:Clave Matrix"
)

for file_info in "${matrix_files[@]}"; do
    file=$(echo $file_info | cut -d: -f1)
    desc=$(echo $file_info | cut -d: -f2)
    if [ -f "$file" ]; then
        echo "  ✅ $desc: $file"
    else
        echo "  ❌ $desc: $file (no existe)"
    fi
done

echo ""
echo "🔧 Configuración Matrix:"
if [ -f /opt/matrix/homeserver.yaml ]; then
    echo "  Base de datos configurada:"
    grep -A 10 "^database:" /opt/matrix/homeserver.yaml | sed 's/^/    /'
else
    echo "  ❌ homeserver.yaml no encontrado"
fi

echo ""
echo "🌐 Conectividad Matrix API:"
if curl -k -s --max-time 5 https://localhost/_matrix/client/versions >/dev/null 2>&1; then
    echo "  ✅ Matrix API responde (HTTPS)"
elif curl -s --max-time 5 http://localhost:8008/_matrix/client/versions >/dev/null 2>&1; then
    echo "  ✅ Matrix API responde (HTTP directo)"
else
    echo "  ❌ Matrix API no responde"
fi

echo ""
echo "💡 Comandos de solución rápida:"
echo "   Reiniciar PostgreSQL: sudo systemctl restart postgresql"
echo "   Reiniciar Matrix: sudo systemctl restart matrix-synapse"
echo "   Ver logs Matrix: sudo journalctl -u matrix-synapse -f"
echo "   Ver logs PostgreSQL: sudo journalctl -u postgresql -f"
echo "   Conectar a PostgreSQL: sudo -u postgres psql"
EOF

chmod +x diagnostico-matrix.sh
./diagnostico-matrix.sh
