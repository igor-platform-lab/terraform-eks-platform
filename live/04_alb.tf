module "alb_internet_facing" {
  source             = "git::https://github.com/igor-platform-lab/terraform-modules.git//modules/load_balancer?ref=55c042f2753c907bf01cda102eea8a33756d2a39"
  name               = "eks-internet-facing"
  subnets_ids        = [module.subnet-public-b.subnet_id, module.subnet-public-a.subnet_id]
  internal           = false
  security_group_ids = [module.sg_alb.sg_id]
  bucket             = module.s3_alb.bucket_id
  enabled            = true
  depends_on         = [aws_s3_bucket_policy.alb_access_logs]
  tags = merge(
    var.environment_tags,
    {
      Owner = "Ig0d"

  })

}

module "alb_listener" {
  source            = "git::https://github.com/igor-platform-lab/terraform-modules.git//modules/load_balancer_listener?ref=55c042f2753c907bf01cda102eea8a33756d2a39"
  port              = 443
  load_balancer_arn = module.alb_internet_facing.alb_arn
  protocol          = "HTTPS"
  target_group_arn  = module.alb_target_group.target_group_arn
}

module "alb_target_group" {
  source   = "git::https://github.com/igor-platform-lab/terraform-modules.git//modules/target_group?ref=55c042f2753c907bf01cda102eea8a33756d2a39"
  name     = "eks-workloads-http"
  port     = 80
  vpc_id   = module.vpc.vpc_id
  protocol = "HTTP"

}

module "sg_alb" {
  source      = "git::https://github.com/igor-platform-lab/terraform-modules.git//modules/security_group?ref=55c042f2753c907bf01cda102eea8a33756d2a39"
  vpc_id      = module.vpc.vpc_id
  name        = "alb"
  description = "Security group for the internet-facing ALB"
  tags = merge(
    var.environment_tags,
    {
      Owner = "Ig0d"
    }
  )

}

module "alb_ingress_https" {
  source = "git::https://github.com/igor-platform-lab/terraform-modules.git//modules/security_group_ingress_rule?ref=55c042f2753c907bf01cda102eea8a33756d2a39"

  security_group_id = module.sg_alb.sg_id
  description       = "HTTPS from the internet"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  source_type       = "cidr_ipv4"
  source_value      = "0.0.0.0/0"
}

module "alb_egress_eks" {
  source            = "git::https://github.com/igor-platform-lab/terraform-modules.git//modules/security_group_egress_rule?ref=55c042f2753c907bf01cda102eea8a33756d2a39"
  from_port         = 80
  to_port           = 80
  security_group_id = module.sg_alb.sg_id
  description       = "HTTP to EKS workloads"
  destination_type  = "security_group"
  destination       = module.sg_eks.sg_id
  ip_protocol       = "tcp"
}
