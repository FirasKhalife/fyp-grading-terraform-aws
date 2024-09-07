terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

#private IP addresses for internal communication
locals {
  subnet_cidr_block = "172.31.64.0/24"

  registry-ip = "172.31.64.100"
  gateway-ip  = "172.31.64.101"
  rabbit-ip   = "172.31.64.102"
  redis-ip    = "172.31.64.103"

  admin-ip        = "172.31.64.104"
  evaluation-ip   = "172.31.64.105"
  rubrics-ip      = "172.31.64.106"
  notification-ip = "172.31.64.107"
  frontend-ip     = "172.31.64.108"
}

#Main VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = local.subnet_cidr_block
  enable_dns_hostnames = "true"
  enable_dns_support   = "true"

  tags = {
    Name = "main_vpc"
  }
}

#Main Subnet
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = local.subnet_cidr_block
  availability_zone = "us-east-1d"

  map_public_ip_on_launch = true

  tags = {
    Name = "main_subnet"
  }

  depends_on = [aws_internet_gateway.gw]
}

#An internet gateway, necessary to associate an Elastic IP to the Frontend Server and API Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main_vpc.id
}

#Assigning a public IP to the Frontend server
resource "aws_eip" "frontend_eip" {
  domain                    = "vpc"
  instance                  = aws_instance.api-gateway.id
  associate_with_private_ip = local.frontend-ip

  depends_on = [
    aws_internet_gateway.gw
  ]
}

#Assigning a public IP to the API Gateway
resource "aws_eip" "gateway_eip" {
  domain                    = "vpc"
  instance                  = aws_instance.api-gateway.id
  associate_with_private_ip = local.gateway-ip

  depends_on = [
    aws_internet_gateway.gw
  ]
}

#Security group for most of Backend internal services
resource "aws_security_group" "backend_group" {
  name        = "Backend group"
  description = "Security rules for most of the backend services"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description = "Spring services Inbound"
    from_port   = 8080
    to_port     = 8090
    protocol    = "tcp"
    cidr_blocks = ["172.31.64.0/24"]
  }

  ingress {
    description = "Eureka Registry Inbound"
    from_port   = 8761
    to_port     = 8761
    protocol    = "tcp"
    cidr_blocks = ["172.31.64.0/24"]
  }

  ingress {
    description = "RabbitMQ Inbound"
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = ["172.31.64.0/24"]
  }

  ingress {
    description = "Redis Inbound"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["172.31.64.0/24"]
  }

  egress {
    description = "Spring services Outbound"
    from_port   = 8080
    to_port     = 8090
    protocol    = "tcp"
    cidr_blocks = ["172.31.64.0/24"]
  }

  egress {
    description = "Eureka Registry Outbound"
    from_port   = 8761
    to_port     = 8761
    protocol    = "tcp"
    cidr_blocks = ["172.31.64.0/24"]
  }

  egress {
    description = "RabbitMQ Outbound"
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = ["172.31.64.0/24"]
  }

  egress {
    description = "Redis Outbound"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["172.31.64.0/24"]
  }

  tags = {
    Name = "backend_group"
  }
}

#Security group for the API Gateway
resource "aws_security_group" "gateway_group" {
  name        = "Gateway group"
  description = "Security rules for the API Gateway"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description      = "Inbound Traffic"
    from_port        = 9191
    to_port          = 9191
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    description      = "Permitted Outbound"
    from_port        = 9191
    to_port          = 9191
    protocol         = "tcp"
    cidr_blocks      = [local.frontend-ip, "172.31.64.0/24"]
  }

  tags = {
    Name = "gateway_group"
  }
}

#Security group for the Frontend service
resource "aws_security_group" "frontend_group" {
  name        = "Frontend group"
  description = "Security rules for the Frontend service"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description      = "Inbound Traffic"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description      = "Outbound Traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "frontend_group"
  }
}

