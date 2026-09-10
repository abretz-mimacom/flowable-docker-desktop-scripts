#!/usr/bin/env bash
set -euo pipefail

# Usage: ./delete-ns-secrets.sh <DEPLOYMENT_NAMESPACE> [RELEASE_NAME] [--all]

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <DEPLOYMENT_NAMESPACE> [RELEASE_NAME] [--all]"
    exit 1
fi

DEPLOYMENT_NAMESPACE="$1"
RELEASE_NAME="${2:-flowable}"
DELETE_ALL="${3:-}"

# List of secrets created by create-ns-secrets.sh
SECRETS=(
    "${RELEASE_NAME}-flowable-regcred"
    "${RELEASE_NAME}-flowable-license"
)

if [[ "$DELETE_ALL" == "--all" ]]; then
    echo "Deleting ALL secrets in namespace '$DEPLOYMENT_NAMESPACE'..."
    kubectl delete secrets --all -n "$DEPLOYMENT_NAMESPACE"
else
    echo "Deleting Flowable secrets in namespace '$DEPLOYMENT_NAMESPACE'..."
    for secret in "${SECRETS[@]}"; do
        if kubectl get secret "$secret" -n "$DEPLOYMENT_NAMESPACE" &>/dev/null; then
            kubectl delete secret "$secret" -n "$DEPLOYMENT_NAMESPACE"
            echo "Deleted secret: $secret"
        else
            echo "Secret not found: $secret"
        fi
    done
fi
