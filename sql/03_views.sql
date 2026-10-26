/* Purpose: Creating "reporting" views to be used in Power BI (rpt schema).
   Run after: 02_quality_checks.sql.
   Staging data is not changed: duplicates are removed here, amounts are signed
   (revenue positive, costs negative) and translated to USD.
*/
USE NovaPay;
GO

-- 1. Actuals without the duplicate rows.
CREATE VIEW rpt.vw_actuals_clean AS
WITH ranked AS
    (SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY month_start, entity_id, product_id, cost_center_id, account_id
               ORDER BY (SELECT NULL)) AS row_num
    FROM stg.fact_actuals)
SELECT month_start, entity_id, product_id, cost_center_id, account_id, amount_local
FROM ranked
WHERE row_num = 1;
GO

-- 2. Actual and Budget stacked in one P&L fact view.
--    amt_usd          = reported USD (actuals at monthly rates, budget at the budget rate)
--    amt_constant_ccy = constant currency (everything at the budget rate)
CREATE VIEW rpt.vw_fact_pnl AS
WITH actual_budget_comb AS
    (SELECT 'Actual' AS scenario, month_start, entity_id, product_id, cost_center_id, account_id, amount_local
    FROM rpt.vw_actuals_clean
    UNION ALL
    SELECT 'Budget' AS scenario, month_start, entity_id, product_id, cost_center_id, account_id, amount_local
    FROM stg.fact_budget)
SELECT s.scenario,
       s.month_start,
       YEAR(s.month_start) AS fiscal_year,
       s.entity_id, s.product_id, s.cost_center_id, s.account_id,
       s.amount_local * ac.pl_sign AS amt_local_signed,
       s.amount_local * ac.pl_sign *
           CASE WHEN s.scenario = 'Actual' THEN fx.usd_per_local ELSE fb.usd_per_local END AS amt_usd,
       s.amount_local * ac.pl_sign * fb.usd_per_local AS amt_constant_ccy
FROM actual_budget_comb AS s
INNER JOIN stg.dim_account AS ac ON ac.account_id = s.account_id
INNER JOIN stg.dim_entity AS e ON e.entity_id = s.entity_id
INNER JOIN stg.fx_rates AS fx ON fx.month_start = s.month_start AND fx.currency = e.currency
INNER JOIN stg.fx_budget_rates AS fb ON fb.fiscal_year = YEAR(s.month_start) AND fb.currency = e.currency;
GO

-- 3. Base amounts for the unit-economics KPIs, one row per entity per month (USD).
--    Ratios are calculated in Power BI as sum divided by sum, not stored here.
CREATE VIEW rpt.vw_unit_economics AS
WITH pl AS
	(SELECT month_start, entity_id,
		ROUND(SUM(CASE WHEN ac.pl_group = 'Revenue' THEN amt_usd END),2) AS revenue_usd,
		ROUND(SUM(CASE WHEN f.account_id = 4010 THEN amt_usd END),2) AS pymt_rev_usd,
		ROUND(SUM(CASE WHEN f.account_id = 4020 THEN amt_usd END),2) AS int_income_usd,
		ROUND(SUM(CASE WHEN f.account_id = 5010 THEN -amt_usd END),2) AS network_cost_usd,
		ROUND(SUM(CASE WHEN f.account_id = 5020 THEN -amt_usd END),2) AS cost_of_funds_usd,
		ROUND(SUM(CASE WHEN f.account_id = 5030 THEN -amt_usd END),2) AS provision_usd,
		ROUND(SUM(CASE WHEN f.account_id = 6020 THEN -amt_usd END),2) AS mkt_acq_cost_usd,
		ROUND(SUM(CASE WHEN ac.pl_group = 'Operating Expenses' THEN -amt_usd END),2) AS opex_usd
	FROM rpt.vw_fact_pnl AS f
	JOIN stg.dim_account AS ac
		ON f.account_id = ac.account_id
	WHERE scenario = 'Actual'
	GROUP BY month_start, entity_id)
SELECT pl.*,
	k.tpv_local * fx.usd_per_local AS tpv_usd,
	k.loan_book_local * fx.usd_per_local AS loan_book_usd,
	k.npl_balance_local * fx.usd_per_local AS npl_usd,
	k.new_customers, k.active_customers, k.headcount
FROM pl
INNER JOIN stg.fact_kpi AS k ON pl.entity_id = k.entity_id AND pl.month_start = k.month_start
INNER JOIN stg.dim_entity AS e ON pl.entity_id = e.entity_id
INNER JOIN stg.fx_rates AS fx ON fx.month_start = pl.month_start AND fx.currency = e.currency;
GO