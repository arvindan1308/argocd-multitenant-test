#!/usr/bin/env bash
set -e
mkdir -p argocd-apps
cp staging/*.yaml argocd-apps/
echo "Promoted: $(ls argocd-apps/)"
