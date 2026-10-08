-- REVENUE RECONCILIATION & EXCEPTION ANALYTICS

-- Project Purpose:
-- Analyze order-level revenue by comparing the expected
-- order amount with the actual amount paid by customers.

-- Data Source:
-- Cleaned and transformed Olist e-commerce data
create database revenue_reconciliation;
use  revenue_reconciliation; 

# Plz cheak total row first
SELECT COUNT(*) AS total_rows
FROM reconciliation;

# Unique order_id
select count(distinct order_id)as unique_order 
from reconciliation;

# cheak any duplicate order
SELECT COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_orders
FROM reconciliation;

# How many orders have a missing expected_total and how many have a missing paid_total?
SELECT
    COUNT(*) AS total_orders,
    SUM(expected_total IS NULL) AS missing_expected_total,
    SUM(paid_total IS NULL) AS missing_paid_total
FROM reconciliation;

# How many orders have both expected_total and paid_total available
select COUNT(*) AS reconciliable_orders
from reconciliation
where expected_total is not null
  and paid_total is not null;

# For each reconciliable order, what is the difference between the amount paid and the expected amount
select order_id,(paid_total-expected_total) as diffrence_between_paid_and_expected
 from reconciliation;
 
# Find the max diffrence betwee both of the 
select order_id,paid_total,expected_total,paid_total-expected_total as Max_diffrence 
from reconciliation
where paid_total is not null and expected_total is not null 
order by diffrence desc limit 1;

# find the min diffrence between both of the 
select order_id,paid_total,expected_total,paid_total-expected_total as diffrence
from reconciliation
where paid_total is not null and expected_total is not null
order by diffrence limit 1;

# plz cheak how much Overpaid,Underpaid,Matched
select reconciliation_status,COUNT(*) AS total_orders
from (
    select
	case when paid_total is null or expected_total is null
			then 'Not Analyzable'
		 when paid_total > expected_total
			then 'Overpaid'
		when paid_total < expected_total
			then 'Underpaid'
		else 'Matched'
	end as reconciliation_status
from reconciliation
) as r
group by reconciliation_status;

# How much money is involved in the overpaid orders
select  SUM(paid_total - expected_total) as total_overpayment
from reconciliation
where paid_total > expected_total
  and paid_total is not null
  and expected_total is not null;
  
  #  How much money is involved in the overpaid orders
  select SUM(paid_total - expected_total) as total_overpayment
from reconciliation
where paid_total < expected_total
  and paid_total is not null
  and expected_total is not null;

# Net Revenue Discrepancy Analysis 
select
    sum(paid_total - expected_total) as net_discrepancy
from reconciliation
where paid_total is not null
  and expected_total is not null;
  
  # Which customers have generated the highest total revenue?
  select customer_id,sum(paid_total) as total_paid from reconciliation
  group by customer_id
  order by total_paid desc limit 1;
  
# Which products generate the highest revenue
select product_id, sum(price) as total_revenue
from order_items
group by product_id
order by total_revenue desc
limit 1;

# which payment type is the highest_payment_vlaue
select payment_type,COUNT(*) AS total_payments,SUM(payment_value) AS total_payment_value
from payments
group  by payment_type
order by total_payment_value DESC;

# Which order status has the highest number of orders and total revenue?
select order_status,count(*) as total_orders,sum(paid_total) as total_paid,sum(expected_total) as total_expected
from reconciliation
where paid_total is not null
  and expected_total is not null
group by order_status
order by total_orders desc;

# 10. Top 10 Products by Revenue
select product_id,sum(price) as total_revenue
from order_items
group by product_id
order by total_revenue desc
limit 10;


# -- top 10 sellers by revenue
select
    seller_id,
    sum(price) as total_revenue
from order_items
group by seller_id
order by total_revenue desc
limit 10;