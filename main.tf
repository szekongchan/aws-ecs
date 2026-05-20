locals {
  image_uri_parameter_name = "/sk/ecs/flask-image-uri"
  ssm_parameter_arn   = "arn:aws:ssm:ap-southeast-1:255945442255:parameter/sk/config"  
  secrets_manager_arn = "arn:aws:secretsmanager:ap-southeast-1:255945442255:secret:sk/db_password-koLWUY" 
  aws_region          = "ap-southeast-1"                                                     
}

data "aws_ssm_parameter" "flask_image_uri" {
  name = local.image_uri_parameter_name
}

resource "aws_iam_role" "ecs_xray_task_role" {
  name = "sk-ecs-xray-taskrole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "xray_daemon_write" {
  role       = aws_iam_role.ecs_xray_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "sk-ecs-xray-taskexecutionrole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

variable "managed_policies" {
  type = list(string)
  default = [
    "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess",
    "arn:aws:iam::aws:policy/SecretsManagerReadWrite",
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
}

resource "aws_iam_role_policy_attachment" "ecs_execution_attachments" {
  count      = length(var.managed_policies)
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = var.managed_policies[count.index]
}

resource "aws_ecs_cluster" "flask_xray_cluster" {
  name = "sk-flask-xray-cluster"

  tags = {
    Name = "sk-flask-xray-cluster"
  }
}

resource "aws_ecs_cluster_capacity_providers" "fargate_provider" {
  cluster_name       = aws_ecs_cluster.flask_xray_cluster.name
  capacity_providers = ["FARGATE"]
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/sk-ecs-taskdef-logsgroup"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "flask_xray_taskdef" {
  family                   = "sk-flask-xray-taskdef"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"

  task_role_arn      = aws_iam_role.ecs_xray_task_role.arn
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      # --- Container 1: flask-app ---
      name      = "flask-app"
      image     = data.aws_ssm_parameter.flask_image_uri.value
      essential = true
      memoryReservation = 512
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "SERVICE_NAME"
          value = "sk-flask-xray-service"
        }
      ]
      secrets = [
        {
          name      = "MY_APP_CONFIG"
          valueFrom = local.ssm_parameter_arn
        },
        {
          name      = "MY_DB_PASSWORD"
          valueFrom = local.secrets_manager_arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_log_group.name
          "awslogs-region"        = local.aws_region
          "awslogs-stream-prefix" = "flask"
        }
      }
    },
    {
      # --- Container 2: xray-sidecar ---
      name      = "xray-sidecar"
      image     = "amazon/aws-xray-daemon"
      essential = false
      memoryReservation = 256
      portMappings = [
        {
          containerPort = 2000
          hostPort      = 2000
          protocol      = "udp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_log_group.name
          "awslogs-region"        = local.aws_region
          "awslogs-stream-prefix" = "xray"
        }
      }
    }
  ])

}

resource "aws_security_group" "ecs_service_sg" {
  name        = "sk-flask-service-sg"
  description = "Allow inbound traffic on port 8080 for Flask app"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "sk-flask-service-sg"
  }

  ingress {
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_ecs_service" "flask_service" {
  name                = "sk-flask-service"
  cluster             = aws_ecs_cluster.flask_xray_cluster.id
  task_definition     = aws_ecs_task_definition.flask_xray_taskdef.arn
  launch_type         = "FARGATE"
  desired_count       = 1
  scheduling_strategy = "REPLICA"

  network_configuration {
    subnets          = [aws_subnet.main.id]
    security_groups  = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = true
  }
}