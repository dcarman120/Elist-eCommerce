--Level 1
--1. What is the date of the earliest and latest order that happened for orders purchased in AUD that were less than $50?
  --MIN and MAX purchase_ts from orders tables
--2. What is the average order value for purchases made in USD? What about average order value made for USD in 2019?
  --AVG of usd_price from orders table, filtering to WHERE currency = USD
--3. Return the id, loyalty program status, and account creation date for customers who made an account on desktop or mobile. Rename the columns to more descriptive names
  --SELECT id, loyalty program status, creation date FROM customers WHERE account_made = desktop OR account_made = mobile.
--4. What are all the unique products taht were sold in AUD on mobile, sorted alphabetically?
  --SELECT DISTINCT product name FROM orders WHERE CURRENCY = AUD AND purchase_platform = mobile ORDER BY product_name
--5. What are the first 10 countries in the North American region, sorted in descending alphabetical order 
  --SELECT * FROM region WHERE country = North America LIMIT 10 ORDER BY country name DESC


SELECT min(purchase_ts) AS earliest_purchase,
    max(purchase_ts) AS latest_purchase
FROM core.orders
WHERE currency = 'AUD' AND usd_price > 50;

SELECT round(AVG(usd_price),2) AS avg_usd_order --round function, 2 stands for 2 decimal places
from core.orders
WHERE currency = 'USD'
AND EXTRACT(year from purchase_ts) = 2019;
--can also do 'AND purchase_ts >= '2019-01-01' AND purchase_ts <= '2019-12-31 11:59:59' 

SELECT id as customer_id,
    loyalty_program as customer_loyalty_status,
    created_on as customer_account_created_date
FROM core.customers
WHERE account_creation_method = 'desktop' OR account_creation_method = 'mobile';

SELECT DISTINCT product_name, purchase_platform
FROM core.orders
WHERE currency = 'AUD'
AND purchase_platform LIKE 'mobile%'
ORDER BY 1 ASC;

SELECT country
FROM core.geo_lookup
WHERE region = 'NA'
ORDER BY 1 DESC
LIMIT 10;

--Level 2
--1. What is the total number of orders by shipping month, sorted from most recent to oldest?
--2. What is the average order value by year? Can you round the results to 2 decimals?
--3. Create a helper column is_refund in the order_status table that returns 1 if there is a refund, 0 if not. Return first 20 records
--4. Return the product IDs and product names of all Apple products.
--5. Calculate the time to ship in days for each order and return all original columns from the table.

--1
select date_trunc(ship_ts, month) as month,
  count(distinct order_id) as order_count
from core.order_status
group by 1
order by 1 desc;

--2
select extract(year from purchase_ts) as year, 
  round(avg(usd_price),2) as aov
from core.orders
group by 1
order by 1;

--3
select *, 
  case when refund_ts is not null then 1 else 0 end as is_refund
from core.order_status
limit 20;

--4 
select distinct product_id,
  product_name
from core.orders
where product_name like '%Apple%'
or product_name = 'Macbook Air Laptop';
--where product_name in ('Apple Airpods Headphones','Apple iPhone','Macbook Air Laptop')

--5
select *, 
  date_diff(ship_ts,purchase_ts, day) as days_to_ship
from core.order_status;

--Level 3 - Advanced 

--1. What is the refund rate per **brand,** rounded to 3 decimals and ordered by highest refund rate to lowest? ****Make sure your calculations for brand are case insensitive.

--2. Which customer has the most refunds in 2020? 

--3. Return all customers with 2 refunds in 2020 by using a CTE. Then return all customers with 2 refunds using `qualify` .


--1
select case when lower(product_name) like 'apple%' or lower(product_name) = 'macbook air laptop' then 'Apple'
  when lower(product_name) like '%thinkpad%' then 'ThinkPad'
  when lower(product_name) like '%samsung%' then 'Samsung'
  when lower(product_name) like '%bose%' then 'Bose'
  else 'unknown' end as brand,
  round(avg(case when refund_ts is not null then 1 else 0 end),3) as refund_rate
from core.orders
left join core.order_status
on orders.id = order_status.order_id
group by 1
order by 2 desc;

--2
select customers.id,
  row_number() over (partition by customers.id order by refund_ts asc) as refund_count
from core.customers
left join core.orders 
	on customers.id = orders.customer_id
left join core.order_status
	on orders.id = order_status.order_id
where extract(year from refund_ts) = 2020
order by 2 desc;

--3
--using CTE
with refund_count_cte as (
  select customers.id,
    row_number() over (partition by customers.id order by refund_ts asc) as refund_count
  from core.customers
  left join core.orders 
  on customers.id = orders.customer_id
  left join core.order_status
  on orders.id = order_status.order_id
  where extract(year from refund_ts) = 2021
  order by 2 desc
)

select * from refund_count_cte where refund_count = 2;

--using qualify
select customers.id,
  row_number() over (partition by customers.id order by refund_ts asc) as refund_count
from core.customers
left join core.orders 
on customers.id = orders.customer_id
left join core.order_status
on orders.id = order_status.order_id
where extract(year from refund_ts) = 2021
qualify (refund_count = 2)
order by 2 desc;

