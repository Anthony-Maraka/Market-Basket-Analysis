-- =====================================================================
-- 05_pairs_sold_at_same_time.sql
-- =====================================================================

USE market_basket_analysis_project;

DROP TABLE IF EXISTS shortlist;
CREATE TABLE shortlist AS
SELECT m.*
FROM pair_metrics m
JOIN product_counts a ON a.StockCode = m.prod_a
JOIN product_counts b ON b.StockCode = m.prod_b
CROSS JOIN params p
WHERE m.pair_type = 'cross family'
  AND m.pair_orders >= p.min_pair_orders                                    -- meaningful (count)
  AND m.lift >= p.min_lift                                                  -- meaningful (strength)
  AND DATEDIFF(LEAST(a.last_sold, b.last_sold), GREATEST(a.first_sold, b.first_sold)) >= p.min_days_together
  AND LEAST(a.last_sold, b.last_sold) >=
      DATE_SUB((SELECT DATE(MAX(InvoiceDate)) FROM clean_lines), INTERVAL p.recent_days DAY);  -- still on sale
ALTER TABLE shortlist ADD PRIMARY KEY (prod_a, prod_b);

SELECT (SELECT COUNT(*) FROM pair_metrics m CROSS JOIN params p
         WHERE m.pair_type = 'cross family' AND m.pair_orders >= p.min_pair_orders AND m.lift >= p.min_lift) AS meaningful_cross_family,
       (SELECT COUNT(*) FROM shortlist) AS also_available_together;

-- INSIGHT (fill in after running):
-- 453 cross-family pairs are meaningful; 
-- 440 are also available together.
