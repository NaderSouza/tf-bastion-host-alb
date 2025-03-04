variable "ami" {
  description = "AMI ID - Centos 7"
  type        = any

}
variable "instance_type" {
  description = "Instance Type"
  type        = list(any)

}

variable "http" {
  description = "Setup http/s port"
  type        = list(any)

}

variable "web_port" {
  description = "LoadBalancer web connection"
  type        = any

}
