#!/usr/bin/env bash
# Client-side Kubernetes check plus one local container start.
# Does not create a cluster.
set -euo pipefail
tgz="${1:?wsl tarball}"
ver="${2:?version}"
image="container.registry.frakma.io/warbletech/warble-linux:${ver}"
need() { command -v "$1" >/dev/null || { echo "missing $1" >&2; exit 1; }; }
need docker
need kubectl
tag="warble-k8s-test:$$"
docker import "$tgz" "$tag" >/dev/null
docker run --rm --user warble "$tag" bash -lc 'cat /etc/warble-release'
docker image rm "$tag" >/dev/null
dir=$(mktemp -d)
cat > "$dir/pod.yaml" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: warble-linux
  namespace: default
spec:
  containers:
    - name: warble
      image: ${image}
      command: ["bash", "-lc", "cat /etc/warble-release"]
EOF
kubectl apply --dry-run=client -f "$dir/pod.yaml"
rm -rf "$dir"
echo "k8s container ok ${image}"
