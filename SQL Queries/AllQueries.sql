--1. What is the date of the earliest and latest return that happened for orders purchased in AUD that were less than $50?

--2. What is the average order value for Apple products? Solve this question using an IN  statement, and then solve it using at least one LIKE  statement. Make sure to round your results.

--3. Of people who created an account in 2022 and created an account through mobile or desktop, how many people are in the loyalty program?

--4. How many people created an account on each account creation method in 2021? Rank by most popular method to least popular.

--5. For orders purchased in 2020-2021, add a column to the order status table that calculates the days to ship, and order the table by orders that took the longest to the shortest. 

select min(refund_ts) as earliest_return,
  max(refund_ts) as latest_return
from core.orders
where currency = 'AUD' AND usd_price < 50;

select distinct product_name 
from core.orders order by 1;

SELECT AVG(usd_price, 2) AS average_apple
FROM core.orders
WHERE product_name LIKE 'Apple %'; --add OR for 'Macbook Air Laptop', an apple product without 'Apple' in the name
SELECT AVG(usd_price, 2) AS average_apple 
FROM core.orders
WHERE product_name IN ('Apple Airpods Headphones', 'Apple iPhone','Macbook Air Laptop'); --IN is specific, so all exact apple product names should be in this field

SELECT SUM(loyalty_program) AS loyalty_count 
FROM core.orders
WHERE EXTRACT(year FROM created_on) = 2022 AND account_creation_method = 'mobile' OR account_creation_method = 'desktop'; --EXTRACT() function extracts a part from a given date

select account_creation_method, 
  count(distinct id) as signup_count
from core.customers
where extract(year from created_on) = 2021
group by 1
order by 2 desc;

select *, 
  date_diff(ship_ts, purchase_ts, day) as time_to_ship
from core.order_status
where purchase_ts >= '2020-01-01' 
	and purchase_ts <= '2021-12-31'
order by time_to_ship desc;

--Level 2
--1. Of people who created an account in 2022 and signed up through tablet, what is the percent of people who are in the loyalty program, rounded to two places? (Hint: remember how we calculated refund rate)

--2. For laptops or Apple products, what is the most popular purchase platform?

--3. How many customers signed up per region in the first quarter of 2022, ordered by most popular to least popular?

--4. What is the average time to ship for orders placed in euros?

--5. Tricky one: How many customers either came through an email marketing channel and created an account on mobile or came through an affiliate marketing campaign and created an account on desktop?

select round(avg(loyalty_program),2) as loyalty_program_perc
from core.customers
where extract(year from created_on) = 2022
and account_creation_method = 'tablet';

select distinct product_name --look at all product names to find all laptops
from core.orders order by 1;

select purchase_platform,
  count(distinct id) as order_count
from core.orders 
where product_name like '%Laptop'
	or product_name like 'Apple%'
group by 1
order by 2 desc;

select region, 
  count(distinct customers.id) as customer_count
from core.customers 
left join core.geo_lookup
on customers.country_code = geo_lookup.country
where created_on between '2022-01-01' and '2022-03-31'
group by 1
order by 2 desc;

select round(avg(date_diff(order_status.ship_ts, order_status.purchase_ts, day)),2) as avg_days_to_ship
from core.order_status
left join core.orders
on order_status.order_id = orders.id
where currency = 'EUR';

select count (distinct id) as customer_count
from core.customers
where (marketing_channel = 'email' and account_creation_method = 'mobile')
	or (marketing_channel = 'affiliate' and account_creation_method = 'desktop');

--Level 3
--1. What is the refund rate per brand, rounded to 3 decimals and ordered by highest refund rate to lowest? Make sure your calculations for brand are case insensitive.
--2. Which customers has the most refunds in 2020? 
--Are there certain products that are getting refunded more frequently than others?
--orders and order status tables (probable join)
--case when refund_ts to get 1 or 0, calculate avg of this column
--3. Bonus - return all customers with 2 refunds in 2020 by using a CTE. Then return all customers with 2 refunds using qualify .

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

select customers.id,
  row_number() over (partition by customers.id order by refund_ts asc) as refund_count --row number counts for every customer, if they have a refund_ts, increment the counter for that ts
from core.customers
left join core.orders 
	on customers.id = orders.customer_id
left join core.order_status
	on orders.id = order_status.order_id
where extract(year from refund_ts) = 2020
qualify row_number() over (partition by customers.id order by refund_ts asc) = 2 --Qualify is equal to a having statement for row_number
order by 2 desc;

SELECT case when product_name = '27in"" 4k gaming monitor' then '27in 4k gaming monitor' else product_name end as product_c,
  sum(case when refund_ts is not null then 1 else 0 end) as refunds,
  avg(case when refund_ts is not null then 1 else 0 end) as refund_rate
