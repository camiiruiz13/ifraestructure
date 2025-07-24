#!/bin/bash

# Obtener región desde el perfil configurado
REGION=$(aws configure get region)
if [ -z "$REGION" ]; then
  echo "Error: No se pudo obtener la región desde la configuración de AWS CLI."
  exit 1
fi

# Obtener ID de la cuenta AWS
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
if [ -z "$ACCOUNT_ID" ]; then
  echo "Error: No se pudo obtener el ID de cuenta AWS."
  exit 1
fi

# Configuración del repositorio e imagen
REPOSITORY_NAME="cruseraws/pragma"
IMAGE_NAME="reto-aws-users"
TAG="latest"
REPO_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPOSITORY_NAME}"

# Validar si la imagen local existe
if ! docker image inspect $IMAGE_NAME:$TAG > /dev/null 2>&1; then
  echo "Error: La imagen Docker local '$IMAGE_NAME:$TAG' no existe. Debes construirla primero con:"
  echo "       docker build -t $IMAGE_NAME ."
  exit 1
fi

# Autenticación en ECR
echo "Iniciando sesión en Amazon ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REPO_URI

# Etiquetar la imagen
echo "Etiquetando imagen como: $REPO_URI:$TAG"
docker tag $IMAGE_NAME:$TAG $REPO_URI:$TAG

# Subir la imagen
echo "Subiendo imagen a ECR..."
docker push $REPO_URI:$TAG

echo "Imagen publicada exitosamente en: $REPO_URI:$TAG"
