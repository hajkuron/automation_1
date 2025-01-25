#!/bin/bash

echo "🚀 Starting automation setup..."

# Create and track installation directory
INSTALL_DIR="$HOME/automation_projects/automation_1"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit 1

# Install Homebrew if not present
if ! command -v brew &> /dev/null; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install Python if not present
if ! command -v python3 &> /dev/null; then
    echo "🐍 Installing Python..."
    brew install python@3.10
fi

# Clone repository
echo "📥 Cloning automation repository..."
git clone https://github.com/hajkuhar/automation_1.git .

# Install requirements
echo "📦 Installing Python packages..."
pip3 install -r requirements.txt

# Create LaunchAgent with correct working directory
cat > ~/Library/LaunchAgents/com.prefect.worker.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.prefect.worker</string>
    <key>WorkingDirectory</key>
    <string>${INSTALL_DIR}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/prefect</string>
        <string>worker</string>
        <string>start</string>
        <string>-p</string>
        <string>local-automation</string>
        <string>-t</string>
        <string>process</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${HOME}/Library/Logs/prefect-worker.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/Library/Logs/prefect-worker-error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PREFECT_API_KEY</key>
        <string>pnu_izU73gpf25wpuCTGNx27RB8kGVtzdj2jNB3J</string>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
EOF

# Start the worker
launchctl load ~/Library/LaunchAgents/com.prefect.worker.plist

echo "
✅ Setup Complete! 
Your automation is now running and will start automatically when you turn on your computer.
The Prefect worker is connected to the 'local-automation' pool.

To update in the future, just run: ./update.sh

Need help? Contact: [Your Email]
"
