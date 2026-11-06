#!/bin/bash
set -euo pipefail
case "${DUO_LOCAL_SIGNING:-YES}" in
  NO)
    if [[ "${CODE_SIGNING_ALLOWED:-NO}" != YES ]]; then
      echo 'Enable local signing or configure Xcode signing before building the host.' >&2
      exit 1
    fi
    if [[ "${1:-}" == sign ]]; then
      # File providers can attach Finder metadata to generated app bundles.
      xattr -cr "$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"
    fi
    exit 0
    ;;
  YES) ;;
  *) echo 'DUO_LOCAL_SIGNING must be YES or NO.' >&2; exit 1 ;;
esac
cd "$(dirname "$0")/.."
app="$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"
case "${1:-}" in
  prepare) exec Scripts/setup-local-signing.sh "$app" ;;
  sign) exec Scripts/sign-local-host.sh "$app" ;;
  *) echo 'Expected prepare or sign.' >&2; exit 64 ;;
esac
