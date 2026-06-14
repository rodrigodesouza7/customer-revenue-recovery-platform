# ============================================================
# data_generator/generate_data.py
# Customer Revenue Recovery Platform - Data Generator
# ============================================================

import os
import random
from datetime import timedelta, date

import pandas as pd
from faker import Faker

from config import (
    NUM_CUSTOMERS,
    HISTORY_YEARS,
    TARGET_PAYMENTS,
    TARGET_TICKETS,
    TARGET_USAGE_EVENTS,
    SEGMENTS,
    SEGMENT_WEIGHTS,
    COUNTRIES,
    COUNTRY_WEIGHTS,
    SUBSCRIPTION_STATUS_WEIGHTS,
    PAYMENT_STATUS_WEIGHTS,
    RECOVERY_PROBABILITY,
    TICKET_STATUS_WEIGHTS,
    EVENT_TYPES,
    RANDOM_SEED,
    OUTPUT_DIR,
)

fake = Faker()
Faker.seed(RANDOM_SEED)
random.seed(RANDOM_SEED)

TODAY = date.today()


# ------------------------------------------------------------
# Plans (fixed seed-like data)
# ------------------------------------------------------------
def generate_plans():
    plans = [
        {"plan_id": 1, "plan_name": "Starter Monthly", "billing_cycle": "monthly", "price": 49.00},
        {"plan_id": 2, "plan_name": "Pro Monthly", "billing_cycle": "monthly", "price": 149.00},
        {"plan_id": 3, "plan_name": "Enterprise Monthly", "billing_cycle": "monthly", "price": 499.00},
        {"plan_id": 4, "plan_name": "Starter Annual", "billing_cycle": "annual", "price": 490.00},
        {"plan_id": 5, "plan_name": "Pro Annual", "billing_cycle": "annual", "price": 1490.00},
    ]
    return pd.DataFrame(plans)


# ------------------------------------------------------------
# Customers
# ------------------------------------------------------------
def generate_customers(n=NUM_CUSTOMERS):
    customers = []
    for i in range(1, n + 1):
        created_days_ago = random.randint(30, HISTORY_YEARS * 365)
        created_at = TODAY - timedelta(days=created_days_ago)
        customers.append({
            "customer_id": i,
            "name": fake.company(),
            "email": fake.unique.company_email(),
            "segment": random.choices(SEGMENTS, weights=SEGMENT_WEIGHTS)[0],
            "country": random.choices(COUNTRIES, weights=COUNTRY_WEIGHTS)[0],
            "status": "active",  # adjusted later based on subscription status
            "created_at": created_at,
        })
    return pd.DataFrame(customers)


# ------------------------------------------------------------
# Subscriptions
# ------------------------------------------------------------
def generate_subscriptions(customers_df, plans_df):
    subscriptions = []
    plan_ids = plans_df["plan_id"].tolist()

    for _, customer in customers_df.iterrows():
        sub_id = customer["customer_id"]  # 1:1 for simplicity
        start_date = customer["created_at"]
        plan_id = random.choice(plan_ids)

        status = random.choices(
            list(SUBSCRIPTION_STATUS_WEIGHTS.keys()),
            weights=list(SUBSCRIPTION_STATUS_WEIGHTS.values()),
        )[0]

        end_date = None
        canceled_at = None

        if status == "canceled":
            # canceled sometime between start_date and today
            days_active = (TODAY - start_date).days
            if days_active > 30:
                cancel_offset = random.randint(30, days_active)
                end_date = start_date + timedelta(days=cancel_offset)
                canceled_at = end_date
            else:
                # too recent to have churned, force active
                status = "active"

        subscriptions.append({
            "subscription_id": sub_id,
            "customer_id": customer["customer_id"],
            "plan_id": plan_id,
            "start_date": start_date,
            "end_date": end_date,
            "status": status,
            "canceled_at": canceled_at,
        })

    return pd.DataFrame(subscriptions)


