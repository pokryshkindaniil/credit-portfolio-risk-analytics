-- High-risk contract watchlist.
-- Identifies non-closed contracts with DPD 30+ or a problematic contract status.
-- Assigns priority and explains the main risk drivers for each contract.
-- Grain: one row per loan contract.

SET search_path TO credit_portfolio;

WITH contracts_snapshot AS (
    SELECT
        ps.loan_contract_id,
        ps.contract_number,
        ps.contract_status,
        aps.score,
        aps.probability_of_default,
        ps.outstanding_principal,
        ps.overdue_principal,
        ps.current_dpd,
        ps.max_dpd,
        ps.dpd_bucket
    FROM portfolio_snapshot ps
    LEFT JOIN loan_contracts lc
        ON lc.loan_contract_id = ps.loan_contract_id
    LEFT JOIN application_scores aps
        ON aps.loan_application_id = lc.loan_application_id
    WHERE ps.contract_status <> 'closed'
      AND ps.outstanding_principal > 0
),

watchlist AS (
    SELECT
        loan_contract_id,
        contract_number,
        contract_status,
        score,
        probability_of_default,
        outstanding_principal,
        overdue_principal,
        current_dpd,
        max_dpd,
        dpd_bucket,

        CASE
            WHEN contract_status = 'defaulted'
                OR current_dpd >= 90
                THEN 'Critical'
            WHEN contract_status = 'restructured'
                OR current_dpd BETWEEN 61 AND 89
                THEN 'High'
            WHEN current_dpd BETWEEN 30 AND 60
                THEN 'Medium'
        END AS priority,

        CONCAT_WS(
            '; ',
            CASE
                WHEN current_dpd >= 90 THEN 'Current DPD 90+'
                WHEN current_dpd >= 61 THEN 'Current DPD 61-89'
                WHEN current_dpd >= 30 THEN 'Current DPD 30-60'
            END,
            CASE
                WHEN score < 550 THEN 'Low score'
            END,
            CASE
                WHEN contract_status = 'defaulted' THEN 'Defaulted status'
                WHEN contract_status = 'restructured' THEN 'Restructured status'
            END
        ) AS risk_reason

    FROM contracts_snapshot
    WHERE current_dpd >= 30
       OR contract_status IN ('defaulted', 'restructured')
)

SELECT
    loan_contract_id,
    contract_number,
    contract_status,
    score,
    probability_of_default,
    outstanding_principal,
    overdue_principal,
    current_dpd,
    max_dpd,
    dpd_bucket,
    priority,
    risk_reason
FROM watchlist
ORDER BY
    CASE priority
        WHEN 'Critical' THEN 1
        WHEN 'High' THEN 2
        WHEN 'Medium' THEN 3
    END,
    current_dpd DESC,
    outstanding_principal DESC;
