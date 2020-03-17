#!/bin/bash

# tools version
VERSION_K3D="1.6.0"
VERSION_KUBE="1.17.3"

# install k3d
wget https://github.com/rancher/k3d/releases/download/v${VERSION_K3D}/k3d-linux-amd64 \
    -O /usr/local/bin/k3d && chmod +x /usr/local/bin/k3d

# install kubectl
wget https://storage.googleapis.com/kubernetes-release/release/v${VERSION_KUBE}/bin/linux/amd64/kubectl \
    -O /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl

# create stack
k3d create \
    --name traefik-ci \
    --workers 2 \
    --publish "80:80" \
    --publish "443:443" \
    --server-arg "--no-deploy=traefik"

# wait few seconds
sleep 10

# set kubeconfig
export KUBECONFIG="$(k3d get-kubeconfig --name='traefik-ci')"

# deploy traefik
kubectl -n kube-system apply -f ./ServiceAccount.yaml
kubectl -n kube-system apply -f ./ClusterRole.yaml
kubectl -n kube-system apply -f ./ClusterRoleBinding.yaml
kubectl -n kube-system apply -f ./CustomResourceDefinition.yaml
kubectl -n kube-system apply -f ./PersistentVolumeClaim.yaml
kubectl -n kube-system apply -f ./ConfigMap.yaml
kubectl -n kube-system apply -f ./Service.yaml
kubectl -n kube-system apply -f ./Deployment.yaml

# wait few seconds
sleep 20

# test traefik
kubectl -n kube-system get pods \
    | grep -E "^(svclb\-)?traefik\-ingress\-[a-z0-9]{5,10}(\-[a-z0-9]{5})?" \
    | grep -v "Running" \
    && exit 1

# test dashboard
curl -sL \
    -u traefik:traefik \
    -H "Host: traefik-dashboard.domain.tld" \
    "http://127.0.0.1:80/dashboard" \
    | grep -v "Traefik UI" \
    && exit 1
