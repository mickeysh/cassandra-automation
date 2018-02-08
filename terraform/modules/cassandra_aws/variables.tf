variable default_keypair_name {
  description = "Name of the KeyPair used for all nodes"
}
variable instance_type {
  description = "AWS Instance type"
  default = "t2.medium"
}

variable cassandra_dcs {
  description = "Number of Cassandra DCs"
  default = "1"
}

variable cassandra_servers {
  description = "Number of Cassandra nodes per DC"
  default = "3"
}

variable owner {
  description = "EC2 owner tag"
  default = "Cassandra"
}

variable vpc_id {
  description = "AWS VPC id"
}

variable cassandra_cluster {
  description = "Name of the cassandra cluster"
  default = "cassandra"
}

variable user {
  description = "EC2 Linux instance user"
  default = "ubuntu"
}