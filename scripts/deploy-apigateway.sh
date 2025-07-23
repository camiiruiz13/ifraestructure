#!/bin/bash

set -e

API_STACK_NAME="api-gateway-stack"
API_TEMPLATE="templates/apigateway.yml"
REGION="us-east-1"

# Obtener ALB DNS desde el stack ECS existente
ECS_STACK_NAME="ecs-fargate-stack"
ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name "$ECS_STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='LoadBalancerDNS'].OutputValue" \
  --output text --region "$REGION")

if [[ -z "$ALB_DNS" ]]; then
  echo "Error: No se pudo obtener el DNS del Load Balancer desde el stack ECS ($ECS_STACK_NAME)"
  exit 1
fi

echo "DNS del Load Balancer obtenido: $ALB_DNS"

# Validar que el servicio en ECS esté saludable
echo "Verificando salud del servicio en http://$ALB_DNS/actuator/health ..."
for i in {1..15}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/actuator/health" || echo "000")
  if [[ "$STATUS" == "200" ]]; then
    echo "Servicio saludable. Responde con HTTP 200."
    break
  else
    echo "Esperando que el servicio esté saludable... intento $i/15 (status=$STATUS)"
    sleep 5
  fi
done

if [[ "$STATUS" != "200" ]]; then
  echo "Error: El contenedor no respondió correctamente en /actuator/health después de varios intentos."
  exit 1
fi

# Verificar si el stack de API Gateway ya existe
EXISTING_STACK=$(aws cloudformation describe-stacks \
  --stack-name "$API_STACK_NAME" \
  --region "$REGION" 2>/dev/null || true)

if [[ -n "$EXISTING_STACK" ]]; then
  echo "El stack $API_STACK_NAME ya existe. Eliminándolo..."
  aws cloudformation delete-stack --stack-name "$API_STACK_NAME" --region "$REGION"
  echo "Esperando que el stack sea eliminado..."
  aws cloudformation wait stack-delete-complete --stack-name "$API_STACK_NAME" --region "$REGION"
  echo "Stack eliminado correctamente."
fi

# Desplegar el API Gateway
echo "Desplegando API Gateway..."
aws cloudformation deploy \
  --template-file "$API_TEMPLATE" \
  --stack-name "$API_STACK_NAME" \
  --parameter-overrides AlbDNS="$ALB_DNS" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "$REGION"

echo "Esperando que el stack esté listo..."
aws cloudformation wait stack-create-complete \
  --stack-name "$API_STACK_NAME" \
  --region "$REGION"

# Obtener la URL del API Gateway
INVOKE_URL=$(aws cloudformation describe-stacks \
  --stack-name "$API_STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='ApiGatewayInvokeURL'].OutputValue" \
  --output text --region "$REGION")

echo "-------------------------------------------------------------"
echo "API Gateway desplegado correctamente."
echo "URL base para consumir la API: $INVOKE_URL"
echo "POST:   $INVOKE_URL/users"
echo "GET:    $INVOKE_URL/users/{identifier}"
echo "HEALTH: $INVOKE_URL/health"
echo "-------------------------------------------------------------"
