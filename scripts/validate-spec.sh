#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

STRICT=0
REQUIRE_AJV=0
REPORT_DIR="$ROOT_DIR/artifacts/validation"

SCHEMA_FILE="$ROOT_DIR/schemas/credittimeline-file.v1.schema.json"
ENUMS_FILE="$ROOT_DIR/schemas/credittimeline-v1-enums.json"
EXAMPLE_FILE="$ROOT_DIR/examples/credittimeline-file.v1.example.json"
RULES_FILE="$ROOT_DIR/mappings/normalization-rules.v1.json"
CROSSWALK_FILE="$ROOT_DIR/mappings/field-crosswalk-v1.csv"
SQL_FILE="$ROOT_DIR/sql/credittimeline-v1.sql"

usage() {
  cat <<'EOF'
Usage: scripts/validate-spec.sh [--strict] [--require-ajv] [--report-dir <path>]

Options:
  --strict          Enable strict policy and completeness checks.
  --require-ajv     Fail if AJV is unavailable for JSON Schema validation.
  --report-dir      Output directory for validation-report.json and validation-summary.md.
  -h, --help        Show this help text.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict)
      STRICT=1
      shift
      ;;
    --require-ajv)
      REQUIRE_AJV=1
      shift
      ;;
    --report-dir)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --report-dir" >&2
        exit 2
      fi
      REPORT_DIR="$2"
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

mkdir -p "$REPORT_DIR"
REPORT_JSON="$REPORT_DIR/validation-report.json"
SUMMARY_MD="$REPORT_DIR/validation-summary.md"

CHECKS_JSONL="$(mktemp "${TMPDIR:-/tmp}/credittimeline-checks.XXXXXX.jsonl")"
TMP_SQLITE_DB="$(mktemp "${TMPDIR:-/tmp}/credittimeline-schema.XXXXXX.sqlite")"
trap 'rm -f "$CHECKS_JSONL" "$TMP_SQLITE_DB"' EXIT

TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0

add_result() {
  local id="$1"
  local status="$2"
  local detail="$3"

  TOTAL=$((TOTAL + 1))
  case "$status" in
    pass) PASSED=$((PASSED + 1)) ;;
    fail) FAILED=$((FAILED + 1)) ;;
    skipped) SKIPPED=$((SKIPPED + 1)) ;;
    *)
      echo "Unknown check status: $status" >&2
      exit 1
      ;;
  esac

  jq -n \
    --arg id "$id" \
    --arg status "$status" \
    --arg detail "$detail" \
    '{id: $id, status: $status, detail: $detail}' >> "$CHECKS_JSONL"
}

run_check_cmd() {
  local id="$1"
  local detail="$2"
  local cmd="$3"

  set +e
  local output
  output="$(bash -o pipefail -c "$cmd" 2>&1)"
  local exit_code=$?
  set -e

  if [[ $exit_code -eq 0 ]]; then
    add_result "$id" "pass" "$detail"
  else
    local failure_detail="$detail"
    if [[ -n "$output" ]]; then
      local trimmed
      trimmed="$(printf "%s" "$output" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g')"
      failure_detail="$detail (error: ${trimmed:0:320})"
    fi
    add_result "$id" "fail" "$failure_detail"
  fi
}

run_check_python() {
  local id="$1"
  local detail="$2"
  local script="$3"

  set +e
  local output
  output="$(python3 - <<PY
$script
PY
  2>&1)"
  local exit_code=$?
  set -e

  if [[ $exit_code -eq 0 ]]; then
    add_result "$id" "pass" "$detail"
  else
    local failure_detail="$detail"
    if [[ -n "$output" ]]; then
      local trimmed
      trimmed="$(printf "%s" "$output" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g')"
      failure_detail="$detail (error: ${trimmed:0:320})"
    fi
    add_result "$id" "fail" "$failure_detail"
  fi
}

require_command() {
  local cmd="$1"
  local id="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    add_result "$id" "pass" "Required command '$cmd' is available."
  else
    add_result "$id" "fail" "Required command '$cmd' is missing."
  fi
}

require_command "jq" "tool_jq_available"
require_command "sqlite3" "tool_sqlite3_available"
require_command "python3" "tool_python3_available"

