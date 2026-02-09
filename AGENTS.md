# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CreditTimeline Spec is a specification repository defining a provider-neutral data model for storing UK credit report data over time. It enables personal credit-report data vaulting and longitudinal comparison across imports from Equifax, TransUnion, and Experian.

## Commands

### Validate Specification (required before committing schema changes)
```bash
bash scripts/validate-spec.sh --strict --report-dir artifacts/validation
```
Runs 15+ checks including JSON parsing, data integrity, crosswalk coverage, and reference validation. Strict mode enforces all fields have crosswalk entries and all references resolve.

### Generate Visual Documentation
```bash
bash scripts/generate-spec-report.sh --out-dir artifacts/visual --validation-report-dir artifacts/validation
```
Produces HTML schema docs and SchemaSpy SQLite explorer in `artifacts/visual/`.

### Dependencies
- Required: `jq`, `sqlite3`, `python3`
- Optional: `ajv-cli` (JSON Schema Draft 2020-12 validation), `generate-schema-doc`, `docker` (SchemaSpy)

## Architecture

### Data Model Layers

1. **Provenance Layer**: `CreditFile` (transport envelope) → `ImportBatch` (one acquisition run) → `RawArtifact` (original input metadata)
2. **Identity Layer**: `Subject` → `PersonName`, `Address`, `Identifiers`
3. **Credit Data Layer**: `Tradelines` (with monthly snapshots), `Searches`, `CreditScores`, `PublicRecords`, `NoticeOfCorrection`
4. **Associations Layer**: `FinancialAssociates`, `ElectoralRollEntries`, `PropertyRecords`, `FraudMarkers`, `Disputes`

### Key Files

| Path | Purpose |
|------|---------|
| `schemas/credittimeline-file.v1.schema.json` | Main transport schema (JSON Schema Draft 2020-12) |
| `schemas/credittimeline-v1-enums.json` | Shared enum definitions |
| `sql/credittimeline-v1.sql` | SQLite DDL (31 tables) |
| `mappings/field-crosswalk-v1.csv` | Canonical field → provider field mappings |
| `mappings/normalization-rules.v1.json` | Deterministic transformation rules |
| `examples/credittimeline-file.v1.example.json` | Reference payload for validation testing |
| `docs/credittimeline-v1-data-model.md` | Human-readable entity model specification |

## Critical Conventions

### Provenance Tracking
Every persisted fact must include `source_import_id` to trace data origin. This is enforced by validation.

### Monetary Values
Store as integer minor units (pence for GBP) in `value_minor_units` with optional `currency_code`. Default currency is GBP, inheritable from file → import level.

### Temporal Data
- Timestamps: ISO 8601 with Z suffix (`2026-02-07T14:30:00Z`)
- Monthly snapshots: YYYY-MM strings (`2024-01`)
- Historical ranges: `valid_from`/`valid_to` date pairs

### Naming
- JSON keys: snake_case (`source_import_id`, `acquisition_method`)
- IDs: `type_descriptor_sequence` format (`imp_2026_02_07_eqf`, `subj_01`)
- Enum values: lowercase with underscores (`pdf_upload`, `joint_account`)

### Schema Changes
1. Run strict validation before committing
2. Update crosswalk CSV if adding canonical fields
3. Update example payload to exercise new fields
4. Use semantic versioning: 1.x for compatible changes, 2.x for breaking
