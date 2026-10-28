# Results Log

Every module: the question, the method, the SQL file, and the result.

---

## Module 1a: Data-quality checks
**SQL:** `sql/01_data_quality.sql`

| Check | Method | Result |
|---|---|---|
| Customer identity | COUNT(DISTINCT) of `customer_id` vs `customer_unique_id` | 99,441 IDs but only 96,096 real people: `customer_id` is new on every order, so retention must use `customer_unique_id` |
| Order status | GROUP BY `order_status` | 96,478 delivered (97%); shipped/canceled/unavailable/etc. excluded from revenue |
| Missing records | LEFT JOIN + COUNTIF(IS NULL) | 775 orders with no items (canceled/unavailable), 1 order with no payment |
| Date range | MIN/MAX of purchase timestamp | Sep 2016 – Oct 2018; trend analysis uses Jan 2017 – Aug 2018 (edge months are sparse) |

## Module 1b: Revenue reconciliation (items vs payments)
**SQL:** `sql/02_reconciliation.sql`
**Method:** total item value (price + freight) and payment value separately per order (to avoid row multiplication), join on `order_id`, label each order match / paid_more / paid_less (±R$0.01 tolerance).

| Metric | Value |
|---|---|
| Delivered orders matching to the cent | **96,094 (99.6%)** |
| Item revenue (GMV) | R$15.42M |
| Payment revenue | R$15.42M |
| Net gap | **R$2,831 (0.018%)** |
| Paid more than item value | 290 orders, +R$3,032; rate rises with installments (0.1% single payment → 0.9% at 6+ installments), consistent with installment interest |
| Paid less than item value | 93 orders, −R$200; consistent with vouchers/discounts |

**Decision:** define GMV on item value (price + freight) so it is not inflated by financing charges. See `docs/metric_dictionary.md`.

## Module 2: Monthly revenue bridge
**SQL:** `sql/03_base_tables.sql` (builds `fact_items`), `sql/04_revenue_bridge.sql`
**Method:** item-level fact table with each customer's order sequence (DENSE_RANK) to tag new vs repeat; monthly GMV with LAG() for month-over-month change split by new/repeat; daily z-scores to flag anomalies; Oct→Nov 2017 bridge by category and region.

| Finding | Number |
|---|---|
| Black Friday spike | Nov 2017 GMV +53.6% (+R$402k) vs Oct |
| Biggest anomaly | 24 Nov 2017: R$175k GMV, 1,147 orders, **z = 10.5** |
| Growth source | 97% of Nov growth (R$391k) from **new** customers |
| Repeat share of GMV | only **1–3.6%** in every month |
| 2018 trend | GMV plateaued at R$1.0–1.13M/month (Jan–Aug 2018) after rising from R$127k in Jan 2017 |
| Top category movers (Oct→Nov 2017) | bed_bath_table +R$50k, health_beauty +R$41k, furniture_decor +R$39k |
| Regional gap | Southeast +62% vs Northeast only +18% on Black Friday month: investigate delivery time/freight |
| AOV | stable at R$146–170 |

## Module 3: Retention, cohorts, RFM, reactivation target
**SQL:** `sql/05_retention_rfm.sql` (builds `cohort_retention`, `rfm_customers`, `first_order_experience`)
**Method:** repeat rate on `customer_unique_id`; monthly first-purchase cohorts with DATE_DIFF month offsets; RFM with NTILE(5) quintiles for Recency and Monetary (Frequency is binary, 1 vs 2+, because 97% of customers buy once); first-order experience (late delivery, review score) vs repeat rate.

| Finding | Number |
|---|---|
| Repeat purchase rate | **3.0%** (2,801 of 93,358 customers) |
| Median time to 2nd order | 28 days |
| Avg cohort retention | 0.48% in month 1, ~0.25% in months 2–6 |
| Late first delivery | 8% of customers; avg review 2.56 vs 4.29 on time; repeat rate 2.52% vs 3.04% (17% lower) |
| Review stars vs repeat | 1★ 2.75% → 5★ 3.12%: weak effect; even happy customers rarely return |

**RFM segments**

| Segment | Customers | % | Avg spend | Total GMV |
|---|---|---|---|---|
| Champions (repeat, recent) | 1,201 | 1.3% | R$323 | R$0.39M |
| Loyal, lapsing (repeat, older) | 1,600 | 1.7% | R$298 | R$0.48M |
| New high-value (1 order, recent) | 14,416 | 15.4% | R$302 | R$4.35M |
| New low-value (1 order, recent) | 21,727 | 23.3% | R$73 | R$1.58M |
| **At-risk high-value (1 order, 6–12 mo)** | **13,886** | **14.9%** | **R$294** | **R$4.09M** |
| Hibernating (1 order, 6–12 mo) | 22,293 | 23.9% | R$72 | R$1.62M |
| Lost (1 order, 12+ mo) | 18,235 | 19.5% | R$160 | R$2.92M |

**Recommendation:** reactivation campaign targets **At-risk high-value**: 13.9k customers who spent ~4× the low-value groups and are still within 12 months. **New high-value** customers get a second-order nudge inside the first ~4 weeks (median repeat gap is 28 days). Customers with a late first delivery get a service-recovery message rather than a plain discount.

## Module 4: CLV by segment
**SQL:** `sql/06_clv.sql` (builds `clv_rates`, `clv_by_segment`)
**Method:** empirical 12-month forward value. Take customers whose first order was on/before 31 Aug 2017 (so 12 months of follow-up exist), split them by first-order value (top 40% = high), and measure what they actually spent in the next 365 days. Apply those rates to each RFM segment. CLV (12m) = historical GMV + expected future GMV. Margin is not in the data, so a 20% contribution margin is an explicit assumption.

| Value band | Customers observed | Repeat within 12m | Expected future GMV (12m) |
|---|---|---|---|
| High first order | 8,280 | 4.13% | R$9.29 |
| Low first order | 13,245 | 4.79% | R$6.43 |

| Segment | CLV 12m (GMV) | CLV 12m (margin @20%) |
|---|---|---|
| Champions | R$332 | R$66 |
| New high-value | R$311 | R$62 |
| At-risk high-value | R$304 | R$61 |
| Lost | R$167 | R$33 |
| New / hibernating low-value | R$79 | R$16 |

**Key insight:** ~97% of a customer's 12-month value is their **first order** (≈R$300 vs ≈R$9 expected after it). CLV here is an acquisition story, not a loyalty story.

**Campaign economics (At-risk high-value):** if a campaign doubled the 12-month repeat rate, it would add R$9.29 GMV ≈ **R$1.86 margin per targeted customer**. A blanket discount sent to everyone cannot pay for itself. The incentive must be **paid only on conversion** (cashback on the 2nd order, like CLiQ Cash): at a ~8% post-campaign conversion rate the break-even is ≈**R$22 cashback per redeemer**, about 7% of a typical order.

**Limitation:** the rates come from first-order value bands, so they understate Champions (customers who already repeated are more likely to repeat again). With ~2.8k repeaters, a separate model would be noisy.
