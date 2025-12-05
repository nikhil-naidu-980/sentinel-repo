terraform {
  backend "s3" {
    bucket  = "sentinel-tfstate-dev-721500739616"
    key     = "dev/terraform.tfstate"
    region  = "us-west-2"
    encrypt = true
  }
}
