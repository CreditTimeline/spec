# CreditTimeline v1 Canonical Data Model

## 1. Purpose
CreditTimeline v1 defines a provider-neutral model for storing UK credit report data over time.

Goals:
- Preserve source provenance so any value can be traced to a specific import/report.
- Normalize common concepts across CRAs (TransUnion, Equifax, future agencies).
- Keep historical changes for trend analysis and cross-agency comparison.
- Stay simple enough for personal data vault use.

Non-goals:
- Real-time lender decisioning.
- Hiding source differences by force-fitting fields that do not match.

## 2. Core Design Rules
1. Every persisted fact must be attributable to an `import_id`.
2. Provider-specific values are preserved in raw form alongside canonical fields.
3. Time-series data is modeled by month (`YYYY-MM`) rather than compact status strings.
4. Unknown/future fields go into `extensions` instead of breaking schema compatibility.
5. Canonical IDs are stable within a subject vault, not globally unique across all users.

## 3. Top-Level Domains
- Provenance and file lifecycle
- Subject identity and residency
- Associations (financial links)
- Electoral registration
- Tradelines (credit agreements)
- Searches/enquiries
- Public records (court/insolvency)
- Notice of correction
- Property valuation
- Gone away (GAIN-like records)
- Fraud markers (CIFAS)
- Attributable/uncertain data
- Disputes

## 4. Entity Model

### 4.1 Provenance

#### `CreditFile`
Canonical transport envelope.
- `schema_version`
- `file_id`
- `subject_id`
- `created_at`
- `imports[]`
- `subject`
- domain arrays (tradelines, searches, etc.)
- `generated_insights[]` (optional derived output)

#### `ImportBatch`
One acquisition run from one source system.
- `import_id`
- `imported_at`
- `source_system` (`equifax`, `transunion`, `experian`, `other`)
- `source_wrapper` (e.g., ClearScore, Credit Karma)
- `acquisition_method` (`pdf_upload`, `html_scrape`, `api`, `image`, `other`)
- `mapping_version`
- `raw_artifacts[]`
- `confidence_notes`
- `extensions`

#### `RawArtifact`
Original unnormalized input metadata.
- `artifact_id`
- `artifact_type` (`pdf`, `html`, `json`, `image`, `text`, `other`)
- `sha256`
- `uri`
- `embedded_base64` (optional)
- `extracted_text_ref` (optional)

### 4.2 Subject & Identity

#### `Subject`
- `subject_id`
- `names[]`
- `dates_of_birth[]`
- `identifiers[]`

#### `PersonName`
- `name_id`
- `full_name`
- `title`, `given_name`, `middle_name`, `family_name`, `suffix`
- `name_type` (`legal`, `alias`, `historical`, `other`)
- `valid_from`, `valid_to`
- `source_import_id`

#### `Address`
Normalized postal record.
- `address_id`
- lines/town/postcode/region/country
- `normalized_single_line`

#### `AddressAssociation`
Links subject (or domain object) to an address with role and dates.
- `association_id`
- `address_id`
- `role` (`current`, `previous`, `linked`, `on_agreement`, `search_input`, `other`)
- `valid_from`, `valid_to`
- `source_import_id`

#### `AddressLink`
Directed linkage between old and new financially-known addresses.
- `address_link_id`
- `from_address_id`, `to_address_id`
- `source_organisation_name`
- `last_confirmed_at`
- `source_import_id`

### 4.3 Associations

#### `FinancialAssociate`
- `associate_id`
- `associate_name`
- `relationship_basis` (`joint_account`, `joint_application`, `other`)
- `status` (`active`, `disputed`, `removed`, `unknown`)
- `confirmed_at` (optional)
- `source_import_id`

### 4.4 Electoral

#### `ElectoralRollEntry`
- `electoral_entry_id`
- `address_id`
- `registered_from`, `registered_to`
- `change_type` (`added`, `amended`, `deleted`, `none`, `unknown`)
- `name_on_register`
- `marketing_opt_out` (optional)
- `source_import_id`

### 4.5 Organisations

#### `Organisation`
Party entity used by tradelines/searches/public records/fraud markers.
- `organisation_id`
- `name`
- `roles[]` (`furnisher`, `searcher`, `court_source`, `fraud_agency`, `other`)
- `industry_type` (`bank`, `telecom`, `utility`, `insurer`, `landlord`, `government`, `other`)
- `source_import_id`

Notes:
- `organisation_id` is internal to the vault; no global registry required.
- Preserve raw names for exact provenance and display.

### 4.6 Tradelines (Credit Agreements)

#### `Tradeline`
Stable account-level identity record.
- `tradeline_id`
- `furnisher_organisation_id`
- `account_type` (`credit_card`, `mortgage`, `unsecured_loan`, `current_account`, `telecom`, `utility`, `rental`, `budget_account`, `insurance`, `other`)
- `opened_at`, `closed_at`
- `status_current`
- `repayment_frequency`
- `regular_payment_amount`
- `supplementary_info`
- `source_import_id`

#### `TradelineIdentifier`
- masked account numbers/references per source.
- `identifier_type` (`masked_account_number`, `provider_reference`, `other`)

#### `TradelineParty`
- `party_role` (`primary`, `secondary`, `joint`, `guarantor`, `other`)
- optional linked `subject` info (for future multi-subject use)

#### `TradelineTerms`
- `term_type` (`revolving`, `installment`, `mortgage`, `rental`, `other`)
- `term_count`
- `term_payment_amount`
- `payment_start_date`
- `source_import_id`

