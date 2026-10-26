"""NovaPay FP&A project - synthetic data generator.
Run:  python generate_novapay_data.py   (needs pandas + numpy)
Creates a folder 'novapay_data' with 9 CSV files."""
import os
import numpy as np
import pandas as pd

rng = np.random.default_rng(42)           # fixed seed -> everyone gets the same data
OUT = "novapay_data"
os.makedirs(OUT, exist_ok=True)

months = pd.date_range("2023-01-01", "2025-12-01", freq="MS")
T = len(months)
t = np.arange(T)
ts = pd.Timestamp
g = lambda r: (1 + r) ** t                 # compound growth curve
between = lambda a, b: np.asarray((months >= ts(a)) & (months <= ts(b)))

# ---------- dimensions ----------
dim_entity = pd.DataFrame({
    "entity_id": [1, 2, 3],
    "entity_name": ["NovaPay US", "NovaPay UK", "NovaPay India"],
    "region": ["North America", "Europe", "Asia"],
    "currency": ["USD", "GBP", "INR"]})
dim_product = pd.DataFrame({
    "product_id": [0, 1, 2],
    "product_name": ["Shared / Corporate", "Payments", "Lending"]})
dim_cost_center = pd.DataFrame({
    "cost_center_id": [0, 1, 2, 3, 4, 5, 6],
    "cost_center_name": ["Non-departmental", "Engineering", "Product",
                         "Sales & Marketing", "Operations & Support",
                         "Risk & Compliance", "G&A"]})
dim_account = pd.DataFrame([
    (4010, "Payment Processing Fees", "Revenue", 1),
    (4020, "Interest Income", "Revenue", 1),
    (4030, "Origination Fees", "Revenue", 1),
    (5010, "Network & Processing Costs", "Cost of Revenue", -1),
    (5020, "Cost of Funds", "Cost of Revenue", -1),
    (5030, "Credit Loss Provision", "Cost of Revenue", -1),
    (6010, "Salaries & Benefits", "Operating Expenses", -1),
    (6020, "Marketing & Acquisition", "Operating Expenses", -1),
    (6030, "Cloud & Technology", "Operating Expenses", -1),
    (6040, "Professional Fees", "Operating Expenses", -1),
    (6050, "Rent & Facilities", "Operating Expenses", -1),
    (6060, "Travel & Other", "Operating Expenses", -1)],
    columns=["account_id", "account_name", "pl_group", "pl_sign"])

# ---------- FX (USD per 1 unit of local currency) ----------
gbp = 1.25 + 0.03 * np.sin(t / 5) - 0.04 * between("2024-09-01", "2025-03-01")
inr = 0.0121 * (1 - 0.0011 * t)
fx = {"USD": np.ones(T),
      "GBP": gbp + rng.normal(0, 0.004, T),
      "INR": inr * (1 + rng.normal(0, 0.002, T))}
fx_rates = pd.concat([pd.DataFrame({"month_start": months, "currency": c,
                                    "usd_per_local": v.round(6)})
                      for c, v in fx.items()], ignore_index=True)
# budget rate = the January rate of each year, frozen for the whole year
brate = {c: np.array([v[months.year == y][0] for y in months.year]) for c, v in fx.items()}
fx_budget_rates = pd.DataFrame([(y, c, round(float(v[months.year == y][0]), 6))
                                for c, v in fx.items() for y in (2023, 2024, 2025)],
                               columns=["fiscal_year", "currency", "usd_per_local"])

# ---------- business drivers ----------
season = np.array([.92, .90, .97, .98, 1, 1, 1, 1.02, 1, 1.05, 1.12, 1.14])
seas = (season / season.mean())[np.asarray(months.month) - 1]
ent = {1: dict(cur="USD", rs=1.00, os=1.00, take=1.00, apr=1.00, cof=1.00, el=.040, hc=11000),
       2: dict(cur="GBP", rs=0.55, os=0.55, take=0.90, apr=0.85, cof=0.95, el=.035, hc=8500),
       3: dict(cur="INR", rs=0.40, os=0.30, take=0.70, apr=1.30, cof=1.40, el=.060, hc=3000)}

bud, act, kpi = [], [], []

def emit(e, p, cc, acc, plan, actual):
    """plan / actual are in 'budget-rate USD'; converted to local currency here."""
    br = brate[ent[e]["cur"]]
    for rows, arr in ((bud, plan), (act, actual)):
        rows.append(pd.DataFrame({"month_start": months, "entity_id": e, "product_id": p,
                                  "cost_center_id": cc, "account_id": acc,
                                  "amount_local": (arr / br).round(2)}))

n = lambda s: rng.normal(0, s, T)

