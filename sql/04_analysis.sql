/* Purpose: Details of Analysis queries that are behind the report findings.
   Run after: 03_views.sql. Each query can be run on its own.
   Convention: Amounts are signed (revenue +, costs -), so a positive
   variance is always favourable.
*/
USE NovaPay;
GO

-- 1. Actual vs Budget by account, FY2025.
--    Check: Payment Processing Fees +2.74M, Network & Processing Costs -1.06M.
SELECT ac.account_id, ac.account_name, ac.pl_group,
       SUM(CASE WHEN f.scenario = 'Actual' THEN f.amt_usd END) AS actual_usd,
       SUM(CASE WHEN f.scenario = 'Budget' THEN f.amt_usd END) AS budget_usd,
       SUM(CASE WHEN f.scenario = 'Actual' THEN f.amt_usd ELSE -f.amt_usd END) AS variance_usd
FROM rpt.vw_fact_pnl AS f
INNER JOIN stg.dim_account AS ac 
	ON ac.account_id = f.account_id
WHERE f.fiscal_year = 2025
GROUP BY ac.account_id, ac.account_name, ac.pl_group
ORDER BY ac.account_id;

-- 2. FX bridge by entity, FY2025: Operating Variance (constant currency) vs FX impact.
--    Check (total): operating variance +0.885M, FX impact -0.064M.
WITH by_entity AS
	(SELECT entity_name,
		ROUND(SUM(CASE WHEN scenario = 'Budget' THEN f.amt_constant_ccy END),0) AS budget_const_ccy,
		ROUND(SUM(CASE WHEN scenario = 'Actual' THEN f.amt_constant_ccy END),0) AS actual_const_ccy,
		ROUND(SUM(CASE WHEN scenario = 'Actual' THEN f.amt_usd END),0) AS actual_usd
	FROM rpt.vw_fact_pnl AS f
	JOIN stg.dim_entity AS e
		ON f.entity_id = e.entity_id
	WHERE f.fiscal_year = 2025
	GROUP BY entity_name)
SELECT entity_name,
	budget_const_ccy,
	actual_const_ccy - budget_const_ccy	AS operating_variance,
	actual_usd - actual_const_ccy AS fx_impact,
	actual_usd
FROM by_entity;

-- 3. Five largest unfavourable variances by entity, account and month.
WITH variances AS
	(SELECT entity_id, account_id, month_start,
		SUM(CASE WHEN scenario = 'Actual' THEN amt_usd ELSE -amt_usd END) AS variance_usd
	FROM rpt.vw_fact_pnl
	GROUP BY entity_id, account_id, month_start)
SELECT TOP 5
	entity_id, account_id, month_start, variance_usd,
	ROW_NUMBER() OVER(ORDER BY variance_usd) AS rnk
FROM variances
ORDER BY variance_usd;

-- 4. Months where UK credit loss provision exceeded budget by more than 50%.
--    Check: July to December 2024.
WITH prov_loss AS 
	(SELECT month_start, entity_id, account_id,
		SUM(CASE WHEN scenario = 'Actual' THEN -amt_usd ELSE 0 END) AS actual_credit_loss_prov,
		SUM(CASE WHEN scenario = 'Budget' THEN -amt_usd ELSE 0 END) AS budget_credit_loss_prov
	FROM rpt.vw_fact_pnl
	WHERE account_id = 5030
	GROUP BY month_start, entity_id, account_id)
SELECT month_start, entity_id, actual_credit_loss_prov, budget_credit_loss_prov,
	(actual_credit_loss_prov - budget_credit_loss_prov) / NULLIF(budget_credit_loss_prov, 0) AS act_to_budget
FROM prov_loss
WHERE entity_id = 2 
	AND ((actual_credit_loss_prov - budget_credit_loss_prov) / NULLIF(budget_credit_loss_prov, 0)) > 0.5
ORDER BY month_start;

-- 5. Revenue trend per entity: month-on-month change, year-to-date, rolling 3 months.
SELECT month_start, entity_id, revenue_usd,
	revenue_usd - LAG(revenue_usd) OVER(PARTITION BY entity_id ORDER BY month_start) AS MoM_change,
	SUM(revenue_usd) OVER(PARTITION BY entity_id, YEAR(month_start) ORDER BY month_start) AS ytd_rev,
	AVG(revenue_usd) OVER (PARTITION BY entity_id ORDER BY month_start
		ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS rolling_3m_avg
FROM rpt.vw_unit_economics
ORDER BY entity_id, month_start;

-- 6. Year-on-year revenue growth per entity (same month last year i.e. 12 rows back).
WITH yoy AS
	(SELECT month_start, entity_id, revenue_usd,
		LAG(revenue_usd, 12) OVER(PARTITION BY entity_id ORDER BY month_start) AS prev_year_rev
	FROM rpt.vw_unit_economics)
SELECT month_start, entity_id, revenue_usd, prev_year_rev,
	ROUND((revenue_usd - prev_year_rev) / NULLIF(prev_year_rev, 0) * 100, 2) AS yoy_rev_growth_pct
FROM yoy
ORDER BY entity_id, month_start;