# ------------------------------------------------------------
# Payments
# ------------------------------------------------------------
def generate_payments(subscriptions_df, plans_df, customers_df):
    payments = []
    payment_id = 1

    plans_lookup = plans_df.set_index("plan_id").to_dict("index")

    for _, sub in subscriptions_df.iterrows():
        plan = plans_lookup[sub["plan_id"]]
        price = plan["price"]
        billing_cycle = plan["billing_cycle"]
        cycle_days = 365 if billing_cycle == "annual" else 30

        start_date = sub["start_date"]
        end_date = sub["end_date"] if pd.notna(sub["end_date"]) else TODAY

        # generate billing cycles from start_date until end_date (or today)
        current_due = start_date + timedelta(days=cycle_days)
        cycle_count = 0
        max_cycles = TARGET_PAYMENTS // len(subscriptions_df) + 3  # soft cap per subscription

        while current_due <= end_date and cycle_count < max_cycles:
            status = random.choices(
                list(PAYMENT_STATUS_WEIGHTS.keys()),
                weights=list(PAYMENT_STATUS_WEIGHTS.values()),
            )[0]

            payment_date = None
            if status == "paid":
                payment_date = current_due + timedelta(days=random.randint(-2, 3))
            elif status == "late":
                payment_date = current_due + timedelta(days=random.randint(5, 20))
            # failed / pending -> payment_date stays None

            # recovery: some late/failed payments get fixed later (paid)
            if status in ("late", "failed") and random.random() < RECOVERY_PROBABILITY:
                status = "paid"
                payment_date = current_due + timedelta(days=random.randint(10, 60))
                if payment_date > TODAY:
                    payment_date = TODAY

            payments.append({
                "payment_id": payment_id,
                "subscription_id": sub["subscription_id"],
                "amount": price,
                "due_date": current_due,
                "payment_date": payment_date,
                "status": status,
            })

            payment_id += 1
            current_due = current_due + timedelta(days=cycle_days)
            cycle_count += 1

    payments_df = pd.DataFrame(payments)
    return payments_df


# ------------------------------------------------------------
# Derive final customer status + subscription past_due adjustment
# ------------------------------------------------------------
def finalize_statuses(customers_df, subscriptions_df, payments_df):
    # Customer is inactive if subscription is canceled
    canceled_customers = set(
        subscriptions_df.loc[subscriptions_df["status"] == "canceled", "customer_id"]
    )
    customers_df["status"] = customers_df["customer_id"].apply(
        lambda cid: "inactive" if cid in canceled_customers else "active"
    )

    # Mark subscription as past_due if it has any late/failed/pending payment
    # among its most recent 2 payments and subscription is still active
    problem_subs = set()
    if not payments_df.empty:
        for sub_id, group in payments_df.groupby("subscription_id"):
            recent = group.sort_values("due_date").tail(2)
            if (recent["status"].isin(["late", "failed", "pending"])).any():
                problem_subs.add(sub_id)

    def adjust_status(row):
        if row["status"] == "active" and row["subscription_id"] in problem_subs:
            # ~50% chance to flag as past_due
            if random.random() < 0.5:
                return "past_due"
        return row["status"]

    subscriptions_df["status"] = subscriptions_df.apply(adjust_status, axis=1)

    return customers_df, subscriptions_df


