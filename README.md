# Matrix Raspberry Installer

Complete installation script for Matrix Synapse + Element Web on Raspberry Pi with PostgreSQL database.

## Features

- **PostgreSQL Database**: Uses PostgreSQL as primary database (not SQLite)
- **HTTPS Support**: Automatic self-signed SSL certificates for local network
- **Optimized for Raspberry Pi**: PostgreSQL and Matrix Synapse optimized configurations
- **Element Web Client**: Pre-configured web interface
- **Nginx Reverse Proxy**: SSL-enabled reverse proxy configuration
- **mDNS Support**: Local network discovery with Avahi
- **Automatic Backups**: Daily PostgreSQL backups with retention
- **Monitoring Tools**: Health check and maintenance utilities
- **Systemd Services**: Auto-start services configuration

## Requirements

- Raspberry Pi (any model)
- Raspbian/Raspberry Pi OS
- Internet connection for installation
- Minimum 1GB RAM recommended
- At least 8GB free disk space

## Installation

1. Clone this repository:
```bash
git clone https://github.com/pablety/matrix-raspberry-installer.git
cd matrix-raspberry-installer
```

2. Run the installation script:
```bash
./install-matrix-raspberry.sh
```

The script will:
1. Update system packages
2. Install and configure PostgreSQL
3. Install Matrix Synapse with PostgreSQL support
4. Generate self-signed SSL certificates
5. Configure Nginx with HTTPS
6. Install and configure Element Web
7. Set up automatic backups and monitoring
8. Configure mDNS for local network access

## Access Information

After installation, access your Matrix server at:
- **Primary URL**: https://matrix-chat.local
- **By IP**: https://YOUR_PI_IP
- **By hostname**: https://YOUR_HOSTNAME.local

## Database Information

- **Database**: PostgreSQL (optimized for Raspberry Pi)
- **Host**: localhost:5432
- **Database**: matrix_synapse
- **User**: matrix
- **Credentials**: Stored in `/opt/matrix/db_config.txt`

## Maintenance Commands

- **Create user**: `sudo -u matrix /opt/matrix/env/bin/register_new_matrix_user -c /opt/matrix/homeserver.yaml http://localhost:8008`
- **View logs**: `sudo journalctl -u matrix-synapse -f`
- **Restart service**: `sudo systemctl restart matrix-synapse`
- **Database backup**: `/usr/local/bin/matrix-backup.sh`
- **System maintenance**: `/usr/local/bin/matrix-maintenance.sh`
- **Health monitor**: `/usr/local/bin/matrix-monitor.sh`

## File Locations

- **Configuration**: `/opt/matrix/homeserver.yaml`
- **Logs**: `/opt/matrix/homeserver.log`
- **Backups**: `/opt/matrix/backups/`
- **SSL Certificates**: `/etc/ssl/matrix/`
- **Element Web**: `/var/www/element/`

## Security Features

- HTTPS-only access with self-signed certificates
- PostgreSQL connection pooling
- Optimized security headers
- Local network isolation
- Automatic IP address updates

## Automatic Tasks

- **Daily backups** (2:00 AM): Database and configuration backup
- **Health monitoring** (every 5 minutes): Service health checks
- **IP updates** (every 10 minutes): Nginx configuration updates for IP changes

## Troubleshooting

Check service status:
```bash
sudo systemctl status postgresql matrix-synapse nginx avahi-daemon
```

View logs:
```bash
sudo journalctl -u matrix-synapse -u postgresql -f
```

## Technical Details

- **Matrix Synapse**: Latest version with PostgreSQL support
- **PostgreSQL**: Optimized for Raspberry Pi hardware
- **Element Web**: Latest stable version
- **Nginx**: SSL-enabled reverse proxy
- **Connection Pooling**: 5-10 connections configured
- **Memory Optimization**: Adapted for Raspberry Pi memory constraints