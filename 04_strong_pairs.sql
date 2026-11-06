-- =====================================================================
-- 04_strong_pairs.sql      (support + confidence + lift live here)
-- =====================================================================

USE market_basket_analysis_project;

-- ---- 4.1 Meaningful words per product (used to judge "same family") ----
DROP TABLE IF EXISTS product_words;
-- Punctuation is stripped first (a trailing comma made "CARD," differ from "CARD", and
-- CHILDREN'S differed from CHILDRENS). KIDS / CHILDREN are mapped to CHILDRENS so spelling
-- variants of one product line match. Add more synonym pairs in the CASE below as you find them.
CREATE TABLE product_words AS
SELECT DISTINCT n.StockCode,
       CASE WHEN jt.word IN ('KIDS', 'CHILDREN') THEN 'CHILDRENS' ELSE jt.word END AS word
FROM (SELECT StockCode, name FROM product_names WHERE name IS NOT NULL) n
JOIN JSON_TABLE(
       CONCAT('["', REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(TRIM(n.name)), '\\\\', ' '), '"', ' '), CHAR(9), ' '), CHAR(10), ' '), ',', ' '), '.', ' '), '(', ' '), ')', ' '), '&', ' '), CHAR(39), ''), ' ', '","'), '"]'),
       '$[*]' COLUMNS (word VARCHAR(100) PATH '$')
     ) jt
WHERE jt.word <> ''
  AND jt.word NOT REGEXP '^(SET/)?[0-9/]+$'               -- pure numbers / pack sizes such as SET/20
  AND jt.word NOT IN (SELECT word FROM stop_words);
ALTER TABLE product_words ADD PRIMARY KEY (StockCode, word);

-- ---- 4.2 The metrics table ----
--   support    = P(A and B)               = pair_orders / all baskets
--   conf_a_to_b= P(B | A)                 = pair_orders / baskets with A
--   lift       = P(A and B) / (P(A)P(B))  = pair_orders * n / (orders_A * orders_B)
DROP TABLE IF EXISTS pair_metrics;
CREATE TABLE pair_metrics AS
SELECT p.prod_a, p.prod_b, na.name AS name_a, nb.name AS name_b, p.pair_orders,
       CAST(p.pair_orders AS DOUBLE) / t.n                                   AS support,
       CAST(p.pair_orders AS DOUBLE) / ca.orders                             AS conf_a_to_b,
       CAST(p.pair_orders AS DOUBLE) / cb.orders                             AS conf_b_to_a,
       (CAST(p.pair_orders AS DOUBLE) * t.n) / (ca.orders * cb.orders)       AS lift,
       (SELECT COUNT(*) FROM product_words x
          JOIN product_words y ON y.word = x.word
         WHERE x.StockCode = p.prod_a AND y.StockCode = p.prod_b)            AS shared_words
FROM pairs p
JOIN product_counts ca ON ca.StockCode = p.prod_a
JOIN product_counts cb ON cb.StockCode = p.prod_b
JOIN product_names na ON na.StockCode = p.prod_a
JOIN product_names nb ON nb.StockCode = p.prod_b
CROSS JOIN (SELECT COUNT(*) AS n FROM order_totals) t;

ALTER TABLE pair_metrics ADD PRIMARY KEY (prod_a, prod_b), ADD COLUMN pair_type VARCHAR(12);
UPDATE pair_metrics
SET pair_type = IF(shared_words >= (SELECT same_family_min_shared FROM params), 'same family', 'cross family');

-- ---- 4.3 Strongest pairs by lift (only pairs with enough support to trust) ----
SELECT name_a, name_b, pair_orders,
       ROUND(100 * support, 2) AS support_pct,
       ROUND(conf_a_to_b, 2)   AS conf_a_to_b,
       ROUND(conf_b_to_a, 2)   AS conf_b_to_a,
       ROUND(lift, 1)          AS lift
FROM pair_metrics
WHERE support >= (SELECT min_support FROM params)
ORDER BY lift DESC, pair_orders DESC LIMIT 10;

-- Same 10 pairs, grouped by product set
SELECT SUBSTRING_INDEX(name_a, ' ', 2) AS product_set,
       COUNT(*)                        AS pairs_in_top10,
       ROUND(MIN(lift), 1)             AS min_lift,
       ROUND(MAX(lift), 1)             AS max_lift,
       ROUND(100 * MIN(LEAST(conf_a_to_b, conf_b_to_a))) AS min_conf_pct,
       ROUND(100 * MAX(GREATEST(conf_a_to_b, conf_b_to_a))) AS max_conf_pct
