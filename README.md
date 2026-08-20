# terraform-aws-web-app

A Terraform module for running a containerised web app with a PostgreSQL
database on AWS. Provisions an EC2 instance, RDS PostgreSQL, and security groups.

## Usage

| Variable | Description |
|---|---|
| `app_name` | Unique name for your app and AWS resources |
| `docker_image` | Docker image to run, e.g. `myorg/notes-api:1.0` |
| `db_name` | Database name (default: `notes`) |
| `instance_type` | EC2 size (default: `t3.micro`) |
| `aws_region` | AWS region (default: `us-west-2`) |

## Outputs

| Output | Description |
|---|---|
| `app_url` | Public URL of your application |
| `db_endpoint` | RDS endpoint (sensitive) |
