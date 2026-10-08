module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  enable_irsa = true

  cluster_name    = "${var.project}-${var.environment}-eks"
  cluster_version = "1.32"

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    workers = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = var.node_count + 1
      desired_size   = var.node_count
    }
  }

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