if [[ $FAILED -eq 0 ]]; then
  run_check_cmd "json_parse_schema" \
    "Parse transport JSON Schema." \
    "jq empty \"$SCHEMA_FILE\""
  run_check_cmd "json_parse_enums" \
    "Parse shared enum JSON Schema." \
    "jq empty \"$ENUMS_FILE\""
  run_check_cmd "json_parse_example" \
    "Parse canonical example payload JSON." \
    "jq empty \"$EXAMPLE_FILE\""
  run_check_cmd "json_parse_rules" \
    "Parse normalization rules JSON." \
    "jq empty \"$RULES_FILE\""
  run_check_cmd "sql_compile" \
    "Compile SQLite DDL against an in-memory database." \
    "sqlite3 :memory: \".read \\\"$SQL_FILE\\\"\""
fi

if [[ $FAILED -eq 0 ]]; then
  run_check_cmd "policy_schema_import_requires_acquisition_method" \
    "Schema requires imports[].acquisition_method." \
    "jq -e --arg defs '\$defs' '.[\$defs].importBatch.required | index(\"acquisition_method\") != null' \"$SCHEMA_FILE\" >/dev/null"
  run_check_cmd "policy_schema_tradeline_requires_source_import_id" \
    "Schema requires tradelines[].source_import_id." \
    "jq -e --arg defs '\$defs' '.[\$defs].tradeline.required | index(\"source_import_id\") != null' \"$SCHEMA_FILE\" >/dev/null"

  sqlite3 "$TMP_SQLITE_DB" ".read \"$SQL_FILE\""
  run_check_cmd "policy_sql_import_batch_acquisition_method_not_null" \
    "SQL import_batch.acquisition_method is NOT NULL." \
    "sqlite3 \"$TMP_SQLITE_DB\" \"SELECT COUNT(*) FROM pragma_table_info('import_batch') WHERE name='acquisition_method' AND \\\"notnull\\\"=1;\" | grep -q '^1$'"
  run_check_cmd "policy_sql_tradeline_source_import_id_not_null" \
    "SQL tradeline.source_import_id is NOT NULL." \
    "sqlite3 \"$TMP_SQLITE_DB\" \"SELECT COUNT(*) FROM pragma_table_info('tradeline') WHERE name='source_import_id' AND \\\"notnull\\\"=1;\" | grep -q '^1$'"
  run_check_cmd "policy_sql_tradeline_source_system_not_null" \
    "SQL tradeline.source_system is NOT NULL." \
    "sqlite3 \"$TMP_SQLITE_DB\" \"SELECT COUNT(*) FROM pragma_table_info('tradeline') WHERE name='source_system' AND \\\"notnull\\\"=1;\" | grep -q '^1$'"
fi

if [[ $STRICT -eq 1 && $FAILED -eq 0 ]]; then
  run_check_python "strict_crosswalk_field_coverage" \
    "Crosswalk includes required rows for new canonical fields." \
"import csv
from pathlib import Path

required = {
  'currency_code',
  'imports[].currency_code',
  'tradelines[].canonical_id',
  'tradelines[].snapshots[].source_account_ref',
  'credit_scores[].score_type',
  'credit_scores[].score_name',
  'credit_scores[].score_value',
  'credit_scores[].score_min',
  'credit_scores[].score_max',
  'credit_scores[].score_band',
  'credit_scores[].calculated_at',
  'credit_scores[].score_factors[]',
}

crosswalk = Path(r'''$CROSSWALK_FILE''')
with crosswalk.open(newline='') as f:
  rows = list(csv.DictReader(f))

paths = {row['canonical_path'].strip() for row in rows if row.get('canonical_path')}
missing = sorted(required - paths)
if missing:
  raise SystemExit('missing canonical_path rows: ' + ', '.join(missing))
"

  run_check_cmd "strict_normalization_rules_presence" \
    "Normalization rules include currency inheritance, ingest fallback, score normalization, and metric_value_key derivation." \
    "jq -e '.currency_inheritance.rule and .ingest_fallbacks.mapping_version_when_missing and .score_normalization.range_validation_rule and .monthly_metric_dedupe.metric_value_key_rule' \"$RULES_FILE\" >/dev/null"

  run_check_python "strict_example_reference_integrity" \
    "Example payload source_import_id and foreign references resolve." \
"import json
from pathlib import Path

data = json.loads(Path(r'''$EXAMPLE_FILE''').read_text())
errors = []

root_subject_id = data.get('subject_id')
subject_object_id = (data.get('subject') or {}).get('subject_id')
if root_subject_id != subject_object_id:
  errors.append('subject.subject_id must equal root subject_id')

imports = data.get('imports') or []
import_ids = {item.get('import_id') for item in imports if item.get('import_id')}

