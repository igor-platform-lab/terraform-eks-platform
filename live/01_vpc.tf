module "vpc" {
  source     = "git::https://github.com/igor-platform-lab/terraform-modules.git//modules/vpc?ref=55c042f2753c907bf01cda102eea8a33756d2a39"
  cidr_block = "10.16.0.0/16"
  tags = merge(
    var.environment_tags,
    {
      Owner = "Ig0d"

  })

}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = module.vpc.vpc_id

}