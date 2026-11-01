# Olist E-commerce: Revenue & Retention Analysis

I wanted to practice the kind of analysis a revenue / CRM team actually does, so I took the Olist dataset (around 100k real orders from a Brazilian marketplace, 2016-2018) and tried to answer a few simple questions:

1. Can I trust the revenue numbers? (do item totals match what customers paid)
2. What made revenue jump or drop in a given month?
3. Do customers come back after their first order?
4. Who is worth spending money on to bring back, and how much?
5. Are orders delivered on time, and what happens when they aren't?

All the SQL is in BigQuery. I built the dashboard twice: first in Looker Studio, then again in Tableau Public, where I also added a delivery & SLA page.

- Dashboard (Tableau Public, 2 pages): [Revenue & Retention](https://public.tableau.com/views/OlistRevenueRetention/RevenueRetention) | [Delivery & SLA](https://public.tableau.com/views/OlistRevenueRetention/DeliverySLA)
- Dashboard (Looker Studio): [link](https://lookerstudio.google.com/reporting/303762a4-ea28-491c-8b66-67e819dec816)
- Short memo with recommendations: [docs/memo.md](docs/memo.md)
- All results in detail: [docs/results.md](docs/results.md)
- How I defined each metric: [docs/metric_dictionary.md](docs/metric_dictionary.md)

## What I found

- Revenue data is mostly clean. 99.6% of delivered orders match their payments exactly. The total gap is about R$2.8k, which is basically nothing (0.018%), and most of it comes from installment interest and vouchers.
- November 2017 revenue went up 54% (+R$402k) because of Black Friday. 24 Nov alone was way off the normal range (z-score 10.5). Almost all of that growth (97%) was new customers, not old ones coming back.
- Revenue grew ~8x through 2017 and then just stayed flat in 2018 at around R$1.0-1.1M a month.
- Retention is really bad. Only 3% of customers ever place a second order, and the ones who do take about 28 days (median).
- If the first delivery was late, the review drops to 2.6 stars (vs 4.3) and fewer people come back.
- Because almost nobody returns, ~97% of a customer's 12-month value is just their first order.
- So my recommendation: run a cashback campaign only for the ~13.9k "at-risk high value" customers, keep a holdout group to measure if it really works, and don't pay more than ~R$22 per customer who redeems.

## Delivery & SLA (added in the Tableau version)

- 8.1% of delivered orders arrived after the promised date. Median delivery time was 10.2 days.
- Late rate by state goes from 2.9% (RO) up to 23.9% (AL). The five worst states (AL, MA, PI, CE, SE) are all in the Northeast and above 15%.
- But those five states are only 3.3% of orders. By volume, SP and RJ together account for 52% of all late orders, and RJ is late 13.5% of the time on 12k orders. So if I could fix one place first, it would be RJ, not the Northeast. The worst rate is not the same as the biggest problem.
- Lateness kills reviews: 4.3 stars on time, 3.3 at 1-3 days late, 2.1 at 4-7 days, 1.7 at 8+ days late. Even 1-3 days late costs a full star.
- Customers whose first order was late come back less (2.52% repeat vs 3.04%).

## Tableau version

- `tableau/prep_tableau.py` builds 3 flat CSVs from the raw Kaggle files with pandas, using the same rules as the SQL (delivered orders only, `customer_unique_id`). Before building anything I checked the totals against BigQuery: GMV R$15.42M, 93,358 customers, 3.0% repeat rate all match.
- In Tableau the three tables are linked with relationships (customers -> orders on `customer_unique_id`, orders -> items on `order_id`) instead of being joined into one big table, so revenue isn't double counted.
- Calculated fields: late rate as `AVG([Is Late])`, a lateness bucket with `IF / ELSEIF`, and cohort size with a FIXED LOD (`{FIXED [Cohort Month] : COUNTD([Customer Unique Id])}`) so filtering to months 1-12 doesn't change the denominator.

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
- In Tableau the lateness chart first showed a "Null" bar averaging 4.5 stars. It was 8 orders with no delivery date. Without an `ISNULL` check they would have been counted as "8+ days late".
- One cell in the cohort heatmap (Jan 2017 cohort, month 9) is blank. I checked the raw data: nobody from that cohort ordered that month, and Tableau doesn't draw a square when there are no rows. The cohorts are small (Jan 2017 is 717 customers), so 0.3% can be just 2 people.

## Limitations

- CLV uses a 20% margin, which I assumed. The real margin isn't in the data.
- I only counted delivered orders (97% of all orders) as revenue.
- The first and last few months are very thin so I left them out of trends.

## If you want to run it yourself

1. Download the data from Kaggle: [olistbr/brazilian-ecommerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
2. Upload the CSVs into a BigQuery dataset called `olist` (auto-detect schema works for all except the category translation file).
3. Change the project ID `olist-analytics-513008` in the SQL to yours and run 01 to 07.

For the Tableau files, run `python tableau/prep_tableau.py` from the repo root (needs pandas). It writes the CSVs to `tableau/data/`.

Note: I'm on the free BigQuery sandbox, which deletes tables after 60 days. If the dashboard looks empty, that's why. I just re-run the SQL.
