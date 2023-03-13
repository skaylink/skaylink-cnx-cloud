# 1 Create your AWS environment

## 1.1 VPC and Security Groups

Make sure you have a VPC with 2 or 3 subnets in a EKS Supported region.
The subnets should be in one in each availability zone and have at least 128 free IP Addresses.

Make sure you tagged your subnets properly to have the load balancer created properly. [Tag the Amazon VPC subnets](https://aws.amazon.com/premiumsupport/knowledge-center/eks-vpc-subnet-discovery/)


## 1.2 IAM Roles and Policies

Create an IAM Policy to allow your EKS Management Host access to manage the required resources on your behalf.  
It is possible to restrict the Policy further but for the test, this will do:

Create a new IAM Policy and name it "EKSFullAccess"

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "iam:CreateInstanceProfile",
                "iam:UntagRole",
                "iam:TagRole",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:CreateRole",
                "iam:AttachRolePolicy",
                "iam:PutRolePolicy",
                "iam:ListPolicies",
                "iam:AddRoleToInstanceProfile",
                "iam:ListInstanceProfilesForRole",
                "iam:PassRole",
                "iam:DetachRolePolicy",
                "iam:ListAttachedRolePolicies",
                "iam:DeleteRolePolicy",
                "iam:DeleteInstanceProfile",
                "iam:GetRole",
                "iam:GetInstanceProfile",
                "iam:DeleteRole",
                "iam:ListInstanceProfiles",
                "iam:TagUser",
                "iam:UntagUser",
                "iam:CreateServiceLinkedRole",
                "iam:DeleteServiceLinkedRole",
                "iam:GetOpenIDConnectProvider",
                "iam:CreateOpenIDConnectProvider",
                "iam:DeleteOpenIDConnectProvider",
                "iam:TagOpenIDConnectProvider",
                "iam:GetRolePolicy",
                "iam:CreatePolicy",
                "iam:DeletePolicy",
                "cloudformation:*",
                "eks:*"
            ],
            "Resource": "*"
        }
    ]
}
```

In case you want to manage your Route53 DNS zones from your EKS Management Host, create a new IAM Policy and name it "DNSAccess".

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:ListHostedZones",
                "route53:GetChange"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "route53:ChangeResourceRecordSets"
            ],
            "Resource": [
                "arn:aws:route53:::hostedzone/<ID of public Route53 zone>",
                "arn:aws:route53:::hostedzone/<ID of private Route53 zone>"
            ]
        }
    ]
}
```

Create a new IAM Role and name it "EKSManager".

Assign this policies to your new IAM Role:
* AmazonEC2FullAccess
* AmazonEKSWorkerNodePolicy
* AmazonEC2ContainerRegistryFullAccess
* AmazonElasticFileSystemFullAccess
* AmazonEKS_CNI_Policy
* EKSFullAccess
* DNSAccess  (optional)


## 1.2 Create an EKS Management Host in your VPC to administer your cluster

To administer your EKS cluster easily, create a administrative host, called the EKS Admin Host.

The admin host will be a small Linux host to upload docker images to the registry and administer the cluster.
It is recommended that the host is in the same VPC as your Kubernetes cluster. This will simplify the access to the cluster resources and the administration.

The host can use a very small server e.g. t3a.medium as no compute power is necessary.

**AWS Console**

Open the AWS Console and create the Management Host.
You can use a small instance type like t3a.medium.
Place the host into the the new VPC as you will use it for your Kubernetes Cluster.
Attach the EKSManager Role you created in 1.1 to the instance.

* Use CentOS, AlmaLinux, or AWS Linux as OS for the Management Host. Other Linux systems should also be possible as long as you can install Docker CE  or podman onto them.
All provided scripts are created on CentOS or RHEL Server. They are not tested with other Linux distributions. 
* Open port 22 (SSH) to access your Management Host from everywhere.
* Make sure a public IP is assigned. Either assign an Elastic IP afterwards or make sure "Auto-assign Public IP" is set to enable.
* Make sure you assign 60GB of Hard Disk space to your new instance. You need this disk space to extract the Component Pack.


## 1.3 Add the required software to your Management Host

Connect to your new host and install this software:

### 1.3.1 Add the epel repo and update the os:

```
sudo yum -y install epel-release
sudo yum update
sudo yum -y install vim nano unzip bind-utils

```

### 1.3.2 Install AWS CLI

Login to your new admin host using SSH and install the required tools:

```
# Install AWS CLI
sudo yum -y install epel-release
curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Check AWS CLI Version
aws --version

# Check AWS IAM Role that it contains the EKSManager role you created and assigned to your Management Host.
aws sts get-caller-identity
```

### 1.3.3 Install eksctl

download and install:

```
# Download and extract the latest release of eksctl with the following command.
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp

# Move the extracted binary to /usr/bin.
install /tmp/eksctl /usr/local/bin

# Test that your installation was successful with the following command.
eksctl version

```

### 1.3.4 Install git to clone this repository to have the scripts available.

```
sudo yum -y update
sudo yum -y install git
git clone https://github.com/skaylink/skaylink-cnx-cloud.git

```

### 1.3.5 Install and Configure kubectl for Amazon EKS

To install kubectl:

```
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
yum install -y kubectl

```

### 1.3.6 Install _aws-iam-authenticator_ for Amazon EKS

```
curl -Lo aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.5.9/aws-iam-authenticator_0.5.9_linux_amd64
install aws-iam-authenticator /usr/local/bin/

```

### 1.3.7 Install helm

**Install helm binary**

Download and extract the helm binaries:

```
# Download Helm
curl -LO "https://get.helm.sh/helm-v3.4.2-linux-amd64.tar.gz"

# Extract
tar -zxvf helm*

# Install
install $HOME/linux-amd64/helm /usr/local/bin

# check that helm is available
helm version --client

# add stable helm repo
helm repo add stable https://charts.helm.sh/stable

```

### 1.3.8 Install Docker / Podman

Docker or Podman is only necessary to deploy the Docker images into the registry or to build your own Docker images.

For the installation run the script:

```
# Run installation script
sudo bash $HOME/skaylink-cnx-cloud/AWS/scripts/install_docker.sh

## Docker
# grant your user docker rights
sudo usermod -a -G docker $USER
newgrp docker

# to check your docker version  and access rights run
docker version

## Podman
# to check your podman version run
podman version

```

### 1.3.9 Install Kubetail

Kubetail is a nice tool to view log output of multiple containers.

```
# Download kubetail
curl -o kubetail https://raw.githubusercontent.com/johanhaleby/kubetail/master/kubetail

# install
sudo install $PWD/kubetail /usr/local/bin

```


## 1.4 Schedule management host shutdown

On Azure you can configure your server to shut down on a certain time each day. This is quite handy so save some mony.

run this command as root to add the shutdown your management host a 7pm.

```
echo "0 19 * * * /usr/sbin/shutdown -h 10 'Power Off in 10 minutes'"| sudo crontab -

```


**[ >> Create Kubernetes infrastructure on AWS](chapter2.html)**
