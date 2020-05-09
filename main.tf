variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "key_name" {}
variable "conductor_address" {}
variable "aws_region" { default = "us-east-1" }
variable "aws_az1" { default = "use1-az1" }
variable "aws_az2" { default = "use1-az2" }
variable "vpc_cidr_range" { default = "10.0.0.0/16" }
variable "az1_external_subnet" { default = "10.0.0.0/24" }
variable "az2_external_subnet" { default = "10.0.1.0/24" }
variable "az1_internal_subnet" { default = "10.0.2.0/24" }
variable "az2_internal_subnet" { default = "10.0.3.0/24" }
variable "t128_flavor" { default = "c5.xlarge" }
variable "az1_minion_id" { default = "az1_t128" }
variable "az2_minion_id" { default = "az2_t128" }
variable "server_flavor" { default = "t3.micro" }

# Configure the AWS Provider
provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}

data "aws_ami" "t128" {
  owners = ["aws-marketplace"]
  most_recent = true
  name_regex = "^128 Technology Router 4.2.0-1 Hourly*"
}

data "aws_ami" "server" {
  owners = ["aws-marketplace"]
  most_recent = true
  name_regex = "^CentOS Linux 7 x86_64 HVM EBS ENA 1803*"
}

data "template_file" "t128_cloud_init" {
  template = "${file("aws-128t.tpl")}"

  vars = {
    conductor-address = "${var.conductor_address}"
  }
}

# Create the VPC
resource "aws_vpc" "t128_vpc" {
  cidr_block = "${var.vpc_cidr_range}"

  tags = {
    Name = "Inline Services VPC"
  }
}

# Create the subnets in the VPC
resource "aws_subnet" "az1_external_subnet" {
  vpc_id = "${aws_vpc.t128_vpc.id}"
  availability_zone_id = "${var.aws_az1}"
  cidr_block = "${var.az1_external_subnet}"

  tags = {
    Name = "Inline Services AZ1 External Subnet"
  }
}

resource "aws_subnet" "az2_external_subnet" {
  vpc_id = "${aws_vpc.t128_vpc.id}"
  availability_zone_id = "${var.aws_az2}"
  cidr_block = "${var.az2_external_subnet}"

  tags = {
    Name = "Inline Services AZ2 External Subnet"
  }
}

resource "aws_subnet" "az1_internal_subnet" {
  vpc_id = "${aws_vpc.t128_vpc.id}"
  availability_zone_id = "${var.aws_az1}"
  cidr_block = "${var.az1_internal_subnet}"

  tags = {
    Name = "Inline Services AZ1 Internal Subnet"
  }
}

resource "aws_subnet" "az2_internal_subnet" {
  vpc_id = "${aws_vpc.t128_vpc.id}"
  availability_zone_id = "${var.aws_az2}"
  cidr_block = "${var.az2_internal_subnet}"

  tags = {
    Name = "Inline Services AZ2 Internal Subnet"
  }
}

resource "aws_internet_gateway" "vpc_gw" {
  vpc_id = "${aws_vpc.t128_vpc.id}"

  tags = {
    Name = "Inline Services VPC Internet Gateway"
  }
}

resource "aws_route_table" "external_rt" {
  vpc_id = "${aws_vpc.t128_vpc.id}"

  tags = {
    Name = "Inline Services External Route Table"
  }
}

resource "aws_route_table" "az1_internal_rt" {
  vpc_id = "${aws_vpc.t128_vpc.id}"

  tags = {
    Name = "Inline Services AZ1 Internal Route Table"
  }
}

resource "aws_route_table" "az2_internal_rt" {
  vpc_id = "${aws_vpc.t128_vpc.id}"

  tags = {
    Name = "Inline Services AZ2 Internal Route Table"
  }
}

resource "aws_route" "external_default" {
  route_table_id = "${aws_route_table.external_rt.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.vpc_gw.id}"
}

resource "aws_route_table_association" "external_az1" {
  subnet_id = "${aws_subnet.az1_external_subnet.id}"
  route_table_id = "${aws_route_table.external_rt.id}"
}

resource "aws_route_table_association" "external_az2" {
  subnet_id = "${aws_subnet.az2_external_subnet.id}"
  route_table_id = "${aws_route_table.external_rt.id}"
}

resource "aws_route_table_association" "internal_az1" {
  subnet_id = "${aws_subnet.az1_internal_subnet.id}"
  route_table_id = "${aws_route_table.az1_internal_rt.id}"
}

resource "aws_route_table_association" "internal_az2" {
  subnet_id = "${aws_subnet.az2_internal_subnet.id}"
  route_table_id = "${aws_route_table.az2_internal_rt.id}"
}

