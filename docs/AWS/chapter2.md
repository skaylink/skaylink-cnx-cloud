# 2 Create Kubernetes infrastructure on AWS

Choose an AWS region that suits your needs. See [Regions and Availability Zones](https://docs.aws.amazon.com/en_us/AWSEC2/latest/UserGuide/using-regions-availability-zones.html) for more details.  

This chapter follows the documentation from AWS [Getting Started with Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html).

## 2.1 Create environment configuration file

As some variables like your EKS Name is required more often, create a file with these variables:  
The file is called `installsettings.sh` and is placed in your home directory.  
Most of the scripts and commands reference to this file.


```
# Write our environment settings
cat > ~/installsettings.sh <<EOF
# Global
installversion=80

# Network
GlobalIngressPublic=1

# EKS settings
EKSName="cluster name e.g. cnx_test_eks" 
EKSVersion=1.25
EKSNodeType=t3a.large
## Depending on your installation
## Generic Worker: 2; Generic Worker + ES: 4
EKSNodeCount=2
EKSNodeCountMax=10
EKSNodeVolumeSize=100
EKSNodePublicKey="Your EC2 Key Name"
# Set to 1 if you want to use EKS private networking
EKSPrivateNetworking=1
# You can tag all resources created by EKS.
# Format: Key=Vaule,Key=Value
EKSTags=""
AWSRegion="Your AWS Region e.g. eu-west-1"
#VPCId=<VPC Id e.g. vpc-2345abcd>
SUBNETID=<List of Subnet IDs e.g.: subnet-a9189fe2,subnet-50432629>
# Set this to 1 in case you want to use the EKS auto scaling feature.
# If you enable this, choose a small worker node type
EKSAutoscale=1

# Route53
HostedZoneId="HostedZoneId"
HostedZoneIdPublic="HostedZoneIdPublic"

# EFS settings
storageclass=aws-efs

# ES settings
useStandaloneES=1
ESVersion=131
standaloneESHost=<Hostname of your ES Server end-point>
standaloneESPort=443

# ECR settings
ECRRegistry="your docker registry"
HCLRegisttry=hclcr.io
HCLHelmRegistry=https://hclcr.io/chartrepo/cnx
HCLUser="<Your Harbor username>"
HCLAccessKey="<Your Harbor access key>"

# Certificate related settings
acme_email="your enterprise email"
use_lestencrypt_prod="[true/false]"

# Component Pack
namespace=connections
GlobalDomainName="global domain name"
ic_admin_user="admin_user"
ic_admin_password='admin_password'
ic_internal="ic_internal"
ic_front_door="ic_front_door"
master_ip="master_ip"
# 6: "elasticsearch,customizer,orientme,kudos-boards"
# 7: "orientme,customizer,elasticsearch,elasticsearch7,teams,tailored-exp,cs_lite,ic360,cnx-mso-plugin,kudosboards"
starter_stack_list=""
# for test environments with just one node or no taint nodes, set to false.
nodeAffinityRequired=false
useSolr=0

# MSTeams
MSTeams=0
MSTeams_Tenant_ID=""
MSTeams_Client_ID=""
MSTeams_Client_Secret=""
MSTeams_Auth_Schema=0
MSTeams_Share_Service_Endpoint="/teams-share-service"
MSTeams_Share_UI_Files_API="/files/basic/api"
MSTeams_Redirect_URI=""

MSGraph_Client_ID=""
MSGraph_Client_Secret=""
MSGraph_Secret_Name=""
MSGraph_Auth_Endpoint="https://login.microsoftonline.com/common/"
MSGraph_Meta_Endpoint="v2.0/.well-known/openid-configuration"
MSGraph_Authorize_Endpoint="oauth2/v2.0/authorize"
MSGraph_Token_Endpoint="oauth2/v2.0/token"
MSGraph_Redirect_URI=""

Outlook_Client_Secret=""
Outlook_Support_URL="https://help.hcltechsw.com/connections/v7/connectors/enduser/c_ms_plugins_add_in_outlook.html"

# KUDOS
KudosPublicImages=1
KudosDockerAccount=""
KudosDockerSecret=""
KudosBoardsLicense=""
KudosBoardsClientSecret="this_value_must_be_filled_in_when_connections_is_up_and_running"
db2host="activites db host"
db2port=50000
oracleservice=
oracleconnect=''
cnxdbusr="activites db user"
cnxdbpwd='activites db password'
EOF

```

## 2.2 Create the EKS environment

For all options and probably adoptions in your environment see the `eksctl help` and the project [eksctl on GitHub](https://github.com/weaveworks/eksctl).

```
bash skaylink-cnx-cloud/AWS/scripts/create_eks_cluster.sh

```

After deployment which takes 10-15 minutes check that you can successfully communicate with your new cluster:  
Run command:

```
kubectl get svc

```

To use the autoscaler and / or EFS auto-provisioning feature, you need to add the OIDC provider to your cluster.

To do so, run:
```
# Load your variables
. ./installsettings.sh

# Add the OIDC provider to your cluster
eksctl utils associate-iam-oidc-provider --cluster $EKSName --region $AWSRegion --approve

```

### Autoscaler

**In case you want to use Autoscaler for your EKS cluster, you can follow the [Cluster Autoscaler](https://docs.aws.amazon.com/de_de/eks/latest/userguide/cluster-autoscaler.html) instructions.**

As alternative, here is a script with the condenst instructions:

```
bash skaylink-cnx-cloud/AWS/scripts/deploy_eks_autoscaler.sh

```

## 2.3 Create a AWS EFS Storage and Storage Class

Make sure, you added the OIDC provider to your cluster successfully during the previous step.

### 2.3.1 Create the EFS Storage

Create your EFS Storage by following the AWS documentation [Step 2: Create Your Amazon EFS File System](https://docs.aws.amazon.com/efs/latest/ug/gs-step-two-create-efs-resources.html).

* **Make sure you specify the VPC and all subnets of your EKS Cluster.**  
* **Add the Security groups from your worker and infra node to the Security Group of your EFS File System.**  
  **This security group was created automatically during step 2.2 Create the EKS environment**

The security group is named `eksctl-<EKSName>-cluster-ClusterSharedNodeSecurityGroup-<Random String>`

To use aws cli to create the EFS, use this script:

```
# run command
bash skaylink-cnx-cloud/AWS/scripts/create_efs.sh

```

**After EFS creation, wait 2 minutes until DNS is up to date.**

### 2.3.2 Create the efs provisioner

The provisioner is using the [Amazon EFS CSI driver](https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html)

Run this scripts to create an IAM policy and role:

```
# Load configuration
. ./installsettings.sh

# download manifest
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/master/docs/iam-policy-example.json

# Create the policy
aws iam create-policy \
    --policy-name AmazonEKS_EFS_CSI_Driver_Policy \
    --policy-document file://iam-policy-example.json

# Get ARN of policy 
ARN=$(aws iam list-policies --query "Policies[?PolicyName=='AmazonEKS_EFS_CSI_Driver_Policy'].Arn" --output text)

# Create the serviceaccount
eksctl create iamserviceaccount \
    --cluster $EKSName \
    --namespace kube-system \
    --name efs-csi-controller-sa \
    --attach-policy-arn $ARN \
    --approve \
    --region $AWSRegion

```
After the service account was created successfully, the provisioner can be deployed using helm.

The script below uses the most common account id. In case the helm upgrade command fails check the [Amazon container image registries](https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html) for the correct registry.

```
# check if this is correct
AWS_REGISTRY="602401143452.dkr.ecr.$AWSRegion.amazonaws.com"

# Add helm repo
helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver/
helm repo update


helm upgrade -i aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
    --namespace kube-system \
    --set image.repository=$AWS_REGISTRY/eks/aws-efs-csi-driver \
    --set controller.serviceAccount.create=false \
    --set controller.serviceAccount.name=efs-csi-controller-sa    
```

To check that your efs provisioner is deployed and running run  
`kubectl get pod -n kube-system -l "app.kubernetes.io/name=aws-efs-csi-driver,app.kubernetes.io/instance=aws-efs-csi-driver"`.

In case the container is not up and running after 2 minutes, check what went wrong by  
`kubectl describe pods -n kube-system -l "app.kubernetes.io/name=aws-efs-csi-driver,app.kubernetes.io/instance=aws-efs-csi-driver"`.

To restart the efs provisioner, delete the pod to get it recreated immediately.  
`kubectl  delete pods -n kube-system -l "app.kubernetes.io/name=aws-efs-csi-driver,app.kubernetes.io/instance=aws-efs-csi-driver"`

### 2.3.3 Create storage class 

Create the storage class using the EFS from above.

```
# Query filesystem id
fsid=$(aws efs describe-file-systems --query "FileSystems[?Name=='$EKSName'].FileSystemId" --output text)
echo Filesystem ID: $fsid

# Crate the storageclass
cat << EOF | kubectl apply -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: $storageclass
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: $fsid
  directoryPerms: "700"
  gidRangeStart: "1000" # optional
  gidRangeEnd: "2000" # optional
EOF
```


**[Create your AWS environment << ](chapter1.html) [ >> Prepare cluster](chapter3.html)**
