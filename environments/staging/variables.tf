variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "devops-staging"
}

variable "environment" {
  type    = string
  default = "staging"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "node_count" {
  type    = number
  default = 2
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "grafana_admin_password" {
  type      = string
  sensitive = "true"
}

