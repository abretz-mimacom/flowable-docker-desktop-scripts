#!/bin/bash

# Meant to be sourced (not executed) so ARC_TOKEN lands in the caller's shell.
# ARC_TOKEN is a GitHub PAT with repo/admin:org scope used by
# actions-runner-controller to register the self-hosted runner - only needed
# if you've opted into the ARC/CI-CD demo (DISABLE_ARC=false).

echo
echo "Please provide a value for the following:"

if [ -n "$ARC_TOKEN" ]; then
    read -rsp "GitHub PAT for the Actions runner (ARC_TOKEN) [****]: " input
    echo
    ARC_TOKEN="${input:-$ARC_TOKEN}"
else
    read -rsp "GitHub PAT for the Actions runner (ARC_TOKEN): " ARC_TOKEN
    echo
fi

if [ -z "$ARC_TOKEN" ]; then
    echo "Error: ARC_TOKEN is required."
    return 1 2>/dev/null || exit 1
fi

export ARC_TOKEN
