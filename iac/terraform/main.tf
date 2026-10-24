# ─── Amazon Linux 2023 EC2 Instance ───────────────────────
# Terraform configuration for launching AL2023 with
# dynamic AMI resolution via SSM Parameter Store

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─── Variables ────────────────────────────────────────────

variable "aws_region" {
  description = "AWS Region to deploy into"
  default     = "us-east-2"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "al_version" {
  description = "Amazon Linux version: al2023 or al2027"
  default     = "al2023"

  validation {
    condition     = contains(["al2023", "al2027"], var.al_version)
    error_message = "al_version must be 'al2023' or 'al2027'."
  }
}

variable "arch" {
  description = "Architecture: x86_64 or arm64"
  default     = "x86_64"

  validation {
    condition     = contains(["x86_64", "arm64"], var.arch)
    error_message = "arch must be 'x86_64' or 'arm64'."
  }
}

variable "ami_type" {
  description = "AMI type: standard or minimal"
  default     = "standard"

  validation {
    condition     = contains(["standard", "minimal"], var.ami_type)
    error_message = "ami_type must be 'standard' or 'minimal'."
  }
}

variable "volume_size" {
  description = "Root volume size in GB"
  default     = 30
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ─── Locals ───────────────────────────────────────────────

locals {
  # Construct the SSM parameter name for AMI lookup
  ami_prefix = var.ami_type == "minimal" ? "${var.al_version}-ami-minimal-kernel-default" : "${var.al_version}-ami-kernel-default"
  ssm_path   = "/aws/service/ami-amazon-linux-latest/${local.ami_prefix}-${var.arch}"

  # Instance type mapping for ARM
  instance_type = var.arch == "arm64" ? replace(var.instance_type, "t3", "t4g") : var.instance_type

  common_tags = {
    Project     = "Amazon-Linux-Hub"
    OS          = "Amazon Linux ${var.al_version == "al2023" ? "2023" : "2027"}"
    ManagedBy   = "Terraform"
    Environment = "development"
  }
}

# ─── Data Sources ─────────────────────────────────────────

data "aws_ssm_parameter" "ami" {
  name = local.ssm_path
}

data "aws_vpc" "default" {
  default = true
}

# ─── Security Group ──────────────────────────────────────

resource "aws_security_group" "al_instance" {
  name_prefix = "${var.al_version}-"
  description = "Security group for ${var.al_version} instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.al_version}-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ─── EC2 Instance ─────────────────────────────────────────

resource "aws_instance" "al_instance" {
  ami                    = data.aws_ssm_parameter.ami.value
  instance_type          = local.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.al_instance.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.volume_size
    encrypted             = true
    delete_on_termination = true

    tags = merge(local.common_tags, {
      Name = "${var.al_version}-root-vol"
    })
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2
    http_put_response_hop_limit = 2
  }

  user_data = <<-EOF
    #!/bin/bash
    echo "Amazon Linux instance initialized at $(date)" > /var/log/init.log
    
    # Install common tools
    dnf install -y htop tree jq aws-cli-2 2>/dev/null || true
  EOF

  tags = merge(local.common_tags, {
    Name = "${var.al_version}-instance"
  })
}

# ─── Outputs ──────────────────────────────────────────────

output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.al_instance.id
}

output "public_ip" {
  description = "Public IP address"
  value       = aws_instance.al_instance.public_ip
}

output "ami_id" {
  description = "AMI ID used"
  value       = data.aws_ssm_parameter.ami.value
}

output "ami_ssm_path" {
  description = "SSM Parameter path for AMI lookup"
  value       = local.ssm_path
}

output "ssh_command" {
  description = "SSH connection command"
  value       = "ssh ec2-user@${aws_instance.al_instance.public_ip}"
}
