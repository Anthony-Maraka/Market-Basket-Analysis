-- =====================================================================
-- 07_final_ranked_list.sql
-- =====================================================================

USE market_basket_analysis_project;

SELECT s.name_a, s.name_b, s.pair_orders,
       ROUND(100 * s.support, 2)                                    AS support_pct,
       ROUND(s.conf_a_to_b, 2)                                      AS conf_a_to_b,
       ROUND(s.conf_b_to_a, 2)                                      AS conf_b_to_a,
       ROUND(s.lift, 1)                                             AS lift,
       ROUND(AVG(o.total))                                          AS avg_basket_value_with_pair,   -- baskets containing BOTH products
       (SELECT ROUND(AVG(total)) FROM order_totals)                 AS avg_basket_value_all,
       ROUND(AVG(o.items), 1)                                       AS avg_items_with_pair,
       (SELECT ROUND(AVG(items), 1) FROM order_totals)              AS avg_items_all,
       ROUND(SUM(a.revenue + b.revenue))                            AS pair_revenue,
       ROUND(100 * MAX(a.revenue + b.revenue) / SUM(a.revenue + b.revenue)) AS top_basket_share_pct,
       IF(MAX(a.revenue + b.revenue) / SUM(a.revenue + b.revenue) > (SELECT max_top_basket_share FROM params),
          'check outliers', 'ok')                                   AS outlier_flag,
       ROUND(SUM(a.revenue + b.revenue) * (SELECT assumed_margin FROM params)) AS est_margin_assumed  -- ASSUMED margin: the data has no cost
FROM shortlist s
JOIN clean_lines a ON a.StockCode = s.prod_a
JOIN clean_lines b ON b.InvoiceNo = a.InvoiceNo AND b.StockCode = s.prod_b
JOIN order_totals o ON o.InvoiceNo = a.InvoiceNo
GROUP BY s.prod_a, s.prod_b
ORDER BY pair_revenue DESC LIMIT 10;

-- INSIGHT:
--   #1 is REGENCY CAKESTAND 3 TIER + ROSES REGENCY TEACUP AND SAUCER: 92 baskets, support 1.9%,
--   lift 5.3, pair revenue 9,973 (est. margin ~3,989 at the assumed margin). No outlier flag
--   (largest basket is only 4% of pair revenue), so the result is broad-based.
--   Baskets with these pairs average 745 vs 408 for all baskets, and hold 23.6 items vs 17.2:
--   part of the gap is simply basket size, so it is NOT proof that a bundle adds sales.
--   5 of the 10 pairs are flagged 'check outliers' (all doormat pairs plus the heart wicker /
--   T-light pair): one big order makes up 39-59% of their pair revenue. Treat with caution.
--   Cleanest candidates (flag = ok): Regency cakestand + roses/green/pink teacup, spotty + party
--   bunting, and the two jumbo bags.