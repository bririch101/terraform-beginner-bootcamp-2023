############################
# ALB — us-east-1
# Manages access to the us-east-1 public instance.
# ALB requires two subnets in different AZs; the second subnet hosts
# only the ALB listener — the actual EC2 is in subnet[0].
############################

# Security group for the ALB — allow HTTP/HTTPS from anywhere
resource "aws_security_group" "use1_alb" {
  provider    = aws.use1
  name        = "${var.project_name}-alb-sg-use1"
  description = "Allow HTTP and HTTPS inbound to ALB"
  vpc_id      = aws_vpc.use1.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-alb-sg-use1"
    Project = var.project_name
  }
}

resource "aws_lb" "use1" {
  provider           = aws.use1
  name               = "${var.project_name}-alb-use1"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.use1_alb.id]
  # ALB requires at least two subnets in different AZs
  subnets            = [aws_subnet.use1_public[0].id, aws_subnet.use1_public[1].id]

  tags = {
    Name    = "${var.project_name}-alb-use1"
    Project = var.project_name
  }
}

resource "aws_lb_target_group" "use1_public" {
  provider    = aws.use1
  name        = "${var.project_name}-tg-use1"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.use1.id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }

  tags = {
    Name    = "${var.project_name}-tg-use1"
    Project = var.project_name
  }
}

# Register the us-east-1 public instance
resource "aws_lb_target_group_attachment" "use1_public" {
  provider         = aws.use1
  target_group_arn = aws_lb_target_group.use1_public.arn
  target_id        = aws_instance.use1_public.id
  port             = 80
}

resource "aws_lb_listener" "use1_http" {
  provider          = aws.use1
  load_balancer_arn = aws_lb.use1.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.use1_public.arn
  }
}
