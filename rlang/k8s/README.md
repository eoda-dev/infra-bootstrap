# rlang_k8s

```bash
kubectl exec -it r-base-pod -- R
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
