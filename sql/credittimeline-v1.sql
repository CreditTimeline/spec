PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS schema_version (
  version INTEGER PRIMARY KEY,
  applied_at TEXT NOT NULL DEFAULT (datetime('now')),
  description TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS subject (
  subject_id TEXT PRIMARY KEY,
  created_at TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS credit_file (
  file_id TEXT PRIMARY KEY,
  schema_version TEXT NOT NULL,
  currency_code TEXT DEFAULT 'GBP',
  subject_id TEXT NOT NULL REFERENCES subject(subject_id),
  created_at TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS import_batch (
  import_id TEXT PRIMARY KEY,
  file_id TEXT NOT NULL REFERENCES credit_file(file_id),
  subject_id TEXT NOT NULL REFERENCES subject(subject_id),
  imported_at TEXT NOT NULL,
  currency_code TEXT DEFAULT 'GBP',
  source_system TEXT NOT NULL,
  source_wrapper TEXT,
  acquisition_method TEXT NOT NULL,
  mapping_version TEXT,
  confidence_notes TEXT,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS raw_artifact (
  artifact_id TEXT PRIMARY KEY,
  import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  artifact_type TEXT NOT NULL,
  sha256 TEXT NOT NULL,
  uri TEXT,
  embedded_base64 TEXT,
  extracted_text_ref TEXT,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS person_name (
  name_id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL REFERENCES subject(subject_id),
  full_name TEXT,
  title TEXT,
  given_name TEXT,
  middle_name TEXT,
  family_name TEXT,
  suffix TEXT,
  name_type TEXT,
  valid_from TEXT,
  valid_to TEXT,
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS subject_identifier (
  identifier_id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL REFERENCES subject(subject_id),
  identifier_type TEXT NOT NULL,
  value TEXT NOT NULL,
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT
);

-- Address lines (line_1, line_2, line_3) follow UK postal addressing conventions.
-- This is a fixed, bounded set — not an unbounded repeating group — so separate
-- columns are preferred over a child table. SchemaSpy's "incrementing column names"
-- anomaly for this table is a known false positive.
CREATE TABLE IF NOT EXISTS address (
  address_id TEXT PRIMARY KEY,
  line_1 TEXT,
  line_2 TEXT,
  line_3 TEXT,
  town_city TEXT,
  county_region TEXT,
  postcode TEXT,
  country_code TEXT,
  normalized_single_line TEXT,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS address_association (
  association_id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL REFERENCES subject(subject_id),
  address_id TEXT NOT NULL REFERENCES address(address_id),
  role TEXT,
  valid_from TEXT,
  valid_to TEXT,
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS address_link (
  address_link_id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL REFERENCES subject(subject_id),
  from_address_id TEXT NOT NULL REFERENCES address(address_id),
  to_address_id TEXT NOT NULL REFERENCES address(address_id),
  source_organisation_name TEXT,
  last_confirmed_at TEXT,
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS financial_associate (
  associate_id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL REFERENCES subject(subject_id),
  associate_name TEXT,
  relationship_basis TEXT,
  status TEXT,
  confirmed_at TEXT,
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS electoral_roll_entry (
  electoral_entry_id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL REFERENCES subject(subject_id),
  address_id TEXT REFERENCES address(address_id),
  name_on_register TEXT,
  registered_from TEXT,
  registered_to TEXT,
  change_type TEXT,
  marketing_opt_out INTEGER,
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS organisation (
  organisation_id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL REFERENCES subject(subject_id),
  name TEXT NOT NULL,
  roles_json TEXT,
  industry_type TEXT,
  source_import_id TEXT REFERENCES import_batch(import_id),
  source_system TEXT,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS tradeline (
  tradeline_id TEXT PRIMARY KEY,
  canonical_id TEXT,
  subject_id TEXT NOT NULL REFERENCES subject(subject_id),
  furnisher_organisation_id TEXT REFERENCES organisation(organisation_id),
  furnisher_name_raw TEXT,
  account_type TEXT,
  opened_at TEXT,
  closed_at TEXT,
  status_current TEXT,
  repayment_frequency TEXT,
  regular_payment_amount INTEGER,
  supplementary_info TEXT,
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS tradeline_identifier (
  identifier_id TEXT PRIMARY KEY,
  tradeline_id TEXT NOT NULL REFERENCES tradeline(tradeline_id),
  identifier_type TEXT NOT NULL,
  value TEXT NOT NULL,
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS tradeline_party (
  party_id TEXT PRIMARY KEY,
  tradeline_id TEXT NOT NULL REFERENCES tradeline(tradeline_id),
  party_role TEXT,
  name TEXT,
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS tradeline_terms (
  terms_id TEXT PRIMARY KEY,
  tradeline_id TEXT NOT NULL REFERENCES tradeline(tradeline_id),
  term_type TEXT,
  term_count INTEGER,
  term_payment_amount INTEGER,
  payment_start_date TEXT,
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS tradeline_snapshot (
  snapshot_id TEXT PRIMARY KEY,
  tradeline_id TEXT NOT NULL REFERENCES tradeline(tradeline_id),
  as_of_date TEXT,
  status_current TEXT,
  source_account_ref TEXT,
  current_balance INTEGER,
  opening_balance INTEGER,
  credit_limit INTEGER,
  delinquent_balance INTEGER,
  payment_amount INTEGER,
  statement_balance INTEGER,
  minimum_payment_received INTEGER,
  cash_advance_amount INTEGER,
  cash_advance_count INTEGER,
  credit_limit_change TEXT,
  promotional_rate_flag INTEGER,
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS tradeline_monthly_metric (
  monthly_metric_id TEXT PRIMARY KEY,
  tradeline_id TEXT NOT NULL REFERENCES tradeline(tradeline_id),
  period TEXT NOT NULL,
  metric_type TEXT NOT NULL,
  value_numeric INTEGER,
  value_text TEXT,
  canonical_status TEXT,
  raw_status_code TEXT,
  reported_at TEXT,
  metric_value_key TEXT NOT NULL,
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT,
  UNIQUE (tradeline_id, period, metric_type, source_import_id, metric_value_key)
);

CREATE TABLE IF NOT EXISTS tradeline_event (
  event_id TEXT PRIMARY KEY,
  tradeline_id TEXT NOT NULL REFERENCES tradeline(tradeline_id),
  event_type TEXT NOT NULL,
  event_date TEXT NOT NULL,
  amount INTEGER,
  notes TEXT,
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS search_record (
  search_id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL REFERENCES subject(subject_id),
  searched_at TEXT,
  organisation_id TEXT REFERENCES organisation(organisation_id),
  organisation_name_raw TEXT,
  search_type TEXT,
  visibility TEXT,
  joint_application INTEGER,
  input_name TEXT,
  input_dob TEXT,
  input_address_id TEXT REFERENCES address(address_id),
  reference TEXT,
  purpose_text TEXT,
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS credit_score (
  score_id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL REFERENCES subject(subject_id),
  score_type TEXT,
  score_name TEXT,
  score_value INTEGER,
  score_min INTEGER,
  score_max INTEGER,
  score_band TEXT,
  calculated_at TEXT,
  score_factors_json TEXT,
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS public_record (
  public_record_id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL REFERENCES subject(subject_id),
  record_type TEXT,
  court_or_register TEXT,
  amount INTEGER,
  recorded_at TEXT,
  satisfied_at TEXT,
  status TEXT,
  address_id TEXT REFERENCES address(address_id),
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS notice_of_correction (
  notice_id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL REFERENCES subject(subject_id),
  text TEXT,
  created_at TEXT,
  expires_at TEXT,
  scope TEXT,
  scope_entity_id TEXT,
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS property_record (
  property_record_id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL REFERENCES subject(subject_id),
  address_id TEXT REFERENCES address(address_id),
  property_type TEXT,
  price_paid INTEGER,
  deed_date TEXT,
  tenure TEXT,
  is_new_build INTEGER,
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS gone_away_record (
  gone_away_id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL REFERENCES subject(subject_id),
  network TEXT,
  recorded_at TEXT,
  old_address_id TEXT REFERENCES address(address_id),
  new_address_id TEXT REFERENCES address(address_id),
  notes TEXT,
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS fraud_marker (
  fraud_marker_id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL REFERENCES subject(subject_id),
  scheme TEXT,
  marker_type TEXT,
  placed_at TEXT,
  expires_at TEXT,
  address_scope TEXT,
  address_id TEXT REFERENCES address(address_id),
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS attributable_item (
  attributable_item_id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL REFERENCES subject(subject_id),
  entity_domain TEXT,
  linked_entity_id TEXT,
  summary TEXT,
  confidence TEXT,
  reason TEXT,
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS dispute (
  dispute_id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL REFERENCES subject(subject_id),
  entity_domain TEXT,
  entity_id TEXT,
  opened_at TEXT,
  closed_at TEXT,
  status TEXT,
  notes TEXT,
  source_import_id TEXT NOT NULL REFERENCES import_batch(import_id),
  source_system TEXT NOT NULL,
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS generated_insight (
  insight_id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL REFERENCES subject(subject_id),
  kind TEXT NOT NULL,
  summary TEXT,
  generated_at TEXT NOT NULL,
  source_import_id TEXT REFERENCES import_batch(import_id),
  extensions_json TEXT
);

CREATE TABLE IF NOT EXISTS generated_insight_entity (
  insight_id TEXT NOT NULL REFERENCES generated_insight(insight_id),
  entity_id TEXT NOT NULL,
  PRIMARY KEY (insight_id, entity_id)
);

CREATE INDEX IF NOT EXISTS idx_import_batch_subject_imported_at
  ON import_batch(subject_id, imported_at DESC);

CREATE INDEX IF NOT EXISTS idx_person_name_subject
  ON person_name(subject_id, source_import_id);

CREATE INDEX IF NOT EXISTS idx_address_assoc_subject_role
  ON address_association(subject_id, role, valid_to, valid_from);

CREATE INDEX IF NOT EXISTS idx_electoral_subject_address
  ON electoral_roll_entry(subject_id, address_id, registered_from, registered_to);

CREATE INDEX IF NOT EXISTS idx_org_subject_name
  ON organisation(subject_id, name);

CREATE INDEX IF NOT EXISTS idx_tradeline_subject_source
  ON tradeline(subject_id, source_system, status_current);

CREATE INDEX IF NOT EXISTS idx_tradeline_canonical_id
  ON tradeline(canonical_id);

CREATE INDEX IF NOT EXISTS idx_tradeline_snapshot_tradeline_date
  ON tradeline_snapshot(tradeline_id, as_of_date DESC);

CREATE INDEX IF NOT EXISTS idx_tradeline_metric_tradeline_period
  ON tradeline_monthly_metric(tradeline_id, period DESC, metric_type);

CREATE INDEX IF NOT EXISTS idx_tradeline_metric_source_period
  ON tradeline_monthly_metric(source_system, period DESC, metric_type);

CREATE INDEX IF NOT EXISTS idx_search_subject_date
  ON search_record(subject_id, searched_at DESC, visibility);

CREATE INDEX IF NOT EXISTS idx_credit_score_subject_date
  ON credit_score(subject_id, calculated_at DESC);

CREATE INDEX IF NOT EXISTS idx_public_record_subject_status
  ON public_record(subject_id, status, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_fraud_marker_subject
  ON fraud_marker(subject_id, scheme, placed_at DESC);

CREATE INDEX IF NOT EXISTS idx_dispute_subject_status
  ON dispute(subject_id, status, opened_at DESC);

INSERT OR IGNORE INTO schema_version (version, description)
VALUES (1, 'Initial schema creation - CreditTimeline v1');
