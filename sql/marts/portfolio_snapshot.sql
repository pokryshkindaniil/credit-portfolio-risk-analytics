-- Current credit portfolio snapshot.
-- One row per loan contract.

SET search_path TO credit_portfolio;

CREATE OR REPLACE VIEW portfolio_snapshot AS

WITH payments_by_contract AS (
    SELECT
        ps.loan_contract_id,
        SUM(p.principal_paid) AS paid_principal
    FROM payment_schedule AS ps
    INNER JOIN payments AS p
        ON p.payment_schedule_id = ps.payment_schedule_id
    WHERE p.payment_status = 'posted'
    GROUP BY
        ps.loan_contract_id
),

delinquency_by_contract AS (
    SELECT
        ps.loan_contract_id,

        SUM(de.overdue_principal)
            FILTER (WHERE de.delinquency_status = 'open')
            AS overdue_principal,

        MAX(de.max_dpd)
            FILTER (WHERE de.delinquency_status = 'open')
            AS current_dpd,

        MAX(de.max_dpd) AS max_dpd

    FROM payment_schedule AS ps
    LEFT JOIN delinquency_events AS de
        ON de.payment_schedule_id = ps.payment_schedule_id
    GROUP BY
        ps.loan_contract_id
)

SELECT
    lc.loan_contract_id,
    lc.contract_number,
    lc.start_date,
    lc.maturity_date,
    lc.principal_amount,
    lc.contract_status,

    COALESCE(pc.paid_principal, 0) AS paid_principal,

    lc.principal_amount
        - COALESCE(pc.paid_principal, 0)
        AS outstanding_principal,

    COALESCE(dc.overdue_principal, 0) AS overdue_principal,
    COALESCE(dc.current_dpd, 0) AS current_dpd,
    COALESCE(dc.max_dpd, 0) AS max_dpd,

    CASE
        WHEN COALESCE(dc.current_dpd, 0) = 0 THEN 'Current'
        WHEN dc.current_dpd <= 30 THEN '1-30'
        WHEN dc.current_dpd <= 60 THEN '31-60'
        WHEN dc.current_dpd <= 89 THEN '61-89'
        ELSE '90+'
    END AS dpd_bucket

FROM loan_contracts AS lc

LEFT JOIN payments_by_contract AS pc
    ON pc.loan_contract_id = lc.loan_contract_id

LEFT JOIN delinquency_by_contract AS dc
    ON dc.loan_contract_id = lc.loan_contract_id;
