# Provider spcific
provider "aws" {
    region = "${var.aws_region}"
    access_key = "*****************************"
    secret_key = "*****************************"

}

# Variables for VPC module
module "vpc_subnets" {
	source = "./modules/vpc_subnets"
	name = "finantier"
	environment = "dev"
	enable_dns_support = true
	enable_dns_hostnames = true
	vpc_cidr = "172.16.0.0/16"
        public_subnets_cidr = "172.16.10.0/24,172.16.20.0/24"
        private_subnets_cidr = "172.16.30.0/24,172.16.40.0/24"
	azs = "ap-southeast-1a,ap-southeast-1b"
}

module "ssh_sg" {
	source = "./modules/ssh_sg"
	name = "finantier"
	environment = "dev"
	vpc_id = "${module.vpc_subnets.vpc_id}"
	source_cidr_block = "0.0.0.0/0"
}

module "web_sg" {
	source = "./modules/web_sg"
	name = "finantier"
	environment = "dev"
	vpc_id = "${module.vpc_subnets.vpc_id}"
	source_cidr_block = "0.0.0.0/0"
}

module "elb_sg" {
	source = "./modules/elb_sg"
	name = "finantier"
	environment = "dev"
	vpc_id = "${module.vpc_subnets.vpc_id}"
}

module "rds_sg" {
    source = "./modules/rds_sg"
    name = "finantier"
    environment = "dev"
    vpc_id = "${module.vpc_subnets.vpc_id}"
    security_group_id = "${module.web_sg.web_sg_id}"
}

module "ec2key" {
	source = "./modules/ec2key"
	key_name = "finantier"
        public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDDy4ZXggrlJHBcKairbqX+BK2kKg3X47/wnV1Z62hq4hSRWZI0s38jBuFWSTnuGL8kAiOVccHH8uyqf8vn4CslavYebIGX55AkLNxR2W3Q7yL0gRgHV5N3mARZTLvotmOS3zaGKee2ugE/fmTqVSPtZwa8DieLolHlj9IJo//duc+qbhKDLRwBzCOiplc/gNiBex6tsqYMn6Cuky9hPitZYYLY50m6sWrJKoUB55CKAefaFsrXa/SQpDxaM6o5KZCzNYrIf9/HZJWwy3L/ElrELFmBiMayRjQeUGEYK/TqvjLFYLVR7IGqi2ap5XMQnlDFWd40HnXfGKNC+xgyamuLIHLcpMgCsspYslnd19+xFXXrF7+bc91Ua3n6jrSzPmX6mKgwlQ0eRRg6noaKPhnyNrNeHn/lPGEp2dwHOFPsCe3TRwBX6gPXV8gnP+BNpKkY4nVmyDApkmZhDlTwYLns5IcW4j9WcJz9Gdg7QHt5QqnP7TbvjL3bpjURGBnN9Xa6gprdDsvyCbZTQJB2Dn6Loby6SgXuKa9b75VitjkW7jGm8Pvo9dA7Z/pGB78SODDLTHj9+pGOnPmZzAQ/rVaAmp3N1g8TnfM+YyrbEOnPr931brE6HZRpOJ1oj8mNKc7Z6Ry4yvAuOJCDisBsZDeLZ4uzbvAUzkm18qnsrUbdgQ== chandra"
}

module "ec2" {
	source = "./modules/ec2"
	name = "finantier"
	environment = "dev"
	server_role = "web"
	ami_id = "ami-055147723b7bca09a"
	key_name = "${module.ec2key.ec2key_name}"
	count = "2"
	security_group_id = "${module.ssh_sg.ssh_sg_id},${module.web_sg.web_sg_id}"
	subnet_id = "${module.vpc_subnets.public_subnets_id}"
	instance_type = "t2.micro"
	user_data = "#!/bin/bash\napt-get -y update\napt-get -y install nginx\n"
}

module "rds" {
	source = "./modules/rds"
	name = "finantier"
	environment = "dev"
	storage = "5"
	engine_version = "5.7"
	db_name = "wordpress"
	username = "root"
	password = "${var.rds_password}"
	security_group_id = "${module.rds_sg.rds_sg_id}"
	subnet_ids = "${module.vpc_subnets.private_subnets_id}"
}

module "elb" {
	source = "./modules/elb"
	name = "finantier"
	environment = "dev"
	security_groups = "${module.elb_sg.elb_sg_id}"
	availability_zones = "ap-southeast-1a,ap-southeast-1b"
	subnets = "${module.vpc_subnets.public_subnets_id}"
	instance_id = "${module.ec2.ec2_id}"
}

module "route53" {
	source = "./modules/route53"
	hosted_zone_id = "${var.hosted_zone_id}"
	domain_name = "${var.domain_name}"
	elb_address = "${module.elb.elb_dns_name}"
	elb_zone_id = "${module.elb.elb_zone_id}"

}
