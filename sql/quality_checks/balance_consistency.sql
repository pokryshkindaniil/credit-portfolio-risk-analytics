-- Balance consistency check.
-- Flags contracts with negative balances or overdue principal above outstanding principal.
-- A valid portfolio should return no rows.
-- Grain: one row per flagged loan contract.

SET search_path TO credit_portfolio;

SELECT
    loan_contract_id,
    contract_number,
    contract_status,
    outstanding_principal,
    overdue_principal
FROM portfolio_snapshot
WHERE outstanding_principal < 0
   OR overdue_principal < 0
   OR overdue_principal > outstanding_principal;
