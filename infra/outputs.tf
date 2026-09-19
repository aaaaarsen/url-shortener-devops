output "public_ip" {
  description = "Public IP address of the provisioned VM"
  value       = aws_instance.app.public_ip
}

output "instance_id" {
  description = "AWS instance ID"
  value       = aws_instance.app.id
}
