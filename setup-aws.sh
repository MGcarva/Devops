#!/bin/bash
set -e

REGION="us-east-1"
CLUSTER_NAME="tienda-perritos"

echo "============================================"
echo " SETUP AWS - Tienda Perritos EKS"
echo "============================================"

# Obtener Account ID y LabRole automáticamente
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LABROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/LabRole"

echo "Account ID  : $ACCOUNT_ID"
echo "LabRole ARN : $LABROLE_ARN"
echo ""

# Obtener VPC default
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text \
  --region $REGION)
echo "VPC default : $VPC_ID"

# Obtener subnets de la VPC default (todas)
SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[*].SubnetId" \
  --output text \
  --region $REGION | tr '\t' ',')
echo "Subnets     : $SUBNET_IDS"

# Obtener security group default
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=default" \
  --query "SecurityGroups[0].GroupId" \
  --output text \
  --region $REGION)
echo "Security GR : $SG_ID"
echo ""

# ─────────────────────────────────────────────
# 1. CREAR REPOSITORIOS ECR
# ─────────────────────────────────────────────
echo ">>> Creando repositorios ECR..."

for REPO in tienda-frontend tienda-backend tienda-db; do
  if aws ecr describe-repositories --repository-names $REPO --region $REGION > /dev/null 2>&1; then
    echo "  [OK] $REPO ya existe"
  else
    aws ecr create-repository --repository-name $REPO --region $REGION > /dev/null
    echo "  [CREADO] $REPO"
  fi
done

ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
echo ""
echo "ECR Registry: $ECR_REGISTRY"
echo ""

# ─────────────────────────────────────────────
# 2. CREAR CLUSTER EKS
# ─────────────────────────────────────────────
echo ">>> Creando cluster EKS '$CLUSTER_NAME' (tarda ~15 min)..."

CLUSTER_STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query "cluster.status" --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$CLUSTER_STATUS" != "NOT_FOUND" ]; then
  echo "  [OK] Cluster ya existe con estado: $CLUSTER_STATUS"
else
  # Detectar la versión de Kubernetes soportada más reciente
  K8S_VERSION=$(aws eks describe-addon-versions \
    --region $REGION \
    --query "addons[0].addonVersions[0].compatibilities[].clusterVersion" \
    --output text | tr '\t' '\n' | sort -V | tail -1)
  echo "  Versión K8s detectada: $K8S_VERSION"

  aws eks create-cluster \
    --name $CLUSTER_NAME \
    --role-arn $LABROLE_ARN \
    --resources-vpc-config subnetIds=${SUBNET_IDS},securityGroupIds=${SG_ID} \
    --kubernetes-version $K8S_VERSION \
    --region $REGION > /dev/null

  echo "  Esperando que el cluster quede ACTIVE..."
  aws eks wait cluster-active --name $CLUSTER_NAME --region $REGION
  echo "  [ACTIVE] Cluster listo"
fi
echo ""

# ─────────────────────────────────────────────
# 3. CREAR NODE GROUP
# ─────────────────────────────────────────────
echo ">>> Creando node group 'workers'..."

NG_STATUS=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name workers --region $REGION --query "nodegroup.status" --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$NG_STATUS" != "NOT_FOUND" ]; then
  echo "  [OK] Node group ya existe con estado: $NG_STATUS"
else
  # Tomar las primeras 2 subnets para el node group
  SUBNET_ARRAY=(${SUBNET_IDS//,/ })
  NG_SUBNETS="${SUBNET_ARRAY[0]} ${SUBNET_ARRAY[1]}"

  aws eks create-nodegroup \
    --cluster-name $CLUSTER_NAME \
    --nodegroup-name workers \
    --node-role $LABROLE_ARN \
    --subnets $NG_SUBNETS \
    --instance-types t3.medium \
    --scaling-config minSize=1,maxSize=3,desiredSize=2 \
    --region $REGION > /dev/null

  echo "  Esperando que el node group quede ACTIVE (~5 min más)..."
  aws eks wait nodegroup-active --cluster-name $CLUSTER_NAME --nodegroup-name workers --region $REGION
  echo "  [ACTIVE] Node group listo"
fi
echo ""

# ─────────────────────────────────────────────
# RESUMEN FINAL
# ─────────────────────────────────────────────
echo "============================================"
echo " SETUP COMPLETADO"
echo "============================================"
echo ""
echo "Copia estos valores para los GitHub Secrets:"
echo ""
echo "  AWS_REGION          = $REGION"
echo "  EKS_CLUSTER_NAME    = $CLUSTER_NAME"
echo "  EKS_NAMESPACE       = tienda"
echo "  ECR_REGISTRY        = $ECR_REGISTRY"
echo ""
echo "Estos los sacas del boton 'AWS Details' del lab:"
echo "  AWS_ACCESS_KEY_ID"
echo "  AWS_SECRET_ACCESS_KEY"
echo "  AWS_SESSION_TOKEN"
echo ""
echo "URLs de tus repos ECR:"
echo "  Frontend : $ECR_REGISTRY/tienda-frontend"
echo "  Backend  : $ECR_REGISTRY/tienda-backend"
echo "  DB       : $ECR_REGISTRY/tienda-db"
echo ""
