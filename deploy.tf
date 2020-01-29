variable "region" {
  default = "croc"
}

variable "key_path" {
#  default = "/croc-k8s/avon-k8s.pem"
   default = "/croc-okd/okd_private.pem"
}

variable "template" {
  default = "cmi-3F5B011E"
}

variable "type" {
  default = "r4.2large"
}

variable "key_name" {
  default = "id_rsa"

}
variable "domain_name" {
 default = "openshift.local"
}


variable "az" {
  default = "ru-msk-vol51"
}

provider "aws" {
  endpoints {
    ec2 = "https://api.cloud.croc.ru"
  }

  insecure = true
  # NOTE: STS API is not implemented, skip validation
  skip_credentials_validation = true

  # NOTE: IAM API is not implemented, skip validation
  skip_requesting_account_id = true

  # NOTE: Region has different name, skip validation
  skip_region_validation = true

  region     = "${var.region}"
}

resource "aws_key_pair" "deployer" {
  key_name   = "id_rsa"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDJwHgjWjex6mJNEPwrE5bj0sezeqKQLvlxs4O1PTequMRQOqez9dsstzd0EzVfzfHjkpgX5qfGjE680FYdAZ3Z2/ZrDGMpydwCW/JU/wC0H8vNvQkusvkeuWiE0NaxmTu2nAWrAmYRJp0ZJZ5DBrUFyAxfoMZJUENWdKsn1JJMImLdul9BUc1EaL9sT57aNO7dGu7G7nCqnBsAyHLT4vsoBHXRI2Rn9xNOQiLouZUErUNTWMiu02d694OdLXFz8RJodUeQ/mQRt8aPQW99mwBnlP15zSBFgBqorvYfuVrJBPQMFsozQM6wo2lWIFOASKup2SszTZGcgmgu+7u0fZAH alexvish@tower.local"
}


# Create a VPC to launch our instances into
resource "aws_vpc" "vol51_vpc" {
  cidr_block = "10.11.0.0/16"
}
resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  vpc_id          = "${aws_vpc.vol51_vpc.id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.okd-dns.id}"
}
# Create a subnet to launch our instances into
resource "aws_subnet" "vol51_subnet" {
  vpc_id = "${aws_vpc.vol51_vpc.id}"
  cidr_block = "10.11.10.0/24"
  map_public_ip_on_launch = false
  availability_zone = "${var.az}"
}

