variable "region" {
  default = "us-west-2"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  default = "10.0.2.0/24"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "db_name" {
  default = "mydb"
}

variable "db_user" {
  default = "admin"
}

variable "db_password" {
  default = "password123"
}

variable "db_allocated_storage" {
  default = 20
}

variable "db_instance_class" {
  default = "db.t2.micro"
}
