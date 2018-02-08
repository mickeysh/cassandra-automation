output "cassandra_server_public_ip" {
  value = "${join(",", aws_instance.cassandra.*.public_ip)}"
}

output "cassandra_server_private_ip" {
  value = "${join(",", aws_instance.cassandra.*.private_ip)}"
}

output "cassandra_seeds" {
  value = "${join(",", data.template_file.seeds.*.rendered)}"
}