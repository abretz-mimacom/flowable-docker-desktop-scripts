#!/bin/bash

# Meant to be sourced (not executed) so the exported vars land in the caller's shell.

echo "Please provide values for the following:"
echo

if [ -n "$FLOWABLE_REPO_USER" ]; then
    read -rp "Flowable repository username [$FLOWABLE_REPO_USER]: " input
    FLOWABLE_REPO_USER="${input:-$FLOWABLE_REPO_USER}"
else
    read -rp "Flowable repository username: " FLOWABLE_REPO_USER
fi

if [ -z "$FLOWABLE_REPO_USER" ]; then
    echo "Error: FLOWABLE_REPO_USER is required."
    return 1 2>/dev/null || exit 1
fi

if [ -n "$FLOWABLE_REPO_PASSWORD" ]; then
    read -rsp "Flowable repository password [****]: " input
    echo
    FLOWABLE_REPO_PASSWORD="${input:-$FLOWABLE_REPO_PASSWORD}"
else
    read -rsp "Flowable repository password: " FLOWABLE_REPO_PASSWORD
    echo
fi

if [ -z "$FLOWABLE_REPO_PASSWORD" ]; then
    echo "Error: FLOWABLE_REPO_PASSWORD is required."
    return 1 2>/dev/null || exit 1
fi

if [ -n "$FLOWABLE_LICENSE_PATH" ]; then
    read -rp "Flowable license file path [$FLOWABLE_LICENSE_PATH]: " input
    FLOWABLE_LICENSE_PATH="${input:-$FLOWABLE_LICENSE_PATH}"
else
    read -rp "Flowable license file path: " FLOWABLE_LICENSE_PATH
fi

FLOWABLE_LICENSE_KEY="$(cat "$FLOWABLE_LICENSE_PATH" 2>/dev/null || echo "")"

if [ -z "$FLOWABLE_LICENSE_KEY" ]; then
    echo "Error: FLOWABLE_LICENSE_KEY is required."
    return 1 2>/dev/null || exit 1
fi

export FLOWABLE_REPO_USER FLOWABLE_REPO_PASSWORD FLOWABLE_LICENSE_KEY FLOWABLE_LICENSE_PATH
