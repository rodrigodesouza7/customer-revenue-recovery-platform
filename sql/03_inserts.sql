-- ============================================================
-- 03_inserts.sql
-- Customer Revenue Recovery Platform
-- Seed data (manual) - cenários variados para validação
-- ============================================================

-- ------------------------------------------------------------
-- core.plans
-- ------------------------------------------------------------
INSERT INTO core.plans (plan_name, billing_cycle, price) VALUES
('Starter Monthly', 'monthly', 49.00),
('Pro Monthly', 'monthly', 149.00),
('Enterprise Monthly', 'monthly', 499.00),
('Starter Annual', 'annual', 490.00),
('Pro Annual', 'annual', 1490.00);

-- ------------------------------------------------------------
-- core.customers
-- ------------------------------------------------------------
INSERT INTO core.customers (name, email, segment, country, status, created_at) VALUES
('Acme Corp', 'contact@acme.com', 'Enterprise', 'USA', 'active', now() - INTERVAL '24 months'),
('Beta Solutions', 'hello@betasol.com', 'SMB', 'Brazil', 'active', now() - INTERVAL '20 months'),
('Gamma Tech', 'info@gammatech.com', 'Mid-Market', 'Brazil', 'active', now() - INTERVAL '18 months'),
('Delta Systems', 'team@deltasys.com', 'SMB', 'Portugal', 'inactive', now() - INTERVAL '16 months'),
('Epsilon Labs', 'contact@epsilonlabs.com', 'Mid-Market', 'USA', 'active', now() - INTERVAL '15 months'),
('Zeta Group', 'hello@zetagroup.com', 'Enterprise', 'Brazil', 'active', now() - INTERVAL '14 months'),
('Eta Partners', 'info@etapartners.com', 'SMB', 'Spain', 'active', now() - INTERVAL '13 months'),
('Theta Inc', 'contact@thetainc.com', 'SMB', 'Brazil', 'inactive', now() - INTERVAL '12 months'),
('Iota Networks', 'team@iotanetworks.com', 'Mid-Market', 'USA', 'active', now() - INTERVAL '11 months'),
('Kappa Digital', 'hello@kappadigital.com', 'SMB', 'Brazil', 'active', now() - INTERVAL '10 months'),
('Lambda Cloud', 'info@lambdacloud.com', 'Enterprise', 'Germany', 'active', now() - INTERVAL '9 months'),
('Mu Analytics', 'contact@muanalytics.com', 'Mid-Market', 'Brazil', 'active', now() - INTERVAL '8 months'),
('Nu Retail', 'team@nuretail.com', 'SMB', 'Brazil', 'active', now() - INTERVAL '7 months'),
('Xi Logistics', 'hello@xilogistics.com', 'Mid-Market', 'Portugal', 'active', now() - INTERVAL '6 months'),
('Omicron Media', 'info@omicronmedia.com', 'SMB', 'Brazil', 'active', now() - INTERVAL '5 months'),
('Pi Software', 'contact@pisoftware.com', 'Enterprise', 'USA', 'active', now() - INTERVAL '4 months'),
('Rho Consulting', 'team@rhoconsulting.com', 'SMB', 'Brazil', 'active', now() - INTERVAL '3 months'),
('Sigma Health', 'hello@sigmahealth.com', 'Mid-Market', 'Spain', 'inactive', now() - INTERVAL '20 months'),
('Tau Education', 'info@taueducation.com', 'SMB', 'Brazil', 'active', now() - INTERVAL '2 months'),
('Ypsilon Foods', 'contact@ypsilonfoods.com', 'Mid-Market', 'Brazil', 'active', now() - INTERVAL '1 month');

