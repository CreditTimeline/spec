# CreditTimeline v1 Long-Term Storage (SQLite)

## 1. Why SQLite for Reference Implementation
SQLite is the reference storage because it is:
- local-first and offline by default
- simple to back up/export (single file)
- strong enough for time-series + diff queries with indexes

Canonical JSON remains the interchange format; SQLite is the analysis layer.

## 2. Source of Truth Split
- Transport truth: canonical JSON files (`schemas/credittimeline-file.v1.schema.json`).
- Query truth: normalized SQLite tables (`sql/credittimeline-v1.sql`).

Recommended ingestion:
1. validate JSON
2. insert `import_batch` + `raw_artifact`
3. upsert dimension-like entities (subject, address, organisation, tradeline)
4. insert import-scoped facts/snapshots/events/metrics

## 3. Schema Design Decisions

### 3.1 Provenance Everywhere
Most fact tables include:
- `source_import_id`
- `source_system`
- `extensions_json`

`source_system` is denormalized for faster filtering across agencies.
`import_batch.acquisition_method` is required, and `tradeline` rows require both `source_import_id` and `source_system` for lineage integrity.

### 3.2 Unified Monthly Metrics
Instead of multiple monthly tables, v1 uses one:
- `tradeline_monthly_metric`

This avoids schema churn when new monthly series types appear.
Ingest derives `metric_value_key` as deterministic storage metadata for dedupe and unique constraints.

### 3.3 Raw + Canonical
Key tables preserve both normalized and source-specific values:
- `raw_status_code` + `canonical_status`
- `organisation_id` + `organisation_name_raw` (where applicable)

### 3.4 Extension Columns
`extensions_json` (TEXT JSON) is included on major tables to support future fields without migration pressure.

### 3.5 Monetary Values
All monetary amounts are stored as integers in minor units (pence for GBP). Currency defaults to GBP and can be overridden per import with `currency_code`.

## 4. Core Table Groups

### 4.1 Provenance
- `schema_version`
- `subject`
- `credit_file`
- `import_batch`
- `raw_artifact`

### 4.2 Identity/Residency
- `person_name`
- `subject_identifier`
- `address`
- `address_association`
- `address_link`
- `financial_associate`
- `electoral_roll_entry`

### 4.3 Tradelines
- `organisation`
- `tradeline`
- `tradeline_identifier`
- `tradeline_party`
- `tradeline_terms`
- `tradeline_snapshot`
- `tradeline_monthly_metric`
- `tradeline_event`

### 4.4 Other Domains
- `search_record`
- `credit_score`
- `public_record`
- `notice_of_correction`
- `property_record`
- `gone_away_record`
- `fraud_marker`
- `attributable_item`
- `dispute`
- `generated_insight`

## 5. Suggested Upsert Keys
- `subject`: `subject_id`
- `address`: normalized full key (`normalized_single_line`, `postcode`, `country_code`)
- `organisation`: normalized name + source system
- `tradeline`: prefer `canonical_id` when provided; otherwise use a stable fingerprint (furnisher + best identifier hash)
- `tradeline_monthly_metric`: unique by (`tradeline_id`, `period`, `metric_type`, `source_import_id`, `metric_value_key`)
- `search_record`: dedupe by (`searched_at`, `organisation_name_raw`, `search_type`, `reference`, `source_import_id`)

## 6. Important Indexes
Included indexes focus on core user queries:
- report timeline by import date
- compare same account across agencies
- monthly trend per tradeline
- hard/soft searches over time
- public/fraud markers by status/date

## 7. Query Examples
- Monthly utilization trend: `balance / credit_limit` from `tradeline_monthly_metric` where types = `balance`, `credit_limit`.
- Agency comparison: latest `tradeline_snapshot` grouped by `source_system`.
- Retroactive correction detection: compare same `period`/`metric_type` across different `source_import_id`.

## 8. Migration Strategy
- Keep v1 schema additive when possible.
- Put low-confidence/rare fields in `extensions_json` first.
- Promote heavily-used extension fields to first-class columns in a future minor schema release.
- Track applied migrations in `schema_version`.
