-- =====================================================================
-- 08_consistency_checks.sql
-- =====================================================================
USE market_basket_analysis_project;

SELECT check_name, IF(ok, 'PASS', 'FAIL') AS result FROM (
  SELECT 'orders in order_totals = distinct invoices in clean_lines' AS check_name,
         (SELECT COUNT(*) FROM order_totals) = (SELECT COUNT(DISTINCT InvoiceNo) FROM clean_lines) AS ok
  UNION ALL SELECT 'every basket has between min and max items',
         (SELECT COUNT(*) FROM order_totals o CROSS JOIN params p
           WHERE o.items < p.min_basket_items OR o.items > p.max_basket_items) = 0
  UNION ALL SELECT 'sum of product_counts.orders = rows in clean_lines',
         (SELECT SUM(orders) FROM product_counts) = (SELECT COUNT(*) FROM clean_lines)
  UNION ALL SELECT 'every kept pair meets the pair floor',
         (SELECT MIN(pair_orders) FROM pairs) >= (SELECT min_pair_orders FROM params)
  UNION ALL SELECT 'pair_metrics has exactly one row per pair',
         (SELECT COUNT(*) FROM pair_metrics) = (SELECT COUNT(*) FROM pairs)
  UNION ALL SELECT 'a pair can never occur more often than its rarer product',
         (SELECT COUNT(*) FROM pair_metrics m
            JOIN product_counts a ON a.StockCode = m.prod_a
            JOIN product_counts b ON b.StockCode = m.prod_b
           WHERE m.pair_orders > LEAST(a.orders, b.orders)) = 0
  UNION ALL SELECT 'support and both confidences are within 0..1',
         (SELECT COUNT(*) FROM pair_metrics
           WHERE support > 1 OR conf_a_to_b > 1 OR conf_b_to_a > 1 OR support <= 0) = 0
  UNION ALL SELECT 'lift recomputed from raw counts matches stored lift (max difference < 1e-9)',
         (SELECT COALESCE(MAX(ABS(m.lift - (m.pair_orders * t.n) / (a.orders * b.orders))), 0) < 1e-9
            FROM pair_metrics m
            JOIN product_counts a ON a.StockCode = m.prod_a
            JOIN product_counts b ON b.StockCode = m.prod_b
            CROSS JOIN (SELECT COUNT(*) AS n FROM order_totals) t)
  UNION ALL SELECT 'top pair recounted from clean_lines equals pair_orders',
         (SELECT COUNT(*) FROM clean_lines x
            JOIN clean_lines y ON y.InvoiceNo = x.InvoiceNo
            JOIN (SELECT prod_a, prod_b, pair_orders FROM pairs ORDER BY pair_orders DESC, prod_a, prod_b LIMIT 1) tp
              ON x.StockCode = tp.prod_a AND y.StockCode = tp.prod_b) =
         (SELECT MAX(pair_orders) FROM pairs)
  UNION ALL SELECT 'shortlist is a subset of pair_metrics (same pair_orders and lift)',
         (SELECT COUNT(*) FROM shortlist s
            LEFT JOIN pair_metrics m ON m.prod_a = s.prod_a AND m.prod_b = s.prod_b
           WHERE m.prod_a IS NULL OR m.pair_orders <> s.pair_orders OR m.lift <> s.lift) = 0
  UNION ALL SELECT 'shortlist only has cross-family pairs above the lift floor',
         (SELECT COUNT(*) FROM shortlist s CROSS JOIN params p
           WHERE s.pair_type <> 'cross family' OR s.lift < p.min_lift) = 0
  UNION ALL SELECT 'no pair in the project exceeds the largest pair in `pairs`',
         (SELECT COALESCE(MAX(pair_orders), 0) FROM shortlist) <= (SELECT MAX(pair_orders) FROM pairs)
  UNION ALL SELECT 'final list: baskets found by the 07 joins = shortlist.pair_orders for every pair',
         (SELECT COUNT(*) FROM shortlist s
            WHERE s.pair_orders <> (SELECT COUNT(*) FROM clean_lines a
                                      JOIN clean_lines b ON b.InvoiceNo = a.InvoiceNo
                                     WHERE a.StockCode = s.prod_a AND b.StockCode = s.prod_b)) = 0
) c;


SELECT (SELECT COUNT(*) FROM order_totals)                 AS orders,      -- Total orders
       (SELECT COUNT(*) FROM product_counts)               AS products,    -- total number of products
       (SELECT ROUND(AVG(total)) FROM order_totals)        AS avg_basket_value,  -- Overall average basket value
       (SELECT COUNT(*) FROM pairs)                        AS pairs_kept,        -- Number of pairs kept
       (SELECT MAX(pair_orders) FROM pairs)                AS largest_pair_orders, -- Maximum order pairs
       (SELECT COUNT(*) FROM pair_metrics WHERE pair_type = 'same family')  AS same_family_pairs,  -- same family pairs containing different variants of the same products
       (SELECT COUNT(*) FROM pair_metrics WHERE pair_type = 'cross family') AS cross_family_pairs, -- Cross family pairs that indicate different products in the same basket
       (SELECT COUNT(*) FROM shortlist)                    AS shortlisted_pairs;  -- Summary of product pairs

-- INSIGHT:
--   All 12 consistency checks PASS: basket totals, pair counts, support/confidence/lift and the
--   final ranked list reconcile with clean_lines, so the 07 results can be relied on.
--   Scale: 4,845 baskets, 3,255 products, average basket value 408.
--   1,444 pairs met the pair floor (largest pair: 153 baskets, 3.2% of all baskets).
--   Pair mix: 684 same-family pairs (47%, variants of one product, not cross-sell) and
--   760 cross-family pairs (53%). 440 of the 760 cross-family pairs (58%) cleared the
--   lift floor and form the shortlist, from which 07 ranks the top 10.
--   Limits: the checks prove the numbers are internally consistent, not that the margin
--   assumption or the outlier threshold are right. Those remain judgement calls.