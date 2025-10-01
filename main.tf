
module "network" {
    source = "./modules/network"
    vpc_cidr = "10.0.0.0/22"
    public_subnet_cidrs = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    tags = {
        Environment = "prod"
        Project = "dr-simulation"
    }
}

module "ec2_primary"{
source = "./modules/ec2-primary"
ami_id = "ami-0110792f6b06bc562"
instance_type = "t3.medium"
subnet_id = module.network.public_subnet_ids[0]
vpc_id = module.network.vpc_id
key_name = "k8s-master-key-pair"
}

module "ec2_dr" {
    source = "./modules/ec2-dr"
    name = "dr-sim"
    vpc_id = module.network.vpc_id
    subnet_ids = module.network.public_subnet_ids
    master_subnet_id = module.network.public_subnet_ids[1]
    ami_id = "ami-0110792f6b06bc562"
    master_instance_type = "t3.medium"
    worker_instance_type = "t3.medium"
    key_name = "k8s-master-key-pair"
    k3s_token = ""
    min_size = 1
    desired_capacity = 1
    max_size = 3

    tags = {
        Project = "dr-simulation"
        ENV = "dr"
    }
}

module "monitoring" {
  source = "./modules/monitoring"
  zone_id  = var.route53_zone_id
  record_name = var.record_name 
  primary_ip = module.ec2_primary.public_ip
  dr_ip = module.ec2_dr.master_public_ip
  ttl = 60
  health_check_port = 80
  health_check_path = "/"
  request_interval = 30
  failure_threshold = 3
  tags = {
    Project = "dr-simulation"
    Env     = "prod"
  }
}
