# rlang_k8s

## Setup

Run [install-rlang.sh](install-rlang.sh) to apply the manifests straight from GitHub `main`:

```bash
sh install-rlang.sh
```

Or fetch and run it directly via curl:

```bash
curl -Lf https://raw.githubusercontent.com/eoda-dev/infra-bootstrap/main/rlang/k8s/install-rlang.sh | sh
```

Or apply the manifests manually. Create the volume, install the R packages into it, then start the R pod that mounts it:

```bash
kubectl apply -f storage.yml
kubectl apply -f install-r-packages-job.yml
kubectl wait --for=condition=complete job/install-r-packages --timeout=300s
kubectl apply -f r-base-pod.yml
```

`install-r-packages-job.yml` installs its packages (`dplyr`, `ggplot2`, `tidyr`) into `/data` on the shared PVC, and `r-base-pod.yml` sets `R_LIBS_USER=/data` so R picks them up from the same volume.

Connect to R in the pod and use the installed packages directly:

```bash
kubectl exec -it r-base-pod -- R
```

```r
library(dplyr)
library(ggplot2)
library(tidyr)
```

## RStudio

Create the secret RStudio reads its login from:

```bash
kubectl create secret generic rstudio-auth --from-literal=password=<your-password>
```

Start RStudio Server and expose it on the node's host port via a `NodePort` Service:

```bash
kubectl apply -f r-studio-pod.yml
kubectl apply -f r-studio-service.yml
```

Or apply both directly from GitHub `main`:

```bash
kubectl apply -f https://raw.githubusercontent.com/eoda-dev/infra-bootstrap/main/rlang/k8s/r-studio-pod.yml
kubectl apply -f https://raw.githubusercontent.com/eoda-dev/infra-bootstrap/main/rlang/k8s/r-studio-service.yml
```

Then open http://<vm-ip>:30787 in your browser (replace `<vm-ip>` with the VM's IP/hostname) and log in as user `rstudio` with `<your-password>`.

Alternatively, without the Service, forward it directly:

```bash
kubectl port-forward --address 0.0.0.0 pod/r-studio-pod 8787:8787
```

### Firewall: restrict the NodePort (optional)

`r-studio-service.yml` exposes RStudio on NodePort `30787` on every node, reachable from anywhere that can reach the node. To instead only expose it through an nginx reverse proxy on port `3000`:

```bash
sudo cp nftables.conf /etc/nftables.conf
sudo nft -f /etc/nftables.conf

sudo cp nginx-rstudio.conf /etc/nginx/sites-available/rstudio-3000.conf
sudo ln -s /etc/nginx/sites-available/rstudio-3000.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

Or fetch both directly from GitHub `main`:

```bash
curl -Lf https://raw.githubusercontent.com/eoda-dev/infra-bootstrap/main/rlang/k8s/nftables.conf | sudo tee /etc/nftables.conf >/dev/null
sudo nft -f /etc/nftables.conf

curl -Lf https://raw.githubusercontent.com/eoda-dev/infra-bootstrap/main/rlang/k8s/nginx-rstudio.conf | sudo tee /etc/nginx/sites-available/rstudio-3000.conf >/dev/null
sudo ln -s /etc/nginx/sites-available/rstudio-3000.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

[nftables.conf](nftables.conf) drops external traffic to the NodePort range (`30000-32767`) on `eth0`, so only the host itself (nginx) can reach it. [nginx-rstudio.conf](nginx-rstudio.conf) proxies plain HTTP port `3000` to the RStudio NodePort (`127.0.0.1:30787`), including websocket upgrade headers RStudio needs.

Afterwards, open http://<vm-ip>:3000 instead of the NodePort directly.

### Without auth

For quick local testing, `r-studio-pod-noauth.yml` disables login instead of requiring a secret:

```bash
kubectl apply -f r-studio-pod-noauth.yml
kubectl port-forward --address 0.0.0.0 pod/r-studio-pod-noauth 8787:8787
```
