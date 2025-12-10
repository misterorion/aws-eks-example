# aws-eks-example

This repository contains Terraform code to provision a secure, production-ready AWS infrastructure featuring an IPv6-native EKS cluster with Bottlerocket nodes and an isolated PostgreSQL RDS database.

## Code Organization

The Terraform configuration is organized into logical, single-purpose files for maintainability and clarity:

- **versions.tf** - Terraform version constraints, provider configuration, and default resource tags
- **variables.tf** - Input variable definitions with sensible defaults and security flags
- **outputs.tf** - Exposed values for cluster access and database connectivity
- **vpc.tf** - VPC networking infrastructure with dual-stack IPv4/IPv6 support
- **security_groups.tf** - Three-tier security group architecture (ALB → Workload → Database)
- **eks.tf** - EKS cluster configuration, managed node groups, addons, and IAM roles
- **rds.tf** - PostgreSQL database instance in isolated subnets
- **secrets.tf** - AWS Secrets Manager secret for auto-generated RDS password

This separation follows Terraform best practices by grouping related resources while keeping files focused and manageable. Each file can be understood independently while the module dependencies create clear resource relationships.

## Architecture & Security Decisions

### 1. Network Segmentation (VPC)
I utilized a **3-tier subnet strategy** to enforce strict network isolation:
* **Public Subnets:** Contain only the NAT Gateway and potential Load Balancers.
* **Private Subnets:** Host the **EKS Worker Nodes**. These nodes have egress access via NAT (for patching/image pulls) but are not directly addressable from the internet.
* **Intra (Isolated) Subnets:** Host the **RDS Database**. These subnets have **no route to the Internet Gateway or NAT Gateway**. This ensures the data layer is air-gapped from the public internet.

### 2. Compute Security (EKS)
* **Private Cluster:** The EKS control plane endpoint has `endpoint_public_access = false`, meaning it's only accessible from within the VPC. This eliminates external attack vectors against the Kubernetes API server.
* **Bottlerocket OS:** Node groups use `BOTTLEROCKET_ARM_64` instead of standard Amazon Linux 2. Bottlerocket is purpose-built for containers with a minimal attack surface, immutable infrastructure, and automatic security updates via image-based deployments.
* **ARM64 Architecture:** Using `t4g.medium` instances provides better price-performance compared to x86, with lower costs and energy efficiency for containerized workloads.
* **IRSA Enabled:** IAM Roles for Service Accounts (`enable_irsa = true`) allows pod-level IAM permissions without sharing node credentials. Each workload can assume its own IAM role following the principle of least privilege.
* **Essential Addons:** The cluster includes critical EKS addons configured to use the latest versions:
  - `coredns` - DNS resolution for service discovery
  - `kube-proxy` - Network proxy for pod-to-pod communication
  - `vpc-cni` - IPv6-aware CNI plugin for pod networking
  - `eks-pod-identity-agent` - Modern pod identity mechanism
  - `aws-ebs-csi-driver` - Persistent volume support with dedicated IAM role for fine-grained EBS permissions
* **Node Security:** Additional security group rules allow node-to-node communication on all ports (required for pod networking) and ephemeral port access from the control plane for kubectl exec/logs.

### 3. Data Security (RDS)
* **Isolation:** The database is deployed in the `intra_subnets` (Isolated layer) which have no route to any Internet Gateway or NAT Gateway.
* **Instance Configuration:** PostgreSQL 14 running on `db.t4g.micro` (ARM Graviton2) for cost efficiency. Storage starts at 20GB with autoscaling up to 50GB.
* **Security Groups:** Access is strictly whitelisted. The RDS Security Group allows ingress on port 5432 **only** from the Workload Security Group ID. This security group chaining approach (not CIDR-based rules) ensures only authorized EKS workloads can connect.
* **Secrets Management:** The database master password is automatically generated using a cryptographically secure random generator (32 characters) and stored in AWS Secrets Manager. This eliminates the need to pass passwords via CLI arguments or environment variables, and provides secure rotation capabilities.
* **Development Settings:** The database has `deletion_protection = false` and `skip_final_snapshot = true` for easy teardown during development. In production, these should be set to `true` and `false` respectively.

