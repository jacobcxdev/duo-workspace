#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source Scripts/build-environment.sh
mode="${1:-run}"
case "$mode" in
  run|--verify|--debug|--logs|--telemetry) ;;
  *) echo "Usage: $0 [--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;;
esac
app="$DUO_BUILD_ROOT/mac/Build/Products/Debug/DuoWorkspaceHost.app"
pkill -x DuoWorkspaceHost >/dev/null 2>&1 || true
xcodebuild -project DuoWorkspace.xcodeproj -scheme DuoWorkspaceHost \
  -destination 'platform=macOS' -derivedDataPath "$DUO_BUILD_ROOT/mac" \
  -allowProvisioningUpdates build
# Documents file providers can attach Finder metadata to generated bundles.
xattr -cr "$app"
codesign --verify --deep --strict "$app"
if [[ "$mode" == --debug ]]; then
  exec lldb -- "$app/Contents/MacOS/DuoWorkspaceHost"
fi
open -n "$app"
case "$mode" in
  --verify) sleep 2; pgrep -x DuoWorkspaceHost ;;
  --logs) exec /usr/bin/log stream --info --style compact --predicate 'process == "DuoWorkspaceHost"' ;;
  --telemetry) exec /usr/bin/log stream --info --style compact --predicate 'subsystem == "dev.jacobcx.DuoWorkspaceHost"' ;;
esac
