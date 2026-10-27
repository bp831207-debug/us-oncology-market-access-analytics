# Power BI Dashboard: Build Notes

The dashboard uses the 5 CSV files in `data/powerbi/`, exported from the DuckDB views by
`sql/04_export_for_powerbi.sql`.

## 1. Load the data

1. Power BI Desktop → **Get data → Text/CSV**.
2. Load each file from `data/powerbi/`: `vw_drugs`, `vw_brand_year`, `vw_benefit_year`,
   `vw_partb_price`, `vw_ira_timeline`.
3. In Power Query, check the types: `data_year` → **Whole number**, spend and cost columns →
   **Decimal number**, `brand` and `benefit` → **Text**.

To update the dashboard later: re-run the SQL scripts, then click **Refresh** in Power BI.

## 2. Data model

`vw_drugs` is the brand table. Relationships (Model view), one-to-many from `vw_drugs[brand]`:

```
vw_drugs[brand] 1 ──< * vw_brand_year[brand]
vw_drugs[brand] 1 ──< * vw_partb_price[brand]
```

`vw_benefit_year` and `vw_ira_timeline` stay unconnected; they feed their own visuals only.

## 3. Measures

Most measures sit on `vw_brand_year`. "Latest year" is found from the data, so the cards update
automatically when a new CMS year is added.

```dax
Total Spend = SUM ( vw_brand_year[total_spend] )

Total Beneficiaries = SUM ( vw_brand_year[total_beneficiaries] )

Oncology Spend (Latest Year) =
VAR y = CALCULATE ( MAX ( vw_brand_year[data_year] ), REMOVEFILTERS ( vw_brand_year ) )
RETURN
    CALCULATE ( [Total Spend], REMOVEFILTERS ( vw_brand_year[data_year] ), vw_brand_year[data_year] = y )

Spend (Prior Year) =
VAR y = CALCULATE ( MAX ( vw_brand_year[data_year] ), REMOVEFILTERS ( vw_brand_year ) )
RETURN
    CALCULATE ( [Total Spend], REMOVEFILTERS ( vw_brand_year[data_year] ), vw_brand_year[data_year] = y - 1 )

YoY Growth % = DIVIDE ( [Oncology Spend (Latest Year)] - [Spend (Prior Year)], [Spend (Prior Year)] )

Part B Share % =
DIVIDE ( CALCULATE ( [Oncology Spend (Latest Year)], vw_drugs[benefit] = "Part B" ), [Oncology Spend (Latest Year)] )

IRA Negotiated Share of Part D % =
DIVIDE (
    CALCULATE ( [Oncology Spend (Latest Year)], vw_drugs[benefit] = "Part D", vw_drugs[ira_selected] = "Yes" ),
    CALCULATE ( [Oncology Spend (Latest Year)], vw_drugs[benefit] = "Part D" )
)

Share of Benefit % =
DIVIDE ( [Oncology Spend (Latest Year)], CALCULATE ( [Oncology Spend (Latest Year)], ALLEXCEPT ( vw_drugs, vw_drugs[benefit] ) ) )

Patients (Latest Year) =
VAR y = CALCULATE ( MAX ( vw_brand_year[data_year] ), REMOVEFILTERS ( vw_brand_year ) )
RETURN
    CALCULATE ( [Total Beneficiaries], REMOVEFILTERS ( vw_brand_year[data_year] ), vw_brand_year[data_year] = y )

Spend per Patient (Latest Year) = DIVIDE ( [Oncology Spend (Latest Year)], [Patients (Latest Year)] )

Spend, Latest Year ($M) = DIVIDE ( [Oncology Spend (Latest Year)], 1000000 )

Brands Selected for IRA Negotiation = CALCULATE ( COUNTROWS ( vw_drugs ), vw_drugs[ira_selected] = "Yes" )

-- on vw_benefit_year
Oncology Share of All Drug Spend % =
DIVIDE ( SUM ( vw_benefit_year[onc_spend] ), SUM ( vw_benefit_year[all_drugs_spend] ) )

-- on vw_partb_price
Price Index = AVERAGE ( vw_partb_price[price_index] )
```

Formats: spend → `$#,0`, `%` measures → `0.0%`.

## 4. Pages

**Page 1: Market Overview**
- Cards: `Oncology Spend (Latest Year)`, `YoY Growth %`, `Part B Share %`, `IRA Negotiated Share of Part D %`
- Slicer (dropdown): `vw_drugs[benefit]`
- Line chart: oncology spend by benefit, X `data_year`, Y `Total Spend`, Legend `benefit`
- Line chart: `Oncology Share of All Drug Spend %` by `vw_benefit_year[data_year]` and `benefit`
- Stacked column chart: spend by brand in the latest year, coloured by `benefit`

**Page 2: Brands & Tumour Areas**
- Table: `brand`, `benefit`, `drug_class`, `Spend, Latest Year ($M)`, `Share of Benefit %`, `YoY Growth %`
- 100% stacked bar: `tumour_area` by `Total Spend`, Legend `route` (Infused / Oral)
- Clustered bar: `manufacturer` by `Oncology Spend (Latest Year)`

**Page 3: Market Access & Pricing**
- Line chart: Part B `Price Index` by `data_year` and `brand` (first year = 100)
- Column chart: `Spend per Patient (Latest Year)` by `brand`, coloured by `route`
- Table: `vw_ira_timeline` (`brand`, `benefit`, `molecule_type`, `fda_approval_year`, `earliest_possible_year`, `ira_price_year`)
- Cards: `IRA Negotiated Share of Part D %`, `Brands Selected for IRA Negotiation`

## 5. Finish

- Each page has a subtitle naming the source: CMS Medicare Part B & Part D Spending by Drug, gross spend before rebates.
- Save as `powerbi/oncology_dashboard.pbix`.
- Export a screenshot of each page to `powerbi/screenshots/` as `page1_overview.png`,
  `page2_brands.png`, `page3_market_access.png` (used in the main README).