### 4. IPv6 Implementation (Dual-Stack)
This infrastructure uses a modern **IPv6-native architecture** to eliminate IP exhaustion issues common in large Kubernetes deployments:
* **VPC:** Configured with `enable_ipv6 = true`, AWS automatically assigns a `/56` IPv6 CIDR block. The VPC module slices this into `/64` subnets for Public, Private, and Intra layers with `ipv6_prefixes` configuration.
* **IPv6 Egress:** An Egress-Only Internet Gateway (`create_egress_only_igw = true`) provides IPv6 internet access for private subnets without allowing inbound connections, complementing the IPv4 NAT Gateway.
* **EKS:** The cluster runs in IPv6 mode (`ip_family = "ipv6"`), assigning each pod a unique, routable IPv6 address. This eliminates the need for overlay networking and secondary CIDR blocks that limit cluster scale.
* **CNI Configuration:** The `create_cni_ipv6_iam_policy = true` flag provisions the correct IAM permissions for the VPC CNI plugin to assign IPv6 addresses to pods.
* **RDS:** Configured with `network_type = "DUAL"`, allowing the database to accept connections from both IPv4 (EKS nodes) and IPv6 (EKS pods) without translation overhead.

### 5. Security Group Chaining
Instead of relying on broad CIDR ranges, I implemented strict **Security Group Chaining** to enforce a Zero Trust network model:
1.  **ALB SG (`alb-sg`):** The *only* security group allowing Ingress from the Internet (Ports 80/443, IPv4 `0.0.0.0/0` and IPv6 `::/0`).
2.  **Workload SG (`workload-sg`):** Applied to EKS Nodes/Pods. It denies all ingress traffic unless it originates specifically from the **ALB SG**.
3.  **Database SG (`rds-sg`):** It denies all ingress traffic unless it originates specifically from the **Workload SG**.

*Result:* Even if an attacker gains access to the VPC network layer, they cannot connect to the Database unless they have compromised a specific compute node.

## Design Rationale

### Why This File Organization?
The Terraform code is deliberately split into single-responsibility files rather than using a monolithic configuration:

1. **Separation of Concerns:** Each file handles one infrastructure domain (networking, compute, data, security), making it easier to review and modify specific components without affecting others.
2. **Team Collaboration:** Different team members can work on networking (vpc.tf) and compute (eks.tf) simultaneously with minimal merge conflicts.
3. **Testing & Validation:** Isolated files make it easier to validate changes with `terraform plan -target=module.vpc` before applying broader changes.
4. **Module Reusability:** The clear separation makes it straightforward to extract any component into a reusable Terraform module.
5. **Standard Convention:** This structure follows HashiCorp's recommended practices and is immediately recognizable to Terraform practitioners.

### Why These Technology Choices?

**Bottlerocket over Amazon Linux 2:**
- Minimal OS footprint reduces attack surface (no package manager, no SSH by default)
- Immutable infrastructure with atomic updates reduces configuration drift
- Purpose-built for containers with optimized boot times and resource usage
- Automatic security patching via image-based updates

**IPv6-Native Networking:**
- Solves the "pods per node" limitation imposed by IPv4 secondary CIDR exhaustion
- Eliminates complex overlay networking and improves performance
- Each pod gets a routable IP, simplifying network troubleshooting and security policies
- Future-proofs the infrastructure as IPv4 addresses become scarce

**Private EKS Endpoint:**
- Eliminates internet-based attack vectors against the Kubernetes API
- Forces all management traffic through the VPC, creating an audit trail
- Requires VPN or bastion host for access, enforcing zero-trust principles
- Prevents accidental exposure of cluster credentials

**Security Group Chaining:**
- More secure than CIDR-based rules as security groups automatically adjust when resources scale
- Prevents the need to update rules when adding/removing nodes or pods
- Creates an explicit dependency graph: Internet → ALB → Workload → Database
- Easier to audit and understand compared to complex CIDR calculations

**ARM64 (Graviton) Instances:**
- 20% better price-performance compared to comparable x86 instances
- Lower power consumption aligns with sustainability goals
- Wide software compatibility through modern container images
- Bottlerocket has first-class ARM support

**AWS Secrets Manager for Passwords:**
- Eliminates password management burden - automatically generated with cryptographic randomness
- No risk of accidentally committing passwords to version control
- Centralized access control via IAM policies
- Enables automatic password rotation without code changes
- Provides audit trail of secret access via CloudTrail
- Applications can retrieve secrets programmatically using IAM roles (no hardcoded credentials)

