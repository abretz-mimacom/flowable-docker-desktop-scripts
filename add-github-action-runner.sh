#!/bin/bash
set -o errexit

CLUSTER_NAME="${1:-local}"
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$PROJECT_DIR/scripts}"

echo
echo
echo "Setting up Cert Manager in Kubernetes"
helm upgrade --install \
  cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.18.2 \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true

# Wait for cert-manager (optional but wise)
kubectl -n cert-manager rollout status deploy/cert-manager --timeout=120s
kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=120s
kubectl -n cert-manager rollout status deploy/cert-manager-cainjector --timeout=120s

# Namespaces
kubectl get ns actions-runner-system >/dev/null 2>&1 || kubectl create ns actions-runner-system
kubectl get ns arc-runners >/dev/null 2>&1 || kubectl create ns arc-runners

helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm repo update

# Check for ARC_TOKEN and prompt if not set
if [ -z "$ARC_TOKEN" ]; then
  echo
  echo "ARC_TOKEN variable are not set."
  source $SCRIPTS_DIR/prompt-arc-token.sh
  bash -c "echo \"Opening new shell to get lastest env.\""
  echo
fi

# Let Helm create the secret & own it; pass the token via values
helm upgrade --install actions-runner-controller \
  actions-runner-controller/actions-runner-controller \
  --namespace actions-runner-system \
  --set authSecret.create=true \
  --set authSecret.github_token="${ARC_TOKEN}" \

# ARC controller + webhook
kubectl -n actions-runner-system rollout status deploy/actions-runner-controller --timeout=180s

echo "Waiting for ARC controller webhook service to be ready"
ehco
sleep 15


echo "Applying GitHub Actions RunnerDeployment"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: apps
---
apiVersion: v1
kind: Namespace
metadata:
  name: ci
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gh-runner
  namespace: ci
automountServiceAccountToken: true
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: gh-runner-read-cluster
rules:
  - apiGroups: ["", "apps", "ci"]
    resources: ["pods", "configmaps", "secrets", "services", "deployments", "replicasets", "namespaces", "statefulsets", "daemonsets", "jobs", "cronjobs", "ingresses", "networkpolicies", "pods", "pods/log", "pods/exec", "serviceaccounts", "persistentvolumeclaims"]
    verbs: ["get","list","watch","create","update","patch","delete"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["networkpolicies"]
    verbs: ["get","list","watch","create","update","patch","delete"]
  - apiGroups: ["policy"]
    resources: ["poddisruptionbudgets"]
    verbs: ["get","list","watch","create","update","patch","delete"]
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get","list","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: gh-runner-read-cluster
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: gh-runner-read-cluster
subjects:
  - kind: ServiceAccount
    name: gh-runner
    namespace: ci
---
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: repo-runner
  namespace: ci
spec:
  replicas: 1
  template:
    spec:
      repository: "${GITHUB_REPOSITORY}"
      labels: [self-hosted, arc, "${CLUSTER_NAME}"]
      serviceAccountName: gh-runner
EOF
echo
echo
