# Data Dictionary

All amounts are in US dollars, gross of manufacturer rebates. Database: `oncology.duckdb` (DuckDB).

## Tables

### `oncology_drugs` (reference, 21 rows)
| Column | Description |
|---|---|
| brand | Brand name (primary key), e.g. Keytruda |
| generic_keyword | Text used to find the drug in CMS files, e.g. `pembrolizumab` |
| generic_name | Generic (chemical) name |
| benefit | `Part B` (infused in a clinic) or `Part D` (oral, pharmacy) |
| drug_class | Mechanism, e.g. PD-1/PD-L1 inhibitor, CDK4/6 inhibitor |
| tumour_area | Main cancer type treated |
| manufacturer | Company marketing the drug in the US |
| molecule_type | `Biologic` or `Small molecule` (decides the 13- or 9-year IRA timeline) |
| fda_approval_year | Year of first FDA approval |
| ira_price_year | Year the IRA negotiated price starts; blank if not selected |

### `national_spend` (brand × billing code × year, 2018-2022)
Source: Part B and Part D Spending by Drug.

| Column | Description |
|---|---|
| benefit | Part B or Part D |
| brand | Brand (matches `oncology_drugs`) |
| source_name | Brand name exactly as written by CMS (e.g. *Darzalex Faspro*) |
| hcpcs_code | Part B billing code (J-code); blank for Part D |
| data_year | Calendar year |
| total_spend | Total Medicare spend |
| total_claims | Number of claims |
| total_beneficiaries | Number of Medicare patients using the drug |
| total_units | Billing units (Part B) or dosage units (Part D) |
| mg_per_unit | Milligrams in one Part B billing unit, taken from the code description |

### `benefit_totals` (benefit × year)
| Column | Description |
|---|---|
| benefit | Part B or Part D |
| data_year | Calendar year |
| all_drugs_spend | Total spend on **all** drugs in that benefit (denominator for oncology share) |

## Views (used by Power BI)

| View | Grain | Purpose |
|---|---|---|
| `vw_drugs` | brand | Brand attributes + route (Infused/Oral) + IRA flag |
| `vw_brand_year` | brand × year | National spend, claims, patients, spend per patient |
| `vw_benefit_year` | benefit × year | Oncology spend vs all-drug spend |
| `vw_partb_price` | brand × year | Part B spend per mg and price index (first year = 100) |
| `vw_ira_timeline` | brand | Earliest possible vs actual negotiated-price year, latest-year spend |
