-- ============================================================
-- 01_schema.sql
-- Customer Revenue Recovery Platform
-- Schema creation
-- ============================================================

-- Reset (uso em ambiente de desenvolvimento)
DROP SCHEMA IF EXISTS core CASCADE;
DROP SCHEMA IF EXISTS analytics CASCADE;
DROP SCHEMA IF EXISTS audit CASCADE;

CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS audit;