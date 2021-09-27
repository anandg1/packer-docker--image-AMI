# Building a PACKER IMAGE
[![Build Status](https://travis-ci.org/joemccann/dillinger.svg?branch=master)]()
### (Packer AMI with Ansible Provisioned Docker Container having Python Flask demo app using CI/CD feature of Jenkins)
## Description:
I going to create packer image having a docker container with flask application with the help of Ansible,Jenkins & Git , i.e, When ever the developer makes changes to the source file to build a docker image and updates changed files in git, with the help of 2 ansible playbooks pipeline via Jenkins, a new docker image is being built and pushed into the docker hub and the new image is then used to create a golden AMI using packer. 
 
## Pre-requesites:

- Basic Knowledge in AWS services, Ansible, Jenkins, Git , Flask and Packer.

PACKER is a tool for building identical machine images for multiple platforms from a single source configuration. It is also lightweight, runs on every major operating system, and is highly performant, creating machine images for multiple platforms in parallel.

FLASK is an API of Python that allows to build up web applications. Flask’s framework is more explicit than Django’s framework. A Web-Application Framework is the collection of modules and libraries that helps the developer to write applications without writing the low-level codes such as protocols, thread management.

## Features:

- Faster Deployment - Allows to launch, completely provision, and configured machines in seconds
- Automated scripts
 - Integration of Continuous Deployment feature of  Jenkins to makes the process simpler and faster.

 How to Install:
 
 Click to know more about Installation:
 1) [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
 2) [Jenkins](https://www.jenkins.io/doc/book/installing/linux/)
 3) [Packer](https://learn.hashicorp.com/tutorials/packer/get-started-install-cli)

 ## Detailed Explanation:
 
PHASE I:  Developers will be creating any custom flask application and once they finishes, they will upload the necessry  codes (Dockerfile,Requirements.txt and app.py) to the Github repository(here flask.git). A Jenkins, a pipeline job is set up to build a docker image using the present contents of Git which will be automatically triggered on recieving web hook from Git once the developer commits the changes. Now, a docker image will be created and uploaded to the docker hub account using an ansible playbook(build_push) triggered by Jenkins.

PHASE II:It includes the packer AMI building. This is done as a second part of the pipeline job configured in the Jenkins. Once the initial bild completes successfully in a stable state, Jenkins will trigger the second job and in that packer image will be built via the packer plugin in Jenkins. The packer build the golden AMI using the second ansible playbook(docker_flask). 
 
 ## Architecture:
![
alt_txt
](https://github.com/anandg1/packer-docker--image-AMI/blob/main/Arc.jpg)
 ## Code:
 Packer Code (packer.pkr.hcl) :
 
```sh
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
```
Ansible playbook 1 (build_push.yml) :
```sh
---
- name: "Docker Image build and push to docker hub"
  hosts: localhost
  become: true
  gather_facts: false
  vars:
    repo_url: "https://github.com/anandg1/flask.git"
    repo_dest: "/var/repository/"
    imageName: "anandgopinath/flask:latest"
    docker_password: "xxxxxxxx"
  tasks:
    - name: "Installing dependencies"
      apt:
        name: ['python3', 'apt-transport-https', 'ca-certificates', 'curl', 'software-properties-common', 'git', 'python3-pip']
        state: latest

    - name: "Adding gpg key"
      apt_key:
        url: https://download.docker.com/linux/ubuntu/gpg
        state: present

    - name: "Adding repositiries for docker"
      apt_repository:
        repo: deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable
        state: present

    - name: "Installing docker"
      apt:
        update_cache: yes
        name: docker-ce
        state: latest
      register: dockerValue

    - name: "Restarting and Enabling docker"
      when: dockerValue.changed
      service:
          name: docker
          state: restarted
          enabled: true

    - name: "Install Docker Python Module"
      pip:
        name: docker-py
        state: latest

    - name: "Cloning Repository"
      git:
        repo: "{{ repo_url }}"
        dest: "{{ repo_dest }}"
      register: repo_status

    - name: "Login to remote Repo"
      when: repo_status.changed
      docker_login:
        username: anandgopinath
        password: "{{ docker_password }}"

    - name: "Building image"
      docker_image:
        source: build
        build:
          path: "{{ repo_dest }}"
          pull: yes
        name: "{{ imageName }}"
        tag: "{{ item }}"
        push: true
        force_tag: yes
        force_source: yes
      with_items:
        - "{{ repo_status.after }}"
        - latest

    - name: "Removing image"
      docker_image:
        state: absent
        name: "{{ imageName }}"
        tag: "{{ item }}"
      with_items:
        - "{{ repo_status.after }}"
        - latest

```
Ansible playbook 2 (docker_flask.yml) :
```sh
---
- name: "Docker Container Creation"
  hosts: all
  become: yes
  vars:
    - imageName: "anandgopinath/flask:latest"
    - containerName: "web" 
    - ports: "80:5000"
  tasks:
    - name: "Docker Installation"
      shell: amazon-linux-extras install docker -y

    - name: "Package Installation"
      yum:
        name:
          - python-pip
        state: present

    - name: "Installing Docker extension"
      pip:
        name: docker-py

    - name: "Docker service Enable/Restart"
      service:
        name: docker
        state: restarted
        enabled: true
      register: dockerValue
       
    - name: "Restarting and Enabling docker"
      when: dockerValue.changed
      service:
          name: docker
          state: restarted
          enabled: true

    - name: "Install Docker-Python"
      pip:
        name: docker-py 
        state: latest

    - name: "Pulling httpd Docker Image"
      docker_image: 
        name: "{{imageName}}"
        source: pull
        state: present
        
    - name: "Creating Docker Container"
      docker_container:
        name: "{{containerName}}"
        detach: yes
        image: "{{imageName}}"
        ports: "{{ports}}"
        restart_policy: always
        state: started

```
## Git Webhook Setup:
1)  In your Git repo, move to settings ---> Webhooks
2) Fill the payload URL section with the below code.
```sh
http://< jenkins-server-IP >:8080/github-webhook/
```
Replace jenkins-server-IP with original IP/

## Jenkins Setup:

1) Open Jenkins using http://< serverIP >:8080 in browser
2) To install ansible plugin, go to Manage Jenkins --> Manage Plugins
3) Search 'Ansible' in search box in 'Available' section.
4) Tick Ansible and complete the installation
5) Navigate to Global Tool Configuration
6) Enter the name and executable path for the ansible. (executebale path can be obatined from 'which ansible' command's result in ansible master node)
7) Now, create new job in Jenkins by clicking 'freestyle project'
8) Now, in the source code management, provide the GitHub Repository name
9) Apply build procedure to invoke the ansible-playbook
10) Update the ansbilbe playbook file location.
11) Provide the vault credentials if the ansible file is already encrypted.
12) Update the Jenkins configuration to trigger the playbook when it recieves webhook by ticking the following
```sh
GitHub hook trigger for GITScm Polling
```
13) Change the 'Post-build Action' section to trigger the packer
13) Similarly, install the packer plugin as well.
14) Create a second project for packer.
15) During packer plugin configuration in the 'build' section, under 'packer template file' section, give the name of your packer file. (In my demonstartion it is 'packer.pkr.hcl').

## Conclusion:
Creating an automated HashiCorp Packer Golden AMI with the help of Jenkins, Git and Ansible has been completed successfully.
