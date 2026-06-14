# ============================================================
# tests/test_data_quality.py
# Customer Revenue Recovery Platform
# Data quality / business rule tests
# ============================================================


def test_all_customers_have_subscription(db_cursor):
    db_cursor.execute(
        """
        SELECT COUNT(*)
        FROM core.customers c
        LEFT JOIN core.subscriptions s ON s.customer_id = c.customer_id
        WHERE s.subscription_id IS NULL;
        """
    )
    count = db_cursor.fetchone()[0]
    assert count == 0, f"{count} customers without a subscription"


def test_no_invalid_payment_dates(db_cursor):
    """
    payment_date must be NULL or >= due_date - 90 days (per CHECK constraint).
    This test re-validates at the data level.
    """
    db_cursor.execute(
        """
        SELECT COUNT(*)
        FROM core.payments
        WHERE payment_date IS NOT NULL
          AND payment_date < due_date - INTERVAL '90 days';
        """
    )
    count = db_cursor.fetchone()[0]
    assert count == 0, f"{count} payments with invalid payment_date"


def test_no_inconsistent_payment_status(db_cursor):
    """
    A payment with a payment_date set should be 'paid' or 'late',
    never 'failed' or 'pending'.
    """
    db_cursor.execute(
        """
        SELECT COUNT(*)
        FROM core.payments
        WHERE payment_date IS NOT NULL
          AND status NOT IN ('paid', 'late');
        """
    )
    count = db_cursor.fetchone()[0]
    assert count == 0, f"{count} payments with inconsistent status"


def test_no_active_customer_with_canceled_subscription(db_cursor):
    db_cursor.execute(
        """
        SELECT COUNT(*)
        FROM core.customers c
        JOIN core.subscriptions s ON s.customer_id = c.customer_id
        WHERE c.status = 'active' AND s.status = 'canceled';
        """
    )
    count = db_cursor.fetchone()[0]
    assert count == 0, f"{count} active customers with a canceled subscription"


def test_no_negative_amounts(db_cursor):
    db_cursor.execute("SELECT COUNT(*) FROM core.payments WHERE amount < 0;")
    assert db_cursor.fetchone()[0] == 0


def test_subscription_end_date_after_start_date(db_cursor):
    db_cursor.execute(
        """
        SELECT COUNT(*)
        FROM core.subscriptions
        WHERE end_date IS NOT NULL AND end_date < start_date;
        """
    )
    assert db_cursor.fetchone()[0] == 0


def test_ticket_closed_after_opened(db_cursor):
    db_cursor.execute(
        """
        SELECT COUNT(*)
        FROM core.support_tickets
        WHERE closed_at IS NOT NULL AND closed_at < opened_at;
        """
    )
    assert db_cursor.fetchone()[0] == 0


def test_expected_row_counts(db_cursor):
    """Sanity check on overall data volume (loaded via data_generator)."""
    db_cursor.execute("SELECT COUNT(*) FROM core.customers;")
    assert db_cursor.fetchone()[0] == 500

    db_cursor.execute("SELECT COUNT(*) FROM core.subscriptions;")
    assert db_cursor.fetchone()[0] == 500

    db_cursor.execute("SELECT COUNT(*) FROM core.payments;")
    assert db_cursor.fetchone()[0] > 0

    db_cursor.execute("SELECT COUNT(*) FROM core.support_tickets;")
    assert db_cursor.fetchone()[0] > 0

    db_cursor.execute("SELECT COUNT(*) FROM core.usage_events;")
    assert db_cursor.fetchone()[0] > 0