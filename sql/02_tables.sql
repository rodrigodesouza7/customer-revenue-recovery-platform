-- ============================================================
-- 02_tables.sql
-- Customer Revenue Recovery Platform
-- Core schema tables + Audit log table
-- ============================================================

-- ------------------------------------------------------------
-- core.customers
-- ------------------------------------------------------------
CREATE TABLE core.customers (
    customer_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            VARCHAR(150) NOT NULL,
    email           VARCHAR(150) NOT NULL UNIQUE,
    segment         VARCHAR(50),
    country         VARCHAR(60),
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive')),
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- core.plans
-- ------------------------------------------------------------
CREATE TABLE core.plans (
    plan_id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    plan_name       VARCHAR(100) NOT NULL,
    billing_cycle   VARCHAR(20) NOT NULL
        CHECK (billing_cycle IN ('monthly', 'annual')),
    price           NUMERIC(10,2) NOT NULL
        CHECK (price >= 0),
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- core.subscriptions
-- ------------------------------------------------------------
CREATE TABLE core.subscriptions (
    subscription_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id     BIGINT NOT NULL
        REFERENCES core.customers (customer_id) ON DELETE CASCADE,
    plan_id         BIGINT NOT NULL
        REFERENCES core.plans (plan_id) ON DELETE RESTRICT,
    start_date      DATE NOT NULL,
    end_date        DATE,
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'canceled', 'past_due')),
    canceled_at     TIMESTAMP,
    created_at      TIMESTAMP NOT NULL DEFAULT now(),
    updated_at      TIMESTAMP NOT NULL DEFAULT now(),

    CHECK (end_date IS NULL OR end_date >= start_date)
);

-- ------------------------------------------------------------
-- core.payments
-- ------------------------------------------------------------
CREATE TABLE core.payments (
    payment_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    subscription_id BIGINT NOT NULL
        REFERENCES core.subscriptions (subscription_id) ON DELETE CASCADE,
    amount          NUMERIC(10,2) NOT NULL
        CHECK (amount >= 0),
    due_date        DATE NOT NULL,
    payment_date    DATE,
    status          VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('paid', 'late', 'failed', 'pending')),
    created_at      TIMESTAMP NOT NULL DEFAULT now(),
    updated_at      TIMESTAMP NOT NULL DEFAULT now(),

    CHECK (payment_date IS NULL OR payment_date >= due_date - INTERVAL '90 days')
);

-- ------------------------------------------------------------
-- core.support_tickets
-- ------------------------------------------------------------
CREATE TABLE core.support_tickets (
    ticket_id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id         BIGINT NOT NULL
        REFERENCES core.customers (customer_id) ON DELETE CASCADE,
    opened_at           TIMESTAMP NOT NULL DEFAULT now(),
    closed_at           TIMESTAMP,
    status              VARCHAR(20) NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'in_progress', 'closed')),
    resolution_time_hours NUMERIC(10,2)
        CHECK (resolution_time_hours IS NULL OR resolution_time_hours >= 0),

    CHECK (closed_at IS NULL OR closed_at >= opened_at)
);

-- ------------------------------------------------------------
-- core.usage_events
-- ------------------------------------------------------------
CREATE TABLE core.usage_events (
    event_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id     BIGINT NOT NULL
        REFERENCES core.customers (customer_id) ON DELETE CASCADE,
    event_date      TIMESTAMP NOT NULL DEFAULT now(),
    event_type      VARCHAR(50) NOT NULL
);

-- ------------------------------------------------------------
-- audit.payment_audit_log
-- ------------------------------------------------------------
CREATE TABLE audit.payment_audit_log (
    log_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_id      BIGINT NOT NULL
        REFERENCES core.payments (payment_id) ON DELETE CASCADE,
    old_status      VARCHAR(20),
    new_status      VARCHAR(20) NOT NULL,
    changed_at      TIMESTAMP NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- Indexes de apoio para queries analíticas
-- ------------------------------------------------------------
CREATE INDEX idx_subscriptions_customer_id ON core.subscriptions (customer_id);
CREATE INDEX idx_subscriptions_plan_id ON core.subscriptions (plan_id);
CREATE INDEX idx_payments_subscription_id ON core.payments (subscription_id);
CREATE INDEX idx_payments_status ON core.payments (status);
CREATE INDEX idx_support_tickets_customer_id ON core.support_tickets (customer_id);
CREATE INDEX idx_usage_events_customer_id ON core.usage_events (customer_id);
CREATE INDEX idx_usage_events_event_date ON core.usage_events (event_date);