# ============================================================
# tests/test_views.py
# Customer Revenue Recovery Platform
# Analytics views and trigger behavior tests
# ============================================================


def test_vw_customer_revenue_row_count(db_cursor):
    db_cursor.execute("SELECT COUNT(*) FROM analytics.vw_customer_revenue;")
    assert db_cursor.fetchone()[0] == 500


def test_vw_customer_revenue_non_negative(db_cursor):
    db_cursor.execute(
        """
        SELECT COUNT(*)
        FROM analytics.vw_customer_revenue
        WHERE mrr < 0 OR total_revenue_paid < 0;
        """
    )
    assert db_cursor.fetchone()[0] == 0


def test_vw_customer_health_score_range(db_cursor):
    db_cursor.execute(
        """
        SELECT COUNT(*)
        FROM analytics.vw_customer_health
        WHERE health_score < 0 OR health_score > 100;
        """
    )
    assert db_cursor.fetchone()[0] == 0


def test_vw_customer_health_status_values(db_cursor):
    db_cursor.execute(
        """
        SELECT DISTINCT health_status
        FROM analytics.vw_customer_health;
        """
    )
    statuses = {row[0] for row in db_cursor.fetchall()}
    assert statuses.issubset({"healthy", "at_risk", "critical"})


def test_vw_revenue_recovery_positive_amounts(db_cursor):
    db_cursor.execute(
        """
        SELECT COUNT(*)
        FROM analytics.vw_revenue_recovery
        WHERE revenue_at_risk <= 0;
        """
    )
    assert db_cursor.fetchone()[0] == 0


def test_vw_revenue_recovery_matches_payments(db_cursor):
    """
    Total revenue_at_risk should match the sum of late/failed/pending
    payments directly queried from core.payments.
    """
    db_cursor.execute(
        "SELECT COALESCE(SUM(revenue_at_risk), 0) FROM analytics.vw_revenue_recovery;"
    )
    view_total = db_cursor.fetchone()[0]

    db_cursor.execute(
        """
        SELECT COALESCE(SUM(amount), 0)
        FROM core.payments
        WHERE status IN ('late', 'failed', 'pending');
        """
    )
    raw_total = db_cursor.fetchone()[0]

    assert view_total == raw_total


def test_audit_trigger_logs_status_change(db_transaction):
    """
    Update a payment's status and verify the audit trigger logs it.
    The transaction is rolled back after this test (db_transaction fixture).
    """
    cur = db_transaction

    # pick any payment not currently 'paid'
    cur.execute(
        "SELECT payment_id, status FROM core.payments WHERE status != 'paid' LIMIT 1;"
    )
    row = cur.fetchone()
    assert row is not None, "No non-paid payment found to test the trigger"

    payment_id, old_status = row

    cur.execute(
        "UPDATE core.payments SET status = 'paid' WHERE payment_id = %s;",
        (payment_id,),
    )

    cur.execute(
        """
        SELECT old_status, new_status
        FROM audit.payment_audit_log
        WHERE payment_id = %s
        ORDER BY changed_at DESC
        LIMIT 1;
        """,
        (payment_id,),
    )
    log_row = cur.fetchone()

    assert log_row is not None
    assert log_row[0] == old_status
    assert log_row[1] == "paid"