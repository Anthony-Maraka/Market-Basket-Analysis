# Market Basket Analysis in MySQL

Which products are bought together, and which pairs are worth promoting as cross-sell offers or bundles? This project answers that with pure SQL on a retail transaction dataset, using support, confidence and lift, together with checks that screen out misleading results (product variants, outlier orders, rare products, and pairs that are no longer on sale).

**Author:** Anthony Maraka
**Tools:** MySQL 8 (window functions, `JSON_TABLE`), MySQL Workbench
**Data:** Online Retail dataset (`Online_Retail.xlsx`), 164,693 transaction lines

---

## Key Findings

**The data**
- After cleaning: **4,845 baskets, 3,255 products, 83,158 product lines** (from 164,693 raw rows).
- The mean basket is worth **408**, but the median is **300**, so the mean is 36.1% above the typical basket. A few large orders lift the average. A typical basket holds 15 items (mean 17.2).

**Products**
- No single product dominates. The best seller (White Hanging Heart T-Light Holder) is in 10.0% of baskets, and the top 10 products each appear in 5.2-10.0%.
- Bags are the strongest theme in the top 10 (4 of 10), followed by baking and tea-party items.
- Only **144 of 3,255 products (4.4%)** appear in 100 or more baskets. They account for 28.0% of product-in-basket appearances and **36.0% of revenue**, so most revenue (64%) sits in a long tail of rarer products.

**Pairs**
- 1,444 pairs appear in at least 20 baskets. The most frequent pair is in 153 baskets (3.2% of baskets).
- **Most frequent pairs are product variants, not cross-sell.** 88 of the 100 most frequent pairs are variants of one product (for example different designs of a jumbo bag). The pipeline separates these (684 pairs, avg lift 21.5) from cross-family pairs (760 pairs, avg lift 7.1).
- **A high lift is a real signal.** Among all possible pairs of the 144 popular products, only 61.5% have lift above 1, and 36.1% are bought together less often than chance.
- **Selection funnel:** 1,444 pairs kept, 760 cross-family, 453 with lift of at least 3, 440 also on sale together, then the top 10 ranked by pair revenue.

### Recommended bundle candidates

Pairs are flagged `check outliers` if one basket supplies more than 20% of the pair's revenue. The five pairs below pass that check.

| Pair | Baskets | Lift | Pair revenue | Outlier flag |
|---|---|---|---|---|
| Regency Cakestand 3 Tier + Roses Regency Teacup and Saucer | 92 | 5.3 | 9,973 | ok |
| Spotty Bunting + Party Bunting | 99 | 5.7 | 9,322 | ok |
| Regency Cakestand 3 Tier + Green Regency Teacup and Saucer | 81 | 5.5 | 8,408 | ok |
| Jumbo Shopper Vintage Red Paisley + Jumbo Bag Red Retrospot | 115 | 6.7 | 6,706 | ok |
| Regency Cakestand 3 Tier + Pink Regency Teacup and Saucer | 60 | 5.5 | 6,319 | ok |

- **The Regency cakestand is the anchor product.** About 47% of teacup buyers also buy the cakestand, but only 14-22% of cakestand buyers add a given teacup colour. Promotions should point from the teacup to the cakestand, and a "build your set" offer suits it better than one fixed bundle.
- **Five of the top 10 pairs (four doormat pairs and one heart pair) are flagged.** One large order makes up 39-59% of their revenue, so they are not recommended despite high lift.
- **Baskets containing a pair are larger than average** (for example 745 vs 408 for the top pair, and 23.6 vs 17.2 items), so this does not prove a bundle would increase sales. An A/B test would be needed to show that.

---

## Method

| Step | Script | What it does |
|---|---|---|
| 0 | `00_params_and_stopwords.sql` | All thresholds in one `params` table, plus stop words for product-family matching |
| 1 | `01_data_cleaning.sql` | Removes cancelled invoices, non-positive quantity or price, non-product codes and carriage; keeps baskets of 2-50 items |
| 2 | `02_most_popular_products.sql` | Product counts, top sellers, mean and median basket value, range concentration |
| 3 | `03_pairs_most_often_bought_together.sql` | Product pairs found in at least 20 baskets, with pair support |
| 4 | `04_strong_pairs.sql` | Support, confidence and lift for each pair, "same family" vs "cross family" labelling, and an unbiased lift check |
| 5 | `05_pairs_sold_at_same_time.sql` | Shortlist: cross-family, lift of at least 3, on sale together for 90+ days and still selling |
| 6 | `06_cross_sell_or_same_product_variants.sql` | Compares cross-sell pairs with product variants, with spot-checks of the family labelling |
| 7 | `07_final_ranked_list.sql` | Top 10 pairs by revenue, with basket value, outlier flag and an assumed-margin estimate |
| 8 | `08_consistency_checks.sql` | Automated PASS/FAIL checks that recount and reconcile the results |

### Key parameters (`params` table)

| Parameter | Value |
|---|---|
| Basket size | 2 to 50 items |
| Minimum baskets per pair | 20 |
| "Popular" product | 100+ baskets |
| Minimum lift | 3 |
| Days on sale together / still selling within | 90 days / 38 days of data end |
| Shared words for "same family" | 2 |
| Outlier flag | One basket above 20% of pair revenue |
| Assumed margin | 40% (the data has no cost column, so margin figures are an assumption) |

### Metrics

- **Support** = baskets containing both products / all baskets
- **Confidence (A to B)** = baskets containing both / baskets containing A
- **Lift** = support(A and B) / (support(A) x support(B)). A value above 1 means the products are bought together more often than chance.

---

## Limitations

- All support figures are shares of **2-50 item baskets**, not of every order in the raw data.
- Estimated margin uses an assumed 40%, not real cost data.
- "Same family" is decided by shared words in product descriptions, so a few pairs may be misclassified (script 06 includes spot-checks).
- Pairs need 20 or more shared baskets, so the analysis cannot say anything about rarer products.
- The data shows association, not causation.

## How to Run

1. Load the Online Retail data into MySQL as a table named `online_retail`, in a schema called `market_basket_analysis_project`.
2. Run the scripts in order, `00` to `08`, in MySQL Workbench (MySQL 8.0 or later).
3. Script `08` should return PASS for every check.
