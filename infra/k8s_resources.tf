provider "aws" {
  region = "eu-west-2"  // Replace with your AWS region
}

provider "kubernetes" {
  host                   = local.host  // Replace with output from Stage 1
  cluster_ca_certificate = local.ca_cert  // Replace with output from Stage 1
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = local.host  // Replace with output from Stage 1
    cluster_ca_certificate = local.ca_cert  // Replace with output from Stage 1
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

locals {
region = "eu-west-2"
ca_cert = <<EOT
-----BEGIN CERTIFICATE-----
MIIDBTCCAe2gAwIBAgIIFf/OqNyXCqswDQYJKoZIhvcNAQELBQAwFTETMBEGA1UE
AxMKa3ViZXJuZXRlczAeFw0yMzEyMTgwNzUzMjVaFw0zMzEyMTUwNzU4MjVaMBUx
EzARBgNVBAMTCmt1YmVybmV0ZXMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
AoIBAQC3wb261enaL1YAhILcquioh9iJ3QRPX8k2lA9XjIH7KzGfRWDLvZzTajjU
YbBmGoLVcRmuOx4Jf5XQoCgQlbdzObNT21dFe3TVSm0yd9yImSgnpPgcOYvpG+0M
O187PRoLDS4iImsq+xCsjwGuTFgEdBRn3OqdkKuQlY2Zpi08IROezMYIV8k3RuGA
QYw3fUMcEYfwoSePc21mtd5WAB06grroMxyJoaIzHBmm+0btcmjXdu/6s1zdbyjm
eKS1Stun2cbJYciEjeRWDSQHJo7NafrGoA2HIJ71D7ji2yfaDz994+euc8CF/teW
RMN94rqR9GOI/PkzMbhX4xGBkfI3AgMBAAGjWTBXMA4GA1UdDwEB/wQEAwICpDAP
BgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBReVTUFbw1cibvTcdHtWemDo1ntOzAV
BgNVHREEDjAMggprdWJlcm5ldGVzMA0GCSqGSIb3DQEBCwUAA4IBAQCpfG2rmryP
7kf4Sh8o6pFJhegNq5sY/q0nxJ8IQF6i9aOw2K3OuBxJ3uUGRyZOFPDdoJqhVKe3
lec7S9tWzQTv0SmBgfEmPsOOpsN3ksAXAxs4mboqjEFttxqfYyd/jQQwgXyI5tSj
wNgHE5TIVbAy/OLQuKzxiMzdzkasItBUdAzeaSGpUm3tXN43vqDzkTUfxTYNxNwb
saRA0k3eQiILvbNBMH+7MbPAxDxCOBYM8dVIVSnm66IY/zvS8kVldCfNIMAqxKUW
FfpSn+EnDxCGNltiKfjBS5O/g6YNV0N8NqICszvdULYDiseoPWASt/z00hcgp/k3
fsLE3FmxpjG6
-----END CERTIFICATE-----

EOT
cluster_name = "my-cluster"
host = "https://EEA0A58A91E07045261A46A5EE4E071D.gr7.eu-west-2.eks.amazonaws.com"
oidc_id = "EEA0A58A91E07045261A46A5EE4E071D"
oidc_url = "https://oidc.eks.eu-west-2.amazonaws.com/id/EEA0A58A91E07045261A46A5EE4E071D"
}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "cluster" {
  name = local.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = local.cluster_name
}

resource "kubernetes_namespace" "argocd" {

  metadata {
    name = "argocd"
  }
}

resource "aws_iam_policy" "aws_lb_controller_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller in EKS"
  policy      = file("iam_policy.json")
}

resource "aws_iam_policy" "argocd_policy" {
  name        = "eks-argocd-policy"
  description = "IAM policy for Argo CD in EKS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:CreateNodegroup",
          "eks:DeleteNodegroup",
          "eks:UpdateNodegroupConfig"
          // More EKS actions as needed
        ],
        Resource = "*"  // Adjust as needed for specific resources
      },
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
          // More CloudWatch actions as needed
        ],
        Resource = "*"  // Adjust as needed for specific resources
      },
      // Add more statements for other AWS services as needed
    ]
  })
}

resource "aws_iam_role" "aws_lb_controller_role" {
  name = "eks-aws-lb-controller-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity",
        Effect = "Allow",
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/oidc.eks.${local.region}.amazonaws.com/id/${local.oidc_id}" 
        },
        Condition = {
          StringEquals = {
            "oidc.eks.${local.region}.amazonaws.com/id/${local.oidc_id}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",  
            "oidc.eks.${local.region}.amazonaws.com/id/${local.oidc_id}:aud": "sts.amazonaws.com"           }
        }
      },
    ]
  })
}

resource "aws_iam_role" "argocd_role" {
  name = "eks-argocd-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity",
        Effect = "Allow",
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_url}"
        },
        Condition = {
          StringEquals = {
            "${local.oidc_url}:sub": "system:serviceaccount:argocd:argocd"
          }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "argocd_policy_attach" {
  policy_arn = aws_iam_policy.argocd_policy.arn
  role       = aws_iam_role.argocd_role.name
}

resource "aws_iam_role_policy_attachment" "aws_lb_controller_attach" {
  policy_arn = aws_iam_policy.aws_lb_controller_policy.arn
  role       = aws_iam_role.aws_lb_controller_role.name
}

resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  
  set {
    name  = "clusterName"
    value = local.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_lb_controller_role.arn
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"

  set {
    name  = "controller.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "argocd"
  }

  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.argocd_role.arn
  }

  set {
    name  = "server.ingress.enabled"
    value = "true"
  }

  set {
    name  = "server.ingress.annotations.kubernetes\\.io/ingress\\.class"
    value = "alb"
  }

  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }

  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }
}

resource "kubernetes_cluster_role" "argocd_cluster_role" {
  metadata {
    name = "argocd-cluster-role"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "endpoints", "persistentvolumeclaims", "events", "configmaps", "secrets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "daemonsets", "replicasets", "statefulsets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["cronjobs", "jobs"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "argocd_cluster_role_binding" {
  metadata {
    name = "argocd-cluster-role-binding"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "argocd" // Name of the ServiceAccount
    namespace = "argocd" // Namespace of the ServiceAccount
  }

  role_ref {
    kind     = "ClusterRole"
    name     = kubernetes_cluster_role.argocd_cluster_role.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
}

