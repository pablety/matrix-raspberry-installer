#!/bin/bash

# Matrix Synapse Installer for Google Colab
# Compatible with Google Colab's restrictions and limitations
# Uses SQLite, user-level installation, and simple HTTP setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
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
║            Matrix Synapse for Google Colab v1.0               ║
║         SQLite + Element Web + User-level Installation        ║
║                                                                ║
║    🚀 No sudo required • 💾 Google Drive persistence           ║
║    🔧 Simple setup • 🌐 Local HTTP server                      ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Configuration
MATRIX_HOME="$HOME/matrix-colab"
MATRIX_DATA="$MATRIX_HOME/data"
MATRIX_MEDIA="$MATRIX_HOME/media"
MATRIX_ENV="$MATRIX_HOME/env"
ELEMENT_PATH="$MATRIX_HOME/element"
DB_PATH="$MATRIX_DATA/synapse.db"
SERVER_NAME="colab-matrix.local"
HTTP_PORT="8008"
ELEMENT_PORT="8080"

# Detect if running in Google Colab
if [ -n "$COLAB_GPU" ] || [ -n "$COLAB_TPU_ADDR" ] || [ -d "/content" ]; then
    log_info "🔍 Google Colab environment detected"
    COLAB_MODE=true
    # Use /content for Colab persistence if available
    if [ -d "/content" ]; then
        MATRIX_HOME="/content/matrix-colab"
        MATRIX_DATA="/content/matrix-colab/data"
        MATRIX_MEDIA="/content/matrix-colab/media"
        MATRIX_ENV="/content/matrix-colab/env"
        ELEMENT_PATH="/content/matrix-colab/element"
        DB_PATH="/content/matrix-colab/data/synapse.db"
    fi
else
    COLAB_MODE=false
    log_info "🖥️  Running in standard Linux environment"
fi

log_info "📁 Matrix home: $MATRIX_HOME"
log_info "🗄️  Database: $DB_PATH"
log_info "🌐 Server name: $SERVER_NAME"
log_info "🔌 HTTP port: $HTTP_PORT"
log_info "🎨 Element port: $ELEMENT_PORT"

# Verify Python version
if ! python3 --version >/dev/null 2>&1; then
    log_error "Python 3 not found. Please install Python 3.7+"
    exit 1
fi

PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
log_info "🐍 Python version: $PYTHON_VERSION"

# Create directory structure
log "📁 Creating directory structure..."
mkdir -p "$MATRIX_HOME"
mkdir -p "$MATRIX_DATA"
mkdir -p "$MATRIX_MEDIA"
mkdir -p "$ELEMENT_PATH"

log_success "Directory structure created"

# Create virtual environment
log "🔧 Setting up Python virtual environment..."
python3 -m venv "$MATRIX_ENV"
source "$MATRIX_ENV/bin/activate"

# Upgrade pip and install requirements
log "📦 Installing Matrix Synapse and dependencies..."
pip install --upgrade pip setuptools wheel

# Install Matrix Synapse with SQLite support
pip install matrix-synapse[sqlite] twisted[tls]

log_success "Matrix Synapse installed"

# Generate basic configuration
log "⚙️  Generating Matrix configuration..."
cd "$MATRIX_HOME"

# Generate initial configuration
python -m synapse.app.homeserver \
    --server-name="$SERVER_NAME" \
    --config-path="$MATRIX_HOME/homeserver.yaml" \
    --generate-config \
    --report-stats=no \
    --data-directory="$MATRIX_DATA"

# Customize configuration for Colab
log "🔧 Customizing configuration for Colab..."
cat > "$MATRIX_HOME/homeserver.yaml" << EOF
# Matrix Synapse Configuration for Google Colab
server_name: "$SERVER_NAME"
pid_file: $MATRIX_HOME/homeserver.pid
public_baseurl: "http://localhost:$HTTP_PORT"

listeners:
  - port: $HTTP_PORT
    tls: false
    type: http
    x_forwarded: false
    bind_addresses: ['0.0.0.0']
    resources:
      - names: [client, federation]
        compress: false

# SQLite Database (no PostgreSQL needed)
database:
  name: sqlite3
  args:
    database: $DB_PATH

log_config: "$MATRIX_HOME/log_config.yaml"
media_store_path: $MATRIX_MEDIA

