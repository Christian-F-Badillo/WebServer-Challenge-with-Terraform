variable "region" {
  description = "Region of AWS to deploy"
  type = string
  default = "us-west-2"
}

variable "instance_type_ec2" {
  description = "Type of EC2 instance"
  type = string
  default = "t3.micro"
}