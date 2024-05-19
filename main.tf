resource "aws_vpc" "test_vpc" {
	cidr_block = "10.0.0.0/16"
	tags = {
	  Name="test_vpc"
	}
}

resource "aws_subnet" "test_public_subnet" {
    count = 2
    vpc_id = aws_vpc.test_vpc.id
	cidr_block = var.cidr_block[count.index]
	availability_zone = var.availability_zone[count.index]
	tags = {
	  Name = "test_public_subnet_${count.index}"
	}
}
	
resource "aws_subnet" "test_private_subnet" {
    vpc_id = aws_vpc.test_vpc.id
	cidr_block = "10.0.2.0/24"
	tags = {
	  Name = "test_private_subnet"
	}
}	

resource "aws_internet_gateway" "test_gw" {
    vpc_id = aws_vpc.test_vpc.id
	tags = {
	  Name = "test_gw"
	}
}

resource "aws_route_table" "test_public_rt" {
   vpc_id = aws_vpc.test_vpc.id
   route {
     cidr_block = "0.0.0.0/0"
	 gateway_id = aws_internet_gateway.test_gw.id
   }
   tags = {
    Name="test_public_rt"
    
   }
}

resource "aws_route_table" "test_private_rt" {
   vpc_id = aws_vpc.test_vpc.id
   route = []
   tags = {
    Name="test_private_rt"
    
   }
}

resource "aws_route_table_association" "public_sa" {
  subnet_id      = aws_subnet.test_public_subnet[0].id
  route_table_id = aws_route_table.test_public_rt.id
}

resource "aws_route_table_association" "private_sa" {
  subnet_id      = aws_subnet.test_private_subnet.id
  route_table_id = aws_route_table.test_private_rt.id
}

resource "aws_security_group" "test_sg" {
  name = "test_sg"
  description= "Allow traffic from http, https, SSH"
  vpc_id = aws_vpc.test_vpc.id
  ingress {
    description = "Allow 8080 port to access jenkins"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
  }

  tags = {
    Name = "Security Groups to allow SSH(22) and HTTP(80)"
  }
}

resource "aws_instance" "test_ec2" {
  instance_type = "t2.micro"
  ami = "ami-0f58b397bc5c1f2e8"
  availability_zone = "ap-south-1b"
  subnet_id = aws_subnet.test_public_subnet[0].id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.test_sg.id,aws_security_group.ec2_sg_ssh_http.id]
  tags = {
    Name = "Target-Server"
  }
  user_data = <<EOF
#!/bin/bash
sudo apt-get update
yes | sudo apt install openjdk-11-jdk-headless
echo "Waiting for 30 seconds before installing the jenkins package..."
sleep 60
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update
yes | sudo apt-get install jenkins
sleep 60
echo "Waiting for 30 seconds before installing the Terraform..."
wget https://releases.hashicorp.com/terraform/1.6.5/terraform_1.6.5_linux_386.zip
yes | sudo apt-get install unzip
unzip 'terraform*.zip'
sudo mv terraform /usr/local/bin/

EOF
}





resource "aws_lb_target_group" "test_tg" {
  name     = "test-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.test_vpc.id
  health_check {
    path = "/login"
    port = 8080
    healthy_threshold = 6
    unhealthy_threshold = 2
    timeout = 2
    interval = 5
    matcher = "200"  # has to be HTTP 200 or fails
  }
}


resource "aws_security_group" "ec2_sg_ssh_http" {
  name        = "ec2_sg_ssh_http"
  description = "Enable the Port 22(SSH) & Port 80(http)"
  vpc_id      = aws_vpc.test_vpc.id

  # ssh for terraform remote exec
  ingress {
    description = "Allow remote SSH from anywhere"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }
  
  ingress {
    description = "Allow tomcat request"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8088
    to_port     = 8088
    protocol    = "tcp"
  }  

  # enable http
  ingress {
    description = "Allow HTTP request from anywhere"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  # enable http
  ingress {
    description = "Allow HTTP request from anywhere"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
  }

  #Outgoing request
  egress {
    description = "Allow outgoing request"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security Groups to allow SSH(22) and HTTP(80)"
  }
}

resource "aws_lb" "test_lb" {
  name               = "test-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ec2_sg_ssh_http.id]
  subnets            = [aws_subnet.test_public_subnet[0].id,aws_subnet.test_public_subnet[1].id] 

  enable_deletion_protection = false

  tags = {
    Name = "example-lb"
  }
}

resource "aws_lb_target_group_attachment" "test_tg_attach5" {
  target_group_arn = aws_lb_target_group.test_tg.arn
  target_id        = aws_instance.test_ec2.id
  port             = 8080
}

resource "aws_lb_listener" "test_lb_listener" {
  load_balancer_arn = aws_lb.test_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test_tg.arn
  }
}









