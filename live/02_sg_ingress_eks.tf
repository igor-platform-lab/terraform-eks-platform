module "eks_ingress_alb" {
  source = "git::https://github.com/igor-platform-lab/terraform-modules.git//modules/security_group_ingress_rule?ref=55c042f2753c907bf01cda102eea8a33756d2a39"

  security_group_id = module.sg_eks.sg_id
  description       = "HTTP from the ALB"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  source_type       = "security_group"
  source_value      = module.sg_alb.sg_id
}
