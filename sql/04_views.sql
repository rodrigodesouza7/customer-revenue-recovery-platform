-- ============================================================
-- 04_views.sql
-- Customer Revenue Recovery Platform
-- Analytics views
-- ============================================================

-- ------------------------------------------------------------
-- vw_customer_revenue
-- MRR atual e receita total paga por cliente
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW analytics.vw_customer_revenue AS
WITH active_subscription AS (
    SELECT
        s.customer_id,
        s.subscription_id,
        s.status AS subscription_status,
        p.plan_name,
        p.billing_cycle,
        CASE
            WHEN p.billing_cycle = 'annual' THEN ROUND(p.price / 12, 2)
            ELSE p.price
        END AS mrr
    FROM core.subscriptions s
    JOIN core.plans p ON p.plan_id = s.plan_id
    WHERE s.status IN ('active', 'past_due')
),
total_paid AS (
    SELECT
        s.customer_id,
        SUM(pay.amount) AS total_revenue_paid
    FROM core.payments pay
    JOIN core.subscriptions s ON s.subscription_id = pay.subscription_id
    WHERE pay.status = 'paid'
    GROUP BY s.customer_id
)
SELECT
    c.customer_id,
    c.name AS customer_name,
    c.segment,
    c.country,
    c.status AS customer_status,
    a.subscription_status,
    a.plan_name,
    a.billing_cycle,
    COALESCE(a.mrr, 0) AS mrr,
    COALESCE(t.total_revenue_paid, 0) AS total_revenue_paid
FROM core.customers c
LEFT JOIN active_subscription a ON a.customer_id = c.customer_id
LEFT JOIN total_paid t ON t.customer_id = c.customer_id;


-- ------------------------------------------------------------
-- vw_customer_health
-- Health Score (0-100): uso (40%) + pagamentos (40%) + tickets (20%)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW analytics.vw_customer_health AS
WITH usage_score AS (
    SELECT
        c.customer_id,
        COUNT(ue.event_id) AS events_last_30_days,
        LEAST(COUNT(ue.event_id) * 2, 100) AS usage_points  -- até 50 eventos = 100 pts, cap em 100
    FROM core.customers c
    LEFT JOIN core.usage_events ue
        ON ue.customer_id = c.customer_id
        AND ue.event_date >= now() - INTERVAL '30 days'
    GROUP BY c.customer_id
),
payment_score AS (
    SELECT
        c.customer_id,
        COUNT(pay.payment_id) AS total_payments,
        COUNT(pay.payment_id) FILTER (WHERE pay.status IN ('late', 'failed', 'pending')) AS problem_payments,
        CASE
            WHEN COUNT(pay.payment_id) = 0 THEN 100
            ELSE ROUND(
                100.0 * COUNT(pay.payment_id) FILTER (WHERE pay.status = 'paid')
                / COUNT(pay.payment_id)
            )
        END AS payment_points
    FROM core.customers c
    LEFT JOIN core.subscriptions s ON s.customer_id = c.customer_id
    LEFT JOIN core.payments pay ON pay.subscription_id = s.subscription_id
    GROUP BY c.customer_id
),
ticket_score AS (
    SELECT
        c.customer_id,
        COUNT(t.ticket_id) FILTER (WHERE t.status IN ('open', 'in_progress')) AS open_tickets,
        AVG(t.resolution_time_hours) AS avg_resolution_hours,
        CASE
            WHEN COUNT(t.ticket_id) FILTER (WHERE t.status IN ('open', 'in_progress')) = 0
                 AND COALESCE(AVG(t.resolution_time_hours), 0) <= 24 THEN 100
            WHEN COUNT(t.ticket_id) FILTER (WHERE t.status IN ('open', 'in_progress')) = 0
                 AND AVG(t.resolution_time_hours) <= 48 THEN 80
            WHEN COUNT(t.ticket_id) FILTER (WHERE t.status IN ('open', 'in_progress')) <= 1 THEN 60
            WHEN COUNT(t.ticket_id) FILTER (WHERE t.status IN ('open', 'in_progress')) <= 2 THEN 40
            ELSE 20
        END AS ticket_points
    FROM core.customers c
    LEFT JOIN core.support_tickets t ON t.customer_id = c.customer_id
    GROUP BY c.customer_id
)
SELECT
    c.customer_id,
    c.name AS customer_name,
    c.status AS customer_status,
    u.events_last_30_days,
    u.usage_points,
    p.payment_points,
    p.problem_payments,
    tk.open_tickets,
    tk.avg_resolution_hours,
    tk.ticket_points,
    ROUND(
        (u.usage_points * 0.40)
        + (p.payment_points * 0.40)
        + (tk.ticket_points * 0.20)
    ) AS health_score,
    CASE
        WHEN ROUND(
            (u.usage_points * 0.40)
            + (p.payment_points * 0.40)
            + (tk.ticket_points * 0.20)
        ) >= 75 THEN 'healthy'
        WHEN ROUND(
            (u.usage_points * 0.40)
            + (p.payment_points * 0.40)
            + (tk.ticket_points * 0.20)
        ) >= 50 THEN 'at_risk'
        ELSE 'critical'
    END AS health_status
FROM core.customers c
JOIN usage_score u ON u.customer_id = c.customer_id
JOIN payment_score p ON p.customer_id = c.customer_id
JOIN ticket_score tk ON tk.customer_id = c.customer_id;


-- ------------------------------------------------------------
-- vw_revenue_recovery
-- Receita em risco por cliente (late, failed, pending)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW analytics.vw_revenue_recovery AS
SELECT
    c.customer_id,
    c.name AS customer_name,
    c.segment,
    s.status AS subscription_status,
    COUNT(pay.payment_id) FILTER (WHERE pay.status = 'late') AS late_payments,
    COUNT(pay.payment_id) FILTER (WHERE pay.status = 'failed') AS failed_payments,
    COUNT(pay.payment_id) FILTER (WHERE pay.status = 'pending') AS pending_payments,
    COALESCE(SUM(pay.amount) FILTER (WHERE pay.status IN ('late', 'failed', 'pending')), 0) AS revenue_at_risk
FROM core.customers c
JOIN core.subscriptions s ON s.customer_id = c.customer_id
JOIN core.payments pay ON pay.subscription_id = s.subscription_id
GROUP BY c.customer_id, c.name, c.segment, s.status
HAVING COALESCE(SUM(pay.amount) FILTER (WHERE pay.status IN ('late', 'failed', 'pending')), 0) > 0
ORDER BY revenue_at_risk DESC;


-- ------------------------------------------------------------
-- vw_recovered_payments
-- Pagamentos que estavam late/failed e foram revertidos para paid
-- (baseado no audit.payment_audit_log)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW analytics.vw_recovered_payments AS
SELECT
    c.customer_id,
    c.name AS customer_name,
    pay.payment_id,
    al.old_status,
    al.new_status,
    pay.amount,
    al.changed_at AS recovered_at
FROM audit.payment_audit_log al
JOIN core.payments pay ON pay.payment_id = al.payment_id
JOIN core.subscriptions s ON s.subscription_id = pay.subscription_id
JOIN core.customers c ON c.customer_id = s.customer_id
WHERE al.old_status IN ('late', 'failed', 'pending')
  AND al.new_status = 'paid'
ORDER BY al.changed_at DESC;