variable "name_prefix" {
  type = string
}

variable "repository_names" {
  type    = list(string)
  default = ["backend", "gateway"]
}

variable "image_tag_mutability" {
  type    = string
  default = "MUTABLE"
}

variable "scan_on_push" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
