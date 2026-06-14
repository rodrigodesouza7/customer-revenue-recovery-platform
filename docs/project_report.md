# Customer Revenue Recovery Platform

## Objective

Develop a PostgreSQL-based analytics platform capable of monitoring customer subscriptions, tracking payments, identifying churn risks, and recovering lost revenue through payment monitoring and auditing.

## Technologies

- PostgreSQL
- DBeaver
- VS Code
- Git
- GitHub

## Database Structure

Schemas:

- core
- analytics
- audit

Main tables:

- customers
- plans
- subscriptions
- payments
- support_tickets
- usage_events

## Analytics Layer

Views implemented:

- vw_customer_revenue
- vw_customer_health
- vw_revenue_recovery
- vw_recovered_payments

## Audit Layer

A trigger-based auditing mechanism records payment status changes automatically.

## Business Value

The platform helps identify revenue loss, customer health status, subscription issues, and recovered payments, providing actionable insights for SaaS operations.
