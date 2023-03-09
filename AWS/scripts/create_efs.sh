. ~/installsettings.sh

# get the security group name: 
groupid=$(aws ec2 describe-security-groups \
  --region=$AWSRegion \
  --filter "Name=group-name,Values=eksctl-${EKSName}-cluster-ClusterSharedNodeSecurityGroup-*" \
  --query "SecurityGroups[*].{Name:GroupId}" \
  --output text)
echo $groupid

# Create EFS File System
aws efs create-file-system \
  --creation-token $EKSName \
  --performance-mode generalPurpose \
  --throughput-mode bursting \
  --tags Key=Name,Value="$EKSName" \
  --region $AWSRegion \
  --encrypted

#waiting
echo waiting 20 seconds for efs creation 
sleep 20

# Get FSId
efsid=$(aws efs describe-file-systems \
  --creation-token $EKSName \
  --query "FileSystems[*].FileSystemId" \
  --region $AWSRegion \
  --output text)
echo $efsid

# Create Mount Targets in every subnet
for sid in $(echo $SUBNETID| tr ',' ' ')
do aws efs create-mount-target \
--file-system-id $efsid \
--subnet-id  $sid \
--security-group $groupid \
--region $AWSRegion
done
