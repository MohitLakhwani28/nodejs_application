# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "nodejs-vpc"
  }
}

# Subnets
resource "aws_subnet" "subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "nodejs-subnet-1"
  }
}

resource "aws_subnet" "subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "nodejs-subnet-2"
  }
}

resource "aws_subnet" "subnet_3" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "ap-south-1c"
  map_public_ip_on_launch = true
  tags = {
    Name = "nodejs-subnet-3"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "nodejs-igw"
  }
}

# Route Table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "nodejs-route-table"
  }
}

# Associate Route Table with Subnets
resource "aws_route_table_association" "subnet_1" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "subnet_2" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "subnet_3" {
  subnet_id      = aws_subnet.subnet_3.id
  route_table_id = aws_route_table.main.id
}

# IAM Role for ECS Execution
resource "aws_iam_role" "ecs_exec_role" {
  name = "ecs_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Role Policy Attachment for ECS Execution Role
resource "aws_iam_role_policy_attachment" "ecs_exec_role_policy" {
  role       = aws_iam_role.ecs_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task_role" {
  name = "ecs_task_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# ECS Cluster
resource "aws_ecs_cluster" "nodejs" {
  name = "nodejs-cluster"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "nodejs" {
  family                   = "nodejs-task"
  execution_role_arn       = aws_iam_role.ecs_exec_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu    = "1024"  # 1 vCPU
  memory = "2048"  # 2 GB

  container_definitions = jsonencode([ 
    { 
      name      = "nodejs" 
      image     = "mohitlakhwani/nodejs-web-app:${var.image_tag}"  # Updated to use dynamic image tag
      essential = true 
      portMappings = [ 
        { 
          containerPort = 3000  # Set to 3000
          protocol      = "tcp" 
        } 
      ] 
      memory = 512  # Specify the memory allocated to the container 
      cpu    = 256  # Specify the CPU units allocated to the container 
    } 
  ])
}

# Security Group for Load Balancer
resource "aws_security_group" "lb_sg" {
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nodejs-lb-sg"
  }
}

# Security Group for ECS Service
resource "aws_security_group" "ecs_sg" {
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]  # Only allow traffic from the load balancer
  }

  tags = {
    Name = "nodejs-ecs-sg"
  }
}

# Load Balancer
resource "aws_lb" "nodejs" {
  name               = "nodejs-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [
    aws_subnet.subnet_1.id,
    aws_subnet.subnet_2.id,
    aws_subnet.subnet_3.id
  ]

  enable_deletion_protection         = false
  enable_cross_zone_load_balancing  = true

  tags = {
    Name = "nodejs-lb"
  }
}

# Target Group
resource "aws_lb_target_group" "nodejs" {
  name     = "nodejs-target-group"
  port     = 3000  # Set to 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  target_type = "ip"

  # Updated Health Check
  health_check {
    path                = "/health"
    interval            = 10   # Reduced interval to 10 seconds
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Load Balancer Listener
resource "aws_lb_listener" "nodejs" {
  load_balancer_arn = aws_lb.nodejs.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nodejs.arn
  }
}

# ECS Service
resource "aws_ecs_service" "nodejs" {
  name            = "nodejs-service"
  cluster         = aws_ecs_cluster.nodejs.id
  task_definition = aws_ecs_task_definition.nodejs.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [
      aws_subnet.subnet_1.id,
      aws_subnet.subnet_2.id,
      aws_subnet.subnet_3.id
    ]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.nodejs.arn
    container_name   = "nodejs"
    container_port   = 3000  # Set to 3000
  }

  depends_on = [
    aws_lb_listener.nodejs
  ]
}

# New variable for image tag
variable "image_tag" {
  description = "Docker image tag (timestamp-based for each deployment)"
  type        = string
}
