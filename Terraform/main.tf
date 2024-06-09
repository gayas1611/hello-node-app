provider "aws" {
  region = "ap-south-1"
}

# Creating ECR repository
resource "aws_ecr_repository" "hello_node_app" {
  name = "hello-node-app"
}

# Creating ECS cluster
resource "aws_ecs_cluster" "hello_node_cluster" {
  name = "hello-node-cluster"
}

# Get custom VPC
data "aws_vpc" "custom_vpc" {
  id = "vpc-07ec151640cbf37f9"
}

# Get custom subnets
data "aws_subnets" "private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.custom_vpc.id]
  }

  filter {
    name   = "tag:Name"
    values = ["my-subnet"]
  }
}

# Creating security group
resource "aws_security_group" "ecs_security_group" {
  name   = "ecs-security-group"
  vpc_id = data.aws_vpc.custom_vpc.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Create ECS task execution role
data "aws_iam_policy" "ecs_task_execution_role_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = data.aws_iam_policy.ecs_task_execution_role_policy.arn
}

# Creating task definition
resource "aws_ecs_task_definition" "hello_node_task" {
  family                   = "hello-node-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "hello-node-container"
      image     = "${aws_ecr_repository.hello_node_app.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
    }
  ])
}

# Creating ECS service
resource "aws_ecs_service" "hello_node_service" {
  name            = "hello-node-service"
  cluster         = aws_ecs_cluster.hello_node_cluster.id
  task_definition = aws_ecs_task_definition.hello_node_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    assign_public_ip = true
    subnets          = data.aws_subnets.private_subnets.ids
    security_groups  = [aws_security_group.ecs_security_group.id]
  }
}
