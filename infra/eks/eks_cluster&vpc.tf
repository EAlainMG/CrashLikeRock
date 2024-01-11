provider "aws" {
  region = local.region
}

locals {
  name   = "my-cluster"
  region = "eu-west-2"

  vpc_cidr = "10.123.0.0/16"
  azs      = ["eu-west-2a", "eu-west-2b"]

  public_subnets  = ["10.123.1.0/24", "10.123.2.0/24"]
  private_subnets = ["10.123.3.0/24", "10.123.4.0/24"]
  intra_subnets   = ["10.123.5.0/24", "10.123.6.0/24"]

  cluster_name = module.eks.cluster_name

  tags = {
    Example = local.name
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets
  intra_subnets   = local.intra_subnets

  enable_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.20.0"

  cluster_name                   = local.name
  cluster_endpoint_public_access = true

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

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  cluster_security_group_additional_rules = {
    ingress_frontend_http = {
      description   = "HTTP for frontend"
      protocol      = "tcp"
      from_port     = 80
      to_port       = 80
      type          = "ingress"
      cidr_blocks   = ["0.0.0.0/0"]
    },
    ingress_backend_custom_port = {
      description   = "Backend service"
      protocol      = "tcp"
      from_port     = 3000
      to_port       = 3000
      type          = "ingress"
      cidr_blocks   = local.private_subnets
    }
  }
  
  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["m5.large"]
    attach_cluster_primary_security_group = false
    tags = {
      ExtraTag = "helloMe"
    }
  }

  eks_managed_node_groups = {
    my-cluster-wg = {
      min_size     = 1
      max_size     = 2
      desired_size = 2
      instance_types = ["t3.small"]
      capacity_type  = "SPOT"
    }
  }

  tags = local.tags
}

output "region" {
  value = local.region
}

output "host" {
  value = module.eks.cluster_endpoint
}

output "ca_cert" {
  value = base64decode(module.eks.cluster_certificate_authority_data)
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "oidc_url" {
  value = module.eks.cluster_oidc_issuer_url
}

output "oidc_id" {
  value = element(split("/", module.eks.cluster_oidc_issuer_url), length(split("/", module.eks.cluster_oidc_issuer_url)) - 1)
}

# Configure the Kubernetes provider
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Configure the Helm provider
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# Kubernetes Namespace for Argo CD
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# Kubernetes Namespace for NGINX Ingress
resource "kubernetes_namespace" "nginx_ingress" {
  metadata {
    name = "nginx-ingress"
  }
}

# Helm Release for Argo CD
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }
}

# Helm Release for NGINX Ingress
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "nginx-ingress"
  version    = "1.0.4"
  # Additional configuration parameters
}

# EKS Cluster Authentication Data Source
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}
