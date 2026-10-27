# US Oncology Drug Market Analysis: Medicare Part B vs Part D

Analysis of Medicare spending on 21 leading cancer drugs from 2018 to 2022, comparing **infused drugs given
in clinics (Part B)** with **oral drugs taken at home (Part D)**. The project covers market size, brand
performance, tumour areas, pricing, cost per patient and exposure to IRA drug price negotiation.

**Tools:** Python (pandas) for data cleaning · SQL (DuckDB) for analysis · Power BI for the dashboard

---

## Business questions

| # | Question | Area |
|---|---|---|
| 1 | How big is Medicare oncology drug spend, and is Part B or Part D growing faster? | Commercial |
| 2 | Which brands lead each channel, and which are growing fastest? | Commercial |
| 3 | In each tumour area, how does spend split between infused and oral drugs? | Commercial |
| 4 | How has the Part B price per mg changed for infused drugs? | Market access |
| 5 | What does Medicare spend per patient per year on each drug? | Market access |
| 6 | How much oncology spend falls on drugs selected for IRA price negotiation? | Market access |
| 7 | How does the IRA "9 vs 13 year" rule treat oral (small molecule) vs infused (biologic) drugs? | Market access |

## Key insights (2022 data)

- **Market size:** Medicare spent **$25.9 bn** on these 21 cancer drugs in 2022: **$11.3 bn in Part B** and
  **$14.6 bn in Part D**. The 9 infused drugs alone made up **26% of all Part B drug spend**, up from 16.5% in 2018.
- **Growth:** both channels grew about **22-23% a year** from 2018 to 2022, but the pace split in 2022:
  Part B accelerated (+23%) while Part D slowed (+8%).
- **Brands:** **Keytruda** is the largest drug at **$4.9 bn** (44% of Part B oncology spend, +24% in 2022).
  **Enhertu** was the fastest grower (+136%). In Part D, **Imbruvica** still leads ($2.9 bn) but fell 9%,
  while fellow BTK inhibitor **Calquence** grew 54%.
- **Tumour areas:** immunotherapy ($7.2 bn) is entirely infused, CLL and prostate cancer are entirely oral,
  breast cancer is 91% oral (CDK4/6 inhibitors), and myeloma and lung split roughly 55/45 infused vs oral.
- **Pricing:** Part B spend per mg rose **20% for Keytruda** and **32% for Kyprolis** from 2018 to 2022.
  Darzalex fell 6% per mg, at the same time as most of its use moved to the subcutaneous Faspro form (83% of 2022 spend).
- **Cost per patient:** the most expensive drugs per patient are **oral**: Pomalyst ($138k a year),
  Imbruvica ($129k) and Tagrisso ($125k), compared with $74k for Keytruda.
- **IRA:** **84% of Part D oncology spend** in this group ($12.3 bn) is on drugs with a negotiated price starting
  2026-2028. **All 9 selected drugs are small molecules**; none of the 8 biologics has been selected yet,
  which reflects their longer 13-year protection and the later start (2028) for Part B drugs.

## Dashboard

| Market overview | Brands & tumour areas | Market access & pricing |
|---|---|---|
| ![](powerbi/screenshots/page1_overview.png) | ![](powerbi/screenshots/page2_brands.png) | ![](powerbi/screenshots/page3_market_access.png) |

## Data

Public data from the Centers for Medicare & Medicaid Services (CMS), 2018-2022 release, downloaded from the
[DataLumos](https://www.datalumos.org) archive of US government data (ICPSR, University of Michigan).

| Dataset | Original source | Archive copy | Save as (`data/raw/`) |
|---|---|---|---|
| Medicare Part B Spending by Drug | [data.cms.gov](https://data.cms.gov/summary-statistics-on-use-and-payments/medicare-medicaid-spending-by-drug/medicare-part-b-spending-by-drug) | [DataLumos 227923](https://www.datalumos.org/datalumos/project/227923/version/V1/view) | `partb_spending_by_drug.csv` |
| Medicare Part D Spending by Drug | [data.cms.gov](https://data.cms.gov/summary-statistics-on-use-and-payments/medicare-medicaid-spending-by-drug/medicare-part-d-spending-by-drug) | [DataLumos 227922](https://www.datalumos.org/datalumos/project/227922/version/V1/view) | `partd_spending_by_drug.csv` |

`data/reference/oncology_drugs.csv` lists the 21 brands in scope with class, tumour area, manufacturer,
molecule type, FDA approval year and IRA negotiated-price year (from CMS announcements).

## Project structure

```
├── data/
│   ├── raw/                      CMS files (not uploaded - see links above)
│   ├── reference/                oncology_drugs.csv
│   ├── clean/                    output of the notebook, loaded into DuckDB
│   └── powerbi/                  view exports used by the dashboard
├── notebooks/
│   └── 01_data_cleaning.ipynb    load, check, filter to oncology, reshape, save
├── sql/
│   ├── 01_create_and_load.sql    tables + CSV load + checks
│   ├── 02_analysis.sql           the 7 business questions
│   ├── 03_powerbi_views.sql      views used by the dashboard
│   └── 04_export_for_powerbi.sql saves the views as CSV for Power BI
├── powerbi/
│   ├── oncology_dashboard.pbix
│   ├── dashboard_guide.md        data model, DAX measures, page layout
│   └── screenshots/
└── docs/
    └── data_dictionary.md
```

## How to run

**1. Clean the data (Python)**
```bash
pip install -r requirements.txt
python -m jupyter nbconvert --to notebook --execute --inplace notebooks/01_data_cleaning.ipynb
```

**2. Load and analyse (DuckDB)**

Install the DuckDB command-line tool (Windows: `winget install DuckDB.cli`), then from the project folder run:
```bash
duckdb oncology.duckdb -c ".read sql/01_create_and_load.sql"
duckdb oncology.duckdb -c ".read sql/02_analysis.sql"
duckdb oncology.duckdb -c ".read sql/03_powerbi_views.sql"
duckdb oncology.duckdb -c ".read sql/04_export_for_powerbi.sql"
```
To explore the results one query at a time, open the database in the browser-based DuckDB UI: `duckdb oncology.duckdb -ui`.

**3. Dashboard (Power BI Desktop)**
- Load the CSVs from `data/powerbi/` and follow `powerbi/dashboard_guide.md`.

## Limitations

- **Scope:** 21 leading brands, not every cancer drug; shares are within this group.
- **Medicare fee-for-service only.** Part B figures exclude Medicare Advantage; commercial insurance is not covered.
- **Gross spend.** Amounts are before manufacturer rebates, so real net prices are lower (especially in Part D).
- **Spend per patient** uses CMS beneficiary counts per drug; a patient on several drugs is counted for each.
- **Data ends in 2022.** IRA negotiated prices (2026-2028) are compared with 2022 spend to show exposure,
  not to forecast savings.
- **IRA timing is simplified.** The 9/13-year rule gives the earliest possible year; actual selection also
  depends on spend ranking and exclusions.

## Next steps

- Refresh with the latest CMS release (2020-2024) when available; the SQL picks up new years automatically.
- Add state-level data to compare regional use of infused vs oral therapies.
- Add Part D formulary data to compare prior authorisation and tier placement for oral cancer drugs.

---
**Bhanu Pratap** · Data Analyst · [LinkedIn](https://www.linkedin.com/in/bhanu-pratap-94961a209)
