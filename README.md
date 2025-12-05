# sentinel-repo
Flagship threat intelligence platform

## Deployment Steps Using Github Actions

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

#### 4. Update the s3 bucket name in ./terraform/environments/backend.tf
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

#### 4. Update the s3 bucket name in ./terraform/environments/backend.tf
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

#### 5. Initialize Terraform, plan and apply
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

#### 7. Build Images and Deploy applications
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


## Architecture

### VPC Design

  **VPC Gateway (10.0.0.0/16)**
  - Hosts the public-facing gateway proxy
  - EKS cluster with internet-facing Network Load Balancer
  - 2 private subnets and 2 public subnets across 2 Availability Zones (us-west-2a, us-west-2b)
  - NAT Gateway in public subnet for outbound internet access

  **VPC Backend (10.1.0.0/16)**
  - Hosts internal backend services
  - EKS cluster with internal-only Network Load Balancer
  - 2 private subnets and 2 public subnets across 2 Availability Zones
  - NAT Gateway for AWS service communication and updates

  Each VPC contains 4 subnets total. Public subnets host NAT Gateways and Load Balancers, while private subnets host EKS worker nodes and application pods. The use of 2 Availability Zones provides high availability (HA).

## Networking and Connectivity

  ### VPC Peering

  The VPCs are connected via AWS VPC Peering, which provides:
  - Private, low-latency communication 
  - No internet traversal required
  - DNS resolution enabled for cross-VPC service discovery
  - Zero data transfer costs within the same region

  ### Route Tables

  Each VPC has separate route tables for public and private subnets:

  **Gateway VPC Private Route Table:**
  10.0.0.0/16    -> local (within VPC)
  10.1.0.0/16    -> peering to Backend VPC
  0.0.0.0/0      -> internet via NAT Gateway

  **Backend VPC Private Route Table:**
  10.1.0.0/16    -> local within VPC
  10.0.0.0/16    -> peering to Gateway VPC
  0.0.0.0/0      -> internet via NAT Gateway

  ### How the Gateway Talks to Backend

  The communication flow works as follows:

  1. User makes request to Gateway's public Load Balancer
  2. Load Balancer forwards to Gateway pod in private subnet
  3. Gateway pod reads Backend URL from Kubernetes ConfigMap
  4. Gateway makes HTTP request to Backend's internal Load Balancer DNS name
  5. VPC peering DNS resolution translates hostname to Backend VPC private IP (10.1.x.x)
  6. Gateway's route table directs traffic with destination 10.1.0.0/16 through peering connection
  7. Traffic flows through peering connection 
  8. Backend's internal Load Balancer receives request and forwards to Backend pod
  9. Response flows back through the same path in reverse

  ### Security Groups

  Security Groups provide defense in depth at the resource level:

  - **Backend Node Security Group**: Allows ingress from Gateway VPC CIDR (10.0.0.0/16) on all ports, allowing Gateway pods to reach Backend services
  - **Gateway Node Security Group**: Allows egress to Backend VPC CIDR (10.1.0.0/16)
  - **Cluster Security Groups**: Allow communication between EKS control plane and worker nodes

  ### Network Policy (Optional)

  Kubernetes NetworkPolicy provides an additional security layer at the pod level. The Backend cluster can optionally use Calico to enforce policies
  that:

  - Allow ingress only from pods in the same namespace
  - Allow egress to DNS (kube-dns) and HTTPS endpoints
  - Block cross-namespace communication within the Backend cluster
  - calico can be installed from ./scripts/calico.sh and networkpolicy.yaml is configured via k8s manifest

  ## Terraform Architecture

  ### Module Structure

    .
    ├── environments
    │   └── dev
    │       ├── backend.tf          - S3 remote state configuration
    │       ├── main.tf             - Composes modules, creates peering
    │       ├── outputs.tf
    │       └── variables.tf        - Environment-specific values
    └── modules
        ├── ecr                     - Container registries
        │   ├── main.tf
        │   ├── outputs.tf
        │   └── variables.tf
        ├── eks                     - EKS cluster, node groups, IAM roles
        │   ├── main.tf
        │   ├── outputs.tf
        │   └── variables.tf
        └── vpc                     - Reusable VPC with subnets, NAT, routing
            ├── main.tf
            ├── outputs.tf
            └── variables.tf

  **Module Benefits and State Management:**
  - Modules can be reused in for multiple resources across environments
  - Consistent configuration patterns
  - Can be tested or applied in an isolated environment
  - Steate is managed in an s3 bucket: sentinel-tfstate-dev-{account-id}
  - Easier for CI/CD and feasible for collaberation between engineers or teams
  - Version control and rollback capability for s3

  ## CI/CD Pipeline

  ### Workflow Structure

  The GitHub Actions pipeline is organized into stages:

  1. **Change Detection** - Determines what changed - Terraform or Kubernetes?
  2. **Terraform Validation** - Runs terraform fmt and tflint
  3. **Infrastructure Deployment** - Deploys in order: ECR → VPC → VPC Peering → EKS
  4. **Kubernetes Validation** - Runs kubeval and kubectl dry-run
  5. **Container Build** - Builds and pushes images to ECR with git SHA tags
  6. **Application Deployment** - Deploys Backend first, then Gateway with Backend URL and outputs endpoints

  ### Authentication

  Currently uses AWS access keys stored in GitHub Secrets:
  - AWS_ACCESS_KEY_ID
  - AWS_SECRET_ACCESS_KEY

  ### Destroy Workflow

  The destroy-all workflow handles cleanup in the correct order:

  1. Delete Kubernetes services (releases Load Balancers)
  2. Wait for AWS to clean up ENIs
  3. Force delete any remaining Load Balancers
  4. Delete orphaned ENIs
  5. Clean up Security Group cross-references
  6. Delete CloudWatch Log Groups
  7. Remove IAM roles from Terraform state
  8. Run terraform destroy

