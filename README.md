# Olist E-commerce: Revenue & Retention Analysis

I wanted to practice the kind of analysis a revenue / CRM team actually does, so I took the Olist dataset (around 100k real orders from a Brazilian marketplace, 2016-2018) and tried to answer a few simple questions:

1. Can I trust the revenue numbers? (do item totals match what customers paid)
2. What made revenue jump or drop in a given month?
3. Do customers come back after their first order?
4. Who is worth spending money on to bring back, and how much?

All the SQL is in BigQuery and the dashboard is in Looker Studio.

**Dashboard:** [Looker Studio](https://lookerstudio.google.com/reporting/303762a4-ea28-491c-8b66-67e819dec816)
**Short memo with recommendations:** [docs/memo.md](docs/memo.md)
**All results in detail:** [docs/results.md](docs/results.md)
**How I defined each metric:** [docs/metric_dictionary.md](docs/metric_dictionary.md)

## What I found

- Revenue data is mostly clean. 99.6% of delivered orders match their payments exactly. The total gap is about R$2.8k, which is basically nothing (0.018%), and most of it comes from installment interest and vouchers.
- November 2017 revenue went up 54% (+R$402k) because of Black Friday. 24 Nov alone was way off the normal range (z-score 10.5). Almost all of that growth (97%) was new customers, not old ones coming back.
- Revenue grew ~8x through 2017 and then just stayed flat in 2018 at around R$1.0-1.1M a month.
- Retention is really bad. Only 3% of customers ever place a second order, and the ones who do take about 28 days (median).
- If the first delivery was late, the review drops to 2.6 stars (vs 4.3) and fewer people come back.
- Because almost nobody returns, ~97% of a customer's 12-month value is just their first order.
- So my recommendation: run a cashback campaign only for the ~13.9k "at-risk high value" customers, keep a holdout group to measure if it really works, and don't pay more than ~R$22 per customer who redeems.

## How the SQL is organised

Run the files in order:

- `01_data_quality.sql` - basic checks before trusting anything
- `02_reconciliation.sql` - item value vs payments, order by order
- `03_base_tables.sql` - one clean table that everything else uses
- `04_revenue_bridge.sql` - month on month change, what drove it, anomaly days
- `05_retention_rfm.sql` - repeat rate, cohorts, RFM segments, effect of late delivery
- `06_clv.sql` - customer value for 12 months and the campaign break-even
- `07_dashboard_tables.sql` - small tables that the Looker dashboard reads from

Things I used: joins, CTEs, GROUP BY, window functions (LAG, NTILE, DENSE_RANK, STDDEV OVER), QUALIFY, CASE WHEN.

## Things I learned / got stuck on

- `customer_id` in this dataset is different for every order, so at first it looked like nobody ever comes back. The real person ID is `customer_unique_id`. That one mistake would have made the whole retention part wrong.
- When you join items and payments directly, rows get duplicated and revenue comes out too high. I had to total each table per order first and then join.
- My Looker line chart was super spiky until I realised it was showing daily data. Changing it to Year Month fixed it.
- The cohort heatmap sorted months as 1, 12, 2, 3... because they were text. I made labels like M01, M02 so they sort properly.
- The category translation file didn't load properly with auto-detect, so I had to give BigQuery the schema myself.

## Limitations

- CLV uses a 20% margin, which I assumed. The real margin isn't in the data.
- I only counted delivered orders (97% of all orders) as revenue.
- The first and last few months are very thin so I left them out of trends.

## If you want to run it yourself

1. Download the data from Kaggle: [olistbr/brazilian-ecommerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
2. Upload the CSVs into a BigQuery dataset called `olist` (auto-detect schema works for all except the category translation file).
3. Change the project ID `olist-analytics-513008` in the SQL to yours and run 01 to 07.

Note: I'm on the free BigQuery sandbox, which deletes tables after 60 days. If the dashboard looks empty, that's why. I just re-run the SQL.
