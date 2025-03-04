output "db_endpoint" {
  description = "Endpoint do banco de dados"
  value       = aws_db_instance.rds.endpoint
}
