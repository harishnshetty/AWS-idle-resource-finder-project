#!/bin/bash
set -euo pipefail

echo "🚀 Installing AWS Audit Tool Dependencies..."
echo "=============================================="

# Function to check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install core packages
echo "📦 Installing core packages..."
sudo apt install -y curl wget git unzip jq python3 python3-pip build-essential

# Install AWS CLI v2
if ! command_exists aws; then
    echo "📦 Installing AWS CLI v2..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws/
else
    echo "✅ AWS CLI already installed"
fi

# Install additional utilities
echo "📦 Installing additional utilities..."
sudo apt install -y moreutils tree htop ncdu


# Verify installations
echo "🔍 Verifying installations..."
echo "AWS CLI version: $(aws --version 2>/dev/null || echo 'Not installed')"
echo "Python3 version: $(python3 --version)"
echo "jq version: $(jq --version)"

echo ""
echo "🎉 All dependencies installed successfully!"
echo "=============================================="
echo "Next steps:"
echo "1. Run: aws configure"
echo "2. Clone your repository: git clone https://github.com/harishnshetty/AWS-idle-resource-finder-project.git"
echo "3. Make scripts executable: chmod +x *.sh"
echo "4. Run: ./main.sh"
echo "=============================================="