#### `TradelineSnapshot`
Import-scoped values for mutable fields.
- `snapshot_id`
- `tradeline_id`
- `as_of_date`
- `current_balance`
- `opening_balance`
- `credit_limit`
- `delinquent_balance`
- `payment_amount`
- `statement_balance`
- `minimum_payment_received`
- `cash_advance_amount`
- `cash_advance_count`
- `credit_limit_change`
- `promotional_rate_flag`
- `source_import_id`

#### `TradelineMonthlyMetric`
Unified table for monthly time-series (simplifies schema and future extension).
- `monthly_metric_id`
- `tradeline_id`
- `period` (`YYYY-MM`)
- `metric_type` (`payment_status`, `balance`, `credit_limit`, `statement_balance`, `payment_amount`, `other`)
- `value_numeric` (for monetary/number values)
- `value_text` (for raw status codes and non-numeric values)
- `canonical_status` (for `payment_status` only)
- `raw_status_code`
- `reported_at` (optional)
- `source_import_id`

#### `TradelineEvent`
Important account milestones.
- `event_type` (`default`, `delinquency`, `satisfied`, `settled`, `arrangement_to_pay`, `query`, `gone_away`, `written_off`, `repossession`, `other`)
- `event_date`
- `amount`
- `notes`
- `source_import_id`

### 4.7 Searches

#### `SearchRecord`
- `search_id`
- `searched_at`
- `organisation_id` or raw `organisation_name`
- `search_type` (`credit_application`, `debt_collection`, `quotation`, `identity_check`, `consumer_enquiry`, `aml`, `insurance_quote`, `other`)
- `visibility` (`hard`, `soft`, `unknown`)
- `joint_application` (nullable bool)
- `input_name`
- `input_dob`
- `input_address_id`
- `reference`
- `purpose_text`
- `source_import_id`

### 4.8 Public Records

#### `PublicRecord`
- `public_record_id`
- `record_type` (`ccj`, `judgment`, `bankruptcy`, `iva`, `dro`, `administration_order`, `other`)
- `court_or_register`
- `amount`
- `recorded_at`
- `satisfied_at`
- `status` (`active`, `satisfied`, `set_aside`, `discharged`, `unknown`)
- `address_id`
- `source_import_id`

### 4.9 Notice of Correction

#### `NoticeOfCorrection`
- `notice_id`
- `text`
- `created_at`
- `expires_at`
- `scope` (`file`, `address`, `entity`)
- `source_import_id`

### 4.10 Property

#### `PropertyRecord`
- `property_record_id`
- `address_id`
- `property_type`
- `price_paid`
- `deed_date`
- `tenure`
- `is_new_build`
- `source_import_id`

### 4.11 Gone Away

#### `GoneAwayRecord`
- `gone_away_id`
- `network` (e.g., `GAIN`)
- `recorded_at`
- `old_address_id`
- `new_address_id`
- `notes`
- `source_import_id`

### 4.12 Fraud Markers

#### `FraudMarker`
- `fraud_marker_id`
- `scheme` (`cifas`, `other`)
- `marker_type` (`protective_registration`, `victim_of_impersonation`, `other`)
- `placed_at`, `expires_at`
- `address_scope` (`current`, `previous`, `linked`, `file`, `unknown`)
- `address_id`
- `source_import_id`

### 4.13 Attributable / Uncertain Data

#### `AttributableItem`
- `attributable_item_id`
- `entity_domain` (`tradeline`, `search`, `address`, `public_record`, `fraud_marker`, `other`)
- `summary`
- `confidence` (`low`, `medium`, `high`)
- `reason`
- `linked_entity_id` (optional)
- `source_import_id`

### 4.14 Disputes

#### `Dispute`
- `dispute_id`
- `entity_domain`
- `entity_id`
- `opened_at`, `closed_at`
- `status` (`open`, `under_review`, `resolved`, `rejected`, `withdrawn`)
- `notes`
- `source_import_id`

## 5. Canonical Payment Status Mapping
Store two values for monthly payment statuses:
- `raw_status_code`: source code as provided (`0`, `1`, `U`, `S`, `D`, `Q`, `G`, `UC`, etc.).
- `canonical_status`: normalized bucket:
  - `up_to_date`
  - `in_arrears`
  - `arrangement`
  - `settled`
  - `default`
  - `query`
  - `gone_away`
  - `no_update`
  - `inactive`
  - `written_off`
  - `transferred`
  - `repossession`
  - `unknown`

## 6. Temporal Semantics
- `imported_at`: when data was acquired.
- `as_of_date`: point-in-time value date for snapshots.
- `valid_from`/`valid_to`: entity validity range where available.
- `period`: monthly series bucket (`YYYY-MM`).
- `reported_at`: when provider says that period’s value was reported/updated.

This supports retroactive corrections and diffing between imports.

## 7. Extension and Compatibility
Every entity may include `extensions` as an object map for provider-specific or future fields.

Versioning:
- Major changes increment `schema_version` major component (e.g., `1.x` -> `2.0.0`).
- Minor additions are backward compatible (`1.0.0` -> `1.1.0`).

## 8. Practical Simplifications Chosen
Compared with a highly normalized financial-industry model, v1 intentionally simplifies by:
- Using one monthly metric entity instead of separate tables per metric type.
- Allowing `organisation_name` directly on records even when no canonical organisation match exists.
- Keeping `extensions` and raw labels rather than forcing strict controlled vocab for every field.

This keeps ingestion and user trust manageable while preserving data needed for long-term analysis.
