helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=rancher.klustered.us \
  --set bootstrapPassword=admin \
  --set ingress.tls.source=secret \
  --set ingress.tls.secretName=klustered-us-tls