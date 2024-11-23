resource "aws_launch_template" "asg-test" {
  image_id               = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.instance.id]
  user_data              = base64encode(templatefile("file.sh", {}))
  # user_data = <<-EOF
  #             #!/bin/bash
  #             echo "Hello, World" > index.html
  #             nohup busybox httpd -f -p ${var.server_port} &
  #             EOF
  # Required when using a launch configuration with an ASG.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "instance" {
  name = "terraform-asg-tanu"
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_autoscaling_group" "example" {
  launch_template {
    id      = aws_launch_template.asg-test.id
    version = aws_launch_template.asg-test.latest_version
  }
  vpc_zone_identifier = data.aws_subnets.default.ids
  min_size            = 1
  max_size            = 5
  target_group_arns   = [aws_lb_target_group.asg.arn]
  health_check_type   = "ELB"

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}
resource "aws_lb" "auto_lb" {
  name               = "terraform-asg-example"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.auto_lb.arn
  port              = 80
  protocol          = "HTTP"

  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_security_group" "alb" {
  name = "terraform-example-alb"
  # Allow inbound HTTP requests
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound requests
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_lb_target_group" "asg" {
  name     = "terraform-asg-example"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}
resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}


resource "aws_autoscaling_schedule" "scale_out_in_morning" {
  scheduled_action_name = "scale-out-during-business-hours"
  min_size              = 1
  max_size              = 5
  desired_capacity      = 4
  # start_time          = "2024-11-08T15:00:00Z"
  recurrence            = "15 00 * * *"
  autoscaling_group_name = aws_autoscaling_group.example.name
}
resource "aws_autoscaling_schedule" "scale_in_at_night" {
  scheduled_action_name = "scale-in-at-night"
  min_size              = 1
  max_size              = 5
  desired_capacity      = 2
  start_time            = "2024-11-08T19:00:00Z"
  recurrence            = "19 10 * * *"
  autoscaling_group_name = aws_autoscaling_group.example.name
}