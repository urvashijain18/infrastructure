variable "aws_region" {
    default = "us-east-1"
}

variable "aws_vpc_name" {
    default = "csye6225"
}

variable "aws_vpc_cidr_block" {
    default = "190.160.0.0/16"
}

variable "aws_subnet1_cidr"{
  default = "190.160.1.0/24"
}

variable "aws_subnet2_cidr"{
  default = "190.160.2.0/24"
}

variable "aws_subnet3_cidr"{
  default = "190.160.3.0/24"
}

variable "aws_route_gateway_destination_cidr_block"{
  default = "0.0.0.0/0"
}

variable "aws_s3_bucket_name"{
  default = "webapp.urvashi.jain"
}

variable "aws_db_identifier"{
  default = "csye6225"
}

variable "aws_db_password"{
  default = "Password123"
}

variable "aws_ami_owner"{
  default = "655716329164"
}

variable "aws_access_key_id"{

}

variable "aws_secret_key_id"{

}
