-- =====================================================================
-- 01_data_cleaning.sql
-- =====================================================================
USE market_basket_analysis_project;

SELECT COUNT(*) AS raw_rows FROM online_retail;  -- Total rows in the entire dataset

-- 1. One row per product per order.
--    Removes cancelled (C) / adjustment (A) invoices, zero or negative quantity/price,
--    and non-product codes (POST, DOT, M, BANK CHARGES...). GROUP BY also collapses duplicate lines,
--    so a basket "contains" a product once, however many lines or units it had.
DROP TABLE IF EXISTS clean_lines;
CREATE TABLE clean_lines AS
SELECT InvoiceNo, StockCode, MIN(InvoiceDate) AS InvoiceDate, SUM(Quantity * UnitPrice) AS revenue
FROM online_retail
WHERE InvoiceNo NOT REGEXP '^[A-Za-z]'
  AND Quantity > 0 AND UnitPrice > 0
  AND StockCode REGEXP '^[0-9]{5}' AND StockCode <> '23444'   -- 23444 = "Next Day Carriage"
GROUP BY InvoiceNo, StockCode;
ALTER TABLE clean_lines ADD PRIMARY KEY (InvoiceNo, StockCode), ADD INDEX (StockCode);

-- 2. Keep only baskets with min..max items (1-item baskets have no pairs; giant wholesale
--    baskets flood the pairs). The limits are read from params.
--    WRITE-UP: from here on, "total baskets" means baskets of 2-50 items,
--    so every support figure is "share of 2-50 item baskets", not "share of all orders".
DELETE FROM clean_lines WHERE InvoiceNo IN (
  SELECT InvoiceNo FROM (
    SELECT InvoiceNo FROM clean_lines GROUP BY InvoiceNo
    HAVING COUNT(*) NOT BETWEEN (SELECT min_basket_items FROM params)
                            AND (SELECT max_basket_items FROM params)) t);

-- 3. One name per product, and order totals (one row per basket = the denominator for support)
DROP TABLE IF EXISTS product_names;
CREATE TABLE product_names AS
SELECT StockCode, TRIM(MAX(Description)) AS name FROM online_retail
WHERE Quantity > 0 AND UnitPrice > 0 GROUP BY StockCode;
ALTER TABLE product_names ADD PRIMARY KEY (StockCode);

DROP TABLE IF EXISTS order_totals;
CREATE TABLE order_totals AS
SELECT InvoiceNo, SUM(revenue) AS total, COUNT(*) AS items FROM clean_lines GROUP BY InvoiceNo;
ALTER TABLE order_totals ADD PRIMARY KEY (InvoiceNo);

-- 4. Records summary - always current because it is a query, not a typed comment
SELECT COUNT(*)                  AS line_rows,
       COUNT(DISTINCT InvoiceNo) AS orders,
       COUNT(DISTINCT StockCode) AS products
FROM clean_lines;

-- =======================================
-- Cleaned Dataset Records
-- =======================================
-- Line rows ---------------------> 83158
-- Total number of products ------> 3255
-- Total Number of orders  -------> 4845