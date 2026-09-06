#!/usr/bin/env bash
set -e
mkdir -p argocd-apps
for f in apps/*/values.yaml; do
  customer=$(basename "$(dirname "$f")")
  project=$(yq '.argoProject' "$f")

  echo "--- Merged manifest preview for $customer ---"
  helm template "$customer" ./helm-chart \
    -f helm-chart/values-common.yaml -f "$f"

  sed -e "s/__CUSTOMER__/${customer}/g" -e "s/__PROJECT__/${project}/g" \
    ci/app-template.yaml > "argocd-apps/${customer}-app.yaml"
done
echo "Generated: $(ls argocd-apps/)"