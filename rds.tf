module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "sec-assignment-db"

  engine               = "postgres"
  engine_version       = "14"
  family               = "postgres14"
  major_engine_version = "14"
  instance_class       = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 50

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  # IPv6
  network_type = "DUAL"

  subnet_ids = module.vpc.intra_subnets

  # --- Security Integration ---
  # Use the explicit DB SG created in security_groups.tf
  vpc_security_group_ids = [module.db_sg.security_group_id]

  create_db_subnet_group = true
  deletion_protection    = false
  skip_final_snapshot    = true
}