#Security rules for services containing a listener to DockerHub Webhook, proxy sent by the gateway
resource "aws_security_group" "webhook_listener_group" {
  name        = "Webhook Listener group"
  description = "Security rules for services containing a listener to DockerHub Webhook"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description = "Inbound Traffic"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["${local.gateway-ip}/32"]
  }

  egress {
    description = "Outbound Traffic"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["${local.gateway-ip}/32"]
  }

  tags = {
    Name = "webhook_listener_group"
  }
}

#Security rules to allow SSH connections
resource "aws_security_group" "ssh_group" {
  name        = "SSH group"
  description = "Security rules to allow SSH connections"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description      = "Inbound Traffic"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description      = "Outbound Traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "ssh_group"
  }
}

resource "aws_key_pair" "ssh_key_pair" {
  key_name   = "ssh_key"
  public_key = ""
}

resource "aws_instance" "frontend" {
  ami           = "ami-0a887e401f7654935"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main_subnet.id

  key_name = "ssh_key"

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y docker
    sudo service docker start

    sudo docker run -p 80:80 \
    --name frontend firas29/frontend
  EOF

  private_ip = local.frontend-ip

  vpc_security_group_ids = [
    aws_security_group.frontend_group.id,
    aws_security_group.webhook_listener_group.id,
    aws_security_group.ssh_group.id
  ]

  tags = {
    Name = "Frontend"
  }

  depends_on = [
    aws_key_pair.ssh_key_pair,
    aws_security_group.frontend_group,
    aws_security_group.webhook_listener_group,
    aws_security_group.ssh_group
  ]

}

resource "aws_instance" "rabbitmq" {
  ami           = "ami-0a887e401f7654935"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main_subnet.id

  key_name = "ssh_key"

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y docker
    sudo service docker start

    sudo docker run \
    -e RABBITMQ_DEFAULT_USER=admin \
    -e RABBITMQ_DEFAULT_PASS=admin \
    -p 5672:5672 -p 15672:15672 \
    --name rabbitmq rabbitmq
  EOF

  private_ip = local.rabbit-ip

  vpc_security_group_ids = [
    aws_security_group.backend_group.id,
    aws_security_group.ssh_group.id
  ]

  tags = {
    Name = "RabbitMQ"
  }

  depends_on = [
    aws_key_pair.ssh_key_pair,
    aws_security_group.backend_group,
    aws_security_group.ssh_group
  ]

}

resource "aws_instance" "redis" {
  ami           = "ami-0a887e401f7654935"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main_subnet.id

  key_name = "ssh_key"

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y docker
    sudo service docker start

    sudo docker run -p 6379:6379 redis
  EOF

  private_ip = local.redis-ip

  vpc_security_group_ids = [
    aws_security_group.backend_group.id,
    aws_security_group.ssh_group.id
  ]

  tags = {
    Name = "Redis"
  }

  depends_on = [
    aws_key_pair.ssh_key_pair,
    aws_security_group.backend_group,
    aws_security_group.ssh_group
  ]

}

resource "aws_instance" "registry-service" {
  ami           = "ami-0a887e401f7654935"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main_subnet.id

  key_name = "ssh_key"

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y docker
    sudo service docker start

    sudo docker run -p 8761:8761 firas29/registry-service
  EOF

  private_ip = local.registry-ip

  vpc_security_group_ids = [
    aws_security_group.backend_group.id,
    aws_security_group.webhook_listener_group.id,
    aws_security_group.ssh_group.id
  ]

  tags = {
    Name = "Registry Service"
  }

  depends_on = [
    aws_key_pair.ssh_key_pair,
    aws_security_group.backend_group,
    aws_security_group.webhook_listener_group,
    aws_security_group.ssh_group
  ]

}