resource "aws_security_group" "waypoint" {
  name = "waypoint_allow_all"
  vpc_id = "${aws_vpc.t128_vpc.id}"

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "az1_128t" {
  ami = "${data.aws_ami.t128.image_id}"
  instance_type = "${var.t128_flavor}"
  user_data = "${data.template_file.t128_cloud_init.rendered}"
  key_name = "${var.key_name}"
  subnet_id = "${aws_subnet.az1_external_subnet.id}"
  private_ip = cidrhost("${var.az1_external_subnet}", 5)
  associate_public_ip_address = true
  security_groups = ["${aws_security_group.waypoint.id}"]
  source_dest_check = false

  root_block_device {
    volume_size = 128
    delete_on_termination = true
  }
  volume_tags = {
    Name = "Inline Services AZ1 128T volume"
  }
  tags = {
    Name = "Inline Services AZ1 128T"
    conductor-ip-primary = "${var.conductor_address}"
  }
}

resource "aws_eip" "az1_t128_eip" {
  vpc = true
  instance = "${aws_instance.az1_128t.id}"
}

resource "aws_network_interface" "az1_128t_internal" {
  subnet_id = "${aws_subnet.az1_internal_subnet.id}"
  private_ips = [cidrhost("${var.az1_internal_subnet}", 5)]
  security_groups = ["${aws_security_group.waypoint.id}"]
  source_dest_check = false

  tags = {
    Name = "Inline Services AZ1 128T Internal"
  }

  attachment {
    instance = "${aws_instance.az1_128t.id}"
    device_index = 1
  }
}

resource "aws_route" "az1_internal_default" {
  route_table_id = "${aws_route_table.az1_internal_rt.id}"
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id = "${aws_network_interface.az1_128t_internal.id}"
}

resource "aws_instance" "az2_128t" {
  ami = "${data.aws_ami.t128.image_id}"
  instance_type = "${var.t128_flavor}"
  user_data = "${data.template_file.t128_cloud_init.rendered}"
  key_name = "${var.key_name}"
  subnet_id = "${aws_subnet.az2_external_subnet.id}"
  private_ip = cidrhost("${var.az2_external_subnet}", 5)
  associate_public_ip_address = true
  security_groups = ["${aws_security_group.waypoint.id}"]
  source_dest_check = false

  root_block_device {
    volume_size = 128
    delete_on_termination = true
  }
  volume_tags = {
    Name = "Inline Services AZ2 128T volume"
  }
  tags = {
    Name = "Inline Services AZ2 128T"
    conductor-ip-primary = "${var.conductor_address}"
  }
}

resource "aws_eip" "az2_t128_eip" {
  vpc = true
  instance = "${aws_instance.az2_128t.id}"
}

resource "aws_network_interface" "az2_128t_internal" {
  subnet_id = "${aws_subnet.az2_internal_subnet.id}"
  private_ips = [cidrhost("${var.az2_internal_subnet}", 5)]
  security_groups = ["${aws_security_group.waypoint.id}"]
  source_dest_check = false

  tags = {
    Name = "Inline Services AZ2 128T Internal"
  }

  attachment {
    instance = "${aws_instance.az2_128t.id}"
    device_index = 1
  }
}

resource "aws_route" "az2_internal_default" {
  route_table_id = "${aws_route_table.az2_internal_rt.id}"
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id = "${aws_network_interface.az2_128t_internal.id}"
}

resource "aws_instance" "az1-server" {
  ami = "${data.aws_ami.server.image_id}"
  instance_type = "${var.server_flavor}"
  key_name = "${var.key_name}"
  subnet_id = "${aws_subnet.az1_internal_subnet.id}"
  private_ip = cidrhost("${var.az1_internal_subnet}", 10)
  security_groups = ["${aws_security_group.waypoint.id}"]

  root_block_device {
    delete_on_termination = true
  }
  volume_tags = {
    Name = "Inline Services AZ1 Server volume"
  }
  tags = {
    Name = "Inline Services AZ1 Server"
  }
}

resource "aws_instance" "az2-server" {
  ami = "${data.aws_ami.server.image_id}"
  instance_type = "${var.server_flavor}"
  key_name = "${var.key_name}"
  subnet_id = "${aws_subnet.az2_internal_subnet.id}"
  private_ip = cidrhost("${var.az2_internal_subnet}", 10)
  security_groups = ["${aws_security_group.waypoint.id}"]

  root_block_device {
    delete_on_termination = true
  }
  volume_tags = {
    Name = "Inline Services AZ2 Server volume"
  }
  tags = {
    Name = "Inline Services AZ2 Server"
  }
}

output "T128_AZ1_ELASTIC_IP" {
  value = "${aws_eip.az1_t128_eip.public_ip}"
}

output "T128_AZ2_ELASTIC_IP" {
  value = "${aws_eip.az2_t128_eip.public_ip}"
}

output "T128_AZ1_MINION_ID" {
  value = "${aws_instance.az1_128t.id}"
}

output "T128_AZ2_MINION_ID" {
  value = "${aws_instance.az2_128t.id}"
}
