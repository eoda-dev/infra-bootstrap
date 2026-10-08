#!/bin/sh
# Installs Harbor (container registry) on an existing k3s cluster
# (Traefik ingress, plain HTTP, sslip.io hostname). POSIX sh.
#
# Usage:   ./install-harbor.sh [NODE_IP] [HARBOR_ADMIN_PASSWORD]
# Or:      export NODE_IP=192.168.1.50 HARBOR_ADMIN_PASSWORD='ChangeMe-12345'
#          ./install-harbor.sh
# Or:      curl -fsSL <url> | sh -s -- 192.168.1.50 'ChangeMe-12345'
#
# Arguments take precedence over the env vars. Requires kubectl and helm on the PATH.
#
# Optional environment variables:
#   HARBOR_CHART_VERSION  chart version to install (default: latest)
#   HARBOR_NAMESPACE      namespace (default: harbor)
#   TRIVY_ENABLED         true | false, vulnerability scanner (default: true)
#   KUBECONFIG            kubeconfig path (default: /etc/rancher/k3s/k3s.yaml)

set -eu

NODE_IP="${1:-${NODE_IP:-}}"
HARBOR_ADMIN_PASSWORD="${2:-${HARBOR_ADMIN_PASSWORD:-}}"

if [ -z "$NODE_IP" ] || [ -z "$HARBOR_ADMIN_PASSWORD" ]; then
  echo "Usage: $0 [NODE_IP] [HARBOR_ADMIN_PASSWORD]  (or set them as env vars)" >&2
  exit 1
fi
if ! printf '%s\n' "$NODE_IP" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
  echo "Invalid IP address: $NODE_IP" >&2
  exit 1
fi

HARBOR_NAMESPACE="${HARBOR_NAMESPACE:-harbor}"
TRIVY_ENABLED="${TRIVY_ENABLED:-true}"
case "$TRIVY_ENABLED" in
  true|false) ;;
  *) echo "TRIVY_ENABLED must be true or false" >&2; exit 1 ;;
esac

KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
export KUBECONFIG
HARBOR_HOST="harbor.${NODE_IP}.sslip.io"

# Escape backslash and double quote so the password is safe inside a YAML "..." string
ESCAPED_PASSWORD="$(printf '%s' "$HARBOR_ADMIN_PASSWORD" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"

log() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }

kubectl get nodes >/dev/null   # fail early if the cluster is unreachable

# Optional chart version, passed through the positional parameters (no arrays in sh)
set --
if [ -n "${HARBOR_CHART_VERSION:-}" ]; then
  set -- --version "$HARBOR_CHART_VERSION"
fi

# ---------- Harbor ----------
log "Installing Harbor at http://${HARBOR_HOST} (this can take several minutes)"
helm repo add harbor https://helm.goharbor.io --force-update
helm repo update

helm upgrade --install harbor harbor/harbor \
  --namespace "$HARBOR_NAMESPACE" --create-namespace \
  "$@" \
  --wait --timeout 15m \
  -f - <<EOF
expose:
  type: ingress
  tls:
    enabled: false           # plain HTTP, like the other sslip.io setups
  ingress:
    className: traefik
    hosts:
      core: ${HARBOR_HOST}
    annotations:
      # chart default annotations that only apply when TLS is on
      ingress.kubernetes.io/ssl-redirect: null
      nginx.ingress.kubernetes.io/ssl-redirect: null
externalURL: http://${HARBOR_HOST}
harborAdminPassword: "${ESCAPED_PASSWORD}"
persistence:
  enabled: true              # k3s local-path storage
trivy:
  enabled: ${TRIVY_ENABLED}
EOF

cat <<EOF

--------------------------------------------------------------
 Harbor:  http://${HARBOR_HOST}
          user: admin / password: (the one you passed in)

 In-cluster core service: harbor-core.${HARBOR_NAMESPACE}.svc.cluster.local

 Because this is plain HTTP, clients must be told to trust it:
  - Docker:  add "${HARBOR_HOST}" to "insecure-registries" in
             /etc/docker/daemon.json, restart Docker, then
             docker login ${HARBOR_HOST} -u admin
  - k3s (to pull images from Harbor): create /etc/rancher/k3s/registries.yaml
             with a mirror/endpoint "http://${HARBOR_HOST}" and
             restart k3s.
--------------------------------------------------------------
EOF
