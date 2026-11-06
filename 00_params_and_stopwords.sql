-- =====================================================================
-- 00_params_and_stopwords.
-- =====================================================================
USE market_basket_analysis_project;

DROP TABLE IF EXISTS params;
CREATE TABLE params (
  min_basket_items       INT,           -- baskets smaller than this have no pairs
  max_basket_items       INT,           -- bigger baskets are wholesale orders that flood the pairs
  min_pair_orders        INT,           -- a pair must appear in at least this many baskets (support floor, as a count)
  min_product_orders     INT,           -- what counts as a "popular" product (used in the unbiased lift check)
  min_support            DECIMAL(6,4),  -- support floor used when ranking top-lift pairs (0.01 = 1% of baskets)
  min_lift               DECIMAL(6,2),  -- "meaningful" association
  min_days_together      INT,           -- both products must have been on sale together this long
  recent_days            INT,           -- both products must still be selling within this many days of the data end
  same_family_min_shared INT,           -- shared meaningful words needed to call a pair "same family"
  max_top_basket_share   DECIMAL(3,2),  -- flag a pair if ONE basket supplies more than this share of its revenue
  assumed_margin         DECIMAL(3,2)   -- ASSUMPTION: the data has no cost column
);
INSERT INTO params VALUES (2, 50, 20, 100, 0.01, 3, 90, 38, 2, 0.20, 0.40);

SELECT * FROM params;

-- Words ignored when deciding whether two products belong to the same family.
-- Colours and filler words are what make variants differ, so they must not count as "shared".
DROP TABLE IF EXISTS stop_words;
CREATE TABLE stop_words (word VARCHAR(60) PRIMARY KEY);
INSERT INTO stop_words VALUES
 ('RED'),('PINK'),('GREEN'),('BLUE'),('WHITE'),('BLACK'),('YELLOW'),('ORANGE'),('PURPLE'),
 ('IVORY'),('CREAM'),('SILVER'),('GOLD'),('TURQUOISE'),('BROWN'),('GREY'),('LILAC'),('MULTI'),
 ('SET'),('OF'),('AND'),('THE'),('WITH'),('IN'),('FOR'),('A'),('SMALL'),('LARGE'),('MEDIUM'),('MINI');
 
-- ======================================
 -- Dataset Summary
-- ======================================
 -- minimum basket items ----> 2
 -- maximum basket items ----> 50
 -- mimimum pair orders -----> 20
 -- minimum product orders---> 20
 -- minimum product orders --> 100
 -- minimum support  --------> 0.01
 -- minimum lift  -----------> 3.00
 -- minimum days together ---> 90
 -- recent days   -----------> 38
 -- same family minimum shared --> 2
 -- maximum top basket share -- 0.20
 -- Assumed margin ----------> 0.040
 -- =========================================
