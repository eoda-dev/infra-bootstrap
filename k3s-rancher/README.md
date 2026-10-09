# K3s + Rancher

## Setup

```bash
sudo ./install-k3s-rancher.sh <NODE_IP> <BOOTSTRAP_PASSWORD>

curl -sfL https://raw.githubusercontent.com/eoda-dev/infra-bootstrap/main/k3s-rancher/install-k3s-rancher.sh | sudo sh -s <NODE_IP> <BOOTSTRAP_PASSWORD>
```

### Configure kubectl access

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER ~/.kube/config
export KUBECONFIG=~/.kube/config
```

## Enable Gateway-API

See also [https://docs.k3s.io/networking/networking-services#gateway-api](https://docs.k3s.io/networking/networking-services#gateway-api)

```bash
kubectl apply --server-side -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml
```

Add [k3s-traefik-config.yaml](k3s-traefik-config.yaml) to `/var/lib/rancher/k3s/server/manifests/k3s-traefik-config.yaml`.

## Argo CD + Gitea

```bash
./install-argocd-gitea.sh <NODE_IP> <GITEA_ADMIN_PASSWORD>

curl -fsSL https://raw.githubusercontent.com/eoda-dev/infra-bootstrap/main/k3s-rancher/install-argocd-gitea.sh | sh -s -- <NODE_IP> <GITEA_ADMIN_PASSWORD>
```

## Harbor

```bash
./install-harbor.sh <NODE_IP> <HARBOR_ADMIN_PASSWORD>

curl -fsSL https://raw.githubusercontent.com/eoda-dev/infra-bootstrap/main/k3s-rancher/install-harbor.sh | sh -s -- <NODE_IP> <HARBOR_ADMIN_PASSWORD>
```
