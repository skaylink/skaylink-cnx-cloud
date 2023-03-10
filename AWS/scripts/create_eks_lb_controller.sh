#!/bin/bash

# Load Configuration
. ./installsettings.sh

# Check if AWSLoadBalancerControllerIAMPolicy  already exists
POL_NAME=AWSLoadBalancerControllerIAMPolicy

echo "Check Policy $POL_NAME"

ARN=$(aws iam list-policies --query "Policies[?PolicyName=='$POL_NAME'].Arn" --output text)

if [ -z "$ARN" ]; then
  echo "Policy $POL_NAME not found. Creating...."
  curl -sO https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy.json
  aws iam create-policy \
    --policy-name $POL_NAME \
    --policy-document file://iam_policy.json
fi

ARN=$(aws iam list-policies --query "Policies[?PolicyName=='$POL_NAME'].Arn" --output text)

if [ -z "$ARN" ]; then
  echo "ERROR: Policy $POL_NAME still not found."
  exit 1 
fi

echo "Policy exists. Good."

echo "Check service Account"
kubectl get serviceaccount aws-load-balancer-controller -n kube-system > /dev/null 2>&1
if [ $? -gt 0 ]; then
  echo "Service Account does not exist. Creating..."

  eksctl create iamserviceaccount \
    --cluster=$EKSName \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --attach-policy-arn=$ARN \
    --approve
fi

kubectl get serviceaccount aws-load-balancer-controller -n kube-system > /dev/null 2>&1
if [ $? -gt 0 ]; then
  echo "ERROR: Service Account still does not exist."
  exit 1
fi

echo "Service Account exists."

echo "Check if controller already exists"
kubectl get deployment -n kube-system aws-load-balancer-controller > /dev/null 2>&1
if [ $? -gt 0 ]; then
  echo "Missing. Install the AWS Load Balancer Controller"

  helm repo add eks https://aws.github.io/eks-charts
  helm repo update
  
  helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set region=$AWSRegion \
    --set clusterName=$EKSName \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller 
fi

kubectl get deployment -n kube-system aws-load-balancer-controller > /dev/null 2>&1
if [ $? -gt 0 ]; then
  echo "ERROR: AWS Load Balancer Controller still missing."
  exit 1
fi

echo "AWS Load Balancer Controller exists."


