# sentinel-repo
Flagship threat intelligence platform

### Deployment Steps Using Github Actions

#### 1. Clone the repository
```bash
git clone <repository-url>
cd sentinel-repo
```

#### 2. Configure AWS credentials
```bash
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_REGION="us-west-2"
```

#### 3. Running initial bootstrap script for s3 remote backend
```bash
chmod +x ./scripts/initial-setup.sh && ./scripts/initial-setup.sh
```

### 4. Update the s3 bucket name in ./terraform/environments/backend.tf
```bash
terraform {
    backend "s3" {
        bucket  = "s3 bucket name"
        key     = "dev/terraform.tfstate"
        region  = "us-west-2"
        encrypt = true
    }
}
```

#### 5. Trigger Github Action workflow
```bash
1. Go to 'Actions' in the repo and click on CI/CD pipeline on the left
2. You can trigger individual stage from 'Run Workflow' dropdown
3. Changes to ./terraform dir will run terraform and k8s stages
4. Changes to ./kubernetes dir will only run k8s stages
5. Destroy all is used to destroy everything in both k8s and terraform
```


