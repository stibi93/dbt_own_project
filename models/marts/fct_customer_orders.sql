-- Import CTEs
with orders as (

    select * from {{ ref('stg_jaffle_shop__orders') }}

),

customers as (

    select * from {{ ref('stg_jaffle_shop__customers') }}
),

payments as (

    select * from {{ ref('stg_stripe__payments') }}
),

-- Logical CTEs

completed_payments as (

  select 
    order_id,
    max(payment_created_at) as payment_finalized_date,
    sum(payment_amount) as total_amount_paid
  from payments
  where payment_status <> 'fail'
  group by 1

),

paid_orders as (
    select 
        orders.order_id,
        orders.customer_id,
        orders.order_placed_at,
        orders.order_status,

        completed_payments.total_amount_paid,
        completed_payments.payment_finalized_date,

        customers.customer_first_name,
        customers.customer_last_name
    FROM orders
    left join completed_payments ON orders.order_id = completed_payments.order_id
    left join customers on orders.customer_id = customers.customer_id

),

customer_orders as (
    select 
        customers.customer_id
        , min(order_placed_at) as first_order_date
        , max(order_placed_at) as most_recent_order_date
        , count(orders.order_id) AS number_of_orders
    from customers
    left join orders as orders
    on orders.customer_id = customers.customer_id
    group by 1
),

-- Final CTE
final as (

  select
    paid_orders.order_id,
    paid_orders.customer_id,
    paid_orders.order_placed_at,
    paid_orders.order_status,
    paid_orders.total_amount_paid,
    paid_orders.payment_finalized_date,
    customers.customer_first_name,
    customers.customer_last_name,

    -- sales transaction sequence
    row_number() over (order by paid_orders.order_id) as transaction_seq,

    -- customer sales sequence
    row_number() over (partition by paid_orders.customer_id order by paid_orders.order_id) as customer_sales_seq,

    -- new vs returning customer
    case 
      when (
      rank() over (
        partition by paid_orders.customer_id
        order by paid_orders.order_placed_at, paid_orders.order_id
        ) = 1
      ) then 'new'
    else 'return' end as nvsr,

    -- customer lifetime value
    sum(paid_orders.total_amount_paid) over (
      partition by paid_orders.customer_id
      order by paid_orders.order_placed_at
      ) as customer_lifetime_value,

    -- first day of sale
    first_value(order_placed_at) over (
      partition by paid_orders.customer_id
      order by paid_orders.order_placed_at
      ) as fdos
    from paid_orders
    left join customers on paid_orders.customer_id = customers.customer_id
)

-- Simple Select Statment

select * from final
order by customer_id, customer_sales_seq