# Registration settings (open for easy testing)
enable_registration: true
enable_registration_without_verification: true
registrations_require_3pid: []
allowed_local_3pids: []
enable_3pid_lookup: false

# Disable federation for local use
federation_domain_whitelist: []
federation_ip_range_blacklist:
  - '127.0.0.0/8'
  - '10.0.0.0/8'
  - '172.16.0.0/12'
  - '192.168.0.0/16'
  - '100.64.0.0/10'
  - '169.254.0.0/16'
  - '::1/128'
  - 'fe80::/64'
  - 'fc00::/7'

# Security keys
registration_shared_secret: "$(openssl rand -hex 32)"
macaroon_secret_key: "$(openssl rand -hex 32)"
form_secret: "$(openssl rand -hex 32)"
signing_key_path: "$MATRIX_HOME/homeserver.signing.key"

# Performance settings for limited resources
enable_metrics: false
enable_media_repo: true
max_upload_size: 25M
max_image_pixels: 16M

# Disable unnecessary features
allow_guest_access: false
enable_group_creation: false
autocreate_auto_join_rooms: false

# Cache settings for limited memory
caches:
  global_factor: 0.5
  expire_caches: true
  cache_entry_ttl: 30m

# Report stats
report_stats: false

# Presence disabled for performance
presence:
  enabled: false

# Room directory
enable_room_list_search: true
alias_creation_rules: []

# URL preview disabled to save resources
url_preview_enabled: false

# Trust proxy headers (for Colab tunneling)
x_forwarded: true
EOF

# Create logging configuration
log "📝 Creating logging configuration..."
cat > "$MATRIX_HOME/log_config.yaml" << 'EOF'
version: 1

formatters:
  precise:
    format: '%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(message)s'

handlers:
  console:
    class: logging.StreamHandler
    formatter: precise
    stream: ext://sys.stdout
  file:
    class: logging.handlers.RotatingFileHandler
    formatter: precise
    filename: /content/matrix-colab/synapse.log
    maxBytes: 10485760
    backupCount: 3

root:
    level: INFO
    handlers: [console, file]

disable_existing_loggers: false
EOF

# Generate signing key
log "🔐 Generating server signing key..."
python -m synapse.app.homeserver \
    --config-path="$MATRIX_HOME/homeserver.yaml" \
    --generate-keys \
    --data-directory="$MATRIX_DATA"

log_success "Matrix configuration completed"

# Install and configure Element Web
log "🌐 Installing Element Web..."
cd "$ELEMENT_PATH"

# Download Element Web
ELEMENT_VERSION="v1.11.69"
ELEMENT_URL="https://github.com/vector-im/element-web/releases/download/$ELEMENT_VERSION/element-$ELEMENT_VERSION.tar.gz"

if wget -q --timeout=30 "$ELEMENT_URL"; then
    tar -xzf "element-$ELEMENT_VERSION.tar.gz" --strip-components=1
    rm "element-$ELEMENT_VERSION.tar.gz"
    log_success "Element Web downloaded and extracted"
else
    log_warning "Failed to download Element Web, using fallback"
    # Create a simple fallback index.html
    cat > index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Matrix Colab Server</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin: 50px; }
        .container { max-width: 600px; margin: 0 auto; }
        .status { padding: 20px; background: #f0f0f0; border-radius: 8px; margin: 20px 0; }
        .url { background: #e8f4f8; padding: 10px; border-radius: 4px; word-break: break-all; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Matrix Synapse Server Running</h1>
        <div class="status">
            <h3>Server Status: ✅ Active</h3>
            <p>Your Matrix server is running on port $HTTP_PORT</p>
        </div>
        <div class="status">
            <h3>📱 Connect with Matrix Client</h3>
            <p>Use any Matrix client (Element, SchildiChat, etc.) with:</p>
            <div class="url">http://localhost:$HTTP_PORT</div>
        </div>
        <div class="status">
            <h3>🔗 API Endpoints</h3>
            <p><a href="/_matrix/client/versions" target="_blank">/_matrix/client/versions</a></p>
            <p><a href="/_matrix/static/" target="_blank">/_matrix/static/</a></p>
        </div>
    </div>
</body>
</html>
EOF
fi

# Configure Element Web
log "🔧 Configuring Element Web..."
cat > "$ELEMENT_PATH/config.json" << EOF
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "http://localhost:$HTTP_PORT",
            "server_name": "$SERVER_NAME"
        }
    },
    "disable_custom_urls": false,
    "disable_guests": true,
    "brand": "Matrix Colab Server",
    "default_federate": false,
    "default_theme": "light",
    "features": {
        "feature_voice_messages": false,
        "feature_video_calls": false,
        "feature_audio_calls": false,
        "feature_thread": true
    },
    "showLabsSettings": false,
    "roomDirectory": {
        "servers": ["$SERVER_NAME"]
    }
}
EOF

