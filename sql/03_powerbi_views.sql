-- =============================================================================
-- 03_powerbi_views.sql
-- Views for the dashboard. Each view is already at the level a visual needs.
-- 04_export_for_powerbi.sql then saves them as CSV files for Power BI.
--
-- Run:   duckdb oncology.duckdb -c ".read sql/03_powerbi_views.sql"
-- =============================================================================


-- Brand attributes (used as the "drug" dimension in Power BI)
CREATE OR REPLACE VIEW vw_drugs AS
SELECT
    brand,
    benefit,
    CASE WHEN benefit = 'Part B' THEN 'Infused' ELSE 'Oral' END   AS route,
    drug_class,
    tumour_area,
    manufacturer,
    molecule_type,
    fda_approval_year,
    ira_price_year,
    CASE WHEN ira_price_year IS NOT NULL THEN 'Yes' ELSE 'No' END  AS ira_selected
FROM oncology_drugs;


-- National spend, claims and patients per brand per year
CREATE OR REPLACE VIEW vw_brand_year AS
SELECT
    brand,
    benefit,
    data_year,
    SUM(total_spend)           AS total_spend,
    SUM(total_claims)          AS total_claims,
    SUM(total_beneficiaries)   AS total_beneficiaries,
    SUM(total_spend) / NULLIF(SUM(total_beneficiaries), 0) AS spend_per_patient
FROM national_spend
GROUP BY brand, benefit, data_year;


-- Oncology vs all-drug spend per benefit per year
CREATE OR REPLACE VIEW vw_benefit_year AS
SELECT
    t.benefit,
    t.data_year,
    o.onc_spend,
    t.all_drugs_spend,
    o.onc_spend / t.all_drugs_spend AS onc_share_of_all_drugs
FROM benefit_totals t
JOIN (
    SELECT benefit, data_year, SUM(total_spend) AS onc_spend
    FROM national_spend
    GROUP BY benefit, data_year
) o ON o.benefit = t.benefit AND o.data_year = t.data_year;


-- Part B price per mg per brand per year, indexed to the first year (= 100)
CREATE OR REPLACE VIEW vw_partb_price AS
WITH price AS (
    SELECT brand, data_year,
           SUM(total_spend) / SUM(total_units * mg_per_unit) AS spend_per_mg
    FROM national_spend
    WHERE benefit = 'Part B' AND total_units > 0 AND mg_per_unit IS NOT NULL
    GROUP BY brand, data_year
)
SELECT
    brand,
    data_year,
    spend_per_mg,
    100 * spend_per_mg / FIRST_VALUE(spend_per_mg) OVER (PARTITION BY brand ORDER BY data_year) AS price_index
FROM price;


-- IRA timeline per brand: earliest possible vs actual negotiated-price year
CREATE OR REPLACE VIEW vw_ira_timeline AS
SELECT
    d.brand,
    d.benefit,
    d.molecule_type,
    d.fda_approval_year,
    CASE WHEN d.molecule_type = 'Small molecule' THEN 9 ELSE 13 END AS years_protected,
    GREATEST(d.fda_approval_year + CASE WHEN d.molecule_type = 'Small molecule' THEN 9 ELSE 13 END,
             CASE WHEN d.benefit = 'Part B' THEN 2028 ELSE 2026 END) AS earliest_possible_year,
    d.ira_price_year,
    s.spend_latest_year
FROM oncology_drugs d
LEFT JOIN (
    SELECT brand, SUM(total_spend) AS spend_latest_year
    FROM national_spend
    WHERE data_year = (SELECT MAX(data_year) FROM national_spend)
    GROUP BY brand
) s ON s.brand = d.brand;


-- Check the views
SELECT 'vw_drugs' AS view_name, COUNT(*) AS row_count FROM vw_drugs
UNION ALL SELECT 'vw_brand_year',   COUNT(*) FROM vw_brand_year
UNION ALL SELECT 'vw_benefit_year', COUNT(*) FROM vw_benefit_year
UNION ALL SELECT 'vw_partb_price',  COUNT(*) FROM vw_partb_price
UNION ALL SELECT 'vw_ira_timeline', COUNT(*) FROM vw_ira_timeline;
