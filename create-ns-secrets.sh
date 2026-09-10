#!/bin/bash

set -o errexit

RELEASE_NAME="${2:-flowable}"
DEFAULT_LICENSE_FILE_PATH="$HOME/.flowable/flowable.license"
LICENSE_FILE_PATH="${3:-$DEFAULT_LICENSE_FILE_PATH}"
PROJECT_DIR="${GITHUB_WORKSPACE:-$(pwd)}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$PROJECT_DIR/scripts}"

echo
echo "Project directory is: $PROJECT_DIR"
echo "Scripts directory is: $SCRIPTS_DIR"


# Check for required argument (namespace)
if [ -z "$1" ]; then
  echo "must specify namespace for secret creation"
  exit 1
else
  echo "creating secrets for namespace: $1"
  DEPLOYMENT_NAMESPACE="$1"
fi

# Check if namespace exists, if not create it
if kubectl get namespace "$DEPLOYMENT_NAMESPACE" >/dev/null 2>&1; then
  echo "Namespace $DEPLOYMENT_NAMESPACE exists. Will not attempt to create it."
else
  echo "Namespace $DEPLOYMENT_NAMESPACE does not exist. Creating it now."
  source "$SCRIPTS_DIR/create-ns.sh" "$DEPLOYMENT_NAMESPACE"
fi

# Check for FLOWABLE_LICENSE_KEY - raw text value (set as a local env var, never committed)
if [ -z "$FLOWABLE_LICENSE_KEY" ]; then
  echo "FLOWABLE_LICENSE_KEY environment variable is not set. Your deployment is likely to fail."
else
  echo "FLOWABLE_LICENSE_KEY is set. Writing its contents to $DEFAULT_LICENSE_FILE_PATH"
  mkdir -p "$HOME/.flowable"
  echo "$FLOWABLE_LICENSE_KEY" > "$DEFAULT_LICENSE_FILE_PATH"
  chmod 600 "$DEFAULT_LICENSE_FILE_PATH" # likely not needed, but just in case
fi

if [ -z "$2" ]; then
  echo "no license file path specified, using $DEFAULT_LICENSE_FILE_PATH by default"
else
  echo "using license file path: $3"
fi



if [ -z "$FLOWABLE_REPO_USER" ]; then
  echo "must have FLOWABLE_REPO_USER env variable set for secret creation"
  exit 1
fi

if [ -z "$FLOWABLE_REPO_PASSWORD" ]; then
  echo "must have FLOWABLE_REPO_PASSWORD env variable set for secret creation"
  exit 1
fi

echo "Attempting to delete existing secrets to avoid 'AlreadyExists' errors"

source "$SCRIPTS_DIR/delete-ns-secrets.sh" "$DEPLOYMENT_NAMESPACE" "$RELEASE_NAME"

echo "Creating secrets in namespace: $DEPLOYMENT_NAMESPACE"

kubectl create secret docker-registry "$RELEASE_NAME-flowable-regcred" \
  --docker-server=repo.flowable.com \
  --docker-username="$FLOWABLE_REPO_USER"\
  --docker-password="$FLOWABLE_REPO_PASSWORD" \
  --namespace $DEPLOYMENT_NAMESPACE

kubectl create secret generic "$RELEASE_NAME-flowable-license" \
  --from-file=flowable.license="$LICENSE_FILE_PATH" \
  --namespace $DEPLOYMENT_NAMESPACE
