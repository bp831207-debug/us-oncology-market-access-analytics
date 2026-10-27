-- =============================================================================
-- 02_analysis.sql
-- Seven business questions on the Medicare oncology drug market.
--   Q1-Q3  Commercial analytics  (market size, brands, tumour areas)
--   Q4-Q7  Market access         (pricing, cost per patient, IRA negotiation)
-- Spend = gross Medicare spend before manufacturer rebates.
-- "Latest year" and "first year" are read from the data, so the queries work
-- for any release of the CMS files without editing.
--
-- Run all:   duckdb oncology.duckdb -c ".read sql/02_analysis.sql"
-- Or open the database in the DuckDB UI (duckdb oncology.duckdb -ui) and run one query at a time.
-- =============================================================================


-- =============================================================================
-- Q1. How big is Medicare oncology spend, and is Part B or Part D growing faster?
-- =============================================================================

-- 1a. Oncology spend by benefit and year, with share of ALL drug spend and YoY growth
WITH onc AS (
    SELECT benefit, data_year, SUM(total_spend) AS onc_spend
    FROM national_spend
    GROUP BY benefit, data_year
)
SELECT
    o.benefit,
    o.data_year,
    ROUND(o.onc_spend / 1e6, 1)                                AS onc_spend_mn,
    ROUND(100 * o.onc_spend / t.all_drugs_spend, 1)            AS pct_of_all_drug_spend,
    ROUND(100 * (o.onc_spend / LAG(o.onc_spend) OVER (PARTITION BY o.benefit ORDER BY o.data_year) - 1), 1)
                                                               AS yoy_growth_pct
FROM onc o
JOIN benefit_totals t
  ON t.benefit = o.benefit AND t.data_year = o.data_year
ORDER BY o.benefit, o.data_year;

-- 1b. Compound annual growth rate (CAGR) from first to latest year, by benefit
WITH onc AS (
    SELECT benefit, data_year, SUM(total_spend) AS onc_spend
    FROM national_spend
    GROUP BY benefit, data_year
),
yrs AS (
    SELECT MIN(data_year) AS first_year, MAX(data_year) AS last_year FROM national_spend
)
SELECT
    o.benefit,
    y.first_year,
    y.last_year,
    ROUND(MAX(CASE WHEN o.data_year = y.first_year THEN o.onc_spend END) / 1e6, 1) AS spend_first_year_mn,
    ROUND(MAX(CASE WHEN o.data_year = y.last_year  THEN o.onc_spend END) / 1e6, 1) AS spend_last_year_mn,
    ROUND(100 * (POWER(MAX(CASE WHEN o.data_year = y.last_year  THEN o.onc_spend END)
                     / MAX(CASE WHEN o.data_year = y.first_year THEN o.onc_spend END),
                       1.0 / (y.last_year - y.first_year)) - 1), 1)                 AS cagr_pct
FROM onc o
CROSS JOIN yrs y
GROUP BY o.benefit, y.first_year, y.last_year
ORDER BY o.benefit;


-- =============================================================================
-- Q2. Which brands lead each channel in the latest year, and which are growing fastest?
-- =============================================================================
WITH brand_spend AS (
    SELECT benefit, brand, data_year, SUM(total_spend) AS spend
    FROM national_spend
    GROUP BY benefit, brand, data_year
),
with_growth AS (
    SELECT
        *,
        LAG(spend) OVER (PARTITION BY brand ORDER BY data_year)                AS prev_spend,
        RANK()     OVER (PARTITION BY benefit, data_year ORDER BY spend DESC)  AS spend_rank,
        spend / SUM(spend) OVER (PARTITION BY benefit, data_year)              AS share_of_benefit
    FROM brand_spend
)
SELECT
    benefit,
    spend_rank,
    brand,
    ROUND(spend / 1e6, 1)                                AS spend_mn,
    ROUND(100 * share_of_benefit, 1)                     AS share_pct,
    ROUND(100 * (spend - prev_spend) / prev_spend, 1)    AS yoy_growth_pct
FROM with_growth
WHERE data_year = (SELECT MAX(data_year) FROM national_spend)
ORDER BY benefit, spend_rank;


-- =============================================================================
-- Q3. In each tumour area, how does spend split between infused (Part B)
--     and oral (Part D) drugs?  (latest year)
-- =============================================================================
SELECT
    d.tumour_area,
    ROUND(SUM(n.total_spend) / 1e6, 1)                                                  AS total_spend_mn,
    ROUND(100 * SUM(CASE WHEN n.benefit = 'Part B' THEN n.total_spend ELSE 0 END)
              / SUM(n.total_spend), 1)                                                  AS pct_infused_part_b,
    ROUND(100 * SUM(CASE WHEN n.benefit = 'Part D' THEN n.total_spend ELSE 0 END)
              / SUM(n.total_spend), 1)                                                  AS pct_oral_part_d,
    STRING_AGG(DISTINCT d.brand, ', ' ORDER BY d.brand)                                 AS brands
FROM national_spend n
JOIN oncology_drugs d ON d.brand = n.brand
WHERE n.data_year = (SELECT MAX(data_year) FROM national_spend)
GROUP BY d.tumour_area
ORDER BY total_spend_mn DESC;


