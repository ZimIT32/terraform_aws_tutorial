provider "aws" {
    region = "us-east-2"
}

variable "http_port" {
    description = "The HTTP port we want to use"

    type    = number
    default = 8080
}

resource "aws_instance" "example" {
    ami                     = "ami-0c55b159cbfafe1f0"
    instance_type           = "t2.micro"
    vpc_security_group_ids  = [aws_security_group.instance.id]

    user_data = <<-EOF
                #!/bin/bash
                echo "Hello, World!" > index.html
                nohup busybox httpd -f -p ${var.http_port} &
                EOF

    tags = {
        Name = "terraform-example"
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

output "public_ip" {
    value = aws_instance.example.public_ip
    description = "The public IP address of the web server"
}