#  Trade-offs and Design Decisions
 
  **VPC Peering vs Transit Gateway:**
  - Chose VPC Peering for simplicity and cost
  - Transit Gateway would be better for 3+ VPCs but adds cost and complexity
  - Current design sufficient for two-VPC architecture

  **Load Balancer Type: NLB vs ALB:**
  - Network Load Balancer chosen for lower cost
  - Layer 4 load balancing sufficient for simple HTTP proxying
  - ALB features (path routing, WAF) not needed for this use case

  **Monitoring: CloudWatch Logs Only:**
  - Full observability stack (Prometheus/Grafana) not implemented
  - CloudWatch sufficient for debugging and basic monitoring

  **Permissions and roles:**
  - I have a working config running with Github OIDC instead of storing long lived secrets in GH actions
  - But that would need me to create a new role in IAM and create ARN

 ## Cost Optimization
  - Can use spot nodes to reduce the compute cost
  - Single NAT is used to save costs instead of using 2
  - VPC peering pretty much have no cost compared to Transit gateway
  - Can use small nodes instead of t3.medium

# Future Enhancement

 - **TLS:** All communication should be encrypted with TLS on production, might need issuer controllers
 - **Observability:** For better logging and debugging. This will enable us to get better monitoring and alerting. Can use Grafana and Prometheus for example
 - **GitOps:** GitOps style deployment funcationlity using ArgoCD. It will also enable self healing and auto sync on all git commits. This will also enable easy rollbacks.
 - **Transit Gateway:** If we are scaling beyond 2/3 VPC, it's better to migrate to Transit Gateway for hub and spoke topology.
 - **Disaster Recovery:** We can have primary infra in us-west-2 and a DR infra in another region with Routes3 health checks with automatic failover
 - **Secret Management:** Sync secrets from AWS secret manager or Vault, to store sensitive data or credentials 
 - **Second Container Registry:** If we enable secrete handling correctly, we can also push the images to a second container registry. In case of an incident, it would be helpful.








