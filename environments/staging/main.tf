locals {
  name = "${var.project}-${var.environment}"
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source      = "../../modules/vpc"
  project     = var.project
  environment = var.environment
  vpc_cidr    = var.vpc_cidr
}

module "ecr" {
  source    = "../../modules/ecr"
  repo_name = "${local.name}-app"
  tags      = local.tags
}

module "eks" {
  source      = "../../modules/eks"
  project     = var.project
  environment = var.environment
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnets
  node_count  = var.node_count
}

module "rds" {
  source                    = "../../modules/rds"
  project                   = var.project
  environment               = var.environment
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.private_subnets
  allowed_security_group_id = module.eks.node_security_group_id
  instance_class            = var.db_instance_class
  tags                      = local.tags
}

module "jenkins" {
  source       = "../../modules/jenkins"
  project      = var.project
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  subnet_id    = module.vpc.public_subnets[0]
  allowed_ip   = var.allowed_ip
  cluster_name = module.eks.cluster_name
  tags         = local.tags
}

resource "aws_eks_access_entry" "jenkins" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.jenkins.role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "jenkins" {
  cluster_name  = aws_eks_access_entry.jenkins.cluster_name
  principal_arn = aws_eks_access_entry.jenkins.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_to_eks_api" {
  security_group_id            = module.eks.cluster_security_group_id
  referenced_security_group_id = module.jenkins.security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Jenkins to EKS API"
}