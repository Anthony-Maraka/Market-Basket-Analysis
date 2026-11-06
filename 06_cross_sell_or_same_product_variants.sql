-- =====================================================================
-- 06_cross_sell_or_same_product_variants.sql
-- =====================================================================
USE market_basket_analysis_project;

SELECT pair_type, COUNT(*) AS pairs, ROUND(AVG(lift), 1) AS avg_lift
FROM pair_metrics GROUP BY pair_type;

-- Of the 100 most frequent pairs, how many are variants of one product?
SELECT pair_type, COUNT(*) AS in_top_100 FROM
  (SELECT pair_type FROM pair_metrics ORDER BY pair_orders DESC, lift DESC, prod_a, prod_b LIMIT 100) t
GROUP BY pair_type;

-- Genuine cross-sell candidates, strongest first
SELECT name_a, name_b, pair_orders, ROUND(100 * support, 2) AS support_pct, ROUND(lift, 1) AS lift
FROM pair_metrics
WHERE pair_type = 'cross family'
ORDER BY lift DESC, pair_orders DESC LIMIT 8;

-- Same idea, but ranked by how OFTEN the pair is bought (lift alone favours rare, niche items:
-- two products in ~45 baskets each can reach lift 50 from just ~20 shared baskets).
SELECT name_a, name_b, pair_orders, ROUND(100 * support, 2) AS support_pct,
       ROUND(conf_a_to_b, 2) AS conf_a_to_b, ROUND(conf_b_to_a, 2) AS conf_b_to_a, ROUND(lift, 1) AS lift
FROM pair_metrics
WHERE pair_type = 'cross family' AND lift >= (SELECT min_lift FROM params)
ORDER BY pair_orders DESC, lift DESC LIMIT 8;

SELECT name_a, name_b, shared_words, pair_orders
FROM pair_metrics
WHERE pair_type = 'cross family' AND shared_words = 1
ORDER BY pair_orders DESC LIMIT 15;

-- SPOT-CHECK 2: pairs called "same family" with the fewest shared words (are they really variants?)
SELECT name_a, name_b, shared_words, pair_orders
FROM pair_metrics
WHERE pair_type = 'same family'
ORDER BY shared_words, pair_orders DESC LIMIT 15;


--   Same-family pairs: 684 with avg lift 21.5. Cross-family pairs: 760 with avg lift 7.1.
--   88 of the 100 most frequent pairs are same-family, so customers mostly buy variants of one design.
