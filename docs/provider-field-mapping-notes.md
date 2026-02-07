# Provider Field Mapping Notes (From Supplied Reports)

This note captures field coverage observed in:
- TransUnion statutory report PDF
- Equifax statutory report PDF

The purpose is to justify v1 model fields and identify known gaps.

## 1. Confirmed Mappings

| Provider label/section | Canonical target |
|---|---|
| TU `Current address`, `Address link history`, `Address link details`, `Source`, `Last confirmed` | `address`, `address_association`, `address_link` |
| TU `Financial connections`, `NAME SOURCE CONFIRMED` | `financial_associate` |
| TU `Other names` | `person_name` with `name_type=alias/historical` |
| TU `Electoral Registration` + `Dates` + `Marketing status` | `electoral_roll_entry` |
| TU account fields (`Account type`, `Account start/end date`, `Opening balance`, `Regular payment`, `Payment start date`, `Repayment frequency`) | `tradeline`, `tradeline_terms`, `tradeline_snapshot` |
| TU monthly sections (`Status history`, `Balance history`, `Limit history`, `Statement balance`, `Payment amount`) | `tradeline_monthly_metric` |
| TU search fields (`Purpose`, `Input address`, `Search reference`, `Name`, `Date of birth`, `Application type`) | `search_record` |
| TU `Public Information` (Judgments / Bankruptcies and Insolvencies) | `public_record` |
| TU `Notices of Correction` | `notice_of_correction` |
| TU `Cifas` | `fraud_marker` |
| EQF address groups (`Current`, `Previous`, `Linked`) | `address_association` with `role` |
| EQF `Financial Associates`, alias section | `financial_associate`, `person_name` |
| EQF electoral `Dates on Electoral Register`, `Changes` (added/amended/deleted) | `electoral_roll_entry` |
| EQF tradeline fields (`Repayment Terms`, `Status`, `Payment Frequency`, `Credit Limit`, `Current Balance`, `Default/Delinquent Balance`, `Date Updated`, `Date Satisfied`, `Default Date`) | `tradeline_terms`, `tradeline_snapshot`, `tradeline_event` |
| EQF credit card management fields (`Payment Amount`, `Previous Statement Balance`, `Cash Advance Amount`, `Number of Cash Advances During Month`, `Credit Limit Change`, `Minimum Payment`, `Promotional Rate`) | `tradeline_snapshot` |
| EQF `Attributable Data` | `attributable_item` |
| EQF search fields (`Hard/Soft`, `Date of birth`, `Search Type`, `Joint Application`) | `search_record` |
| EQF `Property Valuation` (`Property Type`, `Price Paid`, `Deed Date`, `Tenure`, `New Build?`) | `property_record` |
| EQF `Gone Away Records` / GAIN notes | `gone_away_record` |
| EQF `CIFAS Records` | `fraud_marker` |

## 2. Known Data Gaps in Sample Files
The provided files had no live examples for:
- non-empty public records rows
- non-empty gone away records rows
- non-empty CIFAS marker rows
- non-empty notices of correction rows

v1 still models these domains because the section definitions are explicit in report structures.

## 3. Normalization Notes
- Payment status is preserved raw (`raw_status_code`) and mapped (`canonical_status`).
- Search type vocab differs significantly by provider; keep `search_type` broad and preserve `purpose_text`.
- Organisation naming is noisy across wrappers and source systems; keep raw name and optional normalized org mapping.
- Address role is report-contextual (current/previous/linked/on-agreement/search-input) and should not be collapsed.
