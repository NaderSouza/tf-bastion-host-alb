output "bastion_subnet_id" {
  value = aws_subnet.bastion.id
}

output "web_subnet_id" {
  value = aws_subnet.web.id
}

output "db_subnet1_id" {
  value = aws_subnet.db.id
}

output "db_subnet2_id" {
  value = aws_subnet.db2.id
}

output "bastion_sg_id" {
  value = aws_security_group.bastion.id
}

output "web_sg_id" {
  value = aws_security_group.web.id
}

output "db_sg_id" {
  value = aws_security_group.db.id
}

output "ssh_key_name" {
  value = aws_key_pair.hush.key_name
}
