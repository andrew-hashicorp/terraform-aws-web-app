output "app_url" {
  description = "The URL of your application."
  value       = "http://${aws_instance.app.public_dns}"
}

output "db_endpoint" {
  description = "The RDS endpoint (for debugging)."
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}
