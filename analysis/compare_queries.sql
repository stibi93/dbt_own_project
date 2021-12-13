{% set old_etl_relation=ref('customer_orders') %}
{% set dbt_relation=ref('fct_customer_orders') %}

{{ audit_helper.compare_queries(
    a_query=old_etl_relation,
    b_query=dbt_relation,
    primary_key="order_id"
) }}
