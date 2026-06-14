# ============================================================
# data_generator/db_loader.py
# Customer Revenue Recovery Platform - DB Loader
# Truncates core tables and loads CSVs via COPY (psycopg3)
# ============================================================

import os
import psycopg

from config import DB_CONFIG, OUTPUT_DIR

# Order matters: respect FK dependencies for TRUNCATE CASCADE
TRUNCATE_ORDER = [
    "audit.payment_audit_log",
    "core.usage_events",
    "core.support_tickets",
    "core.payments",
    "core.subscriptions",
    "core.customers",
    "core.plans",
]

# (table, csv_file, columns)
COPY_TABLES = [
    (
        "core.plans",
        "plans.csv",
        ["plan_id", "plan_name", "billing_cycle", "price"],
    ),
    (
        "core.customers",
        "customers.csv",
        ["customer_id", "name", "email", "segment", "country", "status", "created_at"],
    ),
    (
        "core.subscriptions",
        "subscriptions.csv",
        ["subscription_id", "customer_id", "plan_id", "start_date", "end_date", "status", "canceled_at"],
    ),
    (
        "core.payments",
        "payments.csv",
        ["payment_id", "subscription_id", "amount", "due_date", "payment_date", "status"],
    ),
    (
        "core.support_tickets",
        "tickets.csv",
        ["ticket_id", "customer_id", "opened_at", "closed_at", "status", "resolution_time_hours"],
    ),
    (
        "core.usage_events",
        "usage_events.csv",
        ["event_id", "customer_id", "event_date", "event_type"],
    ),
]

# Sequences to reset after loading (since we provide explicit IDs)
SEQUENCES = {
    "core.plans": ("plan_id", "core.plans_plan_id_seq"),
    "core.customers": ("customer_id", "core.customers_customer_id_seq"),
    "core.subscriptions": ("subscription_id", "core.subscriptions_subscription_id_seq"),
    "core.payments": ("payment_id", "core.payments_payment_id_seq"),
    "core.support_tickets": ("ticket_id", "core.support_tickets_ticket_id_seq"),
    "core.usage_events": ("event_id", "core.usage_events_event_id_seq"),
}


def truncate_tables(cur):
    print("Truncating tables...")
    for table in TRUNCATE_ORDER:
        cur.execute(f"TRUNCATE TABLE {table} RESTART IDENTITY CASCADE;")


def copy_csv(cur, table, csv_filename, columns):
    csv_path = os.path.join(OUTPUT_DIR, csv_filename)
    columns_str = ", ".join(columns)

    print(f"Loading {table} from {csv_filename}...")
    with open(csv_path, "r", encoding="utf-8") as f:
        # skip header line, we'll feed rows manually via copy
        with cur.copy(
            f"COPY {table} ({columns_str}) FROM STDIN WITH (FORMAT csv, HEADER true, NULL '')"
        ) as copy:
            while data := f.read(8192):
                copy.write(data)


def reset_sequences(cur):
    print("Resetting sequences...")
    for table, (id_column, seq_name) in SEQUENCES.items():
        cur.execute(
            f"SELECT setval('{seq_name}', COALESCE((SELECT MAX({id_column}) FROM {table}), 1), true);"
        )


def main():
    conn = psycopg.connect(**DB_CONFIG)

    try:
        with conn.cursor() as cur:
            truncate_tables(cur)

            for table, csv_filename, columns in COPY_TABLES:
                copy_csv(cur, table, csv_filename, columns)

            reset_sequences(cur)

        conn.commit()
        print("Load completed successfully.")

    except Exception as e:
        conn.rollback()
        print(f"Error during load, rolled back: {e}")
        raise

    finally:
        conn.close()


if __name__ == "__main__":
    main()