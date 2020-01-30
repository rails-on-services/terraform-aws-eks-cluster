resource "aws_security_group" "eks-cluster" {
  name        = join("-", [var.cluster_name, "eks-cluster"])
  description = "Cluster communication with worker nodes"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

## OPTIONAL: Allow inbound traffic from internet to the Kubernetes.
resource "aws_security_group_rule" "eks-cluster-ingress-internet-https" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow workstations to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.eks-cluster.id
  to_port           = 443
  type              = "ingress"
}

module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  version      = ">= 8.0.0"
  cluster_name = var.cluster_name
  subnets      = concat(var.public_subnets, var.private_subnets)
  vpc_id       = var.vpc_id

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  cluster_security_group_id       = aws_security_group.eks-cluster.id
  worker_ami_name_filter          = var.eks_worker_ami_name_filter
  cluster_enabled_log_types       = var.eks_cluster_enabled_log_types
  cluster_version                 = var.eks_cluster_version

  write_kubeconfig   = true
  config_output_path = "./"
  kubeconfig_name    = var.cluster_name

  kubeconfig_aws_authenticator_env_variables = {
    AWS_PROFILE = var.aws_profile
  }

  # using launch configuration
  worker_groups = var.eks_worker_groups
  workers_group_defaults = {
    instance_type                 = "r5.xlarge"
    name                          = "eks_workers_a"
    # ami_id                        = "ami-0d275f57a60281ccc"
    asg_max_size                  = 10
    asg_min_size                  = 2
    root_volume_size              = 100
    root_volume_type              = "gp2"
    autoscaling_enabled           = true
    protect_from_scale_in         = true
    asg_force_delete              = true # This is to address a case when terraform cannot delete autoscaler group if protect_from_scale_in = true
    enable_monitoring             = false
    kubelet_extra_args            = "--node-labels=kubernetes.io/lifecycle=on-demand"
    subnets                       = var.private_subnets
    additional_security_group_ids = var.default_security_group_id
  }

  worker_groups_launch_template = var.eks_worker_groups_launch_template

  map_users = var.eks_map_users
  map_roles = var.eks_map_roles

  tags = var.tags
}

## attach iam policy to allow aws alb ingress controller
resource "aws_iam_policy" "eks-worker-alb-ingress-controller" {
  name_prefix = "eks-worker-ingress-controller-${var.cluster_name}"
  description = "EKS worker node alb ingress controller policy for cluster ${var.cluster_name}"
  policy = file(
    "${path.module}/files/aws-alb-ingress-controller-iam-policy.json",
  )
}

resource "aws_iam_role_policy_attachment" "eks-worker-alb-ingress-controller" {
  policy_arn = aws_iam_policy.eks-worker-alb-ingress-controller.arn
  role       = module.eks.worker_iam_role_name
}

## attach iam policy to allow external-dns
resource "aws_iam_policy" "eks-worker-external-dns" {
  name_prefix = "eks-worker-external-dns-${var.cluster_name}"
  description = "EKS worker node external dns policy for cluster ${var.cluster_name}"
  policy      = file("${path.module}/files/aws-external-dns-iam-policy.json")
}

resource "aws_iam_role_policy_attachment" "eks-worker-external-dns" {
  policy_arn = aws_iam_policy.eks-worker-external-dns.arn
  role       = module.eks.worker_iam_role_name
}

## attach extra iam policies
resource "aws_iam_policy" "eks-worker-extra" {
  count       = length(var.eks_extra_policies)
  name_prefix = "eks-worker-extra-${var.cluster_name}"
  description = "EKS worker node extra permissions for cluster ${var.cluster_name}"
  policy      = var.eks_extra_policies[count.index]
}

resource "aws_iam_role_policy_attachment" "eks-worker-extra" {
 count      = length(var.eks_extra_policies)
 policy_arn = aws_iam_policy.eks-worker-extra[count.index].arn
 role       = module.eks.worker_iam_role_name
}

/*
## Tiller Service Account
resource "kubernetes_service_account" "tiller" {
  metadata {
    name      = "tiller"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "tiller" {
  metadata {
    name = "tiller"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "tiller"
    namespace = "kube-system"
  }
}

## CircleCi Service account
resource "kubernetes_service_account" "circleci" {
  metadata {
    name      = "circleci"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role" "circleci" {
  metadata {
    name = "circleci"
  }

  rule {
    api_groups = [""]
    resources  = ["pods/portforward"]
    verbs      = ["create"]
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["list", "get"]
  }

  rule {
    api_groups = ["apps", "extensions"]
    resources  = ["deployments"]
    verbs      = ["get", "patch"]
  }
}

resource "kubernetes_cluster_role_binding" "circleci" {
  metadata {
    name = "circleci"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "circleci"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "circleci"
    namespace = "kube-system"
  }
}
*/

resource "null_resource" "k8s-tiller-rbac" {
  provisioner "local-exec" {
    working_dir = path.module

    command = <<EOS
for i in `seq 1 10`; do \
echo "${module.eks.kubeconfig}" > kube_config.yaml & \
kubectl apply -f files/tiller-rbac.yaml --kubeconfig kube_config.yaml && break || \
sleep 10; \
done; \
rm kube_config.yaml;
EOS
  }

  triggers = {
    kube_config_rendered = module.eks.kubeconfig
  }
}

