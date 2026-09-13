# modules/eks_access/main.tf

resource "aws_eks_access_entry" "platform_admins" {
  cluster_name  = var.cluster_name
  principal_arn = var.platform_admin_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "platform_admins" {
  cluster_name  = var.cluster_name
  principal_arn = var.platform_admin_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}