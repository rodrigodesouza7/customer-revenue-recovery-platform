# ============================================================
# tests/conftest.py
# Customer Revenue Recovery Platform - Pytest fixtures
# ============================================================

import os
import sys

import psycopg
import pytest

# allow importing config from data_generator/
sys.path.insert(
    0, os.path.join(os.path.dirname(__file__), "..", "data_generator")
)

from config import DB_CONFIG  # noqa: E402


@pytest.fixture(scope="session")
def db_connection():
    """Session-scoped read connection to the database."""
    conn = psycopg.connect(**DB_CONFIG)
    yield conn
    conn.close()


@pytest.fixture()
def db_cursor(db_connection):
    """Per-test cursor."""
    with db_connection.cursor() as cur:
        yield cur


@pytest.fixture()
def db_transaction(db_connection):
    """
    Per-test cursor wrapped in a transaction that is always rolled back.
    Use this for tests that need to modify data (e.g. trigger tests).
    """
    with db_connection.cursor() as cur:
        yield cur
    db_connection.rollback()