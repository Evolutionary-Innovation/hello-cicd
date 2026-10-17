output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Public IP address"
  value       = aws_instance.web.public_ip
}

output "public_dns" {
  description = "Public DNS name"
  value       = aws_instance.web.public_dns
}

output "app_url" {
  description = "Application URL"
  value       = "http://${aws_instance.web.public_ip}:3000"
}
