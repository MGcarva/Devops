#!/bin/bash
REGION="us-east-1"
CLUSTER_NAME="tienda-perritos"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LABROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/LabRole"
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=vpc-07b79e673fd807ded" "Name=group-name,Values=default" \
  --query "SecurityGroups[0].GroupId" --output text --region $REGION)

echo "============================================"
echo " Creando cluster EKS: $CLUSTER_NAME"
echo "============================================"
echo "LabRole : $LABROLE_ARN"
echo "SG      : $SG_ID"
echo ""

aws eks create-cluster \
  --name $CLUSTER_NAME \
  --role-arn $LABROLE_ARN \
  --resources-vpc-config subnetIds=subnet-026bf0b9db41c70d6,subnet-0441c4cedb5814ad3,subnet-06168e2ac8431e666,subnet-0a28b5946545ffbe6,subnet-05df88c0315d44c52,securityGroupIds=$SG_ID \
  --kubernetes-version 1.33 \
  --region $REGION

if [ $? -ne 0 ]; then
  echo ""
  echo "[FALLO] No se pudo crear el cluster. Revisa el error arriba."
  exit 1
fi

echo ""
echo "Esperando que el cluster quede ACTIVE (~15 min)..."
echo "No cierres CloudShell."
echo ""
aws eks wait cluster-active --name $CLUSTER_NAME --region $REGION

echo ""
echo "============================================"
echo " CLUSTER LISTO - Ahora ejecuta el script 3"
echo "============================================"
