#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v bats >/dev/null 2>&1; then
  echo "bats is required. Install bats-core, then rerun this script." >&2
  exit 127
fi

bats -r tests
bats test/bats
