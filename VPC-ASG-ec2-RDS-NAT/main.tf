
# VPC AND SUbnets
# Define the AWS provider and region
provider "aws" {
  region = var.region
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr # CIDR block for the VPC
}

# Create a public subnet
resource "aws_subnet" "public" {
  vpc_id                   = aws_vpc.main.id # VPC ID
  cidr_block               = var.public_subnet_cidr # CIDR block for the public subnet
  map_public_ip_on_launch  = true # Automatically assign a public IP to instances
}

# Create a private subnet
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id # VPC ID
  cidr_block = var.private_subnet_cidr # CIDR block for the private subnet
}

# Create an Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id # VPC ID
}

# Create a public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id # VPC ID

  # Define a route for internet access
  route {
    cidr_block = "0.0.0.0/0" # Route for all traffic
    gateway_id = aws_internet_gateway.main.id # Internet Gateway ID
  }
}

# Associate the public subnet with the public route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id # Public subnet ID
  route_table_id = aws_route_table.public.id # Public route table ID
}

# Allocate an Elastic IP for the NAT Gateway
resource "aws_eip" "nat" {
  vpc = true # Allocate the EIP in the VPC
}

# Create a NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id # EIP allocation ID
  subnet_id     = aws_subnet.public.id # Public subnet ID for the NAT Gateway
}

# Create a private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id # VPC ID

  # Define a route for internet access via the NAT Gateway
  route {
    cidr_block     = "0.0.0.0/0" # Route for all traffic
    nat_gateway_id = aws_nat_gateway.main.id # NAT Gateway ID
  }
}

# Associate the private subnet with the private route table
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id # Private subnet ID
  route_table_id = aws_route_table.private.id # Private route table ID
}


#  Sec Groups
# Create a security group for the web servers
resource "aws_security_group" "web" {
  vpc_id = aws_vpc.main.id # VPC ID

  # Allow inbound HTTP traffic from anywhere
  ingress {
    from_port   = 80 # HTTP port
    to_port     = 80 # HTTP port
    protocol    = "tcp" # TCP protocol
    cidr_blocks = ["0.0.0.0/0"] # Anywhere
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0 # All ports
    to_port     = 0 # All ports
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"] # Anywhere
  }
}

# Create a security group for the RDS database
resource "aws_security_group" "db" {
  vpc_id = aws_vpc.main.id # VPC ID

  # Allow inbound MySQL traffic from the web security group
  ingress {
    from_port       = 3306 # MySQL port
    to_port         = 3306 # MySQL port
    protocol        = "tcp" # TCP protocol
    security_groups = [aws_security_group.web.id] # Web security group
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0 # All ports
    to_port     = 0 # All ports
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"] # Anywhere
  }
}


#  EC2 and Load Balancers

# Create a launch template for the web servers
resource "aws_launch_template" "web" {
  name_prefix   = "web-template" # Template name prefix
  image_id      = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI ID
  instance_type = var.instance_type # Instance type

  # Configure network interfaces
  network_interfaces {
    associate_public_ip_address = true # Assign a public IP
    security_groups             = [aws_security_group.web.id] # Security group
  }

  # User data script to install and start NGINX
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install -y nginx1.12
              systemctl start nginx
              systemctl enable nginx
              EOF
}

# Create an Auto Scaling Group for the web servers
resource "aws_autoscaling_group" "web" {
  desired_capacity     = 2 # Desired number of instances
  max_size             = 2 # Maximum number of instances
  min_size             = 1 # Minimum number of instances
  launch_template {
    id      = aws_launch_template.web.id # Launch template ID
    version = "$Latest" # Use the latest version
  }
  vpc_zone_identifier = [aws_subnet.public.id] # Subnet IDs
  health_check_type   = "EC2" # Health check type
}

# Create an Application Load Balancer
resource "aws_lb" "main" {
  name               = "main-lb" # Load balancer name
  internal           = false # Public load balancer
  load_balancer_type = "application" # Load balancer type
  security_groups    = [aws_security_group.web.id] # Security group
  subnets            = [aws_subnet.public.id] # Subnet IDs
}

# Create a target group for the web servers
resource "aws_lb_target_group" "web" {
  name     = "web-tg" # Target group name
  port     = 80 # HTTP port
  protocol = "HTTP" # Protocol
  vpc_id   = aws_vpc.main.id # VPC ID
}

# Create a listener for the load balancer
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.main.arn # Load balancer ARN
  port              = 80 # HTTP port
  protocol          = "HTTP" # Protocol

  # Default action to forward requests to the target group
  default_action {
    type             = "forward" # Action type
    target_group_arn = aws_lb_target_group.web.arn # Target group ARN
  }
}

# Attach the Auto Scaling Group to the target group
resource "aws_autoscaling_attachment" "asg_lb" {
  autoscaling_group_name = aws_autoscaling_group.web.name # Auto Scaling Group name
  lb_target_group_arn    = aws_lb_target_group.web.arn # Target group ARN
}


#  RDS Instance


# Create a subnet group for the RDS database
resource "aws_db_subnet_group" "main" {
  name       = "main" # Subnet group name
  subnet_ids = [aws_subnet.private.id] # Subnet IDs

  tags = {
    Name = "main" # Tag
  }
}

# Create an RDS MySQL instance
resource "aws_db_instance" "main" {
  allocated_storage    = var.db_allocated_storage # Storage in GB
  engine               = "mysql" # Database engine
  instance_class       = var.db_instance_class # Instance type
  identifier                 = var.db_name # Database name
  username             = var.db_user # Username
  password             = var.db_password # Password
  db_subnet_group_name = aws_db_subnet_group.main.name # Subnet group name
  vpc_security_group_ids = [aws_security_group.db.id] # Security group IDs
  skip_final_snapshot = true # Skip final snapshot on deletion
}


#  Outpusts

# Output the VPC ID
output "vpc_id" {
  value = aws_vpc.main.id
}

# Output the public subnet ID
output "public_subnet_id" {
  value = aws_subnet.public.id
}

# Output the private subnet ID
output "private_subnet_id" {
  value = aws_subnet.private.id
}

# Output the Load Balancer DNS name
output "load_balancer_dns" {
  value = aws_lb.main.dns_name
}
