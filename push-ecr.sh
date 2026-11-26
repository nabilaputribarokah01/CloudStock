#!/usr/bin/env bash
set -euo pipefail
REGION="${1:?Usage: bash push-ecr.sh us-east-1}"
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"
URI="$REGISTRY/cloudstock-api"
aws ecr describe-repositories --region "$REGION" --repository-names cloudstock-api >/dev/null
aws ecr get-login-password --region "$REGION" | sudo docker login --username AWS --password-stdin "$REGISTRY"
trap 'sudo docker logout "$REGISTRY" >/dev/null 2>&1 || true' EXIT
sudo docker tag cloudstock-api:v1 "$URI:v1"
sudo docker push "$URI:v1"
aws ecr describe-images --region "$REGION" --repository-name cloudstock-api --image-ids imageTag=v1 --query 'imageDetails[0].{Tag:imageTags,Digest:imageDigest}' --output json