log_success "Element Web configured"

# Create startup script
log "📝 Creating startup scripts..."
cat > "$MATRIX_HOME/start-matrix.sh" << EOF
#!/bin/bash
# Matrix Synapse Startup Script for Colab

cd "$MATRIX_HOME"
source "$MATRIX_ENV/bin/activate"

echo "🚀 Starting Matrix Synapse server..."
echo "📍 Server: http://localhost:$HTTP_PORT"
echo "🎨 Element: http://localhost:$ELEMENT_PORT"
echo ""

# Start Matrix Synapse in background
python -m synapse.app.homeserver --config-path="$MATRIX_HOME/homeserver.yaml" --daemonize

# Wait for Matrix to start
sleep 5

# Check if Matrix is running
if curl -s http://localhost:$HTTP_PORT/_matrix/client/versions > /dev/null 2>&1; then
    echo "✅ Matrix Synapse is running on port $HTTP_PORT"
else
    echo "❌ Matrix Synapse failed to start"
    exit 1
fi

# Start simple HTTP server for Element (if available)
if [ -f "$ELEMENT_PATH/index.html" ]; then
    cd "$ELEMENT_PATH"
    echo "🌐 Starting Element Web server on port $ELEMENT_PORT..."
    python3 -m http.server $ELEMENT_PORT --bind 0.0.0.0 > /dev/null 2>&1 &
    ELEMENT_PID=\$!
    echo "✅ Element Web is running on port $ELEMENT_PORT"
fi

echo ""
echo "🎉 Matrix server is ready!"
echo "📱 Connect using any Matrix client:"
echo "   Server: http://localhost:$HTTP_PORT"
echo "🌐 Web interface: http://localhost:$ELEMENT_PORT"
echo ""
echo "👤 Create your first user with:"
echo "   $MATRIX_ENV/bin/register_new_matrix_user -c $MATRIX_HOME/homeserver.yaml http://localhost:$HTTP_PORT"
echo ""
echo "Press Ctrl+C to stop all services"

# Keep script running
trap 'echo "🛑 Stopping services..."; kill \$ELEMENT_PID 2>/dev/null; pkill -f synapse; exit 0' INT

while true; do
    sleep 60
    # Check if Matrix is still running
    if ! curl -s http://localhost:$HTTP_PORT/_matrix/client/versions > /dev/null 2>&1; then
        echo "❌ Matrix Synapse stopped unexpectedly"
        break
    fi
done
EOF

chmod +x "$MATRIX_HOME/start-matrix.sh"

# Create user registration helper
cat > "$MATRIX_HOME/create-user.sh" << EOF
#!/bin/bash
# Helper script to create Matrix users

cd "$MATRIX_HOME"
source "$MATRIX_ENV/bin/activate"

echo "👤 Creating new Matrix user..."
echo "📍 Server: $SERVER_NAME"
echo ""

$MATRIX_ENV/bin/register_new_matrix_user -c $MATRIX_HOME/homeserver.yaml http://localhost:$HTTP_PORT
EOF

chmod +x "$MATRIX_HOME/create-user.sh"

# Create stop script
cat > "$MATRIX_HOME/stop-matrix.sh" << EOF
#!/bin/bash
# Stop Matrix services

echo "🛑 Stopping Matrix services..."

# Stop Matrix Synapse
pkill -f synapse && echo "✅ Matrix Synapse stopped" || echo "ℹ️  Matrix Synapse was not running"

# Stop Element server
pkill -f "http.server $ELEMENT_PORT" && echo "✅ Element Web stopped" || echo "ℹ️  Element Web was not running"

echo "🏁 All services stopped"
EOF

chmod +x "$MATRIX_HOME/stop-matrix.sh"