resource "aws_instance" "api-gateway" {
  ami           = "ami-0a887e401f7654935"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main_subnet.id

  key_name = "ssh_key"

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y docker
    sudo service docker start

    sudo docker run \
    -e app.services.address.admin=http://${local.admin-ip} \
    -e app.services.address.evaluation=http://${local.evaluation-ip} \
    -e app.services.address.rubrics=http://${local.rubrics-ip} \
    -e app.services.address.notification=http://${local.notification-ip} \
    -e app.services.address.registry=http://${local.registry-ip} \
    -e app.services.address.frontend=http://${local.frontend-ip} \
    -e registry.client.serviceUrl.defaultZone=http://${local.registry-ip}:8761/registry/ \
    -e spring.data.redis.host=${local.redis-ip} \
    -p 9191:9191 \
    --name api-gateway firas29/api-gateway
  EOF

  private_ip = local.gateway-ip

  vpc_security_group_ids = [
    aws_security_group.gateway_group.id,
    aws_security_group.ssh_group.id
  ]

  tags = {
    Name = "API Gateway"
  }

  depends_on = [
    aws_key_pair.ssh_key_pair,
    aws_security_group.gateway_group,
    aws_instance.registry-service,
    aws_instance.redis,
    aws_security_group.ssh_group
  ]
}

resource "aws_instance" "admin-service" {
  ami           = "ami-0a887e401f7654935"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main_subnet.id

  key_name = "ssh_key"

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y docker
    sudo service docker start

    sudo docker network create admin-network

    sudo docker run \
    --network=admin-network \
    -e POSTGRES_DB=admin-db \
    -e POSTGRES_USER=admin \
    -e POSTGRES_PASSWORD=admin \
    -p 5432:5432
    --name postgres-admin postgres

    sudo docker run \
    --network=admin-network \
    -e spring.datasource.url= jdbc:postgresql://postgres-admin:5432/admin-db \
    -e registry.client.serviceUrl.defaultZone=http://${local.registry-ip}:8761/registry/ \
    -e spring.rabbitmq.host=${local.rabbit-ip} \
    -e spring.data.redis.host=${local.redis-ip} \
    -e SERVER_PORT=8080 \
    -p 8080:8080 \
    --name admin-service1 firas29/admin-service

    sudo docker run \
    --network=admin-network \
    -e spring.datasource.url= jdbc:postgresql://postgres-admin:5432/admin-db \
    -e registry.client.serviceUrl.defaultZone=http://${local.registry-ip}:8761/registry/ \
    -e spring.rabbitmq.host=${local.rabbit-ip} \
    -e spring.data.redis.host=${local.redis-ip} \
    -e SERVER_PORT=8080 \
    -p 8081:8080 \
    --name admin-service2 firas29/admin-service

    sudo docker run \
    -p 5000:5000 \
    --name webhook-listener firas29/webhook-listener
  EOF

  vpc_security_group_ids = [
    aws_security_group.backend_group.id,
    aws_security_group.webhook_listener_group.id,
    aws_security_group.ssh_group.id
  ]

  tags = {
    Name = "Admin Service"
  }

  depends_on = [
    aws_key_pair.ssh_key_pair,
    aws_security_group.backend_group,
    aws_security_group.webhook_listener_group,
    aws_instance.registry-service,
    aws_instance.rabbitmq,
    aws_instance.redis,
    aws_security_group.ssh_group
  ]
}

resource "aws_instance" "evaluation-service" {
  ami           = "ami-0a887e401f7654935"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main_subnet.id

  key_name = "ssh_key"

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y docker
    sudo service docker start

    sudo docker network create evaluation-network

    sudo docker run \
    --network=evaluation-network \
    -e MONGO_INITDB_DATABASE=evaluation-db
    -e MONGO_INITDB_ROOT_USERNAME=admin
    -e MONGO_INITDB_ROOT_PASSWORD=admin
    -p 27017:27017
    --name mongodb mongo

    sudo docker run \
    --network=evaluation-network \
    -e spring.data.mongodb.uri=mongodb://admin:admin@mongodb:27017/evaluation-db?authSource=admin&authMechanism=SCRAM-SHA-1
    -e registry.client.serviceUrl.defaultZone=http://${local.registry-ip}:8761/registry/ \
    -e spring.rabbitmq.host=${local.rabbit-ip} \
    -e spring.data.redis.host=${local.redis-ip} \
    -e SERVER_PORT=8080 \
    -p 8080:8080 \
    --name evaluation-service firas29/evaluation-service

    sudo docker run \
    -p 5000:5000 \
    --name webhook-listener firas29/webhook-listener
  EOF

  vpc_security_group_ids = [
    aws_security_group.backend_group.id,
    aws_security_group.webhook_listener_group.id,
    aws_security_group.ssh_group.id
  ]

  tags = {
    Name = "Evaluation Service"
  }

  depends_on = [
    aws_key_pair.ssh_key_pair,
    aws_security_group.backend_group,
    aws_security_group.webhook_listener_group,
    aws_instance.registry-service,
    aws_instance.rabbitmq,
    aws_instance.redis,
    aws_security_group.ssh_group
  ]
}

