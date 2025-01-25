#!/bin/bash

echo "🚀 Starting automation setup..."

# Prompt for GitHub token
echo "Please enter your GitHub Personal Access Token:"
read -r GITHUB_TOKEN

# Create and track installation directory
INSTALL_DIR="$HOME/automation_projects/automation_1"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit 1

# Update package list
echo "📦 Updating package list..."
sudo apt-get update

# Install Python and pip if not present
echo "🐍 Installing Python and pip..."
sudo apt-get install -y python3 python3-pip

# Install Git if not present
if ! command -v git &> /dev/null; then
    echo "📥 Installing Git..."
    sudo apt-get install -y git
fi

# Configure Git with token
git config --global credential.helper store
echo "https://${GITHUB_TOKEN}:x-oauth-basic@github.com" > ~/.git-credentials

# Clone repository
echo "📥 Cloning automation repository..."
git clone https://github.com/hajkuron/automation_1.git .

# Install prefect first
echo "📦 Installing Prefect..."
pip3 install prefect

# Install other requirements
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
Environment="PATH=/usr/local/bin:/usr/bin:/bin:${HOME}/.local/bin"
Environment="GITHUB_TOKEN=${GITHUB_TOKEN}"
ExecStart=${HOME}/.local/bin/prefect worker start -p ubuntu_pool -t process
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Start and enable the service
sudo systemctl daemon-reload
sudo systemctl enable prefect-worker
sudo systemctl start prefect-worker

echo "✅ Setup complete! Worker is running and will start automatically on boot."
