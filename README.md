# flowable-docker-desktop-scripts

Deployment scripts for running the Flowable Platform locally on Docker
Desktop's built-in Kubernetes (single node, one cluster, `dev`/`test`/`stg`
namespaces). Used as a git submodule by `flowable-deploy-template-local`.

1) Enable Kubernetes in Docker Desktop (Settings -> Kubernetes -> Enable
   Kubernetes), then set up the cluster (ingress-nginx, optionally ARC):

   `% scripts/docker-desktop-cluster-setup.sh`

2) Deploy Flowable into a namespace:

   `% scripts/deploy-flowable-platform.sh dev`

Normally both are driven by `./create-env.sh` at the root of
`flowable-deploy-template-local` rather than called directly.
