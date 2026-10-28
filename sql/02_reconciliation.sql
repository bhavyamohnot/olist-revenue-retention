-- 02_reconciliation.sql
-- Item-level revenue (price + freight) vs payment-level totals, delivered orders only.

CREATE OR REPLACE TABLE `olist-analytics-513008.olist.recon_orders` AS
WITH items AS (
  SELECT order_id,
         SUM(price)         AS item_price,
         SUM(freight_value) AS freight
  FROM `olist-analytics-513008.olist.order_items`
  GROUP BY order_id
),
pays AS (
  SELECT order_id,
         SUM(payment_value)                    AS paid,
         MAX(payment_installments)             AS installments,
         COUNTIF(payment_type = 'voucher') > 0 AS used_voucher,
         COUNT(*)                              AS payment_rows
  FROM `olist-analytics-513008.olist.payments`
  GROUP BY order_id
)
SELECT
  o.order_id,
  i.item_price + i.freight                  AS item_total,
  p.paid,
  ROUND(p.paid - (i.item_price + i.freight), 2) AS gap,
  p.installments,
  p.used_voucher,
  p.payment_rows,
  CASE
    WHEN ABS(p.paid - (i.item_price + i.freight)) <= 0.01 THEN 'match'
    WHEN p.paid > i.item_price + i.freight THEN 'paid_more'
    ELSE 'paid_less'
  END AS recon_status
FROM `olist-analytics-513008.olist.orders` o
JOIN items i USING (order_id)
JOIN pays  p USING (order_id)
WHERE o.order_status = 'delivered';

-- Summary: how many orders match, and how big is the gap?
SELECT
  recon_status,
  COUNT(*)                                   AS orders,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_orders,
  ROUND(SUM(gap), 2)                         AS total_gap,
  ROUND(AVG(installments), 1)                AS avg_installments,
  ROUND(100 * AVG(CAST(used_voucher AS INT64)), 1) AS pct_with_voucher
FROM `olist-analytics-513008.olist.recon_orders`
GROUP BY recon_status
ORDER BY orders DESC;

-- Overall totals.
SELECT
  ROUND(SUM(item_total), 0) AS item_revenue,
  ROUND(SUM(paid), 0)       AS payment_revenue,
  ROUND(SUM(gap), 0)        AS net_gap,
  ROUND(100 * SUM(gap) / SUM(item_total), 3) AS gap_pct
FROM `olist-analytics-513008.olist.recon_orders`;

-- Where does the "paid_more" gap come from? Split by installments.
SELECT
  CASE WHEN installments <= 1 THEN '1 (single)'
       WHEN installments <= 5 THEN '2-5'
       ELSE '6+' END AS installment_band,
  COUNT(*) AS orders,
  COUNTIF(recon_status = 'paid_more') AS paid_more_orders,
  ROUND(100 * COUNTIF(recon_status = 'paid_more') / COUNT(*), 1) AS pct_paid_more
FROM `olist-analytics-513008.olist.recon_orders`
GROUP BY installment_band
ORDER BY installment_band;
