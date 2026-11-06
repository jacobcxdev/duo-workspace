#!/bin/bash
set -euo pipefail
cd -P "$(dirname "$0")/.."

if [[ $# -ne 0 ]]; then
  echo 'Usage: Scripts/export-source.sh (exports the current clean Git checkout)' >&2
  exit 64
fi
if ! repository=$(git rev-parse --show-toplevel 2>/dev/null) || [[ "$repository" != "$PWD" ]]; then
  echo 'Export requires a Git checkout.' >&2
  exit 1
fi
if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then
  echo 'Commit or stash source changes before exporting.' >&2
  exit 1
fi

revision=$(git rev-parse --verify HEAD)
output="$PWD/.artifacts/source-export/$revision"
mkdir -p "$output"
archive="$output/DuoWorkspace-source.tar.gz"
temporary=$(mktemp "$output/.source-XXXXXX")
trap 'rm -f "$temporary"' EXIT
git archive --format=tar --prefix=DuoWorkspace/ "$revision" | gzip -n > "$temporary"
mv "$temporary" "$archive"
printf '%s\n' "$revision" > "$output/REVISION"
(cd "$output" && shasum -a 256 DuoWorkspace-source.tar.gz > SHA256SUMS)
printf 'Source archive: %s\nRevision: %s\n' "$archive" "$revision"
