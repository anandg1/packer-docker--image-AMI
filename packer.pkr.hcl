#######################################################
            # Variable Declaration
#######################################################
variable "region" {
    default = "ap-south-1"
}

variable "instance_type" {
    default = "t2.micro"
}
# -----------------------------------------------#
#  Timestamp variable declaration on running time#
#  -----------------------------------------------#

locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

# #--------------------------------------------------#
# # Image Creation                                   #
# #--------------------------------------------------#


source "amazon-ebs" "flask" {
  ami_name                  = "Packer-AMI-${local.timestamp}"
  ami_description           = "Amazon Linux 2 Image-AMI Created Via Packer"
  instance_type             = "${var.instance_type}"
  region                    = "${var.region}"
  ssh_username              = "ec2-user"
  security_group_ids        = [ "sg-030cb941862974c4b"]
  source_ami_filter   {
    filters                 = {
      name                  = "amzn2-ami-hvm-2.0.*.1-x86_64-ebs"
      root-device-type      = "ebs"
      virtualization-type   = "hvm"
    }
    most_recent             = true
    owners                  = ["amazon"]
  }
 }
build {
  sources = ["source.amazon-ebs.flask"]

provisioner "ansible" {
      playbook_file = "/home/ubuntu/docker_flask.yml"
  }
}
