**NovaPay Financial Performance Report**

A SQL Server + Power BI project on a simulated multi-currency fintech (payments and lending across the US, UK and India). It covers budget vs actual analysis, FX impact, unit economics and forecasting, from raw ledger data to an executive-ready report.

All data is simulated for a fictional company. No real company or figures are used.

Executive Summary

What it shows:
Variance Analysis: A full P&L against budget, drilling from account to cost center, with a bridge that separates real performance from currency movement.
Forecasting: A latest-estimate view (actuals to a chosen month, budget after) against the original plan.
Fintech Metrics: Take Rate, Net Interest Margin, Cost of Risk, NPL Ratio, CAC and revenue per employee, with 36-month trends by entity.
Data Discipline: SQL cleaning and reconciliation, with every figure in the report tied back to a SQL checkpoint.

Key Findings (FY2025)
1. Revenue of $53.09M was about $2.4M (4.8%) ahead of budget; net operating income was -$0.82M against -$1.64M budgeted.
2. The US drove the beat (+$1.27M operating variance), partly offset by higher network costs (-$1.06M).
3. UK credit stress in H2 2024: The NPL ratio rose from ~2.6% to 6.4% before recovering by April 2025.
4. FX was a small drag (-$0.06M), so the improvement is operational, not currency-driven.

What is in the repo:
| Folder | Contents |
|---|---|
|'sql/' |	Four scripts: setup, data-quality checks, reporting views, analysis queries (CTEs, window functions)
|'powerbi/' |	The report: star-schema model, DAX measures, five pages plus a notes page
|'data/' | The simulated CSV files
|'docs/' |	Report PDF and screenshots

Pages: Executive Summary | Budget vs Actual P&L | FX and Constant-Currency Bridge | Unit Economics | Forecast | Notes

How it was built:
Raw CSVs, loaded into a SQL Server staging schema, checked and cleaned (12 duplicate rows and 5 orphan keys found and documented), exposed through reporting views, and modelled in Power BI. The Notes page in the report lists the definitions and the data-quality log.

Tools: SQL Server, Power BI, DAX

To reproduce: Run the scripts in sql/ in order, after importing the CSVs from data/.

Limitations: Simulated data, so the patterns are illustrative. The forecast holds remaining months at budget, and the model covers the income statement only.

Author: 
Pratik Agarwal | linkedin.com/in/pratik-agarwal-cfa-a78446182 | pratik.agarwal8@gmail.com
