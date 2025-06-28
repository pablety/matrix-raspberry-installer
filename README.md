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

# Crear el USB (reemplaza /dev/sdb con tu USB)
sudo ./matrix-portable.sh /dev/sdb

Usar el USB en cualquier computadora:
bash
# 1. Conectar USB y montarlo
cd /media/pablety/MATRIX-USB  # (o donde se monte)

# 2. Ejecutar Matrix
sudo ./matrix-usb.sh

# 3. Acceder a Matrix
# El script te mostrará la URL: https://192.168.X.X

⚠️ Requisitos importantes:
Linux: Ubuntu, Debian, CentOS, etc.
Permisos sudo: Para ejecutar Docker
Puertos libres: 80, 443, 8008
Espacio USB: Mínimo 4GB, recomendado 8GB+

# Instrucciones
Conecta tu USB
Identifica el dispositivo (lsblk)
- Ver todos los dispositivos de bloque
lsblk

- Resultado típico:
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda      8:0    0 238.5G  0 disk 
├─sda1   8:1    0   512M  0 part /boot/efi
├─sda2   8:2    0     1G  0 part /boot
└─sda3   8:3    0   237G  0 part /
sdb      8:16   1    32G  0 disk           ← USB detectado!
└─sdb1   8:17   1    32G  0 part /media/pablety/USB-NAME


-Ejecuta el script (sudo ./matrix-portable.sh /dev/sdX)



# Reiniciar Matrix si hay problemas
sudo systemctl restart matrix-synapse

# Ver usuarios registrados
sudo -u postgres psql -d synapse -c "SELECT name FROM users;"

# Ver estadísticas del servidor
sudo matrix-stats.sh  # (si incluiste este script)


Usar script para crear el USB portable. Te muestro exactamente cómo:

## 🚀 Pasos para crear tu USB Matrix Portable:

### 1. **Preparar el script:**
```bash
# Guardar el script
nano matrix-portable.sh

# Copiar todo el contenido del script
# Guardarlo con Ctrl+X, Y, Enter

# Hacer ejecutable
chmod +x matrix-portable.sh
```

### 2. **Identificar tu USB:**
```bash
# Ver dispositivos conectados
lsblk

# Debería mostrar algo como:
# NAME   SIZE TYPE MOUNTPOINT
# sda    500G disk 
# ├─sda1 500G part /
# sdb      8G disk              ← Este sería tu USB
# └─sdb1   8G part 
```

### 3. **Ejecutar el script:**
```bash
# Crear el USB (reemplaza /dev/sdb con tu USB)
sudo ./matrix-portable.sh /dev/sdb
```

### 4. **El proceso será así:**
```
🔧 Creando Matrix USB Docker Portable...
⚠️  Se borrará todo en /dev/sdb
¿Continuar? [y/N]: y
💾 Formateando USB...
🐳 Descargando Docker portátil...
🔧 Descargando Docker Compose...
📦 Creando estructura Matrix USB...
🔧 Finalizando USB...
✅ Matrix USB Docker Portable creado exitosamente!
```

## 📋 Lo que tendrás en el USB después:

```
USB/
├── matrix-usb.sh          ← Script principal para ejecutar
├── LEEME.txt             ← Instrucciones de uso
├── limpiar.sh            ← Limpia contenedores
├── backup.sh             ← Crea backups
├── bin/                  ← Docker binarios portátiles
│   ├── docker
│   ├── dockerd
│   └── docker-compose
└── matrix-data/          ← Datos persistentes (se crea al usar)
    ├── postgresql/
    ├── synapse/
    ├── element/
    └── ssl/
```

## 🔌 Usar el USB en cualquier computadora:

```bash
# 1. Conectar USB y montarlo
cd /media/pablety/MATRIX-USB  # (o donde se monte)

# 2. Ejecutar Matrix
sudo ./matrix-usb.sh

# 3. Acceder a Matrix
# El script te mostrará la URL: https://192.168.X.X
```

## ⚠️ Requisitos importantes:

- **Linux:** Ubuntu, Debian, CentOS, etc.
- **Permisos sudo:** Para ejecutar Docker
- **Puertos libres:** 80, 443, 8008
- **Espacio USB:** Mínimo 4GB, recomendado 8GB+

## 🛠️ Si hay problemas:

### Docker no funciona:
```bash
# Instalar Docker en el sistema host
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Reiniciar sesión
```

### Puertos ocupados:
```bash
# Ver qué usa los puertos
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# Parar servicios que los usen
sudo systemctl stop apache2 nginx
```

## 🎯 **Instrucciones**

1. **Conecta tu USB**
2. **Identifica el dispositivo** (`lsblk`)
3. **Ejecuta el script** (`sudo ./matrix-usb-docker-portable.sh /dev/sdX`)
4. **Espera 10-15 minutos** (descarga Docker + configuración)
5. **¡USB Matrix listo!**