# Create Google Drive sync script (for Colab)
if [ "$COLAB_MODE" = true ]; then
    log "☁️  Creating Google Drive integration..."
    cat > "$MATRIX_HOME/sync-gdrive.py" << 'EOF'
#!/usr/bin/env python3
"""
Google Drive sync for Matrix Colab data persistence
"""

import os
import shutil
import zipfile
from pathlib import Path

def mount_gdrive():
    """Mount Google Drive in Colab"""
    try:
        from google.colab import drive
        drive.mount('/content/drive')
        print("✅ Google Drive mounted")
        return True
    except ImportError:
        print("❌ Not running in Google Colab")
        return False
    except Exception as e:
        print(f"❌ Error mounting Google Drive: {e}")
        return False

def backup_to_gdrive():
    """Backup Matrix data to Google Drive"""
    if not mount_gdrive():
        return False
    
    try:
        matrix_home = Path("/content/matrix-colab")
        backup_dir = Path("/content/drive/MyDrive/Matrix_Backup")
        backup_dir.mkdir(exist_ok=True)
        
        # Create backup archive
        backup_file = backup_dir / "matrix_colab_backup.zip"
        
        print("📦 Creating backup archive...")
        with zipfile.ZipFile(backup_file, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for root, dirs, files in os.walk(matrix_home):
                for file in files:
                    file_path = Path(root) / file
                    arc_path = file_path.relative_to(matrix_home.parent)
                    zipf.write(file_path, arc_path)
        
        print(f"✅ Backup saved to: {backup_file}")
        print(f"📊 Backup size: {backup_file.stat().st_size / 1024 / 1024:.1f} MB")
        return True
        
    except Exception as e:
        print(f"❌ Backup failed: {e}")
        return False

def restore_from_gdrive():
    """Restore Matrix data from Google Drive"""
    if not mount_gdrive():
        return False
    
    try:
        backup_file = Path("/content/drive/MyDrive/Matrix_Backup/matrix_colab_backup.zip")
        
        if not backup_file.exists():
            print("ℹ️  No backup found in Google Drive")
            return False
        
        print("📥 Restoring from backup...")
        
        # Extract backup
        with zipfile.ZipFile(backup_file, 'r') as zipf:
            zipf.extractall("/content")
        
        print("✅ Backup restored successfully")
        return True
        
    except Exception as e:
        print(f"❌ Restore failed: {e}")
        return False

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) != 2:
        print("Usage: python sync-gdrive.py [backup|restore]")
        sys.exit(1)
    
    action = sys.argv[1].lower()
    
    if action == "backup":
        backup_to_gdrive()
    elif action == "restore":
        restore_from_gdrive()
    else:
        print("Invalid action. Use 'backup' or 'restore'")
        sys.exit(1)
EOF

    chmod +x "$MATRIX_HOME/sync-gdrive.py"
    log_success "Google Drive sync script created"
fi

# Create info script
cat > "$MATRIX_HOME/matrix-info.sh" << EOF
#!/bin/bash
# Matrix Colab Server Information

echo "🖥️  Matrix Synapse for Google Colab"
echo "=================================="
echo ""
echo "📁 Installation path: $MATRIX_HOME"
echo "🗄️  Database: $DB_PATH"
echo "🌐 Server name: $SERVER_NAME"
echo "🔌 HTTP port: $HTTP_PORT"
echo "🎨 Element port: $ELEMENT_PORT"
echo ""
echo "🔗 Access URLs:"
echo "   Matrix API: http://localhost:$HTTP_PORT"
echo "   Element Web: http://localhost:$ELEMENT_PORT"
echo ""
echo "📝 Available commands:"
echo "   Start server: $MATRIX_HOME/start-matrix.sh"
echo "   Stop server: $MATRIX_HOME/stop-matrix.sh"
echo "   Create user: $MATRIX_HOME/create-user.sh"
echo "   Server info: $MATRIX_HOME/matrix-info.sh"
echo ""
echo "📊 Status:"
if curl -s http://localhost:$HTTP_PORT/_matrix/client/versions > /dev/null 2>&1; then
    echo "   Matrix: ✅ Running"
else
    echo "   Matrix: ❌ Stopped"
fi

if curl -s http://localhost:$ELEMENT_PORT > /dev/null 2>&1; then
    echo "   Element: ✅ Running"
else
    echo "   Element: ❌ Stopped"
fi

