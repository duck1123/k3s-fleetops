#!/usr/bin/env bash
# Script to check if AMD GPU device plugin is enabled and working

echo "=== Checking for AMD GPU Device Plugin DaemonSet ==="
kubectl get daemonset -A | grep -i "amd\|gpu\|device"

echo ""
echo "=== Checking node resources for GPU availability ==="
kubectl describe node powerspecnix | grep -A 10 "Allocatable:\|Capacity:"

echo ""
echo "=== Checking if amd.com/gpu resource is available ==="
kubectl describe node powerspecnix | grep -i "amd.com/gpu"

echo ""
echo "=== Checking node labels ==="
kubectl get node powerspecnix --show-labels

echo ""
echo "=== Checking for device plugin pods ==="
kubectl get pods -A | grep -i "amd\|gpu\|device"

echo ""
echo "=== Checking node capacity and allocatable resources ==="
kubectl get node powerspecnix -o jsonpath='{.status.capacity}' | jq .
kubectl get node powerspecnix -o jsonpath='{.status.allocatable}' | jq .

echo ""
echo "=== Checking for GPU devices on the node ==="
kubectl get node powerspecnix -o yaml | grep -i "amd\|gpu" -A 5 -B 5

