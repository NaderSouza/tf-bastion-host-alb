variable "ami" {
  description = "AMI para as instâncias EC2"
  type        = string
}

variable "instance_type" {
  description = "Tipos de instâncias EC2"
  type        = list(string)
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "bastion_sg_id" {
  description = "ID do Security Group do Bastion"
  type        = string
}

variable "web_sg_id" {
  description = "ID do Security Group do Web"
  type        = string
}

variable "web_subnet_id" {
  description = "ID da subnet onde o servidor Web será provisionado"
  type        = string
}

variable "ssh_key_name" {
  description = "Nome da chave SSH para acessar as instâncias"
  type        = string
}

variable "web_port" {
  description = "Porta do servidor web"
  type        = number
}
