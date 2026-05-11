module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.20"

  name               = var.cluster_name
  kubernetes_version  = var.cluster_version

  endpoint_public_access  = true
  endpoint_private_access = true

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  enable_cluster_creator_admin_permissions = true

  addons = {
    coredns                = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni                = { most_recent = true }
  }

  eks_managed_node_groups = {
    system = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["m7i.large"]

      min_size     = 2
      max_size     = 3
      desired_size = 2

      labels = {
        "node-role" = "system"
      }
    }
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  tags = var.tags
}
