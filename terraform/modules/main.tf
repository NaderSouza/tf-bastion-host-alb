# MODULE: NETWORK
module "network" {
  source             = "./modules/network"
  vpc_cidr           = "10.0.0.0/16"
  public_subnets     = [var.subnet_ip[0], var.subnet_ip[1]]
  private_subnets    = [var.subnet_ip[2], var.subnet_ip[3], var.subnet_ip[4], var.subnet_ip[5]]
  availability_zones = var.az
}

# MODULE: COMPUTE
module "compute" {
  source        = "./modules/compute"
  vpc_id        = module.network.vpc_id
  bastion_sg_id = module.network.bastion_sg_id
  web_sg_id     = module.network.web_sg_id
  web_subnet_id = module.network.web_subnet_id
  ami           = var.ami
  instance_type = var.instance_type[0]
  ssh_key_name  = module.network.ssh_key_name
  depends_on    = [module.network]
}

# MODULE: DATABASE
module "database" {
  source            = "./modules/database"
  vpc_id            = module.network.vpc_id
  db_sg_id          = module.network.db_sg_id
  db_subnet_ids     = [module.network.db_subnet_id1, module.network.db_subnet_id2]
  db_instance_class = "db.t3.medium"
  db_username       = "admin"
  db_password       = "admin123"
  kms_key_id        = module.compute.kms_key_id
  depends_on        = [module.compute]
}
