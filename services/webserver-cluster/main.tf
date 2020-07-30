/* ###################
##### PROVIDERS ************
####################

Removing providers block since this folder will be converted to a resuable module

provider "aws" {
  region = "us-east-1"
}
 */


##########################
#        Data           ##
##########################

data "aws_availability_zones" "all" {}


###############################
#        Resources           ##
###############################
## EC2 Resource


resource "aws_security_group" "instance" {
  name = "${var.cluster_name}-instance"
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_configuration" "example" {
  image_id        = "ami-0a0ddd875a1ea2c7f"
  instance_type   = var.instance_type
  security_groups = [aws_security_group.instance.id]
  user_data       = <<-EOF
                    #!/bin/bash
                    echo "Hello, World" > index.html
                    nohup busybox httpd -f -p "${var.server_port}" &
                    EOF
  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_autoscaling_group" "example" {
  launch_configuration  = aws_launch_configuration.example.id
  availability_zones    = data.aws_availability_zones.all.names

  min_size              = var.min_size
  max_size              = var.max_size

  load_balancers    = [aws_elb.example.name]
  health_check_type = "ELB"

    tag {
        key                 = "Name"
        value               = "${var.cluster_name}-asg-example"
        propagate_at_launch = true
    }
}

resource "aws_elb" "example" {
  name               = "${var.cluster_name}-elb"
  availability_zones = data.aws_availability_zones.all.names
  security_groups = [aws_security_group.elb.id]

  #Health Checks block
    health_check {
        target              = "HTTP:${var.server_port}/"
        interval            = 30
        timeout             = 3
        healthy_threshold   = 2
        unhealthy_threshold = 2
    }

  # This adds a listener for incoming HTTP requests.
    listener {
        lb_port           = var.elb_port
        lb_protocol       = "http"
        instance_port     = var.server_port
        instance_protocol = "http"
    }
}

resource "aws_security_group" "elb" {
  name = "${var.cluster_name}-elb-sg"
  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Inbound HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



