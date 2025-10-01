
## Required Setup

```bash
# Update package list
sudo apt-get update

# Install AWS CLI v2 (recommended)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt-get install unzip
unzip awscliv2.zip
sudo ./aws/install
aws --version

# Install other dependencies
sudo apt-get install -y jq bc 
```


## Simple bash Command to Cross Check
```bash
#!/bin/bash
echo "🔍 Checking dependencies..."
command -v aws && echo "✅ AWS CLI installed" || echo "❌ AWS CLI missing"
command -v jq && echo "✅ jq installed" || echo "❌ jq missing" 
command -v bc && echo "✅ bc installed" || echo "❌ bc missing"

echo "🔍 Checking AWS configuration..."
aws sts get-caller-identity && echo "✅ AWS credentials working" || echo "❌ AWS credentials issue"

echo "🔍 Checking script permissions..."
ls -la *.sh | grep -v ^d
```