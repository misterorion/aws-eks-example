module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "sec-vpc"
  cidr = var.vpc_cidr

  azs             = ["${var.region}a", "${var.region}b"]
  public_subnets  = ["10.10.1.0/24", "10.10.2.0/24"]
  private_subnets = ["10.10.11.0/24", "10.10.12.0/24"] # EKS Nodes (NAT access)
  intra_subnets   = ["10.10.21.0/24", "10.10.22.0/24"] # RDS (No Internet)

  # --- IPv6 Configuration ---
  enable_ipv6                                    = true
  public_subnet_assign_ipv6_address_on_creation  = true
  private_subnet_assign_ipv6_address_on_creation = true
  public_subnet_ipv6_prefixes                    = [0, 1]
  private_subnet_ipv6_prefixes                   = [2, 3]
  intra_subnet_ipv6_prefixes                     = [4, 5]

  # Enable egress-only internet gateway for IPv6 (Private subnets)
  create_egress_only_igw = true

  # Security: Enable NAT Gateway for Private subnets (IPv4 egress)
  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}
