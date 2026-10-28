-- 05_retention_rfm.sql
-- Repeat purchase rate, cohort retention, RFM segments, and why customers don't return.

-- A) Repeat purchase rate + days to second order.
WITH per_customer AS (
  SELECT customer_unique_id,
         COUNT(DISTINCT order_id) AS orders,
         MIN(purchased_at)        AS first_at
  FROM `olist-analytics-513008.olist.fact_items`
  GROUP BY customer_unique_id
),
second_order AS (
  SELECT customer_unique_id, MIN(purchased_at) AS second_at
  FROM `olist-analytics-513008.olist.fact_items`
  WHERE order_seq = 2
  GROUP BY customer_unique_id
)
SELECT
  COUNT(*)                                        AS customers,
  COUNTIF(orders >= 2)                            AS repeat_customers,
  ROUND(100 * COUNTIF(orders >= 2) / COUNT(*), 2) AS repeat_rate_pct,
  APPROX_QUANTILES(DATE_DIFF(DATE(s.second_at), DATE(p.first_at), DAY), 2)[OFFSET(1)] AS median_days_to_2nd_order
FROM per_customer p
LEFT JOIN second_order s USING (customer_unique_id);

-- B) Monthly cohort retention: % of each first-purchase cohort ordering again N months later.
CREATE OR REPLACE TABLE `olist-analytics-513008.olist.cohort_retention` AS
WITH firsts AS (
  SELECT customer_unique_id, MIN(order_month) AS cohort_month
  FROM `olist-analytics-513008.olist.fact_items`
  GROUP BY customer_unique_id
),
activity AS (
  SELECT DISTINCT f.customer_unique_id, f.cohort_month,
         DATE_DIFF(x.order_month, f.cohort_month, MONTH) AS months_since
  FROM firsts f
  JOIN `olist-analytics-513008.olist.fact_items` x USING (customer_unique_id)
),
sizes AS (
  SELECT cohort_month, COUNT(*) AS cohort_size FROM firsts GROUP BY cohort_month
)
SELECT a.cohort_month, a.months_since, s.cohort_size,
       COUNT(*) AS active_customers,
       ROUND(100 * COUNT(*) / s.cohort_size, 2) AS retention_pct
FROM activity a
JOIN sizes s USING (cohort_month)
WHERE a.cohort_month BETWEEN '2017-01-01' AND '2018-08-01'
GROUP BY a.cohort_month, a.months_since, s.cohort_size;

-- Average retention curve across cohorts (months 1-6).
SELECT months_since, ROUND(AVG(retention_pct), 2) AS avg_retention_pct
FROM `olist-analytics-513008.olist.cohort_retention`
WHERE months_since BETWEEN 1 AND 6
GROUP BY months_since
ORDER BY months_since;

-- C) RFM segmentation. Snapshot date = day after the last order in the data.
CREATE OR REPLACE TABLE `olist-analytics-513008.olist.rfm_customers` AS
WITH base AS (
  SELECT customer_unique_id,
         DATE_DIFF((SELECT DATE(MAX(purchased_at)) + 1 FROM `olist-analytics-513008.olist.fact_items`),
                   DATE(MAX(purchased_at)), DAY) AS recency_days,
         COUNT(DISTINCT order_id)                AS frequency,
         SUM(gmv)                                AS monetary,
         ANY_VALUE(region)                       AS region
  FROM `olist-analytics-513008.olist.fact_items`
  GROUP BY customer_unique_id
),
scored AS (
  SELECT *,
         6 - NTILE(5) OVER (ORDER BY recency_days) AS r_score,  -- 5 = most recent
         NTILE(5) OVER (ORDER BY monetary)         AS m_score   -- 5 = highest spend
  FROM base
)
SELECT *,
  CASE
    WHEN frequency >= 2 AND r_score >= 4 THEN '1 Champions (repeat, recent)'
    WHEN frequency >= 2                  THEN '2 Loyal, lapsing (repeat, older)'
    WHEN r_score >= 4 AND m_score >= 4   THEN '3 New high-value (1 order, recent)'
    WHEN r_score >= 4                    THEN '4 New low-value (1 order, recent)'
    WHEN r_score >= 2 AND m_score >= 4   THEN '5 At-risk high-value (1 order, 4-12 mo)'
    WHEN r_score >= 2                    THEN '6 Hibernating (1 order, 4-12 mo)'
    ELSE                                      '7 Lost (1 order, oldest)'
  END AS segment
FROM scored;

SELECT segment,
       COUNT(*)                                        AS customers,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_customers,
       ROUND(AVG(recency_days), 0)                     AS avg_recency_days,
       ROUND(AVG(monetary), 0)                         AS avg_spend,
       ROUND(SUM(monetary), 0)                         AS total_gmv,
       MIN(recency_days) AS min_rec, MAX(recency_days) AS max_rec
FROM `olist-analytics-513008.olist.rfm_customers`
GROUP BY segment
ORDER BY segment;

-- D) Why don't customers return? First-order experience vs repeat rate.
CREATE OR REPLACE TABLE `olist-analytics-513008.olist.first_order_experience` AS
WITH first_orders AS (
  SELECT DISTINCT customer_unique_id, order_id
  FROM `olist-analytics-513008.olist.fact_items`
  WHERE order_seq = 1
),
rev AS (
  SELECT order_id, AVG(review_score) AS review_score
  FROM `olist-analytics-513008.olist.reviews`
  GROUP BY order_id
)
SELECT
  f.customer_unique_id,
  r.review_score,
  o.order_delivered_customer_date > o.order_estimated_delivery_date AS delivered_late,
  c.frequency >= 2 AS came_back
FROM first_orders f
JOIN `olist-analytics-513008.olist.orders` o USING (order_id)
LEFT JOIN rev r USING (order_id)
JOIN `olist-analytics-513008.olist.rfm_customers` c USING (customer_unique_id);

SELECT
  IF(delivered_late, 'late', 'on time') AS first_delivery,
  COUNT(*) AS customers,
  ROUND(AVG(review_score), 2) AS avg_review,
  ROUND(100 * COUNTIF(came_back) / COUNT(*), 2) AS repeat_rate_pct
FROM `olist-analytics-513008.olist.first_order_experience`
WHERE delivered_late IS NOT NULL
GROUP BY first_delivery;

SELECT
  CAST(ROUND(review_score) AS INT64) AS first_review_stars,
  COUNT(*) AS customers,
  ROUND(100 * COUNTIF(came_back) / COUNT(*), 2) AS repeat_rate_pct
FROM `olist-analytics-513008.olist.first_order_experience`
WHERE review_score IS NOT NULL
GROUP BY first_review_stars
ORDER BY first_review_stars;
