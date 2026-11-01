"""Builds the 3 flat CSVs the Tableau Public dashboard reads.

Same logic as sql/03_base_tables.sql and sql/05_retention_rfm.sql (delivered
orders only, customers = customer_unique_id), so numbers match BigQuery.
Run from the repo root:  python tableau/prep_tableau.py
"""
from pathlib import Path

import numpy as np
import pandas as pd

RAW = Path("data/raw")
OUT = Path("tableau/data")
OUT.mkdir(parents=True, exist_ok=True)

REGION = {
    **dict.fromkeys(["SP", "RJ", "MG", "ES"], "Southeast"),
    **dict.fromkeys(["PR", "SC", "RS"], "South"),
    **dict.fromkeys(["BA", "PE", "CE", "MA", "PB", "RN", "AL", "SE", "PI"], "Northeast"),
    **dict.fromkeys(["AM", "PA", "RO", "RR", "AP", "AC", "TO"], "North"),
}

dates = ["order_purchase_timestamp", "order_delivered_customer_date",
         "order_estimated_delivery_date", "order_delivered_carrier_date"]
orders = pd.read_csv(RAW / "olist_orders_dataset.csv", parse_dates=dates)
customers = pd.read_csv(RAW / "olist_customers_dataset.csv")
items = pd.read_csv(RAW / "olist_order_items_dataset.csv")
products = pd.read_csv(RAW / "olist_products_dataset.csv")
cats = pd.read_csv(RAW / "product_category_name_translation.csv")
reviews = pd.read_csv(RAW / "olist_order_reviews_dataset.csv")

# ---- delivered orders with the real person id + order sequence -------------
o = orders[orders.order_status == "delivered"].merge(customers, on="customer_id")
o = o[o.order_id.isin(items.order_id)]  # same as the inner join to items in SQL
o = o.sort_values(["customer_unique_id", "order_purchase_timestamp", "order_id"])
o["order_seq"] = o.groupby("customer_unique_id").cumcount() + 1
o["customer_type"] = np.where(o.order_seq == 1, "New", "Repeat")
o["region"] = o.customer_state.map(REGION).fillna("Center-West")
o["order_month"] = o.order_purchase_timestamp.dt.to_period("M").dt.to_timestamp()

# ---- file 1: item level (revenue by category / region / month) -------------
it = (items.merge(products[["product_id", "product_category_name"]], on="product_id", how="left")
           .merge(cats, on="product_category_name", how="left"))
it["category"] = it.product_category_name_english.fillna("unknown")
it["gmv"] = it.price + it.freight_value
f_items = o[["order_id", "customer_unique_id", "order_purchase_timestamp", "order_month",
             "customer_type", "customer_state", "region"]].merge(
    it[["order_id", "category", "price", "freight_value", "gmv"]], on="order_id")
f_items.to_csv(OUT / "olist_items.csv", index=False)

# ---- file 2: order level (delivery / SLA, reviews, cohorts) ----------------
order_gmv = it.groupby("order_id", as_index=False).agg(order_gmv=("gmv", "sum"),
                                                       items=("order_item_id", "count"))
rev = reviews.groupby("order_id", as_index=False).review_score.mean()
f_orders = o.merge(order_gmv, on="order_id").merge(rev, on="order_id", how="left")

delivered = f_orders.order_delivered_customer_date
f_orders["delivery_days"] = (delivered - f_orders.order_purchase_timestamp).dt.total_seconds() / 86400
f_orders["days_vs_estimate"] = (delivered.dt.normalize() - f_orders.order_estimated_delivery_date).dt.days
f_orders["is_late"] = np.where(delivered.isna(), np.nan,
                               (delivered > f_orders.order_estimated_delivery_date).astype(float))
cohort = f_orders.groupby("customer_unique_id").order_month.transform("min")
f_orders["cohort_month"] = cohort
f_orders["months_since_first"] = ((f_orders.order_month.dt.year - cohort.dt.year) * 12
                                  + f_orders.order_month.dt.month - cohort.dt.month)
f_orders = f_orders.rename(columns={"order_purchase_timestamp": "purchased_at",
                                    "order_delivered_customer_date": "delivered_at",
                                    "order_estimated_delivery_date": "estimated_delivery_at"})
f_orders[["order_id", "customer_unique_id", "purchased_at", "order_month", "order_seq",
          "customer_type", "customer_state", "customer_city", "region", "items", "order_gmv",
          "delivered_at", "estimated_delivery_at", "delivery_days", "days_vs_estimate",
          "is_late", "review_score", "cohort_month", "months_since_first"]
         ].to_csv(OUT / "olist_orders.csv", index=False)

# ---- file 3: customer level RFM segments -----------------------------------
snapshot = f_orders.purchased_at.max().normalize() + pd.Timedelta(days=1)
c = f_orders.groupby("customer_unique_id").agg(
    last_at=("purchased_at", "max"), frequency=("order_id", "nunique"),
    monetary=("order_gmv", "sum"), region=("region", "first"),
    cohort_month=("cohort_month", "first")).reset_index()
c["recency_days"] = (snapshot - c.last_at.dt.normalize()).dt.days
n = len(c)
ntile = lambda s: (np.floor(s.rank(method="first") - 1) * 5 // n + 1).astype(int)
c["r_score"] = 6 - ntile(c.recency_days)
c["m_score"] = ntile(c.monetary)
c["segment"] = np.select(
    [(c.frequency >= 2) & (c.r_score >= 4), c.frequency >= 2,
     (c.r_score >= 4) & (c.m_score >= 4), c.r_score >= 4,
     (c.r_score >= 2) & (c.m_score >= 4), c.r_score >= 2],
    ["1 Champions", "2 Loyal, lapsing", "3 New high-value", "4 New low-value",
     "5 At-risk high-value", "6 Hibernating"], default="7 Lost")
c["is_repeat"] = (c.frequency >= 2).astype(int)
c.drop(columns="last_at").to_csv(OUT / "olist_customers.csv", index=False)

# ---- sanity checks vs docs/results.md --------------------------------------
print(f"GMV R${f_items.gmv.sum()/1e6:.2f}M (expect 15.42M) | orders {f_orders.order_id.nunique():,}")
print(f"customers {n:,} (expect 93,358) | repeat rate {c.is_repeat.mean():.2%} (expect 3.0%)")
print(c.segment.value_counts().sort_index().to_string())
for f in OUT.glob("*.csv"):
    print(f.name, f"{f.stat().st_size/1e6:.1f} MB")
