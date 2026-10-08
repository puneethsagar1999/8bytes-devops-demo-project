terraform {
  backend "s3" {
    bucket       = "robot-omns-tfstate-puneeth-om-nama-shivaya"
    key          = "staging/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}