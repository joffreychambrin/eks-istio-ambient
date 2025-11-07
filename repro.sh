#!/usr/bin/env bash
set -euo pipefail

# --- settings ---
REGION=eu-central-1
CLUSTER=ambient-repro
NS=staging
ISTIO_VERSION=1.27.3

# --- create EKS cluster ---
# eksctl create cluster --name "$CLUSTER" --region "$REGION" --nodes 2 --node-type t3.large

# --- install Istio Ambient ---
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
cd "istio-$ISTIO_VERSION"
export PATH="$PWD/bin:$PATH"

istioctl install --set profile=ambient -y
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

# --- namespace + waypoint + access logs ---
kubectl create ns "$NS" || true
kubectl label ns "$NS" istio.io/dataplane-mode=ambient
istioctl waypoint apply -n "$NS" --name "$NS-waypoint" --enroll-namespace --wait --overwrite
kubectl -n "$NS" apply -f $PWD/../access-logs.yaml

# --- app deployments ---
kubectl -n "$NS" apply -f $PWD/../httpbin.yaml
kubectl -n "$NS" apply -f $PWD/../curl.yaml

# --- helper vars ---
CURLPOD=$(kubectl -n "$NS" get pod -l app=curl -o jsonpath='{.items[0].metadata.name}')

# --- repro loop ---
for i in $(seq 1 30); do
  echo "=== Attempt $i ==="
  kubectl -n "$NS" rollout restart deploy/httpbin
  kubectl -n "$NS" rollout status deploy/httpbin --timeout=120s
  sleep 7
  HTTPBINPOD=$(kubectl -n "$NS" get pod -l app=httpbin -o jsonpath='{.items[0].metadata.name}')
  CURLPODNAME=$(kubectl -n "$NS" exec "$CURLPOD" -- hostname)
  CODE=$(kubectl -n "$NS" exec "$CURLPOD" -- sh -lc 'curl -s -o /dev/null -w "%{http_code}" http://httpbin:8000/dump/request ' || echo "ERR")
  echo "curl code: $CODE from pod name $HTTPBINPOD"
  [ "$CODE" = "503" ] && echo "Hit 503!" && break
done
