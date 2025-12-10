# 1. Load Balancer Security Group
# Public facing: Allows HTTP/HTTPS from everywhere (IPv4 + IPv6)
module "alb_sg" {
  source  = "terraform-aws-modules/security-group/aws"

  name        = "alb-sg"
  description = "Public Load Balancer Security Group"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP from Internet"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "HTTPS from Internet"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  ingress_with_ipv6_cidr_blocks = [
    {
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      description      = "HTTP from Internet (IPv6)"
      ipv6_cidr_blocks = "::/0"
    },
    {
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      description      = "HTTPS from Internet (IPv6)"
      ipv6_cidr_blocks = "::/0"
    }
  ]

  # Egress to the Workload SG is required
  egress_rules = ["all-all"]
}

# 2. Workload (Compute) Security Group
# Private: Accepts traffic ONLY from the ALB Security Group
module "workload_sg" {
  source  = "terraform-aws-modules/security-group/aws"

  name        = "workload-sg"
  description = "Security Group for EKS Workload Pods/Nodes"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 8080 # Assuming app runs on 8080
      to_port                  = 8080
      protocol                 = "tcp"
      description              = "Traffic from ALB"
      source_security_group_id = module.alb_sg.security_group_id
    }
  ]

  # Standard egress
  egress_rules            = ["all-all"]
  egress_ipv6_cidr_blocks = ["::/0"]
}

# 3. Database Security Group
# Isolated: Accepts traffic ONLY from the Workload SG
module "db_sg" {
  source  = "terraform-aws-modules/security-group/aws"

  name        = "rds-sg"
  description = "Security Group for RDS Database"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 5432
      to_port                  = 5432
      protocol                 = "tcp"
      description              = "PostgreSQL access from Workload"
      source_security_group_id = module.workload_sg.security_group_id
    }
  ]

  # No egress needed for RDS typically, but standard allow for internal logic
  egress_rules            = ["all-all"]
  egress_ipv6_cidr_blocks = ["::/0"]
}