
## Required Setup


# One command to install everything
```bash
curl -sSL https://raw.githubusercontent.com/harishnshetty/AWS-idle-resource-finder-project/install_dependencies.sh | bash
```


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

```bash
aws configure
```