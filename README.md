Create a new EKS cluster
```bash
eksctl create cluster
```

Install Istio, httpbin and curl
```bash
istioctl install --set profile=ambient --skip-confirmation
kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml

kubectl create namespace staging
kubectl label ns staging istio.io/dataplane-mode=ambient
istioctl waypoint apply --enroll-namespace --wait -n staging

kubens staging
kubectl apply -f access-logs.yaml
kubectl apply -f httpbin.yaml
kubectl apply -f curl.yaml
```

Tests

I executed this action 5 times: it succeeded on attempts 1-4 but failed on the 5th attempt.
```bash
kubectl rollout restart deploy httpbin
# Then, wait 20 seconds
kubectl exec -it curl-74c989df8d-vdjgs -- curl http://httpbin:8000/dump/request
```

Timeline
1. Container started at: "lastTimestamp": "2025-10-15T03:29:49Z"
2. Kube probe OK at 2025-10-15T03:29:52Z
3. curl 503 error at 2025-10-15T03:30:00Z