-- ------------------------------------------------------------
-- core.subscriptions
-- Cenários: ativo saudável, cancelado, past_due, recém-criado
-- ------------------------------------------------------------
INSERT INTO core.subscriptions (customer_id, plan_id, start_date, end_date, status, canceled_at) VALUES
-- Acme Corp: Enterprise ativo, saudável
(1, 3, (now() - INTERVAL '24 months')::date, NULL, 'active', NULL),
-- Beta Solutions: Pro ativo
(2, 2, (now() - INTERVAL '20 months')::date, NULL, 'active', NULL),
-- Gamma Tech: Pro ativo
(3, 2, (now() - INTERVAL '18 months')::date, NULL, 'active', NULL),
-- Delta Systems: cancelado há 4 meses
(4, 1, (now() - INTERVAL '16 months')::date, (now() - INTERVAL '4 months')::date, 'canceled', now() - INTERVAL '4 months'),
-- Epsilon Labs: Pro ativo
(5, 2, (now() - INTERVAL '15 months')::date, NULL, 'active', NULL),
-- Zeta Group: Enterprise ativo
(6, 3, (now() - INTERVAL '14 months')::date, NULL, 'active', NULL),
-- Eta Partners: Starter ativo
(7, 1, (now() - INTERVAL '13 months')::date, NULL, 'active', NULL),
-- Theta Inc: cancelado há 6 meses
(8, 1, (now() - INTERVAL '12 months')::date, (now() - INTERVAL '6 months')::date, 'canceled', now() - INTERVAL '6 months'),
-- Iota Networks: Pro past_due (inadimplente)
(9, 2, (now() - INTERVAL '11 months')::date, NULL, 'past_due', NULL),
-- Kappa Digital: Starter ativo
(10, 1, (now() - INTERVAL '10 months')::date, NULL, 'active', NULL),
-- Lambda Cloud: Enterprise ativo
(11, 3, (now() - INTERVAL '9 months')::date, NULL, 'active', NULL),
-- Mu Analytics: Pro past_due
(12, 2, (now() - INTERVAL '8 months')::date, NULL, 'past_due', NULL),
-- Nu Retail: Starter ativo
(13, 1, (now() - INTERVAL '7 months')::date, NULL, 'active', NULL),
-- Xi Logistics: Pro Annual ativo
(14, 5, (now() - INTERVAL '6 months')::date, NULL, 'active', NULL),
-- Omicron Media: Starter ativo
(15, 1, (now() - INTERVAL '5 months')::date, NULL, 'active', NULL),
-- Pi Software: Enterprise ativo
(16, 3, (now() - INTERVAL '4 months')::date, NULL, 'active', NULL),
-- Rho Consulting: Starter ativo
(17, 1, (now() - INTERVAL '3 months')::date, NULL, 'active', NULL),
-- Sigma Health: cancelado há 10 meses
(18, 2, (now() - INTERVAL '20 months')::date, (now() - INTERVAL '10 months')::date, 'canceled', now() - INTERVAL '10 months'),
-- Tau Education: Starter ativo, recém-criado
(19, 1, (now() - INTERVAL '2 months')::date, NULL, 'active', NULL),
-- Ypsilon Foods: Starter Annual ativo, recém-criado
(20, 4, (now() - INTERVAL '1 month')::date, NULL, 'active', NULL);

-- ------------------------------------------------------------
-- core.payments
-- Cenários: pagos em dia, atrasados, falhados, pendentes
-- subscription_id segue a ordem de inserção acima (1 a 20)
-- ------------------------------------------------------------
INSERT INTO core.payments (subscription_id, amount, due_date, payment_date, status) VALUES
-- Acme Corp (sub 1): histórico saudável, últimos 3 meses pagos em dia
(1, 499.00, (now() - INTERVAL '3 months')::date, (now() - INTERVAL '3 months')::date, 'paid'),
(1, 499.00, (now() - INTERVAL '2 months')::date, (now() - INTERVAL '2 months')::date, 'paid'),
(1, 499.00, (now() - INTERVAL '1 month')::date, (now() - INTERVAL '1 month')::date, 'paid'),

-- Beta Solutions (sub 2): pago em dia
(2, 149.00, (now() - INTERVAL '2 months')::date, (now() - INTERVAL '2 months')::date, 'paid'),
(2, 149.00, (now() - INTERVAL '1 month')::date, (now() - INTERVAL '1 month')::date, 'paid'),

-- Gamma Tech (sub 3): um pagamento atrasado recentemente
(3, 149.00, (now() - INTERVAL '2 months')::date, (now() - INTERVAL '2 months')::date, 'paid'),
(3, 149.00, (now() - INTERVAL '1 month')::date, (now() - INTERVAL '1 month' + INTERVAL '10 days')::date, 'late'),

-- Delta Systems (sub 4): cancelado, último pagamento antes do cancelamento
(4, 49.00, (now() - INTERVAL '5 months')::date, (now() - INTERVAL '5 months')::date, 'paid'),

-- Epsilon Labs (sub 5): saudável
(5, 149.00, (now() - INTERVAL '2 months')::date, (now() - INTERVAL '2 months')::date, 'paid'),
(5, 149.00, (now() - INTERVAL '1 month')::date, (now() - INTERVAL '1 month')::date, 'paid'),

