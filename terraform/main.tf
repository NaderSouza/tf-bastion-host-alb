module "network" {
  source    = "./modules/network"
  vpc       = var.vpc
  subnet_ip = var.subnet_ip
  az        = var.az
  internet  = var.internet
  ssh       = var.ssh
  http      = var.http
  web_port  = var.web_port
  all       = var.all
}




module "compute" {
  source        = "./modules/compute"
  ami           = var.ami
  instance_type = var.instance_type
  vpc_id        = module.network.vpc_id
  bastion_sg_id = module.network.bastion_sg_id
  web_sg_id     = module.network.web_sg_id
  web_subnet_id = module.network.web_subnet_id
  ssh_key_name  = "hush"
  web_port      = var.web_port
}


module "database" {
  source           = "./modules/database"
  db_instance_type = "db.t3.medium"
  db_username      = "admin"
  db_password      = "admin123"
  db_subnet_ids    = [module.network.db_subnet1_id, module.network.db_subnet2_id]
  db_sg_id         = module.network.db_sg_id
  db_port          = 3306
}