for e, c in ent.items():
    # --- Payments ---
    tpv_p = 40e6 * c["rs"] * g(.025) * seas
    tpv_a = tpv_p * (1 + n(.03))
    if e == 1:
        tpv_a = tpv_a * np.where(months >= ts("2024-07-01"), 1.18, 1.0)   # big merchant win
    take, pcost = .014 * c["take"], .0055
    emit(e, 1, 0, 4010, tpv_p * take, tpv_a * take * (1 + n(.01)))
    emit(e, 1, 0, 5010, tpv_p * pcost, tpv_a * pcost * (1 + n(.015)))

    # --- Lending ---
    book_p = 25e6 * c["rs"] * g(.03)
    book_a = book_p * (1 + n(.015))
    if e == 2:
        book_a = book_a * np.where(months >= ts("2024-10-01"), 0.93, 1.0)  # growth stalls
    apr, cof, el = .18 * c["apr"], .07 * c["cof"], c["el"]
    emit(e, 2, 0, 4020, book_p * apr / 12, book_a * apr / 12 * (1 + n(.01)))
    disb_p, disb_a = book_p * .15, book_a * .15 * (1 + n(.05))
    emit(e, 2, 0, 4030, disb_p * .02, disb_a * .02)
    emit(e, 2, 0, 5020, book_p * cof / 12, book_a * cof / 12 * (1 + n(.01)))
    prov_a = book_a * el / 12 * (1 + n(.08))
    if e == 2:
        prov_a = prov_a * np.where(between("2024-07-01", "2024-12-01"), 2.2, 1.0)  # credit stress
    emit(e, 2, 0, 5030, book_p * el / 12, prov_a)

    # --- Operating expenses (product 0 = shared) ---
    sal_total = np.zeros(T)
    for cc, base in {1: 200e3, 2: 60e3, 3: 90e3, 4: 110e3, 5: 70e3, 6: 80e3}.items():
        p_ = base * c["os"] * g(.01)
        a_ = p_ * (1 + n(.015))
        sal_total += a_
        emit(e, 0, cc, 6010, p_, a_)
    mkt_p = 120e3 * c["os"] * g(.02)
    mkt_a = mkt_p * (1 + n(.04))
    if e == 3:
        mkt_a = mkt_a * np.where(between("2025-01-01", "2025-03-01"), 1.5, 1.0)  # campaign overspend
    emit(e, 0, 3, 6020, mkt_p, mkt_a)
    creep = np.where(months >= ts("2025-01-01"), 1.015 ** (t - 23), 1.0)        # cloud cost creep
    for cc, base in {1: 45e3, 4: 15e3}.items():
        p_ = base * c["os"] * g(.02)
        emit(e, 0, cc, 6030, p_, p_ * (1 + n(.03)) * creep)
    for cc, base in {5: 12e3, 6: 20e3}.items():
        p_ = base * c["os"] * g(.01)
        emit(e, 0, cc, 6040, p_, p_ * (1 + n(.08)))
    p_ = 25e3 * c["os"] * g(.01)
    emit(e, 0, 6, 6050, p_, p_)
    for cc in range(1, 7):
        p_ = 4e3 * c["os"] * g(.01)
        emit(e, 0, cc, 6060, p_, p_ * (1 + n(.10)))

    # --- Operating KPIs (one row per month per entity) ---
    npl = book_a * 0.03 * (el / .04) * (1 + n(.05))
    if e == 2:
        npl = npl * np.where(between("2024-08-01", "2025-03-01"), 2.2, 1.0)
    new_c = 4000 * c["rs"] * g(.02) * (1 + n(.05))
    if e == 3:
        new_c = new_c * np.where(between("2025-01-01", "2025-03-01"), 1.35, 1.0)
    br = brate[c["cur"]]
    kpi.append(pd.DataFrame({
        "month_start": months, "entity_id": e,
        "tpv_local": (tpv_a / br).round(0), "loan_book_local": (book_a / br).round(0),
        "npl_balance_local": (npl / br).round(0),
        "new_customers": new_c.round(0).astype(int),
        "active_customers": (100e3 * c["rs"] * g(.02) * (1 + n(.01))).round(0).astype(int),
        "headcount": (sal_total / c["hc"]).round(0).astype(int)}))

fact_budget = pd.concat(bud, ignore_index=True)
fact_actuals = pd.concat(act, ignore_index=True)
fact_kpi = pd.concat(kpi, ignore_index=True)

# ---------- deliberately dirty the actuals (you will find and fix these in SQL) ----------
dups = fact_actuals.sample(12, random_state=1)
fact_actuals = pd.concat([fact_actuals, dups], ignore_index=True)
fact_actuals.loc[fact_actuals.sample(5, random_state=2).index, "cost_center_id"] = 99

for name, df in {"dim_entity": dim_entity, "dim_product": dim_product,
                 "dim_cost_center": dim_cost_center, "dim_account": dim_account,
                 "fx_rates": fx_rates, "fx_budget_rates": fx_budget_rates,
                 "fact_actuals": fact_actuals, "fact_budget": fact_budget,
                 "fact_kpi": fact_kpi}.items():
    df.to_csv(f"{OUT}/{name}.csv", index=False)
    print(f"{name}.csv  {len(df):,} rows")
