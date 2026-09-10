#!/bin/bash
set -o errexit

# Sets up a single single-node kind cluster to host the Flowable Platform's
# dev/test/stg namespaces (one cluster instead of the original two - "qa"
# and "prod" - each of which was its own 3-node kind cluster; the extra
# nodes weren't buying anything for a local demo, just more containers to
# run). Keeps the same kind mechanics as before (local registry, DaemonSet
# ingress controller, optional ARC), just consolidated onto one node, with
# extraPortMappings/extraMounts on that node so the ingress is reachable
# directly on localhost:80/443 without a manual `kubectl port-forward` step.
#
# Uses Traefik as the ingress controller (ingress-nginx - the
# kubernetes/ingress-nginx project - is in maintenance mode/being retired
# upstream; Traefik is actively maintained and needs no extra CRDs for
# plain Kubernetes Ingress resources).
#
# Usage: ./kind-cluster-setup.sh [CLUSTER_NAME] [DISABLE_ARC]

PROJECT_DIR="${GITHUB_WORKSPACE:-$(pwd)}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$PROJECT_DIR/scripts}"
CLUSTER_NAME="${1:-local}"
DISABLE_ARC="${2:-true}"
EXTRA_MOUNT_HOST_PATH="${EXTRA_MOUNT_HOST_PATH:-$PROJECT_DIR/docker}"

# 1. Create registry container unless it already exists
reg_name='kind-registry'
reg_port='5001'
if [ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]; then
  docker run \
    -d --restart=always -p "127.0.0.1:${reg_port}:5000" --network bridge --name "${reg_name}" \
    registry:2
fi

if ! command -v kind >/dev/null 2>&1; then
  echo "kind not found, installing..."
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found, installing..."
    NONINTERACTIVE=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
  brew install kind derailed/k9s/k9s
fi

# 2. Create the kind cluster (single node - kind lifts the control-plane's
# NoSchedule taint automatically when it's the only node, so it happily
# runs Traefik/ARC/Flowable pods too) unless it already exists
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "kind cluster '$CLUSTER_NAME' already exists, reusing it"
else
  echo "Creating single-node kind cluster ${CLUSTER_NAME}..."
  cat <<EOF | kind create cluster --name "$CLUSTER_NAME" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: "${CLUSTER_NAME}"
nodes:
  - role: control-plane
    extraMounts:
      - hostPath: "${EXTRA_MOUNT_HOST_PATH}"
        containerPath: /extra-mount
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"
EOF
fi

# 3. Add the registry config to the nodes
REGISTRY_DIR="/etc/containerd/certs.d/localhost:${reg_port}"
for node in $(kind get nodes --name "$CLUSTER_NAME"); do
  docker exec "${node}" mkdir -p "${REGISTRY_DIR}"
  cat <<EOF | docker exec -i "${node}" cp /dev/stdin "${REGISTRY_DIR}/hosts.toml"
[host."http://${reg_name}:5000"]
EOF
done

# 4. Connect the registry to the cluster network if not already connected
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}")" = 'null' ]; then
  docker network connect "kind" "${reg_name}"
fi

# 5. Document the local registry
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

# 6. Add ingress controller (Traefik, one install for the whole cluster).
# DaemonSet + hostPort (instead of the chart's default LoadBalancer Service,
# which kind can't fulfill) so the control-plane node's extraPortMappings
# above forward host 80/443 straight into the Traefik pod on that node.
helm upgrade --install traefik traefik --repo https://traefik.github.io/charts --set deployment.kind=DaemonSet --set ports.web.hostPort=80 --set ports.websecure.hostPort=443 --set service.type=ClusterIP --namespace traefik --create-namespace

echo "Waiting for the Traefik ingress controller to be ready"
kubectl -n traefik rollout status daemonset/traefik --timeout=180s || sleep 15

# 7. Add github action runner (opt-in)
echo
echo "DISABLE_ARC value is $DISABLE_ARC".
if [ "$DISABLE_ARC" != true ]; then
  echo "Setting up GitHub Action Runner to run inside cluster."
  echo
  "$SCRIPTS_DIR/add-github-action-runner.sh" "$CLUSTER_NAME"
fi