FROM (SELECT * FROM pair_metrics
      WHERE support >= (SELECT min_support FROM params)
      ORDER BY lift DESC, pair_orders DESC LIMIT 10) t
GROUP BY product_set;

-- ---- 4.4 Lift among the pairs we KEPT (biased on purpose: see 4.5) ----
SELECT COUNT(*)                                   AS pairs_kept,
       SUM(lift > 1)                              AS lift_above_1,
       SUM(lift >= 5)                             AS lift_5plus,
       ROUND(100 * SUM(lift > 1) / COUNT(*), 1)   AS pct_lift_above_1
FROM pair_metrics;

-- ---- 4.5 UNBIASED check: every pair among POPULAR products, no co-occurrence floor ----
-- Pairs that NEVER occur together have lift 0 and never appear in `pairs`. If we only look
-- at pairs that passed the floor, almost all of them have lift > 1 by construction.
-- The honest figure divides by ALL possible pairs of popular products.
DROP TABLE IF EXISTS pairs_popular;
CREATE TABLE pairs_popular AS
SELECT a.StockCode AS prod_a, b.StockCode AS prod_b, COUNT(*) AS pair_orders
FROM clean_lines a
JOIN product_counts pa ON pa.StockCode = a.StockCode AND pa.orders >= (SELECT min_product_orders FROM params)
JOIN clean_lines b     ON b.InvoiceNo = a.InvoiceNo AND a.StockCode < b.StockCode
JOIN product_counts pb ON pb.StockCode = b.StockCode AND pb.orders >= (SELECT min_product_orders FROM params)
GROUP BY a.StockCode, b.StockCode;
ALTER TABLE pairs_popular ADD PRIMARY KEY (prod_a, prod_b);

WITH k AS (SELECT COUNT(*) AS n_pop FROM product_counts
           WHERE orders >= (SELECT min_product_orders FROM params)),
     m AS (SELECT (CAST(pp.pair_orders AS DOUBLE) * t.n) / (ca.orders * cb.orders) AS lift
           FROM pairs_popular pp
           JOIN product_counts ca ON ca.StockCode = pp.prod_a
           JOIN product_counts cb ON cb.StockCode = pp.prod_b
           CROSS JOIN (SELECT COUNT(*) AS n FROM order_totals) t)
SELECT (SELECT n_pop FROM k)                                   AS popular_products,
       (SELECT n_pop * (n_pop - 1) / 2 FROM k)                 AS possible_pairs,
       COUNT(*)                                                AS pairs_that_ever_co_occur,
       SUM(lift > 1)                                           AS lift_above_1,
       SUM(lift < 1)                                           AS lift_below_1,
       ROUND(100 * SUM(lift > 1) / (SELECT n_pop * (n_pop - 1) / 2 FROM k), 1) AS pct_of_ALL_possible_pairs_lift_above_1
FROM m;

-- INSIGHT: Each of the top 10 pairs belongs to a different product set (no set appears twice), so the
--          strongest associations are spread across the range: tea plates, children's play items,
--          paper tableware, felt cushions, Christmas wooden decorations, bunting, signs, cutlery and
--          baking cases. Lift runs 29.9-53.3, and confidence is 48-88%, with 9 of 10 pairs at 54% or
--          higher even in their weaker direction. In every one of these pairs, at least half of the
--          buyers of one item also buy the other.
-- INSIGHT: Confidence is lopsided in several pairs. WOODEN STAR is 54% in one direction and 86% in the
--          other (a 32-point gap), CHILDRENS CUTLERY 54-77%, and REGENCY TEA 64-88%. The less popular item is
--          mostly bought as an add-on to the more popular one, but not the reverse, so the
--          promotion should point from the best seller to its companion.
-- WATCH: The grouping query adds nothing new here: because every pair has a different two-word start,
--          the table shows one pair per row, so min_lift and max_lift are the same number. Use it only
--          if you want the confidence ranges (these are the 48-88% above).
-- INSIGHT: Among the 144 popular products (in 100+ baskets each) there are 10,296 possible pairs, and
--          10,044 of them (97.6%) occur together at least once. Only 6,328 pairs (61.5% of all possible)
--          have lift above 1, while 3,715 (36.1%) have lift below 1, meaning customers buy those
--          products together LESS often than chance. 252 pairs never occur together, and one pair has lift
--          of exactly 1. So the earlier "99.1% of kept pairs have lift above 1" came from the 20-basket
--          floor, and across all pairs of popular products, about 4 in 10 have no positive
--          association. A high lift is therefore a real signal, not the default.