output "gateway_vpc_id" {
  value = module.vpc_gateway.vpc_id
}

output "backend_vpc_id" {
  value = module.vpc_backend.vpc_id
}

output "vpc_peering_connection_id" {
  value = aws_vpc_peering_connection.gateway_to_backend.id
}

output "gateway_cluster_name" {
  value = module.eks_gateway.cluster_name
}

output "gateway_cluster_endpoint" {
  value = module.eks_gateway.cluster_endpoint
}

output "backend_cluster_name" {
  value = module.eks_backend.cluster_name
}

output "backend_cluster_endpoint" {
  value = module.eks_backend.cluster_endpoint
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "configure_kubectl_gateway" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks_gateway.cluster_name}"
}

output "configure_kubectl_backend" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks_backend.cluster_name}"
}
