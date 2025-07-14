# matrix-installer

## 🚀 Google Colab Installation (NEW!)
**Run Matrix Synapse directly in Google Colab - No local setup required!**

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/pablety/matrix-raspberry-installer/blob/main/Matrix_Synapse_Colab.ipynb)

- ✅ **No sudo required** - User-level installation  
- ✅ **SQLite database** - No PostgreSQL complexity
- ✅ **Element Web included** - Ready-to-use web interface  
- ✅ **Google Drive persistence** - Save data between sessions
- ✅ **Public tunneling** - Access from anywhere
- ✅ **One-click setup** - Just run the notebook!

### Manual Colab Installation
```bash
curl -fsSL https://raw.githubusercontent.com/pablety/matrix-raspberry-installer/main/install-matrix-colab.sh | bash
```

---

## 🖥️ Traditional Linux Installation
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


Usar script para crear el USB portable

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
3. **Ejecuta el script** (`sudo ./matrix-portable.sh /dev/sdX`)
4. **Espera 10-15 minutos** (descarga Docker + configuración)
5. **¡USB Matrix listo!**

EJ:
root@servidor:~$ cd /mnt/usb-matrix
root@servidor:~$ ./matrix-usb.sh
-Matrix USB Docker Portable  
-IP detectada: 203.45.67.89
💾 Datos en: /mnt/usb-matrix/matrix-data
✅ Matrix funcionando en: https://203.45.67.89




## Como se conservan los datos?

cómo se configuró la persistencia de la base de datos PostgreSQL:

## 🔧 **Configuración de persistencia en el script:**

### 1. **Volúmenes Docker mapeados:**
```yaml
# En docker-compose.yml:
postgresql:
  image: postgres:15-alpine
  volumes:
    - $DATA_DIR/postgresql:/var/lib/postgresql/data  ← CLAVE
```

**Explicación:**
- `$DATA_DIR/postgresql` = Carpeta en el USB
- `/var/lib/postgresql/data` = Donde PostgreSQL guarda datos dentro del contenedor
- **Mapeo:** Los datos del contenedor se guardan en el USB

### 2. **Estructura de datos en el USB:**
```bash
USB/
└── matrix-data/
    ├── postgresql/           ← Base de datos PostgreSQL
    │   ├── base/            ← Tablas y datos
    │   ├── global/          ← Configuración global
    │   ├── pg_wal/          ← Write-Ahead Logs
    │   ├── pg_tblspc/       ← Tablespaces
    │   └── postgresql.conf  ← Configuración
    ├── synapse/             ← Configuración Matrix
    └── ssl/                 ← Certificados
```

### 3. **Variables de entorno que conectan todo:**
```yaml
# PostgreSQL container:
environment:
  POSTGRES_DB: synapse           ← Base de datos
  POSTGRES_USER: synapse_user    ← Usuario
  POSTGRES_PASSWORD: usb_matrix_2024  ← Contraseña

# Matrix container:
database:
  name: psycopg2
  args:
    user: synapse_user
    password: usb_matrix_2024
    database: synapse
    host: postgresql             ← Nombre del contenedor
    port: 5432
```

## 💾 **Qué datos específicos se conservan:**

### **En PostgreSQL (`postgresql/` folder):**
```sql
-- Tablas principales que persisten:
users                 -- Usuarios registrados
rooms                 -- Salas/canales
room_memberships      -- Miembros de salas
events                -- Mensajes y eventos
media_repository      -- Archivos subidos
device_lists          -- Dispositivos conectados
access_tokens         -- Tokens de sesión
```

### **En Matrix Synapse (`synapse/` folder):**
```
homeserver.yaml       -- Configuración principal
signing.key          -- Clave criptográfica del servidor
media_store/         -- Archivos multimedia
```

## 🔄 **Flujo de persistencia:**

### **Primera ejecución (USB nuevo):**
```bash
# 1. Se crea estructura vacía
mkdir -p $DATA_DIR/postgresql

# 2. PostgreSQL inicializa base de datos
docker run postgres:15-alpine  # Crea tablas iniciales

# 3. Matrix configura esquema
docker run matrixdotorg/synapse generate  # Crea homeserver.yaml
```

### **Ejecuciones posteriores (USB usado):**
```bash
# 1. Detecta datos existentes
if [ -f $DATA_DIR/synapse/homeserver.yaml ]; then
    echo "🔄 Cargando configuración existente..."

# 2. Monta volúmenes existentes
docker-compose up -d  # Usa datos del USB

# 3. PostgreSQL lee datos existentes
# 4. Matrix usa configuración existente
```

## 🎯 **Verificación de persistencia:**

```bash
# Ver datos de PostgreSQL en el USB
ls -la /media/pablety/MATRIX-USB/matrix-data/postgresql/
# Deberías ver: base/ global/ pg_wal/ postgresql.conf

# Ver usuarios en la base de datos
docker exec -it matrix-usb-postgres psql -U synapse_user -d synapse
# Dentro de PostgreSQL:
SELECT name FROM users;  -- Ver usuarios registrados
SELECT room_id FROM rooms;  -- Ver salas
```

## 🔍 **Configuración técnica detallada:**

### **Docker Compose volumes:**
```yaml
services:
  postgresql:
    volumes:
      # HOST_PATH:CONTAINER_PATH
      - $DATA_DIR/postgresql:/var/lib/postgresql/data
    # Esto hace que PostgreSQL escriba en el USB

  synapse:
    volumes:
      - $DATA_DIR/synapse:/data
    # Esto hace que Matrix lea/escriba config en el USB
```

### **Configuración PostgreSQL:**
```yaml
# En homeserver.yaml (generado automáticamente):
database:
  name: psycopg2
  args:
    user: synapse_user
    password: usb_matrix_2024
    database: synapse
    host: postgresql  # Nombre del contenedor
    port: 5432
    # Todos los datos van a /var/lib/postgresql/data
    # Que está mapeado al USB
```

## 🚀 **¿Por qué funciona entre computadoras?**

1. **Datos en USB:** Todo está en el USB, no en el disco duro
2. **Contenedores idénticos:** Mismo PostgreSQL, mismo Matrix
3. **Configuración portátil:** IP se detecta automáticamente
4. **Volúmenes mapeados:** Docker siempre mira al USB

## 🎮 **Ejemplo práctico:**

### **En casa (IP: 192.168.1.100):**
```bash
# Crear usuario
docker exec -it matrix-usb-synapse register_new_matrix_user
# Usuario: pablety
# Datos guardados en: USB/matrix-data/postgresql/base/
```

### **En oficina (IP: 10.0.0.50):**
```bash
# Mismo USB, nueva computadora
sudo ./matrix-usb.sh
# Matrix se inicia con IP 10.0.0.50
# Pero los datos están ahí: usuario pablety existe
```

**La clave es que PostgreSQL siempre lee/escribe en la misma carpeta del USB, sin importar en qué computadora esté.** 🎯
