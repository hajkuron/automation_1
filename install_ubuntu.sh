#!/bin/bash

echo "🚀 Starting automation setup..."

# Create and track installation directory
INSTALL_DIR="$HOME/automation_projects/automation_1"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit 1

# Update package list
echo "📦 Updating package list..."
sudo apt-get update

# Install Python if not present
if ! command -v python3 &> /dev/null; then
    echo "🐍 Installing Python..."
    sudo apt-get install -y python3 python3-pip
fi

# Install Git if not present
if ! command -v git &> /dev/null; then
    echo "📥 Installing Git..."
    sudo apt-get install -y git
fi

# Clone repository
echo "📥 Cloning automation repository..."
git clone https://github.com/hajkuhar/automation_1.git .

# Install requirements
echo "📦 Installing Python packages..."
pip3 install -r requirements.txt

# Create systemd service file
echo "🔧 Creating systemd service..."
sudo tee /etc/systemd/system/prefect-worker.service << EOF
[Unit]
Description=Prefect Worker Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=${INSTALL_DIR}
Environment="PREFECT_API_KEY=pnu_izU73gpf25wpuCTGNx27RB8kGVtzdj2jNB3J"
ExecStart=/usr/local/bin/prefect worker start -p local-automation -t process
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Start and enable the service
sudo systemctl daemon-reload
sudo systemctl enable prefect-worker
sudo systemctl start prefect-worker

echo "✅ Setup complete! Worker is running and will start automatically on boot."
