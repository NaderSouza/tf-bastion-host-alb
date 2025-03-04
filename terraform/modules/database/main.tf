#DATA BASE MASTER
resource "aws_db_instance" "rds_primary_instance" {
  allocated_storage = 10
  identifier_prefix = "mydb-master"
  engine            = "mysql"
  storage_type      = "gp2"
  # engine_version         = "5.7"
  instance_class = "db.t3.medium"
  username       = "admin"
  password       = "admin123"
  # parameter_group_name   = "default.mysql5.7"
  skip_final_snapshot          = true
  vpc_security_group_ids       = [aws_security_group.db.id]
  db_subnet_group_name         = aws_db_subnet_group.db_subnet_group.name
  backup_retention_period      = 7
  backup_window                = "03:00-04:00"
  maintenance_window           = "Mon:04:00-Mon:04:30"
  performance_insights_enabled = true
  multi_az                     = true
  storage_encrypted            = true
  kms_key_id                   = aws_kms_key.mykmskey.arn

  tags = {
    Name = "DB Master"
  }
}


#DB SUBNET GROUP
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "mydb-subnet-group"
  subnet_ids = [aws_subnet.db.id, aws_subnet.db2.id]

  tags = {
    Name = "DB-Subnet-Group"
  }
}


#KMS KEY
resource "aws_kms_key" "mykmskey" {
  description             = "KMS Key for RDS"
  deletion_window_in_days = 8
  multi_region            = true
  tags = {
    Name = "KMS-Key"
  }

}

#KMS ALIAS
resource "aws_kms_alias" "a" {
  name          = "alias/master-db-key"
  target_key_id = aws_kms_key.mykmskey.key_id


}

#KMS KEY WEST-2
resource "aws_kms_key" "mykmskey-west" {
  description             = "KMS Key for RDS in west-2 region"
  deletion_window_in_days = 8
  multi_region            = true
  provider                = aws.replica
  tags = {
    Name = "mykmskey-west"
  }

}


#DB REPLICA
resource "aws_db_instance" "replica" {
  replicate_source_db          = aws_db_instance.rds_primary_instance.identifier
  instance_class               = "db.t3.medium"
  skip_final_snapshot          = true
  vpc_security_group_ids       = [aws_security_group.db.id]
  backup_retention_period      = 7
  backup_window                = "03:00-04:00"
  maintenance_window           = "Mon:04:00-Mon:04:30"
  performance_insights_enabled = true
  multi_az                     = true
  storage_encrypted            = true
  kms_key_id                   = aws_kms_key.mykmskey.arn

  tags = {
    Name = "DB Replica"
  }
}

#DB BACKUP WEST-2
resource "aws_db_instance_automated_backups_replication" "default" {
  source_db_instance_arn = aws_db_instance.rds_primary_instance.arn
  kms_key_id             = aws_kms_key.mykmskey-west.arn
  retention_period       = 8
  provider               = aws.replica
}
