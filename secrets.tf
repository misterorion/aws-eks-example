# AWS Secrets Manager secret for RDS database password with auto-generated secure password.

# Generate a secure random password
resource "random_password" "db_password" {
  length  = 32
  special = true
  # Exclude characters that might cause issues in connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store the password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name_prefix             = "${var.cluster_name}-rds-password-"
  description             = "RDS master password for ${var.db_name} database"
  recovery_window_in_days = 7

  tags = {
    Component = "RDS-Password"
    Database  = var.db_name
    Cluster   = var.cluster_name
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}
