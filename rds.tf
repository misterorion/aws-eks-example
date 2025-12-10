# PostgreSQL RDS database instance in isolated subnets with automated backups disabled.

module "db" {
  source = "terraform-aws-modules/rds/aws"

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
  password = random_password.db_password.result
  port     = 5432

  network_type = "DUAL"

  subnet_ids = module.vpc.intra_subnets

  vpc_security_group_ids = [module.db_sg.security_group_id]

  create_db_subnet_group = true
  deletion_protection    = false
  skip_final_snapshot    = true
}