-- =============================================================================
-- Q4. How has the Part B price per mg changed for infused drugs?
--     Price per mg lets different products be compared (billing units differ:
--     Keytruda is billed per 1 mg, Tecentriq per 10 mg, Padcev per 0.25 mg).
-- =============================================================================
WITH price AS (
    SELECT
        brand,
        data_year,
        SUM(total_spend) / SUM(total_units * mg_per_unit) AS spend_per_mg
    FROM national_spend
    WHERE benefit = 'Part B'
      AND total_units > 0
      AND mg_per_unit IS NOT NULL
    GROUP BY brand, data_year
),
with_first AS (
    -- price in the brand's first year in the data (or its launch year if later)
    SELECT
        *,
        MIN(data_year) OVER (PARTITION BY brand)                                AS first_year,
        FIRST_VALUE(spend_per_mg) OVER (PARTITION BY brand ORDER BY data_year)  AS first_price
    FROM price
)
SELECT
    brand,
    first_year,
    ROUND(first_price, 2)                              AS price_per_mg_first_year,
    ROUND(spend_per_mg, 2)                             AS price_per_mg_latest,
    ROUND(100 * (spend_per_mg / first_price - 1), 1)   AS pct_change
FROM with_first
WHERE data_year = (SELECT MAX(data_year) FROM national_spend)
ORDER BY pct_change DESC;


-- =============================================================================
-- Q5. What does Medicare spend per patient per year on each drug?  (latest year)
--     A simple way to compare the annual cost of treatment across brands and
--     between infused and oral drugs.
-- =============================================================================
SELECT
    n.benefit,
    n.brand,
    d.drug_class,
    SUM(n.total_beneficiaries)                                     AS patients,
    ROUND(SUM(n.total_spend) / SUM(n.total_beneficiaries), 0)      AS spend_per_patient,
    RANK() OVER (PARTITION BY n.benefit
                 ORDER BY SUM(n.total_spend) / SUM(n.total_beneficiaries) DESC) AS cost_rank
FROM national_spend n
JOIN oncology_drugs d ON d.brand = n.brand
WHERE n.data_year = (SELECT MAX(data_year) FROM national_spend)
  AND n.total_beneficiaries > 0
GROUP BY n.benefit, n.brand, d.drug_class
ORDER BY n.benefit, cost_rank;


-- =============================================================================
-- Q6. How much oncology spend falls on drugs selected for IRA price negotiation?
-- =============================================================================

-- 6a. Share of latest-year oncology spend on negotiated drugs, by benefit
SELECT
    n.benefit,
    ROUND(SUM(n.total_spend) / 1e6, 1)                                                    AS onc_spend_mn,
    ROUND(SUM(CASE WHEN d.ira_price_year IS NOT NULL THEN n.total_spend ELSE 0 END) / 1e6, 1) AS negotiated_spend_mn,
    ROUND(100 * SUM(CASE WHEN d.ira_price_year IS NOT NULL THEN n.total_spend ELSE 0 END)
              / SUM(n.total_spend), 1)                                                    AS pct_negotiated
FROM national_spend n
JOIN oncology_drugs d ON d.brand = n.brand
WHERE n.data_year = (SELECT MAX(data_year) FROM national_spend)
GROUP BY n.benefit
ORDER BY n.benefit;

-- 6b. The negotiated brands, by the year their new price starts
SELECT
    d.ira_price_year,
    d.brand,
    d.drug_class,
    d.manufacturer,
    ROUND(SUM(n.total_spend) / 1e6, 1) AS spend_latest_year_mn
FROM oncology_drugs d
JOIN national_spend n
  ON n.brand = d.brand
 AND n.data_year = (SELECT MAX(data_year) FROM national_spend)
WHERE d.ira_price_year IS NOT NULL
GROUP BY d.ira_price_year, d.brand, d.drug_class, d.manufacturer
ORDER BY d.ira_price_year, spend_latest_year_mn DESC;


-- =============================================================================
-- Q7. How does the IRA "9 vs 13 year" rule affect oral vs infused drugs?
--     Small molecules (mostly oral pills) can get a negotiated price 9 years
--     after FDA approval; biologics (mostly infusions) after 13 years.
--     Negotiated prices started in 2026, and Part B drugs only from 2028.
--     This is the EARLIEST possible year - actual selection also depends on
--     Medicare spend ranking and exclusions (e.g. orphan drugs).
-- =============================================================================

-- 7a. Earliest possible negotiated-price year per brand vs what actually happened
SELECT
    brand,
    benefit,
    molecule_type,
    fda_approval_year,
    CASE WHEN molecule_type = 'Small molecule' THEN 9 ELSE 13 END          AS years_protected,
    GREATEST(fda_approval_year + CASE WHEN molecule_type = 'Small molecule' THEN 9 ELSE 13 END,
             CASE WHEN benefit = 'Part B' THEN 2028 ELSE 2026 END)        AS earliest_possible_year,
    COALESCE(CAST(ira_price_year AS VARCHAR), 'Not selected yet')         AS actual_price_year
FROM oncology_drugs
ORDER BY earliest_possible_year, brand;

-- 7b. Summary by molecule type: how many brands, years on market, how many selected so far
SELECT
    molecule_type,
    COUNT(*)                                                               AS brands,
    ROUND(AVG(YEAR(CURRENT_DATE) - fda_approval_year), 1)                  AS avg_years_on_market,
    SUM(CASE WHEN ira_price_year IS NOT NULL THEN 1 ELSE 0 END)            AS selected_so_far
FROM oncology_drugs
GROUP BY molecule_type
ORDER BY molecule_type;
