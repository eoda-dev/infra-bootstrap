#!/bin/sh
# Installs Gitea and Argo CD on an existing k3s cluster (Traefik ingress, sslip.io hostnames).
# POSIX sh version: no bash-only features (no [[ ]], =~, echo -e, pipefail).
#
# Usage:   ./install-argocd-gitea-posix.sh [NODE_IP] [GITEA_ADMIN_PASSWORD]
# Or:      export NODE_IP=192.168.1.50 GITEA_ADMIN_PASSWORD='ChangeMe-12345'
#          ./install-argocd-gitea-posix.sh
# Or:      curl -fsSL <url> | sh -s -- 192.168.1.50 'ChangeMe-12345'
#
# Arguments take precedence over the env vars. Requires kubectl and helm on the PATH.
# Gitea runs with SQLite and persistent storage (k3s local-path), which suits a single node.

set -eu

NODE_IP="${1:-${NODE_IP:-}}"
GITEA_ADMIN_PASSWORD="${2:-${GITEA_ADMIN_PASSWORD:-}}"

if [ -z "$NODE_IP" ] || [ -z "$GITEA_ADMIN_PASSWORD" ]; then
  echo "Usage: $0 [NODE_IP] [GITEA_ADMIN_PASSWORD]  (or set them as env vars)" >&2
  exit 1
fi
if ! printf '%s\n' "$NODE_IP" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
  echo "Invalid IP address: $NODE_IP" >&2
  exit 1
fi

KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
export KUBECONFIG
GITEA_HOST="gitea.${NODE_IP}.sslip.io"
ARGOCD_HOST="argocd.${NODE_IP}.sslip.io"

log() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }

kubectl get nodes >/dev/null   # fail early if the cluster is unreachable

# ---------- Gitea ----------
log "Installing Gitea at http://${GITEA_HOST}"
helm repo add gitea-charts https://dl.gitea.com/charts/ --force-update
helm repo update

helm upgrade --install gitea gitea-charts/gitea \
  --namespace gitea --create-namespace \
  --wait --timeout 10m \
  -f - <<EOF
service:
  http:
    type: ClusterIP
ingress:
  enabled: true
  className: traefik
  hosts:
    - host: ${GITEA_HOST}
      paths:
        - path: /
          pathType: Prefix
persistence:
  enabled: true
# no HA dependencies, SQLite instead of PostgreSQL
valkey-cluster:
  enabled: false
valkey:
  enabled: false
postgresql:
  enabled: false
postgresql-ha:
  enabled: false
gitea:
  admin:
    username: gitea_admin
    password: "${GITEA_ADMIN_PASSWORD}"
    email: admin@${GITEA_HOST}
  config:
    database:
      DB_TYPE: sqlite3
    session:
      PROVIDER: memory
    cache:
      ADAPTER: memory
    queue:
      TYPE: level
EOF

# ---------- Argo CD ----------
log "Installing Argo CD at http://${ARGOCD_HOST}"
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --wait --timeout 10m \
  -f - <<EOF
global:
  domain: ${ARGOCD_HOST}
configs:
  params:
    server.insecure: true      # Traefik serves plain HTTP, no TLS redirect loop
server:
  ingress:
    enabled: true
    ingressClassName: traefik
EOF

ARGO_PW="$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)"

cat <<EOF

--------------------------------------------------------------
 Gitea:   http://${GITEA_HOST}
          user: gitea_admin / password: (the one you passed in)

 Argo CD: http://${ARGOCD_HOST}
          user: admin / password: ${ARGO_PW:-<see argocd-initial-admin-secret>}

 In-cluster Gitea URL for Argo CD repos:
   http://gitea-http.gitea.svc.cluster.local:3000/<org>/<repo>.git
--------------------------------------------------------------
EOF
