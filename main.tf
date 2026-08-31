provider "aws" {
  region = var.aws_region
}

# Random password for the database — Terraform generates this, never hardcoded
resource "random_password" "db" {
  length  = 16
  special = false
}

# Security group for EC2 — allows HTTP traffic from the internet
resource "aws_security_group" "app" {
  name        = "${var.app_name}-app"
  description = "Allow HTTP traffic to the app"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["18.237.140.160/29"]  # EC2 Instance Connect us-west-2
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security group for RDS — only allows traffic from the EC2 security group
resource "aws_security_group" "db" {
  name        = "${var.app_name}-db"
  description = "Allow Postgres traffic from app only"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
}

# RDS PostgreSQL instance
resource "aws_db_instance" "main" {
  identifier          = var.app_name
  engine              = "postgres"
  engine_version      = "15"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  db_name             = var.db_name
  username            = "appuser"
  password            = random_password.db.result
  skip_final_snapshot = true

  vpc_security_group_ids = [aws_security_group.db.id]

  tags = {
    Name = var.app_name
  }
}

# HashiCorp approved Ubuntu 24.04 base AMI (includes Uptycs EDR agent)
data "aws_ami" "hc_base" {
  filter {
    name   = "name"
    values = ["hc-base-ubuntu-2404-amd64-*"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
  most_recent = true
  owners      = ["888995627335"]
}

# EC2 instance — installs Docker and runs your container on startup
resource "aws_instance" "app" {
  ami                         = data.aws_ami.hc_base.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.app.name
  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io awscli
    systemctl start docker
    systemctl enable docker

    S3_BUCKET=$(aws secretsmanager get-secret-value \
      --region ${var.aws_region} \
      --secret-id "/${var.app_name}/s3_bucket_name" \
      --query SecretString --output text 2>/dev/null || echo "")

    docker run -d \
      -p 80:3000 \
      -e DATABASE_URL="postgresql://appuser:${random_password.db.result}@${aws_db_instance.main.endpoint}/${var.db_name}" \
      -e PGSSLMODE=require \
      -e NODE_TLS_REJECT_UNAUTHORIZED=0 \
      -e S3_BUCKET_NAME="$S3_BUCKET" \
      -e AWS_REGION="${var.aws_region}" \
      -e PORT=3000 \
      --restart always \
      ${var.docker_image}
  EOF
  tags = {
    Name = var.app_name
  }
}

resource "aws_iam_role" "app" {
  name = "${var.app_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "app" {
  name = "${var.app_name}-policy"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:/${var.app_name}/*"
    }]
   })
 }

resource "aws_iam_instance_profile" "app" {
 name = "${var.app_name}-profile"
 role = aws_iam_role.app.name
}

