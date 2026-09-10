# flowable-docker-desktop-scripts

Deployment scripts for running the Flowable Platform locally on a single
`kind` cluster (`dev`/`test`/`stg` namespaces), backed by Docker Desktop (or
any Docker engine `kind` supports). Used as a git submodule by
`flowable-deploy-template-local`.

1) Set up the cluster (kind cluster, local registry, Traefik,
   optionally ARC):

   `% scripts/kind-cluster-setup.sh`

2) Deploy Flowable into a namespace:

   `% scripts/deploy-flowable-platform.sh dev`

Normally both are driven by `./create-env.sh` at the root of
`flowable-deploy-template-local` rather than called directly.
