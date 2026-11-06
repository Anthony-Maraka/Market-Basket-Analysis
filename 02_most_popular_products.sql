-- =====================================================================
-- 02_most_popular_products.
-- =====================================================================
USE market_basket_analysis_project;

-- ---------------------------------------------------------------------
-- 1. Product counts: in how many baskets does each product appear?
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS product_counts;
CREATE TABLE product_counts AS
SELECT StockCode, COUNT(*) AS orders, MIN(InvoiceDate) AS first_sold, MAX(InvoiceDate) AS last_sold
FROM clean_lines
GROUP BY StockCode;
ALTER TABLE product_counts ADD PRIMARY KEY (StockCode);

-- ---------------------------------------------------------------------
-- 2. Top 10 products. pct_of_orders is the single-product SUPPORT.
-- ---------------------------------------------------------------------
SELECT n.name, c.orders,
       ROUND(100 * c.orders / (SELECT COUNT(*) FROM order_totals), 1) AS pct_of_orders
FROM product_counts c JOIN product_names n USING (StockCode)
ORDER BY c.orders DESC, n.name LIMIT 10;

-- ---------------------------------------------------------------------
-- 3. Average basket value (mean) and average items per basket
-- ---------------------------------------------------------------------
SELECT ROUND(AVG(total)) AS avg_basket_value,
       COUNT(*)          AS orders
FROM order_totals;

SELECT ROUND(AVG(items), 1) AS avg_items_per_basket
FROM (SELECT COUNT(*) AS items FROM clean_lines GROUP BY InvoiceNo) t;

-- ---------------------------------------------------------------------
-- 4. MEDIAN basket value and median items per basket
--    MySQL has no MEDIAN(). Rank the baskets, then average the middle one (odd count)
--    or the two middle ones (even count).
-- ---------------------------------------------------------------------
SELECT ROUND(AVG(total)) AS median_basket_value
FROM (SELECT total,
             ROW_NUMBER() OVER (ORDER BY total) AS rn,
             COUNT(*)     OVER ()               AS cnt
      FROM order_totals) r
WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2));

SELECT AVG(items) AS median_items_per_basket
FROM (SELECT items,
             ROW_NUMBER() OVER (ORDER BY items) AS rn,
             COUNT(*)     OVER ()               AS cnt
      FROM (SELECT COUNT(*) AS items FROM clean_lines GROUP BY InvoiceNo) b) r
WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2));

-- Mean vs median side by side: a mean well above the median means a few big orders lift the average.
SELECT ROUND(AVG(total))                                                       AS mean_basket_value,
       (SELECT ROUND(AVG(total))
          FROM (SELECT total, ROW_NUMBER() OVER (ORDER BY total) AS rn, COUNT(*) OVER () AS cnt
                  FROM order_totals) r
         WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2)))              AS median_basket_value,
       ROUND(100 * (AVG(total) / (SELECT AVG(total)
          FROM (SELECT total, ROW_NUMBER() OVER (ORDER BY total) AS rn, COUNT(*) OVER () AS cnt
                  FROM order_totals) r
         WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2))) - 1), 1)     AS mean_above_median_pct
FROM order_totals;

-- ---------------------------------------------------------------------
-- 5. Popular products (threshold = params.min_product_orders, 100 by default)
-- ---------------------------------------------------------------------
SELECT COUNT(*)                                                   AS products,
       SUM(orders >= (SELECT min_product_orders FROM params))     AS in_100plus,
       ROUND(100 * SUM(orders >= (SELECT min_product_orders FROM params)) / COUNT(*), 1) AS pct_of_products
FROM product_counts;

-- ---------------------------------------------------------------------
-- 6. NEW (B): How concentrated is the range?
--    Share of all "product appears in a basket" events, and of revenue, that comes from the
--    popular products. If both shares are high, the long tail of rare products matters little.
-- ---------------------------------------------------------------------
SELECT ROUND(100 * SUM(CASE WHEN pc.orders >= p.min_product_orders THEN pc.orders END) / SUM(pc.orders), 1)
         AS pct_of_appearances_from_popular_products
FROM product_counts pc CROSS JOIN params p;

SELECT ROUND(100 * SUM(CASE WHEN pc.orders >= p.min_product_orders THEN cl.revenue END) / SUM(cl.revenue), 1)
         AS pct_of_revenue_from_popular_products
FROM clean_lines cl
JOIN product_counts pc ON pc.StockCode = cl.StockCode
CROSS JOIN params p;

-- INSIGHT 1 (top products): WHITE HANGING HEART T-LIGHT HOLDER is the most popular product, in 483 of
--          4,845 baskets (10.0%). REGENCY CAKESTAND 3 TIER (8.7%) and JUMBO BAG RED RETROSPOT (8.6%)
--          follow. The top 10 products each appear in 5.2-10.0% of baskets, so even the best seller is
--          absent from 90% of baskets: no single product dominates.
-- INSIGHT 2 (themes in the top 10): Bags are the strongest theme, with 4 of the top 10 (JUMBO BAG RED
--          RETROSPOT, LUNCH BAG RED RETROSPOT, JUMBO BAG VINTAGE DOILY, LUNCH BAG SUKI DESIGN). Baking and
--          tea-party items form a second theme (REGENCY CAKESTAND, SET OF 3 CAKE TINS PANTRY DESIGN,
--          PACK OF 72 RETROSPOT CAKE CASES), and the RETROSPOT design appears in 3 of the 10.
-- INSIGHT 3 (basket value): The mean basket is worth 408 across 4,845 orders (baskets of 2-50 items),
--          but the MEDIAN basket is worth 300, so the mean is 36.1% above the typical basket:
--          a few large orders lift the average. A typical basket holds 15 items (mean 17.2), so the
--          item count is much less skewed than the value: the large orders are large in value, not
--          just in items. Use the median (300) as the benchmark for a "normal" basket.
-- INSIGHT 4 (long tail): Only 144 of 3,255 products (4.4%) appear in 100 or more baskets. These 144
--          products account for 28.0% of all product-in-basket appearances and 36.0% of revenue.
--          They earn far more than their share of the range, but 72% of appearances and 64% of
--          revenue sit in the rare products, so a lot of activity is in the long tail and is
--          not covered by an analysis built on popular products.
-- WATCH: All percentages are shares of baskets with 2-50 items, not of all orders in the raw data.