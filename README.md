# sentinel-repo
Flagship threat intelligence platform

### Deployment Steps

```bash
# 1. Clone the repository
git clone <repository-url>
cd sentinel-repo

# 2. Configure AWS credentials
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_REGION="us-west-2"

# 3. Running initial bootstrap script for s3 remote backend
chmod +x ./scripts/initial-setup.sh && ./scripts/initial-setup.sh
```


