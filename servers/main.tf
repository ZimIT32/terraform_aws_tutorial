provider "aws" {
    region = "us-east-2"
}

variable "http_port" {
    description = "The HTTP port we want to use"

    type    = number
    default = 8080
}
variable "default_name" {
    type    = string
    default = "terraform-asg-example"
}

# Target group for our ASG 
resource "aws_lb_target_group" "asg" {
    name        = var.default_name
    port        = var.http_port
    protocol    = "HTTP"
    vpc_id      = data.aws_vpc.default.id

    health_check {
        path = "/"
        protocol = "HTTP"
        matcher = "200"
        interval = 15
        timeout = 3
        healthy_threshold =2
        unhealthy_threshold = 2
    }
}

resource "aws_security_group" "alb" {
    name = "${var.default_name}-alb"

    #allow inbound HTTP
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # allow outbound
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# listener for the load balancer
resource "aws_lb_listener" "http" {
    load_balancer_arn   = aws_lb.example.arn
    port                = 80
    protocol            = "HTTP"

    # By default return 404 page

    default_action {
        type = "fixed-response"

        fixed_response {
            content_type    = "text/plain"
            message_body    = "404: page not found"
            status_code     = 404
        }
    }
}

# our load balancer
resource "aws_lb" "example" {
    name                = var.default_name
    load_balancer_type  = "application"
    # Default subnets from our aws subscription
    #aws_subnet_ids      = data.aws_subnet_ids.default.ids
    security_groups     = [aws_security_group.alb.id]
}

resource "aws_lb_listener_rule" "asg"{
    # This adds the load balancer listener
    listener_arn = aws_lb_listener.http.arn
    priority = 100

    condition {
        path_pattern {
            values = ["*"]
        }
    }

    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.asg.arn
    }


}
resource "aws_autoscaling_group" "example" {
    # This is the individual VM launch  config
    launch_configuration = aws_launch_configuration.example.name
    # loads in the default VPC from our account
    vpc_zone_identifier = data.aws_subnet_ids.default.ids
    # AWS Target group for health checks
    target_group_arns = [aws_lb_target_group.asg.arn]
    # Default health checks are not good enough
    health_check_type = "ELB"

    min_size = 2
    max_size = 10

    # Naming our server
    tag {
        key                 = "Name"
        value               = var.default_name
        propagate_at_launch = true
    }
}


# Configuration for our web servers
resource "aws_launch_configuration" "example" {
    image_id        = "ami-0c55b159cbfafe1f0"
    instance_type   = "t2.micro"
    security_groups = [aws_security_group.instance.id]

    user_data = <<-EOF
                #!/bin/bash
                echo "Hello, World InvaderZim!" > index.html
                nohup busybox httpd -f -p 8080 &
                EOF

    # Required when using a launch configuration with an auto scaling group
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_security_group" "instance" {
    name ="terraform-example-instance"

    ingress {
        from_port   = var.http_port
        to_port     = var.http_port
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# list of default VPC from our amazon account
data "aws_vpc" "default" {
    default = true
}

data "aws_subnet_ids" "default" {
    vpc_id = data.aws_vpc.default.id
}

output "alb_dns_name" {
    value = aws_lb.example.dns_name
    description = "The domain name of the loda balancer"
}