-- Zeta Group (sub 6): saudável, Enterprise
(6, 499.00, (now() - INTERVAL '2 months')::date, (now() - INTERVAL '2 months')::date, 'paid'),
(6, 499.00, (now() - INTERVAL '1 month')::date, (now() - INTERVAL '1 month')::date, 'paid'),

-- Eta Partners (sub 7): saudável
(7, 49.00, (now() - INTERVAL '2 months')::date, (now() - INTERVAL '2 months')::date, 'paid'),
(7, 49.00, (now() - INTERVAL '1 month')::date, (now() - INTERVAL '1 month')::date, 'paid'),

-- Theta Inc (sub 8): cancelado, último pagamento falhou antes do cancelamento
(8, 49.00, (now() - INTERVAL '7 months')::date, NULL, 'failed'),

-- Iota Networks (sub 9): past_due - pagamento atual pendente, anterior falhou
(9, 149.00, (now() - INTERVAL '2 months')::date, (now() - INTERVAL '2 months')::date, 'paid'),
(9, 149.00, (now() - INTERVAL '1 month')::date, NULL, 'failed'),
(9, 149.00, (now())::date, NULL, 'pending'),

-- Kappa Digital (sub 10): saudável
(10, 49.00, (now() - INTERVAL '2 months')::date, (now() - INTERVAL '2 months')::date, 'paid'),
(10, 49.00, (now() - INTERVAL '1 month')::date, (now() - INTERVAL '1 month')::date, 'paid'),

-- Lambda Cloud (sub 11): saudável, Enterprise
(11, 499.00, (now() - INTERVAL '2 months')::date, (now() - INTERVAL '2 months')::date, 'paid'),
(11, 499.00, (now() - INTERVAL '1 month')::date, (now() - INTERVAL '1 month')::date, 'paid'),

-- Mu Analytics (sub 12): past_due - dois meses em atraso
(12, 149.00, (now() - INTERVAL '2 months')::date, NULL, 'late'),
(12, 149.00, (now() - INTERVAL '1 month')::date, NULL, 'late'),

-- Nu Retail (sub 13): saudável
(13, 49.00, (now() - INTERVAL '2 months')::date, (now() - INTERVAL '2 months')::date, 'paid'),
(13, 49.00, (now() - INTERVAL '1 month')::date, (now() - INTERVAL '1 month')::date, 'paid'),

-- Xi Logistics (sub 14): Annual, pago no início do ciclo
(14, 1490.00, (now() - INTERVAL '6 months')::date, (now() - INTERVAL '6 months')::date, 'paid'),

-- Omicron Media (sub 15): saudável
(15, 49.00, (now() - INTERVAL '2 months')::date, (now() - INTERVAL '2 months')::date, 'paid'),
(15, 49.00, (now() - INTERVAL '1 month')::date, (now() - INTERVAL '1 month')::date, 'paid'),

-- Pi Software (sub 16): saudável, Enterprise
(16, 499.00, (now() - INTERVAL '2 months')::date, (now() - INTERVAL '2 months')::date, 'paid'),
(16, 499.00, (now() - INTERVAL '1 month')::date, (now() - INTERVAL '1 month')::date, 'paid'),

-- Rho Consulting (sub 17): saudável, recente
(17, 49.00, (now() - INTERVAL '1 month')::date, (now() - INTERVAL '1 month')::date, 'paid'),

-- Sigma Health (sub 18): cancelado, pagamento falhou antes do fim
(18, 149.00, (now() - INTERVAL '11 months')::date, NULL, 'failed'),

-- Tau Education (sub 19): recém-criado, primeiro pagamento pendente
(19, 49.00, (now())::date, NULL, 'pending'),

-- Ypsilon Foods (sub 20): recém-criado, primeiro pagamento pago
(20, 490.00, (now() - INTERVAL '1 month')::date, (now() - INTERVAL '1 month')::date, 'paid');

-- ------------------------------------------------------------
-- core.support_tickets
-- Cenários: clientes saudáveis com poucos tickets,
-- clientes em risco com vários tickets abertos/longos
-- ------------------------------------------------------------
INSERT INTO core.support_tickets (customer_id, opened_at, closed_at, status, resolution_time_hours) VALUES
-- Acme Corp: poucos tickets, resolvidos rápido
(1, now() - INTERVAL '3 months', now() - INTERVAL '3 months' + INTERVAL '4 hours', 'closed', 4.0),
(1, now() - INTERVAL '1 month', now() - INTERVAL '1 month' + INTERVAL '2 hours', 'closed', 2.0),

