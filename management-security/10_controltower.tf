resource "aws_controltower_landing_zone" "main" {
  version       = "4.0"
  manifest_json = file("${path.module}/../landing-zone.json")
}