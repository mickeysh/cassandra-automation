variable "aws_region" {
  default = "us-east-1"
}

variable default_keypair_name {
  description = "Name of the KeyPair used for all nodes"
  default = "Opsschool-1"
}
variable instance_type {
  default = "t2.medium"
}

variable cassandra_servers {
  default = "3"
}

variable owner {
  default = "Cassandra"
}

variable vpc_id {
  default = "vpc-584d6e20"
}

variable cassandra_cluster {
  default = "opsschool"
}

variable user {
  default = "ubuntu"
}