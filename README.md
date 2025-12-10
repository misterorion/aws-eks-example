# aws-eks-example

This repository contains Terraform code to provision a secure, 3-tier AWS architecture containing an EKS cluster and an RDS database.

## Architecture & Security Decisions

### 1. Network Segmentation (VPC)
I utilized a **3-tier subnet strategy** to enforce strict network isolation:
* **Public Subnets:** Contain only the NAT Gateway and potential Load Balancers.
* **Private Subnets:** Host the **EKS Worker Nodes**. These nodes have egress access via NAT (for patching/image pulls) but are not directly addressable from the internet.
* **Intra (Isolated) Subnets:** Host the **RDS Database**. These subnets have **no route to the Internet Gateway or NAT Gateway**. This ensures the data layer is air-gapped from the public internet.

### 2. Compute Security (EKS)
* **Least Privilege:** I utilized the `terraform-aws-modules/eks` module which implements IRSA (IAM Roles for Service Accounts). This allows future workloads to assume fine-grained IAM roles rather than using the Node IAM role.
* **Encryption:** The EBS volumes for the worker nodes are encrypted by default (`encrypted = true`) to protect data at rest.
* **Access:** The EKS Cluster Endpoint is public for the sake of this assignment's accessibility, but in a production environment, I would restrict `cluster_endpoint_public_access_cidrs` to the corporate VPN IP range.
* **Architecture:** Used `t4g.medium` (ARM64) as requested. I configured the `ami_type` to `AL2_ARM_64` to ensure compatibility.

### 3. Data Security (RDS)
* **Isolation:** The database is deployed in the `intra_subnets` (Isolated layer).
* **Security Groups:** Access is strictly whitelisted. The RDS Security Group allows ingress on port 5432 **only** from the EKS Node Security Group ID. No IP-based rules are used, preventing brittle allow-lists.

### 4. IPv6 Implementation (Dual-Stack)
To align with modern container networking best practices, I upgraded the cluster to use **IPv6**:
* **VPC:** configured with a Dual-Stack architecture. AWS assigns a `/56` CIDR block, and we slice `/64` subnets for Public, Private, and Isolated layers.
* **EKS:** `cluster_ip_family` is set to `ipv6`. This solves the common Kubernetes IP exhaustion problem by assigning a unique, routable IPv6 address to every Pod, removing the need for internal NAT overhead within the cluster.
* **RDS:** Configured as `DUAL` stack, allowing it to communicate with the IPv6-native EKS pods without translation layers.

### 5. Security Group Chaining
Instead of relying on broad CIDR ranges, I implemented strict **Security Group Chaining** to enforce a Zero Trust network model:
1.  **ALB SG (`alb-sg`):** The *only* security group allowing Ingress from the Internet (Ports 80/443, IPv4 `0.0.0.0/0` and IPv6 `::/0`).
2.  **Workload SG (`workload-sg`):** Applied to EKS Nodes/Pods. It denies all ingress traffic unless it originates specifically from the **ALB SG**.
3.  **Database SG (`rds-sg`):** It denies all ingress traffic unless it originates specifically from the **Workload SG**.

*Result:* Even if an attacker gains access to the VPC network layer, they cannot connect to the Database unless they have compromised a specific compute node.
## Deployment Instructions

### Prerequisites
* Terraform >= 1.0
* AWS CLI configured

### Steps
1.  **Initialize Terraform:**
    ```bash
    terraform init
    ```
2.  **Plan the deployment:**
    ```bash
    # Pass the DB password securely via CLI or environment variable
    terraform plan -var="db_password=YourSecurePassword123!" -out=tfplan
    ```
3.  **Apply:**
    ```bash
    terraform apply tfplan
    ```

### Cleanup
To destroy resources and avoid costs:
```bash
terraform destroy -var="db_password=YourSecurePassword123!"