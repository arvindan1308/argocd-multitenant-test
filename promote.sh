#!/usr/bin/env bash
# render-and-promote.sh — merges each customer's values with the common
# defaults, validates the result, and only copies to argocd-apps/ (the
# folder that gets pushed) if every customer rendered cleanly.
set -uo pipefail
FAIL=0

mkdir -p staging argocd-apps

for f in apps/*/values.yaml; do
  [ -f "$f" ] || continue
  customer=$(basename "$(dirname "$f")")
  project=$(yq '.argoProject' "$f")

  echo "--- $customer ---"

  # 1. Render: merge common + customer values through the real chart
  if helm template "$customer" ./helm-chart \
      -f helm-chart/values-common.yaml -f "$f" > "/tmp/render_${customer}.yaml" 2>"/tmp/render_err_${customer}"; then
    echo "  PASS: helm template render"
  else
    echo "  FAIL: helm template render"
    cat "/tmp/render_err_${customer}"
    FAIL=1
    continue
  fi

  # 2. Generate this customer's Application CR into staging/
  sed -e "s/__CUSTOMER__/${customer}/g" -e "s/__PROJECT__/${project}/g" \
    ci/app-template.yaml > "staging/${customer}-app.yaml"

  # 3. Validate the generated Application CR is syntactically valid YAML
  if python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" \
      "staging/${customer}-app.yaml" 2>"/tmp/yamlerr_${customer}"; then
    echo "  PASS: generated Application CR is valid YAML"
  else
    echo "  FAIL: generated Application CR is invalid YAML"
    cat "/tmp/yamlerr_${customer}"
    FAIL=1
    continue
  fi
done

echo ""
if [ "$FAIL" -ne 0 ]; then
  echo "Errors found — nothing promoted. Fix the values file(s) or ci/app-template.yaml and re-run ./render-and-promote.sh"
  exit 1
fi

echo "All customers rendered and validated cleanly. Preview is in staging/:"
ls staging/
echo ""
read -r -p "Promote to argocd-apps/ now? [y/N] " CONFIRM
if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
  cp staging/*.yaml argocd-apps/
  echo "Promoted: $(ls argocd-apps/)"
  echo "Now run: git add apps/ argocd-apps/ && git commit -m '...' && git push"
else
  echo "Not promoted. Review staging/ further, then re-run this script when ready."
fi