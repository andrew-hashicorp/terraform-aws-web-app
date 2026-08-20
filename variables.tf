variable "app_name" {
  type        = string
  description = "A unique name for your application. Used to name all AWS resources."
}

variable "docker_image" {
  type        = string
  description = "The Docker image to run. e.g. myorg/notes-api:1.0"
}

variable "db_name" {
  type        = string
  description = "The name of the database to create."
  default     = "notes"
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-west-2"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type."
  default     = "t3.micro"
}
