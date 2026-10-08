#!/bin/bash
set -e
NAMESPACE="${1:-staging}"
cd "$(dirname "$0")/../environments/staging"

SECRET_ARN=$(terraform output -raw rds_secret_arn)
ENDPOINT=$(terraform output -raw rds_endpoint)
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query SecretString --output text)

DB_USER=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['username'])")
DB_PASSWORD=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['password'])")

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic db-credentials \
  --namespace "$NAMESPACE" \
  --from-literal=DB_HOST="${ENDPOINT%%:*}" \
  --from-literal=DB_PORT="5432" \
  --from-literal=DB_NAME="appdb" \
  --from-literal=DB_USER="$DB_USER" \
  --from-literal=DB_PASSWORD="$DB_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -