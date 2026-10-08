variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "allowed_ip" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "tags" {
  type    = map(string)
  default = {}
}