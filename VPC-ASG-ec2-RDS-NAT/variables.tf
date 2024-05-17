# Define variables used in the configuration
variable "region" {
  default = "us-west-2" # AWS region
}

variable "vpc_cidr" {
  default = "10.0.0.0/16" # CIDR block for the VPC
}

variable "public_subnet_cidr" {
  default = "10.0.1.0/24" # CIDR block for the public subnet
}

variable "private_subnet_cidr" {
  default = "10.0.2.0/24" # CIDR block for the private subnet
}

variable "instance_type" {
  default = "t2.micro" # EC2 instance type
}

variable "db_name" {
  default = "mydb" # RDS database name
}

variable "db_user" {
  default = "admin" # RDS database username
}

variable "db_password" {
  default = "password123" # RDS database password
}

variable "db_allocated_storage" {
  default = 20 # RDS database storage in GB
}

variable "db_instance_class" {
  default = "db.t2.micro" # RDS instance type
}
