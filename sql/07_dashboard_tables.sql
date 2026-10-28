-- 07_dashboard_tables.sql
-- Small, ready-to-chart tables for Looker Studio (prefix dash_).

-- Headline KPIs (one row).
CREATE OR REPLACE TABLE `olist-analytics-513008.olist.dash_kpis` AS
SELECT
  (SELECT ROUND(SUM(gmv), 0) FROM `olist-analytics-513008.olist.fact_items`)                       AS total_gmv,
  (SELECT COUNT(DISTINCT order_id) FROM `olist-analytics-513008.olist.fact_items`)                 AS delivered_orders,
  (SELECT COUNT(DISTINCT customer_unique_id) FROM `olist-analytics-513008.olist.fact_items`)       AS customers,
  (SELECT ROUND(SUM(gmv) / COUNT(DISTINCT order_id), 2) FROM `olist-analytics-513008.olist.fact_items`) AS aov,
  (SELECT ROUND(COUNTIF(frequency >= 2) / COUNT(*), 4) FROM `olist-analytics-513008.olist.rfm_customers`) AS repeat_rate,
  (SELECT ROUND(COUNTIF(recon_status = 'match') / COUNT(*), 4) FROM `olist-analytics-513008.olist.recon_orders`) AS recon_match_rate,
  (SELECT ROUND(SUM(gap), 0) FROM `olist-analytics-513008.olist.recon_orders`)                     AS recon_gap;

-- Monthly GMV split new vs repeat in long format (for stacked bars).
CREATE OR REPLACE TABLE `olist-analytics-513008.olist.dash_monthly_split` AS
SELECT order_month, 'New customers' AS customer_type, gmv_new AS gmv FROM `olist-analytics-513008.olist.monthly_kpis`
UNION ALL
SELECT order_month, 'Repeat customers', gmv_repeat FROM `olist-analytics-513008.olist.monthly_kpis`;

-- Monthly GMV by region (for the region trend and filter).
CREATE OR REPLACE TABLE `olist-analytics-513008.olist.dash_monthly_region` AS
SELECT order_month, region, ROUND(SUM(gmv), 0) AS gmv, COUNT(DISTINCT order_id) AS orders
FROM `olist-analytics-513008.olist.fact_items`
WHERE order_month BETWEEN '2017-01-01' AND '2018-08-01'
GROUP BY order_month, region;

-- Segments: RFM + CLV in one table, with a readable label.
CREATE OR REPLACE TABLE `olist-analytics-513008.olist.dash_segments` AS
SELECT
  SUBSTR(c.segment, 3) AS segment,
  c.customers,
  ROUND(c.customers / SUM(c.customers) OVER (), 4) AS share_of_customers,
  c.historical_gmv_per_customer AS avg_spend,
  c.clv_gmv_12m,
  c.clv_margin_12m_at_20pct,
  s.total_gmv
FROM `olist-analytics-513008.olist.clv_by_segment` c
JOIN (SELECT segment, ROUND(SUM(monetary), 0) AS total_gmv
      FROM `olist-analytics-513008.olist.rfm_customers` GROUP BY segment) s USING (segment);

-- Cohort heatmap, months 0-12 only, with a text label for the cohort.
CREATE OR REPLACE TABLE `olist-analytics-513008.olist.dash_cohorts` AS
SELECT FORMAT_DATE('%Y-%m', cohort_month) AS cohort, months_since,
       FORMAT('M%02d', months_since) AS month_label,  -- zero-padded so it sorts M01..M12
       cohort_size,
       retention_pct / 100 AS retention_rate
FROM `olist-analytics-513008.olist.cohort_retention`
WHERE months_since BETWEEN 1 AND 12;

SELECT table_id, row_count
FROM `olist-analytics-513008.olist.__TABLES__`
WHERE table_id LIKE 'dash_%' OR table_id IN ('monthly_kpis', 'bridge_category')
ORDER BY table_id;
