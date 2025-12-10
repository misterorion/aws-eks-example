# Input variables for configuring AWS region, VPC networking, EKS cluster, and RDS database.

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "sec-cluster-01"
}

variable "db_name" {
  description = "Name of the RDS database"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "dbadmin"
  sensitive   = true
}

# In a real scenario, never default the password.
# Pass this via CLI: -var="db_password=..." or env vars.
variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}