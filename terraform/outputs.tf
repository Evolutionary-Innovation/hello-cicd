output "instance_id" {
  description = "EC2 instance ID (target of SSM Run Command)"
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Elastic IP address of the instance"
  value       = aws_eip.web.public_ip
}

output "app_url" {
  description = "Application URL"
  value       = "http://${aws_eip.web.public_ip}:${var.app_port}"
}

output "ecr_repository_url" {
  description = "ECR repository URL images are pushed to"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.app.name
}

output "container_name" {
  description = "Name of the running application container"
  value       = var.project_name
}

output "app_port" {
  description = "Host port the application is published on"
  value       = var.app_port
}
