# Metric Dictionary

All metrics use **delivered orders only** and are dated by `order_purchase_timestamp`.
Customers are identified by `customer_unique_id` (not `customer_id`, which is new on every order).
Analysis window for trends: **Jan 2017 – Aug 2018** (earlier and later months have too few orders).

| Metric | Definition | Source | Notes |
|---|---|---|---|
| **GMV** | SUM(price + freight_value) | order_items | Item-level value. Excludes installment interest, so it is not inflated by financing. |
| **Net product revenue** | SUM(price) | order_items | GMV minus freight. Olist's commission is not in the data, so this is the closest proxy for net revenue. |
| **Payment total** | SUM(payment_value) | payments | Cash collected. Differs from GMV by 0.018% (installment interest and vouchers); see `02_reconciliation.sql`. |
| **Orders** | COUNT(DISTINCT order_id) | orders | Delivered only. |
| **AOV** | GMV / Orders | | Average order value. |
| **New customer order** | The customer's first delivered order | orders + customers | Ranked by purchase time per `customer_unique_id`. |
| **Repeat customer order** | Any delivered order after the customer's first | | |
| **Repeat purchase rate** | Customers with 2+ delivered orders / customers with 1+ | | |
| **Cohort retention (month N)** | % of a first-purchase-month cohort that orders again N months later | | |
| **Region** | Brazilian macro-region of the customer's state | customers | SE, S, NE, N, CO. |

## Data-quality checks (see `sql/01_data_quality.sql`)
1. `customer_id` (99,441) vs `customer_unique_id` (96,096): use the unique ID for anything about people.
2. 3% of orders are not delivered (shipped, canceled, unavailable…); excluded from revenue.
3. 775 orders have no items (nearly all canceled/unavailable); 1 order has no payment.
4. Item total vs payment total: 99.6% of delivered orders match to the cent; net gap R$2.8k (0.018%).
