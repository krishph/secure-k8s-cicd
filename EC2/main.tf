# //////////////////////////////
# BACKEND
# //////////////////////////////
terraform {
  backend "s3" {
  }
}

# //////////////////////////////
# VARIABLES
# //////////////////////////////
variable "aws_access_key" {}

variable "aws_secret_key" {}

variable "region" {
  default = "us-east-1"
}

# //////////////////////////////
# PROVIDERS
# //////////////////////////////
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}


# //////////////////////////////
# RESOURCES
# //////////////////////////////
# SECURITY_GROUP
resource "aws_security_group" "my-sg-grp" {
  name = "ikrish-tf-sg-ec2"
  vpc_id = var.vpc_id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# INSTANCE
resource "aws_instance" "myec2" {
  ami = data.aws_ami.aws-linux.id
  instance_type = "t2.micro"
  subnet_id = values(data.aws_subnet.example)[1].id
  vpc_security_group_ids = [aws_security_group.my-sg-grp.id]
  key_name               = var.ssh_key_name

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file(var.private_key_path)
  }

  tags = {
    "Name" = "ikrish-tf-ec2-myec2"
  }    
}

# //////////////////////////////
# DATA
# //////////////////////////////
data "aws_vpcs" "vpcs" {}

data "aws_vpc" "allvpcs" {
  count = length(data.aws_vpcs.vpcs.ids)
  id    = tolist(data.aws_vpcs.vpcs.ids)[count.index]
}

#From vpcs id's fetched, use first vpc, assuming there will be only one vpc
data "aws_subnets" "example" {
  filter{
     name = "vpc-id"
     values = [tolist(data.aws_vpcs.vpcs.ids)[0]]
  }
  filter{
    name = "map-public-ip-on-launch"
    values = [true]
  }
}

data "aws_subnet" "example" {
  for_each = toset(data.aws_subnets.example.ids)
  id       = each.value
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "aws-linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
# //////////////////////////////
# OUTPUT
# //////////////////////////////

output "instance-dns" {
  value = aws_instance.myec2.public_dns
}

