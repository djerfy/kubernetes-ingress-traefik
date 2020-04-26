#!/bin/bash

set -x

# tools version
VERSION_K3D="1.6.0"
VERSION_KUBE="1.17.3"

# create dir
if [ ! -e ".bin" ]; then
    mkdir -p .bin
    export PATH=".bin:${PATH}"
fi

# install k3d
if [ ! -e ".bin/k3d" ]; then
    wget https://github.com/rancher/k3d/releases/download/v${VERSION_K3D}/k3d-linux-amd64 \
        -O .bin/k3d
    chmod +x .bin/k3d
fi

# install kubectl
if [ ! -e ".bin/kubectl" ]; then
    wget https://storage.googleapis.com/kubernetes-release/release/v${VERSION_KUBE}/bin/linux/amd64/kubectl \
        -O .bin/kubectl
    chmod +x .bin/kubectl
fi

# check stack
if [ "$(k3d list | grep -v "No clusters found" | grep -c 'traefik-ci')" -eq "1" ]; then
    k3d delete --name traefik-ci
fi

# create stack
k3d create \
    --name traefik-ci \
    --workers 2 \
    --publish "80:80" \
    --publish "443:443" \
    --server-arg "--no-deploy=traefik"

# wait few seconds
sleep 20

# set kubeconfig
export KUBECONFIG="$(k3d get-kubeconfig --name='traefik-ci')"

# deploy traefik
kubectl -n kube-system apply -f ./ServiceAccount.yaml
kubectl -n kube-system apply -f ./ClusterRole.yaml
kubectl -n kube-system apply -f ./ClusterRoleBinding.yaml
kubectl -n kube-system apply -f ./CustomResourceDefinition.yaml
kubectl -n kube-system apply -f ./PersistentVolumeClaim.yaml
kubectl -n kube-system apply -f ./ConfigMap.yaml
kubectl -n kube-system apply -f ./TLSOption.yaml
kubectl -n kube-system apply -f ./Service.yaml
kubectl -n kube-system apply -f ./Secret.yaml
kubectl -n kube-system apply -f ./Middleware.yaml
kubectl -n kube-system apply -f ./Deployment.yaml
kubectl -n kube-system apply -f ./IngressRoute.yaml

# wait few seconds
sleep 60

# display
kubectl -n kube-system get pods

# test traefik
TEST1=$(kubectl -n kube-system get pods \
    | grep -E "^(svclb\-)?traefik\-ingress\-[a-z0-9]{5,10}(\-[a-z0-9]{5})?" \
    | grep -cv "Running")

# test dashboard
TEST2=$(curl -sL \
    -u traefik:traefik \
    -H "Host: traefik-dashboard.domain.tld" \
    "http://127.0.0.1:80/dashboard" \
    | grep -cv "Traefik UI")

# exit
exit $(echo "${TEST1} + ${TEST2}" | bc)
