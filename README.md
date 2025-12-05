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
5. Copy the 'Gateway URL' and paste it in your browser to see the response from backend
6. Destroy all is used to destroy everything in both k8s and terraform
```

### Deploy Infra manually

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

### 5. Initialize Terraform, plan and apply
```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

#### 6. Configure kubectl for both clusters
```bash
aws eks update-kubeconfig --name eks-gateway --region us-west-2
aws eks update-kubeconfig --name eks-backend --region us-west-2
```

### 7. Build Images and Deploy applications
```bash
Terraform ouputs the ECR_URL for both registries

docker build -t $ECR_URL:${{ github.sha }} -t $ECR_URL:latest apps/backend-service/
docker push $ECR_URL:${{ github.sha }}
docker push $ECR_URL:latest

docker build -t $ECR_URL:${{ github.sha }} -t $ECR_URL:latest apps/gateway-proxy/
docker push $ECR_URL:${{ github.sha }}
docker push $ECR_URL:latest

Update the image names in manifest files

aws eks update-kubeconfig --name eks-backend --region us-west-2
kubectl apply -f kubernetes/backend/

ENDPOINT=$(kubectl get svc backend-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
BACKEND_URL=http://${ENDPOINT}:8080

aws eks update-kubeconfig --name eks-gateway --region us-west-2

kubectl create configmap gateway-config \
    --from-literal=backend_url="$BACKEND_URL" \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f kubernetes/gateway/
```

#### 8. Get the public endpoint
```bash
GATEWAY_URL=$(kubectl get svc gateway-proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "$GATEWAY_URL"
```