# ------------------------------------------------------------
# Support Tickets
# ------------------------------------------------------------
def generate_tickets(customers_df, target=TARGET_TICKETS):
    tickets = []
    ticket_id = 1

    for _, customer in customers_df.iterrows():
        # number of tickets per customer, gaussian-like via random
        num_tickets = max(0, int(random.gauss(target / len(customers_df), 3)))

        created_days_ago_max = (TODAY - customer["created_at"]).days
        if created_days_ago_max <= 0:
            continue

        for _ in range(num_tickets):
            opened_offset = random.randint(0, created_days_ago_max)
            opened_at = customer["created_at"] + timedelta(days=opened_offset)

            status = random.choices(
                list(TICKET_STATUS_WEIGHTS.keys()),
                weights=list(TICKET_STATUS_WEIGHTS.values()),
            )[0]

            closed_at = None
            resolution_time_hours = None

            if status == "closed":
                resolution_hours = max(1, random.gauss(24, 20))
                resolution_time_hours = round(resolution_hours, 2)
                closed_at = opened_at + timedelta(hours=resolution_hours)
                if closed_at > TODAY:
                    closed_at = None
                    status = "open"
                    resolution_time_hours = None

            tickets.append({
                "ticket_id": ticket_id,
                "customer_id": customer["customer_id"],
                "opened_at": opened_at,
                "closed_at": closed_at,
                "status": status,
                "resolution_time_hours": resolution_time_hours,
            })
            ticket_id += 1

    return pd.DataFrame(tickets)


# ------------------------------------------------------------
# Usage Events
# ------------------------------------------------------------
def generate_usage_events(customers_df, target=TARGET_USAGE_EVENTS):
    events = []
    event_id = 1

    per_customer = max(1, target // len(customers_df))

    for _, customer in customers_df.iterrows():
        created_days_ago_max = (TODAY - customer["created_at"]).days
        if created_days_ago_max <= 0:
            continue

        # Healthier customers (active) generate more recent events;
        # canceled customers generate fewer / older events
        if customer["status"] == "inactive":
            num_events = max(0, int(per_customer * random.uniform(0.1, 0.4)))
            max_days_back = created_days_ago_max
        else:
            num_events = max(0, int(per_customer * random.uniform(0.7, 1.3)))
            max_days_back = min(created_days_ago_max, 90)  # concentrate recent activity

        for _ in range(num_events):
            days_back = random.randint(0, max(1, max_days_back))
            event_date = TODAY - timedelta(days=days_back)
            event_type = random.choice(EVENT_TYPES)

            events.append({
                "event_id": event_id,
                "customer_id": customer["customer_id"],
                "event_date": event_date,
                "event_type": event_type,
            })
            event_id += 1

    return pd.DataFrame(events)


# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print("Generating plans...")
    plans_df = generate_plans()

    print("Generating customers...")
    customers_df = generate_customers()

    print("Generating subscriptions...")
    subscriptions_df = generate_subscriptions(customers_df, plans_df)

    print("Generating payments...")
    payments_df = generate_payments(subscriptions_df, plans_df, customers_df)

    print("Finalizing customer/subscription statuses...")
    customers_df, subscriptions_df = finalize_statuses(customers_df, subscriptions_df, payments_df)

    print("Generating support tickets...")
    tickets_df = generate_tickets(customers_df)

    print("Generating usage events...")
    events_df = generate_usage_events(customers_df)

    print("Writing CSV files...")
    plans_df.to_csv(os.path.join(OUTPUT_DIR, "plans.csv"), index=False)
    customers_df.to_csv(os.path.join(OUTPUT_DIR, "customers.csv"), index=False)
    subscriptions_df.to_csv(os.path.join(OUTPUT_DIR, "subscriptions.csv"), index=False)
    payments_df.to_csv(os.path.join(OUTPUT_DIR, "payments.csv"), index=False)
    tickets_df.to_csv(os.path.join(OUTPUT_DIR, "tickets.csv"), index=False)
    events_df.to_csv(os.path.join(OUTPUT_DIR, "usage_events.csv"), index=False)

    print("Done.")
    print(f"  customers: {len(customers_df)}")
    print(f"  subscriptions: {len(subscriptions_df)}")
    print(f"  payments: {len(payments_df)}")
    print(f"  tickets: {len(tickets_df)}")
    print(f"  usage_events: {len(events_df)}")


if __name__ == "__main__":
    main()