#!/bin/bash

set -e

# Variables
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"
REPOSITORY_NAME="reto-aws-users"
IMAGE_TAG="latest"

# Construir el nombre completo del repositorio ECR
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPOSITORY_NAME}:${IMAGE_TAG}"

echo "Iniciando sesión en ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "Verificando si el repositorio ECR existe..."
aws ecr describe-repositories --repository-names $REPOSITORY_NAME --region $REGION > /dev/null 2>&1 || {
    echo "Repositorio no existe. Creándolo..."
    aws ecr create-repository --repository-name $REPOSITORY_NAME --region $REGION
}

echo "Taggeando imagen local 'reto-aws-users:latest' a $ECR_URI..."
docker tag reto-aws-users:latest $ECR_URI

echo "Haciendo push de la imagen a ECR..."
docker push $ECR_URI

echo "Imagen publicada en ECR exitosamente: $ECR_URI"