## Deployment Instructions

### Prerequisites
* Terraform >= 1.2
* AWS CLI configured with appropriate credentials
* AWS account with permissions to create VPC, EKS, RDS, IAM, and Security Group resources

### Steps
1.  **Initialize Terraform:**
    ```bash
    terraform init
    ```

2.  **Plan the deployment:**
    ```bash
    terraform plan -out=tfplan
    ```

3.  **Apply:**
    ```bash
    terraform apply tfplan
    ```

    Note: A secure random password will be automatically generated and stored in AWS Secrets Manager during the apply.

4.  **Grant cluster access to your IAM identity:**

    After the cluster is created, you must add your IAM user or role to the cluster's access configuration with admin permissions. Choose one method:

    **Option A: Using AWS Console**
    - Navigate to EKS → Clusters → sec-cluster-01 → Access
    - Click "Create access entry"
    - Select your IAM principal (user or role)
    - Add the `AmazonEKSAdminPolicy` access policy
    - Click "Create"

    **Option B: Using AWS CLI**
    ```bash
    # For IAM user
    aws eks create-access-entry \
      --cluster-name sec-cluster-01 \
      --principal-arn arn:aws:iam::ACCOUNT_ID:user/YOUR_USERNAME \
      --region us-east-2

    aws eks associate-access-policy \
      --cluster-name sec-cluster-01 \
      --principal-arn arn:aws:iam::ACCOUNT_ID:user/YOUR_USERNAME \
      --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy \
      --access-scope type=cluster \
      --region us-east-2

    # For IAM role (if using assumed role)
    aws eks create-access-entry \
      --cluster-name sec-cluster-01 \
      --principal-arn arn:aws:iam::ACCOUNT_ID:role/YOUR_ROLE_NAME \
      --region us-east-2

    aws eks associate-access-policy \
      --cluster-name sec-cluster-01 \
      --principal-arn arn:aws:iam::ACCOUNT_ID:role/YOUR_ROLE_NAME \
      --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy \
      --access-scope type=cluster \
      --region us-east-2
    ```

5.  **Access the cluster:**
    ```bash
    # Update kubeconfig (note: requires VPC access since endpoint is private)
    aws eks update-kubeconfig --region us-east-2 --name sec-cluster-01

    # Verify access
    kubectl get nodes

    # If accessing from outside the VPC, you'll need:
    # - A VPN connection to the VPC, OR
    # - A bastion host in the VPC, OR
    # - Temporarily enable public endpoint access
    ```

6.  **Retrieve the RDS password:**

    The database password is stored in AWS Secrets Manager. You can retrieve it using:

    ```bash
    # Get the secret name from Terraform outputs
    terraform output rds_secret_name

    # Retrieve the password
    aws secretsmanager get-secret-value \
      --secret-id $(terraform output -raw rds_secret_name) \
      --query SecretString \
      --output text \
      --region us-east-2

    # Or use the pre-formatted command from outputs
    $(terraform output -raw retrieve_rds_password)
    ```

    **Connection Details:**
    - **Endpoint:** `terraform output rds_endpoint`
    - **Database:** `appdb` (or your custom `db_name` variable)
    - **Username:** `dbadmin` (or your custom `db_username` variable)
    - **Password:** Retrieved from Secrets Manager (see above)

### Important Notes
* **IAM Authentication:** EKS uses IAM for cluster authentication. You must explicitly grant your IAM identity access to the cluster (Step 4) before you can run `kubectl` commands. The Terraform apply does not automatically grant access to any IAM principals.
* **Private Endpoint:** The EKS cluster endpoint is private by default. You must be connected to the VPC (via VPN, AWS Direct Connect, or bastion host) to run `kubectl` commands.
* **Database Password:** The RDS password is automatically generated and securely stored in AWS Secrets Manager. You never need to manually create or manage the password. Retrieve it using the AWS CLI as shown in Step 6.
* **Secret Deletion:** When destroying the infrastructure, the Secrets Manager secret has a 7-day recovery window. If you need to recreate the infrastructure immediately, you may need to manually delete the secret or wait for the recovery period to expire.
* **Region:** The default region is `us-east-2`. Change the `region` variable if deploying elsewhere.

### Cleanup
To destroy resources and avoid costs:
```bash
terraform destroy
```

No password required! The secret will be marked for deletion with a 7-day recovery window.