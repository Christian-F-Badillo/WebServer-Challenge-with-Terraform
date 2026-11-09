# Configuración de Proveedor de AWS
provider "aws" {
  region = var.region
}

#------------- VPC ----------------------------------------------------------------------
resource "aws_vpc" "vpc_web_server" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "VPC Web Server"
  }
}

#------------- VPC Subnetting -------------------------------------------------------------
resource "aws_subnet" "public_subnet_web_server" {
  vpc_id = aws_vpc.vpc_web_server.id
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "Public Subnet"
  }
}


#------------- VPC IGW ----------------------------------------------------------------------
resource "aws_internet_gateway" "igw_web_server" {
  vpc_id = aws_vpc.vpc_web_server.id

  tags = {
    Name = "IGW Web Server"
  }
}

#------------- VPC Route Table ----------------------------------------------------------------
resource "aws_route_table" "rt_web_server" {
  vpc_id = aws_vpc.vpc_web_server.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_web_server.id
  }

  tags = {
    Name = "RT Web Server"
  }
}

# Asociar la RT con la Subred Pública
resource "aws_route_table_association" "rta_public" {
  subnet_id      = aws_subnet.public_subnet_web_server.id
  route_table_id = aws_route_table.rt_web_server.id
}


#------------- Security Group -----------------------------------------------------------

resource "aws_security_group" "allow_http_ssh" {
  name = "allow_http_ssh"
  description = "Allows HTTP and SSH inbound trafic and all outbound trafic"
  vpc_id = aws_vpc.vpc_web_server.id

  tags = {
    Name = "Web Server"
  }
}

# Add inbound rule HTTP
resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.allow_http_ssh.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 80
  to_port = 80
  ip_protocol = "tcp"
}

# Add inbound rule SSH
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4" {
  security_group_id = aws_security_group.allow_http_ssh.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 22
  to_port = 22
  ip_protocol = "tcp"
}

# Add outbound rule for all trafic
resource "aws_vpc_security_group_egress_rule" "allow_all_trafic_ipv4" {
  security_group_id = aws_security_group.allow_http_ssh.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "-1"
}

#------------- Key Pair Gen -------------------------------------------------------------

## Creamos nuestra clave privada localmente
resource "tls_private_key" "lab_key" {
  algorithm = "RSA"
  rsa_bits = 4096
}

## Registramos la clave en AWS
resource "aws_key_pair" "lab_kp" {
  key_name = "Web Server KP"
  public_key = tls_private_key.lab_key.public_key_openssh

  tags = {
    Name = "Web Server KP"
  }
}

## Creamos el .pem
resource "local_file" "ssh_key" {
  content = tls_private_key.lab_key.private_key_pem
  filename = "${path.module}/labsuser.pem"
  file_permission = "0400"
}

#------------- EC2 ----------------------------------------------------------------------

resource "aws_instance" "web_server" {
  ami = data.aws_ami.al2023.id

  instance_type = var.instance_type_ec2
  
  associate_public_ip_address = true
  
  key_name = aws_key_pair.lab_kp.key_name
  
  vpc_security_group_ids = [aws_security_group.allow_http_ssh.id]
  subnet_id = aws_subnet.public_subnet_web_server.id
  
  user_data = file("${path.module}/userdata.txt")

  tags = {
    Name = "Web Server"
  }
}

## Obtener IP pública en archivo txt
resource "local_file" "save_public_ip" {
  content  = aws_instance.web_server.public_ip
  filename = "${path.module}/public_ip.txt"
}

#----------------------------------------------------------------------------------------
#------------- Data Block ---------------------------------------------------------------
#----------------------------------------------------------------------------------------

#------------- AMI ----------------------------------------------------------------------

data "aws_ami" "al2023" {
  most_recent = true
  owners = [ "amazon" ]

  filter {
    name = "name"
    values = [ "al2023-ami-2023.*-x86_64" ]
  }
}