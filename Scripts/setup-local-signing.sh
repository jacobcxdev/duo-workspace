#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
exec /usr/bin/python3 Scripts/local_signing.py ensure \
  --state-dir "${DUO_SIGNING_DIR:-$PWD/.secrets}" \
  --app "${1:-$PWD/.artifacts/mac/Build/Products/Debug/DuoWorkspaceHost.app}"
