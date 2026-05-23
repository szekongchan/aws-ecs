locals {
  prefix = "sk-coaching18"
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 7.5.0"

  cluster_name = "${local.prefix}-ecs"

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
      }
    }
  }

  services = {
    # 1. Service 1: Flask app accessing S3
    s3-service = {
      cpu    = 512
      memory = 1024
      
      # Task Definition container definitions
      container_definitions = {
        s3-app = {
          essential = true
          image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/${local.prefix}-s3-ecr:latest"
          port_mappings = [
            {
              containerPort = 5001
              protocol      = "tcp"
            }
          ]
          # Pass environment variables needed by the application
          environment = [
            { name = "AWS_REGION", value = data.aws_region.current.name },
            { name = "BUCKET_NAME", value = aws_s3_bucket.your_bucket.id }
          ]
        }
      }
      
      # Networking & Deployment settings
      assign_public_ip                   = true
      deployment_minimum_healthy_percent = 100
      subnet_ids                         = ["subnet-xxxxxxxxxxxx"] # Your Public Subnets
      security_group_ids                 = [aws_security_group.ecs_s3_sg.id]
    }

    # 2. Service 2: Flask app accessing SQS
    sqs-service = {
      cpu    = 512
      memory = 1024
      
      container_definitions = {
        sqs-app = {
          essential = true
          image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/${local.prefix}-sqs-ecr:latest"
          port_mappings = [
            {
              containerPort = 5002
              protocol      = "tcp"
            }
          ]
          environment = [
            { name = "AWS_REGION", value = data.aws_region.current.name },
            { name = "QUEUE_URL", value = aws_sqs_queue.your_queue.id }
          ]
        }
      }

      assign_public_ip                   = true
      deployment_minimum_healthy_percent = 100
      subnet_ids                         = ["subnet-xxxxxxxxxxxx"] # Your Public Subnets
      security_group_ids                 = [aws_security_group.ecs_sqs_sg.id]
    }
  }
}
