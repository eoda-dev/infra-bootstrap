# k3s_Rancher

## Setup

sudo ./install-k3s-rancher.sh <NODE_IP> <BOOTSTRAP_PASSWORD>

## Enable Gatway-API

See also [https://docs.k3s.io/networking/networking-services#gateway-api](https://docs.k3s.io/networking/networking-services#gateway-api)

```bash
kubectl apply --server-side -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml
```

Add [k3s-traefik-config.yaml](k3s-traefik-config.yaml) to `/var/lib/rancher/k3s/server/manifests/k3s-traefik-config.yaml`.
