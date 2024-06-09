provider "aws" {
  region = "ap-south-1"
}

# Creating the ECR repository
resource "aws_ecr_repository" "hello_node_app" {
  name                 = "hello-node-app"
  image_scanning_configuration {
    scan_on_push = false
  }
}

# Creating the ECS Cluster
resource "aws_ecs_cluster" "hello_node_cluster" {
  name = "hello-node-cluster"
}

# Create the Execution Role for ECS tasks
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

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_ecs_task_definition" "hello_node_task" {
  family                   = "hello-node-task"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions    = <<DEFINITION
[
  {
    "name": "hello-node-app",
    "image": "${aws_ecr_repository.hello_node_app.repository_url}:latest",
    "portMappings": [
      {
        "containerPort": 3000,
        "hostPort": 3000
      }
    ]
  }
]
DEFINITION
}

# Creating the ECS Service
resource "aws_ecs_service" "hello_node_service" {
  name            = "hello-node-service"
  cluster         = aws_ecs_cluster.hello_node_cluster.id
  task_definition = aws_ecs_task_definition.hello_node_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = ["subnet-01db67cbe2ea6c280"] 
    security_groups  = ["sg-0d11ad8a06ccdec12"]
    assign_public_ip = true
  }
}