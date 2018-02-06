
# Get Ubuntu AMI information 
data "aws_ami" "cassandra" {
    most_recent = true
    filter {
        name   = "name"
        values = ["cassandra-*"]
    }
    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }
    filter {
        name   = "tag:Owner"
        values = ["Opsschool"]
    }
    filter {
        name   = "tag:Name"
        values = ["Cassandra"] 
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
    count         = "${var.cassandra_servers}"
    ami           = "${data.aws_ami.cassandra.id}"
    instance_type = "${var.instance_type}"

    subnet_id              = "${element(data.aws_subnet_ids.subnets.ids, count.index)}"
    vpc_security_group_ids = ["${aws_security_group.cassandra_sg.id}"]
    key_name               = "${var.default_keypair_name}"
    
    associate_public_ip_address = true 

    tags {
      Owner           = "${var.owner}"
      Name            = "Cassandra-${count.index}"
    }
}

data "template_file" "cassandra_yaml" {
    count         = "${var.cassandra_servers}"
    template      = "${file("${path.module}/files/cassandra.yaml")}"
    vars {
        cluster_name = "${var.cassandra_cluster}"
        seeds        = "${join(",", aws_instance.cassandra.*.private_ip)}"
        server_ip = "${aws_instance.cassandra.*.private_ip[count.index]}"
    }
}

resource "null_resource" "copy_yaml" {
  count         = "${var.cassandra_servers}"
    
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
}

resource "null_resource" "bootstrap" {
  count         = "${var.cassandra_servers}"
  depends_on = ["null_resource.copy_yaml"]
  
  provisioner "remote-exec" {
    inline = [
      "sudo systemctl stop cassandra",
      "sudo rm -rf /var/lib/cassandra/data/system/*",
      "sudo systemctl start cassandra"
    ]
    connection {
      host = "${aws_instance.cassandra.*.public_ip[count.index]}"
      user = "${var.user}"
      private_key = "${file("${path.module}/files/${var.default_keypair_name}.pem")}"
    }
  }
}

output "cassandra_server_public_ip" {
  value = "${join(",", aws_instance.cassandra.*.public_ip)}"
}