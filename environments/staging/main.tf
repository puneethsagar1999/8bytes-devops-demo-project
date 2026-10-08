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