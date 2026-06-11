data "terraform_remote_state" "Controlplane_details" {
    backend = "s3"
    config = {
        bucket = "eksprojbackendvenkaiah"
        key = "statefile/eks/controlplane.tfstate"
        region = "ap-south-1"   
    }
}

data "terraform_remote_state" "vpc_details" {
    backend = "s3"
    config = {
        bucket = "eksprojbackendvenkaiah"
        key = "statefile/eks/vpc.tfstate"
        region = "ap-south-1"   
    }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "eks_lbc_policy" {
    name = "${var.cluster_name}-lbc-policy"
    description = "IAM policy for AWS Load Balancer Controller"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
        sid = ""
        Effect = "Allow"
        Action = ["iam:CreateServiceLinkedRole"]
        Resource = "*"
        Condition = {
            StringEquals = {
                "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
            }
        }
      },

      {
        sid = ""
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags"
        ]
        resource = "*"
        },


        {
        sid = ""
        Effect = "Allow"
        Action = [
          "acm:ListCertificates",
          "acm:DescribeCertificate"
        ]
        Resource = "*"
        },

        {
        sid = ""
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:CreateSecurityGroup"
        ]
        resource = "*"
        },

        {
        Effect   = "Allow"
        Action   = ["ec2:CreateTags"]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = "CreateSecurityGroup"
          }
          Null = {
            "aws:RequestedRegion" = "false"
           }
         }
        },

        {
            Effect = "Allow",
            Action = [
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateTargetGroup"
            ]
            Resource = "*"
            Condition = {
                Null = {
                    "aws:RequestedRegion" = "false"
            }
          }
        },

        {
            Effect = "Allow",
            Action = [
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:CreateRule",
                "elasticloadbalancing:DeleteRule"
            ],
            Resource = "*"
        },

        {
            Effect = "Allow"
            Action = [
            "elasticloadbalancing:AddTags",
            "elasticloadbalancing:RemoveTags"
            ]
            Resource = [
            "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
            "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
            "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
            ]
        },

      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DeleteTargetGroup"
        ]
        Resource = "*"
      },

      # Allow LBC to register and deregister pods as targets
      # This is how pods receive traffic from ALB
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      },

      # Allow LBC to manage listener certificates for HTTPS
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddListenerCertificates",
          "elasticloadbalancing:RemoveListenerCertificates",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:SetWebAcl"
        ]
        Resource = "*"
      },

      # Allow LBC to use WAF for ALB protection
      {
        Effect = "Allow"
        Action = [
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL"
        ]
        Resource = "*"
      },

      # Allow LBC to use Shield for DDoS protection
      {
        Effect = "Allow"
        Action = [
          "shield:GetSubscriptionState",
          "shield:DescribeProtection",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ]
        Resource = "*"
      }
      ]
    })
    tags = {
        Name = "${var.cluster_name}-lbc-policy"
        Environment = "production"
        ManagedBy   = "terraform"   
        Project     = "eks"
    }

}


data "iam_policy_document" "lbc_assume_role_policy" {
    Version = "2012-10-17"
    statement {
        effect = "Allow"
        actions = ["sts:AssumeRoleWithWebIdentity"]
        principals{
          type = "Federated"
          identifiers = data.terraform_remote_state.Controlplane_details.outputs.oidc_provider_arn
        }
        condition {
          test = "StringEquals"
          variable = "${replace(data.terraform_remote_state.Controlplane_details.outputs.oidc_provider_url, "https://", "")}:sub"
          values = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]

        }
        condition {
          test = "StringEquals"
          variable = "${replace(data.terraform_remote_state.Controlplane_details.outputs.oidc_provider_url, "https://", "")}:aud"
          values = ["sts.amazonaws.com"]
        }
        
    }
}

resource "aws_iam_role" "lbc_role" {
    name = "${var.cluster_name}-lbc-role"
    description = "IAM role for AWS Load Balancer Controller"
    assume_role_policy = data.aws_iam_policy_document.lbc_assume_role_policy.json

    tags = {
        Name = "${var.cluster_name}-lbc-role"
        Environment = "production"
        ManagedBy   = "terraform"   
        Project     = "eks"
    }
}

resource "aws_iam_role_policy_attachment" "lbc_policy_attachment" {
    role = aws_iam_role.lbc_role.name
    policy_arn = aws_iam_policy.eks_lbc_policy.arn
    depends_on = [aws_iam_role.lbc_role, aws_iam_policy.eks_lbc_policy]

}

resource "kubernetes_service_account" "lbc" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    # LBC runs in kube-system namespace
    # Must match the namespace in the IRSA condition above

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.lbc_role.arn
      # This annotation is the IRSA magic
      # It tells EKS:
      # "Pods using this service account should get
      #  credentials for this IAM role"
    }

    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lbc_policy_attachment]
}

# ─────────────────────────────────────────────────────────────
# RESOURCE 4: Install LBC using Helm
# Helm installs the actual controller pods into the cluster
# ─────────────────────────────────────────────────────────────

resource "helm_release" "lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.lbc_version

  # Tell LBC which cluster it is managing
set {
  name  = "serviceAccount.create"
  value = "false"
  type  = "string"
  # explicitly tell Terraform this is a string
  # so Helm receives it correctly
}

  # Tell LBC to use the service account we created above
  # Do not create a new one
  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  # AWS region
  set {
    name  = "region"
    value = var.aws_region
  }

  # VPC ID — LBC needs this to create ALBs in correct VPC
  set {
    name  = "vpcId"
    value = data.terraform_remote_state.vpc_details.outputs.vpc_id
  }

  # Run 2 replicas for HA
  # If one LBC pod crashes, other keeps managing ALBs
  set {
    name  = "replicaCount"
    value = "2"
  }

  # Only schedule LBC on system nodes
  # Matches the label we put on system node group
  set {
    name  = "nodeSelector.role"
    value = "system"
  }

  # LBC pods tolerate the system node taint
  # So they CAN run on system nodes
  set {
    name  = "tolerations[0].key"
    value = "CriticalAddonsOnly"
  }

  set {
    name  = "tolerations[0].value"
    value = "true"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  depends_on = [
    kubernetes_service_account.lbc
  ]
}

