#!/usr/bin/env bash
set -euo pipefail

output_dir="$(pwd)/dist"

pushd contributors >/dev/null
CONTRIBKIT_GITHUB_CONTRIBUTORS_LOGIN="${GITHUB_REPOSITORY%%/*}" \
  CONTRIBKIT_GITHUB_CONTRIBUTORS_REPO="${GITHUB_REPOSITORY#*/}" \
  npx contribkit --outputDir="${output_dir}" -w=800 --name=github --force
popd >/dev/null

if [[ -n "${CONTRIBKIT_GITHUB_TOKEN:-}" ]]; then
  pushd sponsors >/dev/null
  CONTRIBKIT_GITHUB_LOGIN="${GITHUB_REPOSITORY%%/*}" \
    CONTRIBKIT_GITHUB_TYPE=organization \
    npx contribkit --outputDir="${output_dir}" -w=800 --name=sponsors --force
  popd >/dev/null
fi
