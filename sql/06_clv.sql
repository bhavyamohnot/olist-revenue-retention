CREATE OR REPLACE TABLE `olist-analytics-513008.olist.clv_rates` AS
WITH orders AS (
  SELECT customer_unique_id, order_id, order_seq,
         MIN(purchased_at) AS purchased_at, SUM(gmv) AS order_gmv
  FROM `olist-analytics-513008.olist.fact_items`
  GROUP BY customer_unique_id, order_id, order_seq
),
firsts AS (
  SELECT customer_unique_id, purchased_at AS first_at, order_gmv AS first_gmv,
         NTILE(5) OVER (ORDER BY order_gmv) AS first_value_quintile
  FROM orders WHERE order_seq = 1
),
followup AS (
  SELECT f.customer_unique_id,
         IF(f.first_value_quintile >= 4, 'high', 'low') AS value_band,
         COUNTIF(o.order_seq > 1)                 AS future_orders,
         SUM(IF(o.order_seq > 1, o.order_gmv, 0)) AS future_gmv
  FROM firsts f
  JOIN orders o USING (customer_unique_id)
  WHERE f.first_at <= '2017-08-31'
    AND o.purchased_at <= TIMESTAMP_ADD(f.first_at, INTERVAL 365 DAY)
  GROUP BY f.customer_unique_id, value_band
)
SELECT value_band,
       COUNT(*)                                          AS customers_observed,
       ROUND(100 * COUNTIF(future_orders > 0) / COUNT(*), 2) AS pct_repeat_12m,
       ROUND(AVG(future_gmv), 2)                         AS expected_future_gmv_12m
FROM followup
GROUP BY value_band;

SELECT * FROM `olist-analytics-513008.olist.clv_rates` ORDER BY value_band;

CREATE OR REPLACE TABLE `olist-analytics-513008.olist.clv_by_segment` AS
SELECT
  r.segment,
  COUNT(*)                                        AS customers,
  ROUND(AVG(r.monetary), 0)                       AS historical_gmv_per_customer,
  ROUND(AVG(c.expected_future_gmv_12m), 2)        AS expected_future_gmv_12m,
  ROUND(AVG(r.monetary) + AVG(c.expected_future_gmv_12m), 0) AS clv_gmv_12m,
  ROUND(0.20 * (AVG(r.monetary) + AVG(c.expected_future_gmv_12m)), 0) AS clv_margin_12m_at_20pct,
  ROUND(SUM(c.expected_future_gmv_12m), 0)        AS segment_future_gmv_12m
FROM `olist-analytics-513008.olist.rfm_customers` r
JOIN `olist-analytics-513008.olist.clv_rates` c
  ON c.value_band = IF(r.m_score >= 4, 'high', 'low')
GROUP BY r.segment;

SELECT * FROM `olist-analytics-513008.olist.clv_by_segment` ORDER BY segment;

SELECT
  ROUND(expected_future_gmv_12m, 2)        AS baseline_future_gmv,
  ROUND(0.20 * expected_future_gmv_12m, 2) AS incremental_margin_if_repeat_doubles,
  'max incentive cost per targeted customer (R$)' AS meaning
FROM `olist-analytics-513008.olist.clv_rates`
WHERE value_band = 'high';
