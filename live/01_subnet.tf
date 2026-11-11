module "subnet-public-a" {
  source            = "git::https://github.com/igor-platform-lab/terraform-modules.git//modules/subnet?ref=55c042f2753c907bf01cda102eea8a33756d2a39"
  vpc_id            = module.vpc.vpc_id
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = "10.16.0.0/20"
  depends_on        = [module.vpc]
  is_public         = true
  tags = merge(
    var.environment_tags,
    {
      Owner = "Ig0d",
      Name  = "public-a"
    }

  )
  gateway_id = aws_internet_gateway.internet_gateway.id

}

module "subnet-public-b" {
  source            = "git::https://github.com/igor-platform-lab/terraform-modules.git//modules/subnet?ref=55c042f2753c907bf01cda102eea8a33756d2a39"
  vpc_id            = module.vpc.vpc_id
  availability_zone = data.aws_availability_zones.available.names[1]
  depends_on        = [module.vpc]
  cidr_block        = "10.16.16.0/20"
  is_public         = true
  tags = merge(
    var.environment_tags,
    {
      Owner = "Ig0d",
      Name  = "public-b"
    }
  )
  gateway_id = aws_internet_gateway.internet_gateway.id

}

module "subnet-private-a" {
  source            = "git::https://github.com/igor-platform-lab/terraform-modules.git//modules/subnet?ref=55c042f2753c907bf01cda102eea8a33756d2a39"
  vpc_id            = module.vpc.vpc_id
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = "10.16.32.0/20"
  depends_on        = [module.vpc]
  nat_gateway       = module.nat_gateway.nat_id
  tags = merge(
    var.environment_tags,
    {
      Owner = "Ig0d",
      Name  = "private-a"
    }

  )

}

module "subnet-private-b" {
  source            = "git::https://github.com/igor-platform-lab/terraform-modules.git//modules/subnet?ref=55c042f2753c907bf01cda102eea8a33756d2a39"
  vpc_id            = module.vpc.vpc_id
  nat_gateway       = module.nat_gateway.nat_id
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block        = "10.16.48.0/20"
  depends_on        = [module.vpc]
  tags = merge(
    var.environment_tags,
    {
      Owner = "Ig0d",
      Name  = "private-b"
    }

  )

}