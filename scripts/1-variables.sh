#!/bin/bash
REGION="us-east-1"
CLUSTER_NAME="tienda-perritos"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LABROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/LabRole"
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=vpc-07b79e673fd807ded" "Name=group-name,Values=default" \
  --query "SecurityGroups[0].GroupId" --output text --region $REGION)

echo "Account : $ACCOUNT_ID"
echo "LabRole : $LABROLE_ARN"
echo "SG      : $SG_ID"

# Exportar para que los siguientes scripts las usen
export REGION CLUSTER_NAME ACCOUNT_ID LABROLE_ARN SG_ID
