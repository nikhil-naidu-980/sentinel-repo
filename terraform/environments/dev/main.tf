terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # default_tags {
  #   tags = {
  #     Project     = var.project_name
  #     Environment = var.environment
  #     ManagedBy   = "terraform"
  #   }
  # }
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Import only node roles that persist across destroy cycles
# Cluster roles get deleted, so they need to be recreated each time
import {
  to = module.eks_backend.aws_iam_role.eks_node_role
  id = "eks-backend-eks-node-role"
}

import {
  to = module.eks_gateway.aws_iam_role.eks_node_role
  id = "eks-gateway-eks-node-role"
}

# VPC - Gateway
module "vpc_gateway" {
  source             = "../../modules/vpc"
  vpc_name           = "vpc-gateway"
  vpc_cidr           = var.gateway_vpc_cidr
  enable_nat_gateway = true
  enable_flow_logs   = var.enable_flow_logs
  tags               = local.common_tags
}

# VPC - Backend
module "vpc_backend" {
  source             = "../../modules/vpc"
  vpc_name           = "vpc-backend"
  vpc_cidr           = var.backend_vpc_cidr
  enable_nat_gateway = true
  enable_flow_logs   = var.enable_flow_logs
  tags               = local.common_tags
}

# VPC Peering
resource "aws_vpc_peering_connection" "gateway_to_backend" {
  vpc_id      = module.vpc_gateway.vpc_id
  peer_vpc_id = module.vpc_backend.vpc_id
  auto_accept = true

  accepter {
    allow_remote_vpc_dns_resolution = true
  }
  requester {
    allow_remote_vpc_dns_resolution = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-gateway-to-backend-${var.environment}"
  })
}

resource "aws_route" "gateway_to_backend" {
  route_table_id            = module.vpc_gateway.private_route_table_id
  destination_cidr_block    = var.backend_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.gateway_to_backend.id
}

resource "aws_route" "backend_to_gateway" {
  route_table_id            = module.vpc_backend.private_route_table_id
  destination_cidr_block    = var.gateway_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.gateway_to_backend.id
}

# EKS - Gateway
module "eks_gateway" {
  source                 = "../../modules/eks"
  cluster_name           = "eks-gateway"
  iam_role_prefix        = "eks-gateway"
  kubernetes_version     = var.kubernetes_version
  vpc_id                 = module.vpc_gateway.vpc_id
  subnet_ids             = module.vpc_gateway.private_subnet_ids
  endpoint_public_access = true
  node_instance_types    = var.node_instance_types
  capacity_type          = var.capacity_type
  node_desired_size      = var.gateway_node_desired_size
  node_min_size          = var.gateway_node_min_size
  node_max_size          = var.gateway_node_max_size
  node_labels_role       = "gateway"
  peer_vpc_cidr          = var.backend_vpc_cidr
  tags                   = local.common_tags
}

# EKS - Backend
module "eks_backend" {
  source                 = "../../modules/eks"
  cluster_name           = "eks-backend"
  iam_role_prefix        = "eks-backend"
  kubernetes_version     = var.kubernetes_version
  vpc_id                 = module.vpc_backend.vpc_id
  subnet_ids             = module.vpc_backend.private_subnet_ids
  endpoint_public_access = true
  node_instance_types    = var.node_instance_types
  capacity_type          = var.capacity_type
  node_desired_size      = var.backend_node_desired_size
  node_min_size          = var.backend_node_min_size
  node_max_size          = var.backend_node_max_size
  node_labels_role       = "backend"
  peer_vpc_cidr          = var.gateway_vpc_cidr
  tags                   = local.common_tags
}

# ECR
module "ecr" {
  source           = "../../modules/ecr"
  name_prefix      = "${var.project_name}-${var.environment}"
  repository_names = ["backend", "gateway"]
  scan_on_push     = true
  tags             = local.common_tags
}
