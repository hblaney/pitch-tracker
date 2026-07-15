#!/bin/bash
# Push Pitch Tracker to GitHub and trigger IPA build workflow.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GH="${GH_BIN:-gh}"
if ! command -v "$GH" >/dev/null 2>&1; then
  GH="/tmp/gh/gh_2.74.0_macOS_arm64/bin/gh"
fi

if ! "$GH" auth status >/dev/null 2>&1; then
  echo "Not logged into GitHub. Run: $GH auth login --web"
  exit 1
fi

REPO="${1:-pitch-tracker}"
OWNER="$("$GH" api user -q .login)"

if ! "$GH" repo view "$OWNER/$REPO" >/dev/null 2>&1; then
  echo "Creating repo $OWNER/$REPO ..."
  "$GH" repo create "$REPO" --public --source=. --remote=origin --push
else
  git remote remove origin 2>/dev/null || true
  git remote add origin "https://github.com/$OWNER/$REPO.git"
  git push -u origin main
fi

echo "Triggering Build IPA workflow ..."
"$GH" workflow run build-ipa.yml

sleep 5
RUN_ID="$("$GH" run list --workflow=build-ipa.yml --limit 1 --json databaseId -q '.[0].databaseId')"
echo "Workflow run: https://github.com/$OWNER/$REPO/actions/runs/$RUN_ID"
echo "When finished, download IPA:"
echo "  $GH run download $RUN_ID"
