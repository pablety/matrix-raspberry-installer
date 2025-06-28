# matrix-installer
# Descargar y ejecutar en un solo comando
curl -fsSL https://raw.githubusercontent.com/pablety/matrix-raspberry-installer/main/install-matrix-universal.sh | bash
# Después de la instalación accedes por:
IP detectada: https://TU_IP_DETECTADA
Hostname: https://tu-server.local (si mDNS funciona)
# Crear tu usuario administrador (OBLIGATORIO)
sudo -u matrix /opt/matrix/env/bin/register_new_matrix_user \
    -c /opt/matrix/homeserver.yaml \
    https://localhost:8008

Username: xxxx (o el que prefieras)
Password: tu contraseña
Make admin: yes (para ser administrador)

# Ver logs en tiempo real
sudo journalctl -u matrix-synapse -f

# Reiniciar Matrix si hay problemas
sudo systemctl restart matrix-synapse

# Ver usuarios registrados
sudo -u postgres psql -d synapse -c "SELECT name FROM users;"

# Ver estadísticas del servidor
sudo matrix-stats.sh  # (si incluiste este script)
