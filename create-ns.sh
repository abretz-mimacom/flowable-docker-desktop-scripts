#!/bin/bash
set -o errexit

if [ -z "$1" ]; then
  echo "must specify namespace for creation"
  exit 1
else
  echo "creating namespace: $1"
  DEPLOYMENT_NAMESPACE=$1
fi

kubectl create namespace $DEPLOYMENT_NAMESPACE
