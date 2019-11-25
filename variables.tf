variable "tags" {
  type    = map
  default = {}
}

variable "aws_profile" {
  type        = string
  default     = "default"
  description = "Valid AWS Profile in local config that has access to the cluster. This to avoid Unauthorized error when local-exec runs"
}

variable "cluster_name" {
  type    = string
  default = ""
}

variable "eks_cluster_version" {
  type    = string
  default = "1.14"
}

variable "vpc_id" {
  type    = string
  default = ""
}

variable "public_subnets" {
  type    = list(string)
  default = []
}

variable "private_subnets" {
  type    = list(string)
  default = []
}
variable "default_security_group_id" {
  type    = string
  default = ""
}

variable "eks_worker_ami_name_filter" {
  type    = string
  default = "v*"
}

variable "eks_cluster_enabled_log_types" {
  default = []
}

variable "eks_worker_groups" {
  type    = any
  default = []
}

variable "eks_worker_groups_launch_template" {
  type    = any
  default = []
}

variable "eks_map_users" {
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default     = []
  description = "IAM users to add to the aws-auth configmap, see example here: https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/examples/eks_test_fixture/variables.tf"
}

variable "eks_map_roles" {
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default     = []
  description = "IAM roles to add to the aws-auth configmap, see example here: https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/examples/eks_test_fixture/variables.tf"
}

variable "eks_extra_policies" {
  type        = list(string)
  default     = []
  description = "The list of extra IAM policies to create for cluster nodes"
}