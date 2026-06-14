-- ============================================================
-- 05_audit_trigger.sql
-- Customer Revenue Recovery Platform
-- Audit trigger for payment status changes
-- ============================================================

CREATE OR REPLACE FUNCTION audit.log_payment_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO audit.payment_audit_log (
            payment_id,
            old_status,
            new_status,
            changed_at
        ) VALUES (
            NEW.payment_id,
            OLD.status,
            NEW.status,
            now()
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE TRIGGER trg_payment_status_audit
    AFTER UPDATE ON core.payments
    FOR EACH ROW
    EXECUTE FUNCTION audit.log_payment_status_change();