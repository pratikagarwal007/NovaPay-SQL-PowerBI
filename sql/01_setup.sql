/* Purpose: Creating the NovaPay database and its two schemas.
   This needs to be run first, from any database.

   After running it, the 9 CSV files need to be imported from the data folder into the "stg" schema.
   Below are the table names and the same has been kept as its file name:
     dim_entity, dim_product, dim_cost_center, dim_account,
     fx_rates, fx_budget_rates, fact_actuals, fact_budget, fact_kpi

   Details of column types:
     month_start                -> date
     amount columns             -> decimal(18,2)
     usd_per_local              -> decimal(18,6)
     IDs, pl_sign, counts       -> int
     text columns               -> nvarchar(100)
*/

CREATE DATABASE NovaPay;
GO
USE NovaPay;
GO
CREATE SCHEMA stg;   -- staging: data exactly as received
GO
CREATE SCHEMA rpt;   -- reporting: cleaned views used by Power BI
GO