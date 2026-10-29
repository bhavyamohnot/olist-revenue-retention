CREATE OR REPLACE TABLE `olist-analytics-513008.olist.monthly_kpis` AS
WITH m AS (
  SELECT
    order_month,
    SUM(gmv)                                   AS gmv,
    COUNT(DISTINCT order_id)                   AS orders,
    COUNT(DISTINCT customer_unique_id)         AS customers,
    SUM(IF(customer_type = 'new', gmv, 0))     AS gmv_new,
    SUM(IF(customer_type = 'repeat', gmv, 0))  AS gmv_repeat
  FROM `olist-analytics-513008.olist.fact_items`
  WHERE order_month BETWEEN '2017-01-01' AND '2018-08-01'
  GROUP BY order_month
)
SELECT
  order_month,
  ROUND(gmv, 0)                                   AS gmv,
  orders,
  customers,
  ROUND(gmv / orders, 2)                          AS aov,
  ROUND(gmv_new, 0)                               AS gmv_new,
  ROUND(gmv_repeat, 0)                            AS gmv_repeat,
  ROUND(100 * gmv_repeat / gmv, 1)                AS pct_gmv_repeat,
  ROUND(gmv - LAG(gmv) OVER (ORDER BY order_month), 0)                    AS mom_change,
  ROUND(100 * (gmv / LAG(gmv) OVER (ORDER BY order_month) - 1), 1)        AS mom_pct,
  ROUND(gmv_new - LAG(gmv_new) OVER (ORDER BY order_month), 0)            AS mom_from_new,
  ROUND(gmv_repeat - LAG(gmv_repeat) OVER (ORDER BY order_month), 0)      AS mom_from_repeat
FROM m;

SELECT * FROM `olist-analytics-513008.olist.monthly_kpis` ORDER BY order_month;

WITH d AS (
  SELECT DATE(purchased_at) AS day, SUM(gmv) AS gmv, COUNT(DISTINCT order_id) AS orders
  FROM `olist-analytics-513008.olist.fact_items`
  WHERE order_month BETWEEN '2017-01-01' AND '2018-08-01'
  GROUP BY day
)
SELECT day, ROUND(gmv, 0) AS gmv, orders,
       ROUND((gmv - AVG(gmv) OVER ()) / STDDEV(gmv) OVER (), 1) AS z_score
FROM d
QUALIFY z_score > 3
ORDER BY z_score DESC;

CREATE OR REPLACE TABLE `olist-analytics-513008.olist.bridge_category` AS
SELECT
  category,
  ROUND(SUM(IF(order_month = '2017-10-01', gmv, 0)), 0) AS gmv_oct17,
  ROUND(SUM(IF(order_month = '2017-11-01', gmv, 0)), 0) AS gmv_nov17,
  ROUND(SUM(IF(order_month = '2017-11-01', gmv, 0)) - SUM(IF(order_month = '2017-10-01', gmv, 0)), 0) AS change
FROM `olist-analytics-513008.olist.fact_items`
WHERE order_month IN ('2017-10-01', '2017-11-01')
GROUP BY category;

SELECT * FROM `olist-analytics-513008.olist.bridge_category` ORDER BY change DESC LIMIT 8;

SELECT
  region,
  ROUND(SUM(IF(order_month = '2017-10-01', gmv, 0)), 0) AS gmv_oct17,
  ROUND(SUM(IF(order_month = '2017-11-01', gmv, 0)), 0) AS gmv_nov17,
  ROUND(100 * (SUM(IF(order_month = '2017-11-01', gmv, 0)) / SUM(IF(order_month = '2017-10-01', gmv, 0)) - 1), 1) AS growth_pct
FROM `olist-analytics-513008.olist.fact_items`
WHERE order_month IN ('2017-10-01', '2017-11-01')
GROUP BY region
ORDER BY gmv_nov17 DESC;
