#!/usr/bin/env bash
# Publish the package after release checks pass.
#
# Required before running:
#   npm login
# Optional:
#   NPM_TAG=next NPM_PUBLISH_ACCESS=public bash scripts/publish-npm.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

NPM_TAG="${NPM_TAG:-latest}"
NPM_PUBLISH_ACCESS="${NPM_PUBLISH_ACCESS:-public}"

if ! npm whoami >/dev/null 2>&1; then
  printf 'publish-npm: npm is not authenticated. Run `npm login` first.\n' >&2
  exit 2
fi

bash scripts/release-check.sh
npm publish --access "$NPM_PUBLISH_ACCESS" --tag "$NPM_TAG"
