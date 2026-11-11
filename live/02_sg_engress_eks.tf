module "sg_eks" {
  name        = "eks"
  description = "Security group for EKS workloads"
  source      = "git::https://github.com/igor-platform-lab/terraform-modules.git//modules/security_group?ref=55c042f2753c907bf01cda102eea8a33756d2a39"
  vpc_id      = module.vpc.vpc_id
  tags = merge(
    var.environment_tags,
    {
      Owner   = "Ig0d"
      Purpose = "EKS"

  })
}

module "egress_dns_udp" {
  source = "git::https://github.com/igor-platform-lab/terraform-modules.git//modules/security_group_egress_rule?ref=55c042f2753c907bf01cda102eea8a33756d2a39"

  security_group_id = module.sg_eks.sg_id
  description       = "DNS UDP to VPC resolver"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  destination_type  = "cidr_ipv4"
  destination       = "10.16.0.2/32"
}

module "egress_dns_tcp" {
  source = "git::https://github.com/igor-platform-lab/terraform-modules.git//modules/security_group_egress_rule?ref=55c042f2753c907bf01cda102eea8a33756d2a39"

  security_group_id = module.sg_eks.sg_id
  description       = "DNS TCP to VPC resolver"
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
  destination_type  = "cidr_ipv4"
  destination       = "10.16.0.2/32"
}

module "egress_https_internet" {
  source = "git::https://github.com/igor-platform-lab/terraform-modules.git//modules/security_group_egress_rule?ref=55c042f2753c907bf01cda102eea8a33756d2a39"

  security_group_id = module.sg_eks.sg_id
  description       = "HTTPS internet access through NAT"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  destination_type  = "cidr_ipv4"
  destination       = "0.0.0.0/0"
}

module "egress_s3_gateway" {
  source = "git::https://github.com/igor-platform-lab/terraform-modules.git//modules/security_group_egress_rule?ref=55c042f2753c907bf01cda102eea8a33756d2a39"

  security_group_id = module.sg_eks.sg_id
  description       = "HTTPS to S3 Gateway Endpoint"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  destination_type  = "prefix_list"
  destination       = module.s3_gateway.prefix_list_id
}
