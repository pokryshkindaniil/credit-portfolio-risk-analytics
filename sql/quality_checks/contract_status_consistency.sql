-- Contract status consistency check.
-- Flags active contracts with current DPD 90+ and a positive outstanding balance.
-- These records require review against the portfolio's default status rules.
-- Grain: one row per flagged loan contract.

SET search_path TO credit_portfolio;

SELECT
    loan_contract_id,
    contract_number,
    contract_status,
    current_dpd,
    outstanding_principal,
    overdue_principal,
    dpd_bucket
FROM portfolio_snapshot
WHERE contract_status = 'active'
  AND current_dpd >= 90
  AND outstanding_principal > 0
ORDER BY
    current_dpd DESC,
    outstanding_principal DESC;
