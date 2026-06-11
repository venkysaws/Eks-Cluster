data "terraform_remote_state" "Controlplane_details" {
    backend = "s3"

    config = {
        bucket = "eksprojbackendvenkaiah"
        key    = "statefile/eks/controlplane.tfstate"
        region = "ap-south-1"
    }
}

data "terraform_remote_state" "vpc_details" {
    backend = "s3"

    config = {
        bucket = "eksprojbackendvenkaiah"
        key    = "statefile/eks/vpc.tfstate"
        region = "ap-south-1"
    }
}

data "terraform_remote_state" "Iam_details" {
    backend = "s3"

    config = {
        bucket = "eksprojbackendvenkaiah"
        key    = "statefile/eks/iam.tfstate"
        region = "ap-south-1"
    }
}


data "terraform_remote_state" "WorkerPlane_details" {
    backend = "s3"

    config = {
        bucket = "eksprojbackendvenkaiah"
        key    = "statefile/eks/workerplane.tfstate"
        region = "ap-south-1"
    }
}


resource "aws_iam_policy" "CA_policy" {
    name        = "${var.cluster_name}-ca-policy"
    description = "IAM policy for EKS Cluster Autoscaler"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [

      # ── Read permissions ──────────────────────────────────
      # CA needs to READ ASG state before making decisions
      # All describe/list actions need * resource
      {
        Sid    = "DescribeResources"
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          # Find all ASGs — CA discovers node groups from these

          "autoscaling:DescribeAutoScalingInstances",
          # Check which EC2 instances are in each ASG

          "autoscaling:DescribeLaunchConfigurations",
          # Read launch config to understand node specs
          # (how much CPU/memory each node provides)

          "autoscaling:DescribeScalingActivities",
          # Check if a scaling action is already in progress
          # Prevents duplicate scale up requests

          "autoscaling:DescribeTags",
          # Read ASG tags to find node groups that belong
          # to THIS cluster (via k8s.io/cluster-autoscaler tags)

          "ec2:DescribeLaunchTemplateVersions",
          # Read launch template to understand node capacity
          # We use launch templates (not launch configs)

          "ec2:DescribeInstanceTypes",
          # Understand CPU/memory of each instance type
          # CA uses this to pick the right node group

          "ec2:DescribeImages",
          # Read AMI details for nodes
          # Used for capacity calculations

          "eks:DescribeNodegroup"
          # Read EKS node group details
          # CA uses this for managed node groups
        ]
        Resource = "*"
        # All describe actions need * — cannot restrict further
      },

      # ── Write permissions ─────────────────────────────────
      # CA needs to MODIFY ASGs to scale up/down
      {
        Sid    = "ModifyAutoScalingGroups"
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          # THE most important permission
          # This is how CA scales nodes up or down
          # Sets desired count on the ASG

          "autoscaling:TerminateInstanceInAutoScalingGroup"
          # Terminates a specific idle node
          # Used during scale down
          # More precise than just reducing desired count
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled" = "true"
            # CRITICAL security condition
            # CA can only modify ASGs that have this tag
            # Remember we added this tag to our node groups in Phase 4
            # Without this condition CA could accidentally
            # scale down ASGs belonging to other applications
            # in the same AWS account
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-ca-policy"
    Environment = var.environment
    project     = var.project_name
  }
}

data "aws_iam_policy_document" "CA_assume_role_policy" {

    statement {
        effect = "Allow"
        actions = ["sts:AssumeRoleWithWebIdentity"]
        principals {
            type = "Federated"
            identifiers = [data.terraform_remote_state.Controlplane_details.outputs.oidc_provider_arn]
        }
        condition {
            test     = "StringEquals"
            variable = "${replace(data.terraform_remote_state.Controlplane_details.outputs.oidc_provider_url, "https://", "")}:sub"
            values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
        }
        condition {
            test     = "StringEquals"
            variable = "${replace(data.terraform_remote_state.Controlplane_details.outputs.oidc_provider_url, "https://", "")}:aud"
            values   = ["sts.amazonaws.com"]
        }
    }
}