if [ -f "$DB_PATH" ]; then
    DB_SIZE=\$(du -h "$DB_PATH" | cut -f1)
    echo "   Database: \$DB_SIZE"
fi
EOF

chmod +x "$MATRIX_HOME/matrix-info.sh"

# Final setup and summary
log "🎯 Final setup..."

# Initialize database
cd "$MATRIX_HOME"
source "$MATRIX_ENV/bin/activate"

log "🗄️  Initializing SQLite database..."
python -m synapse.app.homeserver --config-path="$MATRIX_HOME/homeserver.yaml" --generate-keys --data-directory="$MATRIX_DATA"

log_success "Database initialized"

# Create quick start guide
cat > "$MATRIX_HOME/README.md" << EOF
# Matrix Synapse for Google Colab

This is your Matrix Synapse server configured for Google Colab!

## 🚀 Quick Start

1. **Start the server:**
   \`\`\`bash
   cd $MATRIX_HOME
   ./start-matrix.sh
   \`\`\`

2. **Create your first user:**
   \`\`\`bash
   ./create-user.sh
   \`\`\`

3. **Access your server:**
   - Matrix API: http://localhost:$HTTP_PORT
   - Element Web: http://localhost:$ELEMENT_PORT

## 📱 Using Matrix Clients

You can connect with any Matrix client:
- **Element:** Use the web interface or desktop/mobile apps
- **SchildiChat:** Alternative client with extra features
- **FluffyChat:** Mobile-focused client

Server URL: \`http://localhost:$HTTP_PORT\`

## 💾 Data Persistence

EOF

if [ "$COLAB_MODE" = true ]; then
cat >> "$MATRIX_HOME/README.md" << EOF
For Google Colab persistence, use the Google Drive sync:

\`\`\`python
# Backup to Google Drive
python sync-gdrive.py backup

# Restore from Google Drive
python sync-gdrive.py restore
\`\`\`

EOF
fi

cat >> "$MATRIX_HOME/README.md" << EOF
## 🛠️ Commands

- \`./start-matrix.sh\` - Start all services
- \`./stop-matrix.sh\` - Stop all services  
- \`./create-user.sh\` - Create new user
- \`./matrix-info.sh\` - Show server info

## 📁 Directory Structure

- \`$MATRIX_HOME/\` - Main directory
- \`$MATRIX_DATA/\` - Database and data
- \`$MATRIX_MEDIA/\` - Media uploads
- \`$ELEMENT_PATH/\` - Element Web files

## 🔧 Configuration

- \`homeserver.yaml\` - Main Matrix config
- \`log_config.yaml\` - Logging config
- \`element/config.json\` - Element Web config

Enjoy your Matrix server! 🎉
EOF

# Installation complete
echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    ✅ INSTALLATION COMPLETE                     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${PURPLE}🏠 INSTALLATION DIRECTORY:${NC} $MATRIX_HOME"
echo -e "${PURPLE}🗄️  DATABASE:${NC} $DB_PATH"
echo -e "${PURPLE}🌐 SERVER NAME:${NC} $SERVER_NAME"

echo -e "\n${YELLOW}🚀 TO START YOUR MATRIX SERVER:${NC}"
echo -e "   ${GREEN}cd $MATRIX_HOME${NC}"
echo -e "   ${GREEN}./start-matrix.sh${NC}"

echo -e "\n${YELLOW}👤 TO CREATE YOUR FIRST USER:${NC}"
echo -e "   ${GREEN}./create-user.sh${NC}"

echo -e "\n${YELLOW}🔗 ACCESS URLS:${NC}"
echo -e "   Matrix API: ${GREEN}http://localhost:$HTTP_PORT${NC}"
echo -e "   Element Web: ${GREEN}http://localhost:$ELEMENT_PORT${NC}"

if [ "$COLAB_MODE" = true ]; then
    echo -e "\n${YELLOW}☁️  GOOGLE DRIVE PERSISTENCE:${NC}"
    echo -e "   Backup: ${GREEN}python sync-gdrive.py backup${NC}"
    echo -e "   Restore: ${GREEN}python sync-gdrive.py restore${NC}"
fi

echo -e "\n${BLUE}🎉 Your Matrix server is ready for Google Colab!${NC}"
echo -e "${BLUE}   📖 Read $MATRIX_HOME/README.md for detailed instructions${NC}"

exit 0