# Describe default security group
resource "aws_default_security_group" "default" {
  vpc_id = "${aws_vpc.vol51_vpc.id}"

  # ingress {
  #   protocol  = "tcp"
  #   from_port = 22
  #   to_port   = 22
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

#  ingress {
#    from_port   = 6443
#    to_port     = 6443
#    protocol    = "tcp"
#    cidr_blocks = ["109.73.14.98/32"]
#  }

  # ingress {
  #   from_port   = 30001
  #   to_port     = 30001
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    # self	= true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# resource "aws_network_interface" "vrrp" {
#   subnet_id       = "${aws_subnet.vol51_subnet.id}"
#   private_ips     = ["10.0.10.100"]
#   source_dest_check = false
# }

# resource "aws_placement_group" "master" {
#   name     = "k8s-master"
#   strategy = "distribute"
# }

# resource "aws_placement_group" "worker" {
#   name     = "k8s-worker"
#   strategy = "distribute"
# }

# resource "aws_placement_group" "router" {
#   name     = "k8s-router"
#   strategy = "distribute"
# }

resource "aws_instance" "k8s-bastion" {
  ami               = 	"${var.template}"
  subnet_id         = "${aws_subnet.vol51_subnet.id}"
  instance_type     = "${var.type}"
  count        = 1
  monitoring        = true
  source_dest_check = false
  key_name      = "${var.key_name}"
  associate_public_ip_address = false
  provisioner "local-exec" {
    command = "c2-ec2 ModifyInstanceAttribute InstanceId ${aws_instance.k8s-bastion.id} Description.Value k8s-bastion"
  }

}

resource "aws_eip" "bastion" {
  instance = "${aws_instance.k8s-bastion.id}"
  vpc = true

  provisioner "remote-exec" {
    inline = [
      "date"
    ]
   connection {
      type = "ssh"
      user = "ec2-user"
      private_key = "${file(var.key_path)}"
      host = "${aws_eip.bastion.public_ip}"
  }
  }
}

resource "aws_network_interface" "apps" {
  subnet_id         = "${aws_subnet.vol51_subnet.id}"
  description = "APPS-API"
  source_dest_check = false
}

resource "aws_network_interface" "portal" {
  subnet_id         = "${aws_subnet.vol51_subnet.id}"
  description = "web-portal"
  source_dest_check = false
}

resource "aws_vpc_dhcp_options" "okd-dns" {
  domain_name          = "${var.domain_name}"
  domain_name_servers  = ["${aws_instance.k8s-bastion.private_ip}", "8.8.8.8"]
#  ntp_servers          = []
#  netbios_name_servers = []
#  netbios_node_type    = 2

#  tags = {
#    Name = "foo-name"
#  }
}

resource "aws_instance" "k8s-ceph1" {
  ami               =   "${var.template}"
  subnet_id         = "${aws_subnet.vol51_subnet.id}"
  instance_type     = "${var.type}"
  count        = 1
  monitoring        = true
  source_dest_check = false
  key_name      = "${var.key_name}"
  associate_public_ip_address = false
#  placement_group = "${aws_placement_group.router.id}"
  provisioner "local-exec" {
    command = "c2-ec2 ModifyInstanceAttribute InstanceId ${aws_instance.k8s-ceph1.id} Description.Value k8s-ceph1"
  }
}

resource "aws_instance" "k8s-ceph2" {
  ami               =   "${var.template}"
  subnet_id         = "${aws_subnet.vol51_subnet.id}"
  instance_type     = "${var.type}"
  count        = 1
  monitoring        = true
  source_dest_check = false
  key_name      = "${var.key_name}"
  associate_public_ip_address = false
#  placement_group = "${aws_placement_group.router.id}"
  provisioner "local-exec" {
    command = "c2-ec2 ModifyInstanceAttribute InstanceId ${aws_instance.k8s-ceph2.id} Description.Value k8s-ceph2"
  }
}

resource "aws_instance" "k8s-ceph3" {
  ami               =   "${var.template}"
  subnet_id         = "${aws_subnet.vol51_subnet.id}"
  instance_type     = "${var.type}"
  count        = 1
  monitoring        = true
  source_dest_check = false
  key_name      = "${var.key_name}"
  associate_public_ip_address = false
#  placement_group = "${aws_placement_group.router.id}"
  provisioner "local-exec" {
    command = "c2-ec2 ModifyInstanceAttribute InstanceId ${aws_instance.k8s-ceph3.id} Description.Value k8s-ceph3"
  }
}

resource "aws_instance" "k8s-metallb1" {
  ami               = 	"${var.template}"
  subnet_id         = "${aws_subnet.vol51_subnet.id}"
  instance_type     = "${var.type}"
  count        = 1
  monitoring        = true
  source_dest_check = false
  key_name      = "${var.key_name}"
  associate_public_ip_address = false
#  placement_group = "${aws_placement_group.router.id}"
  provisioner "local-exec" {
    command = "c2-ec2 ModifyInstanceAttribute InstanceId ${aws_instance.k8s-metallb1.id} Description.Value k8s-metallb1"
  }

}

resource "aws_instance" "k8s-metallb2" {
  ami               = 	"${var.template}"
  subnet_id         = "${aws_subnet.vol51_subnet.id}"
  instance_type     = "${var.type}"
  root_block_device {
    volume_type     = "gp2"
    volume_size     = "64"
  }
  count        = 1
  monitoring        = true
  source_dest_check = false
  key_name      = "${var.key_name}"
  associate_public_ip_address = false
#  placement_group = "${aws_placement_group.router.id}"
  provisioner "local-exec" {
    command = "c2-ec2 ModifyInstanceAttribute InstanceId ${aws_instance.k8s-metallb2.id} Description.Value k8s-metallb2"
  }

}

resource "aws_eip" "portal" {
  instance = "${aws_instance.k8s-metallb2.id}"
  vpc = true

  provisioner "remote-exec" {
    inline = [
      "date"
    ]
   connection {
      type = "ssh"
      user = "ec2-user"
      private_key = "${file(var.key_path)}"
      host = "${aws_eip.portal.public_ip}"
  }
  }
}

resource "aws_instance" "k8s-master1" {
  ami               = 	"${var.template}"
  subnet_id         = "${aws_subnet.vol51_subnet.id}"
  instance_type     = "${var.type}"
  root_block_device {
    volume_type     = "gp2"
    volume_size     = "64"
  }
  count        = 1
  monitoring        = true
  source_dest_check = false
  key_name      = "${var.key_name}"
  associate_public_ip_address = false
#  placement_group = "${aws_placement_group.master.id}"
  provisioner "local-exec" {
    command = "c2-ec2 ModifyInstanceAttribute InstanceId ${aws_instance.k8s-master1.id} Description.Value k8s-master1"
  }

}

resource "aws_instance" "k8s-master2" {
  ami               =   "${var.template}"
  subnet_id         = "${aws_subnet.vol51_subnet.id}"
  instance_type     = "${var.type}"
  root_block_device {
    volume_type     = "gp2"
    volume_size     = "64"
  }
  count        = 1
  monitoring        = true
  source_dest_check = false
  key_name      = "${var.key_name}"
  associate_public_ip_address = false
#  placement_group = "${aws_placement_group.master.id}"
  provisioner "local-exec" {
    command = "c2-ec2 ModifyInstanceAttribute InstanceId ${aws_instance.k8s-master2.id} Description.Value k8s-master2"
  }

}

resource "aws_instance" "k8s-master3" {
  ami               =   "${var.template}"
  subnet_id         = "${aws_subnet.vol51_subnet.id}"
  instance_type     = "${var.type}"
  root_block_device {
    volume_type     = "gp2"
    volume_size     = "64"
  }
  count        = 1
  monitoring        = true
  source_dest_check = false
  key_name      = "${var.key_name}"
  associate_public_ip_address = false
#  placement_group = "${aws_placement_group.master.id}"
  provisioner "local-exec" {
    command = "c2-ec2 ModifyInstanceAttribute InstanceId ${aws_instance.k8s-master3.id} Description.Value k8s-master3"
  }

}

resource "aws_instance" "k8s-worker1" {
  ami               = 	"${var.template}"
  subnet_id         = "${aws_subnet.vol51_subnet.id}"
  instance_type     = "${var.type}"
  count        = 1
  monitoring        = true
  source_dest_check = false
  key_name      = "${var.key_name}"
  associate_public_ip_address = false
#  placement_group = "${aws_placement_group.worker.id}"
  provisioner "local-exec" {
    command = "c2-ec2 ModifyInstanceAttribute InstanceId ${aws_instance.k8s-worker1.id} Description.Value k8s-worker1"
  }

}

resource "aws_instance" "k8s-worker2" {
  ami               = 	"${var.template}"
  subnet_id         = "${aws_subnet.vol51_subnet.id}"
  instance_type     = "${var.type}"
  count        = 1
  monitoring        = true
  source_dest_check = false
  key_name      = "${var.key_name}"
  associate_public_ip_address = false
#  placement_group = "${aws_placement_group.worker.id}"
  provisioner "local-exec" {
    command = "c2-ec2 ModifyInstanceAttribute InstanceId ${aws_instance.k8s-worker2.id} Description.Value k8s-worker2"
  }

}


resource "aws_instance" "k8s-worker3" {
  ami               = 	"${var.template}"
  subnet_id         = "${aws_subnet.vol51_subnet.id}"
  instance_type     = "${var.type}"
  count        = 1
  monitoring        = true
  source_dest_check = false
  key_name      = "${var.key_name}"
  associate_public_ip_address = false
#  placement_group = "${aws_placement_group.worker.id}"
  provisioner "local-exec" {
    command = "c2-ec2 ModifyInstanceAttribute InstanceId ${aws_instance.k8s-worker3.id} Description.Value k8s-worker3"
  }
}
