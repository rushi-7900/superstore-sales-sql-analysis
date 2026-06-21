-- Create Database

CREATE DATABASE superstore_sales1;
USE superstore_sales1;

-- RAW TABLE
CREATE TABLE superstore_raw (
    row_id INT,
    order_id VARCHAR(30),
    order_date VARCHAR(20),
    ship_date VARCHAR(20),
    ship_mode VARCHAR(50),
    customer_id VARCHAR(30),
    customer_name VARCHAR(100),
    segment VARCHAR(50),
    country VARCHAR(100),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    region VARCHAR(50),
    product_id VARCHAR(50),
    category VARCHAR(50),
    sub_category VARCHAR(50),
    product_name VARCHAR(255),
    sales DECIMAL(10,2),
    quantity INT,
    discount DECIMAL(5,2),
    profit DECIMAL(10,2)
);
select * from superstore_raw;
select COUNT(*) FROM superstore_raw;

-- Customers Table
CREATE TABLE customers (
    customer_id VARCHAR(30) PRIMARY KEY,
    customer_name VARCHAR(100),
    segment VARCHAR(50),
    country VARCHAR(100)
);

-- Orders Table
CREATE TABLE orders (
    order_id VARCHAR(30) PRIMARY KEY,
    order_date_clean DATE,
    ship_date_clean DATE,
    ship_mode VARCHAR(50),
    customer_id VARCHAR(30),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    region VARCHAR(50),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Products Table
CREATE TABLE products (
    product_id VARCHAR(50) PRIMARY KEY,
    category VARCHAR(50),
    sub_category VARCHAR(50),
    product_name VARCHAR(255)
);

-- Sales Table
CREATE TABLE sales (
    row_id INT PRIMARY KEY,
    order_id VARCHAR(30),
    product_id VARCHAR(50),
    sales DECIMAL(10,2),
    quantity INT,
    discount DECIMAL(5,2),
    profit DECIMAL(10,2),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

--  ____________DATE CLEAN_______________
-- 1
ALTER TABLE superstore_raw 
ADD order_date_clean DATE,
ADD ship_date_clean DATE;

-- 2
UPDATE superstore_raw
SET order_date_clean = 
    CASE 
        WHEN order_date LIKE '%/%' 
            THEN STR_TO_DATE(order_date, '%m/%d/%Y')
        ELSE STR_TO_DATE(order_date, '%Y-%m-%d')
    END;
    
-- 3 
UPDATE superstore_raw
SET ship_date_clean =
    CASE 
        WHEN ship_date LIKE '%/%'
            THEN STR_TO_DATE(ship_date, '%m/%d/%Y')
        ELSE STR_TO_DATE(ship_date, '%Y-%m-%d')
    END;
  
    
-- DEDUPLICATE TABLE----
CREATE TABLE superstore_clean AS
SELECT * FROM (SELECT *,ROW_NUMBER() OVER (PARTITION BY row_id ORDER BY row_id) AS rn
    FROM superstore_raw
) t
WHERE rn = 1;

SELECT * FROM Superstore_clean;

-- CHECK DUPLICATES--
SELECT row_id, COUNT(*) AS duplicate_count
FROM superstore_raw
GROUP BY row_id
HAVING COUNT(*) > 1;


-- ----------------INSERT INTO CUSTOMERS---------------------

INSERT IGNORE INTO customers (customer_id, customer_name, segment, country)
SELECT DISTINCT customer_id, customer_name, segment, country
FROM superstore_clean;

SELECT * FROM  customers; 
SELECT count(*) FROM customers; 
-- Check for Null IDs---------
SELECT * FROM customers WHERE customer_id IS NULL;
   
    -- -------------INSERET INTO ORDER TABLE------------------
INSERT IGNORE INTO orders (order_id, order_date_clean, ship_date_clean, ship_mode, customer_id, city, state, postal_code, region)
SELECT DISTINCT order_id, order_date_clean, ship_date_clean, ship_mode,
       customer_id, city, state, postal_code, region
FROM superstore_clean;


SELECT * FROM  orders;    
SELECT count(*) FROM  orders;   
-- Check for Null IDs---------
 SELECT * FROM orders WHERE order_id IS NULL OR customer_id IS NULL;
 
-- --------------- INSERT INTO PRODUCTS TABLE-------
INSERT IGNORE INTO products (product_id, category, sub_category, product_name)
SELECT DISTINCT product_id, category, sub_category, product_name
FROM superstore_clean
;

SELECT * FROM products;
SELECT count(*) FROM products;
-- Check for Null IDs---------
SELECT * FROM products WHERE product_id IS NULL;

-- ------------------INSERT INTO SALES TABLE--------------
INSERT IGNORE INTO sales (row_id, order_id, product_id, sales, quantity, discount, profit)
SELECT row_id, order_id, product_id, sales, quantity, discount, profit
FROM superstore_clean;

SELECT * FROM sales;
select count(*) from sales;
-- Check for Null IDs---------
SELECT * FROM sales WHERE row_id IS NULL OR order_id IS NULL OR product_id IS NULL;


-- -------------------------------------------------
SELECT COUNT(*) FROM superstore_clean;


-- 1 Find the top 5 customers who contributed the highest profit overall, along with their percentage share of total profit.
SELECT c.customer_name,
       SUM(s.profit) AS total_profit,
       ROUND(SUM(s.profit) * 100 / (SELECT SUM(profit) FROM sales), 2) AS profit_share_pct
FROM sales s
INNER JOIN orders o ON s.order_id = o.order_id
INNER JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.customer_name
ORDER BY total_profit DESC
LIMIT 5;

-- 2 To identify customers who placed orders in all four regions
SELECT c.customer_id, c.customer_name
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.customer_name
HAVING COUNT(DISTINCT o.region) = 4;

-- 3 Show customers who generated negative total profit across all orders.
SELECT c.customer_id , c.customer_name
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id 
INNER JOIN sales s ON o.order_id = s.order_id 
GROUP BY c.customer_id , c.customer_name
HAVING sum(s.profit) < 0;

-- 4 Find customers who placed more than 5 distinct orders and calculate their average order value (AOV)
SELECT c.customer_id,c.customer_name ,
count(distinct o.order_id ) as total_order,
sum(s.sales) / count(distinct o.order_id) as avg_order_value
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id 
INNER JOIN sales s ON o.order_id = s.order_id
GROUP BY c.customer_id,c.customer_name 
HAVING count(distinct o.order_id) > 5;


-- 5 Rank customers by total sales within each segment using window functions.
SELECT c.segment, c.customer_id,c.customer_name,
	sum(s.sales) as total_sales,
	rank() over(partition by c.segment order by sum(s.sales)desc) as ranking
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id
INNER JOIN sales s ON o.order_id = s.order_id
GROUP BY c.segment,c.customer_id,c.customer_name
ORDER BY c.segment,ranking;

-- 6 Calculate the average shipping time (days between order_date_clean and ship_date_clean) per ship_mode. 
SELECT o.ship_mode,
avg(datediff(o.ship_date_clean,o.order_date_clean)) as avg_shiping_time
FROM orders o
GROUP BY o.ship_mode
order by avg_shiping_time ;

-- 7 shipping time for every single order
SELECT o.order_id,o.customer_id,o.ship_mode,
datediff(o.ship_date_clean, o.order_date_clean) AS shipping_days
FROM orders o
ORDER BY shipping_days DESC;

-- 8 Find orders where shipping time exceeded 10 days. 
SELECT o.order_id,o.customer_id,o.state,o.city,o.region,
datediff(o.ship_date_clean, o.order_date_clean) as shipping_days
FROM orders o
where datediff(o.ship_date_clean, o.order_date_clean) > 10
ORDER BY shipping_days DESC;

-- 9 Identify the most common ship_mode used in each region. 
SELECT region, ship_mode, order_count
FROM (SELECT o.region,o.ship_mode,
COUNT(*) AS order_count,
RANK() OVER (PARTITION BY o.region ORDER BY COUNT(*) DESC) AS rnk
FROM orders o
GROUP BY o.region, o.ship_mode
) ranked   -- 👈 this is the alias for the subquery
WHERE rnk = 1
ORDER BY region;

-- 10 Display the number of orders per month between 2014 and 2017. 
SELECT year(o.order_date_clean) as order_year,
month(o.order_date_clean) as order_month,
count(o.order_id) as total_order
FROM orders o
where o.order_date_clean BETWEEN '2014-01-01' AND '2017-12-31'
GROUP BY year(o.order_date_clean),month(o.order_date_clean)
order by order_year,order_month;

-- 11 Find orders where sales > 1000 but profit < 0. 
SELECT o.order_id,o.order_date_clean,o.customer_id,o.city,o.state,
sum(s.sales) as total_sales,
sum(s.profit) as total_profit
FROM orders o
INNER JOIN  sales s ON o.order_id = s.order_id
GROUP BY o.order_id,o.order_date_clean,o.customer_id,o.city,o.state
HAVING sum(s.sales) > 1000 AND sum(s.profit) <0
ORDER BY total_sales desc;

-- 12 Find the top 5 products by total profit.
SELECT p.product_id,p.category,p.product_name,
sum(s.profit) as total_profit
FROM products p
INNER JOIN  sales s ON p.product_id = s.product_id
group by p.product_id,p.category,p.product_name
order by total_profit desc
limit 5;

-- 13 Identify the least profitable product category in each region. 
SELECT o.region,p.category,
SUM(s.profit) AS total_profit,
RANK() OVER (PARTITION BY o.region ORDER BY SUM(s.profit)) AS rnk
FROM products p
LEFT JOIN sales s ON p.product_id = s.product_id
LEFT JOIN orders o ON s.order_id = o.order_id
GROUP BY o.region, p.category
ORDER BY o.region, rnk;

-- 14 Show the average discount per sub_category.  
SELECT p.sub_category,
round(avg(s.discount),2) as avg_discount
from products p
inner join sales s on p.product_id = s.product_id
group by p.sub_category;

-- 15 Find products that were sold in all regions
SELECT p.product_id,p.product_name,
count(distinct o.region) as Region
from products p
inner join sales s on p.product_id = s.product_id
inner join orders o on o.order_id = s.order_id
group by p.product_id,p.product_name
having count(distinct o.region) = 4
order by p.product_name;

-- 16 Find the most frequently ordered product in each category. 
SELECT  year(o.order_date_clean) as order_year,
p.category,p.product_name,
COUNT(s.order_id) AS order_count,
dense_rank() OVER (PARTITION BY year(o.order_date_clean),p.category ORDER BY COUNT(s.order_id) DESC) AS rnk
FROM products p
INNER JOIN sales s ON p.product_id = s.product_id
INNER JOIN orders o ON s.order_id = o.order_id
GROUP BY year(o.order_date_clean),p.category, p.product_name
ORDER BY order_year,p.category, rnk;

-- 17 Calculate the profit margin (profit/sales) for each product. 
SELECT p.product_name,p.product_id,
sum(s.sales ) as total_sales,
sum(s.profit) as total_profit,
round(sum(profit)/sum(sales),2) as total_margin
from products p
INNER JOIN sales s
on p.product_id = s.product_id
group by p.product_name,p.product_id
order by total_margin desc;

-- 18 Find the top 3 orders with the highest total sales value. 
SELECT o.order_id,
sum(s.sales) as total_sales
from orders o 
inner join sales s 
on o.order_id = s.order_id
group by o.order_id
order by total_sales desc
limit 3;
 
 
 -- 19 Identify orders where discount > 0.5 and check their profitability.
 SELECT o.order_id ,
 sum(s.sales) as total_sales,
 sum(s.profit) as total_profit,
 round(sum(s.sales)/sum(s.profit),2) as total_margin
 from orders o 
 inner join sales s 
 on o.order_id = s.order_id 
 group by o.order_id 
 order by total_profit desc;

-- 20 Find the largest order (by sales) for each customer. 
SELECT sub.customer_id,sub.customer_name,
max(sub.total_sales) as largest_order_sales
from 
(select c.customer_id,c.customer_name,o.order_id,
sum(s.sales) as total_sales
from customers c
inner join orders o 
on c.customer_id = o.customer_id
inner join sales s 
on o.order_id = s.order_id
group by c.customer_id,c.customer_name,o.order_id
) sub
group by sub.customer_id,sub.customer_name
order by largest_order_sales;


-- 21 Rank products by total profit within each category. 
select p.category,p.product_id,
sum(s.profit) as total_profit,
rank() over (partition by p.category order by sum(s.profit) desc) as rank_profit
from products p
inner join sales s 
on p.product_id = s.product_id
group by p.category,p.product_id
order by p.category,rank_profit;

-- 22 Find the top product per category using RANK(). 
select category,product_id,product_name,total_profit
from
( select p.category,p.product_name,p.product_id,
sum(s.profit) as total_profit,
rank() over (partition by p.category order by sum(s.profit) desc) as rnk
from products p
inner join sales s
on p.product_id = s.product_id
group by p.category,p.product_id,p.product_name
) sub
where rnk = 1
order by category; 

-- 23 Show the YoY growth rate of sales for each category. 
SELECT p.category,
YEAR(o.order_date_clean) AS order_year,
SUM(s.sales) AS total_sales,
LAG(SUM(s.sales)) OVER (PARTITION BY p.category ORDER BY YEAR(o.order_date_clean)) AS prev_year_sales,
ROUND((SUM(s.sales) - LAG(SUM(s.sales)) OVER (PARTITION BY p.category ORDER BY YEAR(o.order_date_clean)
)) / LAG(SUM(s.sales)) OVER (PARTITION BY p.category ORDER BY YEAR(o.order_date_clean)) * 100, 2) AS yoy_growth_rate
FROM products p
JOIN sales s ON p.product_id = s.product_id
JOIN orders o ON s.order_id = o.order_id
GROUP BY p.category, YEAR(o.order_date_clean)
ORDER BY p.category, order_year;

-- 24 Identify the first order placed by each customer (using MIN + window function).
SELECT c.customer_id,c.customer_name,
MIN(o.order_date_clean) AS first_order_date
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.customer_name
ORDER BY first_order_date;


-- 25 Find the top 3 customers per region by profit contribution.
SELECT region,customer_id,customer_name,total_profit,rnk
FROM (
SELECT o.region,c.customer_id,c.customer_name,
SUM(s.profit) AS total_profit,
RANK() OVER (PARTITION BY o.region ORDER BY SUM(s.profit) DESC) AS rnk
FROM customers c 
INNER JOIN orders o ON c.customer_id = o.customer_id 
INNER JOIN sales s ON o.order_id = s.order_id 
GROUP BY o.region, c.customer_id, c.customer_name
) ranked
WHERE rnk <= 3
ORDER BY region, rnk;
