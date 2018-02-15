
# Get Ubuntu AMI information 
data "aws_ami" "cassandra" {
    most_recent = true
    filter {
        name   = "name"
        values = ["${var.image["name"]}-*"]
    }
    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }
    filter {
        name   = "tag:Owner"
        values = ["${var.image["tagowner"]}"]
    }
    filter {
        name   = "tag:Name"
        values = ["${var.image["tagname"]}"] 
    }
}

# Get Subnet Id for the VPC
data "aws_subnet_ids" "subnets" {
    vpc_id = "${var.vpc_id}"
}

#Jenkins Security Group
resource "aws_security_group" "cassandra_sg" {
  name        = "cassandra_sg"
  description = "Security group for Cassandra"
  vpc_id      = "${var.vpc_id}"
  
  egress {
    from_port    = 0
    to_port      = 0
    protocol     = "-1"
    cidr_blocks  = ["0.0.0.0/0"]
  }

  # Allow ICMP from control host IP
  ingress {
    from_port = 1
    to_port = 1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all SSH External
  ingress {
    from_port = 22
    to_port = 22
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }


  # Cassandra inter-node cluster communication
  ingress {
    from_port = 7000
    to_port = 7000
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

    # Cassandra SSL inter-node cluster communication
  ingress {
    from_port = 7001
    to_port = 7001
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Cassandra JMX monitoring port
  ingress {
    from_port = 7199
    to_port = 7199
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Cassandra client port
  ingress {
    from_port = 9041
    to_port = 9041
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Cassandra client port
  ingress {
    from_port = 9042
    to_port = 9042
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
      
  # Cassandra client port (Thrift).
  ingress {
    from_port = 9160
    to_port = 9160
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Allocate the EC2 Cassandra instances 
resource "aws_instance" "cassandra" {
    count         = "${var.cassandra_servers * var.cassandra_dcs}"
    ami           = "${data.aws_ami.cassandra.id}"
    instance_type = "${var.instance_type}"

    subnet_id              = "${element(data.aws_subnet_ids.subnets.ids, ceil(count.index/var.cassandra_servers))}"
    vpc_security_group_ids = ["${aws_security_group.cassandra_sg.id}"]
    key_name               = "${var.default_keypair_name}"
    
    associate_public_ip_address = true 

    tags {
      Owner           = "${var.owner}"
      Name            = "Cassandra-${count.index}"
      Datacenter      = "DC-${ceil(count.index/var.cassandra_servers)}"
    }
}

# Set cassandra seed according to the number of requested DCs (one in each DC)
data "template_file" "seeds" {
    count    = "${var.cassandra_dcs}"
    template = "${aws_instance.cassandra.*.private_ip[var.cassandra_servers * count.index]}"
}

# Prepare the cassandra.yaml file from template 
data "template_file" "cassandra_yaml" {
    count         = "${var.cassandra_servers * var.cassandra_dcs}"
    template      = "${file("${path.module}/files/cassandra.yaml")}"

    vars {
        cluster_name = "${var.cassandra_cluster}"
        seeds        = "${join(",", data.template_file.seeds.*.rendered)}"
        server_ip = "${aws_instance.cassandra.*.private_ip[count.index]}"
    }
}

# Prepare the rackdc file from template
data "template_file" "rackdc" {
    count         = "${var.cassandra_servers * var.cassandra_dcs}"
    template      = "${file("${path.module}/files/cassandra-rackdc.properties")}"
    vars {
        datacenter = "dc-${ceil(count.index/var.cassandra_servers)}"
    }
}

# Copy the prepared files to the cassandra servers
resource "null_resource" "copy_yaml" {
  count         = "${var.cassandra_servers * var.cassandra_dcs}"
    
  provisioner "file" {
    content = "${data.template_file.cassandra_yaml.*.rendered[count.index]}"
    destination = "/etc/cassandra/cassandra.yaml"
    connection {
      host = "${aws_instance.cassandra.*.public_ip[count.index]}"
      user = "${var.user}"
      type = "ssh"
      private_key = "${file("${path.module}/files/${var.default_keypair_name}.pem")}"
    }
  }  

  provisioner "file" {
    content = "${data.template_file.rackdc.*.rendered[count.index]}"
    destination = "/etc/cassandra/cassandra-rackdc.properties"
    connection {
      host = "${aws_instance.cassandra.*.public_ip[count.index]}"
      user = "${var.user}"
      type = "ssh"
      private_key = "${file("${path.module}/files/${var.default_keypair_name}.pem")}"
    }
  }  
}

resource "null_resource" "reset" {
  count         = "${var.cassandra_servers * var.cassandra_dcs}"

  provisioner "remote-exec" {
    inline = [
      "sudo systemctl stop cassandra",
      "sudo rm -rf /var/lib/cassandra/data/system/*",
      "sudo systemctl start cassandra"
    ]
    connection {
      host = "${aws_instance.cassandra.*.public_ip[count.index]}"
      user = "${var.user}"
      type = "ssh"
      private_key = "${file("${path.module}/files/${var.default_keypair_name}.pem")}"
    }
  }
  depends_on = ["null_resource.copy_yaml"]
}
