variable "db_instance_type" {
  description = "Tipo de instância para o banco de dados"
  type        = string
}

variable "db_username" {
  description = "Usuário do banco de dados"
  type        = string
}

variable "db_password" {
  description = "Senha do banco de dados"
  type        = string
}

variable "db_subnet_ids" {
  description = "Lista de subnets privadas para o RDS"
  type        = list(string)
}

variable "db_sg_id" {
  description = "ID do Security Group do banco de dados"
  type        = string
}

variable "db_port" {
  description = "Porta de conexão do banco de dados"
  type        = number
}
