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



