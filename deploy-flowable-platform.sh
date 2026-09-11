#!/bin/bash
set -e

# Usage: ./deploy-flowable-platform.sh <namespace> [release-name]
# <namespace>: Kubernetes namespace, e.g. dev|test|stg (required)
# [release-name]: Helm release name (default: flowable)

if [ -z "$1" ]; then
    echo
    echo "Usage: $0 <namespace> [release-name]"
    exit 1
fi

NAMESPACE="$1"
RELEASE_NAME="${2:-flowable}"

PROJECT_DIR="${GITHUB_WORKSPACE:-$(pwd)}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$PROJECT_DIR/scripts}"
echo
echo "Project directory is: $PROJECT_DIR"


# Check for required environment variables and prompt if any are missing
if [ -z "$FLOWABLE_REPO_USER" ] || [ -z "$FLOWABLE_REPO_PASSWORD" ] || [ -z "$FLOWABLE_LICENSE_KEY" ]; then
  echo
  echo "One or more required environment variables are not set."
  source "$SCRIPTS_DIR/prompt-secrets-input.sh"
  bash -c "echo \"Opening new shell to refresh secrets.\""
fi

# Ensure required environment variables are set
if [ -z "$FLOWABLE_REPO_USER" ] || [ -z "$FLOWABLE_REPO_PASSWORD" ]; then
    echo
    echo "Error: FLOWABLE_REPO_USER and FLOWABLE_REPO_PASSWORD must be set."
    exit 1
fi

# Check if namespace exists, if not create it
if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo
  echo "Namespace $NAMESPACE exists. Will not attempt to create it."
else
  echo
  echo "Namespace $NAMESPACE does not exist. Creating it now."
  source "$SCRIPTS_DIR/create-ns-secrets.sh" "$NAMESPACE" "$RELEASE_NAME"
fi

# stg's Work/Control envSecrets reference a flowable-github-oauth secret
# (see helm/stg/values.yaml, helm/templates/oauth2-configmap.yaml) for its
# GitHub OAuth2 login demo - nothing else creates it, so without this the
# pods sit in CreateContainerConfigError/"secret not found".
if [ "$NAMESPACE" = "stg" ]; then
  if [ -n "$OAUTH_CLIENT_ID" ] && [ -n "$OAUTH_CLIENT_SECRET" ]; then
    echo
    echo "Creating/updating flowable-github-oauth secret in namespace $NAMESPACE"
    kubectl create secret generic flowable-github-oauth \
      --from-literal=clientId="$OAUTH_CLIENT_ID" \
      --from-literal=clientSecret="$OAUTH_CLIENT_SECRET" \
      --namespace "$NAMESPACE" \
      --dry-run=client -o yaml | kubectl apply -f -
  else
    echo
    echo "Warning: OAUTH_CLIENT_ID/OAUTH_CLIENT_SECRET are not set - stg's"
    echo "flowable-work/flowable-control pods will fail to start until you"
    echo "export both and re-run, or create the 'flowable-github-oauth'"
    echo "secret in namespace $NAMESPACE yourself (keys: clientId, clientSecret)."
  fi
fi

# Add the Flowable Helm repo (--force-update so repeat calls - e.g. once per
# namespace from create-env.sh --all - don't fail with "repository name
# (flowable) already exists")
helm repo add flowable https://repo.flowable.com/flowable-helm \
    --username "$FLOWABLE_REPO_USER" \
    --password "$FLOWABLE_REPO_PASSWORD" \
    --force-update

helm repo update

# `update` (not `build`) so a stale/out-of-sync Chart.lock - e.g. after
# Chart.yaml's dependency version was bumped - is just re-resolved and
# rewritten instead of failing with "Chart.lock is out of sync"
helm dependency update "$PROJECT_DIR/helm/"

# Install or upgrade the Flowable platform chart from local ./helm directory
helm upgrade --install "$RELEASE_NAME" "$PROJECT_DIR/helm/" -f "$PROJECT_DIR/helm/$NAMESPACE/values.yaml" \
    --namespace "$NAMESPACE" \
    --create-namespace

echo
echo
echo "Flowable platform deployed with release name '$RELEASE_NAME' in namespace '$NAMESPACE'."
echo
echo
