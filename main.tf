# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
}

#vpc
resource "aws_vpc" "myvpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "myvpc"
  }
}


#internet gateway
resource "aws_internet_gateway" "myigw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "myigw"
  }
}

#route-table
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myigw.id
  }


  tags = {
    Name = "my_route_table"
  }
}

#subnet
resource "aws_subnet" "mysubnet" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "mysubnet"
  }
}

#subnet association
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.mysubnet.id
  route_table_id = aws_route_table.my_route_table.id
}

#security group 
resource "aws_security_group" "my_sg" {
  name        = "my_sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
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
    description = "jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "FOR SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my_sg"
  }
}

#network interface
resource "aws_network_interface" "my_network_interface" {
  subnet_id       = aws_subnet.mysubnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.my_sg.id]
}

#elastic IP
resource "aws_eip" "my_eip" {
  vpc                       = true
  network_interface         = aws_network_interface.my_network_interface.id
  associate_with_private_ip = "10.0.1.50"
}

#print public Ip
output "public_ip" {
  value = aws_eip.my_eip.public_ip
}

#creating instance 

resource "aws_instance" "web-server-instance" {
  ami               = "ami-00bf4ae5a7909786c"
  instance_type     = "t2.micro"
  availability_zone = "ap-south-1a"
  key_name          = "aks"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.my_network_interface.id
  }

  user_data = file("userdata-new.sh")
  tags = {
    Name = "web-server"
  }
}

#print private ip and instance id
output "server_private_ip" {
  value = aws_instance.web-server-instance.private_ip

}

output "server_id" {
  value = aws_instance.web-server-instance.id
}