-- Gamma Tech: ticket em aberto há tempo (sinal de risco leve)
(3, now() - INTERVAL '20 days', NULL, 'open', NULL),

-- Iota Networks (past_due): vários tickets, alguns longos
(9, now() - INTERVAL '2 months', now() - INTERVAL '2 months' + INTERVAL '72 hours', 'closed', 72.0),
(9, now() - INTERVAL '25 days', NULL, 'open', NULL),
(9, now() - INTERVAL '10 days', NULL, 'in_progress', NULL),

-- Mu Analytics (past_due): tickets recorrentes
(12, now() - INTERVAL '45 days', now() - INTERVAL '45 days' + INTERVAL '48 hours', 'closed', 48.0),
(12, now() - INTERVAL '15 days', NULL, 'open', NULL),

-- Theta Inc (cancelado): tickets antes do cancelamento, mal resolvidos
(8, now() - INTERVAL '8 months', now() - INTERVAL '8 months' + INTERVAL '96 hours', 'closed', 96.0),
(8, now() - INTERVAL '7 months', NULL, 'closed', NULL),

-- Sigma Health (cancelado): histórico de tickets longos
(18, now() - INTERVAL '12 months', now() - INTERVAL '12 months' + INTERVAL '120 hours', 'closed', 120.0),

-- Eta Partners: saudável, ticket simples resolvido
(7, now() - INTERVAL '1 month', now() - INTERVAL '1 month' + INTERVAL '1 hour', 'closed', 1.0),

-- Tau Education: novo cliente, primeiro contato com suporte
(19, now() - INTERVAL '5 days', NULL, 'open', NULL);

-- ------------------------------------------------------------
-- core.usage_events
-- Cenários: alto engajamento, baixo engajamento (risco de churn)
-- ------------------------------------------------------------
-- Acme Corp: alto engajamento (eventos diários recentes)
INSERT INTO core.usage_events (customer_id, event_date, event_type)
SELECT 1, now() - (n || ' days')::interval, 'login'
FROM generate_series(1, 30) AS n;

INSERT INTO core.usage_events (customer_id, event_date, event_type)
SELECT 1, now() - (n || ' days')::interval, 'feature_used'
FROM generate_series(1, 15) AS n;

-- Beta Solutions: engajamento moderado
INSERT INTO core.usage_events (customer_id, event_date, event_type)
SELECT 2, now() - (n * 2 || ' days')::interval, 'login'
FROM generate_series(1, 15) AS n;

-- Gamma Tech: engajamento caindo (poucos eventos recentes)
INSERT INTO core.usage_events (customer_id, event_date, event_type)
SELECT 3, now() - (n * 7 || ' days')::interval, 'login'
FROM generate_series(1, 4) AS n;

-- Iota Networks (past_due): engajamento muito baixo, sinal de risco
INSERT INTO core.usage_events (customer_id, event_date, event_type)
SELECT 9, now() - (n * 15 || ' days')::interval, 'login'
FROM generate_series(1, 2) AS n;

-- Mu Analytics (past_due): engajamento baixo
INSERT INTO core.usage_events (customer_id, event_date, event_type)
SELECT 12, now() - (n * 10 || ' days')::interval, 'login'
FROM generate_series(1, 3) AS n;

-- Lambda Cloud: alto engajamento, Enterprise saudável
INSERT INTO core.usage_events (customer_id, event_date, event_type)
SELECT 11, now() - (n || ' days')::interval, 'login'
FROM generate_series(1, 25) AS n;

INSERT INTO core.usage_events (customer_id, event_date, event_type)
SELECT 11, now() - (n || ' days')::interval, 'feature_used'
FROM generate_series(1, 20) AS n;

-- Pi Software: engajamento moderado-alto
INSERT INTO core.usage_events (customer_id, event_date, event_type)
SELECT 16, now() - (n * 3 || ' days')::interval, 'login'
FROM generate_series(1, 12) AS n;

-- Tau Education: novo cliente, poucos eventos
INSERT INTO core.usage_events (customer_id, event_date, event_type)
SELECT 19, now() - (n || ' days')::interval, 'login'
FROM generate_series(1, 3) AS n;