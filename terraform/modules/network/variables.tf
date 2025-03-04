variable "vpc" {
  description = "Terraform VPC"
  type        = string
}

variable "subnet_ip" {
  description = "Terraform Subnet"
  type        = list(any)
}

variable "az" {
  description = "Terraform Availability Zone"
  type        = list(any)
}

variable "internet" {
  description = "Terraform Internet route"
  type        = any

}

variable "ssh" {
  description = "Terraform SSH"
  type        = any

}

variable "web_port" {
  description = "LoadBalancer web connection"
  type        = any

}

variable "all" {
  description = "SSH"
  type        = any
}
