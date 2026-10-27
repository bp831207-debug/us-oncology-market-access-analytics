-- =============================================================================
-- 04_export_for_powerbi.sql
-- Saves each dashboard view as a CSV in data/powerbi/ for Power BI to load.
-- Re-run this after any change, then click Refresh in Power BI.
--
-- Run:   duckdb oncology.duckdb -c ".read sql/04_export_for_powerbi.sql"
-- =============================================================================

COPY (SELECT * FROM vw_drugs)        TO 'data/powerbi/vw_drugs.csv'        (HEADER);
COPY (SELECT * FROM vw_brand_year)   TO 'data/powerbi/vw_brand_year.csv'   (HEADER);
COPY (SELECT * FROM vw_benefit_year) TO 'data/powerbi/vw_benefit_year.csv' (HEADER);
COPY (SELECT * FROM vw_partb_price)  TO 'data/powerbi/vw_partb_price.csv'  (HEADER);
COPY (SELECT * FROM vw_ira_timeline) TO 'data/powerbi/vw_ira_timeline.csv' (HEADER);
