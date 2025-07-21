#!/bin/bash

set -e

STACK_NAME="rds-stack"
TEMPLATE_FILE="templates/postgres-rds.yml"

STACK_STATUS=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query "Stacks[0].StackStatus" \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [[ "$STACK_STATUS" == "ROLLBACK_COMPLETE" || "$STACK_STATUS" == "CREATE_COMPLETE" ]]; then
  echo "El stack '$STACK_NAME' está en estado $STACK_STATUS. Eliminando..."
  aws cloudformation delete-stack --stack-name "$STACK_NAME"
  echo "Esperando que se elimine el stack..."
  aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME"
  echo "Stack eliminado. Continuando..."
elif [ "$STACK_STATUS" != "NOT_FOUND" ]; then
  echo "El stack '$STACK_NAME' ya existe con estado: $STACK_STATUS. No se puede continuar automáticamente."
  exit 1
fi

echo "Obteniendo VPC..."
VPC_ID=$(aws ec2 describe-vpcs \
  --query "Vpcs[0].VpcId" \
  --output text)

echo "VPC ID: $VPC_ID"

echo "Obteniendo 2 subnets en distintas zonas..."
SUBNETS=($(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[*].SubnetId" \
  --output text))

if [ ${#SUBNETS[@]} -lt 2 ]; then
  echo "No se encontraron al menos 2 subnets en el VPC $VPC_ID"
  exit 1
fi

SUBNET1=${SUBNETS[0]}
SUBNET2=${SUBNETS[1]}

echo "Subnet 1: $SUBNET1"
echo "Subnet 2: $SUBNET2"

echo "Desplegando stack: $STACK_NAME"
aws cloudformation deploy \
  --template-file "$TEMPLATE_FILE" \
  --stack-name "$STACK_NAME" \
  --parameter-overrides \
    VpcId="$VPC_ID" \
    Subnet1="$SUBNET1" \
    Subnet2="$SUBNET2" \
  --capabilities CAPABILITY_NAMED_IAM || DEPLOY_FAILED=true

FINAL_STATUS=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query "Stacks[0].StackStatus" \
  --output text)

if [ "$FINAL_STATUS" == "CREATE_COMPLETE" ]; then
  echo "Stack desplegado correctamente."
  echo "Obteniendo endpoint de RDS:"
  aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query "Stacks[0].Outputs[?OutputKey=='RdsEndpoint'].OutputValue" \
    --output text > rd2.txt
  echo "Endpoint guardado en rd2.txt"
else
  echo "El stack falló con estado: $FINAL_STATUS"
  echo "Buscando motivo del fallo..."

  ERROR_MESSAGE=$(aws cloudformation describe-stack-events \
    --stack-name "$STACK_NAME" \
    --query "StackEvents[?ResourceStatus=='CREATE_FAILED'] | [0].ResourceStatusReason" \
    --output text)

  echo "Motivo del fallo: $ERROR_MESSAGE"
  exit 1
fi
