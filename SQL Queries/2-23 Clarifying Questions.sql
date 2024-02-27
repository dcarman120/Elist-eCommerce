--1. Write a query to find the most popular product in North America that isn’t a Samsung product. 
--Can I assume that “most popular” is determined by order count? Yes
--I will output the `product_name` and `order_count` of the top product, does that work? Yes
--Can I assume that all Samsung products include “Samsung” in the name? Yes
--What is the capitalization / case of the product column? Proper capitalization

select orders.product_name, 
  count(distinct orders.id) as order_count
from core.orders
left join core.customers
  on orders.customer_id = customers.id
left join core.geo_lookup
  on geo_lookup.country = customers.country_code
where region = 'NA'
  and product_name not like '%Samsung%'
group by 1
order by 2 desc
limit 1;

--2. For each region, who are the top 2 customers who purchased a product with an ID that either starts with ****`0` , ends with `c`, or contains an `a`? If there is a tie, return all tied customers.
--Can I assume we define “top” by total sales? Yes
--I will return the region , customer_id , and total_sales, and customer_rank, does that work? Yes
select region, 
  customers.id, 
  sum(usd_price) as total_sales,
  dense_rank() over (partition by region order by sum(usd_price) desc) as customer_rank
from core.customers
left join core.geo_lookup
  on customers.country_code = geo_lookup.country
left join core.orders
  on orders.customer_id = customers.id
where orders.product_id like any ('0%', '%c', '%a%')
group by 1,2
qualify dense_rank() over (partition by region order by sum(usd_price) desc) <= 2;

--3. Calculate the average delivery time for orders in each country, excluding any orders that had refunds.
--Can I assume that if an order didn’t have a refund, the `refund_ts` is null? Yes
--Confirming I should return average delivery time in days? Yes

select country, 
  avg(date_diff(delivery_ts, orders.purchase_ts, day)) as avg_delivery_days
from core.orders
left join core.customers
  on orders.customer_id = customers.id
left join core.geo_lookup
  on geo_lookup.country = customers.country_code
left join core.order_status
  on order_status.order_id = orders.id
where refund_ts is null
group by 1
order by 1;

--4. For each region, return the average order value of the first quarter in the calendar year. If the region is missing, assume the purchase is in North America.
--Just to confirm, is average order value equal to the average of the `usd_price` column? Yes
--Can I assume that North America is expressed as “NA” in the `region` column? Yes

select case when region is null then 'NA' 
        else region end as region, 
    round(avg(usd_price),2) as aov
from core.orders
left join core.customers
  on orders.customer_id = customers.id
left join core.geo_lookup
  on geo_lookup.country = customers.country_code
where extract(quarter from purchase_ts) = 1
group by 1;

--solution using coalesce instead of case when
select coalesce(region, 'NA') as region,
    round(avg(usd_price),2) as aov
from core.orders
left join core.customers
  on orders.customer_id = customers.id
left join core.geo_lookup
  on geo_lookup.country = customers.country_code
where extract(quarter from purchase_ts) = 1
group by 1;

--5. For customers who have had 5 purchases, return the time between the 1st purchase and the 5th purchase in months. 
-- I’ll output the `customer_id` and months between the 1st and 5th purchase, does that work? Also include the 1st purchase date and the 5th purchase date
-- Do you mind if I use the `using` function instead of the explicit join statement? That works

with first_purchase as (
  select distinct customer_id, 
    purchase_ts as first_purchase_date
  from core.orders
  qualify row_number() over (partition by customer_id order by purchase_ts) = 1),

 fifth_purchase as (
  select distinct customer_id, 
    purchase_ts as fifth_purchase_date
  from core.orders
  qualify row_number() over (partition by customer_id order by purchase_ts) = 5)

select *, 
  date_diff(fifth_purchase_date,first_purchase_date, month) as first_to_fifth_purchase_months
from first_purchase
left join fifth_purchase
	on first_purchase.customer_id = fifth_purchase.customer_id
	and first_purchase.order_id = fifth_purchase.order_id
  using (customer_id, order_id)
where fifth_purchase_date is not null;

--6. What was the retention rate from 2021 to 2022, returned as a percent in X.XXXX% format? Retention rate is the percent of customers who placed an order in the first year who also placed an order in the second year.
-- Just want to confirm, you only want to return the rate itself? Yes
-- Am I correct in assuming that customers can purchase multiple times in a year? Yes (this indicates you should use distinct)

with customers_2021 as (
  select distinct customer_id as id_2021
  from core.orders
  where extract(year from purchase_ts) = 2021),

customers_2022 as (
  select distinct customer_id as id_2022
  from core.orders
  where extract(year from purchase_ts) = 2022
)

select round(avg(case when id_2022 is not null then 1 else 0 end)*100,4) as retention_rate
from customers_2021
left join customers_2022 
  on customers_2021.id_2021 = customers_2022.id_2022


--7. For customers who purchased more than 4 orders across all years, what was the order ID, product, and purchase date of their most recent order?

with over_4_purchases as (
  select customer_id, 
		count(id)
  from core.orders
  group by 1
  having (count(id)) >= 4)

select orders.customer_id, 
  orders.id, 
  orders.product_name, 
  orders.purchase_ts,
  row_number() over (partition by orders.customer_id order by orders.purchase_ts desc) as order_ranking
from core.orders
inner join over_4_purchases 
  on over_4_purchases.customer_id = orders.customer_id
qualify row_number() over (partition by customer_id order by purchase_ts desc) = 1






