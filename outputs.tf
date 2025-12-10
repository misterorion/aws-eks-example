# Output values for EKS cluster details and RDS database endpoint.

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = module.eks.node_security_group_id
}

output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks update-kubeconfig --region us-east-2 --name ${module.eks.cluster_name}"
}

output "rds_endpoint" {
  description = "RDS Connection Endpoint"
  value       = module.db.db_instance_endpoint
}

output "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the RDS password"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "rds_secret_name" {
  description = "Name of the Secrets Manager secret containing the RDS password"
  value       = aws_secretsmanager_secret.db_password.name
}

output "retrieve_rds_password" {
  description = "Command to retrieve the RDS password from Secrets Manager"
  value       = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.db_password.name} --query SecretString --output text --region ${var.region}"
}