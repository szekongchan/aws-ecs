resource "aws_vpc" "main" {
  cidr_block = "172.168.0.0/16"

  tags = {
    Name = "sk-ecs-vpc"
  }
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "172.168.18.0/24"
  tags = {
    Name = "sk-ecs-subnet"
  }
}

resource "aws_security_group" "main" {
  name        = "sk-ecs-sg"
  description = "Security group for SK ECS"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "sk-ecs-sg"
  }
}

resource "aws_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.main.id
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
}

resource "aws_igw" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "sk-ecs-igw"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_igw.main.id
  }

  route {
    cidr_block = "172.168.0.0/16"
    gateway_id = "local"
  }

  tags = {
    Name = "sk-ecs-route-table"
  }
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}
