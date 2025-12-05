output "cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "cluster_certificate_authority_data" {
  value     = aws_eks_cluster.eks_cluster.certificate_authority[0].data
  sensitive = true
}

output "cluster_security_group_id" {
  value = aws_security_group.eks_cluster_sg.id
}

output "node_security_group_id" {
  value = aws_security_group.eks_node_sg.id
}

output "cluster_oidc_issuer_url" {
  value = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

output "cluster_oidc_provider_arn" {
  value = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}"
}

output "node_role_arn" {
  value = aws_iam_role.eks_node_role.arn
}

output "cluster_role_arn" {
  value = aws_iam_role.eks_cluster_role.arn
}
