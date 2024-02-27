--1. How many refunds were there for each month in 2021? What about each quarter and week?
select date_trunc(refund_ts, month) as month, 
	--date_trunc(refund_ts, week) as week,
	--date_trunc(refund_ts, quarter) as quarter,
  count(distinct order_id) as refunds
from core.order_status
where extract(year from refund_ts) = 2021
group by 1
order by 1;

--2. For each region, what’s the total number of customers and the total number of orders? Sort alphabetically by region.
select region, 
  count(distinct customers.id) as customer_count, 
  count(distinct orders.id) as orders_count
from core.orders
left join core.customers
	on orders.customer_id = customers.id
left join core.geo_lookup
	on geo_lookup.country = customers.country_code
group by 1
order by 1;

--3. What’s the average time to deliver for each purchase platform? 
select purchase_platform, 
  round(avg(date_diff(order_status.delivery_ts, orders.purchase_ts, day)),4) as avg_time_to_deliver
from core.orders
left join core.order_status
  on orders.id = order_status.order_id
group by 1;

--4. What were the top 2 regions for Macbook sales in 2020? 
select region, 
  round(sum(usd_price),2) as macbook_sales
from core.orders
  left join core.customers
on orders.customer_id = customers.id
  left join core.geo_lookup
on geo_lookup.country = customers.country_code
where product_name like '%Macbook%'
  and extract(year from purchase_ts) = 2020
group by 1
order by 2 desc
limit 2;

--5. For each marketing channel, what was the earliest account creation date?
select marketing_channel, 
  min(created_on) as earliest_created_on, 
from core.customers
group by 1
order by 2;


---Intermediate Take-Home


--1. For each purchase platform, return the top 3 customers by the number of purchases and order them within that platform. If there is a tie, break the tie using any order. 
with customer_product_count as (
  select purchase_platform,
    customer_id,
    count(distinct id) as num_purchases
  from core.orders
  group by 1,2)

select *, 
  row_number() over (partition by purchase_platform order by num_purchases desc) as order_ranking
from customer_product_count
qualify row_number() over (partition by purchase_platform order by num_purchases desc) <= 3;

--alternative without qualify
with customer_product_count as (
  select purchase_platform,
    customer_id,
    count(distinct id) as num_purchases
  from core.orders
  group by 1,2),

ranking_cte as (
	select *, 
	  row_number() over (partition by purchase_platform order by num_purchases desc) as order_ranking
	from customer_product_count)

select * 
from ranking_cte 
where order_ranking <= 3;

--2. What was the most-purchased brand in the APAC region?
select case when product_name like 'Apple%' or product_name like 'Macbook%' then 'Apple'
  when product_name like 'Samsung%' then 'Samsung'
  when product_name like 'ThinkPad%' then 'ThinkPad'
  when product_name like 'bose%' then 'Bose'
  else 'Unknown' end as brand, 
  count(distinct orders.id) as order_count
from core.orders
left join core.customers
	on orders.customer_id = customers.id
left join core.geo_lookup
	on geo_lookup.country = customers.country_code
where region = 'APAC'
group by 1
order by 2 desc
limit 1;

--3. Of people who bought Apple products, which 5 customers have the top average order value, ranked from highest AOV to lowest AOV?
with customer_aov as (
  select customer_id, 
		avg(usd_price) as aov
  from core.customers
  left join core.orders
	  on customers.id = orders.customer_id
  where orders.product_name like any ('%Apple%', '%Macbook%')
  group by 1)

select *, 
	row_number() over (order by aov desc) as customer_ranking
from customer_aov
qualify row_number() over (order by aov desc) <= 5

--4. For each of these top 5 customers, which products did they buy?
with customer_aov as (
  select customer_id, 
		avg(usd_price) as aov
  from core.customers
  left join core.orders
    on customers.id = orders.customer_id
	where orders.product_name like any ('%Apple%', '%Macbook%')
  group by 1), 
  
ranking as (
  select *, 
		row_number() over (order by aov desc) as customer_ranking
  from customer_aov
  qualify row_number() over (order by aov desc) <= 5)

select ranking.*, 
  product_name
from ranking
left join core.orders
  on ranking.customer_id = orders.customer_id
order by 3 asc;

--5. Within each purchase platform, what are the top two marketing channels ranked by average order value?
with marketing_sales as (
  select purchase_platform, 
    marketing_channel, 
    round(avg(usd_price),2) as aov
from core.orders
left join core.customers
  on orders.customer_id = customers.id
group by 1,2)

select *, 
  row_number() over (partition by purchase_platform order by aov desc) as ranking
from marketing_sales
qualify row_number() over (partition by purchase_platform order by aov desc) <= 2
order by 1;




