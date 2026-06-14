# ============================================================
# tests/test_schema.py
# Customer Revenue Recovery Platform
# Schema integrity tests
# ============================================================

import pytest


EXPECTED_CORE_TABLES = {
    "customers",
    "plans",
    "subscriptions",
    "payments",
    "support_tickets",
    "usage_events",
}

EXPECTED_AUDIT_TABLES = {"payment_audit_log"}

EXPECTED_ANALYTICS_VIEWS = {
    "vw_customer_revenue",
    "vw_customer_health",
    "vw_revenue_recovery",
    "vw_recovered_payments",
}


def _get_tables(cur, schema):
    cur.execute(
        """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = %s AND table_type = 'BASE TABLE';
        """,
        (schema,),
    )
    return {row[0] for row in cur.fetchall()}


def _get_views(cur, schema):
    cur.execute(
        """
        SELECT table_name
        FROM information_schema.views
        WHERE table_schema = %s;
        """,
        (schema,),
    )
    return {row[0] for row in cur.fetchall()}


def test_schemas_exist(db_cursor):
    db_cursor.execute(
        """
        SELECT schema_name
        FROM information_schema.schemata
        WHERE schema_name IN ('core', 'analytics', 'audit');
        """
    )
    schemas = {row[0] for row in db_cursor.fetchall()}
    assert schemas == {"core", "analytics", "audit"}


def test_core_tables_exist(db_cursor):
    tables = _get_tables(db_cursor, "core")
    assert EXPECTED_CORE_TABLES.issubset(tables)


def test_audit_tables_exist(db_cursor):
    tables = _get_tables(db_cursor, "audit")
    assert EXPECTED_AUDIT_TABLES.issubset(tables)


def test_analytics_views_exist(db_cursor):
    views = _get_views(db_cursor, "analytics")
    assert EXPECTED_ANALYTICS_VIEWS.issubset(views)


@pytest.mark.parametrize(
    "table,column",
    [
        ("customers", "customer_id"),
        ("customers", "status"),
        ("subscriptions", "subscription_id"),
        ("subscriptions", "status"),
        ("payments", "payment_id"),
        ("payments", "status"),
        ("payments", "amount"),
        ("support_tickets", "ticket_id"),
        ("usage_events", "event_id"),
    ],
)
def test_core_table_has_column(db_cursor, table, column):
    db_cursor.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'core' AND table_name = %s AND column_name = %s;
        """,
        (table, column),
    )
    assert db_cursor.fetchone() is not None, f"core.{table}.{column} not found"


def test_audit_trigger_exists(db_cursor):
    db_cursor.execute(
        """
        SELECT trigger_name
        FROM information_schema.triggers
        WHERE event_object_schema = 'core'
          AND event_object_table = 'payments'
          AND trigger_name = 'trg_payment_status_audit';
        """
    )
    assert db_cursor.fetchone() is not None