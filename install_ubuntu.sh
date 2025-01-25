#!/bin/bash

echo "🚀 Starting automation setup..."

# Prompt for GitHub token
echo "Please enter your GitHub Personal Access Token:"
read -r GITHUB_TOKEN

# Create and track installation directory
INSTALL_DIR="$HOME/automation_projects/automation_1"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit 1

# Update package list and install dependencies
echo "📦 Updating package list..."
sudo apt-get update
sudo apt-get install -y python3-venv python3-pip

# Create and activate virtual environment
echo "🐍 Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Clone repository
echo "📥 Cloning automation repository..."
git clone https://github.com/hajkuron/automation_1.git .

# Install Python packages in virtual environment
echo "📦 Installing Python packages..."
pip install prefect
pip install -r requirements.txt

# Create systemd service file with virtual environment path
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
Environment="GITHUB_TOKEN=${GITHUB_TOKEN}"
Environment="PREFECT_API_URL=https://api.prefect.cloud/api/accounts/35ea75b4-220d-4af8-8e1f-0e49eea9ed3e/workspaces/cbb914b8-9c4e-4e45-93c4-dfd630f74bb4"
ExecStart=${INSTALL_DIR}/venv/bin/prefect worker start -p ubuntu_pool -t process
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Start and enable the service
sudo systemctl daemon-reload
sudo systemctl enable prefect-worker
sudo systemctl start prefect-worker

echo "✅ Setup complete! Worker is running and will start automatically on boot."
