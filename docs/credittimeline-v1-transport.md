# CreditTimeline v1 Data Transport (JSON)

## 1. Transport Contract Summary
CreditTimeline adapters send canonical JSON files conforming to:
- `schemas/credittimeline-file.v1.schema.json`

Recommended flow:
1. Acquire source data (PDF/API/scrape).
2. Map to canonical JSON.
3. Validate against JSON Schema.
4. Upsert into SQLite long-term store.

## 2. Envelope
Root object: `CreditFile`

Required root fields:
- `schema_version` (semver, v1 line)
- `file_id`
- `subject_id`
- `created_at` (RFC 3339 UTC timestamp)
- `imports` (>= 1)
- `subject`

Entity-level required fields are intentionally minimal: IDs, provenance pointers (for example `source_import_id`), and schema-defined identity anchors where needed.

Optional root fields:
- `currency_code` (ISO 4217, defaults to GBP)

Import-level required fields:
- `import_id`
- `imported_at`
- `source_system`
- `acquisition_method`

Import-level optional fields:
- `mapping_version` (reference implementation should populate this during ingest when missing)

Optional root domain arrays:
- `organisations`
- `addresses`
- `address_associations`
- `address_links`
- `financial_associates`
- `electoral_roll_entries`
- `tradelines`
- `searches`
- `credit_scores`
- `public_records`
- `notices_of_correction`
- `property_records`
- `gone_away_records`
- `fraud_markers`
- `attributable_items`
- `disputes`
- `generated_insights`

## 3. IDs and References
- IDs are strings unique within one `CreditFile`.
- Cross-references use IDs (`address_id`, `tradeline_id`, `source_import_id`, etc.).
- `source_import_id` must reference one element in `imports[]`.

Recommended pattern: prefix IDs by domain (`addr_`, `tl_`, `srch_`, `imp_`).

## 4. Date and Time Formats
- Date-time: RFC 3339, UTC preferred (`YYYY-MM-DDTHH:MM:SSZ`).
- Date only: `YYYY-MM-DD`.
- Monthly period: `YYYY-MM`.

When exact day is unknown, omit date field and preserve source text in `extensions`.

## 5. Money and Currency
- Monetary fields are integers in minor units (pence for GBP).
- Currency defaults to GBP unless explicitly provided via `currency_code`.
- `ImportBatch.currency_code` overrides the file-level default for a given import.
- Use `extensions.currency` when a field-level currency is required and not modeled explicitly.

## 6. Canonical + Raw Strategy
For provider-specific values:
- set canonical field when confidence is high.
- always keep raw value in `raw_*` or `extensions`.

Examples:
- payment status code `UC` -> `raw_status_code: "UC"`, `canonical_status: "no_update"` (or `unknown` if uncertain).
- unknown search type -> `search_type: "other"`, raw text in `purpose_text`.

## 7. Validation Strictness
- Root and core objects use `additionalProperties: false`.
- `extensions` allows additional provider-specific keys.
- Unknown enum values should map to `other`/`unknown` and preserve raw source text.
- Enum definitions live in `schemas/credittimeline-v1-enums.json`.
- JSON Schema `default` keywords are annotations only; ingest pipelines should materialize defaults (`currency_code`, fallback `mapping_version`) before persistence.

## 8. Quality Profile (Non-Blocking)
The transport remains ultra-flexible for sparse reports, but adapters should emit quality warnings when key analytic anchors are missing.

Recommended warning keys:
- `missing_search_date`
- `missing_search_type`
- `missing_public_record_type`
- `missing_tradeline_account_type`

Warnings can be emitted via `generated_insights` and should not block ingestion.

## 9. Import Granularity
Supported:
- one file containing one import batch (recommended)
- one file containing multiple import batches (backfill/migration)

In all cases, each domain record should carry explicit `source_import_id`.

## 10. Minimal Ingestion Checklist
Before accepting a file:
1. JSON Schema valid.
2. All `source_import_id` values resolve.
3. All foreign IDs resolve (address, organisation, tradeline references).
4. `period` values are valid `YYYY-MM`.
5. No duplicate `(tradeline_id, period, metric_type, source_import_id, raw_status_code/value)` rows in payload.
6. Derive `tradeline_monthly_metric.metric_value_key` during ingest for SQLite dedupe. This is storage metadata and is not part of canonical transport payload fields.

## 11. Backward-Compatible Evolution Rules
Allowed in v1.x:
- adding optional fields
- adding optional arrays
- adding enum members when `other/unknown` fallback exists

Requires v2:
- removing/renaming existing fields
- changing field type
- changing semantic meaning of required fields
