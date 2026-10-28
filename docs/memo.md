# Memo: Olist Revenue & Retention, Jan 2017 – Aug 2018

**To:** Founder's Office · **From:** Bhavya Mohnot · **Data:** 96,478 delivered orders, 93,358 customers (Olist public dataset)

## 1. What changed
- **GMV grew ~8× in 2017** (R$127k in Jan → R$1.15M in Nov) and then **plateaued at R$1.0–1.13M/month through Aug 2018**.
- **Black Friday 2017 was the single biggest event**: November GMV +54% (+R$402k) month over month; 24 Nov alone did R$175k, a 10.5σ outlier versus a normal day.
- The spike was broad-based across categories (bed/bath/table +R$50k, health/beauty +R$41k, furniture/decor +R$39k) but **regionally uneven**: Southeast +62% vs Northeast only +18%.

## 2. Why it matters
- **Growth is almost entirely acquisition.** 97% of November's growth came from first-time buyers, and repeat customers contribute only 1–3.6% of GMV in any month.
- **Retention is close to zero.** Only **3.0%** of customers ever place a second order; under **0.5%** of a cohort returns in month 1.
- **First-order experience matters, but isn't the whole story.** A late first delivery (8% of customers) drops reviews from 4.3★ to 2.6★ and cuts repeat rate by 17%, yet even 5★ customers return only 3.1% of the time. The missing piece is a **re-engagement mechanism**, not just service quality.
- **CLV ≈ first order.** About 97% of a customer's 12-month value is their first purchase (≈R$300 vs ≈R$9 afterwards). With acquisition flattening in 2018, revenue will stay flat unless repeat behaviour improves.
- **Revenue numbers are trustworthy.** Item-level GMV reconciles to payments for 99.6% of orders; the R$2.8k net gap (0.018%) is explained by installment interest and vouchers.

## 3. What to do / investigate next
1. **Reactivation pilot for "At-risk high-value" customers** (13.9k people, one order 6–12 months ago, avg spend R$294). Use **conversion-only cashback** on the second order rather than blanket discounts: a blanket offer can't pay for itself (≈R$1.86 incremental margin per targeted customer even if repeat doubles), while cashback paid only on purchase breaks even up to ≈R$22 per redeemer. Run it with a **10–20% holdout** to measure true lift.
2. **Second-order nudge for new high-value customers** inside the first 4 weeks (median time to a 2nd order is 28 days).
3. **Service recovery for late deliveries**: apology + credit for customers whose first order arrived late.
4. **Investigate the Northeast**: check delivery times and freight share of order value there versus the Southeast.
5. **Get the missing data**: commission/margin by category (the CLV uses an assumed 20% margin) and marketing-touch data, to replace assumptions with measured campaign ROI.

*Dashboard: [link] · SQL & method: github.com/[username]/olist-revenue-retention*