FROM core.orders
left join core.order_status
ON orders.id = order_status.order_id
GROUP BY 1
ORDER BY 3 DESC;

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

------------------------------------------------------------------------------------------

--1) What are the quarterly trends for order count, sales, and AOV for Macbooks sold in North America across all years? [Multiple joins, CTE, date trunc]
--Join orders to geo lookup using customers table
--create quarters column by exracting month from each purchase_ts
--group by year
--avg of usd_price column, as well as sum of usd_price, count of orders
--where to filter macbooks to NA

WITH quarter_stats AS (
SELECT date_trunc(purchase_ts, quarter) AS quarter,
  avg(orders.usd_price),
  sum(orders.usd_price),
  count(distinct orders.id) AS order_count,
  round(sum(orders.usd_price),2) as total_sales,
	round(avg(orders.usd_price),2) as aov
FROM core.orders
LEFT JOIN core.customers
ON orders.customer_id = customers.id
LEFT JOIN core.geo_lookup
ON customers.country_code = geo_lookup.country
WHERE product_name LIKE "%Macbook%" AND geo_lookup.region = "NA" --LIKE is case-sensitive
GROUP BY 1 --groups by quarter, the first column in the SELECT statement
ORDER BY 1 DESC, 2)

select avg(order_count) as avg_orders, 
	avg(total_sales) as avg_sales, 
	avg(aov) as avg_aov
from quarter_stats;


--2) For products purchased in 2022 on the website or products purchased on mobile in any year, which region has the average highest time to deliver? [Multiple joins, and vs. or, date diff]
--Join all tables together to relate delivery timestamps to region and product
--Filter to (products purchased in 2022 and on website) or (mobile across all years)
--Calculate the time to deliver and take the average per region

select geo_lookup.region, 
  avg(date_diff(order_status.delivery_ts, order_status.purchase_ts, day)) as time_to_deliver
from core.order_status
left join core.orders
  on order_status.order_id = orders.id
left join core.customers
  on customers.id = orders.customer_id
left join core.geo_lookup
  on geo_lookup.country = customers.country_code
where (extract(year from orders.purchase_ts) = 2022
  and purchase_platform = 'website')
  or purchase_platform = 'mobile app'
group by 1
order by 2 desc;

--3) Are there certain products that are getting refunded more frequently than others? [Case when, rate calculation]
--Clean up product name using a case when 
--Calculate refund rate by product (clean up product name) to get frequency of refunds - order by refund rate
--Order by refund count instead of refund rate to get products with highest number of refunds

select case when product_name = '27in"" 4k gaming monitor' then '27in 4K gaming monitor' else product_name end as product_clean,
    sum(case when refund_ts is not null then 1 else 0 end) as refunds,
    avg(case when refund_ts is not null then 1 else 0 end) as refund_rate
from core.orders 
left join core.order_status 
    on orders.id = order_status.order_id
group by 1
order by 3 desc;

--4) Within each region, what is the most popular product? [Multiple join, multiple CTEs, row number]
--Join orders, customers, and geo_lookup to match products to regions
--Use a CTE to calculate the total number of orders per region and product
--Two ways of finding the most popular product per region shown below:
--1. Rank the results within each region by order count in a second CTE, then select the top per region
--2. Bonus: Use qualify to filter using the row_number without an extra CTE (Note: this is advanced function that hiring managers do not expect you to know - it will be very impressive if you use it in interviews!)

--option 1
with sales_by_product as (
  select region,
    product_name,
    count(distinct orders.id) as total_orders
  from core.orders
  left join core.customers
    on orders.customer_id = customers.id
  left join core.geo_lookup
    on geo_lookup.country = customers.country_code
  group by 1,2),

ranked_orders as (
  select *,
    row_number() over (partition by region order by total_orders desc) as order_ranking
  from sales_by_product
  order by 4 asc)

select *
from ranked_orders 
where order_ranking = 1;


--option 2
with sales_by_product as (
  select region,
  product_name,
  count(distinct orders.id) as total_orders
from core.orders
left join core.customers
  on orders.customer_id = customers.id
left join core.geo_lookup
  on geo_lookup.country = customers.country_code
group by 1,2)

select *, 
	row_number() over (partition by region order by total_orders desc) as order_ranking
from sales_by_product
qualify row_number() over (partition by region order by total_orders desc) = 1;


--5) Which marketing channel has the highest average signup rate for the loyalty program, and how does this compare to the channel that has the highest number of loyalty program participants? [Rate calculation]
--Calculate the signup rate by taking the average of loyalty_program
--Sum the number of loyalty signups
--Compare these columns to find highest signup rate vs. highest signup count

select marketing_channel,
  round(avg(loyalty_program),2) as loyalty_signup_rate,
  sum(loyalty_program) as loyalty_signup_count
from core.customers
group by 1
order by 2 desc;







