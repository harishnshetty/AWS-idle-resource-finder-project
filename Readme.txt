
# 🚀 AWS Cost & Security Audit (AWS Resource Finder )
## Comprehensive cloud infrastructure assessment report


## For more projects, check out  
[https://harishnshetty.github.io/projects.html](https://harishnshetty.github.io/projects.html)

[![Video Tutorial](https://github.com/harishnshetty/image-data-project/blob/5d2e06ffa3dd7687607b0c7d4892a6b161c077f9/10%20microservice%20online%20shop%20project.jpg)](https://youtu.be/KNH_qe1vJAg)

## Required Setup



# One command to install everything
```bash
curl -sSL https://raw.githubusercontent.com/harishnshetty/AWS-idle-resource-finder-project/main/install_dependencies.sh | bash
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