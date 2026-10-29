SELECT
  COUNT(DISTINCT customer_id)        AS customer_ids,
  COUNT(DISTINCT customer_unique_id) AS real_customers
FROM `olist-analytics-513008.olist.customers`;

SELECT order_status, COUNT(*) AS orders
FROM `olist-analytics-513008.olist.orders`
GROUP BY order_status
ORDER BY orders DESC;

SELECT
  COUNTIF(i.order_id IS NULL) AS orders_without_items,
  COUNTIF(p.order_id IS NULL) AS orders_without_payments
FROM `olist-analytics-513008.olist.orders` o
LEFT JOIN (SELECT DISTINCT order_id FROM `olist-analytics-513008.olist.order_items`) i USING (order_id)
LEFT JOIN (SELECT DISTINCT order_id FROM `olist-analytics-513008.olist.payments`) p USING (order_id);

SELECT
  MIN(order_purchase_timestamp) AS first_order,
  MAX(order_purchase_timestamp) AS last_order
FROM `olist-analytics-513008.olist.orders`;
