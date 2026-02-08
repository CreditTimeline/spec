#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/artifacts/visual-report"
VALIDATION_REPORT_DIR=""

SCHEMA_FILE="$ROOT_DIR/schemas/credittimeline-file.v1.schema.json"
ENUMS_FILE="$ROOT_DIR/schemas/credittimeline-v1-enums.json"
SQL_FILE="$ROOT_DIR/sql/credittimeline-v1.sql"

usage() {
  cat <<'EOF'
Usage: scripts/generate-spec-report.sh [--out-dir <path>] [--validation-report-dir <path>]

Options:
  --out-dir                Output directory for static HTML report assets.
  --validation-report-dir  Optional directory containing validation-summary.md and validation-report.json.
  -h, --help               Show this help text.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --out-dir" >&2
        exit 2
      fi
      OUT_DIR="$2"
      shift 2
      ;;
    --validation-report-dir)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --validation-report-dir" >&2
        exit 2
      fi
      VALIDATION_REPORT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# Convert OUT_DIR to absolute path if relative (required for Docker volume mounts)
if [[ "$OUT_DIR" != /* ]]; then
  OUT_DIR="$(pwd)/$OUT_DIR"
fi

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

require_command "generate-schema-doc"
require_command "sqlite3"
require_command "docker"
require_command "curl"

GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

SCHEMA_DOC_DIR="$OUT_DIR/schema-docs"
SQLITE_DOC_DIR="$OUT_DIR/sqlite-schema"

mkdir -p "$SCHEMA_DOC_DIR" "$SQLITE_DOC_DIR"

run_generate_schema_doc() {
  local input_schema="$1"
  local output_file="$2"
  local cfg_file="$3"

  if generate-schema-doc --help 2>&1 | grep -q -- "--config-template-name"; then
    generate-schema-doc --config-template-name js_offline \
      "$input_schema" \
      "$output_file"
  else
    if ! generate-schema-doc --config-file "$cfg_file" \
      "$input_schema" \
      "$output_file"; then
      echo "Falling back to default generate-schema-doc template for $input_schema"
      generate-schema-doc "$input_schema" "$output_file"
    fi
  fi
}

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/credittimeline-report.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
SQLITE_DB="$TMP_DIR/credittimeline-v1.db"
JSFH_CONFIG="$TMP_DIR/json-schema-for-humans.yaml"

cat > "$JSFH_CONFIG" <<'EOF'
template_name: js_offline
EOF

run_generate_schema_doc "$SCHEMA_FILE" "$SCHEMA_DOC_DIR/credittimeline-file.v1.schema.html" "$JSFH_CONFIG"
run_generate_schema_doc "$ENUMS_FILE" "$SCHEMA_DOC_DIR/credittimeline-v1-enums.html" "$JSFH_CONFIG"

sqlite3 "$SQLITE_DB" ".read \"$SQL_FILE\""

# Download SQLite JDBC driver (not included in schemaspy Docker image)
# Must mount as a directory to /drivers, not a single file
SQLITE_DRIVER_VERSION="3.45.1.0"
DRIVERS_DIR="$TMP_DIR/drivers"
mkdir -p "$DRIVERS_DIR"
curl -fsSL -o "$DRIVERS_DIR/sqlite-jdbc.jar" \
  "https://repo1.maven.org/maven2/org/xerial/sqlite-jdbc/${SQLITE_DRIVER_VERSION}/sqlite-jdbc-${SQLITE_DRIVER_VERSION}.jar"

docker run --rm \
  -v "$TMP_DIR:/db" \
  -v "$SQLITE_DOC_DIR:/output" \
  -v "$DRIVERS_DIR:/drivers" \
  schemaspy/schemaspy:latest \
  -t sqlite-xerial \
  -db /db/credittimeline-v1.db \
  -s main \
  -cat % \
  -sso \
  -vizjs

VALIDATION_LINK_NOTE="Validation summary not bundled in this artifact."
if [[ -n "$VALIDATION_REPORT_DIR" ]]; then
  mkdir -p "$OUT_DIR/validation"
  if [[ -f "$VALIDATION_REPORT_DIR/validation-summary.md" ]]; then
    cp "$VALIDATION_REPORT_DIR/validation-summary.md" "$OUT_DIR/validation/validation-summary.md"
    VALIDATION_LINK_NOTE='Validation summary: <a href="./validation/validation-summary.md">validation/validation-summary.md</a>'
  fi
  if [[ -f "$VALIDATION_REPORT_DIR/validation-report.json" ]]; then
    cp "$VALIDATION_REPORT_DIR/validation-report.json" "$OUT_DIR/validation/validation-report.json"
  fi
fi

cat > "$OUT_DIR/index.html" <<EOF
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>CreditTimeline Spec Report</title>
    <style>
      :root {
        --bg: #f6f8fb;
        --fg: #10243e;
        --muted: #4a617f;
        --card: #ffffff;
        --accent: #0054a6;
      }
      body {
        margin: 0;
        padding: 2rem;
        background: var(--bg);
        color: var(--fg);
        font-family: "Avenir Next", "Segoe UI", sans-serif;
      }
      main {
        max-width: 900px;
        margin: 0 auto;
      }
      .card {
        background: var(--card);
        border-radius: 14px;
        padding: 1.25rem 1.5rem;
        box-shadow: 0 10px 30px rgba(16, 36, 62, 0.08);
      }
      h1 {
        margin-top: 0;
      }
      ul {
        line-height: 1.8;
      }
      a {
        color: var(--accent);
      }
      .meta {
        color: var(--muted);
        margin-bottom: 1rem;
      }
    </style>
  </head>
  <body>
    <main>
      <div class="card">
        <h1>CreditTimeline Spec Report</h1>
        <p class="meta">Generated at $GENERATED_AT</p>
        <ul>
          <li><a href="./schema-docs/credittimeline-file.v1.schema.html">Transport Schema (JSON Schema)</a></li>
          <li><a href="./schema-docs/credittimeline-v1-enums.html">Shared Enums (JSON Schema)</a></li>
          <li><a href="./sqlite-schema/index.html">SQLite Schema Explorer (SchemaSpy)</a></li>
        </ul>
        <p>$VALIDATION_LINK_NOTE</p>
      </div>
    </main>
  </body>
</html>
EOF

echo "Visual report generated at: $OUT_DIR"
