# Provider Crosswalk Matrix (v1)

This crosswalk translates provider-specific UK credit-report fields into the CreditTimeline canonical model.

## Files
- Field-level matrix: `mappings/field-crosswalk-v1.csv`
- Payment status mapping: `mappings/payment-status-crosswalk-v1.csv`
- Account status mapping: `mappings/account-status-crosswalk-v1.csv`
- Search type mapping: `mappings/search-type-crosswalk-v1.csv`
- Account type mapping: `mappings/account-type-crosswalk-v1.csv`
- Machine-consumable rules: `mappings/normalization-rules.v1.json`

## How to Use in Adapters
1. Parse source report rows into raw provider fields.
2. Use `field-crosswalk-v1.csv` to map raw fields to canonical paths.
3. Apply deterministic code conversions from the specialized crosswalk files.
4. Write unmapped or ambiguous raw values to `extensions`.
5. Attach `source_import_id` to every output entity.

## Design Choices
- Canonical model stays strict; provider differences are preserved in raw values and `extensions`.
- Search and payment code systems are normalized into compact enums.
- Address-role mapping is context-driven (current/previous/linked/on-agreement/search-input).

## Confidence Model
- `high`: observed directly in supplied Equifax/TransUnion statutory reports or official provider docs.
- `medium`: supported by official provider docs but not observed in supplied sample rows.
- `low`: inferred from provider guidance where field-level examples were incomplete.

## Coverage Notes
- Equifax + TransUnion mappings are high coverage due direct statutory report samples.
- Experian mappings are included from publicly documented data categories and CRAIN-level descriptions; field label granularity is lower than Equifax/TransUnion.

## Source Set Used
- Supplied statutory reports (local analysis):
  - Equifax credit report dated 07/02/2026
  - TransUnion credit report dated 07/02/2026
- Online references (official/provider):
  - TransUnion statutory report guide: `https://www.transunionstatreport.co.uk/CreditReport/About`
  - Equifax developer data types appendix: `https://developer.equifax.co.uk/products/apiproducts/credit-insights-development-guide/resources/appendix-data-types`
  - Equifax data groups (selected):
    - Electoral Roll: `https://developer.equifax.co.uk/products/apiproducts/credit-insights-development-guide/resources/Data%20Groups/Electoral%20Roll.pdf`
    - Searches: `https://developer.equifax.co.uk/products/apiproducts/credit-insights-development-guide/resources/Data%20Groups/Searches.pdf`
    - Property Insight: `https://developer.equifax.co.uk/products/apiproducts/credit-insights-development-guide/resources/Data%20Groups/Property%20Insight.pdf`
    - Gone Away Insight: `https://developer.equifax.co.uk/products/apiproducts/credit-insights-development-guide/resources/Data%20Groups/Gone%20Away%20Insight.pdf`
    - Court Information Insights: `https://developer.equifax.co.uk/products/apiproducts/credit-insights-development-guide/resources/Data%20Groups/Court%20Information%20Insights.pdf`
    - Insolvency Insight: `https://developer.equifax.co.uk/products/apiproducts/credit-insights-development-guide/resources/Data%20Groups/Insolvency%20Insight.pdf`
    - Attributable Names: `https://developer.equifax.co.uk/products/apiproducts/credit-insights-development-guide/resources/Data%20Groups/Attributable%20Names.pdf`
    - Notice of Correction or Dispute: `https://developer.equifax.co.uk/products/apiproducts/credit-insights-development-guide/resources/Data%20Groups/Notice%20of%20Correction%20or%20Dispute.pdf`
    - Associate: `https://developer.equifax.co.uk/products/apiproducts/credit-insights-development-guide/resources/Data%20Groups/Associate.pdf`
    - Alias: `https://developer.equifax.co.uk/products/apiproducts/credit-insights-development-guide/resources/Data%20Groups/Alias.pdf`
  - Experian statutory report page: `https://www.experian.co.uk/consumer/statutory-report.html`
  - Credit Reference Agency Information Notice (CRAIN): `https://www.transunion.co.uk/legal-information/bureau-privacy-notice`

## Practical ETL Recommendations
- Use case-insensitive lookup for provider field names and code values.
- Keep two columns for status values: `raw_status_code` and `canonical_status`.
- For search footprints, derive visibility from provider sections (`Hard Searches`/`Soft Searches`) before fallback to code mapping.
- Store unresolved provider values under `extensions.unmapped_fields` for future expansion.
