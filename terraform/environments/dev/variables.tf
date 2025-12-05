variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "project_name" {
  type    = string
  default = "sentinel"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "gateway_vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "backend_vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "enable_flow_logs" {
  type    = bool
  default = false  
}

variable "kubernetes_version" {
  type    = string
  default = "1.31"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "capacity_type" {
  type    = string
  default = "ON_DEMAND"
}

variable "gateway_node_desired_size" {
  type    = number
  default = 1
}

variable "gateway_node_min_size" {
  type    = number
  default = 1
}

variable "gateway_node_max_size" {
  type    = number
  default = 2
}

variable "backend_node_desired_size" {
  type    = number
  default = 1
}

variable "backend_node_min_size" {
  type    = number
  default = 1
}

variable "backend_node_max_size" {
  type    = number
  default = 2
}
