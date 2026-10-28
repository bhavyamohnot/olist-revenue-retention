# E-commerce Revenue & Retention Intelligence (Olist · BigQuery · Looker Studio)

Revenue reliability, growth drivers and retention analysis on ~100k real orders from Olist, a Brazilian e-commerce marketplace.

**📊 Dashboard:** [Looker Studio dashboard](https://lookerstudio.google.com/reporting/303762a4-ea28-491c-8b66-67e819dec816)  ·  **📝 Memo:** [docs/memo.md](docs/memo.md)  ·  **📖 Metric dictionary:** [docs/metric_dictionary.md](docs/metric_dictionary.md)  ·  **🔢 Full results:** [docs/results.md](docs/results.md)

## Key findings
| | |
|---|---|
| Revenue reconciliation | 99.6% of delivered orders reconcile item value to payments to the cent; net gap R$2.8k (0.018%), explained by installment interest and vouchers |
| Black Friday 2017 | Nov GMV +54% (+R$402k); 24 Nov was a 10.5σ outlier; 97% of the growth came from new customers |
| 2018 | GMV plateaued at R$1.0–1.13M/month after growing ~8× in 2017 |
| Retention | Repeat purchase rate **3.0%**; under 0.5% of a cohort returns in month 1 |
| Experience | Late first delivery: review 2.6★ vs 4.3★, repeat rate 17% lower |
| CLV | ~97% of 12-month customer value is the first order |
| Recommendation | Conversion-only cashback reactivation for 13.9k "At-risk high-value" customers, with a holdout group |

## Project structure
| Module | What it answers | SQL |
|---|---|---|
| 1a. Data quality | Can the raw data be trusted? Which ID is a real customer? | [01_data_quality.sql](sql/01_data_quality.sql) |
| 1b. Reconciliation | Does item-level revenue match payments? Why not? | [02_reconciliation.sql](sql/02_reconciliation.sql) |
| Base model | One clean item-level fact table with new/repeat flags and regions | [03_base_tables.sql](sql/03_base_tables.sql) |
| 2. Revenue bridge | What changed month over month, and why? Anomaly detection | [04_revenue_bridge.sql](sql/04_revenue_bridge.sql) |
| 3. Retention & RFM | Repeat rate, cohort retention, RFM segments, drivers of churn | [05_retention_rfm.sql](sql/05_retention_rfm.sql) |
| 4. CLV | 12-month value by segment and campaign break-even | [06_clv.sql](sql/06_clv.sql) |
| Dashboard tables | Small pre-aggregated tables for Looker Studio | [07_dashboard_tables.sql](sql/07_dashboard_tables.sql) |

## Methods
- **SQL (BigQuery Standard SQL):** CTEs, joins, aggregation before joining to avoid row fan-out, window functions (`LAG`, `DENSE_RANK`, `NTILE`, `STDDEV OVER`), `QUALIFY`, conditional aggregation.
- **Reconciliation:** per-order item totals vs payment totals with a ±R$0.01 tolerance, gap explained by installment band and voucher use.
- **Anomaly detection:** daily GMV z-scores (|z| > 3).
- **Cohort analysis:** first-purchase-month cohorts, retention by months since first order.
- **RFM:** Recency and Monetary quintiles; Frequency treated as 1 vs 2+ because 97% of customers order once.
- **CLV:** empirical 12-month forward value from customers with a full year of follow-up; 20% contribution margin is an explicit assumption.

## Data-quality notes
- `customer_id` is generated per order; customer metrics use `customer_unique_id` (99,441 IDs → 96,096 people).
- Revenue counts **delivered** orders only (97% of orders).
- Trend analysis uses Jan 2017 – Aug 2018; the edge months are too sparse.

## How to reproduce
1. Download the dataset from Kaggle: [olistbr/brazilian-ecommerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce).
2. Load the 8 CSVs (all except geolocation) into a BigQuery dataset named `olist` with schema auto-detect. Load `product_category_name_translation.csv` with an explicit schema (`product_category_name`, `product_category_name_english`), because auto-detect misses its header.
3. Replace `olist-analytics-513008` with your project ID and run the SQL files in order (01 → 07).

> The BigQuery sandbox deletes tables after 60 days. Re-run steps 2–3 (≈5 minutes), or enable billing and remove the dataset's table expiration, to keep the dashboard live.

## Tools
Google BigQuery · Looker Studio · SQL · Git/GitHub
