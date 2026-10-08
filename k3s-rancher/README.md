# k3s_Rancher

## Setup

```bash
sudo ./install-k3s-rancher.sh <NODE_IP> <BOOTSTRAP_PASSWORD>

curl -sfL https://raw.githubusercontent.com/eoda-dev/infra-bootstrap/main/k3s-rancher/install-k3s-rancher-posix.sh | sudo sh -s <NODE_IP> <BOOTSTRAP_PASSWORD>


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
