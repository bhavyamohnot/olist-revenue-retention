CREATE OR REPLACE TABLE `olist-analytics-513008.olist.fact_items` AS
WITH delivered AS (
  SELECT
    o.order_id,
    c.customer_unique_id,
    c.customer_state,
    o.order_purchase_timestamp AS purchased_at,
    DENSE_RANK() OVER (PARTITION BY c.customer_unique_id
                       ORDER BY o.order_purchase_timestamp, o.order_id) AS order_seq
  FROM `olist-analytics-513008.olist.orders` o
  JOIN `olist-analytics-513008.olist.customers` c USING (customer_id)
  WHERE o.order_status = 'delivered'
)
SELECT
  d.order_id,
  d.customer_unique_id,
  d.purchased_at,
  DATE_TRUNC(DATE(d.purchased_at), MONTH) AS order_month,
  d.order_seq,
  IF(d.order_seq = 1, 'new', 'repeat') AS customer_type,
  d.customer_state,
  CASE
    WHEN d.customer_state IN ('SP','RJ','MG','ES') THEN 'Southeast'
    WHEN d.customer_state IN ('PR','SC','RS') THEN 'South'
    WHEN d.customer_state IN ('BA','PE','CE','MA','PB','RN','AL','SE','PI') THEN 'Northeast'
    WHEN d.customer_state IN ('AM','PA','RO','RR','AP','AC','TO') THEN 'North'
    ELSE 'Center-West'
  END AS region,
  COALESCE(t.product_category_name_english, 'unknown') AS category,
  i.price,
  i.freight_value,
  i.price + i.freight_value AS gmv
FROM delivered d
JOIN `olist-analytics-513008.olist.order_items` i USING (order_id)
LEFT JOIN `olist-analytics-513008.olist.products` p USING (product_id)
LEFT JOIN `olist-analytics-513008.olist.category_translation` t USING (product_category_name);

SELECT
  ROUND(SUM(gmv), 0)                  AS fact_gmv,
  COUNT(DISTINCT order_id)            AS orders,
  COUNT(DISTINCT customer_unique_id)  AS customers
FROM `olist-analytics-513008.olist.fact_items`;
