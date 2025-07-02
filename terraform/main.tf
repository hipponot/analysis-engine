terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.37.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  profile = "dev_admin"
}

data "aws_caller_identity" "current" {}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.37.1"
  cluster_name    = var.cluster_name
  cluster_version = "1.33"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Cluster endpoint access configuration
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]  # Restrict this to your IP for better security

  # Enable cluster access entry API - this should give the cluster creator admin access
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    general = {
      min_size       = 1
      max_size       = 10
      desired_size   = 1
      instance_types = ["t3.medium", "t3.large"]
      capacity_type  = "SPOT"
      
      labels = {
        "worker_type" = "general"
        "node.kubernetes.io/instance-type" = "general"
      }

      # Enable spot instance handling
      update_config = {
        max_unavailable_percentage = 50
      }
      
      # Add EBS CSI driver policy for persistent volumes
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }

    gpu = {
      min_size       = 0  # Start at zero capacity for cost optimization
      max_size       = 5
      desired_size   = 0  # Initially no GPU nodes
      instance_types = ["g4dn.xlarge", "g4dn.2xlarge"]
      capacity_type  = "SPOT"
      ami_type       = "AL2023_x86_64_NVIDIA"  # Updated for Kubernetes 1.33 compatibility

      labels = {
        "worker_type" = "gpu"
        "node.kubernetes.io/instance-type" = "gpu"
        "gpu.amazonaws.com/class" = "nvidia"
      }

      # Taint GPU nodes so only GPU workloads can be scheduled
      taints = [
        {
          key    = "nvidia.com/gpu"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]

      # Faster updates for GPU nodes
      update_config = {
        max_unavailable_percentage = 25
      }

      # GPU-specific configuration
      bootstrap_extra_args = "--container-runtime containerd --use-max-pods false"
      
      # Add EBS CSI driver policy for persistent volumes
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }
}

