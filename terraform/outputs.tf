output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Public IP address"
  value       = aws_eip.web.public_ip
}

output "public_dns" {
  description = "Public DNS name"
  value       = aws_instance.web.public_dns
}

output "app_url" {
  description = "Application URL"
  value       = "http://${aws_eip.web.public_ip}:3000"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.hello_cicd.repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.hello_cicd.name
}

output "container_name" {
  description = "Name of the running application container"
  value       = var.project_name
}

output "app_port" {
  description = "Port the application container listens on"
  value       = var.app_port
}
