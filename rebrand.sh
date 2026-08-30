#!/usr/bin/env bash
# Rebrand this repo in one shot, in case the GitHub org slug, the chart domain or the
# ingest endpoint differ from the defaults.
#
#   ./rebrand.sh <github-org> <chart-host> <ingest-host> [brand-slug]
#
# Example, if the org "bluebill" was taken and you registered "bluebill-io":
#   ./rebrand.sh bluebill-io mfmblueprintgmbh.github.io/helm-charts ai.bluebill.io bluebill
#
# Run it from the repo root, before the first commit. Review with `git diff` afterwards.

set -euo pipefail

OLD_ORG="bluebill"
OLD_CHART_HOST="mfmblueprintgmbh.github.io/helm-charts"
OLD_INGEST_HOST="ai.bluebill.io"
OLD_SLUG="bluebill"

NEW_ORG="${1:?usage: ./rebrand.sh <github-org> <chart-host> <ingest-host> [brand-slug]}"
NEW_CHART_HOST="${2:?missing chart host}"
NEW_INGEST_HOST="${3:?missing ingest host}"
NEW_SLUG="${4:-$OLD_SLUG}"

FILES=$(git ls-files 2>/dev/null || find . -type f -not -path "./.git/*")

for f in $FILES; do
  case "$f" in
    rebrand.sh|LICENSE) continue ;;
  esac
  sed -i \
    -e "s|${OLD_CHART_HOST}|${NEW_CHART_HOST}|g" \
    -e "s|${OLD_INGEST_HOST}|${NEW_INGEST_HOST}|g" \
    -e "s|ghcr.io/${OLD_ORG}/|ghcr.io/${NEW_ORG}/|g" \
    -e "s|github.com/${OLD_ORG}/|github.com/${NEW_ORG}/|g" \
    "$f"
done

if [ "$NEW_SLUG" != "$OLD_SLUG" ]; then
  echo "Renaming brand slug ${OLD_SLUG} -> ${NEW_SLUG}."
  echo "This touches the remote_write name, the namespace and the mount paths."
  for f in $FILES; do
    case "$f" in
      rebrand.sh|LICENSE) continue ;;
    esac
    sed -i \
      -e "s|${OLD_SLUG}-k8s-collector\.|${NEW_SLUG}-k8s-collector.|g" \
      -e "s|/etc/${OLD_SLUG}/|/etc/${NEW_SLUG}/|g" \
      -e "s|\"${OLD_SLUG}\"|\"${NEW_SLUG}\"|g" \
      -e "s|name: ${OLD_SLUG}$|name: ${NEW_SLUG}|g" \
      -e "s|namespace ${OLD_SLUG}|namespace ${NEW_SLUG}|g" \
      -e "s|helm repo add ${OLD_SLUG} |helm repo add ${NEW_SLUG} |g" \
      "$f"
  done
fi

echo
echo "Done. Now verify the rename is consistent:"
echo
echo "  grep -rn 'eq \$value.name' charts/kube-cost-metrics-collector/templates/"
echo "  grep -n -A2 'remote_write:' charts/kube-cost-metrics-collector/values.yaml"
echo
echo "The literal in the templates and the name in values.yaml MUST match."
