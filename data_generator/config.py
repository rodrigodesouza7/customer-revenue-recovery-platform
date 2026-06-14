# ============================================================
# data_generator/config.py
# Customer Revenue Recovery Platform - Data Generator Config
# ============================================================

import os
from dotenv import load_dotenv

# Allows switching environments without editing files:
#   ENV_FILE=.env.docker python3 generate_data.py
# Defaults to .env (Homebrew local Postgres)
_env_file = os.getenv("ENV_FILE", ".env")
_env_path = os.path.join(os.path.dirname(__file__), "..", _env_file)
load_dotenv(dotenv_path=_env_path)

# ------------------------------------------------------------
# Database connection
# ------------------------------------------------------------
DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": os.getenv("DB_PORT", "5432"),
    "dbname": os.getenv("DB_NAME", "customer_revenue_recovery"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", ""),
}

# ------------------------------------------------------------
# Volume parameters
# ------------------------------------------------------------
NUM_CUSTOMERS = 500
HISTORY_YEARS = 3

# Approximate targets (actual numbers vary slightly based on
# subscription lifetimes and churn)
TARGET_PAYMENTS = 25000
TARGET_TICKETS = 10000
TARGET_USAGE_EVENTS = 150000

# ------------------------------------------------------------
# Distribution parameters
# ------------------------------------------------------------

# Customer segments
SEGMENTS = ["SMB", "Mid-Market", "Enterprise"]
SEGMENT_WEIGHTS = [0.6, 0.3, 0.1]

# Countries
COUNTRIES = ["Brazil", "USA", "Portugal", "Spain", "Germany"]
COUNTRY_WEIGHTS = [0.5, 0.2, 0.15, 0.1, 0.05]

# Subscription status distribution (active customers)
SUBSCRIPTION_STATUS_WEIGHTS = {
    "active": 0.75,
    "past_due": 0.10,
    "canceled": 0.15,
}

# Payment status distribution (for due payments)
PAYMENT_STATUS_WEIGHTS = {
    "paid": 0.85,
    "late": 0.07,
    "failed": 0.05,
    "pending": 0.03,
}

# Probability a payment that was late/failed gets recovered (paid later)
RECOVERY_PROBABILITY = 0.4

# Ticket status distribution
TICKET_STATUS_WEIGHTS = {
    "closed": 0.75,
    "open": 0.15,
    "in_progress": 0.10,
}

# Usage event types
EVENT_TYPES = ["login", "feature_used", "report_generated", "api_call", "export_data"]

# Random seed for reproducibility
RANDOM_SEED = 42

# ------------------------------------------------------------
# Output
# ------------------------------------------------------------
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "output")