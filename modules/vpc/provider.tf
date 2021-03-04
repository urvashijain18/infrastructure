provider "aws" {
    region = "${var.aws_region}"
}

resource "aws_vpc" "csye6225_vpc" {
    cidr_block       = "${var.aws_vpc_cidr_block}"
    instance_tenancy = "default"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        Name = "${var.aws_vpc_name}"
    }
}

data "aws_availability_zones" "available_zones" {
  state = "available"
}

resource "aws_subnet" "subnet1" {
  vpc_id     = "${aws_vpc.csye6225_vpc.id}"
  cidr_block = "${var.aws_subnet1_cidr}"
  availability_zone = data.aws_availability_zones.available_zones.names[0]
}

resource "aws_subnet" "subnet2" {
  vpc_id     = "${aws_vpc.csye6225_vpc.id}"
  cidr_block = "${var.aws_subnet2_cidr}"
  availability_zone = data.aws_availability_zones.available_zones.names[1]
}

resource "aws_subnet" "subnet3" {
  vpc_id     = "${aws_vpc.csye6225_vpc.id}"
  cidr_block = "${var.aws_subnet3_cidr}"
  availability_zone = data.aws_availability_zones.available_zones.names[2]
}

resource "aws_internet_gateway" "csye6225_internet_gateway" {
  vpc_id = "${aws_vpc.csye6225_vpc.id}"
}

resource "aws_route" "gateway_route" {
  route_table_id = aws_vpc.csye6225_vpc.main_route_table_id
  destination_cidr_block = "${var.aws_route_gateway_destination_cidr_block}"
  gateway_id = aws_internet_gateway.csye6225_internet_gateway.id
}

resource "aws_security_group" "application-security-group" {
  description = "Allow TCP traffic on ports 22, 80, 43, 3000"
  vpc_id      = "${aws_vpc.csye6225_vpc.id}"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

  ingress {
    description = "NODE SERVER"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Egress rule"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "application"
  }
}

resource "aws_security_group" "database-security-group" {
  description = "Allow TCP traffic on ports 3306 for mysql"
  vpc_id      = "${aws_vpc.csye6225_vpc.id}"

  ingress {
    description = "MYSQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups =  [aws_security_group.application-security-group.id]
  }

  tags = {
    Name = "database"
  }
}

resource "aws_kms_key" "encryption_key" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket" "s3-csye-6225" {
  bucket = "${var.aws_s3_bucket_name}"
  acl    = "private"
  force_destroy = true
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.encryption_key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
  versioning {
    enabled = true
  }
  lifecycle_rule{
    enabled = true
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds_subnet_group"
  subnet_ids = [aws_subnet.subnet1.id, aws_subnet.subnet2.id, aws_subnet.subnet3.id]
  tags = {
    Name = "RDS Subnet Group"
  }
}

resource "aws_db_instance" "rds_instance" {
  identifier = "${var.aws_db_identifier}"
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  name                 = "csye6225"
  username             = "csye6225"
  password             = "${var.aws_db_password}"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  multi_az = false
  publicly_accessible = false
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.database-security-group.id]
}

resource "aws_iam_policy" "IAM_policy" {
  name = "WebAppS3"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:*"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::var.aws_s3_bucket_name",
                "arn:aws:s3:::var.aws_s3_bucket_name/*"
            ]
        }
    ]
})
}

resource "aws_iam_role" "IAM_role" {
  name = "EC2-CSYE6225"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "IAM_policy_attachment" {
  role       = aws_iam_role.IAM_role.name
  policy_arn = aws_iam_policy.IAM_policy.arn
}

data "aws_ami" "ami" {
  owners           = ["${var.aws_ami_owner}"]
  most_recent = true
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = "${aws_iam_role.IAM_role.name}"
}

resource "aws_instance" "ec2instance" {
  ami = data.aws_ami.ami.id
  instance_type = "t2.micro"
  key_name = "csye6225"
  vpc_security_group_ids = [aws_security_group.application-security-group.id]
  subnet_id = "${aws_subnet.subnet1.id}"
  associate_public_ip_address = true
  root_block_device {
      volume_type = "gp2"
      volume_size = 20
      delete_on_termination = true
  }
  depends_on = [aws_db_instance.rds_instance]
  iam_instance_profile = "${aws_iam_instance_profile.ec2_profile.name}"
  user_data = <<-EOF
         #!/bin/bash
         echo "export aws_region=${var.aws_region}">> /home/ubuntu/.bashrc
         echo "export s3_bucket_name=${var.aws_s3_bucket_name}">> /home/ubuntu/.bashrc
         echo "export db_instance_username=${aws_db_instance.rds_instance.username}">> /home/ubuntu/.bashrc
         echo "export db_instance_password=${var.aws_db_password}">> /home/ubuntu/.bashrc
         echo "export ami_id=${data.aws_ami.ami.id}">> /home/ubuntu/.bashrc
         echo "export db_instance_name=${var.aws_db_identifier}">> /home/ubuntu/.bashrc
         echo "export db_instance_hostname=${aws_db_instance.rds_instance.address}">> /home/ubuntu/.bashrc
         echo "export AWS_ACCESS_KEY_ID=${var.aws_access_key_id}">> /home/ubuntu/.bashrc
         echo "export AWS_SECRET_ACCESS_KEY=${var.aws_secret_key_id}">> /home/ubuntu/.bashrc
     EOF
}