def walk(obj):
  if isinstance(obj, dict):
    if 'source_import_id' in obj:
      sid = obj.get('source_import_id')
      if sid and sid not in import_ids:
        errors.append(f'unresolved source_import_id: {sid}')
    for value in obj.values():
      walk(value)
  elif isinstance(obj, list):
    for item in obj:
      walk(item)

walk(data)

address_ids = {item.get('address_id') for item in (data.get('addresses') or []) if item.get('address_id')}
organisation_ids = {item.get('organisation_id') for item in (data.get('organisations') or []) if item.get('organisation_id')}
tradeline_ids = {item.get('tradeline_id') for item in (data.get('tradelines') or []) if item.get('tradeline_id')}

def check_ref(domain, field, ref, valid_ids):
  if ref and ref not in valid_ids:
    errors.append(f'unresolved reference in {domain}.{field}: {ref}')

for item in data.get('address_associations') or []:
  check_ref('address_associations', 'address_id', item.get('address_id'), address_ids)
for item in data.get('address_links') or []:
  check_ref('address_links', 'from_address_id', item.get('from_address_id'), address_ids)
  check_ref('address_links', 'to_address_id', item.get('to_address_id'), address_ids)
for item in data.get('electoral_roll_entries') or []:
  check_ref('electoral_roll_entries', 'address_id', item.get('address_id'), address_ids)
for item in data.get('searches') or []:
  check_ref('searches', 'organisation_id', item.get('organisation_id'), organisation_ids)
  check_ref('searches', 'input_address_id', item.get('input_address_id'), address_ids)
for item in data.get('property_records') or []:
  check_ref('property_records', 'address_id', item.get('address_id'), address_ids)
for item in data.get('public_records') or []:
  check_ref('public_records', 'address_id', item.get('address_id'), address_ids)
for item in data.get('fraud_markers') or []:
  check_ref('fraud_markers', 'address_id', item.get('address_id'), address_ids)
for item in data.get('gone_away_records') or []:
  check_ref('gone_away_records', 'old_address_id', item.get('old_address_id'), address_ids)
  check_ref('gone_away_records', 'new_address_id', item.get('new_address_id'), address_ids)
for item in data.get('tradelines') or []:
  check_ref('tradelines', 'furnisher_organisation_id', item.get('furnisher_organisation_id'), organisation_ids)
for item in data.get('disputes') or []:
  if item.get('entity_domain') == 'tradeline':
    check_ref('disputes', 'entity_id', item.get('entity_id'), tradeline_ids)

if errors:
  raise SystemExit('; '.join(sorted(set(errors))))
"
fi

AJV_AVAILABLE=0
if command -v ajv >/dev/null 2>&1; then
  AJV_AVAILABLE=1
fi

if [[ $AJV_AVAILABLE -eq 1 ]]; then
  run_check_cmd "schema_validation_with_ajv" \
    "Validate example payload against JSON Schema with AJV." \
    "ajv validate --spec=draft2020 --strict=false --validate-formats=false -r \"$ENUMS_FILE\" -s \"$SCHEMA_FILE\" -d \"$EXAMPLE_FILE\""
else
  if [[ $REQUIRE_AJV -eq 1 ]]; then
    add_result "schema_validation_with_ajv" "fail" "AJV CLI is required but not available."
  else
    add_result "schema_validation_with_ajv" "skipped" "AJV CLI not available; schema validation step skipped."
  fi
fi

GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
jq -s \
  --arg generated_at "$GENERATED_AT" \
  --argjson strict "$STRICT" \
  '{
    generated_at: $generated_at,
    strict: ($strict == 1),
    summary: {
      total: length,
      passed: map(select(.status == "pass")) | length,
      failed: map(select(.status == "fail")) | length,
      skipped: map(select(.status == "skipped")) | length
    },
    checks: .
  }' "$CHECKS_JSONL" > "$REPORT_JSON"

{
  echo "# CreditTimeline Spec Validation Summary"
  echo
  echo "- Generated at: $GENERATED_AT"
  if [[ $STRICT -eq 1 ]]; then
    echo "- Strict mode: enabled"
  else
    echo "- Strict mode: disabled"
  fi
  echo "- Total checks: $TOTAL"
  echo "- Passed: $PASSED"
  echo "- Failed: $FAILED"
  echo "- Skipped: $SKIPPED"
  echo
  echo "## Check Results"
  jq -r '.checks[] | "- **\(.status | ascii_upcase)** `\(.id)`: \(.detail)"' "$REPORT_JSON"
} > "$SUMMARY_MD"

echo "Validation report written to: $REPORT_JSON"
echo "Validation summary written to: $SUMMARY_MD"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
