#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE_DIR_INPUT="${1:-$ROOT_DIR/artifacts/site}"
VISUAL_DIR_INPUT="${2:-$ROOT_DIR/artifacts/visual}"
VALIDATION_DIR_INPUT="${3:-$ROOT_DIR/artifacts/validation}"

SITE_SRC_DIR="$ROOT_DIR/artifacts/site-src"
CONFIG_FILE="$ROOT_DIR/zensical.toml"
TMP_CONFIG_FILE="$(mktemp "$ROOT_DIR/.zensical.build.XXXXXX.toml")"

cleanup() {
  rm -f "$TMP_CONFIG_FILE"
}
trap cleanup EXIT

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

resolve_absolute_path() {
  local value="$1"
  python3 - "$value" <<'PY'
import os
import sys

print(os.path.abspath(sys.argv[1]))
PY
}

relative_to_root() {
  local absolute_path="$1"
  local root_dir="$2"
  python3 - "$absolute_path" "$root_dir" <<'PY'
import os
import sys

target = os.path.abspath(sys.argv[1])
root = os.path.abspath(sys.argv[2])

print(os.path.relpath(target, root))
PY
}

copy_directory_if_exists() {
  local source_dir="$1"
  local destination_dir="$2"

  if [[ -d "$source_dir" ]]; then
    cp -R "$source_dir" "$destination_dir"
  fi
}

require_command "python3"
require_command "zensical"

SITE_DIR_ABS="$(resolve_absolute_path "$SITE_DIR_INPUT")"
VISUAL_DIR_ABS="$(resolve_absolute_path "$VISUAL_DIR_INPUT")"
VALIDATION_DIR_ABS="$(resolve_absolute_path "$VALIDATION_DIR_INPUT")"
SITE_DIR_REL="$(relative_to_root "$SITE_DIR_ABS" "$ROOT_DIR")"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing required config file: $CONFIG_FILE" >&2
  exit 1
fi

rm -rf "$SITE_SRC_DIR"
mkdir -p "$SITE_SRC_DIR/guides" "$SITE_SRC_DIR/validation"

cp "$ROOT_DIR/docs/credittimeline-v1-data-model.md" "$SITE_SRC_DIR/guides/data-model.md"
cp "$ROOT_DIR/docs/credittimeline-v1-transport.md" "$SITE_SRC_DIR/guides/transport-format.md"
cp "$ROOT_DIR/docs/credittimeline-v1-storage-sqlite.md" "$SITE_SRC_DIR/guides/sqlite-storage.md"
cp "$ROOT_DIR/docs/provider-crosswalk-matrix.md" "$SITE_SRC_DIR/guides/provider-crosswalk-guide.md"

copy_directory_if_exists "$VISUAL_DIR_ABS/schema-docs" "$SITE_SRC_DIR/"
copy_directory_if_exists "$VISUAL_DIR_ABS/sqlite-schema" "$SITE_SRC_DIR/"

if [[ -f "$VALIDATION_DIR_ABS/validation-summary.md" ]]; then
  cp "$VALIDATION_DIR_ABS/validation-summary.md" "$SITE_SRC_DIR/validation/summary.md"
else
  cat > "$SITE_SRC_DIR/validation/summary.md" <<'EOF'
# Validation Summary

Validation summary was not produced for this run.
EOF
fi

if [[ -f "$VALIDATION_DIR_ABS/validation-report.json" ]]; then
  cp "$VALIDATION_DIR_ABS/validation-report.json" "$SITE_SRC_DIR/validation/validation-report.json"
fi

cat > "$SITE_SRC_DIR/index.md" <<'EOF'
# CreditTimeline Spec

Provider-neutral data model for UK credit report data over time.

## Guides and specifications

- [Data Model Specification](guides/data-model.md)
- [Transport Format](guides/transport-format.md)
- [SQLite Storage](guides/sqlite-storage.md)
- [Provider Crosswalk Guide](guides/provider-crosswalk-guide.md)

## Interactive viewers

- [Transport Schema (JSON Schema)](schema-docs/credittimeline-file.v1.schema.html)
- [Shared Enums](schema-docs/credittimeline-v1-enums.html)
- [SQLite Schema Explorer](sqlite-schema/index.html)

## Validation output

- [Validation Summary](validation/summary.md)
- [Validation Report (JSON)](validation/validation-report.json)
EOF

sed "s|^site_dir = \".*\"$|site_dir = \"$SITE_DIR_REL\"|" "$CONFIG_FILE" > "$TMP_CONFIG_FILE"

zensical build --clean --config-file "$TMP_CONFIG_FILE"

echo "Site built at: $SITE_DIR_ABS"
