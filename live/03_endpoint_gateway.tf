module "s3_gateway" {
  source           = "git::https://github.com/igor-platform-lab/terraform-modules.git//modules/endpoint_gateway?ref=55c042f2753c907bf01cda102eea8a33756d2a39"
  service_name     = "com.amazonaws.us-east-2.s3"
  vpc_id           = module.vpc.vpc_id
  route_tables_ids = [module.subnet-private-b.route_table_id, module.subnet-private-a.route_table_id]
  tags = merge(
    var.environment_tags,
    {
      Purpose = "eks-interface-endpoints"
      Owner   = "Ig0d"
    }

  )
}