# Google Colab Matrix Installation Guide

## 🚀 Quick Start - One Click Setup

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/pablety/matrix-raspberry-installer/blob/main/Matrix_Synapse_Colab.ipynb)

Click the button above to open the Matrix Synapse setup notebook in Google Colab!

## 🎯 What You Get

- **Complete Matrix Server** - Full Matrix Synapse homeserver
- **Element Web Client** - Ready-to-use web interface  
- **Public Access** - Share with friends via tunnel URLs
- **Data Persistence** - Save/restore via Google Drive
- **No Setup Required** - Everything runs in your browser

## 📱 Features

✅ **Zero Installation** - Runs entirely in Google Colab  
✅ **SQLite Database** - No complex database setup  
✅ **HTTP Tunneling** - Access from anywhere  
✅ **Google Drive Backup** - Persistent data storage  
✅ **Element Web** - Modern chat interface  
✅ **Multi-device** - Connect any Matrix client  

## 🔧 Manual Installation

If you prefer to run the installer directly:

```bash
# Download and run the Colab installer
curl -fsSL https://raw.githubusercontent.com/pablety/matrix-raspberry-installer/main/install-matrix-colab.sh | bash

# Or download and inspect first
wget https://raw.githubusercontent.com/pablety/matrix-raspberry-installer/main/install-matrix-colab.sh
chmod +x install-matrix-colab.sh
./install-matrix-colab.sh
```

## 📋 Step-by-Step Process

1. **Open Colab Notebook** - Click the badge above
2. **Run Installation** - Execute the first cell
3. **Setup Google Drive** - Optional persistence
4. **Start Server** - Matrix starts automatically  
5. **Create Tunnel** - Get public URLs
6. **Create User** - Make your admin account
7. **Start Chatting** - Use Element Web or any Matrix client

## 🌐 Accessing Your Server

After setup, you'll get URLs like:
- **Matrix API**: `https://abc123.ngrok.io`
- **Element Web**: `https://def456.ngrok.io`

Share these with friends to let them join your server!

## 📱 Matrix Clients

Connect with any Matrix client:

**Web/Desktop:**
- Element Web (included)
- Element Desktop
- SchildiChat
- Cinny

**Mobile:**
- Element (Android/iOS)
- SchildiChat
- FluffyChat

## 💾 Data Persistence

Your Matrix data can be saved to Google Drive:

- **Automatic Backup** - Before session ends
- **Easy Restore** - Next time you run the notebook
- **Cross-Session** - Keep users, rooms, messages

## ⚠️ Limitations

- **Session Time** - Google Colab has 12-24 hour limits
- **Performance** - Limited to Colab resources
- **URLs Change** - Tunnel URLs reset each session
- **Internet Required** - Need connection for tunneling

## 🐛 Troubleshooting

**Server won't start:**
```bash
# Check logs
tail -f /content/matrix-colab/synapse.log

# Restart server
cd /content/matrix-colab
./stop-matrix.sh
./start-matrix.sh
```

**Can't access externally:**
- Re-run the tunneling cell in the notebook
- Check if ngrok URLs are still active
- Verify ports 8008 and 8080 are accessible

**Data lost:**
- Check Google Drive: MyDrive → Matrix_Backup
- Re-run the restore cell in the notebook
- Make sure to backup before ending sessions

## 🔐 Security Notes

- **Self-Signed Certs** - Browser warnings are normal
- **Public URLs** - Anyone with the URL can access
- **Temporary** - URLs change each session
- **Testing Only** - Not for production use

## 🎉 Enjoy Your Matrix Server!

You now have a fully functional Matrix chat server running in Google Colab. Perfect for:

- Testing Matrix features
- Chat with friends/family
- Learning about Matrix protocol
- Temporary chat rooms
- Development and testing

---

For permanent installations, see the other installers in this repository for Raspberry Pi, Ubuntu, and other Linux distributions.