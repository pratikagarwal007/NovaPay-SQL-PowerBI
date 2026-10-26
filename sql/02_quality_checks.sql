/* Purpose: Staging data needs to be checked before any reporting is built.
   Run after: 01_setup.sql and the CSV import.
   Findings: 12 duplicate rows and 5 orphan cost-center rows in fact_actuals.
   Nothing is deleted from staging. Duplicates are removed in 03_views.sql.
*/
USE NovaPay;
GO

-- 1. Row counts: Actuals and budget share a grain, so they should match.
--    Result: actuals 2,604 vs budget 2,592.
SELECT 'actuals' AS tbl, COUNT(*) AS num_rows FROM stg.fact_actuals
UNION ALL
SELECT 'budget' AS tbl, COUNT(*) AS num_rows FROM stg.fact_budget;

-- 2. Duplicates on the natural key.
--    Result: 12 keys appear twice (exact duplicates).
SELECT month_start, entity_id, product_id, cost_center_id, account_id, COUNT(*) AS n_rows
FROM stg.fact_actuals
GROUP BY month_start, entity_id, product_id, cost_center_id, account_id
HAVING COUNT(*) > 1;

-- 3. Orphan keys: Fact rows whose key is missing from the dimension table.
--    Result: 5 rows, all in cost_center_id (99).
SELECT a.*
FROM stg.fact_actuals AS a
LEFT JOIN stg.dim_cost_center AS c 
	ON c.cost_center_id = a.cost_center_id
WHERE c.cost_center_id IS NULL;
GO
SELECT a.*
FROM stg.fact_actuals AS a
LEFT JOIN stg.dim_entity AS e 
	ON a.entity_id = e.entity_id
WHERE e.entity_id IS NULL;
GO
SELECT a.*
FROM stg.fact_actuals AS a
LEFT JOIN stg.dim_product AS p 
	ON p.product_id = a.product_id
WHERE p.product_id IS NULL;
GO
SELECT a.*
FROM stg.fact_actuals AS a
LEFT JOIN stg.dim_account AS ac 
	ON ac.account_id = a.account_id
WHERE ac.account_id IS NULL;

-- 4. Coverage: Each entity should have all 36 months.
SELECT entity_id, COUNT(DISTINCT month_start) AS months
FROM stg.fact_actuals
GROUP BY entity_id;

-- Treatment for the orphan rows: Parked them under an Unmapped cost center so
-- no amount is lost from the totals and the rows stay visible and flagged.
INSERT INTO stg.dim_cost_center (cost_center_id, cost_center_name)
VALUES (99, 'Unmapped - Needs Review');
GO