module "nat_gateway" {
  source     = "git::https://github.com/igor-platform-lab/terraform-modules.git//modules/nat_gateway?ref=55c042f2753c907bf01cda102eea8a33756d2a39"
  vpc_id     = module.vpc.vpc_id
  depends_on = [aws_internet_gateway.internet_gateway]
  tags = merge(var.environment_tags, {
    Type  = "Network"
    Owner = "Ig0d"
  })
}