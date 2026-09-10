#!/bin/bash
set -o errexit

# Sets up a single Docker Desktop Kubernetes cluster to host the Flowable
# Platform's dev/test/stg namespaces. Replaces the old kind-cluster-setup.sh:
# no kind, no local registry, no per-namespace node containers - just the
# one built-in Docker Desktop node plus a single ingress-nginx install.
#
# Usage: ./docker-desktop-cluster-setup.sh [DISABLE_ARC]

PROJECT_DIR="${GITHUB_WORKSPACE:-$(pwd)}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$PROJECT_DIR/scripts}"
DISABLE_ARC="${1:-true}"

CONTEXT="$(kubectl config current-context 2>/dev/null || true)"
if [ "$CONTEXT" != "docker-desktop" ]; then
	echo
	echo "Error: kubectl's current context is '${CONTEXT:-<none>}', expected 'docker-desktop'."
	echo "Enable Kubernetes in Docker Desktop first: Settings -> Kubernetes -> Enable Kubernetes."
	echo "Once enabled, Docker Desktop adds and selects the 'docker-desktop' context automatically."
	exit 1
fi

echo "Using Kubernetes context 'docker-desktop'"

echo
echo "Installing ingress-nginx (single install, LoadBalancer service bound to localhost)"
helm upgrade --install ingress-nginx ingress-nginx \
	--repo https://kubernetes.github.io/ingress-nginx \
	--namespace ingress-nginx --create-namespace \
	--set controller.service.type=LoadBalancer

echo "Waiting for the ingress controller to be ready"
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=180s

echo
echo "DISABLE_ARC value is $DISABLE_ARC"
if [ "$DISABLE_ARC" != true ]; then
	echo "Setting up GitHub Action Runner to run inside cluster (opt-in)."
	"$SCRIPTS_DIR/add-github-action-runner.sh" "local"
fi
