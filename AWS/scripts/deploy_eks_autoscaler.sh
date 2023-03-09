#!/bin/bash

# Load Configuration
. ./installsettings.sh

#Create IAM Service Account
POL_NAME=AmazonEKSClusterAutoscalerPolicy

ARN=$(aws iam list-policies --query "Policies[?PolicyName=='$POL_NAME'].Arn" --output text)

if [ -z "$ARN" ]; then
  echo "ERROR: Policy $POL_NAME not found."
  exit 1 
fi

eksctl create iamserviceaccount \
  --cluster=$EKSName \
  --region=$AWSRegion \
  --namespace=kube-system \
  --name=cluster-autoscaler \
  --attach-policy-arn=$ARN \
  --override-existing-serviceaccounts \
  --approve


# Download Autoscaler configuration
curl -O https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

# Modify configuration
sed  "s/<YOUR CLUSTER NAME>/$EKSName/" cluster-autoscaler-autodiscover.yaml > cluster-autoscaler-autodiscover_$EKSName.yaml

# Apply the configuration
kubectl apply -f cluster-autoscaler-autodiscover_$EKSName.yaml

#Annotate the cluster-autoscaler service account
#kubectl annotate serviceaccount cluster-autoscaler \
#  -n kube-system \
#  eks.amazonaws.com/role-arn=$ARN

# Patch the deployment
kubectl patch deployment cluster-autoscaler \
  -n kube-system \
  -p '{"spec":{"template":{"metadata":{"annotations":{"cluster-autoscaler.kubernetes.io/safe-to-evict": "false"}}}}}'

# Patch Autoscaler
## Add command options
kubectl patch deployment cluster-autoscaler \
  -n kube-system \
  --type=json \
  -p '[{"op": "add", "path" : "/spec/template/spec/containers/0/command/-", "value" : "--balance-similar-node-groups"}]'

kubectl patch deployment cluster-autoscaler \
  -n kube-system \
  --type=json \
  -p '[{"op": "add", "path" : "/spec/template/spec/containers/0/command/-", "value" : "--skip-nodes-with-system-pods=false"}]'

## Correct used image
kubectl set image deployment cluster-autoscaler \
  -n kube-system \
  cluster-autoscaler=registry.k8s.io/autoscaling/cluster-autoscaler:v1.25.0

