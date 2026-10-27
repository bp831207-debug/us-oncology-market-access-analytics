-- =============================================================================
-- 01_create_and_load.sql
-- Creates the tables and loads the clean CSVs produced by the notebook.
--
-- Run from the project folder (paths below are relative to it):
--     duckdb oncology.duckdb -c ".read sql/01_create_and_load.sql"
-- Before running: run notebooks/01_data_cleaning.ipynb so data/clean/ has the 2 CSVs.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Reference table: the 21 oncology brands in scope
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE oncology_drugs (
    brand               VARCHAR PRIMARY KEY,
    generic_keyword     VARCHAR NOT NULL,
    generic_name        VARCHAR,
    benefit             VARCHAR NOT NULL,      -- 'Part B' (infused) or 'Part D' (oral)
    drug_class          VARCHAR,
    tumour_area         VARCHAR,
    manufacturer        VARCHAR,
    molecule_type       VARCHAR,               -- 'Biologic' or 'Small molecule'
    fda_approval_year   SMALLINT,
    ira_price_year      SMALLINT               -- year the IRA negotiated price starts (NULL = not selected)
);

-- -----------------------------------------------------------------------------
-- 2. National spend by brand, billing code and year (2018-2022)
--    Part B rows have an HCPCS code and mg per billing unit; Part D rows do not.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE national_spend (
    benefit              VARCHAR NOT NULL,
    brand                VARCHAR NOT NULL,
    source_name          VARCHAR,              -- brand name as written by CMS
    hcpcs_code           VARCHAR,
    data_year            SMALLINT NOT NULL,
    total_spend          DECIMAL(18,2),
    total_claims         BIGINT,
    total_beneficiaries  BIGINT,
    total_units          BIGINT,
    mg_per_unit          DECIMAL(10,3)
);

-- -----------------------------------------------------------------------------
-- 3. Total spend on ALL drugs per benefit and year (to calculate oncology share)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE benefit_totals (
    benefit           VARCHAR NOT NULL,
    data_year         SMALLINT NOT NULL,
    all_drugs_spend   DECIMAL(18,2),
    PRIMARY KEY (benefit, data_year)
);

-- =============================================================================
-- Load the CSV files (empty values become NULL)
-- =============================================================================
COPY oncology_drugs FROM 'data/reference/oncology_drugs.csv' (HEADER);
COPY national_spend FROM 'data/clean/national_spend.csv'      (HEADER);
COPY benefit_totals FROM 'data/clean/benefit_totals.csv'      (HEADER);


-- =============================================================================
-- Quick checks after loading
-- =============================================================================

-- Row counts per table
SELECT 'oncology_drugs' AS table_name, COUNT(*) AS row_count FROM oncology_drugs
UNION ALL SELECT 'national_spend', COUNT(*) FROM national_spend
UNION ALL SELECT 'benefit_totals', COUNT(*) FROM benefit_totals;

-- Every brand in the spend data should exist in the reference table (expect 0 rows)
SELECT DISTINCT n.brand AS brand_missing_from_reference
FROM national_spend n
LEFT JOIN oncology_drugs d ON n.brand = d.brand
WHERE d.brand IS NULL;

-- No negative or missing spend (expect 0)
SELECT COUNT(*) AS bad_spend_rows
FROM national_spend
WHERE total_spend IS NULL OR total_spend < 0;

-- Years loaded per benefit (expect 2018-2022 for both)
SELECT benefit, MIN(data_year) AS first_year, MAX(data_year) AS last_year, COUNT(DISTINCT brand) AS brands
FROM national_spend
GROUP BY benefit
ORDER BY benefit;
