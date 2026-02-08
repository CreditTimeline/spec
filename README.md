# CreditTimeline Specs

Specification repository for CreditTimeline v1.

## Included Specs
- Human-readable data model: `docs/credittimeline-v1-data-model.md`
- Human-readable transport contract: `docs/credittimeline-v1-transport.md`
- Human-readable SQLite storage notes: `docs/credittimeline-v1-storage-sqlite.md`
- Provider mapping notes (Equifax/TransUnion): `docs/provider-field-mapping-notes.md`
- Provider crosswalk usage guide: `docs/provider-crosswalk-matrix.md`
- Machine-readable JSON Schema: `schemas/credittimeline-file.v1.schema.json`
- Shared enum definitions: `schemas/credittimeline-v1-enums.json`
- SQLite DDL reference schema: `sql/credittimeline-v1.sql`
- Example canonical payload: `examples/credittimeline-file.v1.example.json`
- Crosswalk matrices:
  - `mappings/field-crosswalk-v1.csv`
  - `mappings/account-type-crosswalk-v1.csv`
  - `mappings/account-status-crosswalk-v1.csv`
  - `mappings/payment-status-crosswalk-v1.csv`
  - `mappings/search-type-crosswalk-v1.csv`
  - `mappings/normalization-rules.v1.json`

## Scope
These v1 specs are designed for personal credit-report data vaulting and longitudinal comparison across imports and credit reference agencies.

## Validation and Reports
- Run strict local validation:
  - `bash scripts/validate-spec.sh --strict --report-dir artifacts/validation`
- Generate a static visual walkthrough artifact:
  - `bash scripts/generate-spec-report.sh --out-dir artifacts/visual --validation-report-dir artifacts/validation`
- Validation output files:
  - `artifacts/validation/validation-report.json`
  - `artifacts/validation/validation-summary.md`

## CI Workflows
- `spec-validation.yml`
  - Runs strict validation and visual report generation on PRs, pushes to `main`, and manual dispatch.
  - Uploads `spec-validation-report` and `spec-visual-report` artifacts.
- `docs-link-check.yml`
  - Runs scheduled/manual link checking for `README.md` and `docs/**/*.md`.

## Versioning
- Current schema line: `1.x`
- Backward-compatible additions: `1.x` minor/patch
- Breaking changes: next major
