#!/usr/bin/env bash
# Installs k3s (single node), cert-manager and Rancher, using sslip.io for DNS.
#
# Usage:   sudo ./install-k3s-rancher.sh <NODE_IP> <BOOTSTRAP_PASSWORD>
# Example: sudo ./install-k3s-rancher.sh 192.168.1.50 'MySecretPass123!'
#
# Optional environment variables:
#   K3S_CHANNEL   k3s release channel (default: v1.31) - must be supported by your Rancher version
#   K3S_VERSION   exact k3s version, e.g. v1.31.4+k3s1 (overrides K3S_CHANNEL)
#   RANCHER_REPO  rancher-latest | rancher-stable (default: rancher-stable)
#   CERT_MANAGER_VERSION  chart version (default: latest)

set -euo pipefail

# ---------- args ----------
if [[ $# -ne 2 ]]; then
  echo "Usage: sudo $0 <NODE_IP> <BOOTSTRAP_PASSWORD>" >&2
  exit 1
fi

NODE_IP="$1"
BOOTSTRAP_PASSWORD="$2"

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (sudo)." >&2
  exit 1
fi

if ! [[ "$NODE_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "Invalid IP address: $NODE_IP" >&2
  exit 1
fi

if [[ ${#BOOTSTRAP_PASSWORD} -lt 12 ]]; then
  echo "Bootstrap password must be at least 12 characters." >&2
  exit 1
fi

K3S_CHANNEL="${K3S_CHANNEL:-v1.31}"
RANCHER_REPO="${RANCHER_REPO:-rancher-stable}"
HOSTNAME_FQDN="rancher.${NODE_IP}.sslip.io"

# Escape characters that Helm's --set parser treats specially
ESCAPED_PASSWORD="${BOOTSTRAP_PASSWORD//\\/\\\\}"
ESCAPED_PASSWORD="${ESCAPED_PASSWORD//,/\\,}"

log() { echo -e "\n\033[1;32m==> $*\033[0m"; }

# ---------- 1. k3s ----------
if command -v k3s >/dev/null 2>&1; then
  log "k3s already installed, skipping"
else
  log "Installing k3s"
  if [[ -n "${K3S_VERSION:-}" ]]; then
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" sh -s - server
  else
    curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL="$K3S_CHANNEL" sh -s - server
  fi
fi

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

log "Waiting for the node to become Ready"
for _ in $(seq 1 60); do
  if kubectl get nodes 2>/dev/null | grep -q ' Ready'; then break; fi
  sleep 5
done
kubectl wait --for=condition=Ready node --all --timeout=120s

# Make kubeconfig available to the invoking user
if [[ -n "${SUDO_USER:-}" ]]; then
  USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  mkdir -p "$USER_HOME/.kube"
  cp "$KUBECONFIG" "$USER_HOME/.kube/config"
  chown -R "$SUDO_USER":"$(id -gn "$SUDO_USER")" "$USER_HOME/.kube"
fi

# ---------- 2. Helm ----------
if command -v helm >/dev/null 2>&1; then
  log "Helm already installed, skipping"
else
  log "Installing Helm"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# ---------- 3. cert-manager ----------
log "Installing cert-manager"
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update

CM_VERSION_ARG=()
[[ -n "${CERT_MANAGER_VERSION:-}" ]] && CM_VERSION_ARG=(--version "$CERT_MANAGER_VERSION")

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true \
  "${CM_VERSION_ARG[@]}" \
  --wait --timeout 5m

# ---------- 4. Rancher ----------
log "Installing Rancher at https://${HOSTNAME_FQDN}"
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest --force-update
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable --force-update
helm repo update

helm upgrade --install rancher "${RANCHER_REPO}/rancher" \
  --namespace cattle-system --create-namespace \
  --set hostname="$HOSTNAME_FQDN" \
  --set bootstrapPassword="$ESCAPED_PASSWORD" \
  --set replicas=1

log "Waiting for Rancher to roll out (can take a few minutes)"
kubectl -n cattle-system rollout status deploy/rancher --timeout=10m

# ---------- done ----------
cat <<EOF

--------------------------------------------------------------
 Rancher is ready.

   URL:      https://${HOSTNAME_FQDN}
   Password: (the bootstrap password you passed in)

 The certificate is self-signed, so your browser will warn once.
 Set a permanent admin password on first login.
--------------------------------------------------------------
EOF
