# Configure AWS Provider
provider "aws" {
	region     = "${var.aws_region}"
}

# Run the cassandra modules
module "cassandra_aws" {
    source = "./modules/cassandra_aws"

    providers = {
        aws = "aws"
    }

    default_keypair_name = "Opsschool-1"  # Default EC2 pem key 
    cassandra_dcs        = "2"            # number of cassandra datacenters
    cassandra_servers    = "3"            # number of cassandra nodes per datacenter
    vpc_id               = "vpc-584d6e20" # AWS VPC 
    image                = {
      "name"     = "cassandra"
      "tagowner" = "Opsschool"
      "tagname"  = "Cassandra"
    }
}

output "public_ip" {
  value = "${module.cassandra_aws.cassandra_server_public_ip}"
}

output "private_ip" {
  value = "${module.cassandra_aws.cassandra_server_private_ip}"
}

output "seeds" {
  value = "${module.cassandra_aws.cassandra_seeds}"
}