locals {
  tags = merge(var.tags, {
    Terraform = "true"
    Project   = var.cluster_name
  })
}

# ──────────────────────────────────────────────
# VPC
# ──────────────────────────────────────────────

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.6"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs = var.azs

  # Private: /20 blocks (4,096 IPs each) — large for workload nodes
  # Public:  /24 blocks (256 IPs each), offset to k+48 to avoid overlap with private /20 ranges
  private_subnets = [for k, v in var.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in var.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery"          = var.cluster_name
  }

  tags = local.tags
}

# ──────────────────────────────────────────────
# EKS + Karpenter
# ──────────────────────────────────────────────

module "eks_karpenter" {
  source = "./modules/eks-karpenter"

  cluster_name                   = var.cluster_name
  cluster_version                = var.cluster_version
  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  karpenter_version              = var.karpenter_version
  karpenter_resources_chart_path = "${path.module}/karpenter-resources"

  tags = local.tags
}
