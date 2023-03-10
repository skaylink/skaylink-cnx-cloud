#!/bin/bash

# Load Configuration
. ./installsettings.sh

# Check if any visible subnet is correctly tagged
subnets=$(aws ec2 describe-subnets --filters "Name=tag:kubernetes.io/cluster/${EKSName},Values=[owned,shared]" --query "Subnets[*].SubnetId" --region $AWSRegion --output text)

if [ -z "$subnets" ]; then
  echo
  echo "ERROR: No tagged subnets found."
  echo "Please make sure the right subnets are tagged."
  echo "Tag:"
  echo "  Key: kubernetes.io/cluster/${EKSName}"
  echo "  Value: 'shared' or 'owned'"
  echo "See https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html"
  exit 1
fi

echo "Found tagged subnets. Good."

echo "Checkng for public subnets"

# Check if any visible subnet is correctly tagged
subnets=$(aws ec2 describe-subnets --filters "Name=tag:kubernetes.io/role/elb,Values=1" --query "Subnets[*].SubnetId" --region $AWSRegion --output text)

if [ -z "$subnets" ]; then
  echo "WARNING: No public subnets found."
else
  echo "Public subnets found."
fi

echo "Checkng for private subnets"

# Check if any visible subnet is correctly tagged
subnets=$(aws ec2 describe-subnets --filters "Name=tag:kubernetes.io/role/internal-elb,Values=1" --query "Subnets[*].SubnetId" --region $AWSRegion --output text)

if [ -z "$subnets" ]; then
  echo "WARNING: No private subnets found."
else
  echo "Private subnets found."
fi

