module "eks" {
  source = "terraform-aws-modules/eks/aws"

  name               = var.cluster_name
  kubernetes_version = "1.34"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  ip_family                  = "ipv6"
  create_cni_ipv6_iam_policy = true

  endpoint_public_access = false
  enable_irsa            = true

  addons = {
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

      vpc_security_group_ids = [module.workload_sg.security_group_id]

      user_data = base64encode(<<-EOT
      [settings.kubernetes]
      max-pods = 58

      [settings.kernel]
      lockdown = "integrity"
    EOT
      )
    }
  }

  # Cluster security group rules
  security_group_additional_rules = {
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