resource "aws_iam_role" "CA_role" {
    name = "${var.cluster_name}-ca-role"
    description = "IAM role for EKS Cluster Autoscaler"
    assume_role_policy = data.aws_iam_policy_document.CA_assume_role_policy.json

    tags = {
        Name        = "${var.cluster_name}-ca-role"
        Environment = var.environment
        project     = var.project_name
    }
}

resource "aws_iam_role_policy_attachment" "CA_role_attachment" {
    role       = aws_iam_role.CA_role.name
    policy_arn = aws_iam_policy.CA_policy.arn
}

resource "kubernetes_service_account" "cluster_autoscaler" {
    metadata {
        name      = "cluster-autoscaler"
        namespace = "kube-system"
        annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.CA_role.arn
        }
        labels = {
        "app.kubernetes.io/name"    = "cluster-autoscaler"
        "app.kubernetes.io/version" = var.ca_version
        }
    }
    depends_on = [aws_iam_role_policy_attachment.CA_role_attachment]
}

resource "helm_release" "cluster_autoscaler" {
    name       = "cluster-autoscaler"
    repository = "https://kubernetes.github.io/autoscaler"
    chart      = "cluster-autoscaler"
    version    = var.ca_version
    namespace  = "kube-system"

      # Which cluster to autoscale
  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
    # CA uses this to find ASGs tagged with
    # k8s.io/cluster-autoscaler/<cluster-name>
  }

  # AWS region
  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  # Use our pre-created service account
  set {
    name  = "rbac.serviceAccount.create"
    value = "false"
    # Do not create a new one
    # Use the one we created above with IRSA annotation
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  # ── Scaling behavior settings ─────────────────────────────

  set {
    name  = "extraArgs.balance-similar-node-groups"
    value = "true"
    # When scaling up, distribute nodes evenly
    # across similar node groups in different AZs
    # Prevents all new nodes going to same AZ
  }

  set {
    name  = "extraArgs.skip-nodes-with-system-pods"
    value = "false"
    # Allow CA to scale down nodes that have system pods
    # System pods will be rescheduled elsewhere
    # If true, system nodes can never be scaled down
  }

  set {
    name  = "extraArgs.scale-down-delay-after-add"
    value = "5m"
    # Wait 5 minutes after adding a node
    # before considering scale down
    # Prevents thrashing (add node → immediately remove)
  }

  set {
    name  = "extraArgs.scale-down-unneeded-time"
    value = "10m"
    # Node must be unneeded for 10 minutes
    # before CA removes it
    # Prevents removing nodes too aggressively
  }

  set {
    name  = "extraArgs.scale-down-utilization-threshold"
    value = "0.5"
    # Node is considered underutilized if
    # CPU and memory requests are below 50%
    # CA will try to remove such nodes
  }

  set {
    name  = "extraArgs.max-node-provision-time"
    value = "15m"
    # If a new node does not join cluster within 15 minutes
    # CA considers the scale up failed
    # And tries again
  }

  set {
    name  = "extraArgs.expander"
    value = "least-waste"
    # When multiple node groups can fit pending pods
    # which one should CA choose?
    #
    # least-waste → pick node group that wastes
    #               least CPU/memory
    #               Most efficient choice
    #
    # Other options:
    # random      → pick randomly
    # most-pods   → node that fits most pods
    # priority    → based on priority you define
  }

  # ── Pod placement settings ────────────────────────────────

  # Run CA on system nodes
  set {
    name  = "nodeSelector.role"
    value = "system"
  }

  # CA pod tolerates system node taint
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

  # ── Resource limits for CA pod itself ────────────────────

  set {
    name  = "resources.requests.cpu"
    value = "100m"
    # 0.1 CPU core requested
  }

  set {
    name  = "resources.requests.memory"
    value = "300Mi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "resources.limits.memory"
    value = "600Mi"
  }

  depends_on = [
    kubernetes_service_account.cluster_autoscaler
  ]
}
