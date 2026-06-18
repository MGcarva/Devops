#!/bin/bash
REGION="us-east-1"
CLUSTER_NAME="tienda-perritos"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LABROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/LabRole"

echo "============================================"
echo " Creando Node Group: workers"
echo "============================================"
echo "Cluster : $CLUSTER_NAME"
echo "LabRole : $LABROLE_ARN"
echo ""

aws eks create-nodegroup \
  --cluster-name $CLUSTER_NAME \
  --nodegroup-name workers \
  --node-role $LABROLE_ARN \
  --subnets subnet-026bf0b9db41c70d6 subnet-0441c4cedb5814ad3 \
  --instance-types t3.medium \
  --scaling-config minSize=1,maxSize=3,desiredSize=2 \
  --region $REGION

if [ $? -ne 0 ]; then
  echo ""
  echo "[FALLO] No se pudo crear el node group. Revisa el error arriba."
  exit 1
fi

echo ""
echo "Esperando que el node group quede ACTIVE (~5 min)..."
aws eks wait nodegroup-active --cluster-name $CLUSTER_NAME --nodegroup-name workers --region $REGION

echo ""
echo "============================================"
echo " TODO LISTO"
echo "============================================"
echo ""
echo "Copia estos valores para los GitHub Secrets:"
echo ""
echo "  AWS_REGION       = $REGION"
echo "  EKS_CLUSTER_NAME = $CLUSTER_NAME"
echo "  EKS_NAMESPACE    = tienda"
echo ""
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "  (y estos del boton AWS Details del lab:)"
echo "  AWS_ACCESS_KEY_ID"
echo "  AWS_SECRET_ACCESS_KEY"
echo "  AWS_SESSION_TOKEN"
echo ""
echo "ECR URLs:"
echo "  528853233991.dkr.ecr.us-east-1.amazonaws.com/tienda-frontend"
echo "  528853233991.dkr.ecr.us-east-1.amazonaws.com/tienda-backend"
echo "  528853233991.dkr.ecr.us-east-1.amazonaws.com/tienda-db"
