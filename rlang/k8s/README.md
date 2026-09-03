# rlang_k8s

```bash
kubectl exec -it r-base-pod -- R
```

## RStudio

Start RStudio Server (auth disabled for local use) and forward it so it's reachable from outside the VM:

```bash
kubectl apply -f r-studio-pod.yml
kubectl port-forward --address 0.0.0.0 pod/r-studio-pod 8787:8787
```

Then open http://<vm-ip>:8787 in your browser (replace `<vm-ip>` with the VM's IP/hostname).
