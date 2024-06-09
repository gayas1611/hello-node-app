# Configure the AWS provider
provider "aws" {
  region = "ap-south-1"
}

# existing ECR repository
resource "aws_ecr_repository" "hello_node_app" {
  name = "hello-node-app"
}

# existing ECS Cluster
resource "aws_ecs_cluster" "hello_node_cluster" {
  name = "hello-node-cluster"
}

# existing ECS Task Definition
resource "aws_ecs_task_definition" "hello_node_task" {
  family                   = "hello-node-task"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
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

# existing ECS Service
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