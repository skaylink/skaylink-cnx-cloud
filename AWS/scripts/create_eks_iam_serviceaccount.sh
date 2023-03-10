#!/bin/bash

. ./installsettings.sh

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

