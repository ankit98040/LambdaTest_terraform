resource "aws_ecr_repository" "ecr" {
  name = "${var.environment}-${var.name}"
}

resource "aws_ecr_lifecycle_policy" "ecr_policy" {
  repository = aws_ecr_repository.ecr.name

  policy = <<EOF
{
    "rules": [
        {
           "rulePriority": 1,
           "description": "Expire images more than 5",
           "selection": {
               "tagStatus": "any",
               "countType": "imageCountMoreThan",
               
               "countNumber": 5
           },
           "action": {
               "type": "expire"
           }
       }
    ]
}
EOF
}

resource "aws_ecs_task_definition" "task_def" {
      family = "${var.environment}-${var.name}"
      requires_compatibilities = ["FARGATE"]
      network_mode             = "awsvpc"
      execution_role_arn       = "${var.role}"
      cpu                      = "256"
      memory                   = "512"

      container_definitions =  <<EOF
[{
	"name": "${var.environment}-${var.name}",
	"image": "${var.accountid}.dkr.ecr.${var.region}.amazonaws.com/${var.environment}-${var.name}:latest",
	"portMappings": [
	  {
		"containerPort": ${var.container_port1},
		"protocol": "tcp"
	  },
      {
		"containerPort": ${var.container_port2},
		"protocol": "tcp"
	  }
	],
	"essential": true,
	"command": [],
	"volumes": [],
	 "mountPoints": [],
	  "logConfiguration": {
	  "logDriver": "awslogs",
	  "options": {
		  "awslogs-group": "/ecs/${var.environment}-${var.name}",
          "awslogs-region": "${var.region}",
          "awslogs-stream-prefix": "ecs"
	  }
	}
  }
]
  EOF
}

// target group

resource "aws_lb_target_group" "target_group1" {
  name     = "${var.environment}-${var.target_group_name1}"
  port     = var.container_port1
  protocol = var.target_group_protocol1
  target_type = "ip"
  vpc_id   = var.vpc_id
  deregistration_delay = 30
  health_check {
  path = var.health_check_path
  matcher = var.health_check_code
  }
}

resource "aws_lb_target_group" "target_group2" {
  name     = "${var.environment}-${var.target_group_name2}"
  port     = var.container_port2
  protocol = var.target_group_protocol2
  target_type = "ip"
  vpc_id   = var.vpc_id
  deregistration_delay = 30
  health_check {
  port = var.container_port1
  path = var.health_check_path
  matcher = var.health_check_code
  }
}

//ecs service
resource "aws_ecs_service" "ecs-service" {
  name            = "${var.environment}-${var.name}"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.task_def.arn
  desired_count   = var.service_desired_count
  launch_type     = "FARGATE"
  lifecycle {
    ignore_changes = [
        desired_count, 
        task_definition
        ]
  }
network_configuration {
    security_groups  = ["${var.ecs_security_group}"]
    subnets          = ["${var.aws_subnet_1}", "${var.aws_subnet_2}"]
    assign_public_ip = false
  }


 load_balancer {
    target_group_arn = aws_lb_target_group.target_group1.arn
    container_name   = "${var.environment}-${var.name}"
    container_port   = var.container_port1
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.target_group2.arn
    container_name   = "${var.environment}-${var.name}"
    container_port   = var.container_port2
  }
 
  

}

resource "aws_lb_listener_rule" "listener_rule_http1" {
listener_arn = var.http_listener_arn
  action {
    type          = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }

  }

  condition {
    host_header {
      values = [var.host1]
    }
  }
}

resource "aws_lb_listener_rule" "listener_rule_https1" {
listener_arn = var.https_listener_arn
  action {
    type          = "forward"
    target_group_arn = aws_lb_target_group.target_group1.arn
  }

  condition {
    host_header {
      values = [var.host1]
    }
  }
}


resource "aws_lb_listener_rule" "listener_rule_http2" {
listener_arn = var.http_listener_arn
  action {
    type          = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }

  }

  condition {
    host_header {
      values = [var.host2]
    }
  }
}

resource "aws_lb_listener_rule" "listener_rule_https2" {
listener_arn = var.https_listener_arn
  action {
    type          = "forward"
    target_group_arn = aws_lb_target_group.target_group2.arn
  }

  condition {
    host_header {
      values = [var.host2]
    }
  }
}

