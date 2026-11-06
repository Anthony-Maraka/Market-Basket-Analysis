-- =====================================================================
-- 03_pairs_most_often_bought_together.sql
-- =====================================================================

USE market_basket_analysis_project;

DROP TABLE IF EXISTS pairs;
CREATE TABLE pairs AS
SELECT a.StockCode AS prod_a, b.StockCode AS prod_b, COUNT(*) AS pair_orders
FROM clean_lines a
JOIN clean_lines b ON a.InvoiceNo = b.InvoiceNo AND a.StockCode < b.StockCode   -- "<" avoids mirrored duplicates
GROUP BY a.StockCode, b.StockCode
HAVING COUNT(*) >= (SELECT min_pair_orders FROM params);                       -- ignore rare pairs
ALTER TABLE pairs ADD PRIMARY KEY (prod_a, prod_b);

-- Pair SUPPORT = baskets containing BOTH products / all baskets
SELECT na.name AS product_a, nb.name AS product_b, p.pair_orders,
       ROUND(100 * p.pair_orders / (SELECT COUNT(*) FROM order_totals), 2) AS support_pct
FROM pairs p
JOIN product_names na ON na.StockCode = p.prod_a
JOIN product_names nb ON nb.StockCode = p.prod_b
ORDER BY p.pair_orders DESC, na.name, nb.name LIMIT 10;

SELECT COUNT(*) AS pairs_kept,
       MIN(pair_orders) AS smallest_pair_orders,   -- must equal the floor or higher
       MAX(pair_orders) AS largest_pair_orders     -- NO pair anywhere in the project can exceed this
FROM pairs;

-- INSIGHT 1: The 10 most frequent pairs appear in 108-153 baskets (support 2.2-3.2%), so even the top pair
--          (JUMBO BAG PINK POLKADOT + JUMBO BAG RED RETROSPOT, 3.16%) is in only about 1 basket in 30.
--          All 10 are design variants of one product (6 jumbo/lunch bags, 2 Regency teacup sets, alarm clocks,
--          paper chain kits), so the commonest co-purchase is customers choosing several designs of the same item.
-- INSIGHT 2: 1,444 pairs were kept. Each appears in 20 to 153 baskets, so the 20-basket floor is working
--          (smallest = 20) and the top pair (153 baskets, 3.16% support) is the most frequent in the
--          whole project. Any later figure above 153 baskets for a pair is an error.