resource "aws_instance" "rubric-service" {
  ami           = "ami-0a887e401f7654935"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main_subnet.id

  key_name = "ssh_key"

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y docker
    sudo service docker start

    sudo docker network create rubric-network

    sudo docker run \
    --network=rubric-network \
    -e POSTGRES_DB=rubric-db \
    -e POSTGRES_USER=admin \
    -e POSTGRES_PASSWORD=admin \
    -p 5432:5432
    --name postgres-rubric postgres

    sudo docker run \
    --network=rubric-network \
    -e spring.datasource.url= jdbc:postgresql://postgres-rubric:5432/rubric-db \
    -e registry.client.serviceUrl.defaultZone=http://${local.registry-ip}:8761/registry/ \
    -e spring.rabbitmq.host=${local.rabbit-ip} \
    -e spring.data.redis.host=${local.redis-ip} \
    -e SERVER_PORT=8080 \
    -p 8080:8080 \
    --name rubric-service firas29/rubric-service

    sudo docker run \
    -p 5000:5000 \
    --name webhook-listener firas29/webhook-listener
  EOF

  vpc_security_group_ids = [
    aws_security_group.backend_group.id,
    aws_security_group.webhook_listener_group.id,
    aws_security_group.ssh_group.id
  ]

  tags = {
    Name = "Rubric Service"
  }

  depends_on = [
    aws_key_pair.ssh_key_pair,
    aws_security_group.backend_group,
    aws_security_group.webhook_listener_group,
    aws_instance.registry-service,
    aws_instance.rabbitmq,
    aws_instance.redis,
    aws_security_group.ssh_group
  ]
}

resource "aws_instance" "notification-service" {
  ami           = "ami-0a887e401f7654935"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main_subnet.id

  key_name = "ssh_key"

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y docker
    sudo service docker start

    sudo docker network create notification-network

    sudo docker run \
    --network=notification-network \
    -e POSTGRES_DB=notification-db \
    -e POSTGRES_USER=admin \
    -e POSTGRES_PASSWORD=admin \
    -p 5432:5432
    --name postgres-notification postgres

    sudo docker run \
    --network=notification-network \
    -e spring.datasource.url= jdbc:postgresql://postgres-notification:5432/notification-db \
    -e registry.client.serviceUrl.defaultZone=http://${local.registry-ip}:8761/registry/ \
    -e spring.rabbitmq.host=${local.rabbit-ip} \
    -e spring.data.redis.host=${local.redis-ip} \
    -e SERVER_PORT=8080 \
    -p 8080:8080 \
    --name notification-service firas29/notification-service

    sudo docker run \
    -p 5000:5000 \
    --name webhook-listener firas29/webhook-listener
  EOF

  vpc_security_group_ids = [
    aws_security_group.backend_group.id,
    aws_security_group.webhook_listener_group.id
  ]

  tags = {
    Name = "Notification Service"
  }

  depends_on = [
    aws_key_pair.ssh_key_pair,
    aws_security_group.backend_group,
    aws_security_group.webhook_listener_group,
    aws_instance.registry-service,
    aws_instance.rabbitmq,
    aws_instance.redis,
    aws_security_group.ssh_group
  ]
}
