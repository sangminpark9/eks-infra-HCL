module "iam" {
  source = "./iam"
}

module "vpc" {
  source = "./vpc"
  outpost_arn = var.outpost_arn
}

module "eks" {
  source             = "./eks"
  cluster_name       = "my-cluster"
  cluster_version    = "1.30"
  subnet_ids         = module.vpc.private_subnet_ids
  node_group_name    = "workers"   
  node_instance_type = "t3.medium"
  desired_capacity   = 2
  max_capacity       = 3
  min_capacity       = 1

  cluster_role_arn   = module.iam.eks_cluster_role_arn
  worker_role_arn    = module.iam.eks_worker_role_arn

  control_plane_instance_type = var.control_plane_instance_type
  outpost_arn                 = var.outpost_arn
  outposts_subnet_ids         = module.vpc.outposts_subnet_ids
  outposts_instance_type      = var.outposts_instance_type
}


module "bastion" {
  source              = "./bastion"
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids

  ssh_cidr            = var.ssh_cidr            # 직접 명시 (예: "0.0.0.0/0")
  ami_id              = var.bastion_ami         # 직접 명시
  instance_type       = "t3.micro"
  key_name            = var.key_name            # 직접 명시
  bastion_role_name   = module.iam.bastion_role_name
}
