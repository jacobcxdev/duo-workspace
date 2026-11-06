#!/bin/bash
# Source from a build script after changing to the repository root.
export DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
duo_build_root="${DUO_BUILD_ROOT:-$PWD/.artifacts}"
mkdir -p "$duo_build_root"
export DUO_BUILD_ROOT="$(cd "$duo_build_root" && pwd -P)"
