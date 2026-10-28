-- 01_data_quality.sql
-- Data-quality checks run before any metric is trusted.

-- Check 1: customer_id is per ORDER, customer_unique_id is the real PERSON.
-- Using customer_id for repeat-purchase metrics would show ~0% repeat.
SELECT
  COUNT(DISTINCT customer_id)        AS customer_ids,
  COUNT(DISTINCT customer_unique_id) AS real_customers
FROM `olist-analytics-513008.olist.customers`;

-- Check 2: order status mix (only delivered orders count as revenue).
SELECT order_status, COUNT(*) AS orders
FROM `olist-analytics-513008.olist.orders`
GROUP BY order_status
ORDER BY orders DESC;

-- Check 3: orders missing items or payments.
SELECT
  COUNTIF(i.order_id IS NULL) AS orders_without_items,
  COUNTIF(p.order_id IS NULL) AS orders_without_payments
FROM `olist-analytics-513008.olist.orders` o
LEFT JOIN (SELECT DISTINCT order_id FROM `olist-analytics-513008.olist.order_items`) i USING (order_id)
LEFT JOIN (SELECT DISTINCT order_id FROM `olist-analytics-513008.olist.payments`) p USING (order_id);

-- Check 4: date coverage.
SELECT
  MIN(order_purchase_timestamp) AS first_order,
  MAX(order_purchase_timestamp) AS last_order
FROM `olist-analytics-513008.olist.orders`;
