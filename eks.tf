module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.34"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # IPv6 Config
  cluster_ip_family          = "ipv6"
  create_cni_ipv6_iam_policy = true

  cluster_endpoint_public_access = true
  enable_irsa                    = true

  # Cluster addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    bottlerocket_arm64 = {
      name           = "bottlerocket-arm64-ng"
      ami_type       = "BOTTLEROCKET_ARM_64"
      platform       = "bottlerocket"
      instance_types = ["t4g.medium"]

      min_size     = 2
      max_size     = 3
      desired_size = 2

      disk_size = 20

      iam_role_attach_cni_policy = true

      labels = {
        role        = "general"
        environment = "demo"
        arch        = "arm64"
        nodegroup   = "bottlerocket-arm64"
      }

      # --- Security Integration ---
      # Attach the custom Workload SG to these nodes
      vpc_security_group_ids = [module.workload_sg.security_group_id]

    }

    bootstrap_extra_args = <<-EOT
        [settings.kubernetes]
        max-pods = 58

        [settings.kernel]
        lockdown = "integrity"
      EOT
  }

  # Cluster security group rules
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  # Node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
  }
}
