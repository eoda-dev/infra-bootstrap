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

Start RStudio Server and forward it so it's reachable from outside the VM:

```bash
kubectl apply -f r-studio-pod.yml
kubectl port-forward --address 0.0.0.0 pod/r-studio-pod 8787:8787
```

Then open http://<vm-ip>:8787 in your browser (replace `<vm-ip>` with the VM's IP/hostname) and log in as user `rstudio` with `<your-password>`.

### Without auth

For quick local testing, `r-studio-pod-noauth.yml` disables login instead of requiring a secret:

```bash
kubectl apply -f r-studio-pod-noauth.yml
kubectl port-forward --address 0.0.0.0 pod/r-studio-pod-noauth 8787:8787
```
