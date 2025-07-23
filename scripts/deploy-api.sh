#!/bin/bash

# Parámetros
CLUSTER_NAME="aws-cluster-reto"
SERVICE_NAME="reto-api-service"
TASK_DEFINITION="reto-api-task"
CONTAINER_NAME="reto-api-container"
CONTAINER_PORT=8080
TARGET_GROUP_ARN="arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/reto-target-group/abc1234567890def" # Reemplazar
SUBNET1="subnet-0d6f59726529bde57"
SUBNET2="subnet-037dbc00be0a1c097"
SECURITY_GROUP="sg-xxxxxxxxxxxxxxxxx"

# Verifica si el servicio ya existe
SERVICE_EXISTS=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --query "services[0].status" \
  --output text 2>/dev/null)

if [[ "$SERVICE_EXISTS" != "ACTIVE" && "$SERVICE_EXISTS" != "DRAINING" ]]; then
  echo "El servicio $SERVICE_NAME no existe. Se creará uno nuevo."
else
  echo "El servicio $SERVICE_NAME ya existe. Eliminando..."
  aws ecs delete-service \
    --cluster "$CLUSTER_NAME" \
    --service "$SERVICE_NAME" \
    --force

  echo "Esperando que el servicio se elimine..."
  while true; do
    STATUS=$(aws ecs describe-services \
      --cluster "$CLUSTER_NAME" \
      --services "$SERVICE_NAME" \
      --query "services[0].status" \
      --output text 2>/dev/null)

    if [[ "$STATUS" == "None" || "$STATUS" == "null" ]]; then
      echo "El servicio ha sido eliminado correctamente."
      break
    fi

    echo "Esperando... Estado actual: $STATUS"
    sleep 5
  done
fi

echo "Creando el servicio $SERVICE_NAME..."

aws ecs create-service \
  --cluster "$CLUSTER_NAME" \
  --service-name "$SERVICE_NAME" \
  --task-definition "$TASK_DEFINITION" \
  --launch-type "FARGATE" \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET1,$SUBNET2],securityGroups=[$SECURITY_GROUP],assignPublicIp=ENABLED}" \
  --load-balancers "targetGroupArn=$TARGET_GROUP_ARN,containerName=$CONTAINER_NAME,containerPort=$CONTAINER_PORT}" \
  --desired-count 1

echo "Servicio $SERVICE_NAME creado exitosamente."
