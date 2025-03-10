-- SQL Consumer Goods Project For AtliQ :-

-- =============================  Questions  =============================

-- Q1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region ?

SELECT DISTINCT
market
FROM dim_customer
WHERE customer = "Atliq Exclusive" AND region = "APAC";

-- Q2. What is the percentage of unique product increase in 2021 vs. 2020? The
-- 	   final output contains these fields,
--     unique_products_2020
--     unique_products_2021
--     percentage_chg

WITH CTE_1 AS
(
SELECT COUNT( DISTINCT product_code) AS unique_products_2020 FROM fact_sales_monthly WHERE fiscal_year = 2020
),
CTE_2 AS
(
SELECT COUNT( DISTINCT product_code) AS unique_products_2021 FROM fact_sales_monthly WHERE fiscal_year = 2021
)
-- Main Query :-
SELECT
	unique_products_2020,
	unique_products_2021,
	ROUND(((unique_products_2021 - unique_products_2020)*100.0)/unique_products_2020,2) AS Percentage_Change
FROM CTE_1 
CROSS JOIN CTE_2;

-- Q3. Provide a report with all the unique product counts for each segment and
--     sort them in descending order of product counts. The final output contains 2 fields,
--     segment
--     product_count

SELECT
	segment,
	COUNT( DISTINCT product_code ) AS products_count
FROM dim_product
GROUP BY segment
ORDER BY products_count DESC;

-- Q4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? The final output contains these fields,
-- segment
-- product_count_2020
-- product_count_2021
-- difference

WITH PC_20 AS
(
	SELECT
		p.segment,
		COUNT( DISTINCT p.product_code ) AS product_count_2020
	FROM dim_product p 
	JOIN fact_sales_monthly s
	ON p.product_code = s.product_code
	WHERE s.fiscal_year = 2020
	GROUP BY p.segment
),
PC_21 AS
(
	SELECT
		p.segment,
		COUNT( DISTINCT p.product_code ) AS product_count_2021
	FROM dim_product p 
	JOIN fact_sales_monthly s
	ON p.product_code = s.product_code
	WHERE s.fiscal_year = 2021
	GROUP BY p.segment
)
-- Main Query :-
SELECT
	PC_20.segment,
	PC_20.product_count_2020,
	PC_21.product_count_2021,
	(PC_21.product_count_2021 - PC_20.product_count_2020) AS difference
FROM PC_20
JOIN PC_21 
ON PC_20.segment = PC_21.segment
ORDER BY difference DESC;

-- Q5. Get the products that have the highest and lowest manufacturing costs.
--     The final output should contain these fields,
--     product_code
--     product
--     manufacturing_cost

WITH Max_Min_Cost AS (
    SELECT 
        product_code, 
        manufacturing_cost
    FROM fact_manufacturing_cost
    WHERE manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost)
    OR manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost)
)
SELECT 
    p.product_code, 
    p.product, 
    mc.manufacturing_cost
FROM Max_Min_Cost mc
JOIN dim_product p 
ON mc.product_code = p.product_code
ORDER BY mc.manufacturing_cost DESC;

-- Q6. Generate a report which contains the top 5 customers who received an 
--     average high pre_invoice_discount_pct for the fiscal year 2021 and in the
--     Indian market. The final output contains these fields,
--     customer_code
--     customer
--     average_discount_percentage

SELECT 
	c.customer_code,
	c.customer,
	ROUND(AVG(pd.pre_invoice_discount_pct),2) AS Avg_pre_invoice_discount_pct
FROM fact_pre_invoice_deductions pd
JOIN dim_customer c
ON pd.customer_code = c.customer_code
WHERE pd.fiscal_year = 2021 AND c.market = 'India'
GROUP BY c.customer_code,c.customer
ORDER BY Avg_pre_invoice_discount_pct DESC
LIMIT 5;

-- Q7. Get the complete report of the Gross sales amount for the customer “Atliq
--     Exclusive” for each month. This analysis helps to get an idea of low and
--     high-performing months and take strategic decisions.
--     The final report contains these columns:
--     Month
--     Year
--     Gross sales Amount

SELECT 
	MONTH(s.date) AS Month,
	s.fiscal_year AS Year,
	ROUND(SUM(g.gross_price * s.sold_quantity),2) AS Gross_Sales_Amount
FROM fact_gross_price g
JOIN fact_sales_monthly s
ON g.product_code = s.product_code AND g.fiscal_year = s.fiscal_year
JOIN dim_customer c
ON s.customer_code = c.customer_code
WHERE c.customer = "Atliq Exclusive"
GROUP BY MONTH(s.date),s.fiscal_year
ORDER BY s.fiscal_year, MONTH(s.date);

-- Q8. In which quarter of 2020, got the maximum total_sold_quantity? The final
-- 	   output contains these fields sorted by the total_sold_quantity,
--     Quarter
-- 	   total_sold_quantity
SELECT
    CASE WHEN MONTHNAME(date) IN ('September','October','November') THEN 'Quarter 1'
		 WHEN MONTHNAME(date) IN ('December','January','February') THEN 'Quarter 2'
         WHEN MONTHNAME(date) IN ('March','April','May') THEN 'Quarter 3'
         ELSE 'Quarter 4' END AS Quarter,
	ROUND(SUM(sold_quantity)/1000000,2) AS Total_Sold_Quantity_Mlns
FROM fact_sales_monthly
WHERE fiscal_year = 2020
GROUP BY Quarter
ORDER BY Total_Sold_Quantity_Mlns DESC;

-- Q9. Which channel helped to bring more gross sales in the fiscal year 2021
-- 	   and the percentage of contribution? The final output contains these fields,
--     channel
--     gross_sales_mln
--     percentage
WITH CTE_1 AS
(
	SELECT 
		c.channel,
		ROUND(SUM(s.sold_quantity * g.gross_price )/1000000,2) AS gross_price_mlns
	FROM dim_customer c
	JOIN fact_sales_monthly s
	ON c.customer_code = s.customer_code
	JOIN fact_gross_price g
	ON s.product_code = g.product_code AND s.fiscal_year = g.fiscal_year
	WHERE s.fiscal_year = 2021
	GROUP BY c.channel
)
-- Main Query :-
SELECT
	channel,
	gross_price_mlns,
	ROUND(gross_price_mlns * 100 / (SELECT SUM(gross_price_mlns) FROM CTE_1),2) AS percentage
FROM CTE_1
GROUP BY channel
ORDER BY gross_price_mlns DESC;

-- Q10. Get the Top 3 products in each division that have a high
-- 		total_sold_quantity in the fiscal_year 2021? The final output contains these fields,
-- 		division
-- 		product_code
-- 		product
-- 		total_sold_quantity
-- 		rank_order
WITH CTE_1 AS
(
	SELECT
		p.division,
		p.product_code,
		p.product,
		SUM(s.sold_quantity) AS total_sold_qty,
		DENSE_RANK() OVER(PARTITION BY p.division ORDER BY SUM(s.sold_quantity) DESC) AS ranking
	FROM dim_product p
	JOIN fact_sales_monthly s
	ON p.product_code = s.product_code
	WHERE s.fiscal_year = 2021
	GROUP BY p.division,p.product_code,p.product
)
-- Main Query :-
SELECT * FROM CTE_1 WHERE ranking <= 3;